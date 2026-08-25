/// L'immagine facoltativa di un esercizio — 3b-D.3.3, 25/08/2026.
///
/// 📌 *«Ogni esercizio deve avere un campo immagine facoltativo»*.
///
/// ══ 🚨 LA DOMANDA DEL BACKUP, FATTA PRIMA DI SCRIVERE IL RESTO ════════════
///
/// *«ogni volta che abbiamo un nuovo dato o un nuovo file o qualsiasi altra
/// cosa, questo deve comunque finire in qualche modo nel backup»*.
///
/// ✅ **Ci finisce**, e non per caso: la foto passa da [CanaleFoto] — il canale
/// unico — con `TipoFoto.esercizi`, che è `permanente: true, nelBackup: true`.
/// 💡 Da lì `RaccoltaFoto` la prende **da sola**, senza che questo file sappia
/// niente di Drive.
///
/// ⚠️ **Non è una cache come `alimenti`**: quelle immagini si riscaricano dal
/// server, questa se l'è fatta chi ha scritto la scheda — spesso è la foto della
/// macchina in *quella* palestra, con il sedile all'altezza giusta. Perderla
/// cambiando telefono vorrebbe dire non poterla rifare.
library;

import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/media/archivio_foto.dart';
import '../../../../core/media/canale_foto.dart';
import '../../../../core/media/tipo_foto.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/foto_locale.dart';
import '../../data/scheda_in_scrittura.dart';

class ImmagineDellEsercizio extends StatelessWidget {
  const ImmagineDellEsercizio({
    required this.esercizio,
    required this.onCambio,
    super.key,
  });

  static const _lato = 84.0;

  final EsercizioInScrittura esercizio;
  final VoidCallback onCambio;

  @override
  Widget build(BuildContext context) {
    final relativo = esercizio.immagine;

    return SizedBox(
      width: _lato,
      height: _lato,
      child: InkWell(
        onTap: () => _scegli(context),
        borderRadius: BorderRadius.circular(Gap.sm),
        child: relativo == null
            ? const _Vuota()
            : ClipRRect(
                borderRadius: BorderRadius.circular(Gap.sm),
                child: FutureBuilder<File>(
                  future: const ArchivioFoto().fileDi(relativo),
                  builder: (context, esito) {
                    final file = esito.data;

                    // ⚠️ Mentre il percorso si risolve non si mostra un giro:
                    // e' un'attesa di millisecondi, e un indicatore che
                    // lampeggia a ogni ricostruzione sembra un difetto.
                    if (file == null) return const _Vuota();

                    return FotoLocale(file: file, width: _lato, height: _lato);
                  },
                ),
              ),
      ),
    );
  }

  Future<void> _scegli(BuildContext context) async {
    /*
     * ══ 🚨 TRE ESITI, NON DUE ═════════════════════════════════════════════
     *
     * ⛔ Alla prima stesura «togli» tornava `null`, e chiudere il foglio
     * toccando fuori torna `null` anche lui: **chi cambiava idea si vedeva
     * cancellare la foto**. Nessun errore, e la si scopriva riaprendo.
     *
     * 💡 Adesso l'esito e' dichiarato: una foto scelta, la richiesta di
     * toglierla, oppure niente. Un `null` che vuol dire due cose diverse e'
     * sempre un difetto in attesa.
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
                  tipo: TipoFoto.esercizi,
                  titolo: "Foto dell'esercizio",
                );

                if (foglio.mounted) {
                  Navigator.of(foglio).pop(f == null ? null : _EsitoFoto(f));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Prendila dalla galleria'),
              onTap: () async {
                final f = await CanaleFoto.dallaGalleria(
                  foglio,
                  tipo: TipoFoto.esercizi,
                  titolo: "Foto dell'esercizio",
                );

                if (foglio.mounted) {
                  Navigator.of(foglio).pop(f == null ? null : _EsitoFoto(f));
                }
              },
            ),
            if (esercizio.immagine != null)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: const Text("Togli l'immagine"),
                /*
                 * ⚠️ **Si toglie il riferimento, non il file.** La stessa foto
                 * potrebbe essere su un altro esercizio, e cancellarla di qui
                 * lascerebbe l'altro con un quadrato rotto. 💡 Le foto senza
                 * padrone le raccoglie la potatura, che sa contarle.
                 */
                onTap: () => Navigator.of(foglio).pop(const _EsitoFoto(null)),
              ),
          ],
        ),
      ),
    );

    // Chiuso senza scegliere: non si tocca niente.
    if (esito == null) return;

    esercizio.immagine = esito.foto?.relativo;
    onCambio();
  }
}

/// Cosa ha deciso il foglio: una foto, oppure «toglila».
///
/// ⚠️ `null` **fuori** da questo tipo vuol dire «foglio chiuso»; `foto == null`
/// **dentro** vuol dire «togli». Due assenze diverse, e vanno tenute diverse.
class _EsitoFoto {
  const _EsitoFoto(this.foto);

  final FotoScelta? foto;
}

class _Vuota extends StatelessWidget {
  const _Vuota();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Gap.sm),
        border: Border.all(color: tema.dividerColor),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_a_photo_outlined,
            color: tema.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 2),
          Text('Foto', style: tema.textTheme.labelSmall),
        ],
      ),
    );
  }
}
