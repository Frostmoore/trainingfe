import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/diary/data/stima_ai.dart';
import 'package:training_companion/src/features/diary/ui/widgets/conferma_stima_sheet.dart';

/// Il foglio di conferma, disegnato davvero — A4.8.
///
/// 🚨 **Serve un widget test e non un unit test**, perché il difetto che questo
/// foglio chiude era esattamente *«il dato c'è e l'interfaccia non lo mostra»*:
/// la `note` del modello arrivava sul telefono e non compariva da nessuna parte.
/// Un test sui modelli avrebbe confermato che la nota si legge — cosa che non
/// era mai stata in dubbio — senza dire niente su chi la disegna.
void main() {
  StimaAi stima({
    List<Map<String, dynamic>>? voci,
    double confidenza = 0.8,
    String? nota,
  }) => StimaAi.fromJson({
    'estimate': {
      'items':
          voci ??
          const [
            {'name': 'Cotoletta di pollo', 'qty': 200, 'unit': 'g', 'grams': 200, 'kcal': 330, 'protein': 48, 'carbs': 0, 'fat': 15},
          ],
      'confidence': confidenza,
      'note': nota,
    },
  });

  Widget dentroUnFoglio(StimaAi s) => ProviderScope(
    child: MaterialApp(
      home: Scaffold(
        body: ConfermaStimaSheet(stima: s, meal: 'lunch', daFoto: false),
      ),
    ),
  );

  /// 🚨 **Il difetto, in un test.**
  ///
  /// Il modello aveva scritto *«non è stato specificato se sono panate»* e
  /// nessuno lo vedeva. Adesso quel testo deve essere sullo schermo.
  testWidgets('la nota del modello si vede', (tester) async {
    await tester.pumpWidget(
      dentroUnFoglio(stima(nota: 'Non è stato specificato se sono panate.')),
    );

    expect(find.text('Non è stato specificato se sono panate.'), findsOneWidget);
  });

  /// ⚠️ Senza nota non deve comparire un riquadro vuoto: un avviso senza
  /// contenuto è peggio di nessun avviso.
  testWidgets('senza nota non si disegna nessun riquadro', (tester) async {
    await tester.pumpWidget(dentroUnFoglio(stima()));

    expect(find.byIcon(Icons.info_outline), findsNothing);
  });

  testWidgets('il totale e il livello di confidenza sono in cima', (tester) async {
    await tester.pumpWidget(dentroUnFoglio(stima(confidenza: 0.5)));

    // ⚠️ La stringa intera, non «330 kcal»: quello compare anche nel
    // sottotitolo della voce, e un test che passa per il motivo sbagliato non
    // dimostra niente.
    expect(find.text('330 kcal · P 48 · C 0 · G 15'), findsOneWidget);
    expect(find.text('Stima incerta'), findsOneWidget);
  });

  /// 💡 I valori sono **collassati**: chi mangia una mela non deve leggere sette
  /// numeri. Ma con una voce sola si aprono da soli, perché non c'è niente da
  /// scorrere e il tocco in più sarebbe gratuito.
  testWidgets('con una voce sola i dettagli sono già aperti', (tester) async {
    await tester.pumpWidget(dentroUnFoglio(stima()));

    expect(find.text('Proteine 48 g'), findsOneWidget);
  });

  testWidgets('con più voci i dettagli partono chiusi', (tester) async {
    await tester.pumpWidget(
      dentroUnFoglio(
        stima(
          voci: const [
            {'name': 'Pasta', 'grams': 80, 'kcal': 280, 'protein': 10, 'carbs': 56, 'fat': 1},
            {'name': 'Sugo', 'grams': 100, 'kcal': 60, 'protein': 2, 'carbs': 8, 'fat': 3},
          ],
        ),
      ),
    );

    expect(find.text('Pasta'), findsOneWidget);
    expect(find.text('Sugo'), findsOneWidget);
    expect(find.text('Proteine 10 g'), findsNothing);

    await tester.tap(find.text('Pasta'));
    await tester.pumpAndSettle();

    expect(find.text('Proteine 10 g'), findsOneWidget);
  });

  /// 🚨 Una voce fisicamente impossibile si segnala, e i suoi dettagli si aprono
  /// da soli: è la riga da guardare.
  testWidgets('i macro impossibili vengono dichiarati', (tester) async {
    await tester.pumpWidget(
      dentroUnFoglio(
        stima(
          voci: const [
            {'name': 'Focaccia', 'grams': 100, 'kcal': 297, 'protein': 8, 'carbs': 36, 'fat': 14},
            {'name': 'Coppiette', 'grams': 100, 'kcal': 588, 'protein': 56, 'carbs': 4, 'fat': 40},
          ],
        ),
      ),
    );

    expect(find.textContaining('più proteine, carboidrati e grassi di quanto'), findsOneWidget);
    expect(find.byIcon(Icons.scale_outlined), findsOneWidget);

    // La riga sbagliata è aperta, quella sana no.
    expect(find.text('Proteine 56 g'), findsOneWidget);
    expect(find.text('Proteine 8 g'), findsNothing);
  });

  /// 🚨 **«Precisa» restituisce la frase**, che è il modo in cui chi ha aperto
  /// il foglio sa di dover riaprire il campo di testo invece di chiudere tutto.
  testWidgets('«Precisa» torna indietro con la frase originale', (tester) async {
    String? uscita = 'non chiamato';

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  uscita = await ConfermaStimaSheet.mostra(
                    context,
                    stima: stima().conFrase('due cotolette di pollo'),
                    meal: 'lunch',
                    daFoto: false,
                  );
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

    await tester.tap(find.text('Precisa'));
    await tester.pumpAndSettle();

    expect(uscita, 'due cotolette di pollo');
  });

  /// ⚠️ Da una foto non c'è niente da precisare a parole: il pulsante non deve
  /// nemmeno esserci, perché premerlo riaprirebbe un campo vuoto.
  testWidgets('da una foto il pulsante «Precisa» non c\'è', (tester) async {
    await tester.pumpWidget(dentroUnFoglio(stima()));

    expect(find.text('Precisa'), findsNothing);
    expect(find.text('Aggiungi al diario'), findsOneWidget);
  });

  /// 🚨 Correggere la quantità deve **cambiare quello che si salverà**. Un campo
  /// modificabile che non ha effetto è peggio di un campo bloccato.
  testWidgets('correggere la quantità aggiorna la voce', (tester) async {
    await tester.pumpWidget(dentroUnFoglio(stima()));

    await tester.enterText(find.widgetWithText(TextField, '200'), '250');
    await tester.pump();

    // La riga in cima si riscrive con la quantità nuova.
    expect(find.textContaining('250 g'), findsWidgets);
  });

  /// ⚠️ Una stima vuota non si può confermare: il pulsante resta spento e si
  /// dice perché, invece di far premere qualcosa che non farà niente.
  testWidgets('una stima senza alimenti non si conferma', (tester) async {
    await tester.pumpWidget(dentroUnFoglio(stima(voci: const [])));

    expect(find.text('Non ho riconosciuto nessun alimento.'), findsOneWidget);

    final bottone = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Aggiungi al diario'),
    );

    expect(bottone.onPressed, isNull);
  });
}
