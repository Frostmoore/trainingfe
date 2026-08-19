import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/storage/archivio_salute.dart';
import 'package:training_companion/src/features/training/data/session_models.dart';
import 'package:training_companion/src/features/training/data/storico_unificato.dart';

/// La fusione dello storico — FASE 1.10, 20/08/2026.
///
/// ── 🚨 Cosa difende questo file ────────────────────────────────────────────
///
/// Che lo stesso allenamento non venga contato due volte. Chi si allena in
/// palestra **con l'app aperta e l'orologio al polso** produce due
/// registrazioni della stessa ora: senza la regola, la settimana ne conta il
/// doppio e il numero in cima allo storico diventa una bugia.
///
/// ⚠️ E che l'errore opposto non succeda: due allenamenti **davvero** diversi
/// che si sfiorano — i pesi e poi subito la corsa — devono restare due.
void main() {
  DateTime alle(int ora, int minuti) => DateTime(2026, 8, 19, ora, minuti);

  WorkoutSession seduta({
    required int id,
    required DateTime inizio,
    int? durataMinuti = 60,
    bool aperta = false,
  }) =>
      WorkoutSession(
        id: id,
        startedAt: inizio,
        endedAt: durataMinuti == null ? null : inizio.add(Duration(minutes: durataMinuti)),
        durationMinutes: durataMinuti,
        isOpen: aperta,
        sets: const [],
        photos: const [],
      );

  AllenamentoDaOrologio dalPolso({
    required int id,
    required DateTime inizio,
    int durataMinuti = 60,
    String tipo = 'STRENGTH_TRAINING',
    bool nascosto = false,
  }) =>
      AllenamentoDaOrologio(
        id: id,
        fonte: 'com.huami.watch.hmwatchmanager',
        tipo: tipo,
        iniziatoIl: inizio,
        finitoIl: inizio.add(Duration(minutes: durataMinuti)),
        nascosto: nascosto,
      );

  group('Il doppio conteggio', () {
    /// 🚨 Il caso vero, misurato sul telefono il 19/08: una seduta di pesi
    /// registrata dal player mentre l'Amazfit registrava la stessa ora.
    test('una seduta e il suo gemello dal polso fanno UNA riga', () {
      final voci = StoricoUnificato.fondi(
        sessioni: [seduta(id: 1, inizio: alle(17, 46))],
        dallOrologio: [dalPolso(id: 10, inizio: alle(17, 46), durataMinuti: 62)],
      );

      expect(voci, hasLength(1));
      expect(voci.single, isA<VoceSeduta>());
      expect((voci.single as VoceSeduta).orologio, isNotNull);
    });

    /// 💡 Non si nasconde: si **attacca**. Il player sa quali esercizi hai
    /// fatto, l'orologio quanto ti è costato — e la riga li tiene insieme.
    test('e il dato dell orologio resta consultabile', () {
      final voci = StoricoUnificato.fondi(
        sessioni: [seduta(id: 1, inizio: alle(17, 46))],
        dallOrologio: [dalPolso(id: 10, inizio: alle(17, 50))],
      );

      expect((voci.single as VoceSeduta).orologio!.id, 10);
    });

    /// ⚠️ L'errore opposto, altrettanto grave: i pesi e **poi** la corsa sono
    /// due allenamenti, e devono restare due righe.
    test('due allenamenti che si sfiorano restano due', () {
      final voci = StoricoUnificato.fondi(
        sessioni: [seduta(id: 1, inizio: alle(17, 0), durataMinuti: 60)],
        // Comincia a 17:55: dieci minuti in comune su sessanta, cioè il 17%.
        dallOrologio: [dalPolso(id: 10, inizio: alle(17, 55), durataMinuti: 40)],
      );

      expect(voci, hasLength(2));
    });

    /// 🚨 Senza questo vincolo una seduta lunga e una corta sovrapposte se lo
    /// prenderebbero **entrambe**, e la stessa ora comparirebbe due volte.
    test('un allenamento del polso si attacca a una sola seduta', () {
      final voci = StoricoUnificato.fondi(
        sessioni: [
          seduta(id: 1, inizio: alle(17, 0), durataMinuti: 60),
          seduta(id: 2, inizio: alle(17, 10), durataMinuti: 50),
        ],
        dallOrologio: [dalPolso(id: 10, inizio: alle(17, 5), durataMinuti: 55)],
      );

      final conGemello = voci.whereType<VoceSeduta>().where((v) => v.orologio != null);

      expect(conGemello, hasLength(1));
      expect(voci, hasLength(2), reason: 'Nessuna riga in più: il polso è stato assorbito.');
    });
  });

  group('Quello che esiste solo grazie all orologio', () {
    /// 💡 Il caso per cui questa fase esiste: una corsa fatta senza toccare il
    /// telefono. Prima di oggi non compariva da nessuna parte.
    test('una corsa senza seduta diventa una riga sua', () {
      final voci = StoricoUnificato.fondi(
        sessioni: const [],
        dallOrologio: [dalPolso(id: 10, inizio: alle(7, 0), tipo: 'RUNNING')],
      );

      expect(voci.single, isA<VoceOrologio>());
      expect((voci.single as VoceOrologio).allenamento.tipo, 'RUNNING');
    });

    test('i nascosti non compaiono', () {
      final voci = StoricoUnificato.fondi(
        sessioni: const [],
        dallOrologio: [dalPolso(id: 10, inizio: alle(7, 0), nascosto: true)],
      );

      expect(voci, isEmpty);
    });
  });

  group('I casi che non si accoppiano mai', () {
    /// ⚠️ `isOpen` vuol dire che non è finita: la durata cresce a ogni secondo,
    /// e accoppiarla sarebbe una decisione che il minuto dopo può cambiare.
    test('una seduta ancora aperta non assorbe niente', () {
      final voci = StoricoUnificato.fondi(
        sessioni: [seduta(id: 1, inizio: alle(17, 46), aperta: true)],
        dallOrologio: [dalPolso(id: 10, inizio: alle(17, 46))],
      );

      expect(voci, hasLength(2));
    });

    /// ⚠️ Senza fine e senza durata non c'è un intervallo, e inventarglielo
    /// vorrebbe dire attaccarle l'allenamento sbagliato.
    test('una seduta senza durata non assorbe niente', () {
      final voci = StoricoUnificato.fondi(
        sessioni: [seduta(id: 1, inizio: alle(17, 46), durataMinuti: null)],
        dallOrologio: [dalPolso(id: 10, inizio: alle(17, 46))],
      );

      expect(voci, hasLength(2));
    });
  });

  /// 🚨 Lo storico si legge dal più recente: è la domanda che ci si fa
  /// aprendolo. Un ordinamento sbagliato qui si vede subito, ma solo su un
  /// telefono con dati veri — cioè tardi.
  test('tutto esce dal più recente', () {
    final voci = StoricoUnificato.fondi(
      sessioni: [seduta(id: 1, inizio: alle(9, 0))],
      dallOrologio: [
        dalPolso(id: 10, inizio: alle(7, 0)),
        dalPolso(id: 11, inizio: alle(20, 0)),
      ],
    );

    expect(
      voci.map((v) => v.quando).toList(),
      [alle(20, 0), alle(9, 0), alle(7, 0)],
    );
  });
}
