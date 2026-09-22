/// 🆕 La foto di un alimento tuo — A4 di `plan_blocco_A.md`, 22/09/2026.
///
/// 📌 Il committente, 22/09: *«foto su alimenti propri teniamola»*.
///
/// È il gemello di `ImmagineDellEsercizio`: stesso riquadro, stesso foglio con
/// «scatta», «dalla galleria» e «togli», stesso canale unico ([CanaleFoto]).
/// Cambia solo il tipo: [TipoFoto.alimentiMiei], che è permanente e nel backup.
///
/// ⚠️ Qui **non si salva niente nell'archivio**: si dice solo cosa ha scelto la
/// persona. Il legame nome → foto lo scrive il foglio di aggiunta **quando il
/// pasto si registra davvero** — una foto scelta e poi abbandonata chiudendo il
/// foglio non deve attaccarsi a nessun alimento.
library;

import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/media/archivio_foto.dart';
import '../../../../core/media/canale_foto.dart';
import '../../../../core/media/tipo_foto.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/foto_locale.dart';

class FotoDellAlimentoMio extends StatelessWidget {
  const FotoDellAlimentoMio({
    required this.relativo,
    required this.onCambio,
    super.key,
  });

  static const lato = 64.0;

  /// Il percorso relativo della foto scelta, o `null`.
  final String? relativo;

  /// Chiamato con il percorso nuovo, o con `null` se la persona l'ha tolta.
  /// ⚠️ **Non** chiamato se il foglio si chiude senza scegliere.
  final ValueChanged<String?> onCambio;

  @override
  Widget build(BuildContext context) {
    final foto = relativo;

    return Semantics(
      button: true,
      label: foto == null ? 'Aggiungi una foto' : 'Cambia la foto',
      child: SizedBox(
        width: lato,
        height: lato,
        child: InkWell(
          onTap: () => _scegli(context),
          borderRadius: BorderRadius.circular(Gap.sm),
          child: foto == null
              ? const _Vuota()
              : ClipRRect(
                  borderRadius: BorderRadius.circular(Gap.sm),
                  child: FutureBuilder<File>(
                    future: const ArchivioFoto().fileDi(foto),
                    builder: (context, esito) {
                      final file = esito.data;

                      if (file == null) return const _Vuota();

                      return FotoLocale(file: file, width: lato, height: lato);
                    },
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _scegli(BuildContext context) async {
    /*
     * 🚨 **Tre esiti, non due** — la stessa trappola già pagata con la foto
     * degli esercizi: chiudere il foglio toccando fuori torna `null`, e se
     * «togli» tornasse `null` anche lui, chi cambia idea si vedrebbe
     * cancellare la foto.
     */
    final esito = await showModalBottomSheet<_EsitoFoto>(
      context: context,
      showDragHandle: true,
      builder: (foglio) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('Scatta una foto'),
              onTap: () async {
                final f = await CanaleFoto.scatta(
                  foglio,
                  tipo: TipoFoto.alimentiMiei,
                  titolo: "Foto dell'alimento",
                );

                if (foglio.mounted) {
                  Navigator.of(
                    foglio,
                  ).pop(f == null ? null : _EsitoFoto(f.relativo));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Prendila dalla galleria'),
              onTap: () async {
                final f = await CanaleFoto.dallaGalleria(
                  foglio,
                  tipo: TipoFoto.alimentiMiei,
                  titolo: "Foto dell'alimento",
                );

                if (foglio.mounted) {
                  Navigator.of(
                    foglio,
                  ).pop(f == null ? null : _EsitoFoto(f.relativo));
                }
              },
            ),
            if (relativo != null)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: const Text('Togli la foto'),
                onTap: () => Navigator.of(foglio).pop(const _EsitoFoto(null)),
              ),
          ],
        ),
      ),
    );

    // Chiuso senza scegliere: non si tocca niente.
    if (esito == null) return;

    onCambio(esito.relativo);
  }
}

/// Cosa ha deciso il foglio: una foto, oppure «toglila» (`relativo == null`).
class _EsitoFoto {
  const _EsitoFoto(this.relativo);

  final String? relativo;
}

class _Vuota extends StatelessWidget {
  const _Vuota();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Gap.sm),
      ),
      child: Icon(
        Icons.add_a_photo_outlined,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
