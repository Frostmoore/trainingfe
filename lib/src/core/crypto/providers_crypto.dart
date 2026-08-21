import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sodium_libs/sodium_libs_sumo.dart';

import '../providers.dart';
import 'portachiavi.dart';
import 'servizio_chiavi.dart';

/// I provider della crittografia — S6.4.

/// libsodium, **una volta sola per tutta l'app**.
///
/// 🚨 Due inizializzazioni funzionerebbero entrambe, ma le `SecureKey` prodotte
/// da una **non sono utilizzabili** con l'altra: la memoria protetta appartiene
/// all'istanza che l'ha allocata. Il guasto arriverebbe lontano dal punto che
/// l'ha causato, ed è il tipo di errore che si insegue per un giorno.
///
/// ⚠️ È `SodiumSumoInit` e non `SodiumInit`: **Argon2id (`crypto_pwhash`) esiste
/// solo nell'API sumo**, ed è la derivazione su cui poggia l'intera password di
/// recupero.
final sodiumProvider = FutureProvider<SodiumSumo>(
  (ref) => SodiumSumoInit.init(),
);

final portachiaviProvider = Provider<Portachiavi>((ref) => Portachiavi());

/// Il servizio che tiene insieme chiave maestra, ripristino e cifratura.
final servizioChiaviProvider = FutureProvider<ServizioChiavi>((ref) async {
  /*
   * ⚠️ **Le `ref.watch` prima dell'`await`, anche qui.**
   *
   * Gli argomenti si valutano in ordine: con `await ref.watch(sodium…)` come
   * primo, `api` e `portachiavi` venivano osservati **dopo una pausa
   * asincrona**, e in Riverpod lì `ref.watch` non registra più la dipendenza.
   *
   * 💡 Oggi non fa danni — sono due singleton che non cambiano mai — ma è lo
   * stesso errore che sul target calorico è costato una serata di prove. Un
   * difetto latente in un file di crittografia non è il posto dove lasciarlo.
   */
  final api = ref.watch(apiClientProvider);
  final portachiavi = ref.watch(portachiaviProvider);
  final sodium = await ref.watch(sodiumProvider.future);

  return ServizioChiavi(sodium: sodium, api: api, portachiavi: portachiavi);
});

/// Cosa deve fare l'app adesso: creare la password, ripristinare, o niente.
///
/// ⚠️ **Non è `autoDispose`**: rifarne la valutazione a ogni schermata
/// significherebbe una chiamata di rete in più a ogni giro, e — peggio — un
/// istante in cui lo stato è «sto caricando» proprio mentre l'utente sta
/// digitando la password.
final statoChiaviProvider = FutureProvider<StatoChiavi>((ref) async {
  final servizio = await ref.watch(servizioChiaviProvider.future);

  return servizio.stato();
});
