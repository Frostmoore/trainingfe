import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/training/rest_timer.dart';

/// C9.3 — il timer di riposo.
///
/// 🚨 Le notifiche sono spente (`notificheAttive = false`): programmarne una
/// vera richiede i canali della piattaforma, che in un test di unità non
/// esistono. Ciò che si prova qui è **il conto alla rovescia**, che è la parte
/// che sbaglia in silenzio.
void main() {
  late RestTimer timer;

  setUp(() {
    timer = RestTimer()..notificheAttive = false;
  });

  tearDown(() => timer.dispose());

  test('un riposo appena avviato ha davanti tutti i suoi secondi', () async {
    await timer.avvia(90);

    expect(timer.attivo, isTrue);
    expect(timer.rimanenti, inInclusiveRange(89, 90));
    expect(timer.totale, 90);
  });

  /// 🚨 **Il test che protegge dal difetto vero.**
  ///
  /// Un `Timer.periodic` che fa `secondi--` smette di essere chiamato in
  /// background: al ritorno il numero sarebbe fermo dov'era e il riposo
  /// risulterebbe più lungo di quanto è stato. Calcolando da un istante di
  /// fine, il tempo passa anche se non gira niente.
  test('il tempo scorre anche se nessun tick viene eseguito', () async {
    await timer.avvia(3);

    final subito = timer.rimanenti;

    // Nessun `pump`, nessun tick: solo tempo reale che passa.
    await Future<void>.delayed(const Duration(milliseconds: 1100));

    expect(timer.rimanenti, lessThan(subito));
  });

  test('«+30s» allunga il riposo e il totale', () async {
    await timer.avvia(60);
    await timer.aggiungi(30);

    expect(timer.totale, 90);
    expect(timer.rimanenti, greaterThan(80));
  });

  test('saltare azzera tutto', () async {
    await timer.avvia(60);
    await timer.salta();

    expect(timer.attivo, isFalse);
    expect(timer.rimanenti, 0);
    expect(timer.progresso, 0);
  });

  test('un riposo di zero secondi non parte', () async {
    await timer.avvia(0);

    expect(timer.attivo, isFalse);
  });

  test('«+30s» su un timer fermo non fa niente', () async {
    await timer.aggiungi(30);

    expect(timer.attivo, isFalse);
    expect(timer.totale, 0);
  });

  test('il testo è minuti:secondi con lo zero davanti', () async {
    await timer.avvia(65);

    expect(timer.testo, anyOf('1:05', '1:04'));
  });

  test('il progresso va da zero a uno', () async {
    await timer.avvia(100);

    expect(timer.progresso, lessThan(0.05));
    expect(timer.progresso, greaterThanOrEqualTo(0));
  });
}
