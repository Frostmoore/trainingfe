import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/providers.dart';
import '../auth/auth_controller.dart';

/// La foto del profilo — M7.2, 18/08/2026.
///
/// ── 🚨 Perché questa foto sta sul server e quelle dei progressi no ─────────
///
/// Perché **serve a farsi riconoscere da qualcun altro**: un trainer deve vedere
/// la faccia di chi gli scrive. ⚠️ Le foto dei progressi sono l'opposto — si
/// guardano da soli — e restano sul telefono (S5.4).
///
/// 💡 La differenza in una riga: **questa la mostri, quelle le nascondi.**
final avatarProvider = Provider((ref) => _Avatar(ref));

class _Avatar {
  _Avatar(this._ref);

  final Ref _ref;

  /// Sceglie una foto e la manda.
  ///
  /// 🚨 **Si ridimensiona sul telefono, non sul server.**
  ///
  /// ⚠️ Una foto di una fotocamera moderna pesa 5-8 MB, cioè **oltre il limite
  /// del server** (4 MB): senza `maxWidth`, metà dei caricamenti fallirebbe con
  /// un `422` che parla di dimensioni e non di foto. E chi ha la connessione
  /// lenta caricherebbe otto megabyte per un cerchio da 32 pixel.
  ///
  /// 💡 512 px è abbondante: l'avatar più grande che l'app disegna è 96.
  Future<bool> scegliEManda({required ImageSource sorgente}) async {
    final scelta = await ImagePicker().pickImage(
      source: sorgente,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );

    if (scelta == null) return false;

    final form = FormData.fromMap({
      'avatar': await MultipartFile.fromFile(
        scelta.path,
        filename: scelta.name,
      ),
    });

    await _ref.read(apiClientProvider).post<dynamic>(
      '/account/avatar',
      body: form,
    );

    /*
     * 🚨 **Si ricarica l'utente, non si aggiorna una variabile.**
     *
     * ⚠️ L'indirizzo della foto nuova lo decide il server (il nome del file lo
     * genera lui). Scrivendocelo da soli si mostrerebbe un percorso inventato,
     * e l'immagine resterebbe quella vecchia finché non si riapre l'app.
     */
    await _ref.read(authControllerProvider.notifier).refresh();

    return true;
  }

  /// Toglie la foto: si torna alle iniziali.
  ///
  /// 🚨 Poter **togliere** un'immagine di sé non è una rifinitura: è la
  /// differenza fra un dato che si è scelto di dare e uno che non si può più
  /// ritirare.
  Future<void> togli() async {
    await _ref.read(apiClientProvider).delete('/account/avatar');
    await _ref.read(authControllerProvider.notifier).refresh();
  }
}
