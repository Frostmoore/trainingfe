import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/storage/local_cache.dart';
import 'data/gym_branding.dart';

/// Lo stato dell'onboarding white-label — A2.1 / A2.2 / A2.5.
class BrandingState {
  const BrandingState({
    required this.branding,
    this.joinCode,
    this.senzaPalestra = false,
    this.sceltaFatta = false,
    this.isLoading = false,
  });

  final GymBranding branding;
  final String? joinCode;

  /// 🚨 Ha scelto **di non averne una** — F3.
  final bool senzaPalestra;

  final bool isLoading;

  /// `true` quando l'utente ha già scelto una palestra.
  bool get hasGym => joinCode != null && joinCode!.isNotEmpty;

  /// 🚨 **Ha fatto la scelta**, qualunque essa sia — F3.
  ///
  /// ⚠️ **Non è `hasGym`, ed è il difetto del 13/08/2026.** Il router usava
  /// `hasGym` per decidere se mandare alla schermata del codice, e così «non ho
  /// una palestra» e «non ho ancora scelto» erano lo stesso stato: chi toccava
  /// «continuo senza palestra» veniva rimandato indietro **allo stesso schermo**,
  /// e per lui non succedeva niente.
  ///
  /// 💡 Le due domande sono diverse e vanno tenute separate: *«di che colore mi
  /// vesto?»* la risponde `hasGym`; *«posso andare avanti?»* la risponde questa.
  ///
  /// ⛔ **E non è più nemmeno `hasGym || senzaPalestra`** — 3b-J.1. Quella
  /// deduzione
  /// valeva quando entrambi gli stati nascevano dalla schermata del codice;
  /// adesso `joinCode` non lo scrive più nessuno e `senzaPalestra` torna
  /// `false` appena si adotta il branding del server. 🚨 Risultato: dopo il
  /// login «la scelta è fatta» diventava falsa, e il router rimandava al
  /// benvenuto chi era appena entrato.
  final bool sceltaFatta;
}

/// Il branding della palestra: dalla cache subito, dalla rete dopo.
///
/// 🚨 **L'ordine è quello e non l'inverso.** Al secondo avvio l'app si apre già
/// vestita dei colori giusti, e la richiesta di rete aggiorna in sottofondo. Un
/// avvio che aspetta la rete per decidere di che colore essere mostra mezzo
/// secondo di bianco a ogni apertura, ed è la prima cosa che si nota di un'app
/// white-label — proprio la cosa che deve funzionare bene.
class BrandingController extends StateNotifier<BrandingState> {
  BrandingController(this._cache)
    : super(
        BrandingState(
          // Avvio a caldo: se c'è una cache, si parte da lì.
          branding: _cache.branding != null
              ? GymBranding.fromJson(_cache.branding!)
              : GymBranding.neutral,
          joinCode: _cache.joinCode,

          // ⚠️ Si rilegge dal disco all'avvio: la scelta deve sopravvivere a
          // una chiusura dell'app a metà registrazione.
          senzaPalestra: _cache.senzaPalestra,

          /*
           * ⚠️ **Il ripiego è la vecchia deduzione**, e serve: chi aveva già
           * l'app installata non ha la chiave nuova, e mandarlo alla schermata
           * di benvenuto vorrebbe dire farlo ripartire da capo per una
           * modifica che non lo riguarda.
           */
          sceltaFatta: _cache.sceltaFatta(
            oppure:
                _cache.senzaPalestra || (_cache.joinCode?.isNotEmpty ?? false),
          ),
        ),
      );

  /*
   * ⛔ **Non c'è più un `ApiClient`** — 27/08/2026, e vale la pena dirlo.
   *
   * 🚨 Questo controller **non parla più con la rete**: legge e scrive la cache,
   * e basta. L'unica chiamata che faceva era `/branding/lookup`, cioè la ricerca
   * del codice palestra prima del login — che da 3b-J.1 non esiste più.
   *
   * 💡 Il branding adesso arriva da chi ce l'ha per davvero: la risposta del
   * server all'utente autenticato, passata a [adottaDalServer].
   */
  final LocalCache _cache;

  /// 🆕 **Si prosegue senza palestra** — F3.
  ///
  /// Non chiama la rete: non c'è niente da cercare. Azzera il codice e riporta
  /// il branding a quello neutro, che è **esattamente** ciò che il server
  /// risponderà poi per un tenant personale.
  ///
  /// ⚠️ **Il codice va tolto dalla cache, non solo dallo stato.** Se restasse su
  /// disco, il prossimo avvio ripartirebbe con la palestra di prima — e la
  /// persona si troverebbe a fare l'accesso dentro una palestra che ha appena
  /// deciso di non avere.
  /// 🚨 **E si registra la scelta**, che è il pezzo che mancava.
  ///
  /// ⚠️ Senza, «non ho una palestra» restava indistinguibile da «non ho ancora
  /// scelto», e la regola 5 del router rimandava alla stessa schermata: per chi
  /// toccava il pulsante **non succedeva niente**. È il difetto riferito il
  /// 13/08/2026 provando la `v6.3.0`.
  Future<void> senzaPalestra() async {
    await _cache.forgetGym();
    await _cache.setSenzaPalestra(true);
    await _cache.setSceltaFatta();

    state = const BrandingState(
      branding: GymBranding.neutral,
      senzaPalestra: true,
      sceltaFatta: true,
    );
  }

  /// 🆕 **Adotta un branding che arriva da un'altra strada** — B4.
  ///
  /// Serve a `POST /account/join-gym`, che risponde già con il branding della
  /// palestra in cui si è appena entrati: senza questo, l'app resterebbe vestita
  /// di neutro dentro una palestra che ha i suoi colori — e sembrerebbe non aver
  /// funzionato.
  ///
  /// ⚠️ **Non chiama la rete e non ha un codice da salvare**: il `join_code`
  /// della palestra è quello che l'utente ha appena digitato, ma qui non
  /// serve — da adesso la palestra si legge dall'utente autenticato, non da un
  /// codice in cache.
  Future<void> adotta(Map<String, dynamic> branding) async {
    await _cache.setBranding(branding);
    await _cache.setSenzaPalestra(false);

    /*
     * 🚪 **Adottare una palestra è anche «la scelta è fatta»** — 3b-J.1.
     *
     * ⛔ Senza questa riga, chi entra in palestra — o chi si limita a fare
     * l'accesso, visto che il branding arriva col login — tornava a essere uno
     * che «non ha ancora scelto», e il router lo rimandava al benvenuto.
     */
    await _cache.setSceltaFatta();

    state = BrandingState(
      branding: GymBranding.fromJson(branding),
      sceltaFatta: true,
    );
  }

  /// 🏷️ Adotta il branding che il **server** ha mandato insieme all'utente.
  ///
  /// ══ 🚨 PERCHÉ ESISTE, DA 3b-J.1 ═══════════════════════════════════════
  ///
  /// 📌 Tolto il codice palestra dalla prima schermata, non c'è più nessun
  /// momento *prima* del login in cui l'app possa sapere di che colore essere.
  ///
  /// ⛔ Senza questo metodo, un iscritto che reinstalla l'app resterebbe
  /// **neutro per sempre** — con il server che sa benissimo in che palestra sta,
  /// e glielo stava già dicendo: `/auth/login` e `/auth/me` rispondono
  /// `{token, data, branding}`, e quel `branding` non lo leggeva nessuno.
  ///
  /// 💡 Ed è anche più giusto di prima: la palestra è **un fatto dell'utente**,
  /// non di un codice rimasto in cache su un telefono.
  ///
  /// ⚠️ **`null` vuol dire «nessuna palestra», e va gestito come tale**: chi
  /// esce da una palestra deve tornare neutro. ⛔ Ignorare il `null` lascerebbe
  /// addosso i colori di una palestra da cui si è appena usciti, che è il modo
  /// più diretto di far credere che l'operazione non abbia funzionato.
  Future<void> adottaDalServer(Object? branding) async {
    if (branding is Map<String, dynamic>) {
      await adotta(branding);

      return;
    }

    await senzaPalestra();
  }

  /*
   * ══ ⛔ QUI VIVEVANO `lookup()` E `refreshQuietly()` — tolti il 27/08/2026 ══
   *
   * 📌 *«al primo accesso, rimuovi l'opzione di registrarsi con una palestra»*.
   *
   * Servivano tutti e due allo stesso mondo: un **codice palestra digitato
   * prima del login**, tenuto in cache, e riletto ogni tanto per aggiornare i
   * colori. ⛔ Quel mondo non c'è più: il codice si digita da dentro l'app, e la
   * palestra si legge dall'utente autenticato.
   *
   * 🚨 **Erano già diventati bugie prima di essere tolti**: chi entrava in
   * palestra dal profilo non ha mai avuto un `joinCode` in cache — `adotta()`
   * non lo scrive, e lo dice nel suo commento — quindi `refreshQuietly()` per
   * lui tornava subito senza fare niente. ⚠️ E siccome è quello che chiamava
   * l'uscita dalla palestra, uscire **lasciava addosso i colori**. Il codice
   * c'era, girava, e non faceva la cosa che il suo nome prometteva.
   *
   * 💡 Al loro posto c'è [adottaDalServer], che prende il branding da chi ce
   * l'ha davvero: la risposta del server.
   */

  /// Dimentica la palestra: si usa al «cambia palestra», non al logout.
  Future<void> forget() async {
    await _cache.forgetGym();

    state = const BrandingState(branding: GymBranding.neutral);
  }
}

final brandingControllerProvider =
    StateNotifierProvider<BrandingController, BrandingState>(
      (ref) => BrandingController(ref.watch(localCacheProvider)),
    );
