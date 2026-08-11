import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/media/photo_picker.dart';
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

/// La cartella dove vivono i file.
///
/// 🚨 **`Documents`, non la cache.** La cache il sistema la svuota quando ha
/// bisogno di spazio: le foto dei progressi sparirebbero da sole, e nessuno
/// capirebbe perché. È la stessa ragione per cui ci sta il database (S3.1).
Future<Directory> _cartellaFoto() async {
  final base = await getApplicationDocumentsDirectory();
  final dir = Directory(p.join(base.path, 'foto'));

  if (!dir.existsSync()) await dir.create(recursive: true);

  return dir;
}

/// Ricostruisce il percorso assoluto da quello relativo salvato a database.
///
/// ⚠️ **Su iOS il contenitore dell'app cambia percorso a ogni aggiornamento.**
/// Salvare l'assoluto avrebbe fatto svuotare la galleria da sola dopo il primo
/// aggiornamento dallo store, senza che nessuno avesse cancellato niente.
Future<File> _fileDi(String relativo) async =>
    File(p.join((await getApplicationDocumentsDirectory()).path, relativo));

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
  Future<bool> upload({required bool daFotocamera, int? workoutSessionId}) async {
    final scelta = daFotocamera
        ? await PhotoPicker.dallaFotocamera()
        : await PhotoPicker.dallaGalleria();

    if (scelta == null) return false;

    final cartella = await _cartellaFoto();
    final nome = '${DateTime.now().microsecondsSinceEpoch}${p.extension(scelta)}';
    final destinazione = File(p.join(cartella.path, nome));

    // ⚠️ `copy`, non `rename`: l'originale sta nella cartella temporanea di
    // `image_picker`, e su Android puo' essere su un volume diverso — dove
    // `rename` fallisce con un errore che non dice perche'.
    await File(scelta).copy(destinazione.path);

    await _ref.read(archivioSaluteProvider).registraFoto(
          FotoProgressiCompanion.insert(
            percorso: p.join('foto', nome),
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
    final cartella = await _cartellaFoto();

    if (cartella.existsSync()) await cartella.delete(recursive: true);

    _ref.read(revisioneFotoProvider.notifier).state++;
  }
}

final progressActionsProvider = Provider<ProgressActions>(ProgressActions.new);
