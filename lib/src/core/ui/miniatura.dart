import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// La miniatura di una scheda o di un esercizio — C23.
///
/// 🚨 **Senza immagine non si lascia un buco: si disegna un segnaposto.**
/// Una lista in cui alcune righe hanno una miniatura e altre un vuoto della
/// stessa dimensione sembra rotta. Il segnaposto tiene l'allineamento e resta
/// leggibile.
///
/// ⚠️ **Da 3b-L il caso raro è quello opposto.** Prima quasi nessun esercizio
/// aveva una figura — le caricava la palestra, una alla volta. Adesso ne hanno
/// una **307 su 314**, e il segnaposto serve per i sette che restano e per gli
/// esercizi scritti a mano dalle palestre.
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
    this.tinta,
    super.key,
  });

  final String? url;

  /// Di che colore dipingere l'immagine — 3b-L, 28/08/2026.
  ///
  /// ══ 🚨 SERVE PERCHE' I DISEGNI DEL CATALOGO SONO BIANCHI ══════════════
  ///
  /// Le illustrazioni sono un tratto **bianco su trasparente**: nate per uno
  /// sfondo scuro, su una card chiara sarebbero **invisibili** — non brutte,
  /// proprio assenti. ⛔ E lo stesso file deve servire tema chiaro e tema
  /// scuro, quindi il colore non può stare dentro il file.
  ///
  /// 💡 `BlendMode.srcIn` tiene la forma (il canale alfa) e butta il colore:
  /// è esattamente quello che serve a una sagoma.
  ///
  /// ⚠️ **Va passata solo per i disegni al tratto.** Su una fotografia —
  /// la copertina di una scheda, la macchina fotografata dalla palestra —
  /// dipingerebbe tutto di una tinta piatta e la distruggerebbe. 🚨 Per questo
  /// il valore predefinito è `null`: chi non sa cosa sta disegnando non tinge.
  final Color? tinta;

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

        /*
         * ⚠️ **`contain` quando è un disegno, `cover` quando è una foto.**
         * I disegni hanno il margine dentro il file: ritagliandoli si
         * taglierebbero via testa e bilanciere. 💡 Una fotografia invece va
         * riempita, o resta con due bande vuote ai lati.
         */
        fit: tinta == null ? BoxFit.cover : BoxFit.contain,
        color: tinta,
        colorBlendMode: tinta == null ? null : BlendMode.srcIn,
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
