import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api/api_client.dart';
import 'config/app_config.dart';
import 'storage/local_cache.dart';
import 'storage/token_store.dart';

/// I provider delle fondamenta — A1.1.
///
/// 🚨 **Riverpod fa anche da contenitore di dipendenze**: non c'è un secondo
/// pacchetto per l'iniezione. Il motivo è che un service locator separato
/// permette di prendere una dipendenza da qualunque punto del codice, e a quel
/// punto nessun test può sostituirla senza toccare uno stato globale. Con i
/// provider la sostituzione è un `override` sul contenitore del test.
///
/// I tre `throw UnimplementedError()` non sono dimenticanze: sono provider che
/// **devono** essere sovrascritti in `bootstrap()`, perché costruirli richiede
/// operazioni asincrone che non si possono fare dentro un `build()`. Se
/// qualcuno li usa senza averli inizializzati, l'app esplode subito e in modo
/// leggibile invece di comportarsi in modo strano.

/// Sovrascritto in `bootstrap()`.
final appConfigProvider = Provider<AppConfig>((ref) {
  throw UnimplementedError('appConfigProvider va sovrascritto in bootstrap()');
});

/// Sovrascritto in `bootstrap()`: `SharedPreferences.getInstance()` è asincrona.
final localCacheProvider = Provider<LocalCache>((ref) {
  throw UnimplementedError('localCacheProvider va sovrascritto in bootstrap()');
});

final tokenStoreProvider = Provider<TokenStore>((ref) => TokenStore());

/// Il client HTTP, uno solo per tutta l'app.
///
/// `keepAlive` implicito (è un `Provider`, non `autoDispose`): ricrearlo
/// significherebbe perdere lo stream `onSessionExpired` a cui il router è
/// iscritto.
final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(
    config: ref.watch(appConfigProvider),
    tokenStore: ref.watch(tokenStoreProvider),
  );

  ref.onDispose(client.dispose);

  return client;
});
