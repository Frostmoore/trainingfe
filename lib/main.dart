import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'src/app.dart';
import 'src/core/backup/backup_che_gira_da_solo.dart';
import 'src/core/backup/backup_in_background.dart';
import 'src/core/config/app_config.dart';
import 'src/core/media/archivio_foto.dart';
import 'src/core/notifications/notifications.dart';
import 'src/core/providers.dart';
import 'src/core/storage/local_cache.dart';
import 'src/features/aggiornamento/aggiornamento_controller.dart';
import 'src/features/auth/auth_controller.dart';

/// L'avvio — A1.1.
///
/// 🚨 **Tutto quello che è asincrono succede QUI, non nel primo `build()`.**
/// Un widget che aspetta `SharedPreferences.getInstance()` mostra mezzo secondo
/// di schermata bianca a ogni apertura — ed è la prima cosa che si nota di
/// un'app. Qui invece si costruisce il necessario, si sovrascrivono i provider
/// che non possono costruirsi da soli, e l'albero parte già completo.
Future<void> main() async {
  // `runZonedGuarded` avvolge tutto: senza, un errore asincrono fuori dal ciclo
  // dei widget termina il processo senza lasciare traccia, e l'utente vede
  // l'app «che si chiude da sola».
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // I nomi dei mesi in italiano: `DateFormat(…, 'it')` lancia se questa non
    // è stata chiamata, e lo fa alla **prima data formattata**, cioè in una
    // schermata a caso e non all'avvio.
    await initializeDateFormatting('it');

    // 🚨 Il fuso e i canali delle notifiche: senza, `tz.local` lancia alla
    // prima serie registrata nel player — in palestra, non all'avvio.
    await initNotifications();

    FlutterError.onError = (dettagli) {
      FlutterError.presentError(dettagli);
      _segnala(dettagli.exception, dettagli.stack);
    };

    final config = AppConfig.fromEnvironment();
    final cache = await LocalCache.open();

    /*
       * 🆕 FASE 2.1 — si dice ad Android **a chi** dare il lavoro in background.
       *
       * 🚨 `initialize` registra il punto d'ingresso, **non pianifica niente**:
       * la pianificazione la fa `accendi()` sull'interruttore del backup. Qui
       * si prepara solo il canale, e va fatto a ogni avvio perche' e' il
       * processo che nasce, non il lavoro.
       *
       * ⚠️ **Non deve poter impedire l'apertura dell'app.** Se il telefono non
       * concede WorkManager, si apre lo stesso: c'e' il backup che parte
       * all'accesso, e quello non dipende da Android.
       */
    try {
      await const BackupInBackground().avvia();
    } on Object catch (errore, stack) {
      debugPrintStack(
        label: 'WorkManager non disponibile: $errore',
        stackTrace: stack,
      );
    }

    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(config),
        localCacheProvider.overrideWithValue(cache),
      ],
    );

    // 🚨 Si fa partire il ripristino della sessione **prima** di disegnare:
    // il router resta su `AuthStatus.unknown` e non decide niente finché non
    // c'è una risposta. Senza, ogni avvio manderebbe al login per la frazione
    // di secondo che serve a leggere il Keychain — e quel salto si vede.
    /*
       * 🆕 **Il cancello della versione si accende all'avvio** — FASE 10.
       *
       * 🚨 `read` e non `watch`: serve solo a **farlo nascere**, perché è nel
       * costruttore che si iscrive allo stream dei 426. ⚠️ Senza questa riga il
       * controller nascerebbe alla prima `watch` — cioè dentro `builder` di
       * `MaterialApp`, dopo che la prima richiesta è già partita: e quel 426
       * andrebbe perso, perché uno stream broadcast non conserva niente per chi
       * arriva dopo.
       */
    container.read(aggiornamentoProvider);

    /*
     * ══ 💾 IL BACKUP AUTOMATICO PARTE A SESSIONE APERTA — 24/08/2026 ═══════
     *
     * 📌 Il committente: *«Non parte, l'avevamo controllato. Facciamo che parte
     * comunque quando apri l'app»* (2q.4, 23/08).
     *
     * 🚨 **Ma non "quando l'app si apre": quando la sessione è aperta.** Il
     * 23/08 partiva subito dopo `restore()`, e con il blocco biometrico acceso
     * quello è **prima** che la persona sia entrata. Risultato, misurato con
     * venti schermate a 0,2 s l'una:
     *
     * ⛔ il foglio «Accesso» di Google saliva **sopra la schermata di blocco**,
     * rubava il fuoco al prompt dell'impronta e lo faceva fallire — la
     * schermata diceva *«Non è andata. Riprova»*. Il backup non era solo brutto
     * da vedere: **impediva di entrare nell'app**.
     *
     * 💡 Ora si aspetta lo stato `loggedIn`, che copre tutte e tre le
     * strade — sessione ripristinata senza blocco, sblocco con l'impronta,
     * accesso con la password — senza che nessuna di loro debba saperlo.
     *
     * ⚠️ **Una volta per avvio.** `loggedIn` si ripresenta a ogni
     * `_loadMe()`, e senza la guardia il backup ripartirebbe a ogni rientro
     * dalla schermata di blocco.
     *
     * ⛔ **Non sostituisce il lavoro notturno di WorkManager**: quello copre
     * chi l'app non la apre più, che è precisamente la persona a cui il backup
     * serve di più. Questo copre chi la apre.
     */
    var backupPartito = false;

    container.listen<AuthState>(authControllerProvider, (_, stato) {
      if (backupPartito || stato.status != AuthStatus.loggedIn) return;

      backupPartito = true;

      // 💡 `unawaited`: un backup può metterci secondi, e nessuna schermata
      // deve aspettarlo. Se fallisce lo dice la pagina «Backup e dati».
      unawaited(container.read(avvioBackupProvider.future));
    }, fireImmediately: true);

    unawaited(container.read(authControllerProvider.notifier).restore());

    /*
     * ⛔ **Qui c'era il riallineamento del branding** — tolto il 27/08/2026.
     *
     * Chiamava `refreshQuietly()`, che rileggeva `/branding/lookup` con il
     * codice palestra in cache. 🚨 Da 3b-J.1 quel codice non lo scrive più
     * nessuno: il branding arriva insieme all'utente, e `restore()` — la riga
     * qui sopra — passa da `/auth/me`, che lo restituisce già.
     *
     * 💡 Una richiesta in meno a ogni avvio, e una fonte sola invece di due che
     * potevano dire cose diverse.
     */

    /*
       * 🧹 **La spazzata delle foto scadute** — N11.6.
       *
       * Butta quello che e' rimasto in `Cache/foto/ai` e `Cache/foto/effimere`
       * oltre le 24 ore. ⚠️ Serve perche' l'app puo' morire fra lo scatto di
       * una foto per il modello e la conferma dell'alimento: quell'orfano non
       * lo cancellerebbe piu' nessuno.
       *
       * 💡 `unawaited` di proposito: e' un giro di disco su cartelle quasi
       * sempre vuote, e non deve rallentare di un millisecondo il primo
       * disegno. Se fallisce, riprova al prossimo avvio.
       */
    unawaited(
      const ArchivioFoto().spazzaGliOrfani().catchError((Object _) => 0),
    );

    /*
     * ══ 📱 SOLO IN VERTICALE — 22/08/2026 ═══════════════════════════════════
     *
     * 📌 Il committente: *«facciamo che l'app deve funzionare solo in portrait
     * mode, mi rompe troppo il cazzo che si gira»*.
     *
     * 🚨 **Due posti, e servono tutti e due.** Il manifest (`screenOrientation`)
     * impedisce ad Android di ruotare **la finestra**, ed è quello che evita il
     * lampo di ridisegno; questa riga vale per iOS, dove il manifest non
     * esiste, e resta l'unica difesa se un domani qualcuno tocca il manifest
     * senza sapere perché c'era.
     *
     * ⚠️ E non è solo fastidio: mezza app è stata disegnata e misurata in
     * verticale — l'intestazione a due righe, i valori nel `Wrap`, i grafici a
     * `SizedBox` fissa. In orizzontale nessuno di quei numeri è stato provato.
     */
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    runApp(
      UncontrolledProviderScope(
        container: container,
        child: const TrainingCompanionApp(),
      ),
    );
  }, (errore, stack) => _segnala(errore, stack));
}

/// Il punto unico in cui finiscono gli errori non gestiti.
///
/// Oggi scrive solo sulla console in sviluppo. È scritto così perché il giorno
/// in cui si aggiunge un servizio di crash reporting ci sia **un posto solo** da
/// toccare, invece di cercare tutti i `catch` sparsi.
void _segnala(Object errore, StackTrace? stack) {
  if (kDebugMode) {
    debugPrint('Errore non gestito: $errore\n$stack');
  }
}
