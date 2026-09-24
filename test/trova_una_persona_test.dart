import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/account/data/nome_pubblico.dart';
import 'package:training_companion/src/features/account/nome_pubblico_controller.dart';
import 'package:training_companion/src/features/chat/ui/trova_una_persona.dart';
import 'package:training_companion/src/features/scoperta/catalogo_controller.dart';
import 'package:training_companion/src/features/scoperta/data/scheda_catalogo.dart';

/// 🔎 **«Trova una persona»** — blocco B3, 24/09/2026.
///
/// 📌 Il committente, il 23/09: *«bisognerà inventarsi un sistema di username
/// per poter scrivere a chiunque»*; e il 24/09, sull'interruttore: *«va messo un
/// toggle nella finestra della chat, in modo che non sia troppo invasivo»*.
///
/// ══ 🚨 COSA GUARDANO QUESTI TEST ════════════════════════════════════════════
///
/// ⚠️ Non «la ricerca funziona»: **chi non si deve vedere non si vede**, e
/// l'interruttore non mente. 💡 Il filtro vero sta sul server
/// (`ChiPossoCercare`): qui si prova che l'app non lo aggiri e non lo racconti
/// male.
void main() {
  final apertiDalCatalogo = <int>[];

  /// Con quali testi è stato interrogato il catalogo, in ordine.
  final catalogatiCon = <String>[];

  setUp(() {
    apertiDalCatalogo.clear();
    catalogatiCon.clear();
  });

  Future<_AzioniFinte> apri(
    WidgetTester tester, {
    NomePubblico mio = const NomePubblico(username: 'io', trovabile: false),
    List<PersonaTrovata> trovati = const [],
    List<SchedaCatalogo> schede = const [],
  }) async {
    final azioni = _AzioniFinte(trovati);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nomePubblicoProvider.overrideWith((ref) async => mio),
          nomePubblicoActionsProvider.overrideWith((ref) => azioni),

          /*
           * ⚠️ **Il catalogo va finto anche quando il test parla d'altro.**
           * ⛔ Senza, la scheda chiama davvero la rete: il test passerebbe
           * lo stesso — l'errore è gestito — ma passerebbe **per il motivo
           * sbagliato**, e nessuno se ne accorgerebbe finche' un giorno la
           * chiamata riesce.
           */
          catalogoProvider.overrideWith((ref, testo) async {
            catalogatiCon.add(testo);

            return schede;
          }),
          apriDalCatalogoProvider.overrideWith(
            (ref) => (int profiloId) async {
              apertiDalCatalogo.add(profiloId);

              return (id: 900 + profiloId, restanti: 3, nome: 'Palestra');
            },
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => TrovaUnaPersona.mostra(context),
                child: const Text('apri'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('apri'));
    await tester.pumpAndSettle();

    return azioni;
  }

  group('l\'interruttore «fatti trovare»', () {
    /// ⛔ **Nasce spento** — decisione 53.1.
    testWidgets('dice chiaramente che nessuno ti trova, quando è spento', (
      tester,
    ) async {
      await apri(tester);

      expect(find.text('Fatti trovare'), findsOneWidget);
      expect(find.textContaining('Nessuno può trovarti'), findsOneWidget);
    });

    testWidgets('acceso, dice con quale nome ti trovano', (tester) async {
      await apri(
        tester,
        mio: const NomePubblico(username: 'marco', trovabile: true),
      );

      expect(find.textContaining('Ti trovano cercando @marco'), findsOneWidget);
    });

    /// ⛔ **Senza un nome non si può accendere**: sarebbe un interruttore che
    /// non fa niente, e chi lo accende crederebbe di essere trovabile.
    testWidgets('senza nome utente non c\'è niente da accendere', (
      tester,
    ) async {
      await apri(tester, mio: const NomePubblico());

      expect(find.byType(SwitchListTile), findsNothing);
      expect(find.text('Non hai ancora un nome utente'), findsOneWidget);
    });

    testWidgets('accendendolo lo dice al server', (tester) async {
      final azioni = await apri(tester);

      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();

      expect(azioni.acceso, [true]);
    });
  });

  group('la ricerca', () {
    /// 💡 La scheda dice **prima** chi si può trovare: chi cerca un iscritto e
    /// non lo trova deve capire perché, invece di crederla rotta.
    testWidgets('spiega che gli iscritti li trovano solo i loro', (
      tester,
    ) async {
      await apri(tester);

      expect(
        find.textContaining('solo chi ha scelto di farsi trovare'),
        findsOneWidget,
      );
      expect(
        find.textContaining('gli iscritti soltanto i loro trainer'),
        findsOneWidget,
      );
    });

    testWidgets('mostra chi trova, col nome utente', (tester) async {
      await apri(
        tester,
        trovati: const [
          PersonaTrovata(id: 7, username: 'ilcoach', nome: 'Marco Coach'),
        ],
      );

      await tester.enterText(find.byType(TextField), 'ilcoach');
      await tester.tap(find.text('Cerca'));
      await tester.pumpAndSettle();

      expect(find.text('Marco Coach'), findsOneWidget);
      expect(find.text('@ilcoach'), findsOneWidget);
    });

    /// 🚨 **Il vuoto non dice «non esiste»**: dice che *potrebbe* non essersi
    /// fatto trovare. ⛔ Affermare che una persona non esiste, quando la verità
    /// è che ha scelto di non farsi cercare, è dire a chi cerca una cosa falsa —
    /// e su una persona vera.
    testWidgets('senza risultati non dichiara che quella persona non esiste', (
      tester,
    ) async {
      await apri(tester);

      await tester.enterText(find.byType(TextField), 'nessuno');
      await tester.tap(find.text('Cerca'));
      await tester.pumpAndSettle();

      expect(find.textContaining('non ha scelto di farsi trovare'), findsOneWidget);
      expect(find.textContaining('non esiste'), findsNothing);
    });

    /// ⛔ Sotto le tre lettere non si cerca: due lettere sono mille persone.
    testWidgets('con due lettere non chiede niente al server', (tester) async {
      final azioni = await apri(tester);

      await tester.enterText(find.byType(TextField), 'ma');
      await tester.tap(find.text('Cerca'));
      await tester.pumpAndSettle();

      expect(azioni.cercati, isEmpty);
    });

    testWidgets('toccando una persona si apre il filo con lei', (tester) async {
      final azioni = await apri(
        tester,
        trovati: const [
          PersonaTrovata(id: 7, username: 'ilcoach', nome: 'Marco Coach'),
        ],
      );

      await tester.enterText(find.byType(TextField), 'ilcoach');
      await tester.tap(find.text('Cerca'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Marco Coach'));
      await tester.pumpAndSettle();

      expect(azioni.scrittiA, [7]);
    });
  });

  // ── 🏋️ Le schede pubbliche, dal 24/09 ─────────────────────────────────────

  group('le palestre e i trainer nella stessa scheda', () {
    SchedaCatalogo scheda({
      int id = 1,
      String titolo = 'Palestra Olimpo',
      String tipo = 'palestra',
      String? comune = 'Bologna (BO)',
      double? km = 2.4,
      bool contattabile = true,
      bool sponsorizzato = false,
    }) => SchedaCatalogo(
      id: id,
      titolo: titolo,
      tipo: tipo,
      sponsorizzato: sponsorizzato,
      contattabile: contattabile,
      comune: comune,
      distanzaKm: km,
    );

    /// 📌 Il committente, 24/09: *«mettiamole semplicemente che si mostrano
    /// tutte nella ricerca della chat, con un criterio di vicinanza»*.
    ///
    /// 🚨 **Si vedono senza cercare niente**: è tutto il punto della richiesta.
    /// ⛔ Una schermata che si apre vuota e pretende che tu sappia già cosa
    /// scrivere non risponde alla domanda «chi c'è vicino a me?».
    testWidgets('si vedono appena si apre, senza aver cercato', (tester) async {
      await apri(tester, schede: [scheda()]);

      expect(find.text('Palestra Olimpo'), findsOneWidget);
      expect(find.textContaining('PALESTRE E TRAINER VICINO A TE'), findsOneWidget);
    });

    /// 💡 La distanza si scrive solo quando si sa: `null` non è zero.
    testWidgets('dice che cos\'è, dov\'è e quanto è lontana', (tester) async {
      await apri(tester, schede: [scheda()]);

      expect(find.text('Palestra · Bologna (BO) · 2,4 km'), findsOneWidget);
    });

    testWidgets('senza distanza non scrive «0 km»', (tester) async {
      await apri(tester, schede: [scheda(km: null)]);

      expect(find.text('Palestra · Bologna (BO)'), findsOneWidget);
      expect(find.textContaining('0 km'), findsNothing);
    });

    /// 🚨 **L'ordine è quello del server**, che sa le distanze: l'app non
    /// riordina niente. ⛔ Un secondo ordinamento qui sarebbe una regola
    /// scritta due volte, e quella dell'app non conoscerebbe le coordinate.
    testWidgets('le mostra nell\'ordine in cui arrivano', (tester) async {
      await apri(
        tester,
        schede: [
          scheda(id: 1, titolo: 'Vicina', km: 0.5),
          scheda(id: 2, titolo: 'Lontana', km: 30),
        ],
      );

      /*
       * ⚠️ **Si guarda chi sta più in alto, non la struttura dei widget.**
       * ⛔ Frugare dentro i `ListTile` per estrarne il titolo lega il test
       * all'impaginazione: cambiarla lo romperebbe senza che sia cambiato
       * niente di quello che il test dice.
       */
      final vicina = tester.getTopLeft(find.text('Vicina')).dy;
      final lontana = tester.getTopLeft(find.text('Lontana')).dy;

      expect(vicina, lessThan(lontana));
    });

    /// 🚨 Si manda **l'id della scheda**, non quello di una persona: chi sia il
    /// destinatario lo decide il server.
    testWidgets('toccandone una si apre il filo con quella scheda', (
      tester,
    ) async {
      await apri(tester, schede: [scheda(id: 7)]);

      await tester.tap(find.text('Palestra Olimpo'));
      await tester.pumpAndSettle();

      expect(apertiDalCatalogo, [7]);
    });

    /// ⛔ **Una scheda senza nessuno dietro lo dice prima**, non dopo aver
    /// fatto scrivere un messaggio che non arriverebbe da nessuna parte.
    testWidgets('una scheda non contattabile non apre niente', (tester) async {
      await apri(tester, schede: [scheda(contattabile: false)]);

      await tester.tap(find.text('Palestra Olimpo'));
      await tester.pumpAndSettle();

      expect(apertiDalCatalogo, isEmpty);
      expect(find.textContaining('non ha nessuno a cui scrivere'), findsOneWidget);
    });

    /// 🚨 **Lo sponsorizzato si etichetta, mai si mimetizza.**
    ///
    /// ⏳ Oggi non ce ne sono — le campagne sono spente dal 23/09 — ma
    /// l'etichetta c'è già: presentare a pagamento qualcosa che sembra un
    /// risultato di ricerca è pubblicità occulta, e il giorno che le campagne
    /// tornano nessuno deve **ricordarsi** di aggiungerla.
    testWidgets('una scheda sponsorizzata lo dichiara', (tester) async {
      await apri(tester, schede: [scheda(sponsorizzato: true)]);

      expect(find.text('Sponsorizzata'), findsOneWidget);
    });

    /// 🔍 **Lo stesso campo cerca tutte e due le cose.**
    ///
    /// 💡 Chi scrive «Olimpo» non sta pensando «sto cercando un nome utente
    /// oppure una palestra?»: sta cercando Olimpo.
    testWidgets('cercando si filtrano anche le schede', (tester) async {
      await apri(tester, schede: [scheda()]);

      await tester.enterText(find.byType(TextField), 'olimpo');
      await tester.tap(find.widgetWithText(FilledButton, 'Cerca'));
      await tester.pumpAndSettle();

      expect(catalogatiCon, ['', 'olimpo']);
    });

    /// ⚠️ **Il nome utente vuole tre lettere, le schede no.**
    ///
    /// ⛔ Fermare tutto sotto le tre lettere vorrebbe dire non rispondere a chi
    /// cerca una palestra che si chiama «Up», per una regola che riguarda
    /// un'altra cosa.
    testWidgets('con due lettere filtra le schede ma non cerca persone', (
      tester,
    ) async {
      final azioni = await apri(tester, schede: [scheda()]);

      await tester.enterText(find.byType(TextField), 'up');
      await tester.tap(find.widgetWithText(FilledButton, 'Cerca'));
      await tester.pumpAndSettle();

      expect(catalogatiCon, ['', 'up']);
      expect(azioni.cercati, isEmpty);
    });

    testWidgets('quando non ce ne sono, lo dice invece di restare vuota', (
      tester,
    ) async {
      await apri(tester);

      expect(
        find.textContaining('Ancora nessuna palestra o trainer'),
        findsOneWidget,
      );
    });
  });

}

class _AzioniFinte implements NomePubblicoActions {
  _AzioniFinte(this._trovati);

  final List<PersonaTrovata> _trovati;

  final acceso = <bool>[];
  final cercati = <String>[];
  final scrittiA = <int>[];

  @override
  Future<NomePubblico> famiTrovare({required bool si}) async {
    acceso.add(si);

    return NomePubblico(username: 'io', trovabile: si);
  }

  @override
  Future<List<PersonaTrovata>> cerca(String pezzo) async {
    // ⚠️ Il taglio sotto le tre lettere è **dell'app**: qui si prova che
    //    esista, quindi il finto non lo rifà.
    if (pezzo.trim().length < 3) return const [];

    cercati.add(pezzo);

    return _trovati;
  }

  @override
  Future<int> scriviA(int utenteId) async {
    scrittiA.add(utenteId);

    return 42;
  }

  @override
  Future<NomePubblico> cambia(String nuovo) async => const NomePubblico();

  @override
  Future<void> blocca(int utenteId) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
