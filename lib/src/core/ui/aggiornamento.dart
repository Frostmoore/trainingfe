/// Cosa vuol dire «strisciare in giù» — FASE 1-ter, 20/08/2026.
///
/// ── 🚨 Il difetto di aspettativa che chiude ───────────────────────────────
///
/// La sincronizzazione con Health Connect girava **una volta per apertura
/// dell'app** (`avvioSaluteProvider`, che non è `autoDispose` apposta). ⚠️ Chi
/// lasciava l'app aperta, andava ad allenarsi e tornava **non vedeva niente di
/// nuovo** finché non la chiudeva e riapriva — e non aveva nessun modo di
/// forzarla.
///
/// 📌 Il committente: *«voglio che in generale ogni volta che aggiorno
/// strisciando si risincronizzi google health»*.
///
/// 💡 Strisciare in giù è il gesto che **tutti** conoscono per dire «riprova».
/// Che non facesse ripartire l'unica cosa che ne aveva bisogno era un difetto di
/// aspettativa, non di codice.
///
/// ── 🚨 Un punto solo, e non nove copie ────────────────────────────────────
///
/// I `RefreshIndicator` dell'app sono **nove**. ⚠️ Nove copie della stessa
/// chiamata divergono sempre: fra sei mesi due schermate risincronizzerebbero e
/// sette no, e nessuno saprebbe dire quali.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/health/health_controller.dart';

/// Aggiorna quello che serve a questa schermata, **e** risincronizza Health.
///
/// ── ⚠️ Perché non aspetta Health ──────────────────────────────────────────
///
/// Perché leggere Health Connect richiede **secondi** sul telefono vero, e la
/// rotellina dello strisciamento è un gesto che deve chiudersi subito. 🚨 Se
/// aspettasse, strisciare su «Oggi» diventerebbe un'attesa di due secondi **ogni
/// volta**, per un dato che nella maggior parte dei casi non è cambiato.
///
/// 💡 E non serve aspettare: quando la sincronizzazione finisce, `HealthController`
/// incrementa `revisioneAllenamentiProvider` e le schermate si riaggiornano da
/// sole. È lo stesso meccanismo del difetto «scrivere non basta» (§47.9-bis) —
/// qui viene riusato invece di inventarne un altro.
///
/// ⚠️ **`unawaited` è dichiarato, non dimenticato**: senza, l'analizzatore
/// segnalerebbe un future non atteso e qualcuno «riparerebbe» mettendoci un
/// `await`, cioè rimettendo l'attesa che stiamo togliendo.
Future<void> aggiornaTutto(
  BuildContext context,
  WidgetRef ref,
  void Function() invalida,
) async {
  invalida();

  /*
   * 🚨 Il messaggero si prende **adesso**, non dopo.
   *
   * ⚠️ `ScaffoldMessenger.of(context)` dopo un `await` è il classico uso di un
   * `BuildContext` attraverso un salto asincrono: se nel frattempo la schermata
   * è sparita, lancia. Qui non c'è ancora nessun `await` di mezzo, e il
   * riferimento sopravvive alla schermata.
   */
  final messaggero = ScaffoldMessenger.of(context);

  unawaited(
    ref
        .read(risincronizzazioneHealthProvider)
        .forse(annuncia: () => _diCheStaLavorando(messaggero)),
  );
}

/// Il toast che dice che qualcosa sta succedendo — FASE 1-ter, 20/08/2026.
///
/// ── 🚨 Perché serve, ed è la stessa lezione di due giorni fa ──────────────
///
/// Togliendo l'attesa alla rotellina il gesto era diventato **muto**: si
/// strisciava, la rotellina si chiudeva subito, e i dati dell'orologio
/// arrivavano qualche secondo dopo senza che niente lo avesse detto. ⚠️ È
/// esattamente la forma del difetto del ripristino silenzioso (§2t.8) — *«non
/// era lento: era muto, e dieci secondi muti non si distinguono da un guasto»*.
///
/// 📌 Proposto dal committente: *«ci mettiamo un toast che dice "Aggiornamento
/// dati in corso..."»*.
///
/// ── ⚠️ Solo quando parte DAVVERO ──────────────────────────────────────────
///
/// Se la soglia blocca la sincronizzazione il toast **non compare**. 🚨 Altrimenti
/// cinque strisciate darebbero cinque toast su un lavoro che non sta
/// succedendo: una bugia gentile, che è comunque una bugia — e la seconda volta
/// che uno se ne accorge smette di credere anche ai messaggi veri.
void _diCheStaLavorando(ScaffoldMessengerState messaggero) {
  messaggero
    /*
     * 💡 Si toglie quello di prima invece di accodarlo. Senza, due
     * strisciamenti a mezzo minuto di distanza lascerebbero il secondo messaggio
     * in coda dietro al primo, e comparirebbe quando il lavoro è già finito.
     */
    ..hideCurrentSnackBar()
    ..showSnackBar(
      const SnackBar(
        content: Text('Aggiornamento dati in corso…'),
        // ⚠️ Corto: descrive un lavoro che dura un paio di secondi, e un
        // messaggio che resta più a lungo del lavoro che annuncia mente.
        duration: Duration(seconds: 2),
      ),
    );
}

/// La risincronizzazione, ma non più spesso di [attesaMinima].
///
/// ── 🚨 Perché una soglia ──────────────────────────────────────────────────
///
/// Perché chi striscia cinque volte di fila — e capita, quando si aspetta che
/// qualcosa compaia — non deve far partire cinque letture di Health Connect.
/// ⚠️ Ognuna apre il canale nativo, legge trenta giorni di campioni e riscrive
/// l'archivio: cinque insieme non fanno arrivare i dati prima, fanno solo
/// scaldare il telefono.
///
/// 💡 **Trenta secondi**: abbastanza da assorbire una raffica di strisciamenti,
/// abbastanza poco da non far sembrare l'app sorda a chi riprova dopo mezzo
/// minuto perché *davvero* è cambiato qualcosa.
class RisincronizzazioneHealth {
  RisincronizzazioneHealth(
    this._sincronizza, {
    DateTime Function()? adesso,
    Duration? attesa,
  }) : _adesso = adesso ?? DateTime.now,
       _attesa = attesa ?? attesaMinima;

  static const attesaMinima = Duration(seconds: 30);

  /// 🚨 **`aggiornaInSilenzio`, mai `collega`.** Quella chiede il permesso, e un
  /// permesso chiesto per uno strisciamento distratto è un permesso **negato per
  /// sempre**: su Android un rifiuto ripetuto non si ripropone più.
  ///
  /// ⚠️ È la regola già scritta nel dartdoc di `PonteSalute.chiediPermessi()`, e
  /// qui va ripetuta perché è il punto in cui è più facile violarla senza
  /// accorgersene.
  final Future<void> Function() _sincronizza;

  /// 💡 Iniettabile perché un test non può aspettare trenta secondi veri, e
  /// perché `DateTime.now()` dentro una classe la rende non verificabile.
  final DateTime Function() _adesso;
  final Duration _attesa;

  DateTime? _ultima;

  /// Torna `true` se la sincronizzazione è **partita davvero**.
  ///
  /// 💡 Il valore serve ai test: dal di fuori «non è partita» e «è partita e non
  /// ha trovato niente» sono indistinguibili, ed è precisamente la differenza
  /// che la soglia introduce.
  ///
  /// [annuncia] viene chiamato **nell'istante in cui si decide di partire**, e
  /// solo allora. 🚨 Serve al toast: prima di questa riga non si sa ancora se il
  /// lavoro ci sarà, e annunciare un lavoro che la soglia sta per bloccare
  /// vorrebbe dire mentire.
  ///
  /// ⚠️ È chiamato **prima** del primo `await`, quindi in modo sincrono rispetto
  /// a chi ha strisciato: il messaggio compare con il gesto, non un fotogramma
  /// dopo.
  Future<bool> forse({void Function()? annuncia}) async {
    final ora = _adesso();
    final ultima = _ultima;

    if (ultima != null && ora.difference(ultima) < _attesa) return false;

    /*
     * ⚠️ Il segnaposto si scrive **prima**, non dopo.
     *
     * 🚨 Scrivendolo alla fine, cinque strisciamenti dentro il secondo che
     * serve a leggere partirebbero **tutti**: nessuno di loro troverebbe una
     * data recente, perche' la prima non l'ha ancora scritta. La soglia
     * proteggerebbe solo da chi e' gia' lento.
     */
    _ultima = ora;

    annuncia?.call();

    try {
      await _sincronizza();

      return true;
    } on Object catch (errore, stack) {
      /*
       * ⚠️ Un guasto qui **non deve rompere lo strisciamento**: la parte
       * principale dell'aggiornamento e' la rete, e Health e' un di piu'. 💡 Ma
       * si dice, perche' una ricaduta silenziosa e' la stessa forma del difetto
       * «scrivere non basta».
       */
      debugPrintStack(
        label: 'RisincronizzazioneHealth: $errore',
        stackTrace: stack,
      );

      return true;
    }
  }
}

/// ⚠️ **Non `autoDispose`**: la soglia vive nell'istanza, e un provider che
/// muore quando l'ultima schermata sparisce si porterebbe via la memoria di
/// quando è stata l'ultima sincronizzazione. 🚨 Cambiare scheda azzererebbe la
/// soglia, cioè la toglierebbe di mezzo proprio nel caso in cui serve.
final risincronizzazioneHealthProvider = Provider<RisincronizzazioneHealth>(
  (ref) => RisincronizzazioneHealth(
    () => ref.read(healthControllerProvider.notifier).aggiornaInSilenzio(),
  ),
);
