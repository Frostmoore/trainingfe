/// Il backup che gira **anche con l'app chiusa** — FASE 2.1 (`N4.1`).
///
/// ── 🚨 Chi copre, e perché non basta l'altro ──────────────────────────────
///
/// `BackupCheGiraDaSolo` parte quando si apre l'app, ed è la rete di sicurezza
/// **certa**. ⚠️ Ma copre chi l'app la apre — e la persona a cui il backup serve
/// di più è **precisamente quella che ha smesso di aprirla**, e che fra due mesi
/// cambia telefono senza aver salvato niente.
///
/// 💡 Per questo i meccanismi sono due, e non è ridondanza: coprono due
/// popolazioni diverse che non si sovrappongono nel caso peggiore.
///
/// ══ ⚠️ QUESTO PEZZO NON È ANCORA PROVATO SU UN TELEFONO ═══════════════════
///
/// E va detto qui, perché è **esattamente il tipo di codice che sembra
/// funzionare**: un lavoro pianificato che non parte non dà nessun errore.
///
/// Le tre cose che possono non funzionare, in ordine di probabilità:
///
/// 1. 🚨 **Il produttore del telefono.** Xiaomi, Huawei, Samsung e OPPO uccidono
///    i lavori in background in modi non documentati. Su MIUI serve
///    l'avvio automatico concesso a mano.
/// 2. ⚠️ **L'autorizzazione a Google Drive senza schermata davanti.**
///    `DriveDiBackup._api()` usa `attemptLightweightAuthentication()` e
///    `authorizationForScopes()` — entrambe silenziose — ma in un isolato
///    separato, senza `Activity`, non è scontato che rispondano.
/// 3. I vincoli: sotto wi-fi, in carica, batteria non bassa. Chi non mette mai
///    il telefono in carica di notte non vedrà mai partire questo lavoro.
///
/// 💡 **Come si verifica** (è in FASE 2-quater del piano): attaccare il telefono
/// alla corrente sotto wi-fi, aspettare, e guardare `adb logcat | grep BACKUP-BG`.
/// Non c'è modo di provarlo in un test: la parte che può rompersi è
/// **fuori** da Dart.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';

import '../config/app_config.dart';
import '../providers.dart';
import '../storage/local_cache.dart';
import 'backup_che_gira_da_solo.dart';

/// Il nome con cui il lavoro è registrato presso Android.
///
/// ⚠️ **Uno solo, e stabile.** `ExistingPeriodicWorkPolicy.keep` fa sì che
/// riaprire l'app non ne accodi un altro: senza, ogni avvio ne lascerebbe uno in
/// più e il telefono farebbe backup a raffica.
const nomeDelLavoro = 'backup-automatico-giornaliero';

const _compito = 'backup';

/// ⚠️ **Quindici minuti è il minimo che Android accetta**, ma qui la frequenza è
/// un giorno: chi decide davvero quando è ora è `BackupCheGiraDaSolo.ogniQuanto`.
///
/// 💡 Il doppio controllo non è ridondante: Android può far partire il lavoro
/// molto dopo — o molto più spesso di quanto si creda, se il sistema raggruppa i
/// risvegli — e la regola «non più di una volta al giorno» deve stare **in un
/// posto solo**, quello che sa anche dell'apertura dell'app.
const _ogniQuanto = Duration(days: 1);

/// ══ 🚨 Il punto d'ingresso dell'isolato, e le sue due regole ══════════════
///
/// **`@pragma('vm:entry-point')` non è decorativo**: senza, la compilazione in
/// release lo butta via perché nessuno lo chiama da Dart — e il lavoro fallisce
/// **solo in produzione**, dove nessuno lo sta guardando.
///
/// ⚠️ **Deve essere una funzione di primo livello.** Un metodo, o una chiusura,
/// non hanno un indirizzo che il codice nativo possa richiamare.
@pragma('vm:entry-point')
void puntoDIngresso() {
  Workmanager().executeTask((compito, dati) async {
    /*
     * 🚨 **Qui non c'è nessuna app.** Non c'è una schermata, non c'è il
     * `ProviderContainer` che vive nel `main()`, non c'è niente: questo e' un
     * isolato nuovo, avviato da Android, con solo i plugin registrati.
     *
     * 💡 Quindi il contenitore si costruisce a mano, con gli stessi `override`
     * che mette `bootstrap()`. ⚠️ Se un domani `bootstrap()` ne aggiunge uno e
     * questa riga non lo segue, il lavoro fallira' **solo in background**.
     */
    final contenitore = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(AppConfig.fromEnvironment()),
        localCacheProvider.overrideWithValue(await LocalCache.open()),
      ],
    );

    try {
      final fatto = await contenitore.read(backupCheGiraDaSoloProvider).forse();

      debugPrint('[BACKUP-BG] $compito: ${fatto ? 'fatto' : 'non era ora'}');

      return true;
    } on Object catch (errore, stack) {
      debugPrintStack(label: '[BACKUP-BG] $errore', stackTrace: stack);

      /*
       * ⚠️ **Si torna `true` anche quando fallisce**, e non è pigrizia.
       *
       * 🚨 Un `false` dice ad Android di **riprovare con backoff**, e su un
       * errore che non passa da solo — Drive scollegato, permesso revocato —
       * vorrebbe dire un telefono che ritenta all'infinito consumando batteria.
       * 💡 Il prossimo giro arriva comunque fra un giorno, e nel frattempo c'è
       * l'apertura dell'app a coprire.
       */
      return true;
    } finally {
      contenitore.dispose();
    }
  });
}

/// Accende o spegne il lavoro periodico.
///
/// 🚨 **Si chiama quando l'interruttore del backup cambia**, non all'avvio: un
/// lavoro pianificato per chi ha il backup spento sarebbe un risveglio al giorno
/// per non fare niente.
class BackupInBackground {
  const BackupInBackground();

  Future<void> avvia() async {
    if (!_soloAndroid) return;

    await Workmanager().initialize(puntoDIngresso);
  }

  /// 🚨 I vincoli sono quelli scritti in `plan_backup.md` §N4.1, e ognuno ha una
  /// ragione:
  ///
  /// | Vincolo | Perché |
  /// |---|---|
  /// | `networkType: unmetered` | il backup con le foto pesa: sotto rete a consumo sarebbe un conto salato |
  /// | `requiresCharging` | cifrare e caricare costa batteria |
  /// | `requiresBatteryNotLow` | ⚠️ e comunque mai sotto il minimo, in carica o no |
  Future<void> pianifica() async {
    if (!_soloAndroid) return;

    await Workmanager().registerPeriodicTask(
      nomeDelLavoro,
      _compito,
      frequency: _ogniQuanto,
      constraints: Constraints(
        networkType: NetworkType.unmetered,
        requiresCharging: true,
        requiresBatteryNotLow: true,
      ),
      /*
       * ⚠️ `keep` e non `replace`: riaprire l'app non deve rimettere in coda un
       * lavoro che sta gia' aspettando. Con `replace`, chi apre l'app ogni
       * giorno azzererebbe il conto alla rovescia **ogni volta**, e il lavoro
       * non partirebbe mai.
       */
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }

  Future<void> ferma() async {
    if (!_soloAndroid) return;

    await Workmanager().cancelByUniqueName(nomeDelLavoro);
  }

  /// ⚠️ **Solo Android, per adesso.** Su iOS il meccanismo è diverso
  /// (`BGTaskScheduler`) e va dichiarato nell'`Info.plist`: sta in §6 del piano,
  /// insieme a tutto il resto di iOS. 💡 Chiamare queste funzioni su iOS non
  /// romperebbe niente, ma darebbe l'impressione che il lavoro sia pianificato.
  bool get _soloAndroid =>
      defaultTargetPlatform == TargetPlatform.android && !kIsWeb;
}
