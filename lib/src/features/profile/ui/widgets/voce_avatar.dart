import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/api/api_client.dart';
import '../../../auth/auth_controller.dart';
import '../../avatar_controller.dart';

/// La riga «la tua foto» nel profilo — M7.2, 18/08/2026.
class VoceAvatar extends ConsumerStatefulWidget {
  const VoceAvatar({super.key});

  @override
  ConsumerState<VoceAvatar> createState() => _VoceAvatarState();
}

class _VoceAvatarState extends ConsumerState<VoceAvatar> {
  bool _inCorso = false;

  @override
  Widget build(BuildContext context) {
    final utente = ref.watch(authControllerProvider).user;
    final tema = Theme.of(context);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: tema.colorScheme.primaryContainer,
        foregroundImage: utente?.avatarUrl != null
            ? NetworkImage(utente!.avatarUrl!)
            : null,
        child: Text(utente?.initials ?? '?'),
      ),
      title: const Text('La tua foto'),
      subtitle: Text(
        utente?.avatarUrl == null
            // 💡 Dice **a cosa serve**, non «nessuna foto»: chi legge deve
            // capire cosa ci guadagna a metterla.
            ? 'Ti fa riconoscere da chi ti scrive'
            : 'Tocca per cambiarla o toglierla',
      ),
      trailing: _inCorso
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.chevron_right_rounded),
      onTap: _inCorso ? null : _scegli,
    );
  }

  Future<void> _scegli() async {
    final utente = ref.read(authControllerProvider).user;

    final azione = await showModalBottomSheet<String>(
      context: context,
      builder: (foglio) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Scatta una foto'),
              onTap: () => Navigator.of(foglio).pop('fotocamera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Scegli dalla galleria'),
              onTap: () => Navigator.of(foglio).pop('galleria'),
            ),

            /*
             * 🚨 «Togli» c'è **solo se c'è una foto**.
             *
             * ⚠️ Mostrarlo sempre vorrebbe dire offrire di cancellare qualcosa
             * che non esiste: un'azione che non fa niente insegna a non fidarsi
             * delle altre.
             */
            if (utente?.avatarUrl != null) ...[
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: const Text('Togli la foto'),
                onTap: () => Navigator.of(foglio).pop('togli'),
              ),
            ],
          ],
        ),
      ),
    );

    if (azione == null || !mounted) return;

    setState(() => _inCorso = true);
    final messaggeria = ScaffoldMessenger.of(context);

    try {
      if (azione == 'togli') {
        await ref.read(avatarProvider).togli();
      } else {
        await ref
            .read(avatarProvider)
            .scegliEManda(
              sorgente: azione == 'fotocamera'
                  ? ImageSource.camera
                  : ImageSource.gallery,
            );
      }
    } on Object catch (errore) {
      messaggeria.showSnackBar(
        SnackBar(content: Text(ApiClient.unwrapError(errore).message)),
      );
    } finally {
      // ⚠️ `mounted` prima di `setState`: chi esce dal profilo mentre la foto
      // sale lascerebbe questo widget fuori dall'albero.
      if (mounted) setState(() => _inCorso = false);
    }
  }
}
