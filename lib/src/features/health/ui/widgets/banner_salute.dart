import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../health_controller.dart';

/// L'invito a collegare Health Connect, in «Oggi» — 14/09/2026.
///
/// ══ 📌 PERCHE' ESISTE ═════════════════════════════════════════════════════
///
/// 📌 Il committente, dopo il giro sull'emulatore: *«per Collega google health
/// c'è il tasto + quindi in realtà quella la possiamo anche togliere, magari
/// mettiamo un bannerino in oggi»*.
///
/// ⛔ **Prima era il terzo dialogo di fila subito dopo l'accesso** — impronta,
/// ripristino, salute, consensi — e arrivava a qualcuno che **non aveva ancora
/// visto niente**: nessun dato suo, nessuna card, nessun motivo per capire cosa
/// siano «il sonno e il battito». 🚨 Un permesso chiesto lì si nega per
/// riflesso, e su Android un rifiuto ripetuto rende la richiesta **non più
/// riproponibile** — cioè brucia la funzione per sempre.
///
/// 💡 Un banner nella schermata che quei numeri li mostra si legge **quando si
/// ha la domanda**, non mentre si sta ancora entrando. E non blocca niente: chi
/// non lo tocca continua a usare l'app.
///
/// ══ ⚠️ QUANDO SPARISCE ════════════════════════════════════════════════════
///
/// | Caso | Chi glielo dice |
/// |---|---|
/// | Il permesso c'è già | `_permessoSaluteProvider` |
/// | È stato appena concesso | `healthControllerProvider.collegato` |
/// | È stato chiuso con la ✕ | `LocalCache`, chiave `salute_banner_chiuso` |
///
/// ⚠️ **Il telefono senza Health Connect resta scoperto**: `permessiGiaConcessi()`
/// risponde `false` sia a «non concesso» sia a «non installato», e il banner si
/// vede lo stesso. 💡 Chi lo tocca riceve l'errore del controllore, che lo dice;
/// e la ✕ chiude la faccenda per sempre.
class BannerSalute extends ConsumerStatefulWidget {
  const BannerSalute({super.key});

  @override
  ConsumerState<BannerSalute> createState() => _BannerSaluteState();
}

/// Il permesso c'è già? — **letto senza aprire niente**.
///
/// 🚨 `permessiGiaConcessi()` e non `chiediPermessi()`: la seconda apre la
/// finestra di sistema, e un banner che la aprisse solo per decidere se
/// disegnarsi sarebbe esattamente il dialogo d'ingresso che sostituisce.
final _permessoSaluteProvider = FutureProvider.autoDispose<bool>(
  (ref) => ref.read(ponteSaluteProvider).permessiGiaConcessi(),
);

class _BannerSaluteState extends ConsumerState<BannerSalute>
    with WidgetsBindingObserver {
  /// La chiave su disco: una volta chiuso, resta chiuso.
  static const _chiave = 'salute_banner_chiuso';

  bool _chiuso = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _chiuso = ref.read(localCacheProvider).getBool(_chiave) ?? false;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// ⚠️ **Il permesso si concede fuori dall'app**: si apre Health Connect, si
  /// spunta, si torna indietro. 🚨 Senza questo, il banner resterebbe a offrire
  /// una cosa appena ottenuta finché non si cambia schermata.
  @override
  void didChangeAppLifecycleState(AppLifecycleState stato) {
    if (stato == AppLifecycleState.resumed) {
      ref.invalidate(_permessoSaluteProvider);
    }
  }

  Future<void> _chiudi() async {
    setState(() => _chiuso = true);

    await ref.read(localCacheProvider).setBool(_chiave, value: true);
  }

  @override
  Widget build(BuildContext context) {
    if (_chiuso) return const SizedBox.shrink();

    final stato = ref.watch(healthControllerProvider);

    // 💡 Chi collega da qui, o dalla schermata dei consensi: sparisce subito,
    // senza aspettare che qualcuno riapra l'app.
    if (stato.collegato) return const SizedBox.shrink();

    /*
     * ⚠️ **Finché non si sa, non si disegna.** Un banner che compare per mezzo
     * secondo e poi sparisce a chi il permesso ce l'ha già fa sobbalzare la
     * pagina sotto le dita: arrivare un attimo tardi costa meno.
     */
    final concesso = ref.watch(_permessoSaluteProvider).valueOrNull;

    if (concesso == null || concesso) return const SizedBox.shrink();

    final tema = Theme.of(context);

    return Card(
      color: tema.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.favorite_outline_rounded,
                  color: tema.colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Collega Google Health',
                        style: tema.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: tema.colorScheme.onSecondaryContainer,
                        ),
                      ),
                      const SizedBox(height: 2),

                      /*
                       * ⚠️ **Dice cosa ci guadagna chi legge, e dove finiscono
                       * i dati.** 🚨 La seconda frase non è una cortesia: è la
                       * sola risposta alla domanda che una persona si fa prima
                       * di dare accesso al proprio sonno.
                       */
                      Text(
                        "L'app legge sonno, battito e calorie bruciate, e le "
                        'somma al tuo obiettivo del giorno. Restano sul '
                        'telefono: non le mandiamo a nessun server.',
                        style: tema.textTheme.bodySmall?.copyWith(
                          color: tema.colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),

                // 🚨 La ✕ c'è: senza, l'unico modo di non vederlo più sarebbe
                // concedere il permesso — cioè un invito che non si può
                // rifiutare.
                IconButton(
                  onPressed: _chiudi,
                  icon: const Icon(Icons.close_rounded, size: 20),
                  tooltip: 'Non mostrare più',
                  color: tema.colorScheme.onSecondaryContainer,
                ),
              ],
            ),

            if (stato.errore != null) ...[
              const SizedBox(height: Gap.sm),
              Text(
                stato.errore!,
                style: tema.textTheme.bodySmall?.copyWith(
                  color: tema.colorScheme.error,
                ),
              ),
            ],

            const SizedBox(height: Gap.sm),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: stato.inCorso
                    ? null
                    : () => unawaited(
                        ref.read(healthControllerProvider.notifier).collega(),
                      ),
                icon: stato.inCorso
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.link_rounded, size: 18),
                label: const Text('Collega'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
