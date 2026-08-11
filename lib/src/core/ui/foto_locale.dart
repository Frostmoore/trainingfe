import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Una foto che vive **sul telefono** — S5.3.
///
/// 🚨 **Sostituisce `FotoProtetta`, che è stata cancellata.**
///
/// `FotoProtetta` esisteva per un problema che non c'è più: le foto stavano su
/// `/photos/{id}/file`, un endpoint autenticato, e `CachedNetworkImage` non
/// passa dagli interceptor di `dio` — quindi bisognava dargli l'intestazione a
/// mano, aspettando che il token arrivasse dal Keychain. Un difetto vero (G12),
/// risolto con una classe apposta.
///
/// 💡 **Da S5.3 quel problema è sparito insieme all'endpoint**: le foto sono
/// file locali, non c'è nessuna richiesta da autenticare e nessun 401 da
/// mettere in cache. È il caso migliore di risoluzione di un difetto — non è
/// stato corretto, è stata tolta la condizione che lo rendeva possibile.
///
/// ⚠️ Il file **può non esserci**: l'utente può aver ripulito lo spazio, o il
/// ripristino può averne portato l'indice ma non i byte. Si disegna un
/// segnaposto, non un riquadro rotto.
class FotoLocale extends StatelessWidget {
  const FotoLocale({
    required this.file,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    super.key,
  });

  final File file;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget segnaposto([IconData icona = Icons.image_outlined]) => Container(
      width: width,
      height: height,
      color: theme.colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(icona, color: theme.colorScheme.outline),
    );

    if (!file.existsSync()) return segnaposto(Icons.broken_image_outlined);

    return Image.file(
      file,
      width: width,
      height: height,
      fit: fit,
      // ⚠️ Anche esistendo, il file può essere troncato o corrotto: un
      // ripristino interrotto a metà lascia esattamente questo. Meglio un
      // segnaposto che un'eccezione durante il layout, che farebbe sparire la
      // schermata intera (§8.9).
      errorBuilder: (_, _, _) => segnaposto(Icons.broken_image_outlined),
      // La cache in memoria evita di rileggere il file a ogni scorrimento
      // della griglia: sono immagini grandi, e senza si vede scattare.
      cacheWidth: width == null ? null : (width! * MediaQuery.devicePixelRatioOf(context)).round(),
    );
  }
}

/// Il segnaposto quadrato usato quando una foto non c'è affatto.
class RiquadroFotoAssente extends StatelessWidget {
  const RiquadroFotoAssente({this.lato = 52, super.key});

  final double lato;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Gap.radiusSm),
      ),
      child: SizedBox(
        width: lato,
        height: lato,
        child: Icon(Icons.fitness_center_rounded, color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}
