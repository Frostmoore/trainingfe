import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/auth/data/app_user.dart';

/// 🏋️ **Il muro da trainer si decide da `puo_allenare`** — giro A6, 22/09/2026.
///
/// ⛔ Si decideva da `abbonato`, il contratto **della persona**: un trainer
/// creato dal pannello di una palestra non è abbonato (la palestra gli paga il
/// lavoro, non il Plus), e si vedeva «Abbonamento da trainer scaduto».
void main() {
  AppUser utente(Map<String, dynamic> campi) => AppUser.fromJson({
    'id': 1,
    'name': 'Coach',
    'email': 'coach@esempio.test',
    'roles': ['trainer'],
    ...campi,
  });

  test('un trainer di palestra non abbonato può allenare', () {
    final u = utente({'abbonato': false, 'puo_allenare': true});

    expect(u.abbonato, isFalse);
    expect(u.puoFareIlTrainer, isTrue);
  });

  test('se il server dice di no, è no anche da abbonato', () {
    expect(
      utente({'abbonato': true, 'puo_allenare': false}).puoFareIlTrainer,
      isFalse,
    );
  });

  /// ⚠️ Un server che non manda ancora il campo: si fa quello che si faceva.
  test('senza il campo si ricade su abbonato', () {
    expect(utente({'abbonato': true}).puoFareIlTrainer, isTrue);
    expect(utente({'abbonato': false}).puoFareIlTrainer, isFalse);
  });
}
