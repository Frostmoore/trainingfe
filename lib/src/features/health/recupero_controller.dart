import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  final archivio = ref.watch(archivioSaluteProvider);

  // Si ricalcola quando il ponte scrive: senza questa dipendenza, collegare
  // Health Connect non aggiornerebbe la dashboard fino al riavvio dell'app.
  ref.watch(healthControllerProvider);

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
  await ref.watch(avvioSaluteProvider.future);

  final ultima = await archivio.ultimaNotteConDati();

  return Recupero(
    notte: ultima == null ? null : await AnalizzatoreSonno.notte(archivio, ultima),
    parametri: await MediaDiRiferimento.tutte(archivio),
  );
});
