import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/media/archivio_foto.dart';
import '../../core/media/canale_foto.dart';
import '../../core/media/tipo_foto.dart';
import '../../core/storage/archivio_salute.dart';
import '../health/health_controller.dart';

/// Una foto dei progressi — C16, **sul telefono** da S5.3.
///
/// 🚨 **Non c'è più nessun `url`.** Le foto non stanno sul server (decisione
/// **D9-bis**): il campo che conta adesso è `file`, e si disegna con
/// `Image.file`, non con `CachedNetworkImage`.
class ProgressPhoto {
  const ProgressPhoto({
    required this.id,
    required this.file,
    required this.takenOn,
    this.workoutSessionId,
  });

  final int id;
  final File file;
  final DateTime takenOn;
  final int? workoutSessionId;

  bool get daAllenamento => workoutSessionId != null;
}

/// Ogni scrittura incrementa questo contatore e i provider si ricalcolano.
final revisioneFotoProvider = StateProvider<int>((ref) => 0);

/// Ricostruisce il percorso assoluto da quello relativo salvato a database.
///
/// 💡 Adesso lo sa fare `ArchivioFoto`, che conosce anche la differenza fra
/// documenti e cache: qui restava una seconda idea di dove stiano le foto, ed
/// erano due idee destinate a divergere.
Future<File> _fileDi(String relativo) async =>
    const ArchivioFoto().fileDi(relativo);

/// La galleria.
final progressPhotosProvider = FutureProvider.autoDispose<List<ProgressPhoto>>((ref) async {
  ref.watch(revisioneFotoProvider);

  final righe = await ref.watch(archivioSaluteProvider).galleria();

  return Future.wait(righe.map((r) async => ProgressPhoto(
        id: r.id,
        file: await _fileDi(r.percorso),
        takenOn: r.scattataIl,
        workoutSessionId: r.sessioneId,
      )));
});

/// Le foto di una sessione di allenamento.
final fotoSessioneProvider =
    FutureProvider.autoDispose.family<List<ProgressPhoto>, int>((ref, sessioneId) async {
  ref.watch(revisioneFotoProvider);

  final righe = await ref.watch(archivioSaluteProvider).fotoDellaSessione(sessioneId);

  return Future.wait(righe.map((r) async => ProgressPhoto(
        id: r.id,
        file: await _fileDi(r.percorso),
        takenOn: r.scattataIl,
        workoutSessionId: r.sessioneId,
      )));
});

class ProgressActions {
  ProgressActions(this._ref);

  final Ref _ref;

  /// Scatta o sceglie una foto e la mette **sul telefono**.
  ///
  /// 🚨 **Si comprime lo stesso, anche senza upload.** Prima serviva a non
  /// sprecare banda; adesso serve a non riempire il telefono: una foto da
  /// fotocamera moderna sono 8-12 MB, e venti foto di progressi non compresse
  /// sono un quarto di giga per una funzione che si guarda una volta al mese.
  ///
  /// ⚠️ Restituisce `false` se la persona **annulla**: non è un errore, e chi
  /// chiama non deve mostrarlo come tale. È il motivo per cui non basta un
  /// `Future<void>` — a fine allenamento la foto è facoltativa, e «ho cambiato
  /// idea» dev'essere distinguibile da «non è riuscita».
  /// ⚠️ Serve il [context] perche' la fotocamera e la scelta del quadrato sono
  /// **schermate nostre**, non finestre di sistema: vanno spinte su un
  /// `Navigator`, e quello sta nel contesto di chi chiama.
  Future<bool> upload({
    required BuildContext context,
    required bool daFotocamera,
    int? workoutSessionId,
  }) async {
    /*
     * 🚨 **Dal canale unico** — N11.4.
     *
     * Torna una foto gia' quadrata, gia' a 1080, gia' riposta nella cartella
     * giusta e senza EXIF. 💡 Qui dentro non resta niente che sappia di
     * fotocamere, di compressione o di dove stiano i file: era quella
     * conoscenza sparsa a far salvare le foto di progresso a 1600 px senza che
     * nessuno l'avesse deciso.
     */
    final scelta = daFotocamera
        ? await CanaleFoto.scatta(
            context,
            tipo: TipoFoto.progressi,
            titolo: 'La foto di oggi',
          )
        : await CanaleFoto.dallaGalleria(
            context,
            tipo: TipoFoto.progressi,
            titolo: 'Scegli il quadrato',
          );

    if (scelta == null) return false;

    await _ref.read(archivioSaluteProvider).registraFoto(
          FotoProgressiCompanion.insert(
            percorso: scelta.relativo,
            scattataIl: DateTime.now(),
            sessioneId: Value(workoutSessionId),
          ),
        );

    _ref.read(revisioneFotoProvider.notifier).state++;

    return true;
  }

  /// Cancella una foto, **file compreso**.
  ///
  /// 🚨 Prima la riga, poi il file — e il file anche se la riga non c'era.
  /// Cancellare solo la riga lascerebbe l'immagine sul disco senza più niente
  /// che ne ricordi l'esistenza: occupa spazio e contiene il corpo di una
  /// persona che ha chiesto di toglierla.
  Future<void> delete(int id) async {
    final archivio = _ref.read(archivioSaluteProvider);
    final riga = await archivio.foto(id);

    if (riga != null) {
      final file = await _fileDi(riga.percorso);

      if (file.existsSync()) await file.delete();
    }

    await archivio.dimenticaFoto(id);

    _ref.read(revisioneFotoProvider.notifier).state++;
  }

  /// Cancella tutte le foto e i loro file.
  ///
  /// Serve alla cancellazione dell'account e al logout (S9.3): il server non
  /// può cancellare ciò che non ha mai avuto.
  Future<void> cancellaTutto() async {
    /*
     * 🚨 **Tutti i tipi, non solo i progressi** — N11.4.
     *
     * Prima qui c'era una cartella sola, perche' ce n'era una sola. Adesso ce
     * ne sono cinque, e chi cancella l'account non intende «cancella le foto
     * dei progressi»: intende **tutto**.
     *
     * /!\ Lasciare indietro `foto/chat` vorrebbe dire tenere sul telefono le
     * foto scambiate con un trainer dopo che l'account non esiste piu' - la
     * cosa peggiore da dimenticare, fra tutte quelle che si possono
     * dimenticare qui.
     */
    for (final tipo in TipoFoto.values) {
      final cartella = await const ArchivioFoto().cartellaDi(tipo);

      if (cartella.existsSync()) await cartella.delete(recursive: true);
    }

    _ref.read(revisioneFotoProvider.notifier).state++;
  }
}

final progressActionsProvider = Provider<ProgressActions>(ProgressActions.new);
