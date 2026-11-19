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
/// ══ 🔄 È UNA `Card`, DAL 19/11/2026 (I3) ═════════════════════════════════
///
/// ⛔ In I1 era bianca e piatta, come nelle tavole. Ma accanto alle card
/// vecchie — peso, grafico, calorie, grigie e con l'ombra — sulla stessa
/// pagina di Oggi sembrava un pezzo di un'altra app (visto sull'emulatore).
///
/// 🚨 **E l'ombra delle card è una richiesta del committente**, non un caso:
/// 21/08/2026, *«una lieve ombreggiatura […] tutta l'interfaccia deve essere
/// modernizzata»* — scritta in `AppTheme.cardTheme`. Una regola scritta batte
/// un disegno (`plan_interfaccia.md` R1/R2): quindi è la tessera che si adegua
/// alle card, prendendone colore, ombra e raggio dal tema, in un posto solo.
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

  /// `null` = il colore delle card del tema.
  final Color? colore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final contenuto = Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          /*
           * 🔠 **L'etichetta rimpicciolisce, non si spezza** — I9, 19/11/2026.
           *
           * ⛔ Col carattere del telefono ingrandito, in mezza larghezza
           * «ABBONAMENTO» andava a capo **a metà parola** («ABBONAMENT» / «O»).
           * 💡 È un'etichetta di una o due parole: rimpicciolita resta
           * leggibile, spezzata no. ⚠️ `scaleDown` non la ingrandisce mai:
           * col carattere normale è identica a prima.
           */
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              etichetta.toUpperCase(),
              maxLines: 1,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: Gap.sm),
          child,
        ],
      ),
    );

    // 💡 `Card` senza parametri di forma: colore, ombra e raggio li decide
    // `cardTheme`, e se un giorno cambiano lì cambiano anche qui.
    return Card(
      color: colore,
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? contenuto
          : InkWell(onTap: onTap, child: contenuto),
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
