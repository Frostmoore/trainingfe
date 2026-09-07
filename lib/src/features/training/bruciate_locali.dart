import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/archivio_salute.dart';
import '../health/health_controller.dart';
import '../profile/corpo_controller.dart';
import '../profile/data/modello_calorie.dart';
import '../profile/livello_attivita.dart';
import '../profile/profile_controller.dart';
import 'calorie_dal_cammino.dart';
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

/// Le calorie del **cammino** di un giorno — 07/09/2026.
///
/// 🚨 **Esiste perché l'orologio non scrive le calorie attive.** La sonda del
/// 07/09 ha trovato zero campioni in due giorni: i 269 kcal che il committente
/// vede li calcola l'app dell'orologio e non li manda a Health Connect.
///
/// ⚠️ Usa i passi **fuori dagli allenamenti**: quelli fatti correndo hanno già
/// le loro calorie, e contarli anche qui li sommerebbe a se stessi.
///
/// ══ 🚨 E SOLO QUELLI SOPRA IL PROPRIO GRADINO — 08/09/2026 ════════════════
///
/// ⛔ **Fino all'08/09 sommava i passi interi**, sopra un TDEE che il cammino ce
/// l'ha già dentro: i gradini del modello «misurata» sono definiti **a passi al
/// giorno**, e il gradino si suggerisce leggendo i passi. 💡 La spiegazione
/// completa sta in [CalorieDalCammino.inEccesso].
///
/// ⚠️ **Zero in tutti i casi in cui non si sa**: modello «stima», gradino
/// `labour`, o nessuna scelta fatta. 🚨 Non è prudenza generica — è la stessa
/// regola di `bruciateExtraDelGiornoProvider`, che in «misurata» torna zero
/// *«perché lì entrano già tutte»*.
final caloriePassiDelGiornoProvider = FutureProvider.autoDispose
    .family<int, DateTime>((ref, giorno) async {
      ref.watch(revisioneAllenamentiProvider);

      /*
       * ⛔ **Fuori dal modello «misurata» non si stima niente**, e si esce
       * prima di leggere l'archivio: nel modello a stima il fattore contiene
       * già lo sport, e sommarci sopra qualunque cosa è il difetto del 26/08.
       */
      final modello = ref.watch(modelloCalorieProvider);

      if (modello != ModelloCalorie.misurata) return 0;

      final passi = await ref
          .watch(archivioSaluteProvider)
          .passiFuoriDagliAllenamenti(giorno);

      return CalorieDalCammino.kcal(
        passi: CalorieDalCammino.inEccesso(
          passi: passi,
          tettoDelGradino: ModelloCalorie.misurata
              .livello(ref.watch(livelloAttivitaProvider))
              ?.passiFinoA,
        ),
        pesoKg: ref.watch(corpoOggiProvider).valueOrNull?.weightKg,
        altezzaCm: ref.watch(profileProvider).valueOrNull?.heightCm?.toDouble(),
      );
    });

/// Le bruciate **stimate** da noi: le sedute più il cammino — 07/09/2026.
///
/// ══ 🚨 PERCHE' SI SOMMANO QUESTE DUE E NON LE ALTRE ═══════════════════════
///
/// ⛔ La catena di `BruciateDelGiorno` **sostituisce** invece di sommare, e per
/// un'ottima ragione: l'orologio che misura una giornata ha già dentro
/// l'allenamento che la nostra formula stima, e sommarli darebbe a chi si allena
/// il doppio del margine calorico.
///
/// 💡 Ma sedute e cammino sono **disgiunti per costruzione**: i passi sono
/// quelli **fuori** dalle sessioni. Sommarli non conta niente due volte, e
/// insieme sono «quello che stimiamo noi» — cioè un gradino solo della catena.
///
/// ⚠️ E stando sul gradino **più basso**, se un giorno arrivasse un orologio che
/// scrive le attive di tutta la giornata, quelle vincerebbero e questo numero
/// sparirebbe da solo. 🚨 È l'unico modo di aggiungere il cammino senza
/// rischiare di contarlo due volte su un altro telefono.
final bruciateStimateDelGiornoProvider = FutureProvider.autoDispose
    .family<int, DateTime>((ref, giorno) async {
      final sedute = await ref.watch(
        bruciateLocaliDelGiornoProvider(giorno).future,
      );

      final cammino = await ref.watch(
        caloriePassiDelGiornoProvider(giorno).future,
      );

      return sedute + cammino;
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
