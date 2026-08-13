import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/router/app_router.dart';
import 'package:training_companion/src/features/auth/auth_controller.dart';

/// Dove si può stare — la cascata del `redirect`.
///
/// ── 🚨 Perché questi test esistono ────────────────────────────────────────
///
/// Il 12/08/2026, provando l'app su un telefono vero: l'impronta sbloccava e
/// **non succedeva niente**. Si restava sulla pagina «App bloccata», senza
/// errori e senza log.
///
/// La causa era che `/bloccata` non è fra le rotte pubbliche, quindi la regola
/// «autenticato su una schermata di accesso → dentro» non la riconosceva —
/// e in quella cascata **«nessuna regola si applica» significa «resta dove
/// sei»**. È il modo più silenzioso di lasciare qualcuno in un vicolo cieco:
/// non c'è niente da cercare in un log.
///
/// ⚠️ Finché la decisione viveva dentro una closure di `GoRouter` non era
/// verificabile senza montare tutta l'app. Estratta in `destinazione()`, si
/// prova in venti righe.
void main() {
  String? dove(
    AuthStatus stato, {
    String posizione = AppRoutes.home,
    bool sceltaFatta = true,
  }) => destinazione(
    stato: stato,
    sceltaFatta: sceltaFatta,
    posizione: posizione,
  );

  group('mentre si legge il token', () {
    /// ⚠️ Decidere adesso manderebbe al login **ogni** utente a ogni avvio, per
    /// la frazione di secondo che serve a leggere il Keychain. E quel salto si
    /// vede.
    test('non si decide niente, da nessuna posizione', () {
      expect(dove(AuthStatus.unknown), isNull);
      expect(dove(AuthStatus.unknown, posizione: AppRoutes.login), isNull);
      expect(dove(AuthStatus.unknown, posizione: AppRoutes.bloccata), isNull);
    });
  });

  group('palestra sospesa', () {
    test('porta alla schermata dedicata e ce la tiene', () {
      expect(dove(AuthStatus.gymInactive), AppRoutes.gymInactive);
      expect(
        dove(AuthStatus.gymInactive, posizione: AppRoutes.gymInactive),
        isNull,
      );
    });

    /// 🚨 Viene prima del blocco e prima della palestra: chi è in questo stato
    /// ha le credenziali giuste e non può farci niente.
    test('vince anche su una posizione qualsiasi', () {
      expect(
        dove(AuthStatus.gymInactive, posizione: AppRoutes.diary),
        AppRoutes.gymInactive,
      );
    });
  });

  group('sessione bloccata', () {
    test('porta alla schermata di blocco e ce la tiene', () {
      expect(dove(AuthStatus.locked), AppRoutes.bloccata);
      expect(dove(AuthStatus.locked, posizione: AppRoutes.bloccata), isNull);
    });

    /// 🚨 Il blocco viene **prima** del controllo sulla palestra: il branding si
    /// legge dalla cache locale, quindi a schermo bloccato l'app saprebbe già
    /// di che colore essere e passerebbe oltre. Mostrare qualunque schermata a
    /// chi non ha sbloccato vorrebbe dire che il blocco non blocca niente.
    test('blocca anche senza palestra scelta', () {
      expect(
        dove(AuthStatus.locked, sceltaFatta: false),
        AppRoutes.bloccata,
      );
    });
  });

  group('quando si sblocca', () {
    /// 🎯 **Il test del difetto.** Prima tornava `null`, cioè «resta dove sei»,
    /// e l'impronta sembrava non funzionare.
    test('si esce dalla schermata di blocco', () {
      expect(
        dove(AuthStatus.loggedIn, posizione: AppRoutes.bloccata),
        AppRoutes.home,
      );
    });

    /// 🚨 L'altra metà, quella che si romperebbe «rimediando» con `_public`.
    ///
    /// «Entra con la password» porta a `loggedOut`: se `/bloccata` fosse fra le
    /// rotte pubbliche, si resterebbe **inchiodati lì** invece di andare al
    /// login — un vicolo cieco scambiato con un altro.
    test('«entra con la password» porta al login, non lascia lì', () {
      expect(
        dove(AuthStatus.loggedOut, posizione: AppRoutes.bloccata),
        AppRoutes.login,
      );
    });
  });

  group('nessuna palestra scelta', () {
    test('porta al codice e ce lo tiene', () {
      expect(
        dove(AuthStatus.loggedOut, sceltaFatta: false),
        AppRoutes.gymCode,
      );
      expect(
        dove(
          AuthStatus.loggedOut,
          sceltaFatta: false,
          posizione: AppRoutes.gymCode,
        ),
        isNull,
      );
    });

    /// 🚨 **Il difetto del 13/08/2026, provando la `v6.3.0`.**
    ///
    /// *«Se clicco su "non ho un codice" non succede niente.»*
    ///
    /// ⚠️ La causa era **questa regola**, e il nome del parametro la
    /// nascondeva: si chiamava `haPalestra` e leggeva `hasGym`, quindi chi
    /// sceglieva di non avere una palestra restava **indistinguibile** da chi
    /// non aveva ancora scelto. `context.go('/registrati')` partiva davvero, e
    /// il `redirect` lo rimandava **allo stesso schermo** un istante dopo:
    /// nessun errore, nessun movimento.
    ///
    /// 💡 Le due domande sono diverse: *«di che colore mi vesto?»* la risponde
    /// `hasGym`; *«posso andare avanti?»* la risponde `sceltaFatta`.
    test('chi ha scelto di NON avere una palestra può andare avanti', () {
      // Ha scelto: `sceltaFatta` è vero anche se `hasGym` è falso.
      expect(
        dove(
          AuthStatus.loggedOut,
          posizione: AppRoutes.register,
        ),
        isNull,
        reason: 'La registrazione senza palestra viene rimandata al codice.',
      );

      expect(
        dove(AuthStatus.loggedOut, posizione: AppRoutes.login),
        isNull,
      );
    });

    /// ⚠️ E il contrario resta vero: chi **non ha ancora scelto** non deve
    /// poter arrivare alla registrazione, o l'app non saprebbe dove iscriverlo.
    test('chi non ha ancora scelto viene riportato al codice', () {
      expect(
        dove(
          AuthStatus.loggedOut,
          sceltaFatta: false,
          posizione: AppRoutes.register,
        ),
        AppRoutes.gymCode,
      );
    });
  });

  group('sessione assente', () {
    test('le schermate d\'accesso si possono vedere', () {
      expect(dove(AuthStatus.loggedOut, posizione: AppRoutes.login), isNull);
      expect(dove(AuthStatus.loggedOut, posizione: AppRoutes.register), isNull);
    });

    test('tutto il resto porta al login', () {
      expect(dove(AuthStatus.loggedOut), AppRoutes.login);
      expect(
        dove(AuthStatus.loggedOut, posizione: AppRoutes.diary),
        AppRoutes.login,
      );
    });
  });

  group('sessione valida', () {
    test('si sta dove si è', () {
      expect(dove(AuthStatus.loggedIn), isNull);
      expect(dove(AuthStatus.loggedIn, posizione: AppRoutes.diary), isNull);
      expect(dove(AuthStatus.loggedIn, posizione: AppRoutes.profile), isNull);
    });

    test('ma non su una schermata d\'accesso', () {
      expect(
        dove(AuthStatus.loggedIn, posizione: AppRoutes.login),
        AppRoutes.home,
      );
      expect(
        dove(AuthStatus.loggedIn, posizione: AppRoutes.gymCode),
        AppRoutes.home,
      );
    });
  });

  /// ⚠️ Nessuno stato deve poter lasciare qualcuno **fermo** su una schermata
  /// che non può usare. È la proprietà che il difetto del 12/08 ha violato, ed
  /// è quella che si dimentica di verificare aggiungendo uno stato nuovo.
  test('da /bloccata si esce sempre, tranne quando si è bloccati', () {
    for (final stato in AuthStatus.values) {
      final destino = dove(stato, posizione: AppRoutes.bloccata);

      if (stato == AuthStatus.locked || stato == AuthStatus.unknown) {
        expect(destino, isNull, reason: '$stato deve poter restare');
      } else {
        expect(
          destino,
          isNotNull,
          reason: '$stato resterebbe inchiodato su /bloccata',
        );
      }
    }
  });
}

