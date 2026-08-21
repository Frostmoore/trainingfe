import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/crypto/cifratura_allegati.dart';
import '../../../../core/crypto/contenuto_messaggio.dart';
import '../../../../core/crypto/providers_crypto.dart';
import '../../../../core/media/archivio_foto.dart';
import '../../../../core/providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../chat_controller.dart';
import '../../data/allegato_di_chat.dart';

/// Una foto dentro la conversazione — N13.4.
///
/// ── 🚨 Si scarica una volta sola, e va scritta su disco subito ────────────
///
/// Il server cancella il blob **appena lo consegna**. Se la foto restasse solo
/// in memoria, riaprendo la conversazione domani non ci sarebbe più niente da
/// scaricare — e resterebbe un riquadro vuoto senza spiegazione.
///
/// 💡 Per questo `AllegatoDiChat.riprendi()` scrive in `Documents/foto/chat/`
/// e la seconda volta trova il file già lì.
///
/// ⚠️ **Una foto che non c'è più non è un guasto**: è scaduta dopo 24 ore, o
/// è stata scaricata da un altro telefono. Va detto, non fatto girare
/// all'infinito.
final _fotoDiChatProvider = FutureProvider.autoDispose
    .family<String?, ContenutoFoto>((ref, busta) async {
      return AllegatoDiChat(
        api: ref.watch(apiClientProvider),
        cripto: CifraturaAllegati(await ref.watch(sodiumProvider.future)),
      ).riprendi(busta);
    });

class FotoInChat extends ConsumerWidget {
  const FotoInChat({
    required this.messaggio,
    required this.contenuto,
    required this.mio,
    super.key,
  });

  final ChatMessage messaggio;
  final ContenutoFoto contenuto;
  final bool mio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);

    return Align(
      alignment: mio ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 260),
        margin: const EdgeInsets.symmetric(vertical: Gap.xs),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: mio
              ? tema.colorScheme.primaryContainer
              : tema.colorScheme.surfaceContainerHighest,
        ),
        clipBehavior: Clip.antiAlias,
        child: AspectRatio(
          aspectRatio: 1,
          child: ref
              .watch(_fotoDiChatProvider(contenuto))
              .when(
                loading: () => const Center(
                  child: SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                error: (_, _) => _Assente(
                  icona: Icons.error_outline,
                  testo: 'Non sono riuscito a scaricarla.',
                  riprova: () => ref.invalidate(_fotoDiChatProvider(contenuto)),
                ),
                data: (relativo) => relativo == null
                    /*
                     * 💡 Il messaggio più utile possibile: dice **perché** non
                     * c'è, così nessuno va a cercare un difetto. Le 24 ore sono
                     * una scelta, e va detta come tale.
                     */
                    ? const _Assente(
                        icona: Icons.hourglass_disabled_outlined,
                        testo:
                            'Questa foto non è più disponibile.\n'
                            'Le foto restano 24 ore.',
                      )
                    : _Aperta(relativo: relativo),
              ),
        ),
      ),
    );
  }
}

class _Aperta extends StatelessWidget {
  const _Aperta({required this.relativo});

  final String relativo;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File>(
      future: const ArchivioFoto().fileDi(relativo),
      builder: (context, esito) {
        final file = esito.data;

        if (file == null) return const SizedBox.shrink();

        return GestureDetector(
          onTap: () => _apri(context, file),
          child: Image.file(file, fit: BoxFit.cover),
        );
      },
    );
  }

  /// 💡 Lo stesso velo delle foto dei progressi: una foto aperta deve
  /// **sembrare** aperta, o chi la apre cerca il modo di chiudere una cosa che
  /// non sembra aperta.
  void _apri(BuildContext context, File file) => showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.82),
    builder: (dialogo) => Dialog(
      insetPadding: const EdgeInsets.all(Gap.md),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Stack(
        alignment: Alignment.topRight,
        children: [
          InteractiveViewer(child: Image.file(file, fit: BoxFit.contain)),
          IconButton(
            onPressed: () => Navigator.of(dialogo).pop(),
            icon: const Icon(Icons.close_rounded),
            color: Colors.white,
            tooltip: 'Chiudi',
          ),
        ],
      ),
    ),
  );
}

class _Assente extends StatelessWidget {
  const _Assente({required this.icona, required this.testo, this.riprova});

  final IconData icona;
  final String testo;
  final VoidCallback? riprova;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(Gap.md),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icona, color: tema.colorScheme.onSurfaceVariant),
          const SizedBox(height: Gap.sm),
          Text(
            testo,
            textAlign: TextAlign.center,
            style: tema.textTheme.bodySmall,
          ),
          if (riprova != null) ...[
            const SizedBox(height: Gap.sm),
            TextButton(onPressed: riprova, child: const Text('Riprova')),
          ],
        ],
      ),
    );
  }
}
