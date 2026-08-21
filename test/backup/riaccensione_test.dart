import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:training_companion/src/core/backup/backup_controller.dart';
import 'package:training_companion/src/core/backup/cloud_di_backup.dart';

/// Il ripristino non deve poter distruggere ciò che sta ripristinando — N7.1.
///
/// ── 🚨 Il guasto che questi test tengono chiuso ────────────────────────────
///
/// `ripristinaDalCloudERiaccendi()` fa due cose: riprende l'archivio dal cloud
/// e riaccende il backup automatico. La seconda comporta un caricamento
/// **immediato**.
///
/// ⚠️ Se le due cose non fossero in quest'ordine — e se un ripristino fallito
/// non interrompesse la sequenza — riaccendere caricherebbe l'archivio **vuoto**
/// del telefono nuovo sopra la copia buona. Il gesto con cui si recuperano i
/// propri dati diventerebbe quello con cui si perdono, e nessun messaggio lo
/// direbbe: l'interruttore risulterebbe acceso e il backup «riuscito».
///
/// 💡 È il motivo per cui quella regola sta nel controller e non nella
/// schermata: dentro un widget non si sarebbe potuta provare.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // ⚠️ Portachiavi vuoto = nessuna chiave maestra, che è esattamente la
    // condizione di chi arriva alla porta delle chiavi su un telefono nuovo.
    FlutterSecureStorage.setMockInitialValues({});
  });

  ProviderContainer contenitore(CloudFinto cloud) {
    final c = ProviderContainer(
      overrides: [cloudDiBackupProvider.overrideWithValue(cloud)],
    );
    addTearDown(c.dispose);

    return c;
  }

  test(
    'senza chiave maestra il ripristino lancia e NON carica niente',
    () async {
      final cloud = CloudFinto();
      final c = contenitore(cloud);

      await c.read(backupAutomaticoProvider.future);

      await expectLater(
        c
            .read(backupAutomaticoProvider.notifier)
            .ripristinaDalCloudERiaccendi(),
        throwsA(isA<CloudNonRaggiungibile>()),
      );

      /*
     * 🚨 **Questa è l'asserzione che conta.** Un `carica()` qui vorrebbe dire
     * aver scritto sopra la copia buona con quella vuota di questo telefono.
     */
      expect(cloud.caricamenti, isEmpty, reason: 'ha sovrascritto il backup');
    },
  );

  test('un ripristino fallito lascia l\'interruttore spento', () async {
    final cloud = CloudFinto();
    final c = contenitore(cloud);

    await c.read(backupAutomaticoProvider.future);

    try {
      await c
          .read(backupAutomaticoProvider.notifier)
          .ripristinaDalCloudERiaccendi();
    } on Object {
      // atteso: senza chiave non si ripristina niente.
    }

    /*
     * ⚠️ Un interruttore acceso dopo un ripristino fallito è **peggio** che
     * spento: dice che i dati si stanno salvando quando non è vero, e chi lo
     * legge smette di preoccuparsene.
     */
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('backup_automatico_acceso'), isNot(true));
  });

  test('senza cloud configurato lo stato dice «non disponibile»', () async {
    final c = ProviderContainer(
      overrides: [cloudDiBackupProvider.overrideWithValue(null)],
    );
    addTearDown(c.dispose);

    final stato = await c.read(backupAutomaticoProvider.future);

    // 💡 È il segnale con cui schermata e porta delle chiavi decidono di **non
    // mostrare** l'interruttore, invece di mostrarlo e dare errore.
    expect(stato.disponibile, isFalse);
    expect(stato.acceso, isFalse);
  });

  test('cercaNelCloud torna la data quando una copia c\'è', () async {
    final quando = DateTime(2026, 8, 18);
    final cloud = CloudFinto(ultimo: quando);
    final c = contenitore(cloud);

    await c.read(backupAutomaticoProvider.future);

    expect(
      await c.read(backupAutomaticoProvider.notifier).cercaNelCloud(),
      quando,
    );
  });

  test('cercaNelCloud torna null se la persona rifiuta l\'accesso', () async {
    // 🚨 Rifiutare non è un errore: la porta delle chiavi deve poter dire
    // «non l'ho trovata» e lasciar proseguire con la sola password.
    final cloud = CloudFinto(
      ultimo: DateTime(2026, 8, 18),
      accettaIlCollegamento: false,
    );
    final c = contenitore(cloud);

    await c.read(backupAutomaticoProvider.future);

    expect(
      await c.read(backupAutomaticoProvider.notifier).cercaNelCloud(),
      isNull,
    );
  });
}

/// Un cloud che tiene il conto di cosa gli è stato chiesto.
class CloudFinto implements CloudDiBackup {
  CloudFinto({this.ultimo, this.accettaIlCollegamento = true});

  final DateTime? ultimo;
  final bool accettaIlCollegamento;

  /// 🚨 Ogni caricamento finisce qui: è la prova che serve per dire se il
  /// backup buono è stato toccato o no.
  final List<Uint8List> caricamenti = [];

  bool collegato = false;

  @override
  String get nome => 'Cloud finto';

  @override
  Future<bool> collega() async => collegato = accettaIlCollegamento;

  @override
  Future<void> scollega() async => collegato = false;

  @override
  Future<bool> eCollegato() async => collegato;

  @override
  Future<void> carica(Uint8List contenuto) async => caricamenti.add(contenuto);

  @override
  Future<Uint8List?> scarica() async => null;

  @override
  Future<DateTime?> quandoLUltimo() async => ultimo;

  @override
  Future<void> cancellaTutto() async {
    caricamenti.clear();
    allegati.clear();
  }

  // ── gli allegati: un cloud in memoria ──────────────────────────────────
  //
  // 💡 Tenerli in una mappa invece che simularne il protocollo rende i test
  // sulle foto veri esperimenti: si guarda **cosa c'è finito dentro**, che è
  // la sola domanda che conta.

  final Map<String, Uint8List> allegati = {};

  @override
  Future<void> caricaAllegato(String nome, Uint8List contenuto) async =>
      allegati[nome] = contenuto;

  @override
  Future<Uint8List?> scaricaAllegato(String nome) async => allegati[nome];

  @override
  Future<Set<String>> elencaAllegati() async => allegati.keys.toSet();

  @override
  Future<void> cancellaAllegato(String nome) async => allegati.remove(nome);
}
