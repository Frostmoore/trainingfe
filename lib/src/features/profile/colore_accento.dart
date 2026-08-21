import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

/// Il colore d'accento scelto da chi **non ha una palestra** — 3b-O.1a.1.
///
/// ══ 🚨 SOLO PER CHI NON HA UNA PALESTRA ═══════════════════════════════════
///
/// 📌 Il committente: *«il colore di accento deve essere quello della palestra,
/// se è un utente free_user, questo deve poter scegliere il suo colore di
/// accento dalle impostazioni»*.
///
/// ⚠️ **Chi una palestra ce l'ha non sceglie**, e non è una dimenticanza: il
/// colore è l'identità del cliente (ADR-A01), ed è il motivo per cui l'app si
/// chiama white-label. 🚨 Lasciarlo cambiare vorrebbe dire che l'iscritto può
/// spegnere il marchio della palestra che lo paga.
///
/// ── ⚠️ Una tavolozza chiusa, non un selettore libero ──────────────────────
///
/// 📌 Scelta del committente: *«fai selettore con un po' di colori già
/// preimpostati»*.
///
/// 🚨 Ed è anche l'unica sicura. Il colore finisce in `primaryContainer`, che è
/// lo sfondo dell'intestazione: sopra ci vanno testo, icone di sistema e il
/// saldo dei gettoni. ⚠️ Con un colore qualunque — un giallo acceso, un bianco —
/// quel testo **sparisce**, e non c'è modo di impedirlo a valle.
///
/// 💡 Questi otto sono tutti abbastanza scuri e saturi da reggere testo chiaro
/// sopra, in tema chiaro e in tema scuro.
///
/// ── 💡 Vive sul telefono, e va nel backup ─────────────────────────────────
///
/// È una preferenza di **questo** schermo, non un dato del server: due telefoni
/// della stessa persona possono volerla diversa. Sta in `LocalCache`, che
/// finisce nella copia di sicurezza come tutto il resto.
class ColoreAccento {
  const ColoreAccento._();

  static const chiave = 'aspetto.accento';

  /// 🚨 L'ordine conta: il primo è quello di serie, ed è il verde del prodotto.
  static const tavolozza = <String, Color>{
    'verde': Color(0xFF0E7C66),
    'blu': Color(0xFF1E5EA8),
    'indaco': Color(0xFF4338CA),
    'viola': Color(0xFF7A3EA1),
    'magenta': Color(0xFFA82E6B),
    'rosso': Color(0xFFB3261E),
    'arancio': Color(0xFFB2560D),
    'ardesia': Color(0xFF37474F),
  };

  static Color? daNome(String? nome) => nome == null ? null : tavolozza[nome];
}

/// Il colore scelto, o `null` se non ne è stato scelto nessuno.
///
/// ⚠️ `null` e non «il verde»: chi legge deve poter distinguere «ha scelto il
/// verde» da «non ha scelto», perché nel secondo caso vince comunque il colore
/// della palestra, se c'è.
class AccentoScelto extends Notifier<String?> {
  @override
  String? build() =>
      ref.watch(localCacheProvider).getString(ColoreAccento.chiave);

  Future<void> scegli(String? nome) async {
    final cache = ref.read(localCacheProvider);

    if (nome == null) {
      await cache.remove(ColoreAccento.chiave);
    } else {
      await cache.setString(ColoreAccento.chiave, nome);
    }

    state = nome;
  }
}

final accentoSceltoProvider = NotifierProvider<AccentoScelto, String?>(
  AccentoScelto.new,
);
