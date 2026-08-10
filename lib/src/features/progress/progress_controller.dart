import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/media/photo_picker.dart';
import '../../core/providers.dart';

/// Una foto dei progressi — C16.
class ProgressPhoto {
  const ProgressPhoto({
    required this.id,
    required this.url,
    required this.type,
    this.takenOn,
    this.workoutSessionId,
  });

  factory ProgressPhoto.fromJson(Map<String, dynamic> j) => ProgressPhoto(
    id: (j['id'] as num).toInt(),
    url: j['url'].toString(),
    type: j['type']?.toString() ?? 'progress',
    takenOn: j['taken_on'] == null ? null : DateTime.tryParse(j['taken_on'].toString()),
    workoutSessionId: (j['workout_session_id'] as num?)?.toInt(),
  );

  final int id;
  final String url;

  /// `progress` o `workout`: la seconda è stata scattata a fine allenamento e
  /// resta legata a quella sessione (C5).
  final String type;

  final DateTime? takenOn;
  final int? workoutSessionId;

  bool get daAllenamento => type == 'workout';
}

/// La galleria.
///
/// ⚠️ L'endpoint restituisce **tutte** le foto in una volta: sono righe leggere
/// (id, url, data), non immagini. Il caricamento progressivo che serve davvero è
/// quello dei **file**, e lo fa `CachedNetworkImage` scaricandoli solo quando la
/// cella entra nello schermo. Paginare l'elenco complicherebbe il codice senza
/// risparmiare quasi niente.
final progressPhotosProvider = FutureProvider.autoDispose<List<ProgressPhoto>>((ref) async {
  final data = await ref.watch(apiClientProvider).get<List<dynamic>>('/photos');

  return data
      .map((e) => ProgressPhoto.fromJson((e as Map).cast<String, dynamic>()))
      .toList();
});

/// Le intestazioni con cui scaricare le immagini.
///
/// 🚨 **Le foto NON stanno su un URL pubblico**: l'endpoint controlla di chi
/// sono prima di consegnarle, e senza il token risponde 401. `CachedNetworkImage`
/// non passa dagli interceptor di `dio`, quindi l'intestazione va data a mano —
/// è l'unico punto dell'app in cui succede, e senza si vedrebbe una griglia di
/// riquadri rotti senza capire perché.
final progressAuthHeaderProvider = FutureProvider<Map<String, String>>((ref) async {
  final token = await ref.watch(tokenStoreProvider).read();

  return token == null ? const {} : {'Authorization': 'Bearer $token'};
});

class ProgressActions {
  ProgressActions(this._ref);

  final Ref _ref;

  /// Carica una foto scattata o scelta dalla galleria.
  ///
  /// 🚨 **Si comprime prima di caricare.** Una foto da fotocamera moderna sono
  /// 8-12 MB: su rete mobile l'upload fallisce o impiega mezzo minuto, e il
  /// server la ridimensiona comunque. Mandare l'originale è banda sprecata due
  /// volte.
  /// `workoutSessionId` lega la foto a quell'allenamento — C5.
  ///
  /// ⚠️ Restituisce `false` se la persona **annulla** la scelta della foto:
  /// non è un errore, e chi chiama non deve mostrarlo come tale. È il motivo
  /// per cui non basta un `Future<void>`: a fine allenamento la foto è
  /// facoltativa, e «ho cambiato idea» dev'essere distinguibile da «non è
  /// riuscito a caricarla».
  Future<bool> upload({required bool daFotocamera, int? workoutSessionId}) async {
    final percorso = daFotocamera
        ? await PhotoPicker.dallaFotocamera()
        : await PhotoPicker.dallaGalleria();

    if (percorso == null) return false;

    final form = FormData.fromMap({
      'photo': await MultipartFile.fromFile(percorso),
      'workout_session_id': ?workoutSessionId,
    });

    await _ref.read(apiClientProvider).upload<dynamic>('/photos', form);

    _ref.invalidate(progressPhotosProvider);

    return true;
  }

  Future<void> delete(int id) async {
    await _ref.read(apiClientProvider).delete('/photos/$id');

    _ref.invalidate(progressPhotosProvider);
  }
}

final progressActionsProvider = Provider<ProgressActions>(ProgressActions.new);
