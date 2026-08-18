import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../auth/auth_controller.dart';

/// L'avatar in alto a destra, che porta al profilo — M7.1, 18/08/2026.
///
/// ── 🚨 Perché il profilo esce dalla barra in basso ─────────────────────────
///
/// *(richiesta del committente)*. La barra in basso è **quello che si fa ogni
/// giorno**: oggi, diario, allenamento, messaggi. ⚠️ Il profilo non è
/// un'attività — è dove si va a cambiare una cosa, ogni tanto — e teneva un
/// quinto dello spazio più prezioso dell'app per una schermata che si apre una
/// volta a settimana.
///
/// 💡 In alto a destra con la propria faccia è anche **dove le persone lo
/// cercano già**: è la convenzione di ogni applicazione che hanno sul telefono.
class BottoneProfilo extends ConsumerWidget {
  const BottoneProfilo({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final utente = ref.watch(authControllerProvider).user;
    final tema = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: IconButton(
        tooltip: 'Il tuo profilo',
        onPressed: () => context.push(AppRoutes.profile),
        icon: CircleAvatar(
          radius: 16,
          backgroundColor: tema.colorScheme.primaryContainer,

          /*
           * 💡 `NetworkImage` con il ripiego sulle iniziali: se l'immagine non
           * si carica — rete lenta, file cancellato — resta il cerchio con le
           * lettere. ⚠️ Senza il ripiego comparirebbe un buco grigio, che si
           * legge come «app rotta» e non come «foto non ancora caricata».
           */
          foregroundImage: utente?.avatarUrl != null
              ? NetworkImage(utente!.avatarUrl!)
              : null,
          child: Text(
            utente?.initials ?? '?',
            style: tema.textTheme.labelMedium?.copyWith(
              color: tema.colorScheme.onPrimaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}
