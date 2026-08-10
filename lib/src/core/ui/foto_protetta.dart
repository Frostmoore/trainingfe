import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/progress/progress_controller.dart';

/// Un'immagine servita da un endpoint **autenticato**.
///
/// 🚨 **Non si disegna finché il token non c'è.**
///
/// Le foto dell'iscritto (progressi, allenamento) non stanno su un URL
/// pubblico: `/photos/{id}/file` controlla di chi sono e senza intestazione
/// risponde **401**. `CachedNetworkImage` non passa dagli interceptor di `dio`,
/// quindi l'intestazione va data a mano — ma il token si legge dal Keychain,
/// cioè **in modo asincrono**.
///
/// Il difetto che questa classe esiste per chiudere: chi scriveva
/// `httpHeaders: ref.watch(provider).valueOrNull ?? const {}` alla prima
/// costruzione otteneva `{}`, faceva la richiesta **senza token**, prendeva 401
/// — e `CachedNetworkImage` **si tiene l'errore**: quando il token arrivava, un
/// istante dopo, non riprovava più. Risultato: un riquadro rotto permanente,
/// con il file perfettamente presente sul server. È successo nel riepilogo di
/// fine allenamento, dove la foto si carica e si guarda nello stesso secondo.
///
/// Qui si aspetta: finché il token non è pronto si mostra il segnaposto, e
/// `CachedNetworkImage` nasce solo quando l'intestazione esiste davvero.
class FotoProtetta extends ConsumerWidget {
  const FotoProtetta({
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    super.key,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final intestazioni = ref.watch(progressAuthHeaderProvider).valueOrNull;

    Widget riquadro({IconData? icona}) => Container(
      width: width,
      height: height,
      color: theme.colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: icona == null ? null : Icon(icona, color: theme.colorScheme.outline),
    );

    // ⚠️ `null` = il token si sta ancora leggendo. `{}` non andrebbe bene:
    // sarebbe una richiesta senza autenticazione, cioè un 401 memorizzato.
    if (intestazioni == null) return riquadro();

    return CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      httpHeaders: intestazioni,
      placeholder: (context, _) => riquadro(),
      errorWidget: (context, _, _) => riquadro(icona: Icons.broken_image_outlined),
    );
  }
}
