import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../privacy/consensi_controller.dart';
import 'analizzatore_sonno.dart';
import 'dati_salute.dart';
import 'health_controller.dart';
import 'media_di_riferimento.dart';

/// Il recupero di oggi, **letto dal telefono** — S4.3.
///
/// 🚨 **Questa è la sostituzione della sezione che il backend mandava.**
/// Fino a `v4.8.1` `GET /dashboard` restituiva `sleep` e `vitals`; dopo S1 non
/// li ha più, e questi provider prendono il loro posto leggendo da
/// `ArchivioSalute`.
///
/// ⚠️ **È l'eccezione dichiarata a §8.3 dell'atlante** — *«le decisioni del
/// server non si riscrivono in Dart»*. Qui si riscrivono, e la ragione è
/// precisa: **il server non ha più i dati, quindi non può decidere**. Non è un
/// precedente per riportare in Dart una regola che il server potrebbe ancora
/// applicare; è ciò che resta quando il dato non gli arriva.
class Recupero {
  const Recupero({this.notte, this.parametri = const {}});

  final GiudizioNotte? notte;
  final Map<MetricaSalute, LetturaConMedia> parametri;

  /// Se c'è qualcosa da mostrare. Sostituisce l'`has_any` che mandava il
  /// backend: senza, l'interfaccia dovrebbe dedurlo da tre `null`.
  bool get haQualcosa => notte != null || parametri.isNotEmpty;
}

/// Il recupero della notte più recente per cui esistono dati.
///
/// ⚠️ **La notte più recente, non «stanotte».** Chi apre l'app alle 18 dopo una
/// giornata senza sincronizzazione vedrebbe altrimenti una scheda vuota pur
/// avendo dormito: il dato c'è, è solo di ieri.
final recuperoProvider = FutureProvider.autoDispose<Recupero>((ref) async {
  /*
   * 🚨 **TUTTE le `ref.watch` qui, PRIMA di qualunque `await`.**
   *
   * In Riverpod le dipendenze si registrano durante la costruzione **sincrona**:
   * dopo una pausa asincrona `ref.watch` si comporta come `ref.read` e **non si
   * iscrive**. Il difetto non dà errori — si manifesta come «l'app non si
   * aggiorna finché non cambio schermata», ed è costato una serata di prove
   * sul target calorico (vedi `targetLocaleProvider`).
   *
   * ⚠️ Qui il prezzo sarebbe stato peggiore: `consensoSaluteProvider` era
   * osservato **dopo** un `await`, quindi **revocare il consenso non avrebbe
   * spento il recupero** finché non si cambiava schermata — cioè proprio il
   * difetto che quella riga era stata scritta per chiudere.
   */
  final archivio = ref.watch(archivioSaluteProvider);

  // Si ricalcola quando il ponte scrive: senza questa dipendenza, collegare
  // Health Connect non aggiornerebbe la dashboard fino al riavvio dell'app.
  ref.watch(healthControllerProvider);

  final consenso = ref.watch(consensoSaluteProvider.future);
  final avvio = ref.watch(avvioSaluteProvider.future);

  /*
   * 🚨 **Si aspetta la risincronizzazione d'avvio prima di leggere** — A5.
   *
   * Senza, la scheda in cima a «Oggi» mostrerebbe i dati vecchi dell'archivio e
   * poi, mezzo secondo dopo, salterebbe a quelli nuovi. ⚠️ Un numero che cambia
   * da solo sotto gli occhi è peggio di un numero che tarda: fa dubitare di
   * entrambi i valori.
   *
   * 💡 Non costa niente quando non c'è niente da fare: `aggiornaInSilenzio()`
   * esce subito se il consenso manca o se il permesso di sistema non c'è, e
   * `avvioSaluteProvider` gira **una volta per avvio**.
   */
  await avvio;

  /*
   * 🚨 **Revocare il consenso spegne il recupero, subito** — difetto trovato
   * provando l'app il 12/08.
   *
   * Prima la revoca fermava la **lettura** da Health Connect
   * (`aggiornaInSilenzio()`), ⚠️ ma non toccava quello che era già
   * nell'archivio: la scheda del sonno in cima a «Oggi» e la sezione recupero
   * restavano lì con i dati di prima. Per chi aveva appena revocato sembrava
   * — a ragione — che la revoca non avesse funzionato.
   *
   * 💡 **Si smette di mostrare, NON si cancella.** I dati sono sul telefono e
   * sono suoi: buttarli via a un tocco su un interruttore sarebbe una perdita
   * irreversibile decisa al posto suo. Per cancellarli davvero c'è
   * «Cancella tutto» in Sonno e recupero, che chiede conferma.
   *
   * 🚨 In dubbio si spegne: un errore di rete sui consensi non deve poter
   * **mostrare** dati sanitari. È la stessa regola del cancello di A5, e vale
   * nello stesso verso.
   */
  if (!await consenso) return const Recupero();

  final ultima = await archivio.ultimaNotteConDati();

  return Recupero(
    notte: ultima == null
        ? null
        : await AnalizzatoreSonno.notte(archivio, ultima),
    parametri: await MediaDiRiferimento.tutte(archivio),
  );
});

/// Il recupero **nella forma che il consiglio del giorno si aspetta** — 16/08/2026.
///
/// ── 🚨 I nomi sono quelli del server, non i nostri ────────────────────────
///
/// `AiController::RECUPERO` è una **lista bianca**: quello che non ha
/// esattamente questi nomi non parte, e non lo dice a nessuno. ⚠️ Un `hrv` al
/// posto di `hrv_ms` non darebbe errore — darebbe un consiglio che ignora la
/// variabilità, e nessuno capirebbe perché.
///
/// ── 💡 Perché i `baseline` viaggiano insieme ai valori ────────────────────
///
/// Un HRV di 48 non vuol dire niente da solo: vuol dire qualcosa solo contro la
/// media di quella persona. Mandare il valore senza la sua media significa dare
/// al modello un numero che **non può leggere** — e un modello che non può
/// leggere un numero se lo inventa.
///
/// 🎯 Restituisce una mappa vuota quando non c'è niente da dire: senza le ore
/// dormite il server scarta tutto comunque, e mandare metà quadro sarebbe
/// traffico per niente.
final recuperoPerIlConsiglioProvider =
    FutureProvider.autoDispose<Map<String, Object>>((ref) async {
      final r = await ref.watch(recuperoProvider.future);
      final notte = r.notte;

      if (notte == null) return const {};

      final hrv = r.parametri[MetricaSalute.hrv];
      final battito = r.parametri[MetricaSalute.battitoARiposo];

      return {
        // ⚠️ Ore, non minuti: è l'unità che il prompt nomina.
        'hours': (notte.minutiDormiti / 60).toStringAsFixed(1),
        'wakings': notte.minutiSvegli,
        'deep_min': notte.minutiProfondo,
        'rem_min': notte.minutiRem,

        if (hrv != null) 'hrv_ms': hrv.valore.round(),
        if (hrv?.media != null) 'hrv_baseline_ms': hrv!.media!.round(),

        if (battito != null) 'resting_hr': battito.valore.round(),
        if (battito?.media != null)
          'resting_hr_baseline': battito!.media!.round(),
      };
    });
