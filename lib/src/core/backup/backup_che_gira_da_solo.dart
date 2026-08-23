import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backup_controller.dart';
import 'cloud_di_backup.dart';

/// Com'è andato un tentativo di backup automatico — difetto del 22/08/2026.
///
/// ══ 🚨 «NON ERA ORA» E «NON CE L'HA FATTA» NON SONO LA STESSA COSA ════════
///
/// ⚠️ `forse()` restituiva un `bool`, e chi lo stampava scriveva *«non era
/// ora»* per qualunque `false`. 🚨 Il committente ha tenuto il telefono in
/// carica tutta la notte apposta, e nel log ha trovato scritto che **non era
/// ora** — mentre la verità era *«Non sei collegato a Google Drive»*, due righe
/// sopra e in mezzo a uno stack.
///
/// ⛔ È la specie di difetto che fa perdere una giornata: il messaggio dice che
/// va tutto bene, e il backup non si fa da giorni.
///
/// 💡 Quattro esiti, quattro frasi diverse. E [fallito] è l'unico che merita di
/// comparire a schermo.
enum EsitoBackup {
  /// Il backup automatico è spento, o non c'è un posto dove metterlo.
  spento('backup automatico spento'),

  /// L'ultimo è recente: si riprova domani.
  nonEraOra('non era ora'),

  fatto('fatto'),

  /// 🚨 Ci ha provato e non ce l'ha fatta. La data finisce in
  /// `chiaveUltimoErrore`, e la schermata «Copia di sicurezza» la mostra.
  fallito('NON RIUSCITO — guarda le righe sopra'),

  /// ⛔ L'autorizzazione a Drive non c'è più: **si ferma e non riprova**.
  ///
  /// 🚨 È l'esito nato dal difetto del 24/08/2026: riprovare vorrebbe dire far
  /// comparire il foglio di Google a **ogni** apertura dell'app, perché per
  /// rifare l'autorizzazione serve la persona. 💡 Da qui in poi tace, e lo dice
  /// la schermata «Copia di sicurezza».
  daRicollegare('Google Drive va ricollegato: l\'automatico si ferma qui');

  const EsitoBackup(this.frase);

  final String frase;

  bool get eRiuscito => this == EsitoBackup.fatto;
}

/// Il backup che gira **da solo** — FASE 2.1 (`N4.1`), 20/08/2026.
///
/// ══ 🚨 IL DIFETTO CHE CHIUDE, ED È IL PIÙ GRAVE DEL PIANO ═══════════════════
///
/// Fino al 20/08 la copia di sicurezza girava **solo** quando la si lanciava a
/// mano o nel momento in cui si accendeva l'interruttore. Poi mai più.
///
/// ⚠️ Tutto il progetto è costruito su **«i dati stanno sul telefono»**
/// (decisione D9-bis), e quella scelta regge **solo se il backup funziona**. Chi
/// accende l'interruttore crede di essere coperto; se il telefono si rompe o si
/// cambia, perde diario, peso, misure, foto e allenamenti — e **non c'è nessun
/// server da cui recuperarli**.
///
/// 🚨 **È peggio di non avere il backup.** Chi non ce l'ha lo sa. Chi ce l'ha e
/// non funziona **crede di essere al sicuro**, e lo scopre nel momento peggiore.
///
/// ── 💡 Due meccanismi, e non è ridondanza ─────────────────────────────────
///
/// | | Copre | Affidabilità |
/// |---|---|---|
/// | **Questo file**: all'apertura dell'app | chi apre l'app | 🟢 certa |
/// | `WorkManager`: in background | chi **non** la apre per settimane | 🟡 da provare sul telefono |
///
/// ⚠️ Il secondo è quello che il piano chiedeva, ed è anche quello che può non
/// partire: un lavoro in background dipende dal produttore del telefono, dai
/// risparmi energetici e dall'autorizzazione a Drive **senza nessuna schermata
/// davanti**. 🚨 Il primo invece non può fallire per quelle ragioni, e da solo
/// copre la stragrande maggioranza delle persone: chi usa l'app la apre.
///
/// 💡 Farne uno solo sarebbe stato sbagliato in entrambi i versi: solo il
/// secondo lascia scoperto chi ha un telefono aggressivo con il background, solo
/// il primo lascia scoperto chi smette di aprire l'app — che è **precisamente**
/// la persona a cui il backup serve di più.
class BackupCheGiraDaSolo {
  BackupCheGiraDaSolo(this._ref, {DateTime Function()? adesso})
    : _adesso = adesso ?? DateTime.now;

  final Ref _ref;
  final DateTime Function() _adesso;

  /// Ogni quanto ha senso rifarlo.
  ///
  /// 💡 **Un giorno**, come chiede `plan_backup.md` §N4.1. ⚠️ Più spesso non
  /// serve — l'archivio pesa decine di kilobyte ma le foto no — e più di rado
  /// vorrebbe dire perdere una giornata di diario, che è la cosa che uno
  /// scrive ogni giorno e non ricostruisce.
  static const ogniQuanto = Duration(days: 1);

  /// 🚨 Si ricorda **quando è andato bene**, e sta nelle preferenze accanto
  /// all'interruttore.
  ///
  /// ⚠️ **Non si chiede al cloud.** `StatoBackup.ultimo` lo fa, e va benissimo
  /// per una schermata — ma qui vorrebbe dire una chiamata di rete a **ogni
  /// avvio dell'app** solo per decidere di non fare niente. 💡 E se la rete non
  /// c'è, la risposta è `null`, che qui verrebbe letta come «non l'ho mai
  /// fatto» — cioè rifarlo ogni volta.
  static const chiaveUltimo = 'backup_automatico_ultimo_riuscito';

  /// 🚨 L'automatico è **fermo** perché Drive va ricollegato — 24/08/2026.
  ///
  /// ══ ⛔ UNA VOLTA SOLA, POI SI TACE ═════════════════════════════════════
  ///
  /// ⚠️ `attemptLightweightAuthentication()` **può disegnare**, per contratto
  /// del plugin: quando l'autorizzazione non c'è più, chiederla di nuovo fa
  /// salire il foglio «Accesso» di Google. Senza questa chiave succederebbe a
  /// **ogni apertura dell'app**, per sempre.
  ///
  /// 💡 La scrive il primo tentativo che scopre il problema; la cancella
  /// `accendi()`, cioè il momento in cui la persona ricollega davvero. È
  /// l'unica cosa che può rimetterla a posto, ed è giusto che sia lei.
  static const chiaveDaRicollegare = 'backup_automatico_da_ricollegare';

  /// Quando l'ultimo tentativo è andato storto.
  ///
  /// 🚨 **Serve perché adesso il backup gira da solo.** Un fallimento alle tre
  /// di notte non lo vede nessuno, e senza questa data la schermata continuerebbe
  /// a mostrare l'ultimo riuscito — vero, e fuorviante.
  static const chiaveUltimoErrore = 'backup_automatico_ultimo_errore';

  /// Segna che un tentativo è andato storto.
  ///
  /// 🚨 **Statica e pubblica** perché la chiama anche il pulsante «Aggiorna
  /// adesso»: prima lo scriveva solo il backup automatico, e provando a mano si
  /// vedeva «Ultimo backup: oggi» **subito dopo un fallimento**. ⚠️ Un
  /// tentativo è un tentativo, che a farlo sia un cron o un dito.
  /// Scrive una preferenza booleana senza che un guasto qui rovini il resto.
  static Future<void> _segna(String chiave) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(chiave, true);
    } on Object {
      // 💡 Se non si riesce a scrivere una preferenza, il problema non è il
      // backup: si lascia perdere in silenzio.
    }
  }

  static Future<void> segnaFallito() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setInt(
        chiaveUltimoErrore,
        DateTime.now().millisecondsSinceEpoch,
      );
    } on Object {
      // 💡 Se non si riesce a scrivere una preferenza, il problema non e' il
      // backup: si lascia perdere in silenzio.
    }
  }

  /// Fa il backup **se è ora**. Torna `true` se l'ha fatto davvero.
  ///
  /// ── ⚠️ Perché non lancia mai ──────────────────────────────────────────────
  ///
  /// Perché lo chiama l'avvio dell'app, e un backup che fallisce **non è una
  /// buona ragione per non far partire l'app**. 💡 L'errore si scrive nel log e
  /// la schermata «Copia di sicurezza» continua a raccontare la verità: è lì che
  /// una persona va a guardare se le cose funzionano.
  Future<EsitoBackup> forse() async {
    try {
      /*
       * ══ 🚨 PRIMA SI DECIDE IN LOCALE, POI SI TOCCA IL CLOUD ══════════════
       *
       * Difetto del 24/08/2026, trovato guardando venti schermate dell'avvio.
       *
       * ⛔ Qui c'era `_ref.read(backupAutomaticoProvider.future)` **come prima
       * riga**, e quel provider per costruirsi chiede a Drive quand'è stato
       * l'ultimo backup. Cioè: per decidere *se fosse ora*, l'app parlava con
       * Google **a ogni apertura** — e `attemptLightweightAuthentication()`,
       * per contratto del plugin, **può disegnare**.
       *
       * 🚨 Il risultato a schermo: il foglio «Accesso» di Google che sale
       * **sopra la schermata di blocco**, ruba il fuoco al prompt dell'impronta
       * e lo fa fallire — *«Non è andata. Riprova»*. Il backup non solo era
       * brutto da vedere: **impediva di entrare nell'app**.
       *
       * 💡 Le tre domande che decidono si rispondono tutte dalle preferenze,
       * che sono sul telefono e non costano niente. Il cloud si tocca solo
       * quando si è già deciso di fare il backup davvero.
       */
      final prefs = await SharedPreferences.getInstance();

      // 🚨 Spento vuol dire spento: non si fa un backup a chi non l'ha chiesto.
      if (!(prefs.getBool(BackupAutomatico.chiaveAcceso) ?? false)) {
        return EsitoBackup.spento;
      }

      /*
       * ⛔ **Fermo perché Drive va ricollegato.** Riprovare significherebbe
       * rifare comparire il foglio di Google, e per rifare l'autorizzazione
       * serve comunque la persona: chiederlo da soli non la avvicina alla
       * soluzione, la infastidisce e basta.
       */
      if (prefs.getBool(chiaveDaRicollegare) ?? false) {
        return EsitoBackup.daRicollegare;
      }

      final quando = prefs.getInt(chiaveUltimo);

      if (quando != null) {
        final ultimo = DateTime.fromMillisecondsSinceEpoch(quando);

        if (_adesso().difference(ultimo) < ogniQuanto) {
          return EsitoBackup.nonEraOra;
        }
      }

      /*
       * ⚠️ **Che un cloud ci sia si chiede al contenitore, non al cloud.**
       *
       * ⛔ Qui c'era `backupAutomaticoProvider.future`, che per costruirsi
       * chiede a Drive **quand'è stato l'ultimo backup**. Non serviva a
       * decidere niente: serviva a sapere se un cloud esiste, che è una
       * domanda a cui `cloudDiBackupProvider` risponde da solo e senza rete.
       *
       * 🚨 È l'ultima delle tre chiamate a Google che l'apertura dell'app
       * faceva senza motivo.
       */
      if (_ref.read(cloudDiBackupProvider) == null) return EsitoBackup.spento;

      await _ref.read(backupAutomaticoProvider.notifier).adesso();

      /*
       * ⚠️ La data si scrive **dopo**, e solo se è andata bene.
       *
       * 🚨 Scrivendola prima, un backup fallito comprerebbe ventiquattro ore di
       * silenzio: si riproverebbe domani invece che alla prossima apertura. E
       * chi ha la rete che va e viene resterebbe scoperto proprio nei giorni in
       * cui non funziona niente.
       */
      await prefs.setInt(chiaveUltimo, _adesso().millisecondsSinceEpoch);

      /*
       * 💡 Un successo **cancella** l'errore invece di lasciarlo li'. La
       * schermata guarda quale delle due date e' piu' recente, quindi tenerlo
       * non farebbe danni — ma una preferenza che non serve piu' e' una cosa che
       * qualcuno un giorno legge senza sapere che e' scaduta.
       */
      await prefs.remove(chiaveUltimoErrore);

      return EsitoBackup.fatto;
    } on CloudNonRaggiungibile catch (errore, stack) {
      debugPrintStack(label: 'BackupCheGiraDaSolo: $errore', stackTrace: stack);

      /*
       * ⛔ **Se manca l'autorizzazione, l'automatico si ferma qui.**
       *
       * ⚠️ Non è la rete che va e viene: è un permesso che solo la persona può
       * ridare. 🚨 Riprovare alla prossima apertura vorrebbe dire rifare
       * comparire il foglio di Google **ogni volta**, che è esattamente il
       * difetto del 24/08/2026.
       */
      if (errore.serveRicollegare) {
        await _segna(chiaveDaRicollegare);
        await segnaFallito();

        return EsitoBackup.daRicollegare;
      }

      await segnaFallito();

      return EsitoBackup.fallito;
    } on Object catch (errore, stack) {
      debugPrintStack(label: 'BackupCheGiraDaSolo: $errore', stackTrace: stack);

      /*
       * 🚨 **Il fallimento si SCRIVE**, non si limita a non scrivere il
       * successo.
       *
       * ⚠️ Le due cose sembrano uguali e non lo sono: «non c'e' una data di
       * successo recente» puo' voler dire che non era ora di farlo. «C'e' una
       * data di errore» vuol dire che ci ha provato e non ce l'ha fatta, ed e'
       * l'unica delle due che merita di comparire a schermo.
       */
      try {
        final prefs = await SharedPreferences.getInstance();

        await prefs.setInt(
          chiaveUltimoErrore,
          _adesso().millisecondsSinceEpoch,
        );
      } on Object {
        // 💡 Se non si riesce nemmeno a scrivere una preferenza, il problema
        // non e' il backup: si lascia perdere in silenzio.
      }

      return EsitoBackup.fallito;
    }
  }
}

final backupCheGiraDaSoloProvider = Provider<BackupCheGiraDaSolo>(
  BackupCheGiraDaSolo.new,
);

/// Lo fa partire all'avvio, **una volta per vita dell'app**.
///
/// 🚨 **Non `autoDispose`**, per la stessa ragione di `avvioSaluteProvider`: se
/// lo fosse, ogni volta che l'ultima schermata interessata sparisce il provider
/// morirebbe e il controllo ripartirebbe al ritorno — cioè a ogni cambio di
/// scheda.
///
/// ⚠️ **Non aspetta niente e non blocca niente**: `unawaited` di proposito, come
/// la risincronizzazione di Health. Un backup può metterci secondi, e nessuna
/// schermata deve stare ferma ad aspettarlo.
final avvioBackupProvider = FutureProvider<void>((ref) async {
  unawaited(ref.read(backupCheGiraDaSoloProvider).forse());
});
