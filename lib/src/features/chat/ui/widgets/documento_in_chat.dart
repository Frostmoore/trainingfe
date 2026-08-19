import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';

import '../../../../core/crypto/cifratura_allegati.dart';
import '../../../../core/crypto/contenuto_messaggio.dart';
import '../../../../core/crypto/providers_crypto.dart';
import '../../../../core/media/archivio_foto.dart';
import '../../../../core/providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../chat_controller.dart';
import '../../data/allegato_di_chat.dart';

/// Un documento dentro la conversazione — N21.3.
///
/// ── 🚨 Non si disegna: si apre ─────────────────────────────────────────────
///
/// Una foto si mostra; un documento no. ⚠️ Un riquadro che provasse a
/// disegnare un PDF darebbe un rettangolo grigio, e chi lo guarda penserebbe
/// che l'allegato non è arrivato.
///
/// 💡 Quindi qui si mostra **cosa è** — nome e peso — e si apre col lettore del
/// telefono. Un visualizzatore PDF interno sarebbe una libreria grossa per un
/// problema che il sistema risolve già, e peggio: sarebbe una seconda cosa da
/// tenere aggiornata su un formato con una storia di vulnerabilità.
///
/// ── ⚠️ Si scarica solo quando lo si chiede ────────────────────────────────
///
/// A differenza delle foto, che si scaricano da sole per poterle mostrare, un
/// documento parte **solo al tocco**: può pesare dieci megabyte, e nessuno
/// vuole scoprire che aprire una chat gli ha consumato il piano dati.
class DocumentoInChat extends ConsumerStatefulWidget {
  const DocumentoInChat({
    required this.messaggio,
    required this.contenuto,
    required this.mio,
    super.key,
  });

  final ChatMessage messaggio;
  final ContenutoDocumento contenuto;
  final bool mio;

  @override
  ConsumerState<DocumentoInChat> createState() => _DocumentoInChatState();
}

class _DocumentoInChatState extends ConsumerState<DocumentoInChat> {
  bool _inCorso = false;
  String? _errore;

  Future<void> _apri() async {
    if (_inCorso) return;

    setState(() {
      _inCorso = true;
      _errore = null;
    });

    try {
      final relativo = await AllegatoDiChat(
        api: ref.read(apiClientProvider),
        cripto: CifraturaAllegati(await ref.read(sodiumProvider.future)),
      ).riprendiDocumento(widget.contenuto);

      if (!mounted) return;

      if (relativo == null) {
        /*
         * 💡 Non è un guasto: è scaduto dopo 24 ore, o l'ha già scaricato un
         * altro telefono. ⚠️ Mostrarlo come errore manderebbe qualcuno a
         * cercare un difetto che non c'è.
         */
        setState(() {
          _errore = 'Non è più disponibile: i documenti restano 24 ore.';
          _inCorso = false;
        });

        return;
      }

      final file = await const ArchivioFoto().fileDi(relativo);

      // 🚨 Si apre col lettore del telefono, non con uno nostro.
      await OpenFilex.open(file.path);

      if (mounted) setState(() => _inCorso = false);
    } on Object catch (e) {
      if (!mounted) return;

      setState(() {
        _errore = e.toString();
        _inCorso = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final peso = widget.contenuto.pesoLeggibile;

    return Align(
      alignment: widget.mio ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        margin: const EdgeInsets.symmetric(vertical: Gap.xs),
        child: Card(
          margin: EdgeInsets.zero,
          color: widget.mio
              ? tema.colorScheme.primaryContainer
              : tema.colorScheme.surfaceContainerHighest,
          child: InkWell(
            onTap: _inCorso ? null : _apri,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(Gap.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _inCorso
                          ? const SizedBox.square(
                              dimension: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.description_outlined, size: 28),
                      const SizedBox(width: Gap.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.contenuto.nome,
                              style: tema.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),

                            // 💡 Il peso **prima** di toccare: dieci megabyte su
                            // rete mobile sono una decisione, non un dettaglio.
                            if (peso != null)
                              Text(peso, style: tema.textTheme.labelSmall),
                          ],
                        ),
                      ),
                    ],
                  ),

                  if (_errore != null) ...[
                    const SizedBox(height: Gap.sm),
                    Text(
                      _errore!,
                      style: tema.textTheme.labelSmall?.copyWith(
                        color: tema.colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
