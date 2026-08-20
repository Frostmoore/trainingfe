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

import 'package:flutter/foundation.dart';
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
Future<void> aggiornaTutto(WidgetRef ref, void Function() invalida) async {
  invalida();

  unawaited(ref.read(risincronizzazioneHealthProvider).forse());
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
  })  : _adesso = adesso ?? DateTime.now,
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
  Future<bool> forse() async {
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
