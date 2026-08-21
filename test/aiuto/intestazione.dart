import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:training_companion/src/core/config/app_config.dart';
import 'package:training_companion/src/core/providers.dart';
import 'package:training_companion/src/core/storage/local_cache.dart';
import 'package:training_companion/src/features/dashboard/gettoni_controller.dart';

/// Quello che serve a far costruire [IntestazioneApp] in un test di widget —
/// 3b-O.1a.6, 21/08/2026.
///
/// ══ 🚨 PERCHÉ SERVE, E PERCHÉ NON È UNA SCOCCIATURA ═══════════════════════
///
/// Da quando l'intestazione sta su **tutte** le pagine, ogni schermata dipende
/// dall'identità dell'app: il branding della palestra, l'utente, il saldo dei
/// gettoni. ⚠️ Quelli poggiano su `localCacheProvider` e `appConfigProvider`,
/// che di proposito **lanciano `UnimplementedError`** finché `bootstrap()` non
/// li sovrascrive (vedi `core/providers.dart`).
///
/// 🚨 **Quel `throw` è una difesa, non un difetto**: garantisce che nessuno usi
/// una cache o una configurazione inventate al posto di quelle vere. Toglierlo
/// per far passare i test vorrebbe dire spegnere il controllo che impedisce
/// all'app di partire con le impostazioni sbagliate.
///
/// 💡 Quindi la strada giusta è **dare al test quello che l'app dà a sé
/// stessa**: una cache finta in memoria e una configurazione qualunque. Il
/// saldo dei gettoni resta vuoto perché la sua chiamata non ha un server — ed è
/// esattamente il comportamento voluto anche in produzione (`orElse` disegna
/// niente).
///
/// ⚠️ **Va chiamato dopo `SharedPreferences.setMockInitialValues({})`**, che è
/// asincrono: per questo restituisce un `Future`.
Future<List<Override>> intestazioneFinta() async {
  SharedPreferences.setMockInitialValues({});
  final cache = LocalCache(await SharedPreferences.getInstance());

  return [
    localCacheProvider.overrideWithValue(cache),
    appConfigProvider.overrideWithValue(
      const AppConfig(
        environment: AppEnvironment.local,
        apiBaseUrl: 'http://localhost',
        enableDebugTools: false,
      ),
    ),

    /*
     * 🚨 **Il saldo dei gettoni non deve chiamare nessuno** — e non è una
     * comodità: `gettoniProvider` fa `GET /ai/usage`, e in un test quella
     * chiamata lascia in piedi il **timer di scadenza di dio**. Il framework se
     * ne accorge alla fine e fa fallire il test con `!timersPending`, che è un
     * errore che non nomina né la rete né i gettoni — cioè un'ora persa a
     * cercarlo nel posto sbagliato.
     *
     * 💡 Un future che non si risolve mai è lo stato «sta ancora caricando», e
     * in quello stato l'intestazione **non disegna il saldo** (`orElse`): è
     * esattamente ciò che si vuole in un test di un'altra pagina.
     */
    gettoniProvider.overrideWith((ref) => Completer<Gettoni>().future),
  ];
}
