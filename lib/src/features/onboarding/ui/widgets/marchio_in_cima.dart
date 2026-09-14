import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/gym_branding.dart';

/// Il marchio in cima alle schermate d'ingresso — era `GymHeader` (A2.2).
///
/// ══ 🚨 PERCHE' NON SI CHIAMA PIU' `GymHeader` ═════════════════════════════
///
/// ⛔ Perché non disegna solo le palestre, e **non lo faceva nemmeno prima**:
/// chi non ne ha una vedeva lo stesso un cerchio con una lettera dentro. La
/// lettera era la «T» di *Training Companion*, il nome che porta
/// `GymBranding.neutral`.
///
/// ⚠️ Trovato il 14/09 girando l'app da un account nuovo: `/benvenuto` mostrava
/// **il manubrio**, `/accedi` e `/registrati` un **cerchio verde con una T**.
/// Tre schermate consecutive, due marchi diversi, e il nome dell'applicazione
/// da nessuna parte — proprio dove una persona non sa ancora cosa ha aperto.
///
/// ══ 🚨 LA CAUSA È IL QUINTO PUNTO DI UN DIFETTO GIÀ CHIUSO ════════════════
///
/// Il controllo era `name != null && name.isNotEmpty`, e
/// `GymBranding.haPalestra` esiste **apposta** perché quella riga dà il
/// risultato sbagliato: `neutral` ha `name: 'Training Companion'`, cioè un nome
/// non vuoto a tutti gli effetti. Il dartdoc di `haPalestra` avvertiva che il
/// difetto sarebbe rinato «dal quinto punto in poi». 💡 Questo era il quinto.
///
/// ⚠️ Chi tocca questo file usa **`haPalestra`**, mai il nome.
///
/// ══ 💡 COSA DISEGNA, NEI DUE CASI ═════════════════════════════════════════
///
/// | Chi guarda | Cosa vede |
/// |---|---|
/// | Iscritto a una palestra | Il logo della palestra, o la sua iniziale, e il suo nome |
/// | Chiunque altro | Il manubrio su cerchio, e **«Training Companion»** |
///
/// 🚨 **Il nome dell'applicazione si scrive**, e non è ridondanza: `/benvenuto`
/// è l'unica schermata che si vede prima di avere un account, cioè l'unica in
/// cui qualcuno può ancora chiedersi cosa ha appena aperto.
class MarchioInCima extends StatelessWidget {
  const MarchioInCima({required this.branding, super.key});

  final GymBranding branding;

  /// Il nome dell'applicazione, scritto una volta sola.
  static const nomeApp = 'Training Companion';

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    // 🚨 `haPalestra` e non il nome: vedi il dartdoc della classe.
    final palestra = branding.haPalestra;
    final titolo = palestra ? branding.name!.trim() : nomeApp;

    return Column(
      children: [
        /*
         * 🚨 **Il logo remoto solo a chi ha una palestra.** Su rete mobile
         * un'immagine remota fallisce spesso, e una schermata d'accesso con un
         * rettangolo vuoto in cima sembra rotta: il ripiego è il cerchio, che
         * si vede che è voluto.
         */
        if (palestra && branding.logoUrl != null)
          CachedNetworkImage(
            imageUrl: branding.logoUrl!,
            height: 88,
            fit: BoxFit.contain,
            placeholder: (_, _) => const SizedBox(height: 88),
            errorWidget: (_, _, _) => _Cerchio(branding: branding),
          )
        else
          _Cerchio(branding: branding),

        const SizedBox(height: Gap.md),
        Text(
          titolo,
          textAlign: TextAlign.center,
          style: tema.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

/// Il cerchio: l'iniziale della palestra, o il manubrio dell'applicazione.
class _Cerchio extends StatelessWidget {
  const _Cerchio({required this.branding});

  final GymBranding branding;

  @override
  Widget build(BuildContext context) {
    // 🚨 Di nuovo `haPalestra`: senza, qui dentro rinasceva la «T».
    final iniziale = branding.haPalestra
        ? branding.name!.trim()[0].toUpperCase()
        : null;

    return Container(
      height: 88,
      width: 88,
      decoration: BoxDecoration(
        color: branding.primary,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: iniziale == null
          ? const Icon(
              Icons.fitness_center_rounded,
              size: 40,
              color: Colors.white,
            )
          : Text(
              iniziale,
              style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
    );
  }
}
