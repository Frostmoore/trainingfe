import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/ui/etichetta_ai.dart';
import 'package:training_companion/src/features/privacy/ui/widgets/presa_d_atto_ai.dart';
import 'package:training_companion/src/features/training/data/limiti_delle_schede.dart';

/// Il gate del colore, la presa d'atto, e l'etichetta — 3b-J, 27/08/2026.
///
/// ══ 🚨 COSA DIFENDE QUESTO FILE ═══════════════════════════════════════════
///
/// Tre cose che si tolgono senza accorgersi di cosa si sta togliendo:
///
/// 1. **Il colore dietro l'abbonamento.** È una riga in `app.dart`: chi
///    semplifica quel `build` la fa sparire senza sospettare che fosse un
///    limite commerciale.
/// 2. **La presa d'atto.** È la finestra che qualcuno, un giorno, troverà
///    «fastidiosa all'attivazione». ⚖️ Non è fastidio: è la difesa contro
///    qualcuno che prende una frase generata da un modello per un parere
///    sanitario.
/// 3. **L'etichetta «Generato con l'AI»**, che sparisce alla prima modifica di
///    layout — e nessuno la leggerebbe come una modifica legale.
void main() {
  group('il colore dell\'app è degli abbonati', () {
    test('un abbonato senza palestra sceglie', () {
      expect(
        puoScegliereIlColore(haPalestra: false, abbonato: true),
        isTrue,
      );
    });

    test('chi non è abbonato non sceglie', () {
      expect(
        puoScegliereIlColore(haPalestra: false, abbonato: false),
        isFalse,
      );
    });

    test('chi ha una palestra non sceglie, abbonato o no', () {
      /*
       * 🚨 **Non è il gate, è una regola più vecchia.** Il colore è l'identità
       * del cliente (ADR-A01): lasciarlo cambiare a un iscritto vorrebbe dire
       * che può spegnere il marchio della palestra che lo paga.
       *
       * ⛔ Se un giorno il gate dell'abbonamento cadesse, questa resterebbe.
       */
      expect(puoScegliereIlColore(haPalestra: true, abbonato: true), isFalse);
      expect(puoScegliereIlColore(haPalestra: true, abbonato: false), isFalse);
    });

    test('se non si sa se è abbonato, non si blocca', () {
      // ⚠️ `null` è «il profilo non è ancora arrivato»: un flag che manca non
      // deve togliere niente a chi ha pagato. È la regola di `senzaLimiti`.
      expect(puoScegliereIlColore(haPalestra: false, abbonato: null), isTrue);
    });
  });

  group('la presa d\'atto sull\'AI', () {
    test('dice tutte e quattro le cose che deve dire', () {
      final tutto = testoPresaDAtto.join(' ').toLowerCase();

      /*
       * 📌 *«mi rendo conto che tutto ciò che è prodotto dall'ai non è mai un
       * consiglio medico, ma solo una stima stocastica generata da un modello
       * di intelligenza artificiale e che non devo farci alcun tipo di
       * affidamento perché ne va della mia vita e della mia salute»*.
       *
       * 💡 Non si controlla il testo esatto — quello si può riscrivere meglio —
       * ma che le quattro affermazioni **ci siano**.
       */
      expect(tutto, contains('non è mai un parere medico'));
      expect(tutto, contains('stima statistica'));
      expect(tutto, contains('non devo farci affidamento'));
      expect(tutto, contains('la mia salute'));
    });

    test('è scritta in prima persona', () {
      /*
       * 🚨 **È la differenza fra leggere e dichiarare.** «L'AI può sbagliare» è
       * un'informazione su un prodotto; «non devo farci affidamento» è una cosa
       * che dico io — ed è quella che poi si conserva come consenso.
       */
      final tutto = testoPresaDAtto.join(' ');

      expect(tutto, contains('Non devo'));
      expect(tutto, contains('me ne prendo la responsabilità'));
    });

    testWidgets('il pulsante è spento finché non si spunta', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => chiediLaPresaDAtto(context),
              child: const Text('apri'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('apri'));
      await tester.pumpAndSettle();

      final attiva = find.widgetWithText(FilledButton, 'Attiva l\'AI');

      expect(attiva, findsOneWidget);

      /*
       * ⛔ **Spento, e non «acceso che poi avvisa»**: un pulsante che si può
       * toccare invita a toccarlo, e chi lo tocca ha già smesso di leggere.
       */
      expect(tester.widget<FilledButton>(attiva).onPressed, isNull);

      /*
       * 💡 **Bisogna scorrere per arrivarci, e va bene così.** Su uno schermo
       * piccolo la casella sta sotto la piega: per spuntarla si passa davanti a
       * tutto il testo. ⛔ Metterla sopra la renderebbe raggiungibile senza
       * aver letto niente — che è esattamente quello che non deve succedere.
       */
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();

      expect(tester.widget<FilledButton>(attiva).onPressed, isNotNull);
    });

    testWidgets('non si chiude toccando fuori', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => chiediLaPresaDAtto(context),
              child: const Text('apri'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('apri'));
      await tester.pumpAndSettle();

      // ⚠️ `tapAt` in alto a sinistra: fuori dalla finestra.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
    });
  });

  group('l\'etichetta «Generato con l\'AI»', () {
    testWidgets('si vede', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: EtichettaAi())),
      );

      expect(find.text(testoEtichettaAi), findsOneWidget);
    });

    testWidgets('con l\'aggiunta resta una riga sola', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: EtichettaAi(aggiunta: 'può sbagliare')),
        ),
      );

      expect(find.text('$testoEtichettaAi · può sbagliare'), findsOneWidget);
    });

    test('sta dove l\'AI scrive qualcosa', () {
      /*
       * ══ 🚨 IL TEST CHE VALE, E PERCHÉ LEGGE I SORGENTI ══════════════════
       *
       * 📌 *«dovunque ci sia qualcosa di generato da ai, ci deve essere
       * chiaramente scritto che la cosa è stata generata con l'ai»*.
       *
       * ⛔ Un test per schermata proverebbe che *quella* schermata ce l'ha. Qui
       * la domanda è un'altra: **ce l'hanno tutte quelle che devono**. 💡 E la
       * risposta è un elenco che si allunga quando nasce una funzione nuova —
       * cioè il momento esatto in cui l'etichetta si dimentica.
       *
       * ⚠️ Il consiglio del giorno **non è in elenco**: là c'è un'avvertenza
       * più lunga, provata da `avvertenza_consiglio_test.dart`. Quella avverte,
       * questa attribuisce, e dove serve avvertire non basta etichettare.
       */
      const dove = [
        // La stima di un alimento, scritta o fotografata.
        'lib/src/features/diary/ui/widgets/conferma_stima_sheet.dart',

        // Il riassunto della scheda.
        'lib/src/features/training/ui/plans_screen.dart',

        // La riga sotto ogni esercizio, che si legge lontano dalla card.
        'lib/src/features/training/ui/widgets/progresso_dell_esercizio.dart',
      ];

      for (final file in dove) {
        expect(
          File(file).readAsStringSync(),
          contains('EtichettaAi('),
          reason: '$file mostra roba generata dall\'AI e non lo dice',
        );
      }
    });
  });
}
