import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/storage/archivio_salute.dart';
import 'package:training_companion/src/features/training/data/session_models.dart';
import 'package:training_companion/src/features/training/data/storico_unificato.dart';
import 'package:training_companion/src/features/training/storico_unificato_controller.dart';

/// Rimuovere un allenamento — 3b-B.20.2, 25/08/2026.
///
/// 📌 *«possibilità di rimuovere un allenamento»*.
void main() {
  VoceStorico voce({
    List<WorkoutSession> sedute = const [],
    int? kcalDalPolso,
  }) => VoceStorico(
    sedute: sedute,
    dalPolso: [
      AllenamentoDaOrologio(
        id: 1,
        fonte: 'com.huami.watch.hmwatchmanager',
        tipo: 'RUNNING',
        iniziatoIl: DateTime(2026, 8, 25, 17),
        finitoIl: DateTime(2026, 8, 25, 18),
        kcal: kcalDalPolso,
        nascosto: false,
        staccato: false,
      ),
    ],
  );

  WorkoutSession seduta({required int quanteSerie}) => WorkoutSession(
    id: 7,
    startedAt: DateTime(2026, 8, 25, 17),
    isOpen: false,
    photos: const [],
    sets: [
      for (var i = 0; i < quanteSerie; i++)
        LoggedSet(
          id: i,
          exerciseId: 1,
          exerciseName: 'Panca',
          setNumber: i + 1,
          reps: 8,
          weight: 40,
        ),
    ],
  );

  group('⚠️ la conferma dice cosa si porta via', () {
    /// 🚨 **Si contano le cose vere.** «12 serie registrate» ferma la mano,
    /// «questo allenamento» no. ⛔ Una cancellazione che non dice cosa cancella
    /// è la cosa che il 24/08 ha fatto sparire due esercizi.
    test('le serie registrate si contano', () {
      final frase = cosaSiPortaViaLaRimozione(
        voce(sedute: [seduta(quanteSerie: 12)]),
      );

      expect(frase, contains('12 serie registrate'));
    });

    test('e al singolare si dice al singolare', () {
      final frase = cosaSiPortaViaLaRimozione(
        voce(sedute: [seduta(quanteSerie: 1)]),
      );

      expect(frase, contains('1 serie registrata'));
    });

    /// ⚠️ Le calorie escono dal bilancio della giornata, e chi sta contando
    /// quanto ha mangiato deve saperlo prima, non dopo.
    test('e anche le calorie che escono dal bilancio', () {
      final frase = cosaSiPortaViaLaRimozione(voce(kcalDalPolso: 430));

      expect(frase, contains('430 kcal'));
    });

    /// 💡 Senza niente da perdere non si spaventa nessuno: si dice cosa succede
    /// e basta.
    test('e senza niente da perdere non si inventa una minaccia', () {
      expect(
        cosaSiPortaViaLaRimozione(voce()),
        'Sparirà dallo storico.',
      );
    });
  });

  group('🗑️ e la rimozione', () {
    late ArchivioSalute archivio;
    late ProviderContainer contenitore;

    setUp(() {
      archivio = ArchivioSalute.inMemoria();
      contenitore = ProviderContainer();
      addTearDown(contenitore.dispose);
      addTearDown(archivio.close);
    });

    /// 🚨 **Le righe dell'orologio si nascondono, non si cancellano.** Il dato
    /// vero sta in Health Connect: una `DELETE` verrebbe annullata dalla
    /// prossima sincronizzazione, che la reinserirebbe. ⛔ Chi la togliesse così
    /// se la vedrebbe tornare da sola dopo mezz'ora.
    test('l\'allenamento del polso viene nascosto, non cancellato', () async {
      await archivio.scriviAllenamenti([
        AllenamentoDaOrologio(
          id: 0,
          fonte: 'com.huami.watch.hmwatchmanager',
          tipo: 'RUNNING',
          iniziatoIl: DateTime(2026, 8, 25, 17),
          finitoIl: DateTime(2026, 8, 25, 18),
          nascosto: false,
          staccato: false,
        ),
      ]);

      final prima = await archivio.allenamentiDellOrologio();

      expect(prima, hasLength(1));

      await archivio.nascondiAllenamento(prima.first.id, nascosto: true);

      final dopo = await archivio.allenamentiDellOrologio();

      /*
       * ⚠️ **La riga c'è ancora, ed è il punto.** `allenamentiDellOrologio()`
       * non filtra: il filtro sta in `StoricoUnificato.fondi`. 🚨 La riga deve
       * restare in archivio proprio perché la prossima sincronizzazione la
       * ritrovi già lì e non ne crei una nuova — è `insertOrIgnore` su
       * `(fonte, iniziatoIl)` a fare da guardia, e senza la riga la guardia non
       * ha niente da riconoscere.
       */
      expect(dopo, hasLength(1), reason: 'la riga resta, o tornerebbe da sola');
      expect(dopo.first.nascosto, isTrue);

      expect(
        StoricoUnificato.fondi(sessioni: const [], dallOrologio: dopo),
        isEmpty,
        reason: 'e lo storico non la mostra più',
      );
    });
  });
}
