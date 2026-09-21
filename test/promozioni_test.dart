import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/notifications/notifiche_push.dart';
import 'package:training_companion/src/core/router/app_router.dart';
import 'package:training_companion/src/features/auth/auth_controller.dart';
import 'package:training_companion/src/features/promozioni/data/promozioni.dart';

/// 🎁 **Le promozioni nell'app** — 24/09/2026, P8 di `plan_promozioni.md`.
///
/// Due cose che, se si rompono, non danno errore: un'offerta letta male mostra
/// un tasto «Attiva» che non c'è (o lo nasconde), e un link amico aperto
/// senza sessione finisce al login e **il codice si perde**.
void main() {
  group('Offerta.fromJson', () {
    test('legge quello che manda il server', () {
      final o = Offerta.fromJson({
        'codice': 'REGALO10',
        'nome': 'Benvenuto',
        'descrizione': 'Per chi arriva',
        'cosa': '10 gettoni in regalo',
        'scade_il': '2026-10-01T00:00:00+00:00',
        'attivabile': true,
        'in_sospeso': false,
        'si_usa_pagando': false,
      });

      expect(o.codice, 'REGALO10');
      expect(o.cosa, '10 gettoni in regalo');
      expect(o.attivabile, isTrue);
      expect(o.inSospeso, isFalse);
      expect(o.scadeIl, isNotNull);
    });

    /// ⚠️ Un campo che manca non è un `true`: il tasto non deve comparire.
    test('i campi che mancano non accendono niente', () {
      final o = Offerta.fromJson({'codice': 'X', 'nome': 'Y', 'cosa': 'Z'});

      expect(o.attivabile, isFalse);
      expect(o.siUsaPagando, isFalse);
      expect(o.scadeIl, isNull);
    });
  });

  group('il link amico', () {
    /// 🚨 Chi apre `/amico/{codice}` senza sessione **resta lì**: al login il
    /// codice sparirebbe, come succedeva agli inviti prima del 17/09.
    test('senza sessione non si viene mandati via', () {
      expect(
        destinazione(
          stato: AuthStatus.loggedOut,
          sceltaFatta: false,
          posizione: '${AppRoutes.amico}/ABCD1234',
        ),
        isNull,
      );
    });

    test('e nemmeno con la sessione', () {
      expect(
        destinazione(
          stato: AuthStatus.loggedIn,
          sceltaFatta: true,
          posizione: '${AppRoutes.amico}/ABCD1234',
        ),
        isNull,
      );
    });
  });

  group("il link di un'offerta", () {
    /// 🚨 Come il link amico: senza sessione il codice non si perde al login.
    test('senza sessione non si viene mandati via', () {
      expect(
        destinazione(
          stato: AuthStatus.loggedOut,
          sceltaFatta: true,
          posizione: '${AppRoutes.promo}/AUTUNNO',
        ),
        isNull,
      );
    });
  });

  group('il tocco su una notifica', () {
    /// 📌 «il tocco su una notifica deve aprire l'offerta».
    test('una promozione apre la sua offerta', () {
      expect(
        destinazioneDellaNotifica({'tipo': 'promozione', 'codice': 'AUTUNNO'}),
        '${AppRoutes.offerte}?codice=AUTUNNO',
      );
    });

    test('un messaggio apre la chat', () {
      expect(
        destinazioneDellaNotifica({'conversation_id': '12'}),
        AppRoutes.chat,
      );
    });

    /// ⚠️ Una promozione senza codice non porta da nessuna parte: meglio
    /// restare dove si apre l'app che su una pagina vuota.
    test('senza indirizzo non si va da nessuna parte', () {
      expect(destinazioneDellaNotifica({'tipo': 'promozione'}), isNull);
      expect(destinazioneDellaNotifica({}), isNull);
    });
  });
}
