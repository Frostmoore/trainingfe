/// Quand'è successa l'ultima cosa che vale la pena raccontare — 3b-AB.
///
/// ══ 📌 A COSA SERVE ═══════════════════════════════════════════════════════
///
/// 📌 Il committente, il 30/08/2026: *«questo può succedere solo dopo che apri
/// l'app e solo dopo che si è registrato un pasto, un allenamento o il sonno»*.
///
/// 🎯 È il **secondo dei due cancelli** del consiglio del giorno. Il primo è la
/// fascia oraria, che mette il tetto a tre al giorno; questo evita di
/// consumarne una per niente.
///
/// ⚠️ **Senza, tre chiamate fatte a vuoto restano tre chiamate.** Chi apre
/// l'app alle 09:10 senza aver toccato niente da ieri sera riceverebbe un
/// consiglio identico a quello di ieri sera — e l'avremmo pagato.
///
/// ══ 🍽️ E DA I5 CI SONO ANCHE I PASTI ════════════════════════════════════
///
/// Qui c'era scritto che i pasti **li sa il server**: `food_entries` era sua, e
/// `created_at` diceva quando una voce era stata registrata. ⛔ Con I2.5 quella
/// premessa è morta — il diario alimentare vive sul telefono — e per qualche ora
/// **registrare un pasto non ha fatto scattare più niente**.
///
/// 🚨 Un difetto silenzioso: nessun errore, il consiglio c'era, era solo quello
/// di prima. 💡 Si è chiuso con I5, **insieme** al contesto del cibo: aggiungere
/// l'ultimo pasto qui *da solo* sarebbe stato peggio — il consiglio si sarebbe
/// rigenerato a ogni pasto per dire «oggi non hai mangiato niente», cioè una
/// chiamata pagata per una risposta sbagliata.
///
/// 💡 Adesso qui c'è **tutto quello che il telefono sa**, che dopo D9, la FASE
/// 11.6 e la Parte I è tutto: pasti, allenamenti e sonno. ⚠️ Il server non ha
/// più nessuna fonte sua — vedi `AiController::qualcosaDiNuovo()`, che infatti
/// non guarda più nessuna tabella.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../diary/data/diario_locale.dart';
import '../health/health_controller.dart';
import '../training/session_controller.dart';
import '../training/storico_unificato_controller.dart';

/// L'istante dell'ultima notizia, o `null` se non ce n'è nessuna.
///
/// ⚠️ **`null` non è «adesso» e non è «mai»**: è *«non lo so»*, e chi lo riceve
/// deve decidere cosa farne. Sul server, `null` vuol dire «non generare».
final ultimaNotiziaProvider = FutureProvider.autoDispose<DateTime?>((ref) async {
  final quando = <DateTime>[];

  /*
   * 🏋️ Le sedute registrate nell'app.
   *
   * ⛔ **Solo quelle chiuse.** Una seduta aperta è un allenamento in corso: non
   * ha ancora prodotto niente da raccontare, e farla contare vorrebbe dire
   * generare un consiglio nel mezzo di una serie.
   *
   * 💡 `finitaIl` e non `iniziataIl`: la notizia è che l'allenamento è
   * **finito**. Un allenamento cominciato alle 18 e finito alle 19:30 è una
   * notizia delle 19:30.
   */
  try {
    for (final s in await ref.watch(sessionsProvider.future)) {
      if (s.isOpen) continue;

      final fine = s.endedAt;
      if (fine != null) quando.add(fine);
    }
  } on Object {
    /*
     * ⚠️ Una lettura che non riesce **non deve bloccare il consiglio**: si
     * perde una fonte, non la funzione. È la stessa scelta già fatta in
     * `contestoConsiglioProvider` per la settimana e per i tipi.
     */
  }

  /*
   * ⌚ E gli allenamenti visti solo dall'orologio.
   *
   * 🚨 **Contano come gli altri, e non è un di più.** Il consiglio riceve già
   * `week_workouts` dal polso: una corsa che il telefono ha importato ma che
   * non ha prodotto nessuna seduta è materiale nuovo per il modello, e
   * lasciarla fuori vorrebbe dire far leggere al consiglio un allenamento di
   * cui non si è mai accorto che esisteva.
   */
  try {
    for (final a in await ref.watch(allenamentiDalPolsoProvider.future)) {
      if (a.nascosto) continue;

      quando.add(a.finitoIl);
    }
  } on Object {
    // Vedi sopra: una fonte in meno, non un guasto.
  }

  /*
   * 😴 E il sonno.
   *
   * 💡 `ultimoRisveglio()` e non l'ultima notte: la notte è una data a
   * mezzanotte, e confrontata con un consiglio delle 09:15 risulterebbe sempre
   * più vecchia. ⛔ Il sonno non farebbe mai scattare niente, e nessuno se ne
   * accorgerebbe.
   */
  try {
    final sveglia = await ref.watch(archivioSaluteProvider).ultimoRisveglio();
    if (sveglia != null) quando.add(sveglia);
  } on Object {
    // Vedi sopra.
  }

  /*
   * 🍽️ E i pasti — I5.2.
   *
   * 🚨 **`scrittaIl` e non `mangiatoIl`**: il secondo è la mezzanotte del giorno
   * scelto, quindi chi programma la cena di domani scriverebbe una notizia di
   * **domani** — e il consiglio si rigenererebbe per un pasto non ancora
   * avvenuto, ogni volta, fino a domani.
   *
   * ⚠️ Il contatore [revisioneDiarioProvider] serve a rileggere questo numero
   * dopo una scrittura: senza, la notizia resterebbe quella di prima proprio
   * nell'istante in cui è cambiata.
   */
  ref.watch(revisioneDiarioProvider);

  try {
    final pasto = await ref.watch(diarioLocaleProvider).ultimaScrittura();
    if (pasto != null) quando.add(pasto);
  } on Object {
    // Vedi sopra: una fonte in meno, non un guasto.
  }

  if (quando.isEmpty) return null;

  return quando.reduce((a, b) => a.isAfter(b) ? a : b);
});
