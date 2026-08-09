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

        const SizedBox(height: Gap.md),
        Text(
          branding.name,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _Iniziale extends StatelessWidget {
  const _Iniziale({required this.branding});

  final GymBranding branding;

  @override
  Widget build(BuildContext context) {
    final iniziale = branding.name.trim().isEmpty ? '?' : branding.name.trim()[0].toUpperCase();

    return Container(
      height: 88,
      width: 88,
      decoration: BoxDecoration(color: branding.primary, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        iniziale,
        style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: Colors.white),
      ),
    );
  }
}
