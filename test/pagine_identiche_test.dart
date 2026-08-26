import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/storage/archivio_salute.dart';
import 'package:training_companion/src/features/training/data/session_models.dart';
import 'package:training_companion/src/features/training/data/storico_unificato.dart';

/// «IDENTICA» — 3b-C.4, 25/08/2026.
///
/// 📌 *«Ti avevo detto che la pagina di un allenamento dall'orologio a cui ho
/// associato una scheda doveva essere identica a un allenamento partito
/// dall'app. Questo significa che deve essere IDENTICA. Stesse cards, stesso
/// layout, stessi numeri, stesse cose»*.
///
/// ══ 🚨 COSA SI PUÒ DIFENDERE CON UN TEST, E COSA NO ═══════════════════════
///
/// ⛔ «Stesso layout» non si prova confrontando due schermate: sarebbe un test
/// che si rompe a ogni pixel. 💡 Quello che si può difendere è la **sostanza**:
/// che le due pagine chiedano gli stessi dati alla stessa forma, e che quella
/// forma risponda anche quando la provenienza è l'altra.
void main() {
  AllenamentoDaOrologio dalPolso({int? kcal, int? kcalCorrette}) =>
      AllenamentoDaOrologio(
        id: 1,
        fonte: 'com.huami.watch.hmwatchmanager',
        tipo: 'STRENGTH_TRAINING',
        iniziatoIl: DateTime(2026, 8, 25, 17),
        finitoIl: DateTime(2026, 8, 25, 18),
        kcal: kcal,
        kcalCorrette: kcalCorrette,
        nascosto: false,
        staccato: false,
        contaComeExtra: false,
      );

  WorkoutSession seduta({int? kcal, String? fonte}) => WorkoutSession(
    id: 7,
    startedAt: DateTime(2026, 8, 25, 17),
    isOpen: false,
    photos: const [],
    sets: const [],
    kcal: kcal,
    kcalSource: fonte,
  );

  group('🔥 le calorie si correggono da tutte e due le parti', () {
    /// ⛔ **Era il buco vero.** Sulla pagina di una seduta le calorie si
    /// correggevano da sempre; su quella del polso lo stesso riquadro avrebbe
    /// mostrato un numero che non si tocca. 🚨 Una card identica che non fa la
    /// stessa cosa è peggio di una card diversa: promette e non mantiene.
    test('una correzione sul polso vince sull\'orologio', () {
      final voce = VoceStorico(
        sedute: const [],
        dalPolso: [dalPolso(kcal: 900, kcalCorrette: 420)],
      );

      expect(voce.kcal, 420);
      expect(voce.kcalCorrettaAMano, isTrue);
    });

    test('e senza correzione vale quello che ha misurato l\'orologio', () {
      final voce = VoceStorico(
        sedute: const [],
        dalPolso: [dalPolso(kcal: 900)],
      );

      expect(voce.kcal, 900);
      expect(voce.kcalCorrettaAMano, isFalse);
    });

    /// 💡 La stessa domanda, dall'altra provenienza: la catena era già così, e
    /// non è cambiata.
    test('e sulle sedute funziona come prima', () {
      final voce = VoceStorico(
        sedute: [seduta(kcal: 350, fonte: 'manual')],
        dalPolso: [dalPolso(kcal: 900)],
      );

      expect(
        voce.kcal,
        350,
        reason: 'la correzione a mano vince sull\'orologio',
      );
      expect(voce.kcalCorrettaAMano, isTrue);
    });

    /// 🚨 **Il caso che il vecchio codice sbagliava.** Con `kcalCorrettaAMano`
    /// vero ma nessuna seduta, la vecchia catena tornava `null`: una pagina che
    /// diceva «—» dopo che ci avevi appena scritto un numero.
    test('una correzione senza sedute non torna a mani vuote', () {
      final voce = VoceStorico(
        sedute: const [],
        dalPolso: [dalPolso(kcalCorrette: 500)],
      );

      expect(voce.kcal, 500);
    });
  });

  group('🏷️ e il nome è lo stesso da tutte e due le parti', () {
    /// 🚨 **La scheda vince su tutto**: «Giorno 1» dice più di «Pesi», e se
    /// l'hai associata tu è la risposta che hai dato. È il caso della richiesta:
    /// *«un allenamento dall'orologio a cui ho associato una scheda»*.
    test('con una scheda associata, il nome è quello della scheda', () {
      final voce = VoceStorico(
        sedute: const [],
        dalPolso: [dalPolso()],
        nomeScheda: 'Giorno 1',
        schedaId: 3,
      );

      expect(voce.nomeScheda, 'Giorno 1');
      expect(voce.schedaId, 3);
    });
  });
}
