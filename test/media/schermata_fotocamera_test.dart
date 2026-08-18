import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/fotocamera/ui/schermata_fotocamera.dart';

/// La fotocamera nostra — N10.
///
/// ⚠️ **Quello che questi test NON possono dimostrare** è che l'anteprima
/// mostri esattamente ciò che viene salvato: serve una fotocamera vera, e la
/// prova è **N10.6, a mano sul telefono**. Qui si tiene fermo tutto il resto —
/// che è la parte che si rompe senza che nessuno se ne accorga.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Gli orientamenti che la schermata ha chiesto al sistema, in ordine.
  late List<List<String>> chiesti;

  setUp(() {
    chiesti = [];

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (chiamata) async {
          if (chiamata.method == 'SystemChrome.setPreferredOrientations') {
            chiesti.add((chiamata.arguments as List).cast<String>());
          }

          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  /// ── ⚠️ Due trappole in una riga sola ─────────────────────────────────────
  ///
  /// **Niente `pumpAndSettle`**: finché la fotocamera non risponde la schermata
  /// mostra un cerchio che gira, e quella è un'animazione che non finisce
  /// **mai**. `pumpAndSettle` aspetterebbe la quiete fino a scadere, e
  /// fallirebbe sempre.
  ///
  /// **Serve `runAsync`**: `pump` fa avanzare l'orologio finto, ma il rifiuto di
  /// `availableCameras()` arriva dal vero giro di eventi. Senza, la schermata
  /// resta in caricamento per sempre e non si vedrebbe mai il messaggio.
  Future<void> apri(WidgetTester tester, {String? titolo = 'Prova'}) async {
    await tester.pumpWidget(
      MaterialApp(home: SchermataFotocamera(titolo: titolo)),
    );

    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );

    await tester.pump();
  }

  testWidgets('senza fotocamera non crolla: lo dice e offre di riprovare', (
    tester,
  ) async {
    /*
     * 🚨 In `flutter test` il plugin non è registrato, quindi
     * `availableCameras()` lancia `MissingPluginException` — che **non** è una
     * `CameraException`.
     *
     * ⚠️ Prendendo solo quella, l'eccezione sfuggirebbe e la schermata
     * crollerebbe invece di dire cosa succede. Questo test è la ragione per cui
     * la presa in `_avvia` è su `Object`.
     */
    await apri(tester);

    expect(find.textContaining('Non riesco ad aprire la fotocamera'), findsOne);
    expect(find.text('Riprova'), findsOne);
    expect(tester.takeException(), isNull, reason: 'e\' crollata');
  });

  testWidgets('🚨 blocca in verticale entrando e RIMETTE tutto uscendo', (
    tester,
  ) async {
    /*
     * ── ⚠️ La riga che si dimentica ─────────────────────────────────────────
     *
     * Bloccare l'orientamento è facile; **sbloccarlo all'uscita** è quello che
     * salta. Senza, l'app **intera** resta in verticale, e il difetto si
     * manifesta lontano dalla causa — in una schermata che con la fotocamera
     * non c'entra niente, dove nessuno andrà a cercarlo.
     */
    await apri(tester);

    /*
     * 💡 Un predicato e non `contains`: quel matcher confronta con `==`, e
     * due liste distinte non sono **mai** uguali in Dart. Ci avevo provato, e
     * falliva dicendo `Actual: [[DeviceOrientation.portraitUp]]` — cioe' il
     * valore giusto.
     *
     * Non serve nemmeno che sia la prima chiamata in assoluto: basta che il
     * blocco sia stato chiesto.
     */
    expect(
      chiesti.any(
        (c) => c.length == 1 && c.single == 'DeviceOrientation.portraitUp',
      ),
      isTrue,
      reason: 'non ha bloccato in verticale',
    );

    final primaDiUscire = chiesti.length;

    // Si esce dalla schermata: `dispose` deve rimettere tutto.
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump();

    expect(
      chiesti.length,
      greaterThan(primaDiUscire),
      reason: 'uscendo non ha chiesto niente: l\'app resta bloccata',
    );
    expect(
      chiesti.last.length,
      DeviceOrientation.values.length,
      reason: 'ha rimesso solo una parte degli orientamenti',
    );
  });

  testWidgets('il titolo che le passi finisce in cima', (tester) async {
    await apri(tester);

    expect(find.text('Prova'), findsOne);
  });

  testWidgets('senza titolo dice comunque qualcosa', (tester) async {
    await apri(tester, titolo: null);

    expect(find.text('Scatta'), findsOne);
  });
}
