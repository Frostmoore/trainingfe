import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/providers.dart';
import 'data/invito_in_sospeso.dart';
import 'data/utente_seguito.dart';

/// «I miei utenti» — F5.1 e F6 della Parte B.
///
/// ── ⚠️ Perché questa sezione è nell'app e non nel pannello web ─────────────
///
/// Decisione D6, ed è la stessa linea di C13: **il modello sta sul web,
/// l'istanza assegnata sta sull'app.** Comporre una scheda o un piano a sei
/// pasti è lavoro da schermo grande; *assegnarla a una persona* è l'unico
/// momento che tocca dati personali e deve passare dal canale cifrato, che vive
/// sul telefono.
///
/// 🚨 **Un trainer si allena anche lui.** Nell'app è utente **e** gestore: non
/// due account, non due accessi — un account con una sezione in più.
final mieiUtentiProvider = FutureProvider<MieiUtenti>((ref) async {
  final api = ref.watch(apiClientProvider);

  final risposta = await api.get<Map<String, dynamic>>(
    '/trainer/members',
    unwrap: false,
  );

  final dati = (risposta['data'] as List? ?? const [])
      .map((e) => UtenteSeguito.fromJson((e as Map).cast<String, dynamic>()))
      .toList(growable: false);

  return MieiUtenti(
    utenti: dati,
    posti: PostiDelTrainer.fromJson(
      ((risposta['meta'] as Map?) ?? const {}).cast<String, dynamic>(),
    ),
  );
});

/// 🆕 📨 **Gli inviti ancora in piedi** — blocco B1, 24/09/2026.
///
/// ⛔ **Prima non esisteva nessuna schermata che li mostrasse**, e nemmeno una
/// rotta che li restituisse: un invito creato dall'app spariva nel momento in
/// cui il link finiva negli appunti.
///
/// 🚨 E ogni invito in sospeso **tiene un posto del piano** finché non scade:
/// senza elenco non c'era modo di liberarlo, e un tocco distratto costava un
/// posto per sette giorni.
/// 🆕 🏋️ **Una famiglia, e non due provider** — blocco B2, 24/09/2026.
///
/// ⛔ Gli inviti di una palestra hanno le stesse quattro azioni di quelli di un
/// trainer: un secondo provider vorrebbe dire la stessa logica in due posti, e
/// due posti divergono. 💡 Cambia **solo la rotta**, e la porta [ChiInvita].
///
/// ⚠️ **I due contatori arrivano in forme diverse**, e è di proposito: un
/// trainer ha un limite solo, una palestra ne ha **due** — iscritti e trainer
/// — e il server li manda annidati. 🚨 Appiattirli qui vorrebbe dire
/// dimenticare quale dei due sta finendo.
final invitiProvider = FutureProvider.family<InvitiEPosti, ChiInvita>((
  ref,
  chi,
) async {
  final api = ref.watch(apiClientProvider);

  final risposta = await api.get<Map<String, dynamic>>(
    chi.rotta,
    unwrap: false,
  );

  final meta = ((risposta['meta'] as Map?) ?? const {}).cast<String, dynamic>();

  return InvitiEPosti(
    inviti: (risposta['data'] as List? ?? const [])
        .map(
          (e) => InvitoInSospeso.fromJson((e as Map).cast<String, dynamic>()),
        )
        .toList(growable: false),
    posti: PostiDegliInviti.fromJson(
      chi.sceglieIlRuolo
          ? ((meta['iscritti'] as Map?) ?? const {}).cast<String, dynamic>()
          : meta,
    ),
    postiTrainer: chi.sceglieIlRuolo
        ? PostiDegliInviti.fromJson(
            ((meta['trainer'] as Map?) ?? const {}).cast<String, dynamic>(),
          )
        : null,
  );
});

final trainerActionsProvider = Provider(
  (ref) => TrainerActions(ref.watch(apiClientProvider), ref),
);

class TrainerActions {
  TrainerActions(this._api, this._ref);

  final ApiClient _api;
  final Ref _ref;

  /// Crea un invito monouso.
  ///
  /// 🚨 **Il link arriva dal server**, non si compone qui: il giorno in cui
  /// cambia il dominio, un link costruito nell'app resterebbe sbagliato finché
  /// non esce una versione nuova sugli store — e nel frattempo ogni invito
  /// mandato punterebbe da nessuna parte.
  ///
  /// ══ 🆕 E ADESSO TORNA ANCHE L'ESITO DELLA MAIL — B1, 24/09/2026 ═══════════
  ///
  /// ⚠️ **Prima tornava solo `String`**, il link. Con l'email di mezzo non
  /// bastava più: l'invio può fallire — e quando fallisce l'invito **resta
  /// valido di proposito**, perché il link c'è. 💡 Chi ha scritto un indirizzo
  /// deve poter leggere *«mandata»* solo quando è vero, e altrimenti sapere che
  /// il link va passato a mano.
  Future<InvitoCreato> invita({
    String? email,
    ChiInvita chi = ChiInvita.trainer,
    RuoloInvitato? ruolo,
  }) async {
    final dati = await _api.post<Map<String, dynamic>>(
      chi.rotta,
      body: {
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),

        /*
         * ⚠️ **Il ruolo si manda solo se lo si sceglie davvero**: le rotte
         * del trainer non lo conoscono, e un campo di troppo in una
         * validazione stretta è un 422 su una cosa che nessuno ha chiesto.
         */
        if (chi.sceglieIlRuolo)
          'ruolo': (ruolo ?? RuoloInvitato.iscritto).valore,
      },
    );

    _ref
      ..invalidate(mieiUtentiProvider)
      ..invalidate(invitiProvider(chi));

    return InvitoCreato.fromJson(dati);
  }

  /// 🆕 🚫 **Revoca un invito, e restituisce il posto.**
  ///
  /// 🚨 È il motivo per cui il committente l'ha chiesta: un invito valido
  /// **tiene un posto del piano** finché non scade. ⛔ Senza revoca, un link
  /// mandato alla persona sbagliata costa un posto per sette giorni.
  Future<void> revocaInvito(int id, {ChiInvita chi = ChiInvita.trainer}) async {
    await _api.delete('${chi.rotta}/$id');

    _ref
      ..invalidate(invitiProvider(chi))
      ..invalidate(mieiUtentiProvider);
  }

  /// 🆕 📧 **Rimanda per email un invito già creato.**
  ///
  /// ⚠️ Senza questa, un invito finito nello spam si poteva solo revocare e
  /// rifare — e rifarlo **consuma un altro posto** finché il primo non scade.
  ///
  /// 💡 `email` facoltativa: se manca, il server usa quella con cui l'invito era
  /// nato.
  Future<bool> rimandaInvito(
    int id, {
    String? email,
    ChiInvita chi = ChiInvita.trainer,
  }) async {
    final dati = await _api.post<Map<String, dynamic>>(
      '${chi.rotta}/$id/email',
      body: {
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
      },
    );

    _ref.invalidate(invitiProvider(chi));

    return dati['email_inviata'] as bool? ?? false;
  }

  /// Sospende o riattiva il rapporto — D5.
  ///
  /// ⚠️ **Non cancella niente e non blocca l'account di nessuno**: chiude il
  /// canale dei messaggi, e basta. Il legame resta, la storia si conserva, ed è
  /// reversibile.
  ///
  /// 🚨 E i piani **già ricevuti** non si possono revocare: vivono sul telefono
  /// di quella persona, e il server non può togliere ciò che non ha mai avuto.
  Future<bool> cambiaStato(int utenteId) async {
    final dati = await _api.post<Map<String, dynamic>>(
      '/trainer/members/$utenteId/toggle',
    );

    _ref.invalidate(mieiUtentiProvider);

    return dati['attivo'] as bool? ?? true;
  }

  /// 🆕 🎟️ **Tengo il posto, o lo libero** — AH.1-ter.6, 18/09/2026.
  ///
  /// 📌 Il committente: *«se il trainer decide di mantenere lo slot occupato,
  /// l'allievo passa alla palestra, poi se si dissocia dalla palestra torna al
  /// trainer. Se il trainer decide di liberare lo slot, […] non torna al
  /// trainer.»*
  ///
  /// ⚠️ **La scelta si passa sempre**, e il server la pretende: è una decisione
  /// che costa soldi in un verso e un allievo nell'altro, e un valore di serie
  /// sarebbe deciderla al posto del trainer.
  Future<void> decidiLoSlot(int allievoId, {required bool tengo}) async {
    await _api.post<Map<String, dynamic>>(
      '/trainer/slot/$allievoId',
      body: {'tengo_lo_slot': tengo},
    );

    _ref
      ..invalidate(slotDaDecidereProvider)
      ..invalidate(mieiUtentiProvider);
  }
}

/// 🆕 🎟️ **Un allievo entrato nella palestra dove lavori anche tu** — AH.1-ter.6.
///
/// ⛔ **Non vuol dire che il rapporto sia fermo.** Il committente, 18/09:
/// *«un allievo deve poter essere iscritto a infiniti free_trainer e una sola
/// palestra, anche contemporaneamente»*. Il rapporto resta intero; la domanda
/// riguarda solo **chi paga il posto**.
class SlotDaDecidere {
  const SlotDaDecidere({
    required this.allievoId,
    required this.nome,
    required this.palestra,
  });

  factory SlotDaDecidere.fromJson(Map<String, dynamic> json) => SlotDaDecidere(
    allievoId: (json['member_id'] as num).toInt(),
    nome: json['nome']?.toString() ?? '',
    palestra: json['palestra']?.toString(),
  );

  final int allievoId;
  final String nome;

  /// ⚠️ Può mancare: se la palestra è stata cancellata la colonna diventa
  /// `null` (`nullOnDelete`), e la schermata non deve scrivere «null».
  final String? palestra;
}

/// Le scelte sullo slot che questo trainer deve ancora fare.
///
/// 💡 **Le domande non hanno una tabella loro, sul server**: sono i rapporti
/// sovrapposti senza risposta. Qui si chiedono e basta.
final slotDaDecidereProvider = FutureProvider<List<SlotDaDecidere>>((
  ref,
) async {
  final api = ref.watch(apiClientProvider);

  final risposta = await api.get<Map<String, dynamic>>(
    '/trainer/slot-da-decidere',
    unwrap: false,
  );

  return (risposta['data'] as List? ?? const [])
      .map((e) => SlotDaDecidere.fromJson((e as Map).cast<String, dynamic>()))
      .toList(growable: false);
});
