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
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../config/app_config.dart';
import '../providers.dart';
import '../storage/local_cache.dart';
import 'backup_che_gira_da_solo.dart';
import 'backup_controller.dart';

/// Il nome con cui il lavoro è registrato presso Android.
///
/// ⚠️ **Uno solo, e stabile.** `ExistingPeriodicWorkPolicy.keep` fa sì che
/// riaprire l'app non ne accodi un altro: senza, ogni avvio ne lascerebbe uno in
/// più e il telefono farebbe backup a raffica.
const nomeDelLavoro = 'backup-notturno-ore-4';

/// 🆕 Il nome che il lavoro aveva prima delle 4 di notte — 21/08/2026.
///
/// ══ 🚨 PERCHÉ IL NOME È CAMBIATO, INVECE DI CAMBIARE SOLO L'ORARIO ════════
///
/// Perché `ExistingPeriodicWorkPolicy.keep` fa **esattamente il suo mestiere**:
/// se un lavoro con quel nome è già in coda, il nuovo viene **ignorato**. ⚠️ Un
/// orario nuovo scritto nel codice non sarebbe mai arrivato sui telefoni che il
/// lavoro ce l'hanno già — cioè su tutti quelli che contano.
///
/// 💡 Le alternative erano peggiori:
/// - `replace`/`update` a ogni avvio rimetterebbero in coda il lavoro **ogni
///   volta che si apre l'app**, e chi la apre tutti i giorni azzererebbe il
///   conto alla rovescia per sempre. È il difetto che `keep` esiste per evitare.
/// - Lasciare il nome e sperare: il lavoro vecchio sarebbe rimasto con il suo
///   orario, **senza dare nessun errore**.
///
/// 🚨 Un nome nuovo è una migrazione dichiarata: il vecchio si cancella una
/// volta, il nuovo nasce con l'orario giusto, e `keep` torna a fare il suo
/// lavoro dal giorno dopo.
const nomeVecchio = 'backup-automatico-giornaliero';

/// A che ora della notte, in ora locale.
///
/// 📌 Scelta dal committente il 21/08: *«mi metti l'orario in cui lo deve fare
/// alle 4 di mattina, così è attaccato sicuro»*.
///
/// 💡 Non è un dettaglio di comodità: il vincolo `requiresCharging` è quello che
/// decide davvero se il lavoro parte, e alle quattro di notte il telefono è in
/// carica. ⚠️ Con la finestra a un'ora qualunque del giorno, il lavoro aspettava
/// di trovare il telefono attaccato — e su un telefono che si carica solo la
/// notte quel momento poteva non arrivare mai.
const oraDelBackup = 4;

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

    /*
     * ══ 🚨 E si pianifica anche QUI, non solo su `accendi()` ══
     *
     * ⚠️ **Il difetto trovato sul telefono il 20/08**, e si vedeva solo
     * guardando due cose insieme: `backup_automatico_acceso = true` nelle
     * preferenze, e **nessun lavoro** in `dumpsys jobscheduler`.
     *
     * 🚨 `pianifica()` la chiamava solo `accendi()`, cioe' il **passaggio** da
     * spento ad acceso. Chi l'interruttore l'aveva acceso ieri — o un mese fa —
     * non lo ripassa mai, e il lavoro non veniva registrato **per nessuno degli
     * utenti gia' esistenti**.
     *
     * 💡 E' la trappola del default: una funzione che si attiva su una
     * transizione, applicata a una popolazione che quella transizione l'ha gia'
     * fatta. Il sintomo e' «funziona sui telefoni nuovi», cioe' sui nostri.
     *
     * ⚠️ Ripeterlo a ogni avvio non accoda niente di doppio:
     * `ExistingPeriodicWorkPolicy.keep` lascia stare quello che c'e' gia'.
     */
    final prefs = await SharedPreferences.getInstance();

    if (prefs.getBool(BackupAutomatico.chiaveAcceso) ?? false) {
      await pianifica();
    }
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

    /*
     * 🚨 **Il lavoro vecchio se ne va prima**, o resterebbe in coda con il suo
     * orario accanto a quello nuovo: due risvegli al giorno per fare una cosa
     * sola. ⚠️ È idempotente — cancellare un nome che non esiste non fa niente —
     * quindi può restare qui per sempre senza costare nulla.
     */
    await Workmanager().cancelByUniqueName(nomeVecchio);

    await Workmanager().registerPeriodicTask(
      nomeDelLavoro,
      _compito,
      frequency: _ogniQuanto,

      /*
       * 🆕 **Alle 4 di notte** — 21/08/2026.
       *
       * ⚠️ `initialDelay` sposta **solo la prima esecuzione**; da lì in poi
       * Android ripete ogni `frequency`. 💡 È il modo con cui si dà un orario a
       * un lavoro periodico: `WorkManager` non ha un «alle 4», ha «fra tot».
       *
       * 🚨 E l'orario non è una garanzia: Android può far partire il lavoro
       * **molto dopo**, e il vincolo `requiresCharging` lo tiene fermo finché il
       * telefono non è attaccato. Chi decide se è davvero ora resta
       * `BackupCheGiraDaSolo.forse()`, che è l'unico posto che sa anche delle
       * aperture dell'app.
       */
      initialDelay: quantoMancaAlleQuattro(),
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

/// Quanto manca alla prossima [oraDelBackup], in ora locale.
///
/// 💡 Sta fuori dalla classe ed è pura apposta: è l'unico pezzo di questa
/// storia che si può provare in un test, e sarebbe un peccato lasciarlo dentro
/// un metodo che chiama Android.
///
/// ⚠️ Se sono **già passate** le quattro, si punta a domani: un ritardo negativo
/// farebbe partire il lavoro subito, cioè con il telefono probabilmente non in
/// carica — e da lì in poi l'orario resterebbe sbagliato per sempre, perché il
/// periodico si ancora alla prima esecuzione.
@visibleForTesting
Duration quantoMancaAlleQuattro([DateTime? adesso]) {
  final ora = adesso ?? DateTime.now();

  var bersaglio = DateTime(ora.year, ora.month, ora.day, oraDelBackup);

  if (!bersaglio.isAfter(ora)) {
    bersaglio = bersaglio.add(const Duration(days: 1));
  }

  return bersaglio.difference(ora);
}
