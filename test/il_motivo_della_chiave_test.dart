import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/chiavi/ui/schermata_password_di_recupero.dart';

import 'aiuto/intestazione.dart';

/// La password di recupero dice **perché** si sta chiedendo — 14/09/2026.
///
/// ══ ⛔ IL DIFETTO ══════════════════════════════════════════════════════════
///
/// La schermata cominciava sempre con *«I tuoi messaggi sono cifrati»*, anche a
/// chi aveva appena toccato *«Importa una scheda da PDF»* o *«Ho un piano su
/// PDF»*. 🚨 Quella persona non stava scrivendo a nessuno: chiedeva di caricare
/// un documento, e trovava una pagina che parlava di messaggi e di trainer.
///
/// ⚠️ Visto sull'emulatore il 14/09, da due strade diverse.
///
/// ══ 💡 COSA PROVA QUESTO FILE ═════════════════════════════════════════════
///
/// Non che i testi esistano — quello lo direbbe l'enum da solo. Prova che la
/// schermata **usi quello che le viene passato**, e che il valore di serie non
/// sia cambiato: è lui che tiene in piedi la porta più frequentata, la chat.
void main() {
  /// ⚠️ L'intestazione dell'app poggia su branding, utente e gettoni: senza le
  /// sovrascritture di `intestazioneFinta()` la schermata non si costruisce
  /// nemmeno, e il test fallirebbe per un motivo che non c'entra niente.
  Future<void> disegna(WidgetTester tester, PercheLaChiave? perche) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: await intestazioneFinta(),
        child: MaterialApp(
          home: perche == null
              ? const SchermataPasswordDiRecupero()
              : SchermataPasswordDiRecupero(perche: perche),
        ),
      ),
    );

    await tester.pump();
  }

  testWidgets('di serie parla di messaggi, che è la porta più frequentata', (
    tester,
  ) async {
    await disegna(tester, null);

    expect(find.text('I tuoi messaggi sono cifrati'), findsOneWidget);
  });

  /// 🚨 Il caso del difetto: si arriva da un'importazione.
  testWidgets('da un documento non si parla più di messaggi', (tester) async {
    await disegna(tester, PercheLaChiave.documenti);

    expect(find.text('Il documento resta tuo'), findsOneWidget);
    expect(find.text('I tuoi messaggi sono cifrati'), findsNothing);
  });

  testWidgets('e dalle schede si parla di schede', (tester) async {
    await disegna(tester, PercheLaChiave.schede);

    expect(find.text('Le tue schede sono cifrate'), findsOneWidget);
    expect(find.text('I tuoi messaggi sono cifrati'), findsNothing);
  });

  /// ⚠️ **Ogni motivo deve avere due testi veri.** Un valore aggiunto in fretta
  /// con la stringa vuota darebbe una schermata senza titolo, e nessun errore.
  test('nessun motivo ha testi vuoti', () {
    for (final p in PercheLaChiave.values) {
      expect(p.titolo.trim(), isNotEmpty, reason: 'titolo di ${p.name}');
      expect(
        p.spiegazione.trim(),
        isNotEmpty,
        reason: 'spiegazione di ${p.name}',
      );
    }
  });
}
