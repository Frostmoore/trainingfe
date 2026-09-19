import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/errors/api_exception.dart';
import 'package:training_companion/src/core/router/app_router.dart';
import 'package:training_companion/src/features/auth/auth_controller.dart';
import 'package:training_companion/src/features/onboarding/invito_del_trainer_controller.dart';
import 'package:training_companion/src/features/onboarding/ui/schermata_invito_trainer.dart';

/// 🤝 L'invito di un trainer — F6.2, 17/09/2026.
///
/// ══ ⛔ PERCHE' QUESTI TEST NASCONO OGGI, E NON CON F6.2 ═══════════════════
///
/// 🚨 **Questo giro viveva sul server senza un cliente.** La pagina web diceva
/// *«apri l'app e tocca "Ho un invito"»*, e **quel pulsante non esisteva**:
/// `POST /inviti/{token}/riscatta` e `POST /auth/register-with-invite` erano
/// scritti, provati, documentati — e non li chiamava nessuno.
///
/// ⚠️ Trovato cercando dove mettere la modale della sovrapposizione
/// (AH.1-ter.4): non c'era **nessuna** schermata dove metterla.
void main() {
  Widget schermata({String? trainer = 'Anna', bool sessioneAttiva = true}) =>
      ProviderScope(
        overrides: [
          invitoDelTrainerProvider('tok').overrideWith(
            (ref) async => InvitoDelTrainer(trainer: trainer, scadeIl: null),
          ),
          sessioneAttivaProvider.overrideWithValue(sessioneAttiva),
        ],
        child: const MaterialApp(home: SchermataInvitoTrainer(token: 'tok')),
      );

  group('la pagina dice chi invita e cosa cambia', () {
    testWidgets('il nome di chi invita, in cima', (tester) async {
      await tester.pumpWidget(schermata());
      await tester.pumpAndSettle();

      expect(find.text('Anna ti ha invitato'), findsOneWidget);
      expect(
        find.text('Accettando, Anna diventa il tuo trainer.'),
        findsOneWidget,
      );
    });

    /// 💡 **Le tre cose che cambiano**, non una lista di vantaggi: è quello che
    /// quella persona vedrà succedere, e che ha il diritto di sapere prima.
    testWidgets('le tre cose che cambiano', (tester) async {
      await tester.pumpWidget(schermata());
      await tester.pumpAndSettle();

      expect(find.text('Ti manda le schede'), findsOneWidget);
      expect(find.text('Potete scrivervi senza limiti'), findsOneWidget);
      // ⛔ «Vede i tuoi allenamenti» era falso (giro del 18/09): il trainer
      // riceve nome, email e foto. Non deve tornare.
      expect(find.text('I tuoi dati restano tuoi'), findsOneWidget);
      expect(find.text('Vede i tuoi allenamenti'), findsNothing);
    });

    /// ⚠️ Il server può non dire il nome: la pagina non deve scrivere «null».
    testWidgets('senza il nome la pagina regge', (tester) async {
      await tester.pumpWidget(schermata(trainer: null));
      await tester.pumpAndSettle();

      expect(find.text('Un trainer ti ha invitato'), findsOneWidget);
    });
  });

  group('le due porte', () {
    /// 🚨 Chi ha una sessione accetta e basta.
    testWidgets('con la sessione si accetta', (tester) async {
      await tester.pumpWidget(schermata());
      await tester.pumpAndSettle();

      expect(find.text('Accetto'), findsOneWidget);
      expect(find.text('Accedi'), findsNothing);
    });

    /// ⛔ **E chi non ce l'ha non viene mandato per forza a registrarsi.**
    ///
    /// 📌 Il committente, sull'invito della palestra: *«se ho già un account non
    /// ha senso essere rimandati alla registrazione»*. ⚠️ Vale identico qui.
    testWidgets('senza sessione si accede, e la registrazione è accanto', (
      tester,
    ) async {
      await tester.pumpWidget(schermata(sessioneAttiva: false));
      await tester.pumpAndSettle();

      expect(find.text('Accedi'), findsOneWidget);
      expect(find.text('Non ho ancora un account'), findsOneWidget);
      expect(find.text('Accetto'), findsNothing);
      expect(find.textContaining("L'invito ti aspetta qui"), findsOneWidget);
    });
  });

  /// 🚨 **I due inviti non si confondono** — la trappola del manifest, vista
  /// dal lato delle rotte.
  ///
  /// ⛔ `/invito` come **prefisso** catturerebbe anche `/invito-palestra/xyz`:
  /// l'invito di una palestra aperto sulla schermata di un trainer, senza
  /// nessun errore.
  group('i due inviti restano distinti', () {
    test('ognuno ha il suo percorso', () {
      expect(AppRoutes.invito, '/invito-palestra');
      expect(AppRoutes.invitoTrainer, '/invito');
    });

    test('e tutti e sei passano la cascata del router', () {
      for (final dove in [
        '${AppRoutes.invito}/tok',
        '${AppRoutes.invitoTrainer}/tok',
        '${AppRoutes.loginDaInvito}/tok',
        '${AppRoutes.loginDaInvitoTrainer}/tok',
        '${AppRoutes.registerDaInvito}/tok',
        '${AppRoutes.registerDaInvitoTrainer}/tok',
      ]) {
        expect(
          destinazione(
            stato: AuthStatus.loggedOut,
            sceltaFatta: false,
            posizione: dove,
          ),
          isNull,
          reason: '$dove non arriva a destinazione.',
        );
      }
    });
  });

  /// 🚨 **Il 409 è una domanda, non un errore** — AH.1-ter.4.
  ///
  /// ⛔ Senza una classe sua cadrebbe nel ramo generico dei 409 e diventerebbe
  /// *«qualcosa non ha funzionato, riprova»*. 💡 E riprovare non può
  /// funzionare: non c'è niente di rotto, manca una **risposta**.
  test('«ti segue già qualcuno» porta il nome dell\'altro', () {
    const e = TiSegueGiaQualcunoException('Ti segue già Anna.', 'Anna');

    expect(e.chiTiSegue, 'Anna');
    expect(TiSegueGiaQualcunoException.codice, 'hai_gia_un_trainer');
  });
}
