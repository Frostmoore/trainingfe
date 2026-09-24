import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'data/nome_pubblico.dart';

/// 🆔 **Il nome pubblico, lato app** — blocco B3, 24/09/2026.
///
/// 🚨 **Un provider solo per tre cose che sono la stessa cosa**: il nome,
/// l'interruttore «fatti trovare» e la ricerca. Sono la stessa domanda vista da
/// due lati — *«mi faccio trovare?»* e *«chi trovo?»* — e separarle vorrebbe
/// dire due file che si rimandano a vicenda a ogni cambio di regola.
final nomePubblicoProvider = FutureProvider<NomePubblico>((ref) async {
  final dati = await ref
      .watch(apiClientProvider)
      .get<Map<String, dynamic>>('/account/nome-utente');

  return NomePubblico.fromJson(dati);
});

final nomePubblicoActionsProvider = Provider(
  (ref) => NomePubblicoActions(ref),
);

class NomePubblicoActions {
  NomePubblicoActions(this._ref);

  final Ref _ref;

  /// Sceglie o cambia il nome utente.
  ///
  /// ⚠️ Il server rifiuta se è troppo presto (30 giorni) o se il nome è preso —
  /// **o bruciato**: un nome lasciato libero da chi ha cancellato l'account non
  /// si riassegna, o i messaggi che cercavano quella persona arriverebbero a
  /// un'altra.
  Future<NomePubblico> cambia(String nuovo) async {
    final dati = await _ref
        .read(apiClientProvider)
        .patch<Map<String, dynamic>>(
          '/account/nome-utente',
          body: {'username': nuovo.trim().toLowerCase()},
        );

    _ref.invalidate(nomePubblicoProvider);

    return NomePubblico.fromJson(dati);
  }

  /// 🔦 Accende o spegne «fatti trovare».
  ///
  /// ⛔ Accenderlo **senza un nome** non si può: sarebbe un interruttore che non
  /// fa niente, e chi lo accende crederebbe di essere trovabile. Il server
  /// risponde `serve_il_nome_utente`.
  Future<NomePubblico> famiTrovare({required bool si}) async {
    final dati = await _ref
        .read(apiClientProvider)
        .patch<Map<String, dynamic>>(
          '/account/trovabile',
          body: {'trovabile': si},
        );

    _ref.invalidate(nomePubblicoProvider);

    return NomePubblico.fromJson(dati);
  }

  /// 🔎 Cerca una persona per nome utente.
  ///
  /// 🚨 **Chi si trova lo decide il server** (`ChiPossoCercare`): un trainer lo
  /// trova chiunque, un iscritto **solo i suoi**. ⛔ L'app non filtra niente, o
  /// sarebbe una seconda regola che prima o poi dice un'altra cosa.
  Future<List<PersonaTrovata>> cerca(String pezzo) async {
    if (pezzo.trim().length < 3) return const [];

    final dati = await _ref
        .read(apiClientProvider)
        .get<List<dynamic>>('/persone/cerca?nome=${Uri.encodeQueryComponent(pezzo.trim())}');

    return dati
        .map((e) => PersonaTrovata.fromJson((e as Map).cast<String, dynamic>()))
        .toList(growable: false);
  }

  /// 💬 Apre un filo **di presentazione** con una persona trovata.
  ///
  /// ⚠️ Tre messaggi, il limite che c'era già: è una presentazione, non un
  /// rapporto. 💡 Da lì chi allena può mandare un invito in chat — la strada
  /// «da app a app» esisteva già **tranne** il modo di trovarsi.
  Future<int> scriviA(int utenteId) async {
    final dati = await _ref
        .read(apiClientProvider)
        .post<Map<String, dynamic>>(
          '/conversations/da-nome-utente',
          body: {'utente_id': utenteId},
        );

    return (dati['id'] as num).toInt();
  }

  /// 🚫 Blocca una persona: non ti scrive **e non ti trova più**.
  Future<void> blocca(int utenteId) async {
    await _ref
        .read(apiClientProvider)
        .post<Map<String, dynamic>>('/persone/$utenteId/blocca');
  }
}
