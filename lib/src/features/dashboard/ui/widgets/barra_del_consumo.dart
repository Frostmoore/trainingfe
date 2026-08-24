/// Quanto hai bruciato finora oggi — 3b-B.19, 25/08/2026.
///
/// ══ 📌 LA RICHIESTA ═══════════════════════════════════════════════════════
///
/// *«vorrei sotto un'altra barra dove mi dice le calorie bruciate. Deve
/// funzionare mappando l'ora del giorno al mio tdee. Di base, mi deve mettere le
/// calorie che ho bruciato perché sono vivo del colore d'accento, e le calorie
/// "attive" diciamo rosse (o comunque di un altro colore), ma nella stessa
/// barra»*.
library;

import 'package:flutter/material.dart';

/// Le calorie bruciate **solo per essere vivo**, da mezzanotte a adesso.
///
/// ══ 🚨 SI MAPPA IL BASALE, NON IL TDEE ════════════════════════════════════
///
/// ⛔ **Mappare il TDEE sull'ora conterebbe due volte il movimento.** Il TDEE è
/// `BMR × fattore di attività` (1.2 sedentario, 1.55 attivo…): dentro c'è già
/// una previsione di quanto ti muovi in un giorno normale. Sommargli sopra le
/// calorie attive **misurate** vorrebbe dire contare lo stesso movimento due
/// volte — una prevista e una vera.
///
/// 💡 Quindi: la parte «sono vivo» è il **BMR**, che è davvero ciò che si brucia
/// stando fermi, e le attive sono quelle vere. La loro somma è quanto hai
/// bruciato **davvero** finora. ⚠️ E il TDEE resta il **fondo** della barra: è
/// la previsione della giornata intera, quindi arrivarci vuol dire «ti sei
/// mosso quanto previsto», superarlo vuol dire «di più».
///
/// ══ 🚨 E LA FRAZIONE È SULLE 24 ORE, NON SULLA GIORNATA SVEGLIA ═══════════
///
/// ⛔ **Non si usa `dayProgressPct`**, che pure è lì nella stessa card e sembra
/// la stessa cosa. Quello conta dalle **6 alle 23**, perché serve al ritmo del
/// *mangiare*: alle 8 del mattino è passato il 12% della giornata in cui si
/// mangia, non il 33% delle ore.
///
/// 🚨 Per il basale sarebbe **sbagliato**: alle 6 del mattino `dayProgressPct` è
/// **0**, ma di calorie ne hai già bruciate sei ore — un quarto del basale della
/// giornata. La barra direbbe «zero» a chi si sveglia presto.
///
/// ⚠️ Sono due quantità diverse che si somigliano, ed è esattamente il tipo di
/// cosa che qualcuno un giorno «uniforma». Non sono la stessa cosa.
double basaleFinora({required double bmr, required DateTime adesso}) =>
    bmr * (adesso.hour * 60 + adesso.minute) / (24 * 60);

/// La barra: **una sola**, con dentro due colori.
///
/// 📌 *«ma nella stessa barra»*. 💡 Due barre separate direbbero due cose; una
/// barra con due colori dice **una cosa fatta di due parti**, che è quello che
/// il consumo è.
class BarraDelConsumo extends StatelessWidget {
  const BarraDelConsumo({
    required this.basale,
    required this.attive,
    required this.tdee,
    super.key,
  });

  /// Il basale **già mappato sull'ora**: vedi [basaleFinora].
  final double basale;

  /// Le calorie attive di oggi — dall'orologio, o dalla stima degli
  /// allenamenti. ⚠️ Sono quelle **sopra** il basale, quindi non lo ripetono.
  final double attive;

  /// Il fondo della barra: la previsione della giornata intera.
  final double tdee;

  /// 🚨 **Il colore del fuoco, ed è scritto a mano di proposito.**
  ///
  /// ⛔ Non si può usare `colorScheme.error` («rosso» a schermo ma vuol dire
  /// *guasto*, e qui non è successo niente di male: bruciare è la cosa buona) né
  /// il colore d'accento, che è **proprio l'altro segmento** — e la tavolozza
  /// degli accenti contiene un rosso, quindi con quello scelto i due pezzi
  /// diventerebbero indistinguibili.
  ///
  /// 💡 È lo stesso arancio che la card del recupero usa già per le calorie in
  /// questa stessa pagina: chi lo vede l'ha già visto voler dire «bruciate».
  static const fuoco = Color(0xFFE0603A);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, vincoli) {
        final larghezza = vincoli.maxWidth;

        /*
         * ⚠️ **Si taglia a fondo barra, e i numeri sotto dicono la verità.**
         * Superare il TDEE è normale — un giorno in cui ci si è mossi più del
         * previsto — e non è un errore da segnalare in rosso: sarebbe la
         * lettura opposta di quella giusta.
         */
        double fin(double kcal) =>
            tdee <= 0 ? 0 : (kcal / tdee).clamp(0.0, 1.0) * larghezza;

        final finBasale = fin(basale);
        final finTotale = fin(basale + attive);

        return ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 10,
            width: larghezza,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ColoredBox(
                    color: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: finBasale,
                  child: ColoredBox(color: theme.colorScheme.primary),
                ),
                // 💡 Parte **dove finisce il basale**: è quello che «nella
                // stessa barra» vuol dire — le attive si aggiungono, non si
                // sovrappongono.
                Positioned(
                  left: finBasale,
                  top: 0,
                  bottom: 0,
                  width: (finTotale - finBasale).clamp(0.0, larghezza),
                  child: const ColoredBox(color: fuoco),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// La legenda: due pallini e due numeri.
///
/// 🚨 **Senza, la barra è indecifrabile.** Due colori dentro una barra sola non
/// si spiegano da soli, e il numero grande sopra ne dice la somma: chi guarda
/// deve poter sapere quale pezzo è quale, o si inventa una risposta.
class LegendaDelConsumo extends StatelessWidget {
  const LegendaDelConsumo({
    required this.basale,
    required this.attive,
    super.key,
  });

  final double basale;
  final double attive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget voce(Color colore, String testo) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: colore, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(testo, style: theme.textTheme.bodySmall),
      ],
    );

    return Wrap(
      spacing: 12,
      runSpacing: 2,
      children: [
        voce(theme.colorScheme.primary, 'a riposo ${basale.round()}'),
        voce(BarraDelConsumo.fuoco, 'in movimento ${attive.round()}'),
      ],
    );
  }
}
