import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

/// Quali sezioni del diario sono ripiegate — 3b-D.3.3, 22/08/2026.
///
/// ══ 💡 PERCHÉ SI RICORDA ══════════════════════════════════════════════════
///
/// 📌 Il committente: *«Le sezioni dei pasti devono essere collassabili»*.
///
/// ⚠️ Sei pasti aperti su un telefono sono uno scorrimento lungo per arrivare
/// alla cena, e chi guarda il diario a metà giornata ha tre sezioni vuote in
/// mezzo. 🚨 Ma richiudere le stesse tre a ogni apertura sarebbe peggio di non
/// poterle chiudere: una scelta che non dura non è una scelta, è un gesto.
///
/// ── ⛔ Perché sta in `LocalCache` e NON nell'archivio ─────────────────────
///
/// 🚨 **Non è un dato, è lo stato di uno schermo.** La regola del committente —
/// *«ogni volta che abbiamo un nuovo dato […] deve finire nel backup»* — parla
/// di dati: peso, pasti, allenamenti. Quale sezione è ripiegata su **questo**
/// telefono non lo è, e su un secondo telefono può ragionevolmente essere
/// diverso.
///
/// ⚠️ **Va detto perché è importante saperlo**: `LocalCache` **non finisce nel
/// backup** — quello impacca l'archivio drift e le foto, e basta. Quindi
/// reinstallando l'app le sezioni tornano tutte aperte. 💡 È il comportamento
/// giusto per questa cosa, e sarebbe **sbagliato** per un dato: chi ci mette
/// qualcosa di più pesante deve saperlo.
class PastiChiusi extends Notifier<Set<String>> {
  static const chiave = 'diario.pasti.chiusi';

  @override
  Set<String> build() {
    final salvato = ref.watch(localCacheProvider).getString(chiave) ?? '';

    return salvato.split(',').where((p) => p.isNotEmpty).toSet();
  }

  /// Apre quello che è chiuso, e viceversa.
  Future<void> cambia(String pasto) async {
    final nuovo = {...state};

    if (!nuovo.remove(pasto)) nuovo.add(pasto);

    state = nuovo;

    final cache = ref.read(localCacheProvider);

    if (nuovo.isEmpty) {
      await cache.remove(chiave);
    } else {
      await cache.setString(chiave, nuovo.join(','));
    }
  }
}

final pastiChiusiProvider = NotifierProvider<PastiChiusi, Set<String>>(
  PastiChiusi.new,
);
