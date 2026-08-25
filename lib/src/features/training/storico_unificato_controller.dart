import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/archivio_salute.dart';
import '../health/health_controller.dart';
import 'data/storico_unificato.dart';
import 'session_controller.dart';
import 'training_controller.dart';

/// Gli allenamenti registrati dall'orologio, dal telefono — FASE 1.9.
///
/// 🚨 **Non passa dal server, e non ci deve passare.** Sono dati sanitari, e la
/// regola del 19/08 non ha eccezioni: restano sul telefono e nel backup.
final allenamentiDalPolsoProvider =
    FutureProvider.autoDispose<List<AllenamentoDaOrologio>>((ref) async {
      ref.watch(revisioneAllenamentiProvider);

      return ref.watch(archivioSaluteProvider).allenamentiDellOrologio();
    });

/// Lo storico completo: le sedute dell'app e gli allenamenti dell'orologio,
/// fusi — FASE 1.10.
///
/// ── ⚠️ Perché l'orologio non fa fallire lo storico ────────────────────────
///
/// Le sedute arrivano dalla rete, gli allenamenti dal disco. Se l'archivio
/// locale desse un errore — un telefono senza Health Connect, un database
/// appena migrato — far fallire tutto vorrebbe dire nascondere anche le sedute
/// che avevamo già, per un dato **accessorio**.
///
/// 💡 Quindi: un guasto sul lato locale vale «nessun allenamento dall'orologio»,
/// e lo storico resta quello di prima. 🚨 Il contrario no: se cade la rete, lo
/// storico deve dirlo, perché lì manca la parte principale.
final storicoUnificatoProvider = FutureProvider.autoDispose<List<VoceStorico>>((
  ref,
) async {
  final sessioni = await ref.watch(sessionsProvider.future);

  /*
   * ⚠️ **Il `debugPrint` non è decorazione.** Una ricaduta silenziosa su lista
   * vuota è la stessa forma del difetto del 20/08: la schermata diceva «Nessun
   * allenamento» e nel database la riga c'era. Se un giorno la lettura locale
   * fallisce davvero, «vuoto» e «rotto» devono essere distinguibili almeno da
   * chi ha il telefono attaccato al cavo.
   */
  final dalPolso = await ref
      .watch(allenamentiDalPolsoProvider.future)
      .catchError((Object e) {
        debugPrint(
          'storicoUnificato: gli allenamenti locali non si leggono — $e',
        );

        return const <AllenamentoDaOrologio>[];
      });

  /*
   * ══ 🚨 TUTTE E DUE LE PROVENIENZE — 3b-A.2, 23/08/2026 ═══════════════════
   *
   * ⛔ Qui c'era `schedeRicevuteProvider`, che contiene **solo** le schede
   * arrivate in chat. Le schede assegnate dal trainer stanno sul server, e per
   * chi ha solo quelle — cioè il caso normale — l'elenco era **sempre vuoto**:
   * *«mi dice sempre che non ho schede disponibili»*.
   *
   * 💡 `schedeUniteProvider` le tiene già insieme — e dal 25/08 «insieme» vuol
   * dire **una tabella sola**, non due elenchi accostati con gli id firmati.
   * `schedaAssegnata` contiene quello stesso id, quindi una mappa sola basta.
   */
  final nomi = await ref
      .watch(schedeUniteProvider.future)
      .then((v) => {for (final s in v) s.id: s.name})
      .catchError((Object e) {
        debugPrint('storicoUnificato: le schede non si leggono — $e');

        return const <int, String>{};
      });

  return StoricoUnificato.fondi(
    sessioni: sessioni,
    dallOrologio: dalPolso,
    nomiDelleSchede: nomi,
  );
});

/// Il **tipo** delle sedute della settimana, per il consiglio del giorno —
/// 20/08/2026.
///
/// ── 🚨 Perché lo sa solo il telefono ──────────────────────────────────────
///
/// Perché sul server il tipo **non esiste**: `workout_sessions` ha date, calorie
/// e note, `workout_plans` ha un nome. ⚠️ L'unico posto dove esiste «Pesi» è
/// l'orologio, che scrive `STRENGTH_TRAINING` in Health Connect — e quello sta
/// qui dentro.
///
/// 📌 Richiesta del committente: *«il tipo di allenamento deve partire: se il mio
/// allenamento è Pesi questo deve passare»*.
///
/// ── ⚠️ Parte il CODICE, non l'etichetta italiana ──────────────────────────
///
/// `STRENGTH_TRAINING`, non «Pesi». 🚨 Il codice è un **vocabolario chiuso**, e
/// il server lo verifica con `/^[A-Z_]{2,48}$/`: è quella regex a garantire che
/// da qui non possa uscire testo libero.
///
/// 💡 L'etichetta italiana serve a chi guarda lo schermo, e vive in
/// `TipoAllenamento`. Mandarla vorrebbe dire mandare una stringa che un domani
/// qualcuno potrebbe rendere più descrittiva senza pensarci.
///
/// ── 💡 Solo le sedute, non gli allenamenti a sé ───────────────────────────
///
/// La mappa è `id della seduta → codice`: una corsa registrata **solo**
/// dall'orologio non ha un `id` di seduta, quindi non ha modo di entrare. È la
/// decisione del committente — nel consiglio vanno solo gli allenamenti
/// registrati nell'app — applicata dalla forma del dato invece che da un
/// controllo.
final tipiDegliAllenamentiProvider =
    FutureProvider.autoDispose<Map<int, String>>((ref) async {
      final voci = await ref.watch(storicoUnificatoProvider.future);

      final fuori = <int, String>{};

      for (final v in voci) {
        if (v.sedute.isEmpty || v.dalPolso.isEmpty) continue;

        /*
     * ⚠️ Il tipo del **primo** tratto del gruppo. Se l'orologio è stato fermato
     * e ripreso i tratti sono più d'uno, ma il raggruppamento li tiene insieme
     * solo se il tipo non cambia (o se si sovrappongono): prendere il primo è
     * quindi rappresentativo, e prendere l'ultimo non cambierebbe niente.
     */
        final tipo = v.dalPolso.first.tipo;

        for (final s in v.sedute) {
          fuori[s.id] = tipo;
        }
      }

      return fuori;
    });

/// La riga di storico a cui appartiene una seduta — FASE 1-bis.
///
/// ── 🚨 Perché il riepilogo ne ha bisogno ──────────────────────────────────
///
/// Perché altrimenti **si contraddice con lo storico**. La card dello storico
/// mostra le calorie misurate dall'orologio; il riepilogo mostrava la nostra
/// stima e la chiamava «stima calcolata dagli esercizi». ⚠️ Due schermate, la
/// stessa ora, due numeri diversi e nessuno che dica quale vale.
///
/// 💡 `null` quando quella seduta non è (ancora) in nessun gruppo: il riepilogo
/// si comporta come prima, che è la cosa giusta.
final voceDellaSedutaProvider = FutureProvider.autoDispose
    .family<VoceStorico?, int>((ref, sedutaId) async {
      final voci = await ref.watch(storicoUnificatoProvider.future);

      for (final v in voci) {
        if (v.sedute.any((s) => s.id == sedutaId)) return v;
      }

      return null;
    });

/// Assegna a un allenamento dell'orologio una delle proprie schede — FASE 1.10.
///
/// 💡 È la richiesta del 19/08 detta così: *«devo poter scegliere di assegnarvi
/// una mia scheda»*. `null` toglie l'assegnazione, perché una scelta che non si
/// può disfare è una trappola.
///
/// ⚠️ `WidgetRef` e non `Ref`: la chiama una schermata, non un provider. Sono
/// due tipi diversi e non imparentati — `Ref` vive dentro il grafo, `WidgetRef`
/// lo guarda da fuori.
Future<void> assegnaSchedaAllAllenamento(
  WidgetRef ref, {
  required int allenamentoId,
  required int? schedaId,
}) async {
  await ref
      .read(archivioSaluteProvider)
      .assegnaSchedaAllenamento(allenamentoId, schedaId);

  ref.read(revisioneAllenamentiProvider.notifier).state++;
}

/// Dichiara che tipo di allenamento era — 3b-B.20.5, 25/08/2026.
///
/// 📌 *«voglio poterci assegnare anche un tipo di allenamento diverso dalla
/// scheda. Tipo corsa, bicicletta, nuoto, ste cose qui, in modo che possa
/// stimare i muscoli coinvolti e le calorie»*.
///
/// 💡 `null` toglie la dichiarazione e rimette in gioco quello dell'orologio:
/// una scelta che non si può disfare è una trappola. È la stessa regola di
/// [assegnaSchedaAllAllenamento], e non è un caso — sono lo stesso gesto su due
/// campi diversi: *«quella cosa lì, in realtà, era questa»*.
Future<void> dichiaraTipoAllenamento(
  WidgetRef ref, {
  required int allenamentoId,
  required String? codice,
}) async {
  await ref
      .read(archivioSaluteProvider)
      .dichiaraTipoAllenamento(allenamentoId, codice);

  ref.read(revisioneAllenamentiProvider.notifier).state++;
}

/// Corregge a mano le calorie di un allenamento del polso — 3b-C.4.
///
/// 💡 `null` toglie la correzione e rimette in gioco quelle dell'orologio: è la
/// stessa regola di [dichiaraTipoAllenamento] e di [assegnaSchedaAllAllenamento]
/// — una scelta che non si può disfare è una trappola.
Future<void> correggiKcalAllenamento(
  WidgetRef ref, {
  required int allenamentoId,
  required int? kcal,
}) async {
  await ref
      .read(archivioSaluteProvider)
      .correggiKcalAllenamento(allenamentoId, kcal);

  ref.read(revisioneAllenamentiProvider.notifier).state++;
}

/// «Non è lo stesso allenamento» — FASE 1-bis.
///
/// ── 🚨 È la contropartita della regola larga ──────────────────────────────
///
/// Dal 20/08 basta **un istante** di sovrapposizione perché due registrazioni
/// finiscano nella stessa riga (decisione D-1bis/A). ⚠️ Senza questo comando un
/// raggruppamento sbagliato farebbe **sparire** un allenamento vero dallo
/// storico, e non ci sarebbe modo di riaverlo.
///
/// 💡 Il committente l'ha messa proprio come uno scambio: *«se i timeframes si
/// sovrappongono allora è lo stesso allenamento. Poi ci mettiamo la possibilità
/// di splittarli e via»*. Le due cose stanno o cadono insieme.
Future<void> staccaAllenamento(
  WidgetRef ref, {
  required int allenamentoId,
  required bool staccato,
}) async {
  await ref
      .read(archivioSaluteProvider)
      .staccaAllenamento(allenamentoId, staccato: staccato);

  ref.read(revisioneAllenamentiProvider.notifier).state++;
}

/// Toglie un allenamento dallo storico — 3b-B.20.2, 25/08/2026.
///
/// ══ 📌 LA RICHIESTA ═══════════════════════════════════════════════════════
///
/// *«possibilità di rimuovere un allenamento»*.
///
/// ══ 🚨 DUE GESTI DIVERSI, PERCHÉ LE DUE COSE SONO DIVERSE ═════════════════
///
/// | Cosa | Come sparisce | Perché |
/// |---|---|---|
/// | le sedute dell'app | **cancellate**, serie comprese | vivono solo qui: cancellarle è definitivo |
/// | le righe dell'orologio | **nascoste** | ⛔ una `DELETE` non basterebbe |
///
/// ⛔ **Cancellare una riga dell'orologio non la fa sparire**: il dato vero sta
/// in Health Connect, e `scriviAllenamenti()` la reinserisce alla prossima
/// sincronizzazione — `insertOrIgnore` su `(fonte, iniziatoIl)` non ritrova
/// niente, quindi ricrea la riga. 🚨 Chi la togliesse così se la vedrebbe
/// tornare da sola dopo mezz'ora, e sarebbe un difetto della specie peggiore:
/// funziona finché non guardi.
///
/// 💡 `nascosto` esiste apposta ed è **già** ciò che lo storico salta. La
/// differenza con il vecchio comando «nascondi» non è tecnica, è di intenzione:
/// lì si toglieva dagli occhi una riga sola, qui si toglie **l'allenamento**,
/// con tutto quello che ci sta dentro.
///
/// ⚠️ Chi chiama **deve** aver chiesto conferma, e la conferma deve dire cosa si
/// porta via: le serie registrate spariscono per sempre, e le calorie escono dal
/// bilancio della giornata. ⛔ Una cancellazione che non dice cosa cancella è la
/// cosa che il 24/08 ha fatto sparire due esercizi.
Future<void> rimuoviAllenamento(WidgetRef ref, VoceStorico voce) async {
  final archivio = ref.read(archivioSaluteProvider);

  for (final seduta in voce.sedute) {
    await archivio.cancellaSeduta(seduta.id);
  }

  for (final dal in voce.dalPolso) {
    await archivio.nascondiAllenamento(dal.id, nascosto: true);
  }

  ref.read(revisioneAllenamentiProvider.notifier).state++;
  ref.invalidate(sessionsProvider);
}

/// Cosa si porta via la rimozione, detto in una frase.
///
/// 🚨 **Si contano le cose vere, non si dice «tutto»**: «12 serie registrate»
/// ferma la mano, «questo allenamento» no. ⚠️ E le due provenienze hanno destini
/// diversi — vedi [rimuoviAllenamento] — quindi la frase lo dice.
String cosaSiPortaViaLaRimozione(VoceStorico voce) {
  final pezzi = <String>[];

  var serie = 0;
  for (final s in voce.sedute) {
    serie += s.sets.length;
  }

  if (serie > 0) {
    pezzi.add(serie == 1 ? '1 serie registrata' : '$serie serie registrate');
  }

  final kcal = voce.kcal;
  if (kcal != null && kcal > 0) pezzi.add('$kcal kcal dal bilancio di oggi');

  if (pezzi.isEmpty) return 'Sparirà dallo storico.';

  return 'Spariranno anche ${pezzi.join(' e ')}.';
}
