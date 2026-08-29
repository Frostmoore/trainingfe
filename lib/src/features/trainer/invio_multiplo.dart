import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/crypto/contenuto_messaggio.dart';
import '../chat/chat_controller.dart';
import 'data/utente_seguito.dart';

/// Mandare **la stessa scheda a più allievi** — 3b-U.1.
///
/// ══ 📌 LA RICHIESTA ═══════════════════════════════════════════════════════
///
/// *«Nella finestra delle chat deve poter selezionare tutti i suoi allievi (gli
/// user registrati con lui)»*.
///
/// ══ 🚨 NON ESISTE, E NON DEVE ESISTERE, UN «GRUPPO» ═══════════════════════
///
/// La chat è cifrata **da un capo all'altro, per conversazione**: mandare una
/// scheda a venti persone vuol dire **venti buste cifrate**, una per
/// conversazione, ciascuna con la chiave di quella persona.
///
/// ⛔ Un «invio di gruppo» vero richiederebbe una chiave condivisa fra venti
/// telefoni — cioè smontare la garanzia su cui è costruita tutta la chat, per
/// risparmiare diciannove richieste.
///
/// 💡 Quindi **il ciclo sta qui, nell'app**, e il server continua a instradare
/// buste che non capisce. Non c'è nessun endpoint nuovo, e non ce ne sarà uno.
///
/// ══ ⛔ E PASSA DALL'INVIO SINGOLO, NON LO RIFÀ ════════════════════════════
///
/// [ThreadController.inviaContenuto] è l'unico posto che cifra. Due strade per
/// la stessa cosa vanno bene **finché la seconda passa dalla prima**: qui si
/// chiama N volte quella, e non si tocca una riga di crittografia.
///
/// 🚨 Se un giorno la cifratura cambia, cambia in un posto solo. Una copia qui
/// sarebbe la meno provata delle due, e quella che diverge per prima.
class InvioMultiploDiSchede {
  const InvioMultiploDiSchede(this._ref);

  final Ref _ref;

  /// Manda [scheda] a ciascuno dei [destinatari], e dice **com'è andata a
  /// ciascuno**.
  ///
  /// ── 🚨 L'esito è per persona, non complessivo ────────────────────────────
  ///
  /// Con venti invii qualcuno fallisce: rete che cade a metà, chiave della
  /// persona non ancora pubblicata, conversazione mai aperta.
  ///
  /// ⛔ Un «non è riuscito» solo non dice **a chi è arrivata**, e il trainer
  /// non ha nessun modo di saperlo: rimanderebbe a tutti — e chi l'aveva già
  /// ricevuta se la ritrova due volte — oppure a nessuno.
  ///
  /// 💡 Per questo si torna una lista di [EsitoInvio] e non un `bool`.
  ///
  /// ⚠️ **Uno per volta e non in parallelo.** Venti richieste insieme su rete
  /// mobile è il modo migliore per farne fallire otto per timeout e far
  /// sembrare rotto qualcosa che funziona.
  Future<List<EsitoInvio>> manda({
    required Map<String, dynamic> scheda,
    required List<UtenteSeguito> destinatari,
  }) async {
    /*
     * 🚨 R4 — la copia che parte non ha il promemoria di chi l'ha scritta.
     *
     * ⚠️ Si toglie **una volta sola, qui**, e non dentro il ciclo: dimenticarlo
     * su una delle venti copie manderebbe l'appunto privato del trainer a una
     * persona sola, che è il modo in cui questo difetto non si vede.
     */
    final perLAllievo = Map<String, dynamic>.from(scheda)
      ..remove('rif_allievo');

    final esiti = <EsitoInvio>[];

    final aUno = _ref.read(inviaSchedaAProvider);

    for (final persona in destinatari) {
      try {
        await aUno(persona.id, perLAllievo);

        esiti.add(EsitoInvio.riuscito(persona));
      } on Object catch (e) {
        /*
         * 🚨 **Si prende nota e si va avanti** — U.1.3.
         *
         * ⛔ Fermarsi al primo errore lascerebbe metà degli allievi senza
         * scheda **e senza che nessuno lo sappia**: il trainer vedrebbe un
         * errore e non avrebbe modo di capire a chi era già arrivata.
         */
        esiti.add(EsitoInvio.fallito(persona, '$e'));
      }
    }

    return esiti;
  }
}

/// Manda **una** scheda a **una** persona: apre il filo e ci mette la busta.
///
/// ── ⛔ È l'unica strada, e per questo ha un nome ─────────────────────────
///
/// U.1.5 dice che l'invio multiplo non deve reimplementare niente: deve
/// chiamare N volte l'invio singolo. 🚨 Finché quelle due righe stavano dentro
/// il ciclo, quella era una **promessa scritta in un commento** — nessuno
/// impediva a qualcuno di aggiungerci una scorciatoia. Un passo con una firma
/// la rende una cosa vera.
///
/// 💡 Ed è anche il punto in cui i test possono infilare un guasto finto, che è
/// l'unico modo di provare «un fallimento non ferma gli altri» senza montare la
/// crittografia dentro un test.
///
/// ⚠️ **U.1.4 — chi non ha mai aperto una conversazione**: la scheda va in un
/// filo che non esiste ancora, quindi si apre prima. Il server è idempotente
/// (`Conversation::between()`), quindi per chi ce l'ha già non ne nasce una
/// seconda — e chi tocca due volte non si ritrova due fili con la stessa
/// persona.
final inviaSchedaAProvider =
    Provider<Future<void> Function(int, Map<String, dynamic>)>((ref) {
      return (int utenteId, Map<String, dynamic> scheda) async {
        final conversazione = await ref.read(apriConversazioneProvider)(
          utenteId,
        );

        await ref
            .read(threadProvider(conversazione).notifier)
            .inviaContenuto(ContenutoScheda(scheda));
      };
    });

/// Com'è andata con **una** persona.
class EsitoInvio {
  const EsitoInvio._(this.persona, this.errore);

  const EsitoInvio.riuscito(UtenteSeguito persona) : this._(persona, null);

  const EsitoInvio.fallito(UtenteSeguito persona, String errore)
    : this._(persona, errore);

  final UtenteSeguito persona;

  /// `null` quando è arrivata.
  ///
  /// 💡 Si tiene il messaggio e non solo un `bool`: «chiave non trovata» e
  /// «rete assente» si risolvono in due modi diversi, e dirlo evita che il
  /// trainer riprovi venti volte una cosa che non può riuscire.
  final String? errore;

  bool get riuscito => errore == null;
}

final invioMultiploProvider = Provider(InvioMultiploDiSchede.new);
