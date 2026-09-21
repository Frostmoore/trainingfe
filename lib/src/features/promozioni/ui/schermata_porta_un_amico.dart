import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/intestazione_app.dart';
import '../data/promozioni.dart';

/// 🤝 **Porta un amico** — 24/09/2026, P8 di `plan_promozioni.md` (opzione 27).
///
/// Il mio codice, il link da mandare, e quanti amici sono già arrivati.
///
/// ⚠️ **Non promette premi**: se ci sono lo decide una promozione del pannello
/// (evento «porta un amico»), che può esserci o no. La schermata dice solo cosa
/// succede di sicuro — l'amico si iscrive col tuo codice.
class SchermataPortaUnAmico extends ConsumerWidget {
  const SchermataPortaUnAmico({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dati = ref.watch(ilMioCodiceAmicoProvider);
    final tema = Theme.of(context);

    return Scaffold(
      appBar: const IntestazioneApp(titolo: 'Porta un amico'),
      body: dati.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(
          child: Padding(
            padding: EdgeInsets.all(Gap.lg),
            child: Text(
              'Non riesco a leggere il tuo codice. Riprova fra poco.',
            ),
          ),
        ),
        data: (mio) => ListView(
          padding: const EdgeInsets.all(Gap.lg),
          children: [
            Text(
              'Manda il link a chi vuoi: si iscrive, e il suo account resta '
              'legato al tuo. Se c\'è un\'offerta per chi porta un amico, '
              'arriva da sola.',
              style: tema.textTheme.bodyLarge,
            ),
            const SizedBox(height: Gap.lg),
            Text('Il tuo codice', style: tema.textTheme.titleMedium),
            const SizedBox(height: Gap.sm),
            SelectableText(
              mio.codice,
              style: tema.textTheme.headlineMedium?.copyWith(letterSpacing: 4),
            ),
            const SizedBox(height: Gap.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: mio.link));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Link copiato')),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('Copia il link'),
                  ),
                ),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => SharePlus.instance.share(
                      ShareParams(
                        text:
                            'Ti invito su Training Companion: ${mio.link}\n'
                            'Il mio codice amico è ${mio.codice}.',
                      ),
                    ),
                    icon: const Icon(Icons.share_rounded),
                    label: const Text('Condividi'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Gap.lg),
            Text(
              mio.amici == 0
                  ? 'Nessun amico si è ancora iscritto col tuo codice.'
                  : mio.amici == 1
                  ? 'Un amico si è iscritto col tuo codice.'
                  : '${mio.amici} amici si sono iscritti col tuo codice.',
              style: tema.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
