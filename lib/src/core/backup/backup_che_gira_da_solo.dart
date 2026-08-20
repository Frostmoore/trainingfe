import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backup_controller.dart';

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

  /// Quando l'ultimo tentativo è andato storto.
  ///
  /// 🚨 **Serve perché adesso il backup gira da solo.** Un fallimento alle tre
  /// di notte non lo vede nessuno, e senza questa data la schermata continuerebbe
  /// a mostrare l'ultimo riuscito — vero, e fuorviante.
  static const chiaveUltimoErrore = 'backup_automatico_ultimo_errore';

  /// Fa il backup **se è ora**. Torna `true` se l'ha fatto davvero.
  ///
  /// ── ⚠️ Perché non lancia mai ──────────────────────────────────────────────
  ///
  /// Perché lo chiama l'avvio dell'app, e un backup che fallisce **non è una
  /// buona ragione per non far partire l'app**. 💡 L'errore si scrive nel log e
  /// la schermata «Copia di sicurezza» continua a raccontare la verità: è lì che
  /// una persona va a guardare se le cose funzionano.
  Future<bool> forse() async {
    try {
      final stato = await _ref.read(backupAutomaticoProvider.future);

      // 🚨 Spento vuol dire spento: non si fa un backup a chi non l'ha chiesto.
      if (!stato.acceso || !stato.disponibile) return false;

      final prefs = await SharedPreferences.getInstance();
      final quando = prefs.getInt(chiaveUltimo);

      if (quando != null) {
        final ultimo = DateTime.fromMillisecondsSinceEpoch(quando);

        if (_adesso().difference(ultimo) < ogniQuanto) return false;
      }

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

      return true;
    } on Object catch (errore, stack) {
      debugPrintStack(
        label: 'BackupCheGiraDaSolo: $errore',
        stackTrace: stack,
      );

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

        await prefs.setInt(chiaveUltimoErrore, _adesso().millisecondsSinceEpoch);
      } on Object {
        // 💡 Se non si riesce nemmeno a scrivere una preferenza, il problema
        // non e' il backup: si lascia perdere in silenzio.
      }

      return false;
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
