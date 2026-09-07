/// Cosa scrive **davvero** l'orologio, campione per campione — 07/09/2026.
///
/// ══ 🎯 LA DOMANDA A CUI RISPONDE, E BASTA ═════════════════════════════════
///
/// 📌 Il committente, il 06/09: *«secondo me le calorie attive le calcola
/// l'orologio (oggi dice che ne ho spese 269, quindi da qualche parte sono)»*.
///
/// ⛔ **Il codice dice il contrario**, con «verificato» accanto e la data del
/// 26/08: in `bruciate_dalle_sedute.dart` sta scritto che sullo Zebb scrive
/// *«solo la finestra della sessione, e nient'altro in tutto il giorno»*.
///
/// 🚨 **Uno dei due è vecchio, e la differenza decide un pezzo di modello**: se
/// l'orologio scrive solo dentro l'allenamento, dopo la sottrazione resta zero e
/// i passi sono l'**unico** segnale di movimento quotidiano. Se scrive tutto il
/// giorno, la sottrazione che esiste già basta.
///
/// ══ ⚠️ PERCHE' NON SI USA `DiagnosticaSalute` ═════════════════════════════
///
/// Quella racconta **tutto** quello che Health Connect contiene, e per farlo si
/// porta dietro **diciannove permessi temporanei** che vanno messi e poi tolti a
/// mano. ⛔ Qui non servono: `ACTIVE_ENERGY_BURNED`, `STEPS` e `WORKOUT` l'app
/// li dichiara già per conto suo.
///
/// 💡 Meno permessi si chiedono, meno se ne dimentica in giro uno.
///
/// ══ 🔬 COME SI LANCIA ═════════════════════════════════════════════════════
///
///     flutter build apk --release --dart-define=ENV=staging \
///         --dart-define=DIAGNOSTICA=attive
///     bash memory/scripts/installa-app.sh
///     adb logcat -c && adb shell monkey -p com.smp.mytrainingcompanion 1
///     adb logcat -d | grep "ATTIVE|"
///
/// ⚠️ **Poi si ricompila pulito**: nelle build normali `accesa` è `false` e il
/// compilatore toglie tutto, ma la riga in `app.dart` resta — e una diagnostica
/// dimenticata è codice che nessuno rilegge.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';

import '../profile/corpo_controller.dart';
import '../profile/profile_controller.dart';
import '../training/calorie_dal_cammino.dart';
import 'health_controller.dart';

class SondaDelleAttive {
  const SondaDelleAttive(this._ref, [this._salute]);

  /// 🚨 **Serve a leggere i dati VERI della persona**, non dei letterali.
  ///
  /// 📌 Il committente, il 07/09: *«ma perché? Cioè nell'app i dati ci sono
  /// tutti»*. ⛔ Aveva ragione: una verifica fatta con un peso inventato non è
  /// una verifica, ed è esattamente l'errore che questa sonda serve a non
  /// rifare.
  final WidgetRef _ref;

  final Health? _salute;

  /// 🔬 Accesa solo con `--dart-define=DIAGNOSTICA=attive`.
  static const accesa = String.fromEnvironment('DIAGNOSTICA') == 'attive';

  /// Quanti giorni indietro guardare.
  ///
  /// 💡 Due: oggi e ieri. ⚠️ Oggi da solo non basta — se il committente non si è
  /// ancora mosso, l'assenza di campioni non distingue «l'orologio non scrive»
  /// da «non hai camminato».
  static const giorni = 2;

  Future<void> racconta() async {
    if (!accesa) return;

    final salute = _salute ?? Health();

    final adesso = DateTime.now();
    final da = DateTime(
      adesso.year,
      adesso.month,
      adesso.day,
    ).subtract(const Duration(days: giorni - 1));

    _riga('══════ dal ${_data(da)} al ${_data(adesso)} ══════');

    /*
     * 🚨 **I permessi si chiedono comunque**, anche se il manifest li dichiara:
     * l'elenco lo costruisce il pacchetto dai **tipi**, e senza questa chiamata
     * la lettura torna vuota senza nessun errore — che è il sintomo più
     * ingannevole che ci sia.
     */
    const tipi = [
      HealthDataType.ACTIVE_ENERGY_BURNED,
      HealthDataType.STEPS,
      HealthDataType.WORKOUT,

      /*
       * 🆕 **Il battito, e non è curiosità** — 07/09/2026.
       *
       * 🚨 Il TEI si calcola sui **minuti passati a una certa frequenza
       * cardiaca**: senza campioni fitti di battito non esiste, e costruirlo
       * prima di saperlo vorrebbe dire scrivere un indice che mostrerà sempre
       * «dati insufficienti».
       *
       * ⚠️ Serve anche il battito **a riposo**: è il fondo della frequenza di
       * riserva, e senza quello la percentuale non si calcola.
       */
      HealthDataType.HEART_RATE,
      HealthDataType.RESTING_HEART_RATE,
    ];

    final concessi = await salute.hasPermissions(tipi) ?? false;

    if (!concessi) {
      _riga('permessi da concedere — sblocca il telefono');

      await salute.requestAuthorization(tipi);
    }

    _riga('permessi: ${await salute.hasPermissions(tipi)}');

    // ── Prima le sessioni: sono le finestre da confrontare ──────────────────
    final sessioni = <DateTime, DateTime>{};

    for (final w in await _leggi(salute, HealthDataType.WORKOUT, da, adesso)) {
      sessioni[w.dateFrom] = w.dateTo;

      _riga(
        'SESSIONE ${_data(w.dateFrom)} ${_ora(w.dateFrom)}→${_ora(w.dateTo)} '
        '· ${w.sourceName}',
      );
    }

    if (sessioni.isEmpty) _riga('SESSIONE nessuna nei $giorni giorni');

    // ── Poi le calorie attive, una per una ─────────────────────────────────
    //
    // 🚨 **Campione per campione e non il totale**: il totale non dice DOVE
    //    cadono, e la domanda è esattamente quella.
    await _campioni(
      salute,
      HealthDataType.ACTIVE_ENERGY_BURNED,
      'ATTIVE',
      da,
      adesso,
      sessioni,
    );

    await _campioni(
      salute,
      HealthDataType.STEPS,
      'PASSI',
      da,
      adesso,
      sessioni,
    );

    /*
     * 💡 **Il battito non si somma**: sommare 319 battiti darebbe un numero
     * senza significato. Qui interessa **quanti campioni** ci sono e **come sono
     * distribuiti**, che è quello che decide se il TEI è calcolabile.
     */
    await _distribuzione(
      salute,
      HealthDataType.HEART_RATE,
      'BATTITO',
      da,
      adesso,
    );
    await _distribuzione(
      salute,
      HealthDataType.RESTING_HEART_RATE,
      'RIPOSO',
      da,
      adesso,
    );

    await _ilContoDellApp(adesso);

    _riga('══════ fine ══════');
  }

  Future<void> _campioni(
    Health salute,
    HealthDataType tipo,
    String etichetta,
    DateTime da,
    DateTime a,
    Map<DateTime, DateTime> sessioni,
  ) async {
    final punti = await _leggi(salute, tipo, da, a);

    if (punti.isEmpty) {
      _riga('$etichetta nessun campione');

      return;
    }

    var dentro = 0.0;
    var fuori = 0.0;
    final perOra = <String, double>{};

    for (final p in punti) {
      final v = p.value is NumericHealthValue
          ? (p.value as NumericHealthValue).numericValue.toDouble()
          : 0.0;

      /*
       * ⚠️ **Basta un istante di sovrapposizione** perché un campione sia
       * «dentro» una sessione: è la stessa regola larga di D-1bis/A. 🚨 Con un
       * confronto stretto, un campione a cavallo dell'inizio risulterebbe fuori
       * e falserebbe proprio il numero che si sta cercando.
       */
      final eDentro = sessioni.entries.any(
        (s) => p.dateFrom.isBefore(s.value) && p.dateTo.isAfter(s.key),
      );

      eDentro ? dentro += v : fuori += v;

      final chiave = '${_data(p.dateFrom)} ${_due(p.dateFrom.hour)}';
      perOra[chiave] = (perOra[chiave] ?? 0) + v;
    }

    _riga(
      '$etichetta ${punti.length} campioni · fonti: '
      '${punti.map((p) => p.sourceName).toSet().join(", ")}',
    );

    /*
     * ══ 🚨 PER SORGENTE, E NON SOLO IL TOTALE ═════════════════════════════
     *
     * ⛔ La prima versione sommava tutto e basta: 17.010 passi in due giorni,
     * da **due** sorgenti che contano **gli stessi passi**. Quel numero era il
     * doppio del vero, e nessuno se ne sarebbe accorto guardandolo.
     *
     * 💡 `ArchivioSalute.passiDi()` fa la cosa giusta — somma per sorgente e
     * tiene **la più alta** — ma questa sonda serve proprio a controllare che
     * la cosa giusta sia quella: stampare il totale grezzo nascondeva la
     * domanda invece di rispondere.
     */
    final perSorgente = <String, double>{};

    for (final p in punti) {
      final v = p.value is NumericHealthValue
          ? (p.value as NumericHealthValue).numericValue.toDouble()
          : 0.0;

      perSorgente[p.sourceName] = (perSorgente[p.sourceName] ?? 0) + v;
    }

    for (final s in perSorgente.entries) {
      _riga('$etichetta  «${s.key}» → ${s.value.round()}');
    }

    /*
     * 🎯 **È questa la riga che risponde alla domanda.** Se «fuori» è ~0
     * l'orologio scrive solo dentro gli allenamenti; se è un numero vero, il
     * movimento quotidiano c'è e la sottrazione basta.
     */
    _riga(
      '$etichetta dentro le sessioni: ${dentro.round()} · '
      'FUORI: ${fuori.round()}',
    );

    // 💡 Ora per ora: fa vedere **quando** cadono, non solo quanti sono.
    final ore = perOra.keys.toList()..sort();

    for (final o in ore) {
      _riga('$etichetta  $o:00 → ${perOra[o]!.round()}');
    }
  }

  /// Il numero che l'app **mostrerebbe**, con i dati veri della persona.
  ///
  /// ══ 🎯 E' QUESTO CHE SI CONFRONTA CON L'OROLOGIO ══════════════════════
  ///
  /// 🚨 Non una formula riempita a mano con dei numeri plausibili: **peso dalla
  /// bilancia, altezza dal profilo, passi dall'archivio**, cioè esattamente
  /// quello che `caloriePassiDelGiornoProvider` userà.
  ///
  /// 💡 Se questo numero e quello dell'orologio si somigliano, la stima è
  /// verificata. Se non si somigliano, si sa **di quanto** e si sa **perché**,
  /// perché tutti gli ingredienti sono stampati qui accanto.
  Future<void> _ilContoDellApp(DateTime giorno) async {
    final archivio = _ref.read(archivioSaluteProvider);

    final tutti = await archivio.passiDi(giorno);
    final fuori = await archivio.passiFuoriDagliAllenamenti(giorno);

    final kg = _ref.read(corpoOggiProvider).valueOrNull?.weightKg;
    final cm = _ref.read(profileProvider).valueOrNull?.heightCm?.toDouble();

    _riga('── il conto che farebbe l\'app ──');
    _riga('  peso     ${kg ?? "(non lo sa)"}');
    _riga('  altezza  ${cm ?? "(non lo sa)"}');

    /*
     * ⚠️ **Due numeri di passi, e sono diversi apposta**: quello che si mostra
     * comprende i passi fatti allenandosi, quello che stima le calorie no —
     * altrimenti conterebbe due volte lo stesso movimento.
     */
    _riga('  passi    $tutti in tutto · $fuori fuori dagli allenamenti');

    _riga(
      '  🎯 stima  ${CalorieDalCammino.kcal(passi: fuori, pesoKg: kg, altezzaCm: cm)} kcal'
      '  ← confronta con quello che dice l\'orologio',
    );
  }

  /// Quanti campioni, ogni quanto, e in che intervallo di valori.
  ///
  /// 🚨 **La densità è il numero che conta.** Un battito al giorno non permette
  /// di calcolare niente; uno ogni cinque minuti sì.
  Future<void> _distribuzione(
    Health salute,
    HealthDataType tipo,
    String etichetta,
    DateTime da,
    DateTime a,
  ) async {
    final punti = await _leggi(salute, tipo, da, a);

    if (punti.isEmpty) {
      _riga('$etichetta nessun campione');

      return;
    }

    final valori =
        punti
            .map(
              (p) => p.value is NumericHealthValue
                  ? (p.value as NumericHealthValue).numericValue.toDouble()
                  : 0.0,
            )
            .where((v) => v > 0)
            .toList()
          ..sort();

    final minuti = a.difference(da).inMinutes;

    _riga(
      '$etichetta ${punti.length} campioni · uno ogni '
      '${(minuti / punti.length).toStringAsFixed(1)} min · fonti: '
      '${punti.map((p) => p.sourceName).toSet().join(", ")}',
    );

    if (valori.isNotEmpty) {
      _riga(
        '$etichetta  min ${valori.first.round()} · '
        'mediana ${valori[valori.length ~/ 2].round()} · '
        'max ${valori.last.round()}',
      );
    }
  }

  /// ⚠️ Un tipo che il telefono non ha non deve fermare gli altri: si torna
  /// vuoto e si va avanti. 🚨 Un'eccezione qui farebbe sembrare che la sonda non
  /// sia partita.
  Future<List<HealthDataPoint>> _leggi(
    Health salute,
    HealthDataType tipo,
    DateTime da,
    DateTime a,
  ) async {
    try {
      return await salute.getHealthDataFromTypes(
        types: [tipo],
        startTime: da,
        endTime: a,
      );
    } on Object catch (e) {
      _riga('${tipo.name} ERRORE: $e');

      return const [];
    }
  }

  String _data(DateTime d) => '${_due(d.month)}-${_due(d.day)}';

  String _ora(DateTime d) => '${_due(d.hour)}:${_due(d.minute)}';

  String _due(int n) => n.toString().padLeft(2, '0');

  /// ⛔ `print` e non `dart:developer.log`: in release il secondo è **inerte**,
  /// e il risultato sarebbe zero righe — indistinguibile da «non è partita».
  // ignore: avoid_print
  void _riga(String testo) => print('ATTIVE| $testo');
}
