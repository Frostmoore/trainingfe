import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/providers.dart';

/// ✍️ **La liberatoria dell'art. 28, per chi allena** — 20/09/2026.
///
/// 📌 Il committente, 20/09: *«…dovrà firmare la liberatoria specifica per le
/// palestre (idem per i trainer)»*.
///
/// ── 🚨 Perché un muro e non un avviso ─────────────────────────────────────
///
/// Un trainer vede nome, email e conversazioni dei suoi allievi. L'art. 28(3)
/// vuole che quel rapporto sia messo per iscritto **prima** che cominci: un
/// banner ignorabile lascerebbe accettare allievi a chi non ha accettato
/// niente.
///
/// 💡 La palestra firma nel pannello, il trainer qui: è la stessa tabella sul
/// server (`liberatorie_firmate`), e la stessa versione del testo.
class StatoLiberatoria {
  const StatoLiberatoria({
    required this.serve,
    this.tipo,
    this.versione,
    this.testo,
  });

  const StatoLiberatoria.aPosto() : this(serve: false);

  factory StatoLiberatoria.fromJson(Map<String, dynamic> json) =>
      StatoLiberatoria(
        serve: json['serve'] as bool? ?? false,
        tipo: json['tipo'] as String?,
        versione: json['versione'] as String?,
        testo: json['testo'] as String?,
      );

  final bool serve;
  final String? tipo;
  final String? versione;

  /// Il testo completo, in markdown. 💡 L'app ne mostra l'essenziale e manda al
  /// testo intero sul sito: qui dentro non c'è un lettore di markdown, e
  /// aggiungerne uno per una schermata sola vorrebbe dire un pacchetto in più
  /// da aggiornare per sempre.
  final String? testo;
}

final liberatoriaProvider = Provider<Liberatoria>(Liberatoria.new);

class Liberatoria {
  Liberatoria(this._ref);

  final Ref _ref;

  ApiClient get _api => _ref.read(apiClientProvider);

  /// Cosa manca, se manca qualcosa.
  ///
  /// ⚠️ **Non lancia mai**: senza rete non si sa, e non sapere non deve
  /// impedire di usare l'app — il muro vero è sul server, che rifiuta comunque.
  Future<StatoLiberatoria> cosaServe() async {
    try {
      final dati = await _api.get<Map<String, dynamic>>('/account/liberatoria');

      return StatoLiberatoria.fromJson(dati);
    } on Object {
      return const StatoLiberatoria.aPosto();
    }
  }

  /// Firma. Il server registra versione, data e provenienza.
  Future<void> firma() =>
      _api.post<Map<String, dynamic>>('/account/liberatoria');
}
