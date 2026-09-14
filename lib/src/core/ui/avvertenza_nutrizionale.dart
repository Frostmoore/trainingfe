import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// «Questa è una stima, non un consiglio medico» — N17.
///
/// ── 🚨 Perché esiste, detto per intero ─────────────────────────────────────
///
/// In Italia **l'elaborazione di una dieta è un atto sanitario riservato**: la
/// possono fare medici, biologi nutrizionisti e dietisti. Un numero che dice
/// «devi mangiare 1.850 kcal» somiglia a una prescrizione anche quando nasce da
/// una formula di sessant'anni fa applicata a quattro dati anagrafici.
///
/// ⚠️ **Non basta una riga nei termini d'uso.** Un avviso letto una volta
/// all'iscrizione non protegge nessuno — né la persona, che quel numero lo
/// guarda ogni giorno, né noi. Va **accanto al numero**, ogni volta che il
/// numero si vede.
///
/// ── 💡 Dice tre cose, e servono tutte e tre ────────────────────────────────
///
/// 1. **cos'è** — una stima da formule generiche, non una misura;
/// 2. **cosa non è** — un consiglio medico;
/// 3. **a chi rivolgersi** — perché un avviso che dice solo «non fidarti» lascia
///    la persona esattamente dov'era.
///
/// 🚨 **Il testo vive qui e in nessun altro posto.** Ripetuto a mano in sei
/// schermate, fra un anno sarebbero sei testi diversi — e quello che conta
/// legalmente è il più debole dei sei.
class AvvertenzaNutrizionale extends StatelessWidget {
  const AvvertenzaNutrizionale({
    this.compatta = false,
    this.perIlPiano = false,
    super.key,
  });

  /// La forma corta, per starci sotto un numero senza rubargli la scena.
  ///
  /// ⚠️ Corta, **non** ammorbidita: dice comunque «stima» e «non è un consiglio
  /// medico». È la lunghezza a cambiare, non il contenuto.
  final bool compatta;

  /// ══ 🆕 QUANDO NON C'È NESSUN NUMERO — 14/09/2026 ═════════════════════════
  ///
  /// ⛔ **Su `/diario/importa-piano` questo riquadro diceva «Questo numero è
  /// una stima»**, e su quella schermata **non c'è nessun numero**: c'è un PDF
  /// da caricare. Trovato guardando la schermata, non leggendo il codice — dal
  /// codice sembrava giusto, perché il widget è giusto: è il posto che è
  /// diverso.
  ///
  /// 🚨 **L'avvertenza lì serve eccome**, ed è il motivo per cui non si toglie:
  /// importare una dieta è il momento in cui la responsabilità di chi l'ha
  /// scritta va detta per intero. ⚠️ Ma un avviso che comincia parlando di una
  /// cosa che non c'è è un avviso che si salta.
  ///
  /// 💡 Dice le stesse tre cose — cos'è, cosa non è, a chi rivolgersi —
  /// partendo dal piano invece che dal numero.
  final bool perIlPiano;

  static const String testoBreve =
      'Stima da formule generiche. Non è un consiglio medico.';

  static const String testoPerEsteso =
      'Questo numero è una stima, calcolata con formule generiche a partire da '
      'età, sesso, altezza, peso e attività dichiarata. Non è una misura del '
      'tuo metabolismo e non è un consiglio medico.\n\n'
      'Per un fabbisogno calcolato davvero su di te, e per un piano alimentare, '
      'rivolgiti a un biologo nutrizionista, a un dietista o al tuo medico: '
      'sono le figure abilitate a farlo.';

  /// Lo stesso avviso, dove si importa un piano invece di leggere un numero.
  static const String testoPerIlPiano =
      'Questo piano non lo elabora l\'app: lo ricopia e basta, e resta '
      'responsabilità di chi te l\'ha scritto. Quello che l\'app calcola da '
      'sola sono stime da formule generiche, e non sono un consiglio medico.\n\n'
      'Per un piano alimentare, o per un fabbisogno calcolato davvero su di te, '
      'rivolgiti a un biologo nutrizionista, a un dietista o al tuo medico: '
      'sono le figure abilitate a farlo.';

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final testo = perIlPiano ? testoPerIlPiano : testoPerEsteso;

    if (compatta) {
      return InkWell(
        onTap: () => mostra(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 14,
                color: tema.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  testoBreve,
                  style: tema.textTheme.labelSmall?.copyWith(
                    color: tema.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      color: tema.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: tema.colorScheme.onSurfaceVariant),
            const SizedBox(width: Gap.sm),
            Expanded(child: Text(testo, style: tema.textTheme.bodySmall)),
          ],
        ),
      ),
    );
  }

  /// Il testo per esteso, per chi tocca la forma corta.
  static void mostra(BuildContext context) => showDialog<void>(
    context: context,
    builder: (dialogo) => AlertDialog(
      icon: const Icon(Icons.info_outline),
      title: const Text('Come nasce questo numero'),
      content: const Text(testoPerEsteso),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogo).pop(),
          child: const Text('Ho capito'),
        ),
      ],
    ),
  );
}
