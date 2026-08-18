import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/crypto/file_di_backup.dart';
import '../../../core/crypto/providers_crypto.dart';
import '../../health/health_controller.dart';

/// L'esportazione del file di backup — M7.3, 18/08/2026.
///
/// ── 🚨 A quale guasto risponde ─────────────────────────────────────────────
///
/// Fino a oggi l'app sapeva **importare** un file di backup e non crearne
/// nessuno: si poteva ripristinare da un file che non si poteva fare. ⚠️ Era il
/// buco più silenzioso di tutto l'impianto delle chiavi, perché si scopre solo
/// nel momento in cui serve — cioè quando è troppo tardi.
///
/// ── ⚠️ Cosa c'è dentro, e cosa no ──────────────────────────────────────────
///
/// Dentro c'è **la chiave maestra**, che è la cosa irrecuperabile: senza,
/// nessuno — nemmeno noi — può più leggere i messaggi ricevuti. 📌 L'archivio
/// locale (peso, sonno, allenamenti) **non** ci è ancora dentro: lo copre il
/// backup di sistema, ed è debito dichiarato nel piano.
///
/// 🚨 **Il file vale quanto l'account.** Chi ce l'ha, insieme al codice, entra.
/// Va detto nella schermata, non nascosto in una nota.
class SchermataBackup extends ConsumerStatefulWidget {
  const SchermataBackup({super.key});

  @override
  ConsumerState<SchermataBackup> createState() => _SchermataBackupState();
}

class _SchermataBackupState extends ConsumerState<SchermataBackup> {
  bool _inCorso = false;
  String? _codice;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Copia di sicurezza')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('A cosa serve', style: tema.textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text(
            'I tuoi messaggi sono cifrati con una chiave che sta solo sul tuo '
            'telefono. Se perdi il telefono e hai dimenticato la password di '
            'recupero, questo file è l\'unico modo per rientrare.',
          ),
          const SizedBox(height: 20),

          Text('Cosa c\'è dentro', style: tema.textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text('· La chiave per leggere i tuoi messaggi.'),
          const SizedBox(height: 4),
          const Text(
            '· Peso, misure, sonno e recupero: tutto quello che vive solo sul '
            'tuo telefono.',
          ),
          const SizedBox(height: 4),
          /*
           * 🚨 **Si dice anche cosa NON c'è.**
           *
           * ⚠️ Un backup che qualcuno crede completo è peggio di nessun backup:
           * si perde il telefono tranquilli, e si scopre dopo.
           */
          /*
           * 🚨 Si dice anche cosa NON c'è.
           *
           * ⚠️ Un backup che qualcuno crede completo è peggio di nessun backup:
           * si perde il telefono tranquilli, e si scopre dopo.
           */
          const Text(
            '· Non ci sono le foto dei progressi: quelle le copia il backup del '
            'telefono.',
          ),
          const SizedBox(height: 20),

          Card(
            color: tema.colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: tema.colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Questo file vale quanto il tuo account. Chi lo ha, '
                      'insieme al codice, può leggere i tuoi messaggi.',
                      style: TextStyle(color: tema.colorScheme.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          if (_codice != null) ...[
            /*
             * 🚨 **Il codice si mostra UNA VOLTA SOLA**, e non si può
             * ritrovare: non lo conserviamo da nessuna parte.
             *
             * ⚠️ È il motivo per cui non è una password scelta dalla persona:
             * una password si **ricorda** — e si dimentica, ed è il guasto da
             * cui stiamo scappando. Un codice si **conserva** insieme al file.
             */
            Text('Il tuo codice di ripristino', style: tema.textTheme.titleMedium),
            const SizedBox(height: 8),
            SelectableText(
              _codice!,
              style: tema.textTheme.headlineSmall?.copyWith(
                fontFamily: 'monospace',
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Conservalo insieme al file: senza, il file non si apre. '
              'Non possiamo recuperarlo — non lo conosciamo.',
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _codice!));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Codice copiato')),
                );
              },
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copia il codice'),
            ),
            const SizedBox(height: 24),
          ],

          FilledButton.icon(
            onPressed: _inCorso ? null : _esporta,
            icon: _inCorso
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share_rounded),
            label: Text(_codice == null ? 'Crea il file' : 'Crea un file nuovo'),
          ),
        ],
      ),
    );
  }

  Future<void> _esporta() async {
    setState(() => _inCorso = true);
    final messaggeria = ScaffoldMessenger.of(context);

    try {
      final sodium = await ref.read(sodiumProvider.future);
      final maestra = await ref.read(portachiaviProvider).chiaveMaestra();

      if (maestra == null) {
        messaggeria.showSnackBar(
          const SnackBar(
            content: Text(
              'Non c\'è ancora nessuna chiave: apri prima la chat.',
            ),
          ),
        );

        return;
      }

      final backup = FileDiBackup(sodium);
      final codice = backup.generaCodice();

      /*
       * 🚨 **L'archivio ci va dentro davvero** — N2.1.
       *
       * ⚠️ Fino alla `v6.24.0` qui c'era `archivio: const {}`: il file
       * conteneva solo la chiave, e la schermata sembrava funzionare
       * benissimo. Un backup si prova riaprendo quello che c'era, non
       * guardando se il pulsante risponde.
       */
      final byte = await backup.esportaV2(
        chiaveMaestra: maestra,
        archivio: await ref.read(archivioSaluteProvider).esportaPerBackup(),
        codice: codice,
      );

      /*
       * 💡 Si scrive in una cartella temporanea e si passa al foglio di
       * condivisione. ⚠️ Non si salva da nessuna parte da soli: dove tenere un
       * file che vale quanto l'account lo deve decidere la persona, non noi.
       */
      final cartella = await getTemporaryDirectory();
      final file = File('${cartella.path}/training-companion-backup.json');
      await file.writeAsBytes(byte);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'Copia di sicurezza Training Companion',
        ),
      );

      if (mounted) setState(() => _codice = codice);
    } on Object catch (_) {
      messaggeria.showSnackBar(
        const SnackBar(content: Text('Non riesco a creare il file.')),
      );
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }
}
