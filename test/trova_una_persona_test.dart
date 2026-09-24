import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/account/data/nome_pubblico.dart';
import 'package:training_companion/src/features/account/nome_pubblico_controller.dart';
import 'package:training_companion/src/features/chat/ui/trova_una_persona.dart';

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
  Future<_AzioniFinte> apri(
    WidgetTester tester, {
    NomePubblico mio = const NomePubblico(username: 'io', trovabile: false),
    List<PersonaTrovata> trovati = const [],
  }) async {
    final azioni = _AzioniFinte(trovati);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nomePubblicoProvider.overrideWith((ref) async => mio),
          nomePubblicoActionsProvider.overrideWith((ref) => azioni),
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
        find.textContaining('Gli iscritti li trovano soltanto i loro trainer'),
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
