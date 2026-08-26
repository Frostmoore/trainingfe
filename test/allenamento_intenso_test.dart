import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/storage/archivio_salute.dart';
import 'package:training_companion/src/features/training/data/storico_unificato.dart';

/// L'allenamento **intenso** — 3b-B.20.6, 25/08/2026.
///
/// 📌 *«Tutti gli allenamenti superiori alle 500kcal devono essere circondati
/// d'oro e ci deve essere un flag per poter dire che sono allenamenti intensi
/// (ci servirà per gli achievements in futuro)»*.
///
/// ⚠️ **Il flag deriva dalle calorie, non è una colonna.** Un dato salvato che
/// si può ricavare prima o poi non torna con ciò da cui deriva — basta
/// correggere le calorie a mano dopo averlo scritto.
void main() {
  VoceStorico dalPolso({required int? kcal}) => VoceStorico(
    sedute: const [],
    dalPolso: [
      AllenamentoDaOrologio(
        id: 1,
        fonte: 'com.huami.watch.hmwatchmanager',
        tipo: 'STRENGTH_TRAINING',
        iniziatoIl: DateTime(2026, 8, 25, 17),
        finitoIl: DateTime(2026, 8, 25, 18),
        kcal: kcal,
        nascosto: false,
        staccato: false,
        contaComeExtra: false,
      ),
    ],
  );

  group('🥇 la soglia', () {
    test('sopra le 600 è intenso', () {
      expect(dalPolso(kcal: 601).intenso, isTrue);
    });

    /// ⚠️ **Il valore tondo conta.** Escluderlo vorrebbe dire che l'unico
    /// allenamento che centra la soglia in pieno è l'unico che non la passa.
    test('e seicento esatte pure', () {
      expect(dalPolso(kcal: 600).intenso, isTrue);
    });

    test('sotto no', () {
      expect(dalPolso(kcal: 599).intenso, isFalse);
    });

    /// 🚨 *«Non lo so»* non è *«non è stato intenso»* — ma una medaglia non si
    /// dà a un forse.
    test('e senza calorie non si sa, quindi no', () {
      expect(dalPolso(kcal: null).intenso, isFalse);
    });
  });

  /// ⛔ **La soglia sta in un posto solo.** Copiarla nel widget che disegna il
  /// bordo e poi di nuovo dentro le medaglie vorrebbe dire che un giorno lo
  /// stesso allenamento è d'oro nello storico e non abbastanza intenso per la
  /// medaglia.
  test('e la soglia è quella dichiarata, non un numero sparso', () {
    expect(VoceStorico.kcalIntenso, 600);
    expect(dalPolso(kcal: VoceStorico.kcalIntenso).intenso, isTrue);
    expect(dalPolso(kcal: VoceStorico.kcalIntenso - 1).intenso, isFalse);
  });
}
