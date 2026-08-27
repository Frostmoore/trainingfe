/// La settimana programmata: leggerla, scriverla, distribuirla — 3b-I.B.
///
/// ══ 🔒 E' DIETRO L'ABBONAMENTO ════════════════════════════════════════════
///
/// 📌 Deciso il 27/08/2026: *«stiamo sviluppando il gate dell'abbonamento, la
/// versione gratuita NON DEVE guadagnare niente. Però i tasti per fare quella
/// cosa ci devono essere e si deve capire che sono bloccati»*.
///
/// 💡 Si riusa `senzaLimiti` invece di scrivere una condizione nuova: è la
/// stessa regola delle schede — **basta una fra abbonamento e AI illimitata** —
/// e averla in due stesure vorrebbe dire che un giorno si aprono due porte
/// diverse.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../health/health_controller.dart';
import 'data/catalogo_esercizi.dart';
import 'data/gruppo_muscolare.dart';
import 'data/limiti_delle_schede.dart';
import 'data/settimana_programmata.dart';
import 'muscoli_allenati.dart';
import 'training_controller.dart';

/// Se questa persona può usare la settimana programmata.
///
/// ⛔ **Corretta il 27/08/2026 insieme ai progressi**, e non era stata
/// contestata: apriva anche a chi ha l'AI illimitata senza abbonamento.
///
/// 🚨 **È lo stesso gate, quindi dev'essere la stessa porta.** Due funzioni
/// della stessa fase che rispondono in modo diverso alla domanda «sei abbonato?»
/// sono il modo per scoprire fra un mese che una delle due non era stata
/// aggiornata — e non si scopre guardando il codice, si scopre da un cliente.
final puoProgrammareProvider = Provider.autoDispose<bool>(
  (ref) => soloSeAbbonato(ref.watch(authControllerProvider).user?.abbonato),
);

/// Le sette caselle, da lunedì. `null` = riposo.
///
/// 🚨 **Non è `autoDispose`**: la riga in «Oggi» la legge a ogni apertura della
/// pagina principale, e ributtarla via a ogni uscita vorrebbe dire una lettura
/// del database ogni volta che si cambia scheda.
final settimanaProvider = FutureProvider<List<int?>>((ref) async {
  ref.watch(revisioneDellaSettimanaProvider);

  return ref.watch(archivioSaluteProvider).settimanaDelPiano();
});

/// 💡 Il contatore che fa ridisegnare dopo un salvataggio: drift non notifica
/// da solo chi legge con `Future`. È lo stesso meccanismo delle schede.
final revisioneDellaSettimanaProvider = StateProvider<int>((ref) => 0);

/// La scheda di **oggi**, se ce n'è una programmata.
///
/// ⚠️ `DateTime.weekday` va da 1 a 7 come le nostre caselle: è il motivo per cui
/// la tabella usa quella convenzione invece di partire da zero.
final schedaDiOggiProvider = FutureProvider<int?>((ref) async {
  if (!ref.watch(puoProgrammareProvider)) return null;

  final settimana = await ref.watch(settimanaProvider.future);

  return settimana[DateTime.now().weekday - 1];
});

/// Scrive la settimana e fa ridisegnare chi la guarda.
Future<void> salvaLaSettimana(WidgetRef ref, List<int?> giorni) async {
  await ref.read(archivioSaluteProvider).scriviLaSettimana(giorni);

  ref.read(revisioneDellaSettimanaProvider.notifier).state++;
}

/// La proposta dell'app: le schede scelte, distribuite sui giorni.
///
/// ⛔ **Non salva niente**: propone. 📌 È la stessa regola del TDEE misurato —
/// un obiettivo (o una settimana) che cambia da solo non lo si può più
/// controllare.
Future<List<int?>> proponiLaSettimana(
  WidgetRef ref, {
  required List<int> schede,
  required int quantiGiorni,
}) async {
  final catalogo = await ref.read(catalogoEserciziProvider.future);
  final tutte = await ref.read(schedeUniteProvider.future);

  final pesi = <int, Map<GruppoMuscolare, double>>{
    for (final s in tutte)
      if (schede.contains(s.id)) s.id: pesiDellaScheda(s, catalogo),
  };

  return distribuisci(schede: schede, quantiGiorni: quantiGiorni, pesi: pesi);
}
