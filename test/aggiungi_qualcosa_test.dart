import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/dashboard/ui/widgets/aggiungi_qualcosa.dart';

/// ➕ Il tasto che aggiunge tutto — 08/09/2026.
///
/// ══ 🚨 COSA DIFENDE ═══════════════════════════════════════════════════════
///
/// ⛔ **Non dove portano le voci**: quello è instradamento, e verificarlo qui
/// vorrebbe dire montare mezza app per guardare una `push`.
///
/// 🚨 Difende le due cose che si rompono in silenzio:
///
/// 1. **l'elenco è completo** — una voce che sparisce in un `if` non dà nessun
///    errore, e nessuno se ne accorge finché qualcuno non la cerca;
/// 2. **«Integratore alimentare» è spento** — 📌 *«per adesso lascialo mock e
///    disabilitato con scritto "In Arrivo"»*. ⚠️ È l'unica voce che **non deve**
///    funzionare, quindi è l'unica che un giro di modifiche può accendere per
///    sbaglio.
void main() {
  Widget conIlTasto() => const ProviderScope(
    child: MaterialApp(
      home: Scaffold(floatingActionButton: AggiungiQualcosa()),
    ),
  );

  testWidgets('➕ il tasto è verde e porta un\'icona, non un\'emoji', (
    tester,
  ) async {
    await tester.pumpWidget(conIlTasto());

    final fab = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );

    expect(fab.backgroundColor, AggiungiQualcosa.verde);

    /*
     * ⛔ **`Icon` e non `Text`**: 📌 *«un + in mezzo - icona, non emoji»*. Una
     * emoji è un carattere, quindi cambia disegno da un telefono all'altro e
     * non prende il colore che le si dà. 💡 Qui si verifica il tipo, che è
     * l'unico modo di distinguerle in un test.
     */
    expect(fab.child, isA<Icon>());
  });

  testWidgets('📋 il foglio elenca tutte e sei le cose che si aggiungono', (
    tester,
  ) async {
    await tester.pumpWidget(conIlTasto());
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    for (final voce in [
      'Allenamento',
      'Cibo',
      'Integratore alimentare',
      'Dispositivo smart',
      'Scheda',
      'Piano alimentare',
    ]) {
      expect(find.text(voce), findsOneWidget, reason: 'manca «$voce»');
    }
  });

  testWidgets('⏳ e l\'integratore è spento, e dice perché', (tester) async {
    await tester.pumpWidget(conIlTasto());
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('In arrivo'), findsOneWidget);

    /*
     * 🚨 **`enabled: false` e non solo `onTap: null`.** Il secondo blocca il
     * tocco ma lascia la riga scritta con il colore normale: sembra premibile,
     * e chi la preme conclude che l'app si è inceppata. 💡 `enabled` la
     * scolorisce, cioè lo dice **prima** del tocco.
     */
    final riga = tester.widget<ListTile>(
      find.ancestor(
        of: find.text('Integratore alimentare'),
        matching: find.byType(ListTile),
      ),
    );

    expect(riga.enabled, isFalse);
    expect(riga.onTap, isNull);
  });
}
