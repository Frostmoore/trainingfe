import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/health/health_controller.dart';
import '../crypto/file_di_backup.dart';
import '../crypto/providers_crypto.dart';
import '../providers.dart';
import 'cloud_di_backup.dart';
import 'drive_di_backup.dart';

/// Il posto dove finisce la copia di sicurezza — N3.
///
/// 💡 Oggi è Drive; su iOS sarà iCloud. Chi lo usa non deve saperlo.
final cloudDiBackupProvider = Provider<CloudDiBackup?>((ref) {
  final config = ref.watch(appConfigProvider);

  // ⚠️ Senza ID client il backup su cloud **non si offre**, invece di offrirsi
  // e fallire: un interruttore che dà sempre errore fa sembrare rotta tutta
  // l'applicazione.
  if (!config.backupSuDriveDisponibile) return null;

  return DriveDiBackup(serverClientId: config.googleServerClientId);
});

/// Lo stato del backup automatico, come lo vede la schermata.
class StatoBackup {
  const StatoBackup({
    required this.acceso,
    required this.disponibile,
    this.ultimo,
    this.nomeDelCloud,
  });

  final bool acceso;

  /// Se il cloud è configurato: senza, l'interruttore non si mostra.
  final bool disponibile;

  /// 🚨 Quando è stato fatto l'ultimo. È **l'unica cosa che rende credibile**
  /// un backup automatico: senza una data, «è acceso» è una promessa che
  /// nessuno può verificare.
  final DateTime? ultimo;

  final String? nomeDelCloud;
}

/// Accende, spegne e fa il backup — N3.5, N3.6.
class BackupAutomatico extends AsyncNotifier<StatoBackup> {
  /// 💡 In `SharedPreferences` e non in `flutter_secure_storage`: è una
  /// preferenza, non un segreto. E le cassette cifrate sono escluse dal backup
  /// di sistema, quindi lì si perderebbe al cambio telefono.
  static const _chiaveAcceso = 'backup_automatico_acceso';

  @override
  Future<StatoBackup> build() async {
    final cloud = ref.watch(cloudDiBackupProvider);

    if (cloud == null) {
      return const StatoBackup(acceso: false, disponibile: false);
    }

    final prefs = await SharedPreferences.getInstance();
    final acceso = prefs.getBool(_chiaveAcceso) ?? false;

    return StatoBackup(
      acceso: acceso,
      disponibile: true,
      nomeDelCloud: cloud.nome,
      // ⚠️ La data si chiede al cloud solo se è acceso: interrogarlo da spento
      // vorrebbe dire chiedere un accesso a chi non l'ha concesso.
      ultimo: acceso ? await _quandoLUltimo(cloud) : null,
    );
  }

  Future<DateTime?> _quandoLUltimo(CloudDiBackup cloud) async {
    try {
      return await cloud.quandoLUltimo();
    } on Object {
      // 💡 Non sapere quando è stato l'ultimo non è un guasto da mostrare: la
      // schermata dirà «non lo so», che è la verità.
      return null;
    }
  }

  /// Accende il backup automatico e ne fa subito uno.
  ///
  /// 🚨 **Il primo backup si fa adesso, non domani.** ⚠️ Accendere un
  /// interruttore e non vedere succedere niente per ventiquattro ore è il modo
  /// per non sapere mai se funziona — e per scoprire che non funzionava proprio
  /// quando serviva.
  ///
  /// @return `false` se la persona ha rifiutato l'accesso.
  Future<bool> accendi() async {
    final cloud = ref.read(cloudDiBackupProvider);

    if (cloud == null) return false;

    if (!await cloud.collega()) return false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_chiaveAcceso, true);

    await adesso();
    ref.invalidateSelf();

    return true;
  }

  /// Spegne. [cancellaDalCloud] chiede anche di buttare quello che c'è già.
  ///
  /// 🚨 **Si chiede, non si decide.** ⚠️ Lasciare i file di qualcuno che ha
  /// appena detto «non voglio più» è la cosa sbagliata; cancellarli senza
  /// chiedere è peggio — quella copia potrebbe essere l'unica rimasta.
  Future<void> spegni({required bool cancellaDalCloud}) async {
    final cloud = ref.read(cloudDiBackupProvider);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_chiaveAcceso, false);

    if (cloud != null) {
      if (cancellaDalCloud) {
        try {
          await cloud.cancellaTutto();
        } on Object {
          // ⚠️ Se la cancellazione fallisce, lo spegnimento resta valido: chi
          // ha detto «basta» non deve restare acceso perché la rete non va.
        }
      }

      await cloud.scollega();
    }

    ref.invalidateSelf();
  }

  /// Fa un backup adesso, sul cloud.
  ///
  /// 🚨 **Avvolto con la chiave maestra**, non con la password.
  ///
  /// ⚠️ Un lavoro in background non ha nessuno a cui chiedere la password di
  /// recupero, e l'app non la conserva: un backup automatico che la pretende
  /// non e' automatico.
  ///
  /// 💡 **La catena regge lo stesso**, e passa da quello che esiste gia': su
  /// un telefono nuovo si digita la password, il server restituisce la chiave
  /// maestra (`ripristinaConPassword`), e con quella si apre questo file. Una
  /// porta in piu', non una scorciatoia.
  Future<void> adesso() async {
    final cloud = ref.read(cloudDiBackupProvider);

    if (cloud == null) {
      throw const CloudNonRaggiungibile('Nessun cloud configurato.');
    }

    final sodium = await ref.read(sodiumProvider.future);
    final maestra = await ref.read(portachiaviProvider).chiaveMaestra();

    if (maestra == null) {
      throw const CloudNonRaggiungibile(
        'Non c\'è ancora nessuna chiave da salvare: apri prima la chat.',
      );
    }

    final backup = FileDiBackup(sodium);

    final contenuto = await backup.esportaV2(
      chiaveMaestra: maestra,
      archivio: await ref.read(archivioSaluteProvider).esportaPerBackup(),
      /*
       * ⚠️ Un codice serve comunque: il formato ne pretende almeno uno, e
       * questo è la seconda porta sullo stesso file. 💡 Non si mostra a nessuno
       * — chi ripristina da qui usa la password — ma esiste, così il file resta
       * apribile anche se un giorno lo si scarica a mano.
       */
      codice: backup.generaCodice(),
      avvolgiConLaChiaveMaestra: true,
    );

    await cloud.carica(contenuto);

    ref.invalidateSelf();
  }
}

final backupAutomaticoProvider =
    AsyncNotifierProvider<BackupAutomatico, StatoBackup>(BackupAutomatico.new);
