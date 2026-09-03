/// Quello che si legge **prima** di cominciare a correggere — Parte K, K4.
///
/// ══ 🚨 IL RISCHIO CHE QUESTO WIDGET ESISTE PER RENDERE VISIBILE ═══════════
///
/// Il rischio dell'importazione non è che l'AI **fallisca**: un fallimento si
/// vede e si rifà. È che riesca **a metà**. «200 g» letti «20 g» non danno
/// nessun errore: producono un piano plausibile e sbagliato, che qualcuno
/// seguirà per settimane credendolo fedele all'originale.
///
/// ⚠️ **Quindi la revisione non è una conferma, è un lavoro** — e tutto qui
/// dentro serve a rendere il confronto più facile che la fiducia.
library;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/origine_della_bozza.dart';

class CappelloDellaRevisione extends StatelessWidget {
  const CappelloDellaRevisione({required this.origine, super.key});

  final OrigineDellaBozza origine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avvertenza = origine.avvertenza;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        /*
         * ⚠️ **L'avvertenza sulle fotografie, solo quando è una fotografia.**
         *
         * 📌 *«Per risultati ottimali, si consiglia di usare un documento in
         * PDF. L'analisi delle immagini è generalmente meno accurata»*.
         *
         * ⛔ Su un PDF sarebbe rumore: la revisione è obbligatoria comunque, e
         * un avviso che compare sempre si smette di leggere.
         */
        if (avvertenza != null)
          Card(
            color: theme.colorScheme.tertiaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(Gap.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.image_outlined,
                    color: theme.colorScheme.onTertiaryContainer,
                  ),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: Text(
                      avvertenza,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onTertiaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        /*
         * 💡 **Quello che c'era scritto intorno alle righe**, in chiaro.
         *
         * ⛔ Non nel riquadro rosso: su un documento vero qui dentro finiscono
         * la frequenza settimanale, la durata della seduta e le regole di
         * progressione — cose utili e per niente allarmanti. 🚨 Un avviso rosso
         * che compare sempre insegna a saltare gli avvisi rossi.
         */
        if (origine.note != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Gap.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sul documento c\'era scritto anche',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: Gap.xs),
                  Text(origine.note!, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ),

        /*
         * ══ 🚨 I DUBBI DEL MODELLO, IN CIMA E NON SEPOLTI ══════════════════
         *
         * Sono la parte **più utile** di tutta la risposta: portano chi controlla
         * dritto sulle righe che contano, invece di lasciarlo scorrere trenta
         * voci tutte uguali.
         *
         * ⛔ Metterli in fondo, o dietro un tocco, vorrebbe dire buttarli: la
         * revisione si stanca prima di arrivarci.
         */
        if (origine.dubbi.isNotEmpty)
          Card(
            color: theme.colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(Gap.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.help_outline,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: Gap.sm),
                      Text(
                        origine.dubbi.length == 1
                            ? 'Un punto da guardare'
                            : '${origine.dubbi.length} punti da guardare',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Gap.xs),
                  for (final dubbio in origine.dubbi)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '· $dubbio',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
