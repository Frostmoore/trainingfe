/// La foto di un allenamento: aggiungerla, e **vederla lì** — 3b-B.20.8.
///
/// ══ 📌 LA RICHIESTA ═══════════════════════════════════════════════════════
///
/// *«Anche nella schermata di allenamento con orologio devo poter aggiungere una
/// foto. Idem per gli allenamenti completati senza foto, se voglio devo poter
/// aggiungere una foto dalla pagina dell'allenamento»*.
///
/// ⛔ Prima questa card viveva **dentro** `session_summary_screen`, privata e
/// legata a una `WorkoutSession`. Un allenamento visto solo dall'orologio una
/// sessione non ce l'ha, quindi non poteva averla — e la pagina che doveva
/// essere «identica» perdeva proprio il pezzo che si riempie a fine
/// allenamento.
///
/// 💡 Adesso la card è una sola e si aggancia **all'uno o all'altro**: le due
/// colonne dell'archivio (`sessioneId` e `allenamentoOrologioId`) non sono mai
/// piene insieme, e questo widget rispecchia quella forma.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/foto_locale.dart';
import '../../../progress/progress_controller.dart';

class FotoDellAllenamento extends ConsumerStatefulWidget {
  const FotoDellAllenamento({
    this.sedutaId,
    this.allenamentoOrologioId,
    super.key,
  });

  /// L'id della seduta dell'app, quando l'allenamento ne ha una.
  final int? sedutaId;

  /// L'id della riga dell'orologio, quando l'allenamento viene solo da lì.
  final int? allenamentoOrologioId;

  @override
  ConsumerState<FotoDellAllenamento> createState() =>
      _FotoDellAllenamentoState();
}

class _FotoDellAllenamentoState extends ConsumerState<FotoDellAllenamento> {
  bool _inCorso = false;

  Future<void> _carica({required bool daFotocamera}) async {
    setState(() => _inCorso = true);

    try {
      await ref
          .read(progressActionsProvider)
          .upload(
            context: context,
            daFotocamera: daFotocamera,
            workoutSessionId: widget.sedutaId,
            allenamentoOrologioId: widget.allenamentoOrologioId,
          );

      // ⚠️ Non serve invalidare niente: `upload()` incrementa la revisione, e i
      // due provider delle foto si ricalcolano da soli.
    } on Object catch (errore) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiClient.unwrapError(errore).message)),
        );
      }
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    final seduta = widget.sedutaId;
    final polso = widget.allenamentoOrologioId;

    /*
     * ⛔ **Senza un aggancio non si disegna niente.** Una card «Foto» con due
     * pulsanti che salvano una foto attaccata a nessun allenamento sarebbe una
     * foto che poi non si ritrova più.
     */
    if (seduta == null && polso == null) return const SizedBox.shrink();

    final foto =
        (seduta != null
            ? ref.watch(fotoSessioneProvider(seduta)).valueOrNull
            : ref.watch(fotoAllenamentoOrologioProvider(polso!)).valueOrNull) ??
        const [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.photo_camera_outlined,
                  color: tema.colorScheme.primary,
                ),
                const SizedBox(width: Gap.sm),
                Text('Foto', style: tema.textTheme.titleMedium),
              ],
            ),

            if (foto.isNotEmpty) ...[
              const SizedBox(height: Gap.sm),
              SizedBox(
                height: 160,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: foto.length,
                  separatorBuilder: (context, i) =>
                      const SizedBox(width: Gap.sm),
                  // 💡 File locale da S5.3: niente token, niente 401 in cache.
                  itemBuilder: (context, i) => ClipRRect(
                    borderRadius: BorderRadius.circular(Gap.radiusSm),
                    child: FotoLocale(file: foto[i].file, width: 130),
                  ),
                ),
              ),
            ],

            const SizedBox(height: Gap.sm),

            if (_inCorso)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: Gap.sm),
                child: LinearProgressIndicator(),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _carica(daFotocamera: true),
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Scatta'),
                    ),
                  ),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _carica(daFotocamera: false),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Galleria'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
