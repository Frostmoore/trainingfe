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
  proveDellInvito();

  String? dove(
    AuthStatus stato, {
    String posizione = AppRoutes.home,
    bool sceltaFatta = true,
    String? dopoLoSblocco,
  }) => destinazione(
    stato: stato,
    sceltaFatta: sceltaFatta,
    posizione: posizione,
    dopoLoSblocco: dopoLoSblocco,
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
      expect(dove(AuthStatus.locked, sceltaFatta: false), AppRoutes.bloccata);
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

    /// 🆕 🎯 **Il difetto del 26/09**, riferito provando la prima notifica che
    /// porta da qualche parte: *«mi ha correttamente indirizzato sulla pagina
    /// degli allenamenti ma … appena autenticato mi ha mandato sulla pagina
    /// oggi»*.
    ///
    /// ⛔ La destinazione era **giusta** e veniva buttata via allo sblocco,
    /// perché questa regola conosceva una sola risposta.
    test('si torna dove si stava andando, non a casa', () {
      expect(
        dove(
          AuthStatus.loggedIn,
          posizione: AppRoutes.bloccata,
          dopoLoSblocco: AppRoutes.training,
        ),
        AppRoutes.training,
      );
    });

    /// ⚠️ E quando non c'è niente da ricordare, si fa come si è sempre fatto:
    /// 💡 il rimedio non deve cambiare il comportamento di chi apre l'app e
    /// basta, che è il caso di gran lunga più frequente.
    test('ma senza niente da ricordare si va a casa, come prima', () {
      expect(
        dove(AuthStatus.loggedIn, posizione: AppRoutes.bloccata),
        AppRoutes.home,
      );
    });

    /// 🚨 **E il ricordo non scavalca il blocco.** ⛔ Se bastasse averne uno
    /// per entrare, il blocco non bloccherebbe: finché la sessione è bloccata
    /// si va a `/bloccata` e basta, ricordo o no.
    test('un ricordo non apre la porta a chi è ancora bloccato', () {
      expect(
        dove(
          AuthStatus.locked,
          posizione: AppRoutes.training,
          dopoLoSblocco: AppRoutes.training,
        ),
        AppRoutes.bloccata,
      );
    });
  });

  /// 🆕 🧭 **Cosa si lascia ricordare** — 26/09/2026.
  ///
  /// 💡 Il pezzo che tiene il dato è separato dalla cascata apposta: la
  /// cascata resta pura, e le due cose si provano da sole.
  group('il ricordo di dove si stava andando', () {
    setUp(DoveSiStavaAndando.dimentica);

    test('si ricorda una pagina qualunque dell\'app', () {
      DoveSiStavaAndando.ricorda(AppRoutes.training);

      expect(DoveSiStavaAndando.rotta, AppRoutes.training);
    });

    /// ⛔ Ricordarsi `/bloccata` vorrebbe dire, allo sblocco, rimandare alla
    /// schermata di blocco: il router girerebbe su sé stesso.
    test('⛔ non si ricorda la schermata di blocco', () {
      DoveSiStavaAndando.ricorda(AppRoutes.bloccata);

      expect(DoveSiStavaAndando.rotta, isNull);
    });

    /// ⛔ E nemmeno le schermate d'accesso: non sono posti dove tornare.
    test('⛔ né le schermate d\'accesso', () {
      DoveSiStavaAndando.ricorda(AppRoutes.login);

      expect(DoveSiStavaAndando.rotta, isNull);
    });

    /// 🚨 L'ultimo vince: mentre lo schermo di blocco è in piedi il tocco su
    /// una notifica può ancora far cambiare idea.
    test('l\'ultimo posto visto vince sul precedente', () {
      DoveSiStavaAndando.ricorda(AppRoutes.diary);
      DoveSiStavaAndando.ricorda(AppRoutes.training);

      expect(DoveSiStavaAndando.rotta, AppRoutes.training);
    });

    /// ⚠️ Leggere non consuma: la cascata è rivalutata molte volte di fila, e
    /// un ricordo che sparisce alla prima lettura non arriverebbe mai alla
    /// regola che lo usa.
    test('⚠️ leggerlo non lo consuma', () {
      DoveSiStavaAndando.ricorda(AppRoutes.training);

      expect(DoveSiStavaAndando.rotta, AppRoutes.training);
      expect(DoveSiStavaAndando.rotta, AppRoutes.training);
    });

    /// 🔑 Chi se n'è andato non fa da bussola a chi entra dopo.
    test('🔑 si dimentica quando la sessione finisce', () {
      DoveSiStavaAndando.ricorda(AppRoutes.training);
      DoveSiStavaAndando.dimentica();

      expect(DoveSiStavaAndando.rotta, isNull);
    });
  });

  group('nessuna palestra scelta', () {
    test('porta al codice e ce lo tiene', () {
      expect(dove(AuthStatus.loggedOut, sceltaFatta: false), AppRoutes.gymCode);
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
        dove(AuthStatus.loggedOut, posizione: AppRoutes.register),
        isNull,
        reason: 'La registrazione senza palestra viene rimandata al codice.',
      );

      expect(dove(AuthStatus.loggedOut, posizione: AppRoutes.login), isNull);
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

/// 🔗 L'invito deve arrivare a destinazione — 17/09/2026.
///
/// ══ 🚨 IL DIFETTO CHE QUESTI TEST HANNO TROVATO ═══════════════════════════
///
/// ⛔ **Il link d'invito non funzionava per chi non ha una sessione**, cioè
/// esattamente la persona a cui un invito si manda.
///
/// `_public` contiene `{gymCode, login, register, gymInactive}` e `isPublic()`
/// confronta la stringa **intera**. 🚨 Due motivi perché `/invito-palestra/ABC`
/// non ci finisse dentro: non è nell'elenco, e porta un token appeso — quindi
/// nemmeno aggiungendolo il confronto esatto lo riconoscerebbe.
///
/// ⚠️ Risultato: la regola 6 mandava al **login**, e il token spariva. La
/// schermata d'accesso arrivava vestita della palestra — il branding si carica
/// per conto suo — quindi sembrava che avesse funzionato.
///
/// 🚨 **E colpiva anche chi installa dal link.** `app.dart` legge il referrer
/// del Play Store e fa `go('/invito-palestra/$token')`: quel `go` passa dalla
/// stessa cascata, quindi anche il giro «installo e entro» finiva al login.
/// Cioè l'unica strada per entrare in una palestra, da quando il codice è stato
/// tolto il 15/09.
void proveDellInvito() {
  const token = '/invito-palestra/AtE1AiDYOrfoR8yDi5IGKRX9pYwbcK1i';

  group("l'invito arriva a destinazione", () {
    /// 🚨 Il caso per cui l'invito esiste: qualcuno che non è ancora nessuno.
    test('chi non ha una sessione ci resta sopra', () {
      expect(
        destinazione(
          stato: AuthStatus.loggedOut,
          sceltaFatta: true,
          posizione: token,
        ),
        isNull,
        reason:
            'Chi apre un invito senza account viene mandato al login, e il '
            'token si perde.',
      );
    });

    /// ⚖️ E chi invece ce l'ha già non deve essere buttato a casa: sta
    /// guardando un invito, non una schermata d'accesso.
    test('e chi ce l\'ha non viene buttato dentro', () {
      expect(
        destinazione(
          stato: AuthStatus.loggedIn,
          sceltaFatta: true,
          posizione: token,
        ),
        isNull,
      );
    });

    /// 🚨 **Anche prima di aver scelto una palestra.** Chi installa dal link non
    /// è mai passato dal benvenuto: la regola 5 lo rimanderebbe lì, e l'invito
    /// sarebbe di nuovo perso.
    test('anche per chi non ha ancora scelto niente', () {
      expect(
        destinazione(
          stato: AuthStatus.loggedOut,
          sceltaFatta: false,
          posizione: token,
        ),
        isNull,
        reason: 'Chi installa dal link non è mai passato dal benvenuto.',
      );
    });

    /// 🆕 🚨 **E vale anche per la registrazione che arriva da li'.**
    ///
    /// ⛔ Il primo tentativo passava il token in una **query**
    /// (`/registrati?invito=...`), e la cascata riceve `matchedLocation`, che la
    /// query non ce l'ha: la regola 5 mandava al benvenuto chi aveva appena
    /// toccato «Crea un account». 🔬 Visto sull'emulatore.
    test('e la registrazione che ne arriva', () {
      const daInvito = '/registrati/da-invito/AtE1AiDYOrfoR8yDi5IGKRX9pYwbcK1i';

      expect(
        destinazione(
          stato: AuthStatus.loggedOut,
          sceltaFatta: false,
          posizione: daInvito,
        ),
        isNull,
        reason:
            'Chi tocca «Crea un account» da un invito finisce al benvenuto.',
      );
    });

    /// 🆕 🔑 **E l'accesso che ne arriva** — 17/09/2026.
    ///
    /// 📌 Il committente: *«se ho già un account non ha senso essere rimandati
    /// alla registrazione»*. ⚠️ Chi ha cambiato telefono passa di qui, e la
    /// regola 5 lo manderebbe al benvenuto come faceva con la registrazione.
    test("e l'accesso che ne arriva", () {
      const daInvito = '/accedi/da-invito/AtE1AiDYOrfoR8yDi5IGKRX9pYwbcK1i';

      expect(
        destinazione(
          stato: AuthStatus.loggedOut,
          sceltaFatta: false,
          posizione: daInvito,
        ),
        isNull,
        reason: 'Chi ha già un account e apre un invito finisce al benvenuto.',
      );
    });

    /// ⛔ Ma le altre schermate restano chiuse: si apre l'invito, non l'app.
    test('e non apre nient\'altro', () {
      expect(
        destinazione(
          stato: AuthStatus.loggedOut,
          sceltaFatta: true,
          posizione: AppRoutes.diary,
        ),
        AppRoutes.login,
      );
    });
  });
}
