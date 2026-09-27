import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/notifications/catalogo.dart';
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

    /// 🔄 **Cambiata il 27/09/2026, e in meglio.**
    ///
    /// ⛔ Prima una promozione **senza codice** non portava da nessuna parte, e
    /// il motivo scritto qui era: *«meglio restare dove si apre l'app che su una
    /// pagina vuota»*.
    ///
    /// 💡 Ma «Offerte per te» **non è una pagina vuota**: è l'elenco delle
    /// offerte. 🔑 Da quando la destinazione è dichiarata in catalogo
    /// (`promozione` → `offerte`), una promozione senza codice porta all'elenco
    /// invece che in nessun posto — che è quello che una persona si aspetta
    /// toccando una notifica di un'offerta.
    ///
    /// ⚠️ Resta vero il caso che conta: **un carico senza niente dentro** non
    /// muove l'app.
    test('senza niente dentro non si va da nessuna parte', () {
      expect(destinazioneDellaNotifica({}), isNull);
      expect(
        destinazioneDellaNotifica({'tipo': 'promozione'}),
        AppRoutes.offerte,
        reason:
            "💡 Senza codice non si sa QUALE offerta, ma si sa che si parla di "
            'offerte: si porta all\'elenco.',
      );
    });

    /// 🆕 📣 **Un avviso porta a casa** — 26/09/2026.
    ///
    /// ══ ⛔ IL DIFETTO CHE QUESTO TEST CHIUDE ═════════════════════════
    ///
    /// 🚨 `MandaLAvvisoInPush` manda `tipo: avviso` dal 24/09, e il suo
    /// commento prometteva che *«toccando la notifica l'app sa quale modale
    /// aprire»*. ⛔ Non era vero: `avviso` non era gestito, e il tocco non
    /// faceva **niente**.
    ///
    /// ⚠️ Non si vedeva perché le push non partivano: il sintomo del difetto
    /// era **identico** a quello atteso. 💡 È saltato fuori il giorno che
    /// Firebase si è acceso.
    ///
    /// 💡 Porta a **casa** e non a una pagina dell'avviso, perché quella
    /// pagina non esiste: l'avviso è una modale che compare da sé al rientro.
    test('un avviso porta alla casa, dove la modale compare da sola', () {
      expect(
        destinazioneDellaNotifica({'tipo': 'avviso', 'avviso_id': '7'}),
        AppRoutes.home,
      );
    });

    /// 🗺️ **Le sezioni note** — 26/09/2026, spostate su `dove` il 27/09.
    ///
    /// 📌 Il committente: *«la prossima notifica mandami — che ne so — alla
    /// pagina degli allenamenti»*.
    ///
    /// ══ 🔄 COSA E' CAMBIATO, E PERCHE' NON SI E' PERSO NIENTE ═════════════
    ///
    /// ⛔ Prima queste sezioni si chiedevano nel campo **`tipo`**. 🚨 Ma `tipo`
    /// è il **tipo di notifica** — `incasso_fallito`, `stima_pronta` — e nessuna
    /// notifica si è mai chiamata `allenamenti`: quella mappa non è mai stata
    /// raggiunta da un carico vero. Due significati nello stesso campo, e uno
    /// dei due morto.
    ///
    /// 🔑 Dal 27/09 la sezione si chiede nel campo **`dove`**, che esiste per
    /// questo. ⚠️ La richiesta del committente è servita meglio di prima: il
    /// nome si può mandare **insieme** al tipo, invece che al posto suo.
    test('una sezione conosciuta porta alla sua pagina', () {
      expect(destinazioneDellaNotifica({'dove': 'allenamenti'}), AppRoutes.training);
      expect(destinazioneDellaNotifica({'dove': 'diario'}), AppRoutes.diary);
      expect(destinazioneDellaNotifica({'dove': 'progressi'}), AppRoutes.progress);
      expect(destinazioneDellaNotifica({'dove': 'messaggi'}), AppRoutes.chat);
      expect(destinazioneDellaNotifica({'dove': 'profilo'}), AppRoutes.profile);
      expect(destinazioneDellaNotifica({'dove': 'casa'}), AppRoutes.home);

      /*
       * 🚨 E il vecchio modo **non** funziona più, deliberatamente: un tipo di
       * notifica che non esiste non porta da nessuna parte, anche se per caso si
       * chiama come una sezione.
       */
      expect(destinazioneDellaNotifica({'tipo': 'allenamenti'}), isNull);
    });

    /// 🚨 **Un percorso qualunque non apre niente.**
    ///
    /// ⛔ Quello che arriva in una notifica è testo che viene da fuori:
    /// accettare un indirizzo libero vorrebbe dire far navigare l'app dove dice
    /// il messaggio. 💡 Le destinazioni sono **dichiarate**, e ciò che non è
    /// in elenco non porta da nessuna parte.
    test('un tipo sconosciuto o un percorso libero non portano niente', () {
      expect(destinazioneDellaNotifica({'tipo': 'inventato'}), isNull);
      expect(destinazioneDellaNotifica({'rotta': '/profilo/i-miei-utenti'}), isNull);
      expect(destinazioneDellaNotifica({'tipo': '/allenamento'}), isNull);
    });

    /// 🆕 🧭 **La destinazione la dichiara il catalogo** — 27/09/2026.
    ///
    /// 📌 Il committente: *«ci deve essere un altro parametro nelle notifiche:
    /// dove rimanda. Cioè a che pagina dell'app o a che url»*.
    ///
    /// 🔑 Queste sono le notifiche **vere** del catalogo, quelle che il server
    /// manda davvero. ⛔ Le sezioni provate qui sopra — `allenamenti`,
    /// `progressi`, `profilo` — non sono tipi di notifica e non lo sono mai
    /// stati: restano valide come **nomi di destinazione**, ed è la differenza
    /// che il rifacimento del 27/09 ha messo in chiaro.
    test('ogni notifica del catalogo porta dove ha dichiarato', () {
      expect(
        destinazioneDellaNotifica({'tipo': 'incasso_fallito'}),
        AppRoutes.acquisti,
        reason: '💳 Chi non ha incassato va dove si paga.',
      );
      expect(
        destinazioneDellaNotifica({'tipo': 'abbonamento_in_scadenza'}),
        AppRoutes.acquisti,
      );
      expect(
        destinazioneDellaNotifica({'tipo': 'servizio_riattivato'}),
        AppRoutes.acquisti,
      );
      expect(
        destinazioneDellaNotifica({'tipo': 'stima_pronta'}),
        AppRoutes.diary,
      );
      expect(
        destinazioneDellaNotifica({'tipo': 'slot_deciso'}),
        AppRoutes.chat,
        reason:
            "🎟️ La riceve l'ALLIEVO, e la decisione si vede nella chat: "
            '⛔ non «i miei utenti», che è la schermata di chi ha deciso.',
      );
      expect(
        destinazioneDellaNotifica({'tipo': 'import_pronto'}),
        AppRoutes.home,
        reason:
            '📄 ⚠️ Debito noto: nessuna rotta riapre QUELLA bozza, e '
            "/schede/importa ricomincerebbe un caricamento nuovo.",
      );
      expect(destinazioneDellaNotifica({'tipo': 'invito'}), AppRoutes.home);
      expect(
        destinazioneDellaNotifica({'tipo': 'risposta_a_richiesta'}),
        AppRoutes.home,
      );
    });

    /// 🆕 ⚖️ **Nessuna notifica del catalogo resta senza destinazione.**
    ///
    /// ⛔ Una push che non porta da nessuna parte è una notifica che si può solo
    /// scartare: 🚨 e non si vedrebbe come un difetto, si vedrebbe come «l'ho
    /// toccata e non è successo niente» — che è esattamente il sintomo con cui
    /// il difetto di `avviso` è sopravvissuto due giorni a settembre.
    test('e nessuna push del catalogo è senza destinazione', () {
      for (final n in Notifica.push) {
        expect(
          n.destinazione,
          isNotNull,
          reason:
              '🚨 ${n.valore} parte dal server e non dichiara dove porta: '
              'aggiungila in catalogo.dart E in App\\Enums\\Notifica.',
        );
        expect(
          destinazioneDellaNotifica({'tipo': n.valore}),
          isNotNull,
          reason:
              "🚨 ${n.valore} dichiara «${n.destinazione}», ma quel nome non è "
              'in _leDestinazioni: il tocco non porterebbe da nessuna parte.',
        );
      }
    });

    /// 🆕 🚨 **`dove` è un nome, e resta un nome.**
    ///
    /// ⛔ Il campo nuovo è la tentazione di farci passare un percorso. 💡 Questo
    /// test è il chiodo: un percorso in `dove` non apre niente, e nemmeno un
    /// nome inventato.
    test('un percorso dentro `dove` non apre niente', () {
      expect(
        destinazioneDellaNotifica({'tipo': 'fantasma', 'dove': '/acquisti'}),
        isNull,
      );
      expect(
        destinazioneDellaNotifica({'dove': AppRoutes.deleteAccount}),
        isNull,
        reason:
            "🚨 Il caso che conta: se bastasse un percorso, una notifica "
            "potrebbe portare chiunque sulla pagina che cancella l'account.",
      );
      expect(
        destinazioneDellaNotifica({'tipo': 'fantasma', 'dove': 'inventato'}),
        isNull,
      );
    });

    /// 🆕 💡 **`dove` serve per le notifiche che questa versione non conosce.**
    ///
    /// ⚠️ Il server si aggiorna **prima** dei telefoni: una notifica aggiunta
    /// oggi arriva a un'app di un mese fa, che non ha il suo caso in catalogo.
    /// 💡 Col nome nel carico quella notifica porta comunque in una sezione —
    /// purché sia una di quelle in elenco, quindi senza aprire la porta a nulla.
    test('un tipo che non conosciamo ancora porta dove dice `dove`', () {
      expect(
        destinazioneDellaNotifica({'tipo': 'roba_del_futuro', 'dove': 'diario'}),
        AppRoutes.diary,
      );
    });

    /// 🆕 🔑 **Fra il catalogo e il carico, vince il catalogo.**
    ///
    /// ⚖️ I due sono tenuti uguali da `catalogo_delle_notifiche_test.dart`, e
    /// quando si discostano la copia di cui fidarsi è la **nostra**: ⛔ un
    /// carico vecchio, storto o manomesso non deve poter spostare l'app da dove
    /// questa versione ha dichiarato che si va.
    test('e se il carico dice altro, il catalogo ha ragione', () {
      expect(
        destinazioneDellaNotifica({'tipo': 'stima_pronta', 'dove': 'profilo'}),
        AppRoutes.diary,
      );
    });
  });
}
