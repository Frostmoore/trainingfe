import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/ui/states.dart';
import '../auth_controller.dart';

/// La frase che conta, e che serve **in tutti e due i posti**.
///
/// ══ 🚨 Perché è una costante e non due stringhe uguali ════════════════════
///
/// ⛔ Il giro UX del 23/09: sospesa la palestra e rifatto l'accesso, l'app
/// rispondeva con la sola riga del server — *«La tua palestra è sospesa.
/// Contattala per riattivare l'accesso.»* — mentre la schermata dedicata dice
/// anche **che i dati sono al sicuro**.
///
/// ⚠️ È la cosa che uno vuole sapere per prima quando si trova chiuso fuori, e
/// la riceveva **solo chi era già dentro**: chi stava provando a entrare — cioè
/// chi è più in ansia — no.
///
/// 💡 Una costante sola: due copie della stessa rassicurazione si separano alla
/// prima riscrittura, e la versione buona resterebbe in uno dei due posti a
/// caso.
const rassicurazionePalestraSospesa =
    'Il tuo account e i tuoi dati sono al sicuro: torneranno disponibili '
    'appena la palestra riattiverà l\'abbonamento. Per informazioni, rivolgiti '
    'direttamente a loro.';

/// La palestra ha sospeso il servizio — A2.4.
///
/// 🚨 **Perché è una schermata a sé e non un messaggio d'errore.**
/// L'utente ha le credenziali giuste e non può farci niente: non è un errore
/// suo. Mandarlo al login lo farebbe riprovare all'infinito con la password
/// corretta, convinto di sbagliarla; mostrargli un errore generico gli farebbe
/// pensare che l'app sia rotta e la disinstallerebbe.
///
/// Qui gli si dice cosa è successo, **a chi rivolgersi**, e gli si lascia un
/// modo per riprovare quando la palestra avrà sistemato — perché è l'unica cosa
/// che può fare.
class GymInactiveScreen extends ConsumerWidget {
  const GymInactiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: EmptyState(
                icon: Icons.pause_circle_outline_rounded,
                title: 'Servizio sospeso',
                message:
                    '${auth.message ?? 'La tua palestra ha sospeso il servizio.'}\n\n'
                    '$rassicurazionePalestraSospesa',
                action: FilledButton.icon(
                  onPressed: () =>
                      ref.read(authControllerProvider.notifier).refresh(),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Controlla di nuovo'),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Gap.lg),
              child: TextButton(
                onPressed: () =>
                    ref.read(authControllerProvider.notifier).logout(),
                child: const Text('Esci'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
