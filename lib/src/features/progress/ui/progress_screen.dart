import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/aggiornamento.dart';
import '../../../core/ui/foto_locale.dart';
import '../../../core/ui/states.dart';
import '../progress_controller.dart';

/// La galleria delle foto dei progressi — C16.
///
/// 🚨 **Le immagini si scaricano solo quando entrano nello schermo.** È
/// `CachedNetworkImage` dentro una griglia pigra a farlo, e non è un dettaglio:
/// una galleria di due anni sono centinaia di foto da un megabyte, e scaricarle
/// tutte all'apertura vorrebbe dire mezzo minuto di attesa e un conto di traffico
/// che nessuno si aspetta. La cache su disco fa il resto: scorrere avanti e
/// indietro non riscarica niente.
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foto = ref.watch(progressPhotosProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Foto dei progressi')),
      floatingActionButton: const _Aggiungi(),
      body: foto.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(
          error: ApiClient.unwrapError(e),
          onRetry: () => ref.invalidate(progressPhotosProvider),
        ),
        data: (elenco) => elenco.isEmpty
            ? const EmptyState(
                icon: Icons.photo_camera_outlined,
                title: 'Nessuna foto',
                message:
                    'Una foto ogni tanto, sempre nella stessa posizione e con la '
                    'stessa luce, racconta i progressi meglio della bilancia.',
              )
            : RefreshIndicator(
                onRefresh: () => aggiornaTutto(ref, () => ref.invalidate(progressPhotosProvider)),
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(Gap.sm, Gap.sm, Gap.sm, 96),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.78,
                    mainAxisSpacing: Gap.sm,
                    crossAxisSpacing: Gap.sm,
                  ),
                  itemCount: elenco.length,
                  itemBuilder: (context, i) => _Cella(foto: elenco[i]),
                ),
              ),
      ),
    );
  }
}

class _Cella extends ConsumerWidget {
  const _Cella({required this.foto});

  final ProgressPhoto foto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _apri(context),
            onLongPress: () => _elimina(context, ref),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Gap.radiusSm),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  // Il bordo dorato distingue le foto di fine allenamento da
                  // quelle scattate apposta: sono due cose diverse nella stessa
                  // griglia, come nell'app storica.
                  border: foto.daAllenamento
                      ? Border.all(color: theme.colorScheme.tertiary, width: 2)
                      : null,
                  borderRadius: BorderRadius.circular(Gap.radiusSm),
                ),
                // 💡 Da S5.3 la foto e' un file locale: niente token, niente
                // 401 da mettere in cache, niente `FotoProtetta`. Il difetto
                // G12 non e' stato corretto — e' sparita la condizione che lo
                // rendeva possibile.
                child: FotoLocale(file: foto.file),
              ),
            ),
          ),
        ),
        const SizedBox(height: Gap.xs),
        Text(
          DateFormat('d MMM y', 'it').format(foto.takenOn),
          style: theme.textTheme.labelSmall,
        ),
      ],
    );
  }

  /// Apre la foto a schermo intero.
  ///
  /// 💡 **Il velo scuro dietro non e' decorazione**: una foto quadrata su fondo
  /// chiaro, aperta sopra una griglia di altre foto quadrate, non si distingue
  /// da quella che era gia' li'. ⚠️ Senza uno stacco netto, chi la apre non
  /// capisce di aver aperto qualcosa — e cerca il modo di chiudere una cosa che
  /// non sembra aperta.
  void _apri(BuildContext context) => showDialog<void>(
    context: context,
    // Il velo del sistema, ma piu' fitto: il predefinito e' pensato per un
    // riquadro piccolo su una pagina di testo, non per una foto a tutto schermo.
    barrierColor: Colors.black.withValues(alpha: 0.82),
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.all(Gap.md),
      // 🚨 Senza sfondo e senza ombra: il contenitore chiaro del `Dialog`
      // disegnerebbe un rettangolo bianco attorno alla foto, e sarebbe
      // esattamente il bordo che il velo serve a togliere.
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Stack(
        alignment: Alignment.topRight,
        children: [
          Consumer(
            builder: (context, ref, _) => InteractiveViewer(
              child: FotoLocale(file: foto.file, fit: BoxFit.contain),
            ),
          ),
          /*
           * 💡 Una via d'uscita **visibile**. Il tocco fuori chiude gia', ma
           * dopo aver ingrandito con le dita non e' piu' ovvio dove sia il
           * "fuori": la X e' li' per quel momento.
           */
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
            color: Colors.white,
            tooltip: 'Chiudi',
          ),
        ],
      ),
    ),
  );

  Future<void> _elimina(BuildContext context, WidgetRef ref) async {
    // 🚨 Qui la conferma serve: una foto cancellata non si recupera, e il
    // gesto è una pressione lunga, che capita anche per sbaglio scorrendo.
    final conferma = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminare la foto?'),
        content: const Text('Non sarà possibile recuperarla.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );

    if (conferma == true) {
      await ref.read(progressActionsProvider).delete(foto.id);
    }
  }
}

class _Aggiungi extends ConsumerWidget {
  const _Aggiungi();

  @override
  Widget build(BuildContext context, WidgetRef ref) => FloatingActionButton.extended(
    // Vedi la nota su `heroTag` in `conversations_screen.dart`.
    heroTag: 'fab-foto',
    onPressed: () => showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Scatta'),
              onTap: () {
                Navigator.of(sheet).pop();
                _carica(context, ref, daFotocamera: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Scegli dalla galleria'),
              onTap: () {
                Navigator.of(sheet).pop();
                _carica(context, ref, daFotocamera: false);
              },
            ),
          ],
        ),
      ),
    ),
    icon: const Icon(Icons.add_a_photo_outlined),
    label: const Text('Aggiungi'),
  );

  Future<void> _carica(
    BuildContext context,
    WidgetRef ref, {
    required bool daFotocamera,
  }) async {
    try {
      await ref.read(progressActionsProvider).upload(context: context, daFotocamera: daFotocamera);
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(ApiClient.unwrapError(error).message)));
      }
    }
  }
}
