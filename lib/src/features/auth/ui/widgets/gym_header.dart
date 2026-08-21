import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../onboarding/data/gym_branding.dart';

/// Logo e nome della palestra, in cima alle schermate di accesso — A2.2.
///
/// 🚨 **Se il logo non carica, non deve restare un buco.** Su rete mobile una
/// immagine remota fallisce spesso, e una schermata di accesso con un rettangolo
/// vuoto in cima sembra rotta. Il ripiego è l'iniziale della palestra su un
/// cerchio colorato: si vede che è voluto.
class GymHeader extends StatelessWidget {
  const GymHeader({required this.branding, super.key});

  final GymBranding branding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nome = branding.name?.trim();

    return Column(
      children: [
        if (branding.logoUrl != null)
          CachedNetworkImage(
            imageUrl: branding.logoUrl!,
            height: 88,
            fit: BoxFit.contain,
            placeholder: (_, _) => const SizedBox(height: 88),
            errorWidget: (_, _, _) => _Iniziale(branding: branding),
          )
        else
          _Iniziale(branding: branding),

        // 🚨 Senza palestra non si scrive niente — F3.
        //
        // Il nome è `null` per chi si è iscritto senza codice. ⚠️ Qui non si
        // mette un ripiego: scrivere «La tua palestra» a chi ha scelto di non
        // averne una è peggio del vuoto, perché afferma una cosa falsa invece
        // di tacere.
        if (nome != null && nome.isNotEmpty) ...[
          const SizedBox(height: Gap.md),
          Text(
            nome,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ],
    );
  }
}

class _Iniziale extends StatelessWidget {
  const _Iniziale({required this.branding});

  final GymBranding branding;

  @override
  Widget build(BuildContext context) {
    // 💡 Senza palestra il cerchio resta, con il logo dell'applicazione al
    // posto dell'iniziale: un buco in cima alla schermata di accesso la fa
    // sembrare rotta, ed è il motivo per cui questo widget esiste.
    final nome = branding.name?.trim() ?? '';
    final iniziale = nome.isEmpty ? null : nome[0].toUpperCase();

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
