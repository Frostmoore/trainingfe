import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/avvertenza_nutrizionale.dart';
import '../data/importazione_piano.dart';
import 'revisione_piano_importato.dart';

/// Importare un piano alimentare da un PDF — N20.
///
/// ── 🚨 Cosa fa davvero questa funzione, detto senza giri ──────────────────
///
/// **Ricopia**, non elabora. Il piano l'ha scritto un professionista abilitato
/// fuori di qui — un medico, un biologo nutrizionista, un dietista — e noi lo
/// trasformiamo in righe che l'app sa leggere. Elaborare una dieta è un atto
/// riservato (art. 348 c.p.), e non è quello che succede qui.
///
/// ⚠️ Per questo si chiede una **dichiarazione** e non una spunta di comodo, e
/// per questo la trascrizione va **controllata riga per riga** prima di
/// diventare un piano (N20.3).
///
/// 💡 Costa 50 gettoni, ed è scritto **prima** di scegliere il file: scoprire il
/// prezzo dopo aver caricato è il modo di far arrabbiare qualcuno per un
/// numero che avrebbe accettato senza problemi.
class ImportaPianoScreen extends ConsumerStatefulWidget {
  const ImportaPianoScreen({super.key});

  static const gettoni = 50;

  /// 🚨 Lo stesso tetto del server (`ImportazionePiano::BYTE_MASSIMI`).
  ///
  /// ⚠️ Si controlla **prima di caricare**: mandare dieci megabyte per poi
  /// ricevere un 422 vuol dire aver consumato il piano dati di qualcuno per
  /// niente, e su rete mobile metterci anche un minuto prima di dirglielo.
  static const tetto = 10 * 1024 * 1024;

  @override
  ConsumerState<ImportaPianoScreen> createState() => _ImportaPianoScreenState();
}

class _ImportaPianoScreenState extends ConsumerState<ImportaPianoScreen> {
  bool _dichiarazione = false;
  bool _inCorso = false;
  String? _errore;
  String? _passo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Importa un piano')),
      body: ListView(
        padding: const EdgeInsets.all(Gap.md),
        children: [
          const _Spiegazione(),
          const SizedBox(height: Gap.md),

          CheckboxListTile(
            value: _dichiarazione,
            onChanged: _inCorso
                ? null
                : (v) => setState(() => _dichiarazione = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text(
              'Dichiaro che questo piano è stato redatto da un professionista '
              'abilitato (medico, biologo nutrizionista o dietista) e che lo '
              'importo sotto la mia responsabilità.',
            ),
          ),
          const SizedBox(height: Gap.md),

          if (_passo != null) ...[
            Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: Gap.sm),
                Expanded(child: Text(_passo!)),
              ],
            ),
            const SizedBox(height: Gap.md),
          ],

          if (_errore != null) ...[
            Text(
              _errore!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: Gap.md),
          ],

          FilledButton.icon(
            /*
             * 🚨 Il pulsante è spento finché la dichiarazione non c'è: il
             * server la pretende comunque (`accepted`), ma far scegliere un
             * file per poi rifiutarlo sarebbe una lezione inutile.
             */
            onPressed: _dichiarazione && !_inCorso ? _scegliEImporta : null,
            icon: const Icon(Icons.upload_file),
            label: const Text(
              'Scegli il PDF · ${ImportaPianoScreen.gettoni} gettoni',
            ),
          ),
          const SizedBox(height: Gap.lg),

          const AvvertenzaNutrizionale(),
        ],
      ),
    );
  }

  Future<void> _scegliEImporta() async {
    // 📌 `FilePicker.platform` e non i metodi statici: siamo fermi alla 10.x,
    // vedi la nota in `conversations_screen.dart`.
    final scelta = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: true,
    );

    final file = scelta?.files.firstOrNull;
    final byte = file?.bytes;

    if (byte == null || !mounted) return;

    if (byte.length > ImportaPianoScreen.tetto) {
      setState(
        () => _errore = 'Questo PDF supera i 10 MB: non riesco a caricarlo.',
      );

      return;
    }

    setState(() {
      _inCorso = true;
      _errore = null;
      _passo = 'Carico il PDF…';
    });

    try {
      final importazioni = ref.read(importazioniPianiProvider);

      var importazione = await importazioni.carica(
        byte: byte,
        nomeFile: file!.name,
        dichiarazione: true,
      );

      if (!mounted) return;

      setState(() => _passo = 'Sto ricopiando il piano: ci vuole un minuto…');

      importazione = await _aspetta(importazione.id);

      if (!mounted) return;

      if (importazione.stato == StatoImportazione.fallita) {
        setState(() {
          _errore =
              'Non sono riuscito a leggere questo PDF. '
              '${importazione.errore ?? ''}\n\n'
              'I gettoni non sono stati scalati.';
          _inCorso = false;
          _passo = null;
        });

        return;
      }

      setState(() {
        _inCorso = false;
        _passo = null;
      });

      final salvato = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => RevisionePianoImportato(importazione: importazione),
        ),
      );

      if (!mounted) return;

      if (salvato ?? false) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Piano salvato sul telefono.')),
        );

        Navigator.of(context).pop();
      }
    } on Object catch (e) {
      if (!mounted) return;

      setState(() {
        _errore = ApiClient.unwrapError(e).message;
        _inCorso = false;
        _passo = null;
      });
    }
  }

  /// Aspetta che il job finisca, chiedendo ogni tre secondi.
  ///
  /// ── ⚠️ Perché si chiede invece di ricevere ──────────────────────────────
  ///
  /// Perché è **una volta sola**, dura un minuto e finisce. Aprire un canale
  /// realtime per un evento che accade una volta per importazione vorrebbe dire
  /// mantenere un pezzo di infrastruttura per il caso più raro che abbiamo.
  ///
  /// 🚨 **E c'è un limite di tentativi.** Senza, un job morto lascerebbe una
  /// rotellina che gira per sempre — che è il modo peggiore di fallire, perché
  /// non dice niente e non finisce mai.
  Future<ImportazionePiano> _aspetta(int id) async {
    final importazioni = ref.read(importazioniPianiProvider);

    for (var tentativo = 0; tentativo < 40; tentativo++) {
      await Future<void>.delayed(const Duration(seconds: 3));

      if (!mounted) throw StateError('Schermata chiusa.');

      final stato = await importazioni.stato(id);

      if (!stato.inLavorazione) return stato;
    }

    throw TimeoutException('La trascrizione ci sta mettendo troppo.');
  }
}

class _Spiegazione extends StatelessWidget {
  const _Spiegazione();

  @override
  Widget build(BuildContext context) {
    final testi = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Come funziona', style: testi.titleMedium),
            const SizedBox(height: Gap.sm),
            Text(
              'Carichi il PDF del piano che ti ha dato il tuo professionista. '
              'Un modello lo ricopia riga per riga in una bozza, tu la '
              'controlli confrontandola con l\'originale, e solo allora diventa '
              'il tuo piano.',
              style: testi.bodyMedium,
            ),
            const SizedBox(height: Gap.sm),
            Text(
              'Il piano resta sul tuo telefono. Il PDF che carichi viene '
              'cancellato dal server appena hai finito, e comunque entro sette '
              'giorni.',
              style: testi.bodySmall,
            ),
            const SizedBox(height: Gap.sm),
            Text(
              'Nessuno qui dentro elabora diete: quello lo ha già fatto chi ha '
              'firmato il tuo piano.',
              style: testi.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
