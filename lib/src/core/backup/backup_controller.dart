import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/health/health_controller.dart';
import '../crypto/file_di_backup.dart';
import '../crypto/providers_crypto.dart';
import '../providers.dart';
import 'cloud_di_backup.dart';
import 'drive_di_backup.dart';
import 'raccolta_foto.dart';
import 'sincronizza_foto.dart';

/// L'inventario delle foto che vanno nel backup — N5.1, N12.1.
///
/// 💡 Non prende piu' una cartella: le sa da sola, chiedendole a
/// `TipoFoto.daSalvare`. ⚠️ Prima qui c'era `Documents/foto` scritta a mano,
/// cioe' una **seconda idea** di dove stiano le foto accanto a quella di
/// `ArchivioFoto` — e due idee sulla stessa cosa divergono.
final raccoltaFotoProvider = Provider<RaccoltaFoto>(
  (ref) => const RaccoltaFoto(),
);

/// Quanto pesano le foto, per poterlo scrivere accanto alla spunta — N5.1.
///
/// 💡 Provider separato dallo stato del backup, e non un campo dentro
/// `StatoBackup`: contare i byte vuol dire leggere la cartella, e farlo a ogni
/// ricalcolo dello stato metterebbe un giro di disco su ogni apertura della
/// schermata.
final pesoDelleFotoProvider = FutureProvider<int>(
  (ref) async => ref.watch(raccoltaFotoProvider).byteTotali(),
);

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
    this.fotoIncluse = false,
    this.ultimo,
    this.nomeDelCloud,
  });

  final bool acceso;

  /// Se il cloud è configurato: senza, l'interruttore non si mostra.
  final bool disponibile;

  /// Se anche le foto vanno nel cloud — N5.1.
  ///
  /// 🚨 **Spenta di serie**, e separata dall'interruttore principale: sono due
  /// decisioni di peso diverso. L'archivio sono decine di kilobyte; le foto
  /// possono essere centinaia di megabyte dello spazio Drive di qualcuno, e
  /// nessuno deve trovarcele senza averlo chiesto.
  final bool fotoIncluse;

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

  /// 🚨 Chiave separata da [_chiaveAcceso], e **il difetto è nel default**: se
  /// mancasse questa preferenza il valore è `false`. ⚠️ Un default `true`
  /// avrebbe caricato le foto di chi aveva acceso il backup **prima** che
  /// questa scelta esistesse, senza che nessuno gliel'avesse chiesto.
  static const _chiaveFoto = 'backup_automatico_foto';

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
      fotoIncluse: prefs.getBool(_chiaveFoto) ?? false,
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

    /*
     * 🚨 **Le foto DOPO l'archivio, e senza poter far fallire l'archivio** —
     * N5.
     *
     * L'archivio contiene la chiave maestra e tutta la storia di salute: è la
     * parte che non si ricostruisce. Le foto sono grandi, lente, e la loro
     * carica può inciampare in mille modi — rete che cade a metà, spazio su
     * Drive finito, un file cancellato mentre lo si legge.
     *
     * ⚠️ Legarle allo stesso destino vorrebbe dire che un Drive pieno di foto
     * impedisce il salvataggio dei dati che pesano venti kilobyte. Al contrario
     * si perde una foto e si tiene tutto il resto, che è il baratto giusto.
     */
    if (await _leFotoSonoIncluse()) {
      try {
        await (await _sincronizzatore(cloud, maestra)).caricaLeNuove();
      } on Object {
        // 💡 Silenzioso di proposito: l'archivio è già al sicuro, e un errore
        // rosso su un backup in gran parte riuscito insegnerebbe a ignorarli.
      }
    }

    ref.invalidateSelf();
  }

  /// Accende o spegne le foto nel backup — N5.1.
  ///
  /// 💡 Accendendola non si carica niente subito: lo farà il prossimo backup.
  /// ⚠️ Partire con centinaia di megabyte nell'istante in cui si tocca una
  /// spunta è il modo per far pentire chi l'ha toccata — di solito su rete
  /// mobile, e senza averlo chiesto.
  Future<void> cambiaLeFoto({required bool incluse}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_chiaveFoto, incluse);

    ref.invalidateSelf();
  }

  Future<bool> _leFotoSonoIncluse() async =>
      (await SharedPreferences.getInstance()).getBool(_chiaveFoto) ?? false;

  Future<SincronizzaFoto> _sincronizzatore(
    CloudDiBackup cloud,
    Uint8List maestra,
  ) async =>
      SincronizzaFoto(
        cloud: cloud,
        backup: FileDiBackup(await ref.read(sodiumProvider.future)),
        raccolta: ref.read(raccoltaFotoProvider),
        chiaveMaestra: maestra,
      );

  /// Riprende l'archivio dal cloud **e riaccende il backup automatico** — N7.1.
  ///
  /// ── 🚨 Perché le due cose stanno in un metodo solo ────────────────────────
  ///
  /// L'interruttore vive in `SharedPreferences`, cioè **su quel telefono**: chi
  /// ne cambia uno arriva col backup spento anche se sul vecchio lo teneva
  /// acceso. ⚠️ Lasciarlo così vuol dire ripristinare oggi e scoprire al
  /// telefono **successivo** che da mesi non si salvava più niente — lo stesso
  /// guasto che questa parte esiste per evitare, ricomparso un giro dopo.
  ///
  /// ── 🚨 L'ordine è una misura di sicurezza, non un dettaglio ───────────────
  ///
  /// [accendi] fa **subito** un backup. Chiamarlo dopo un ripristino fallito
  /// caricherebbe l'archivio vuoto di questo telefono **sopra la copia buona**:
  /// il gesto con cui si recuperano i propri dati diventerebbe quello con cui
  /// si perdono. Per questo il ripristino non è in un `try`: se lancia, si esce
  /// di qui prima di toccare qualunque cosa.
  ///
  /// 💡 Sta nel controller e non nella schermata proprio per poterlo provare:
  /// `test/backup/riaccensione_test.dart`.
  ///
  /// @return quanti dati sono tornati.
  Future<int> ripristinaDalCloudERiaccendi() async {
    final quante = await ripristinaDalCloud();

    try {
      await accendi();
    } on Object {
      // 💡 Non essere riusciti a riaccenderlo non è un guasto da raccontare a
      // chi ha appena riavuto i suoi dati: l'interruttore resta lì nel profilo.
      // Farne un errore vorrebbe dire un messaggio rosso su un'operazione
      // riuscita.
    }

    return quante;
  }

  /// C'è un backup nel cloud da cui si può ripristinare? — N4.2.
  ///
  /// 💡 Non richiede che l'interruttore sia acceso: su un telefono nuovo è
  /// spento per definizione, e chi arriva qui vuole proprio **riprendere**
  /// quello che c'era prima.
  Future<DateTime?> cercaNelCloud() async {
    final cloud = ref.read(cloudDiBackupProvider);

    if (cloud == null) return null;

    if (!await cloud.eCollegato()) {
      if (!await cloud.collega()) return null;
    }

    return cloud.quandoLUltimo();
  }

  /// Riprende l'archivio dal backup nel cloud — N4.2.
  ///
  /// ── 🚨 Va DOPO il recupero della chiave, e non è un ordine arbitrario ───
  ///
  /// Il file è avvolto con la **chiave maestra**: per aprirlo bisogna già
  /// averla. Su un telefono nuovo si arriva qui così:
  ///
  /// 1. si digita la password di recupero → il server restituisce la chiave;
  /// 2. con quella si scarica da Drive e si riapre l'archivio.
  ///
  /// ⚠️ Chiamarlo prima del passo 1 fallisce, ed è giusto che fallisca: senza
  /// chiave non c'è niente da fare con quei byte.
  ///
  /// ── ⚠️ SOVRASCRIVE l'archivio locale ────────────────────────────────────
  ///
  /// Chi chiama **deve** aver chiesto conferma. Su un telefono appena
  /// installato non c'è niente da perdere, ma su uno in uso si butterebbe via
  /// quello che c'è — ed è esattamente ciò che qualcuno farebbe premendo per
  /// curiosità.
  ///
  /// @return quanti dati sono tornati, per poterlo dire.
  Future<int> ripristinaDalCloud() async {
    final cloud = ref.read(cloudDiBackupProvider);

    if (cloud == null) {
      throw const CloudNonRaggiungibile('Nessun cloud configurato.');
    }

    final maestra = await ref.read(portachiaviProvider).chiaveMaestra();

    if (maestra == null) {
      /*
       * 🚨 Il messaggio dice **cosa fare**, non solo cosa manca.
       *
       * ⚠️ Chi legge questo sta ripristinando un telefono nuovo ed è già in
       * difficoltà: «chiave assente» lo lascerebbe fermo senza sapere che il
       * passo precedente esiste.
       */
      throw const CloudNonRaggiungibile(
        'Prima devi recuperare il tuo account con la password di recupero: '
        'la copia nel cloud si apre con quella chiave.',
      );
    }

    final byte = await cloud.scarica();

    if (byte == null) {
      throw const CloudNonRaggiungibile(
        'Non c\'è nessuna copia di sicurezza in questo account.',
      );
    }

    final sodium = await ref.read(sodiumProvider.future);

    final contenuto = await FileDiBackup(sodium).importaConChiaveMaestra(
      file: byte,
      chiaveMaestra: maestra,
    );

    if (contenuto.archivio.isNotEmpty) {
      await ref
          .read(archivioSaluteProvider)
          .ripristinaDaBackup(contenuto.archivio);
    }

    /*
     * 🚨 **Le foto si riprendono SEMPRE, anche a spunta spenta** — N5.
     *
     * ⚠️ La spunta decide se **caricarle**, non se riaverle. Chi l'aveva accesa
     * sul telefono vecchio arriva sul nuovo con la preferenza a zero — vive
     * nelle preferenze locali, non nel backup — e legare il ripristino a quel
     * valore vorrebbe dire lasciare nel cloud foto che qualcuno ci ha messo
     * apposta, senza nemmeno dirglielo.
     *
     * 💡 Non fallisce il ripristino: l'archivio è già a posto, e le foto si
     * riprendono al giro dopo.
     */
    var foto = 0;

    try {
      foto = await (await _sincronizzatore(cloud, maestra)).riprendiLeMancanti();
    } on Object {
      // Le foto sono l'unica cosa che il committente ha detto di poter perdere.
    }

    /*
     * 🚨 **Le schermate vanno svegliate**, o il ripristino sembra non aver
     * fatto niente.
     *
     * ⚠️ I dati sono nel database ma i provider tengono in memoria quello che
     * avevano letto prima: peso e misure resterebbero vuoti fino al riavvio
     * dell'app, e chi ha appena ripristinato concluderebbe che non ha
     * funzionato.
     */
    ref
      ..invalidate(archivioSaluteProvider)
      ..invalidateSelf();

    final righe = contenuto.archivio.values
        .whereType<List<dynamic>>()
        .fold<int>(0, (somma, r) => somma + r.length);

    return righe + foto;
  }
}

final backupAutomaticoProvider =
    AsyncNotifierProvider<BackupAutomatico, StatoBackup>(BackupAutomatico.new);
