import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// La miniatura di una scheda o di un esercizio — C23.
///
/// 🚨 **Senza immagine non si lascia un buco: si disegna un segnaposto.**
/// La maggior parte degli esercizi non avrà mai una foto — le carica la palestra,
/// una alla volta — e una lista in cui alcune righe hanno una miniatura e altre
/// un vuoto della stessa dimensione sembra rotta. Il segnaposto con l'iniziale
/// tiene l'allineamento e resta leggibile.
///
/// ⚠️ **Nessuna intestazione di autenticazione, a differenza delle foto dei
/// progressi.** Quelle passano da un endpoint che controlla di chi sono; queste
/// sono illustrazioni servite da un URL pubblico, e possono usare la cache di
/// rete come qualunque immagine.
class Miniatura extends StatelessWidget {
  const Miniatura({
    required this.url,
    required this.etichetta,
    this.lato = 48,
    this.icona = Icons.fitness_center_rounded,
    super.key,
  });

  final String? url;

  /// Da cui si ricava l'iniziale del segnaposto.
  final String etichetta;

  final double lato;
  final IconData icona;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final raggio = BorderRadius.circular(Gap.radiusSm);

    if (url == null || url!.isEmpty) {
      return Container(
        width: lato,
        height: lato,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: raggio,
        ),
        alignment: Alignment.center,
        child: Icon(icona, size: lato * 0.5, color: theme.colorScheme.outline),
      );
    }

    return ClipRRect(
      borderRadius: raggio,
      child: CachedNetworkImage(
        imageUrl: url!,
        width: lato,
        height: lato,
        fit: BoxFit.cover,
        placeholder: (context, _) => Container(
          width: lato,
          height: lato,
          color: theme.colorScheme.surfaceContainerHighest,
        ),
        // ⚠️ Un'immagine che non si scarica ricade sul **segnaposto**, non su
        // un riquadro rotto: un URL vecchio o un file cancellato dal pannello
        // non devono far sembrare guasta tutta la schermata.
        errorWidget: (context, _, _) => Container(
          width: lato,
          height: lato,
          color: theme.colorScheme.surfaceContainerHighest,
          alignment: Alignment.center,
          child: Icon(
            icona,
            size: lato * 0.5,
            color: theme.colorScheme.outline,
          ),
        ),
      ),
    );
  }
}
