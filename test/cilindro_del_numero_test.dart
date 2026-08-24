import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/training/ui/widgets/cilindro_del_numero.dart';

/// Il cilindro del numero — 3b-B.14, 24/08/2026.
///
/// ══ 🚨 COSA DIFENDE QUESTO FILE ═══════════════════════════════════════════
///
/// 📌 *«si deve vedere tipo "cilindro" con vicino altri due o tre numeri, e
/// quando appare deve fare tipo l'animazione di un cilindro che si ferma lì con
/// un po' di bezier (diciamo tipo elastico)»* e poi: *«il cilindro deve scorrere
/// in **orizzontale**, per quello ho detto rettangolo bianco»*.
///
/// ⛔ Un'animazione non si prova guardando che «sembra giusta»: si prova
/// controllando **cosa c'è a schermo** all'inizio, a metà e alla fine. ⚠️ I
/// difetti veri di un cilindro sono che si fermi sul numero sbagliato, che mostri
/// numeri che non esistono e che scorra **nel verso sbagliato** — e nessuno dei
/// tre dà un errore.
void main() {
  Widget attorno(int valore, {bool animazioni = true}) => MediaQuery(
    data: MediaQueryData(disableAnimations: !animazioni),
    child: MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 320,
            height: 120,
            child: CilindroDelNumero(valore: valore, passo: 60),
          ),
        ),
      ),
    ),
  );

  /// 🚨 **Alla fine ci deve essere il numero giusto.** È l'unica cosa che
  /// l'utente deve poter credere: tutto il resto è come ci arriva.
  testWidgets('si ferma sul numero giusto', (tester) async {
    await tester.pumpWidget(attorno(7));
    await tester.pumpAndSettle();

    expect(find.text('7'), findsOneWidget);
  });

  /// 📌 *«con vicino altri due o tre numeri»*: a riposo si vedono i vicini, a
  /// destra e a sinistra.
  ///
  /// 💡 Senza di loro l'animazione non si capirebbe da dove viene: sono i
  /// vicini sbiaditi a dire **che cosa è quell'oggetto**.
  testWidgets('e accanto ci sono i vicini', (tester) async {
    await tester.pumpWidget(attorno(7));
    await tester.pumpAndSettle();

    for (final n in [5, 6, 8, 9]) {
      expect(find.text('$n'), findsOneWidget, reason: 'Manca il vicino $n.');
    }
  });

  /// ══ 🚨 IL TEST CHE MI AVREBBE FATTO RISPARMIARE UN GIRO ═════════════════
  ///
  /// 📌 *«il cilindro deve scorrere in **orizzontale**, per quello ho detto
  /// rettangolo bianco»*.
  ///
  /// ⛔ Al primo tentativo scorreva **in verticale**, e tutti gli altri test di
  /// questo file passavano lo stesso: cercavano *quali* numeri si vedono, non
  /// *dove*. ⚠️ Un test che non guarda l'asse non distingue un cilindro
  /// orizzontale da uno verticale — e la forma del contenitore, un rettangolo
  /// largo, era già la risposta.
  ///
  /// 💡 I più bassi a sinistra, i più alti a destra: il verso di un contatore
  /// che sale.
  testWidgets('e i vicini stanno DI LATO, non sopra e sotto', (tester) async {
    await tester.pumpWidget(attorno(7));
    await tester.pumpAndSettle();

    final centro = tester.getCenter(find.text('7'));
    final prima = tester.getCenter(find.text('6'));
    final dopo = tester.getCenter(find.text('8'));

    expect(
      prima.dx,
      lessThan(centro.dx),
      reason: 'Il numero più basso non sta a sinistra.',
    );
    expect(
      dopo.dx,
      greaterThan(centro.dx),
      reason: 'Il numero più alto non sta a destra.',
    );

    // ⛔ E sulla stessa riga: se scorressero in verticale, questo fallirebbe.
    expect(prima.dy, closeTo(centro.dy, 1));
    expect(dopo.dy, closeTo(centro.dy, 1));
  });

  /// ⛔ **Niente numeri negativi.** Un cilindro che passa da «−2» mentre sale
  /// verso «1» racconta una cosa che non esiste, e con pochi allenamenti — cioè
  /// il caso normale di chi comincia — succederebbe sempre.
  testWidgets('e non mostra mai numeri negativi', (tester) async {
    await tester.pumpWidget(attorno(1));

    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 40));

      for (final n in ['-1', '-2', '-3', '-4']) {
        expect(find.text(n), findsNothing, reason: 'È comparso $n.');
      }
    }

    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);
  });

  /// ══ 🚨 L'ELASTICO DEVE SFORARE, O NON È UN ELASTICO ═════════════════════
  ///
  /// 💡 `Curves.elasticOut` **supera** il valore d'arrivo e ci torna sopra: è
  /// quello che fa sembrare l'oggetto pesante, ed è la ragione per cui la
  /// richiesta diceva *«tipo elastico»* e non «una dissolvenza».
  ///
  /// ⚠️ Si prova così: a un certo punto del giro deve essere visibile un numero
  /// **oltre** quello d'arrivo, che a fine corsa non c'è più al centro.
  testWidgets('e sfora, come fa un elastico', (tester) async {
    await tester.pumpWidget(attorno(10));

    var haSforato = false;

    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 40));

      // 💡 Oltre l'arrivo più i vicini: se si vede, è perché ha superato.
      if (find.text('13').evaluate().isNotEmpty) haSforato = true;
    }

    expect(
      haSforato,
      isTrue,
      reason: 'Il cilindro non ha mai superato il valore: non è un elastico.',
    );
  });

  /// 💡 E parte **da un numero più basso**, scorrendo verso il suo: il nastro va
  /// verso sinistra e quello buono arriva da destra, come un contatore che sale.
  /// ⛔ Al contrario sembrerebbe che il conteggio scenda.
  testWidgets('e parte da più indietro, salendo', (tester) async {
    await tester.pumpWidget(attorno(20));
    await tester.pump(const Duration(milliseconds: 16));

    /*
     * Al primo fotogramma il centro è ancora vicino a `20 - 6 = 14`, quindi il
     * 20 non è ancora arrivato in mezzo e il 14 sì.
     */
    expect(find.text('14'), findsOneWidget);

    /*
     * ⚠️ E il **20 non c'è ancora**: la finestra mostra due posizioni per parte,
     * quindi all'inizio si vede 12-16 e basta.
     *
     * 💡 Sembra un dettaglio e non lo è: se il valore d'arrivo fosse già a
     * schermo al primo fotogramma, vorrebbe dire che il nastro non parte da
     * lontano — cioè che non sta scorrendo, sta comparendo.
     */
    expect(find.text('20'), findsNothing);

    await tester.pumpAndSettle();
    expect(find.text('20'), findsOneWidget);
  });

  /// ⛔ **Chi ha spento le animazioni non vede nessun giro.** Non è una spunta
  /// di accessibilità: chi lo attiva spesso lo fa perché il movimento gli dà
  /// fastidio fisico.
  testWidgets('e chi ha spento le animazioni vede solo il numero', (
    tester,
  ) async {
    await tester.pumpWidget(attorno(7, animazioni: false));
    await tester.pump();

    expect(find.text('7'), findsOneWidget);
    expect(find.text('6'), findsNothing);
    expect(find.text('8'), findsNothing);
  });

  /// ⛔ **Non rigira a ogni ridisegno.** Un'animazione che riparte quando si
  /// scorre la pagina o cambia un'altra card è fastidiosa, e per giunta senza
  /// motivo: il numero è lo stesso.
  testWidgets('e rigira solo se il numero cambia davvero', (tester) async {
    await tester.pumpWidget(attorno(7));
    await tester.pumpAndSettle();

    // Stesso valore: nessuna animazione da smaltire.
    await tester.pumpWidget(attorno(7));
    await tester.pump();

    expect(find.text('7'), findsOneWidget);
    expect(
      tester.hasRunningAnimations,
      isFalse,
      reason: 'È ripartito senza che il numero sia cambiato.',
    );

    // Valore diverso: riparte.
    await tester.pumpWidget(attorno(9));
    await tester.pump();

    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpAndSettle();
    expect(find.text('9'), findsOneWidget);
  });
}
