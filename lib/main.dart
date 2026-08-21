import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'src/app.dart';
import 'src/core/backup/backup_in_background.dart';
import 'src/core/config/app_config.dart';
import 'src/core/media/archivio_foto.dart';
import 'src/core/notifications/notifications.dart';
import 'src/core/providers.dart';
import 'src/core/storage/local_cache.dart';
import 'src/features/aggiornamento/aggiornamento_controller.dart';
import 'src/features/auth/auth_controller.dart';
import 'src/features/onboarding/branding_controller.dart';
import 'src/features/training/trasloco_allenamenti.dart';

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

    unawaited(
      container.read(authControllerProvider.notifier).restore().then((_) {
        /*
         * ══ 🏋️ IL TRASLOCO DEGLI ALLENAMENTI — FASE 11.3 ═══════════════════
         *
         * 📌 Il committente: *«Nessun allenamento deve risiedere sul server,
         * devono stare tutti nell'app»*.
         *
         * 🚨 **Dopo `restore()`, non prima**: senza una sessione il server
         * risponde 401, il trasloco fallisce e — peggio — il primo avvio dopo
         * l'aggiornamento sarebbe anche l'unico tentativo che qualcuno guarda.
         *
         * 💡 `unawaited` e senza bloccare niente: se non riesce si riprova al
         * prossimo avvio, e finché non riesce i dati sono ancora **tutti** sul
         * server. ⛔ Nessuno cancella niente prima che questo abbia confermato.
         */
        unawaited(container.read(traslocoAllenamentiProvider).seServe());
      }),
    );

    // Il branding si riallinea in sottofondo: se fallisce, resta quello in
    // cache. I colori sbagliati sono un problema estetico, un'app che non
    // parte no.
    unawaited(
      container.read(brandingControllerProvider.notifier).refreshQuietly(),
    );

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
