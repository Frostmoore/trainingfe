import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/providers.dart';
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

final trainerActionsProvider = Provider(
  (ref) => TrainerActions(ref.watch(apiClientProvider), ref),
);

class TrainerActions {
  TrainerActions(this._api, this._ref);

  final ApiClient _api;
  final Ref _ref;

  /// Crea un invito monouso e restituisce il link da condividere.
  ///
  /// 🚨 **Il link arriva dal server**, non si compone qui: il giorno in cui
  /// cambia il dominio, un link costruito nell'app resterebbe sbagliato finché
  /// non esce una versione nuova sugli store — e nel frattempo ogni invito
  /// mandato punterebbe da nessuna parte.
  Future<String> invita({String? email}) async {
    final dati = await _api.post<Map<String, dynamic>>(
      '/trainer/invites',
      body: {
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
      },
    );

    _ref.invalidate(mieiUtentiProvider);

    return dati['url']?.toString() ?? '';
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
