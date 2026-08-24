import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/archivio_salute.dart';
import '../health/health_controller.dart';
import '../profile/corpo_controller.dart';
import 'data/calorie_allenamento.dart';
import 'data/session_models.dart';
import 'data/tipo_scelto.dart';
import 'session_controller.dart';
import 'storico_unificato_controller.dart';

/// Le calorie bruciate con l'allenamento, **calcolate sul telefono** —
/// FASE 11.5, 21/08/2026.
///
/// ══ 🚨 IL CAMPO CHE SAREBBE DIVENTATO ZERO IN SILENZIO ════════════════════
///
/// Fino a `v8.4.1` questo numero arrivava dal server in **tre punti diversi**:
/// `nutrition.burned` di `/dashboard`, l'array `burned` di `/series`, e
/// `training` sempre di `/dashboard`. ⚠️ Tutti e tre nascono da
/// `workout_sessions` e `daily_burns`.
///
/// 🚨 Togliendo quelle tabelle senza toccare l'app, i tre campi sarebbero
/// diventati **zero per tutti, senza un errore**: l'obiettivo calorico avrebbe
/// smesso di comprendere le bruciate, e chi si allena avrebbe mangiato meno di
/// quanto poteva credendo di essere in regola. È la classe di difetto di
/// §56.3 n° 3, applicata a un numero su cui si decide cosa mangiare.
///
/// ── ⚠️ La regola, trasportata e non reinventata ──────────────────────────
///
/// | Precedenza | Cosa | Perché |
/// |---|---|---|
/// | 1 | la dichiarazione **a mano** del giorno | è complessiva («oggi ho bruciato 800»), non un contributo |
/// | 2 | la somma delle **sedute** di quel giorno | formula `MET × kg × ore`, o il numero salvato |
///
/// 💡 Sommare la prima alla seconda raddoppierebbe la giornata di chi corregge
/// il numero dopo essersi allenato — la stessa regola che il server applicava in
/// `WorkoutCalorieService::dailyBurned()`.
///
/// ⛔ **Le calorie attive dell'orologio NON entrano qui.** Sono un'altra cosa e
/// hanno la loro strada (`kcalAttivePerGiorniProvider`): chi le mette insieme lo
/// fa a valle, con `BruciateDelGiorno.scegli`, che è il posto dove quella regola
/// vive da sempre.
final bruciateLocaliProvider = FutureProvider.autoDispose
    .family<Map<String, int>, String>((ref, giorniCsv) async {
      /*
       * 💡 La chiave è **una stringa**, non una lista: due liste con lo stesso
       * contenuto non sono uguali per Riverpod, e il provider si ricreerebbe a
       * ogni ridisegno. È la stessa trappola di `kcalAttivePerGiorniProvider`.
       */
      final giorni = giorniCsv.split(',').where((g) => g.isNotEmpty).toSet();

      if (giorni.isEmpty) return const {};

      ref.watch(revisioneAllenamentiProvider);

      final sedute = await ref.watch(sessionsProvider.future);
      final archivio = ref.watch(archivioSaluteProvider);

      /*
       * ══ 🔥 E GLI ALLENAMENTI DI CUI HAI DICHIARATO IL TIPO — B.20.7 ═══════
       *
       * 📌 *«se ci sono quelle che arrivano dall'orologio ok, se le inserisco a
       * mano ok, ma se non faccio nessuna delle due cose non vedo proprio
       * perché quelle stimate non dovrebbero entrare nel calcolo»*.
       *
       * ⛔ **Aveva ragione, e qui c'era un buco.** Le stime venivano **solo**
       * dalle sedute registrate nell'app: una corsa vista solo dall'orologio,
       * su cui avevi dichiarato «corsa», non produceva nessuna seduta — quindi
       * non entrava da nessuna parte, e la giornata la contava zero.
       *
       * ⚠️ **Solo quelle senza calorie proprie.** Se l'orologio le ha misurate,
       * quelle passano dalla loro strada (`kcalAttivePerGiorniProvider`) e
       * sommare la formula qui le conterebbe due volte.
       *
       * 💡 Il peso è quello registrato; senza, il ripiego prudente.
       */
      final dalPolso = await ref
          .watch(allenamentiDalPolsoProvider.future)
          .catchError((Object _) => const <AllenamentoDaOrologio>[]);

      final kg =
          ref.watch(corpoOggiProvider).valueOrNull?.weightKg ??
          CalorieAllenamento.pesoDiRipiego;

      final stimateDalTipo = <String, int>{};

      for (final a in dalPolso) {
        if (a.nascosto) continue;
        if (a.kcal != null && a.kcal! > 0) continue;

        final sport = TipoScelto.per(a.tipoScelto);
        if (sport == null) continue;

        final kcal = CalorieAllenamento.formula(
          durata: a.finitoIl.difference(a.iniziatoIl),
          kg: kg,
          metMedio: sport.met,
        );

        if (kcal <= 0) continue;

        final g = _etichetta(a.iniziatoIl);
        stimateDalTipo[g] = (stimateDalTipo[g] ?? 0) + kcal;
      }

      final perGiorno = <String, List<WorkoutSession>>{};

      for (final s in sedute) {
        // ⛔ Le sedute ancora aperte non contano: non hanno un numero, e
        // contarle come zero abbasserebbe la giornata di chi sta ancora in sala.
        if (s.isOpen) continue;

        (perGiorno[_etichetta(s.startedAt)] ??= []).add(s);
      }

      final fuori = <String, int>{};

      for (final g in giorni) {
        final data = DateTime.tryParse(g);
        if (data == null) continue;

        final aMano = await archivio.bruciateAManoDel(data);

        /*
         * ⚠️ **La dichiarazione a mano vince ancora su tutto.** Le stime dal
         * tipo entrano fra le sedute, cioè **dentro** il ramo che `aMano`
         * scavalca: chi ha scritto un numero l'ha scritto apposta, e una
         * formula non lo sconfessa.
         */
        final kcal = CalorieAllenamento.bruciateDelGiorno(
          aMano: aMano,
          kcalDelleSedute: [
            ...(perGiorno[g] ?? const []).map((s) => s.kcal ?? 0),
            if (stimateDalTipo[g] != null) stimateDalTipo[g]!,
          ],
        );

        if (kcal > 0) fuori[g] = kcal;
      }

      return fuori;
    });

/// Le bruciate di **un** giorno.
final bruciateLocaliDelGiornoProvider = FutureProvider.autoDispose
    .family<int, DateTime>((ref, giorno) async {
      final per = await ref.watch(
        bruciateLocaliProvider(_etichetta(giorno)).future,
      );

      return per[_etichetta(giorno)] ?? 0;
    });

/// La dichiarazione a mano di un giorno, o `null` se non ce n'è.
///
/// ⚠️ **`null` e non `0`**: uno zero dichiarato è «oggi fermo» e vince sulla
/// stima; l'assenza è «non lo so» e lascia parlare le sedute. 🚨 È la stessa
/// distinzione del difetto O.D.4, e qui decide quanto qualcuno può mangiare.
final bruciateAManoDelGiornoProvider = FutureProvider.autoDispose
    .family<int?, DateTime>((ref, giorno) {
      ref.watch(revisioneAllenamentiProvider);

      return ref.watch(archivioSaluteProvider).bruciateAManoDel(giorno);
    });

/// `yyyy-mm-dd` **locale**.
///
/// 🚨 Non `toIso8601String()`: quello scriverebbe l'ora, e su un `DateTime` in
/// UTC scriverebbe pure il giorno sbagliato. È la stessa trappola che il 12/08
/// aveva fatto finire una cena nel giorno prima.
String _etichetta(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
