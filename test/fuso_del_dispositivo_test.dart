import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/tempo/fuso_del_dispositivo.dart';

/// A3 — il fuso del telefono, che è l'unico posto in cui esiste davvero.
///
/// 🚨 **Il contratto che conta è «non lancia mai».** Questa lettura sta sul
/// percorso d'avvio dell'app e dentro `initNotifications()`: un'eccezione qui
/// non sarebbe un fuso sbagliato, sarebbe **un'app che non parte**.
void main() {
  const canale = MethodChannel('flutter_timezone');

  TestWidgetsFlutterBinding.ensureInitialized();

  void rispondi(Object? Function() risposta) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canale, (_) async => risposta());
  }

  setUp(FusoDelDispositivo.dimentica);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canale, null);
    FusoDelDispositivo.dimentica();
  });

  test('restituisce l\'identificativo IANA che dà la piattaforma', () async {
    rispondi(() => 'Europe/Rome');

    expect(await FusoDelDispositivo.leggi(), 'Europe/Rome');
  });

  test('non rilegge la piattaforma la seconda volta', () async {
    var chiamate = 0;

    rispondi(() {
      chiamate++;

      return 'Europe/Rome';
    });

    await FusoDelDispositivo.leggi();
    await FusoDelDispositivo.leggi();
    await FusoDelDispositivo.leggi();

    expect(chiamate, 1);
  });

  /// ⚠️ Il caso che rende il metodo sicuro da chiamare all'avvio.
  test('se la piattaforma lancia, risponde null invece di propagare', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canale, (_) async {
          throw PlatformException(code: 'niente');
        });

    expect(await FusoDelDispositivo.leggi(), isNull);
  });

  /// 🚨 Una stringa vuota passerebbe il `required` del server per poi farsi
  /// rifiutare dall'elenco IANA: è un 422 che nessuno vedrebbe mai, generato
  /// da noi. Meglio non mandarla.
  test('una stringa vuota vale come «non lo so»', () async {
    rispondi(() => '');

    expect(await FusoDelDispositivo.leggi(), isNull);
  });

  test('un canale che risponde null non fa saltare niente', () async {
    rispondi(() => null);

    expect(await FusoDelDispositivo.leggi(), isNull);
  });
}
