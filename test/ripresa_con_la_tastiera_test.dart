import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/chiavi/ui/schermata_ripresa_dati.dart';

import 'aiuto/intestazione.dart';

/// ⌨️ **«Riprendi i tuoi dati» con la tastiera aperta** — I8, 19/11/2026.
///
/// ⛔ Visto sull'emulatore: il campo della password ha `autofocus`, quindi
/// all'arrivo la tastiera è **sempre** aperta, e la colonna fissa traboccava
/// di 31 px — «Riprendi» e «Più tardi» finivano sotto la tastiera.
///
/// 💡 Il telefono del test è quello dell'emulatore (1080×2400 a 2,625) con la
/// tastiera alta come la sua. ⚠️ Un trabocco in un test di widget fa fallire
/// il test da solo: la prima aspettativa è che si arrivi in fondo senza errori.
void main() {
  testWidgets('con la tastiera aperta si arriva a «Più tardi» e lo si tocca', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    // ⌨️ La tastiera dell'emulatore: circa 970 px fisici.
    tester.view.viewInsets = const FakeViewPadding(bottom: 970);
    addTearDown(tester.view.reset);

    var uscito = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: await intestazioneFinta(),
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => const SchermataRipresaDati(),
                    ),
                  );
                  uscito = true;
                },
                child: const Text('apri'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('apri'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.text('Più tardi'),
      100,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Più tardi'));
    await tester.pumpAndSettle();

    expect(uscito, isTrue);
  });
}
