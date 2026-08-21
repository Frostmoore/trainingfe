import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/storage/archivio_salute.dart';
import 'package:training_companion/src/features/training/data/session_models.dart';
import 'package:training_companion/src/features/training/data/storico_unificato.dart';

/// Il raggruppamento dello storico — FASE 1-bis, 20/08/2026.
///
/// ── 🚨 Le due decisioni che questo file difende ────────────────────────────
///
/// > *«se i timeframes si sovrappongono allora è lo stesso allenamento […]
/// > esiste anche la possibilità che io fermi per sbaglio un allenamento sul
/// > telefono e lo faccia ripartire, anche in tal caso è lo stesso allenamento
/// > (a meno che non cambi proprio tipo)»*
///
/// **D-1bis/A** — basta la sovrapposizione, anche di un istante.
/// **D-1bis/B** — anche un buco breve, se il tipo non cambia.
///
/// ⚠️ **Un test qui è stato ROVESCIATO di proposito**: «due allenamenti che si
/// sfiorano restano due» era verde il 19/08 e oggi è falso. Non è una
/// regressione, è una decisione — ed è scritto qui perché nessuno lo «ripari».
void main() {
  DateTime alle(int ora, [int minuti = 0]) =>
      DateTime(2026, 8, 19, ora, minuti);

  WorkoutSession seduta({
    required int id,
    required DateTime inizio,
    int? durataMinuti = 60,
    bool aperta = false,
    int? kcal,
    bool aMano = false,
  }) => WorkoutSession(
    id: id,
    startedAt: inizio,
    endedAt: durataMinuti == null
        ? null
        : inizio.add(Duration(minutes: durataMinuti)),
    durationMinutes: durataMinuti,
    isOpen: aperta,
    kcal: kcal,
    // 💡 `kcal` è già il valore **che vale**: il server ci mette la
    // correzione a mano se c'è, altrimenti la stima. `kcalSource` dice solo
    // quale delle due storie raccontare.
    kcalSource: aMano ? 'manual' : 'estimate',
    sets: const [],
    photos: const [],
  );

  AllenamentoDaOrologio dalPolso({
    required int id,
    required DateTime inizio,
    int durataMinuti = 60,
    String tipo = 'STRENGTH_TRAINING',
    int? kcal = 400,
    bool nascosto = false,
    bool staccato = false,
  }) => AllenamentoDaOrologio(
    id: id,
    fonte: 'com.huami.watch.hmwatchmanager',
    tipo: tipo,
    iniziatoIl: inizio,
    finitoIl: inizio.add(Duration(minutes: durataMinuti)),
    kcal: kcal,
    nascosto: nascosto,
    staccato: staccato,
  );

  group('D-1bis/A — basta la sovrapposizione', () {
    /// 📌 Lo scenario testuale del committente: parto dall'app, faccio partire
    /// l'orologio, chiudo l'app, e dieci minuti dopo mi ricordo dell'orologio.
    test('lo scenario del committente fa UNA riga', () {
      final voci = StoricoUnificato.fondi(
        sessioni: [seduta(id: 1, inizio: alle(18), durataMinuti: 60)],
        dallOrologio: [dalPolso(id: 10, inizio: alle(18, 5), durataMinuti: 65)],
      );

      expect(voci, hasLength(1));
      expect(voci.single.sedute, hasLength(1));
      expect(voci.single.dalPolso, hasLength(1));
    });

    /// 🚨 **Lo scenario specchiato: l'orologio partito TARDI.**
    ///
    /// ⚠️ È il caso che con la soglia al 50% falliva — dieci minuti in comune su
    /// sessanta fanno il 17% — ed è lo stesso identico gesto, capitato
    /// all'inizio invece che alla fine.
    test('anche quando è l orologio a partire tardi', () {
      final voci = StoricoUnificato.fondi(
        sessioni: [seduta(id: 1, inizio: alle(18), durataMinuti: 60)],
        dallOrologio: [
          dalPolso(id: 10, inizio: alle(18, 50), durataMinuti: 60),
        ],
      );

      expect(voci, hasLength(1));
    });

    /// ══ 🚨 IL TEST ROVESCIATO ═══════════════════════════════════════════
    ///
    /// Il 19/08 questo caso doveva dare **due** righe, e il test si chiamava
    /// «due allenamenti che si sfiorano restano due». ⚠️ Oggi ne dà **una**, ed
    /// è una decisione presa sapendo il costo:
    ///
    /// > *«per i falsi accoppiamenti io non vedo un problema vero […] poi ci
    /// > mettiamo la possibilità di splittarli e via»*
    ///
    /// 💡 Chi in futuro lo trovasse «sbagliato»: la riparazione non è
    /// restringere la regola, è `staccato`.
    test('un minuto solo in comune basta — deciso, non subito', () {
      final voci = StoricoUnificato.fondi(
        sessioni: [seduta(id: 1, inizio: alle(18), durataMinuti: 60)],
        dallOrologio: [dalPolso(id: 10, inizio: alle(17), durataMinuti: 61)],
      );

      expect(voci, hasLength(1));
    });

    /// ⚠️ Ma **toccarsi non è sovrapporsi**: una che finisce alle 18:00 e una
    /// che comincia alle 18:00 non hanno nessun istante in comune. Restano
    /// insieme solo grazie alla regola del buco, che qui vale zero minuti.
    test('e chi si tocca senza sovrapporsi passa dalla regola del buco', () {
      final voci = StoricoUnificato.fondi(
        sessioni: [seduta(id: 1, inizio: alle(17), durataMinuti: 60)],
        // Stesso istante di fine/inizio: buco zero, tipi compatibili.
        dallOrologio: [dalPolso(id: 10, inizio: alle(18), durataMinuti: 30)],
      );

      expect(voci, hasLength(1));
    });
  });

  group('D-1bis/B — fermato per sbaglio e ripreso', () {
    /// 📌 *«fermi per sbaglio un allenamento sul telefono e lo faccia
    /// ripartire»*: due sedute consecutive, che non si sovrappongono affatto.
    test('due sedute a cinque minuti di distanza fanno una riga', () {
      final voci = StoricoUnificato.fondi(
        sessioni: [
          seduta(id: 1, inizio: alle(18), durataMinuti: 30),
          seduta(id: 2, inizio: alle(18, 35), durataMinuti: 25),
        ],
        dallOrologio: const [],
      );

      expect(voci, hasLength(1));
      expect(voci.single.sedute, hasLength(2));
    });

    /// 💡 E la durata è quella del **gruppo intero**, buchi compresi: è il tempo
    /// che ci hai messo, non quello col cronometro acceso.
    test('e la durata copre anche il buco', () {
      final voci = StoricoUnificato.fondi(
        sessioni: [
          seduta(id: 1, inizio: alle(18), durataMinuti: 30),
          seduta(id: 2, inizio: alle(18, 35), durataMinuti: 25),
        ],
        dallOrologio: const [],
      );

      expect(voci.single.durata.inMinutes, 60);
    });

    /// 🚨 *«a meno che non cambi proprio tipo»* — la clausola del committente.
    test('ma due tipi diversi nel buco restano due', () {
      final voci = StoricoUnificato.fondi(
        sessioni: const [],
        dallOrologio: [
          dalPolso(id: 10, inizio: alle(18), durataMinuti: 30, tipo: 'RUNNING'),
          dalPolso(
            id: 11,
            inizio: alle(18, 35),
            durataMinuti: 25,
            tipo: 'BIKING',
          ),
        ],
      );

      expect(voci, hasLength(2));
    });

    /// ⚠️ Un buco lungo separa comunque: pesi alle 17 e corsa alle 19 sono due
    /// allenamenti, ed è l'errore opposto che non deve tornare.
    test('un buco di un ora separa, tipo o non tipo', () {
      final voci = StoricoUnificato.fondi(
        sessioni: [seduta(id: 1, inizio: alle(17), durataMinuti: 60)],
        dallOrologio: [dalPolso(id: 10, inizio: alle(19), durataMinuti: 60)],
      );

      expect(voci, hasLength(2));
    });

    /// 🚨 **La transitività**, che è la ragione per cui non bastano le coppie:
    /// i due estremi non si sfiorano affatto, e stanno insieme perché c'è
    /// qualcosa in mezzo che li lega.
    test('la catena tiene insieme anche gli estremi che non si toccano', () {
      final voci = StoricoUnificato.fondi(
        sessioni: [
          seduta(id: 1, inizio: alle(18), durataMinuti: 20),
          // 19:10 → 19:40: con la prima non ha niente in comune, e il buco con
          // lei e' di 70 minuti.
          seduta(id: 2, inizio: alle(19, 10), durataMinuti: 30),
        ],
        // L'orologio copre il mezzo e lega le due.
        dallOrologio: [
          dalPolso(id: 10, inizio: alle(18, 10), durataMinuti: 65),
        ],
      );

      expect(voci, hasLength(1));
      expect(voci.single.sedute, hasLength(2));
    });

    /// ⚠️ **La catena si può riaprire**, ed è il motivo per cui serve un
    /// union-find e non una passata sola: la bici in mezzo rompe la contiguità
    /// di tipo, ma le due corse distano sei minuti.
    test('due corse separate da una bici restano legate fra loro', () {
      final voci = StoricoUnificato.fondi(
        sessioni: const [],
        dallOrologio: [
          dalPolso(id: 10, inizio: alle(18), durataMinuti: 30, tipo: 'RUNNING'),
          dalPolso(
            id: 11,
            inizio: alle(18, 32),
            durataMinuti: 3,
            tipo: 'BIKING',
          ),
          dalPolso(
            id: 12,
            inizio: alle(18, 36),
            durataMinuti: 24,
            tipo: 'RUNNING',
          ),
        ],
      );

      final corse = voci.where((v) => v.dalPolso.length == 2);

      expect(corse, hasLength(1), reason: 'Le due corse stanno insieme…');
      expect(voci, hasLength(2), reason: '…e la bici resta per conto suo.');
    });
  });

  group('D-1bis/C — chi resta fuori da ogni gruppo', () {
    /// 🚨 La contropartita della regola larga: senza, un raggruppamento
    /// sbagliato farebbe sparire un allenamento vero.
    test('uno staccato non si unisce a niente', () {
      final voci = StoricoUnificato.fondi(
        sessioni: [seduta(id: 1, inizio: alle(18), durataMinuti: 60)],
        dallOrologio: [dalPolso(id: 10, inizio: alle(18, 5), staccato: true)],
      );

      expect(voci, hasLength(2));
    });

    /// ⚠️ La durata di una seduta aperta cresce a ogni secondo: raggrupparla
    /// vorrebbe dire prendere una decisione che il minuto dopo può cambiare — e
    /// nel frattempo avrebbe già inghiottito la riga di qualcun altro.
    test('una seduta ancora aperta non assorbe niente', () {
      final voci = StoricoUnificato.fondi(
        sessioni: [seduta(id: 1, inizio: alle(18), aperta: true)],
        dallOrologio: [dalPolso(id: 10, inizio: alle(18, 5))],
      );

      expect(voci, hasLength(2));
    });

    /// ⚠️ Senza fine e senza durata non c'è un intervallo, e inventarglielo
    /// vorrebbe dire attaccarle l'allenamento sbagliato.
    test('una seduta senza durata non assorbe niente', () {
      final voci = StoricoUnificato.fondi(
        sessioni: [seduta(id: 1, inizio: alle(18), durataMinuti: null)],
        dallOrologio: [dalPolso(id: 10, inizio: alle(18, 5))],
      );

      expect(voci, hasLength(2));
    });

    test('i nascosti non compaiono affatto', () {
      final voci = StoricoUnificato.fondi(
        sessioni: const [],
        dallOrologio: [dalPolso(id: 10, inizio: alle(7), nascosto: true)],
      );

      expect(voci, isEmpty);
    });
  });

  group('Quello che la riga sa dire', () {
    /// 💡 Il caso per cui la FASE 1.8 esiste: una corsa fatta senza toccare il
    /// telefono. Prima non compariva da nessuna parte.
    test('una corsa senza seduta è una riga sua', () {
      final voci = StoricoUnificato.fondi(
        sessioni: const [],
        dallOrologio: [dalPolso(id: 10, inizio: alle(7), tipo: 'RUNNING')],
      );

      expect(voci.single.soloDalPolso, isTrue);
      expect(voci.single.dalPolso.single.tipo, 'RUNNING');
    });

    /// 🚨 Le calorie **attive** si sommano su tutto il gruppo: se l'orologio è
    /// stato fermato e ripreso, i due tratti sono lo stesso allenamento.
    test('le calorie si sommano sui tratti del gruppo', () {
      final voci = StoricoUnificato.fondi(
        sessioni: const [],
        dallOrologio: [
          dalPolso(id: 10, inizio: alle(18), durataMinuti: 30, kcal: 250),
          dalPolso(id: 11, inizio: alle(18, 35), durataMinuti: 25, kcal: 200),
        ],
      );

      expect(voci.single.kcalDalPolso, 450);
    });

    /// ══ 🚨 Anche le SEDUTE si sommano ═══════════════════════════════════
    ///
    /// 📌 Trovato dal committente il 20/08 chiedendo *«le calorie come le
    /// calcola?»*. ⚠️ I tratti dell'orologio si sommavano e le sedute no — si
    /// prendeva `sedute.first` — quindi chi si fermava a metà si vedeva contare
    /// **metà allenamento**, senza nessun segnale che mancasse qualcosa.
    test('anche le calorie delle sedute si sommano sul gruppo', () {
      final voci = StoricoUnificato.fondi(
        sessioni: [
          seduta(id: 1, inizio: alle(18), durataMinuti: 30, kcal: 180),
          seduta(id: 2, inizio: alle(18, 35), durataMinuti: 25, kcal: 150),
        ],
        dallOrologio: const [],
      );

      expect(voci.single.kcalDalleSedute, 330);
    });

    /// 🚨 Basta **una** seduta corretta a mano perché il gruppo lo sia: chi ha
    /// scritto un numero l'ha scritto apposta. ⚠️ Guardare solo la prima
    /// vorrebbe dire ignorare in silenzio una correzione fatta sul secondo
    /// tratto.
    test('basta un tratto corretto a mano perché il gruppo lo sia', () {
      final voci = StoricoUnificato.fondi(
        sessioni: [
          seduta(id: 1, inizio: alle(18), durataMinuti: 30, kcal: 180),
          seduta(
            id: 2,
            inizio: alle(18, 35),
            durataMinuti: 25,
            kcal: 900,
            aMano: true,
          ),
        ],
        dallOrologio: const [],
      );

      expect(voci.single.kcalCorrettaAMano, isTrue);
      expect(voci.single.kcalDalleSedute, 1080);
    });

    test('e senza nessuna correzione il gruppo non è a mano', () {
      final voci = StoricoUnificato.fondi(
        sessioni: [
          seduta(id: 1, inizio: alle(18), durataMinuti: 30, kcal: 180),
        ],
        dallOrologio: const [],
      );

      expect(voci.single.kcalCorrettaAMano, isFalse);
    });

    /// ⚠️ «Non lo so» e «non hai bruciato niente» sono due cose diverse.
    test('senza calorie da nessun tratto resta null, non zero', () {
      final voci = StoricoUnificato.fondi(
        sessioni: const [],
        dallOrologio: [dalPolso(id: 10, inizio: alle(18), kcal: null)],
      );

      expect(voci.single.kcalDalPolso, isNull);
    });

    /// 🚨 La seduta principale è la **prima**: è quella che la persona ha
    /// cominciato, e le altre del gruppo sono riprese di quella.
    test('la seduta principale è la prima cominciata', () {
      final voci = StoricoUnificato.fondi(
        sessioni: [
          seduta(id: 2, inizio: alle(18, 35), durataMinuti: 25),
          seduta(id: 1, inizio: alle(18), durataMinuti: 30),
        ],
        dallOrologio: const [],
      );

      expect(voci.single.seduta!.id, 1);
    });
  });

  /// 🚨 Lo storico si legge dal più recente: è la domanda che ci si fa
  /// aprendolo.
  test('tutto esce dal più recente', () {
    final voci = StoricoUnificato.fondi(
      sessioni: [seduta(id: 1, inizio: alle(9), durataMinuti: 30)],
      dallOrologio: [
        dalPolso(id: 10, inizio: alle(7), durataMinuti: 30),
        dalPolso(id: 11, inizio: alle(20), durataMinuti: 30),
      ],
    );

    expect(voci.map((v) => v.quando).toList(), [alle(20), alle(9), alle(7)]);
  });
}
