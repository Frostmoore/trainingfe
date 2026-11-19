import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 🧱 **I tre mattoni del corpo delle pagine** — `plan_interfaccia.md` §3.3,
/// I1, 19/11/2026.
///
/// Sotto la testata scura, ogni pagina è fatta di **sezioni con un titolo** e
/// di **tessere**, spesso **a due a due**. Stanno in un file solo perché si
/// usano sempre insieme, e cambiarne una senza le altre rompe il colpo
/// d'occhio.

/// Il titolo di una sezione: «ENERGIA DI OGGI» a sinistra, una nota corta a
/// destra («ore 13:30»).
///
/// 💡 **Si scrive normale e si mostra in maiuscolo**: così chi legge il
/// codice cerca «Energia di oggi» e lo trova, e il maiuscolo resta una scelta
/// di disegno, in un posto solo.
class TitoloDiSezione extends StatelessWidget {
  const TitoloDiSezione(this.testo, {this.nota, super.key});

  final String testo;

  final String? nota;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.xs, Gap.md, Gap.xs, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(
              testo.toUpperCase(),
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          if (nota != null)
            Text(
              nota!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

/// Il rettangolo con l'etichetta piccola in alto.
///
/// ⚠️ **Non è una `Card`**: la `Card` del tema ha l'ombra e il colore
/// `surfaceContainer`, pensati per una colonna di schede tutte uguali. Le
/// tessere stanno su un fondo grigio chiaro e si distinguono per il bianco —
/// è il disegno delle tavole del 19/11.
class Tessera extends StatelessWidget {
  const Tessera({
    required this.etichetta,
    required this.child,
    this.onTap,
    this.colore,
    super.key,
  });

  final String etichetta;

  final Widget child;

  final VoidCallback? onTap;

  /// `null` = `surfaceContainerLowest`, cioè il bianco in chiaro.
  final Color? colore;

  static const double raggio = 20;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final forma = BorderRadius.circular(raggio);

    final contenuto = Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            etichetta.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Gap.sm),
          child,
        ],
      ),
    );

    return Material(
      color: colore ?? theme.colorScheme.surfaceContainerLowest,
      borderRadius: forma,
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? contenuto
          : InkWell(onTap: onTap, borderRadius: forma, child: contenuto),
    );
  }
}

/// Due tessere affiancate, **alte uguali**.
///
/// ══ 🚨 PERCHÉ ESISTE, INVECE DI UNA `Row` OGNI VOLTA ═══════════════════════
///
/// Due tessere con contenuti diversi vengono **alte diverse**, e il colpo
/// d'occhio delle tavole — due rettangoli gemelli — si perde. ⚠️ È la stessa
/// lezione dell'«altezza identica» del carosello dello storico (3b-A.6.4): si
/// risolve una volta, qui, con `IntrinsicHeight` e `stretch`.
///
/// ⚠️ `IntrinsicHeight` costa un giro di misura in più: va bene per due
/// tessere, ⛔ non per una lista lunga.
class Coppia extends StatelessWidget {
  const Coppia({required this.sinistra, required this.destra, super.key});

  final Widget sinistra;

  final Widget destra;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: sinistra),
          const SizedBox(width: 10),
          Expanded(child: destra),
        ],
      ),
    );
  }
}
