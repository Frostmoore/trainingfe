import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/pubblicita/banner_contestuale.dart';

/// La pubblicità, e i due posti in cui non deve stare — F9.4, decisione D7.
///
/// ── 🚨 Cosa prova davvero questo file ───────────────────────────────────────
///
/// Non prova che un banner si disegni: prova che **non esiste un modo di
/// chiederne uno per l'allenamento o per il riepilogo di fine seduta**.
///
/// ⚠️ Sono i due momenti che convincono qualcuno a pagare: metterci un annuncio
/// è pagare pochi centesimi per perdere un abbonamento. E il rischio non è il
/// progetto — è l'incidente: qualcuno, mesi dopo, che aggiunge un banner «anche
/// qui» per alzare il riempimento, senza aver mai letto D7.
void main() {
  Widget schermo(Widget figlio) => MaterialApp(
    home: Scaffold(body: Center(child: figlio)),
  );

  /// 🚨 **Il test che vale per tutti gli altri.**
  ///
  /// `Collocazione` è un enum **chiuso**, e contiene solo schermate di
  /// consultazione. Il giorno in cui qualcuno aggiungesse `allenamento` o
  /// `riepilogo`, questo test lo direbbe — nominando il caso.
  test('non esiste una collocazione per l\'allenamento o per il riepilogo', () {
    final nomi = Collocazione.values.map((c) => c.name).toList();

    expect(nomi, ['diario', 'storico']);

    for (final vietato in ['allenamento', 'riepilogo', 'player', 'sessione']) {
      expect(
        nomi,
        isNot(contains(vietato)),
        reason:
            'Aggiunta una collocazione «$vietato»: D7 dice che durante '
            'l\'allenamento e nel riepilogo di fine seduta non va MAI un '
            'annuncio. Sono i due momenti che convincono qualcuno a pagare.',
      );
    }
  });

  /// ⚠️ **Non c'è un posto dove infilare un dato dell'utente, nemmeno volendo.**
  ///
  /// Il costruttore accetta solo la collocazione e un interruttore. Chi un
  /// giorno vorrà «targettizzare meglio» dovrà cambiare la firma — e a quel
  /// punto leggerà il perché.
  testWidgets('si costruisce senza nessun dato della persona', (tester) async {
    await tester.pumpWidget(
      schermo(const BannerContestuale(dove: Collocazione.diario)),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(Card), findsOneWidget);
  });

  /// 🚨 Chi paga non vede niente: è il senso del piano.
  testWidgets('con un piano a pagamento sparisce del tutto', (tester) async {
    await tester.pumpWidget(
      schermo(
        const BannerContestuale(dove: Collocazione.diario, mostra: false),
      ),
    );

    expect(find.byType(Card), findsNothing);
    expect(tester.takeException(), isNull);
  });

  /// 💡 Nel segnaposto non compare nessun dato: né peso, né calorie, né nomi.
  testWidgets('il segnaposto non mostra dati dell\'utente', (tester) async {
    await tester.pumpWidget(
      schermo(const BannerContestuale(dove: Collocazione.storico)),
    );

    final testi = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .join(' ');

    for (final vietato in ['kg', 'kcal', 'peso', 'HRV', 'sonno']) {
      expect(
        testi.toLowerCase(),
        isNot(contains(vietato.toLowerCase())),
        reason: 'Un dato della persona è finito in un banner pubblicitario.',
      );
    }
  });
}
