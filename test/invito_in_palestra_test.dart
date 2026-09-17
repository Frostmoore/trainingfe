import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/onboarding/data/invito_in_palestra.dart';
import 'package:training_companion/src/features/onboarding/invito_controller.dart';
import 'package:training_companion/src/features/auth/auth_controller.dart';
import 'package:training_companion/src/features/onboarding/ui/schermata_invito.dart';

/// 🎯 La pagina che si apre toccando un link d'invito — 3b-V.
///
/// ══ 📌 LA RICHIESTA ═══════════════════════════════════════════════════════
///
/// *«Il link d'invito deve essere monouso, e a chi ci clicca si deve aprire
/// l'app in una pagina con la descrizione della palestra, il logo, i colori, un
/// messaggio di congratulazioni, le cose a cui avrà accesso e due tasti, uno
/// per accettare e uno per rifiutare»* — 29/08/2026.
Map<String, dynamic> _rispostaDelServer({
  bool conAi = true,
  String? descrizione = 'Sala pesi, corsi e due personal trainer.',
}) => {
  'palestra': {
    'name': 'Olimpo',
    'slug': 'olimpo',
    'colors': {
      'primary': '#B71C1C',
      'secondary': '#212121',
      'accent': '#FFC107',
    },
    'logo_url': null,
  },
  'descrizione': descrizione,
  'cosa_ottieni': [
    {
      'icona': 'fitness_center',
      'titolo': 'Le schede del tuo trainer',
      'dettaglio': 'Arrivano sul telefono.',
    },
    {
      'icona': 'chat',
      'titolo': 'La chat con chi ti segue',
      'dettaglio': 'La leggete solo voi due.',
    },
    if (conAi)
      {
        'icona': 'auto_awesome',
        'titolo': 'I consigli e le stime con l\'AI',
        'dettaglio': 'Fino a 150 richieste al mese.',
      },
  ],
  'scade_il': '2026-09-05T12:00:00+00:00',
};

/// ⚠️ **Un albero per test, e non due `pumpWidget` di fila.** Riverpod rifiuta
/// di sostituire un override su uno scope già montato — *«Changing the kind of
/// override or reordering overrides is not supported»* — e il secondo
/// `pumpWidget` riusa l'elemento, quindi ci prova.
///
/// 💡 È anche la forma giusta: due affermazioni diverse vogliono due test, così
/// quando uno diventa rosso si sa **quale** delle due è saltata.
/// 🆕 ⚠️ **`sessioneAttiva` decide quali tasti si vedono** — 17/09/2026.
///
/// 📌 Da quando l'invito distingue chi ha un account da chi non ce l'ha, la
/// pagina ha bisogno di saperlo. 💡 Qui basta un booleano: `sessioneAttivaProvider`
/// esiste apposta per non dover costruire un `AuthController` intero — con
/// client, token store, cache e blocco biometrico — dentro un test che parla
/// d'altro.
Widget _schermata(
  Map<String, dynamic> risposta, {
  bool sessioneAttiva = true,
}) => ProviderScope(
  overrides: [
    invitoProvider(
      'tok',
    ).overrideWith((ref) async => InvitoInPalestra.fromJson(risposta)),
    sessioneAttivaProvider.overrideWithValue(sessioneAttiva),
  ],
  child: const MaterialApp(home: SchermataInvito(token: 'tok')),
);

void main() {
  group('la lettura della risposta', () {
    test('legge marchio, descrizione e vantaggi', () {
      final invito = InvitoInPalestra.fromJson(_rispostaDelServer());

      expect(invito.palestra.name, 'Olimpo');
      expect(invito.descrizione, contains('Sala pesi'));
      expect(invito.cosaOttieni.length, 3);
      expect(invito.cosaOttieni.first.titolo, 'Le schede del tuo trainer');
    });

    /// 🚨 **Tollerante come `GymBranding`.** Questa risposta arriva a un'app che
    /// può essere più vecchia del server: un campo mancante non deve impedire di
    /// mostrare l'invito, che è l'unica cosa che quella persona vuole fare.
    test('una risposta monca non fa saltare niente', () {
      final invito = InvitoInPalestra.fromJson(const {});

      expect(invito.palestra.name, isNull);
      expect(invito.descrizione, isNull);
      expect(invito.cosaOttieni, isEmpty);
      expect(invito.scadeIl, isNull);
    });

    /// ⚠️ Il server manda **un nome**, non un `IconData`. Una parola che questa
    /// versione non conosce non deve lasciare un buco.
    test('un\'icona sconosciuta non rompe la riga', () {
      final invito = InvitoInPalestra.fromJson({
        'cosa_ottieni': [
          {
            'icona': 'roba_del_futuro',
            'titolo': 'Cosa nuova',
            'dettaglio': 'X',
          },
        ],
      });

      expect(invito.cosaOttieni.single.icona, 'roba_del_futuro');
      expect(invito.cosaOttieni.single.titolo, 'Cosa nuova');
    });
  });

  group('la pagina mostra quello che è stato chiesto', () {
    testWidgets('congratulazioni, nome, descrizione e i due tasti', (
      tester,
    ) async {
      await tester.pumpWidget(_schermata(_rispostaDelServer()));
      await tester.pumpAndSettle();

      // 📌 «un messaggio di congratulazioni»
      expect(find.text('Ti hanno invitato!'), findsOneWidget);

      // 📌 «la descrizione della palestra»
      expect(find.text('Olimpo'), findsOneWidget);
      expect(find.textContaining('Sala pesi'), findsOneWidget);

      // 📌 «due tasti, uno per accettare e uno per rifiutare»
      expect(find.text('Entro in Olimpo'), findsOneWidget);
      expect(find.text('No, grazie'), findsOneWidget);
    });

    /// 🚨 **L'elenco viene dal server, e questo test lo dimostra**: la stessa
    /// pagina, con una risposta senza AI, non nomina l'AI.
    ///
    /// ⛔ Se l'elenco fosse scritto nell'app, la riga comparirebbe comunque — e
    /// la persona entrerebbe, cercherebbe quella funzione e non la troverebbe.
    testWidgets('con l\'AI, la riga dell\'AI si vede', (tester) async {
      await tester.pumpWidget(_schermata(_rispostaDelServer()));
      await tester.pumpAndSettle();

      expect(find.textContaining('AI'), findsOneWidget);
    });

    testWidgets('senza AI, la riga dell\'AI non c\'è', (tester) async {
      await tester.pumpWidget(_schermata(_rispostaDelServer(conAi: false)));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('AI'),
        findsNothing,
        reason:
            'La pagina promette l\'AI a una palestra che non ce l\'ha: '
            'la persona entrerebbe e non la troverebbe.',
      );

      // 💡 E il resto resta: non è sparito l'elenco, è sparita una riga.
      expect(find.text('Le schede del tuo trainer'), findsOneWidget);
    });

    /// ⚠️ La descrizione può mancare — non tutte le palestre hanno una scheda
    /// nel catalogo. La pagina deve reggere lo stesso.
    testWidgets('senza descrizione la pagina regge', (tester) async {
      await tester.pumpWidget(
        _schermata(_rispostaDelServer(descrizione: null)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Olimpo'), findsOneWidget);
      expect(find.text('Entro in Olimpo'), findsOneWidget);
    });

    /// ⛔ **Non si entra per sbaglio**: accettare sposta una persona dentro
    /// un'organizzazione, e da lì si esce solo parlando con loro.
    /// 🆕 🔑 **Chi non ha una sessione trova due porte** — 17/09/2026.
    ///
    /// ⛔ **Prima il tasto diceva «Entro in Olimpo» a chiunque.** Chi non aveva
    /// un account lo premeva, la richiesta partiva senza sessione e tornava un
    /// errore tecnico: un vicolo cieco, e proprio per la persona che l'invito
    /// esiste per raggiungere. 🔬 Provato sull'emulatore con i dati puliti.
    ///
    /// 📌 Il committente, dopo averlo visto: *«e se sono su un telefono nuovo
    /// o semplicemente non ho fatto il login? Non mi deve mandare per forza
    /// alla registrazione»*. ⚠️ È il caso che il primo rimedio aveva
    /// dimenticato: chi riceve un invito **può avere già un account**.
    testWidgets('senza sessione si accede, e la registrazione è accanto', (
      tester,
    ) async {
      await tester.pumpWidget(
        _schermata(_rispostaDelServer(), sessioneAttiva: false),
      );
      await tester.pumpAndSettle();

      expect(find.text('Accedi'), findsOneWidget);
      expect(find.text('Non ho ancora un account'), findsOneWidget);

      // ⛔ E non si offre di entrare: senza sessione non si può, e prometterlo
      // porterebbe a un errore tecnico.
      expect(find.text('Entro in Olimpo'), findsNothing);

      // 💡 E si dice **prima** che l'invito non si perde.
      expect(find.textContaining("L'invito ti aspetta qui"), findsOneWidget);
    });

    /// ⚖️ E chi la sessione ce l'ha entra e basta: nessun passaggio in più.
    testWidgets('con la sessione si entra e basta', (tester) async {
      await tester.pumpWidget(_schermata(_rispostaDelServer()));
      await tester.pumpAndSettle();

      expect(find.text('Entro in Olimpo'), findsOneWidget);
      expect(find.text('Accedi'), findsNothing);
      expect(find.text('Non ho ancora un account'), findsNothing);
    });

    testWidgets('accettare chiede conferma', (tester) async {
      await tester.pumpWidget(_schermata(_rispostaDelServer()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Entro in Olimpo'));
      await tester.pumpAndSettle();

      expect(find.text('Entri in Olimpo?'), findsOneWidget);
      expect(
        find.textContaining('Per uscirne dovrai parlare con loro'),
        findsOneWidget,
      );

      // 💡 E si può tornare indietro senza entrare.
      await tester.tap(find.text('Aspetta'));
      await tester.pumpAndSettle();

      expect(find.text('Entri in Olimpo?'), findsNothing);
    });

    /// ⛔ **Un invito non valido non dice perché**, e non potrebbe: il server
    /// risponde lo stesso 404 a scaduto, revocato, usato e mai esistito.
    testWidgets('un invito non valido dice l\'unica cosa utile', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            invitoProvider(
              'tok',
            ).overrideWith((ref) async => throw const SocketException('no')),
          ],
          child: const MaterialApp(home: SchermataInvito(token: 'tok')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Questo invito non è più valido'), findsOneWidget);
      expect(find.textContaining('Chiedine uno nuovo'), findsOneWidget);
    });
  });

  /// 🚨 **I colori sono quelli della palestra, non quelli dell'app.**
  ///
  /// ⚠️ È l'unico momento in cui questo è vero **prima** di entrarci: la
  /// palestra si sta presentando, e presentarsi coi colori di qualcun altro è
  /// il contrario di quello che serve.
  testWidgets('la pagina si veste dei colori della palestra', (tester) async {
    await tester.pumpWidget(_schermata(_rispostaDelServer()));
    await tester.pumpAndSettle();

    final tema = Theme.of(tester.element(find.text('Ti hanno invitato!')));

    // #B71C1C — il rosso dell'Olimpo, non il teal dell'app.
    expect(tema.colorScheme.primary.toARGB32(), isNot(0xFF00897B));
  });
}
