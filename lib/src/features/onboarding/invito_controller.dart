import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'data/invito_in_palestra.dart';

/// L'invito dietro un link — 3b-V.2.
///
/// ── 🚨 Tutto **prima** dell'accesso, e non e' una svista ──────────────────
///
/// Chi tocca il link **non ha ancora l'app**, e spesso non ha nemmeno un
/// account. ⛔ Se l'anteprima chiedesse l'autenticazione, la prima cosa che
/// quella persona vedrebbe sarebbe un modulo di registrazione invece
/// dell'invito che le è stato mandato — cioè esattamente il muro che il link
/// esiste per togliere.
///
/// 💡 Il token **è** la credenziale: 32 caratteri casuali, monouso, a scadenza.
final invitoProvider = FutureProvider.autoDispose
    .family<InvitoInPalestra, String>((ref, token) async {
      final dati = await ref
          .watch(apiClientProvider)
          .get<Map<String, dynamic>>('/inviti-palestra/$token');

      return InvitoInPalestra.fromJson(dati);
    });

/// Le due risposte: accetto, o non accetto.
class RispostaAllInvito {
  const RispostaAllInvito(this._ref);

  final Ref _ref;

  /// Entra nella palestra. Torna il marchio, per ridipingersi subito.
  ///
  /// 💡 Il branding arriva **nella stessa risposta**: senza, l'app dovrebbe
  /// fare una seconda richiesta per una cosa che il server sa già, e per
  /// qualche istante la persona resterebbe dentro una palestra vestita coi
  /// colori di prima.
  Future<Map<String, dynamic>> accetta(String token) async {
    final dati = await _ref
        .read(apiClientProvider)
        .post<Map<String, dynamic>>('/inviti-palestra/$token/accetta');

    return (dati['palestra'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
  }

  /// Dice di no, e l'invito si brucia.
  ///
  /// ⚠️ **Non serve l'accesso**: chi non vuole entrare non deve crearsi un
  /// account per dirlo.
  ///
  /// 🚨 **Un errore qui non si mostra.** Il rifiuto è una cortesia verso la
  /// palestra — che così non tiene in sospeso una persona che ha già deciso —
  /// non un'operazione della persona. ⛔ Farle vedere «non è riuscito» per una
  /// cosa che non le interessa sarebbe un errore su un'azione che per lei è
  /// già finita: se ne va comunque.
  Future<void> rifiuta(String token) async {
    try {
      await _ref
          .read(apiClientProvider)
          .post<void>('/inviti-palestra/$token/rifiuta', unwrap: false);
    } on Object {
      // Voluto: vedi sopra.
    }
  }
}

final rispostaAllInvitoProvider = Provider(RispostaAllInvito.new);
