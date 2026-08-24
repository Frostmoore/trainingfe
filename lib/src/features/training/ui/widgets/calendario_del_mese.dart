/// Il calendario del mese, con un puntino per allenamento — 3b-A.7, 24/08/2026.
///
/// 📌 Il committente: *«sotto alla card uomo vitruviano ci deve essere un
/// semplice calendario mensile, con un puntino in ogni giorno in cui c'è stato
/// un allenamento»*.
///
/// ══ 💡 «SEMPLICE» È UNA SPECIFICA ═════════════════════════════════════════
///
/// ⛔ Niente selezione, niente navigazione propria, nessun tocco che apra
/// qualcosa: il mese lo decide la settimana scelta in cima, e questo calendario
/// **racconta**, non comanda. ⚠️ Due navigatori nella stessa schermata — le
/// frecce per settimana e un calendario che cambia mese — sarebbero due
/// comandi in conflitto per la stessa domanda.
///
/// 🚨 **Tocca comunque**: toccare un giorno con il puntino porta la settimana
/// scelta su quel giorno. Non è una seconda navigazione, è una **scorciatoia**
/// alla prima — e senza, un puntino visibile e non toccabile è una cosa che
/// tutti provano a premere.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../costanza.dart';
import '../../settimana_scelta.dart';
import '../../storico_unificato_controller.dart';

class CalendarioDelMese extends ConsumerWidget {
  const CalendarioDelMese({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final settimana = ref.watch(settimanaSceltaProvider);
    final mese = DateTime(settimana.year, settimana.month);

    final voci = ref.watch(storicoUnificatoProvider).valueOrNull ?? const [];

    /*
     * 💡 Un insieme di **giorni**, non di date: due allenamenti lo stesso
     * giorno fanno un puntino solo. ⚠️ `DateTime(y, m, d)` normalizza a
     * mezzanotte locale, che è quello che serve per confrontare.
     */
    final conAllenamento = <DateTime>{
      for (final v in voci)
        if (v.quando.year == mese.year && v.quando.month == mese.month)
          DateTime(v.quando.year, v.quando.month, v.quando.day),
    };

    if (conAllenamento.isEmpty) return const SizedBox.shrink();

    final giorniNelMese = DateTime(mese.year, mese.month + 1, 0).day;

    /*
     * 🚨 **Quante caselle vuote prima del primo giorno.** `weekday` va da 1
     * (lunedì) a 7 (domenica), e la settimana qui comincia di lunedì come
     * ovunque nell'app: il 1° del mese di mercoledì vuole due caselle vuote.
     */
    final vuotePrima = mese.weekday - 1;

    final oggi = DateTime.now();
    final oggiSecco = DateTime(oggi.year, oggi.month, oggi.day);

    final costanza = ref.watch(costanzaDelMeseProvider(mese));
    final forma = ref.watch(quantoSeiAllenatoProvider);

    return Card(
      /*
       * 📌 *«Il calendario dovrebbe essere in una card»* — B.12. ⚠️ Il margine
       * laterale è lo stesso delle card del carosello: due contenitori
       * incolonnati con margini diversi si vedono subito, ed è il genere di cosa
       * che nessuno sa dire cos'è ma sembra sbagliata.
       */
      margin: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, 0),
      child: Padding(
        padding: const EdgeInsets.all(Gap.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Testata(costanza: costanza, forma: forma),

            const Divider(height: Gap.md),

            Row(
              children: [
                for (final g in const ['L', 'M', 'M', 'G', 'V', 'S', 'D'])
                  Expanded(
                    child: Center(
                      child: Text(
                        g,
                        style: tema.textTheme.labelSmall?.copyWith(
                          color: tema.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 2),

            /*
           * ⚠️ **`shrinkWrap` e niente scorrimento**: il calendario vive dentro
           * la pagina dello storico, che scorre già. Una griglia che scorre
           * dentro una che scorre è il modo per non riuscire a scorrere né
           * l'una né l'altra.
           */
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),

              /*
             * ══ 🚨 LE CELLE SONO BASSE, NON QUADRATE ═══════════════════════
             *
             * ⛔ `GridView.count` fa celle **quadrate** di serie, e con sette
             * colonne su un telefono la cella è larga ottanta punti: sei righe
             * da ottanta sono **mezzo schermo** per un calendario che deve
             * essere «semplice». Visto a schermo il 24/08: il calendario
             * scacciava gli allenamenti sotto il bordo.
             *
             * ⚠️ E c'era un secondo danno, meno ovvio: con la cella alta, il
             * puntino finiva lontano dal suo numero e **sembrava appartenere
             * alla riga sotto**. Un dato giusto, letto sbagliato.
             *
             * 💡 Un'altezza fissa — numero, due punti di aria, puntino — e
             * scalata con il carattere, come le card dello storico.
             */
              mainAxisExtent: MediaQuery.textScalerOf(context).scale(34),
              children: [
                for (var i = 0; i < vuotePrima; i++) const SizedBox.shrink(),
                for (var g = 1; g <= giorniNelMese; g++)
                  _Giorno(
                    giorno: g,
                    allenato: conAllenamento.contains(
                      DateTime(mese.year, mese.month, g),
                    ),
                    eOggi: DateTime(mese.year, mese.month, g) == oggiSecco,
                    nellaSettimana: () {
                      final d = DateTime(mese.year, mese.month, g);

                      return lunediDi(d) == settimana;
                    }(),
                    onTap: () => ref
                        .read(settimanaSceltaProvider.notifier)
                        .vaiA(DateTime(mese.year, mese.month, g)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// I due numeri sopra il calendario — B.12.
///
/// 📌 *«sulla parte superiore ci dovrebbe essere un valore percentuale che
/// indica la mia costanza … Inoltre, dovrebbe esserci un numero che mi dice
/// quanto sono allenato»*.
///
/// ⚠️ **Due misure diverse, e la differenza va detta**: la costanza parla del
/// **mese che stai guardando**, la forma parla di **adesso** e guarda indietro
/// sei settimane. ⛔ Metterle vicine senza spiegarlo farebbe credere che siano
/// due facce dello stesso periodo — e navigando a marzo la seconda non
/// cambierebbe, che sembrerebbe un difetto.
class _Testata extends StatelessWidget {
  const _Testata({required this.costanza, required this.forma});

  final Costanza costanza;
  final int forma;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _Misura(
          etichetta: 'Costanza',
          valore: costanza.siPuoDire ? '${costanza.percentuale}%' : '—',

          /*
           * ⛔ **Con meno di due settimane finite si scrive un trattino**, non
           * uno zero: «0%» direbbe che sei incostante, quando la verità è che
           * non si sa ancora. È la stessa regola del «0 km».
           */
          sotto: costanza.siPuoDire
              ? _comeVaLaCostanza(costanza)
              : 'ancora presto per dirlo',
        ),
      ),

      const SizedBox(height: 34, child: VerticalDivider(width: Gap.md)),

      Expanded(
        child: _Misura(
          etichetta: 'Quanto sei allenato',
          valore: '$forma',
          sotto: 'ultime sei settimane',
        ),
      ),
    ],
  );

  /// 💡 La frase dice **quale dei tre pezzi** è il più debole, perché «61%» da
  /// solo non distingue «ti alleni poco» da «ti alleni a caso» — e sono due
  /// consigli opposti.
  static String _comeVaLaCostanza(Costanza c) {
    final peggiore = [
      (c.frequenza, 'ti alleni poco spesso'),
      (c.regolaritaNumero, 'settimane molto diverse fra loro'),
      (c.regolaritaGiorni, 'giorni sempre diversi'),
    ]..sort((a, b) => a.$1.compareTo(b.$1));

    if (peggiore.first.$1 >= 0.8) return 'molto regolare';

    return peggiore.first.$2;
  }
}

class _Misura extends StatelessWidget {
  const _Misura({
    required this.etichetta,
    required this.valore,
    required this.sotto,
  });

  final String etichetta;
  final String valore;
  final String sotto;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Column(
      children: [
        Text(
          etichetta,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: tema.textTheme.labelSmall?.copyWith(
            color: tema.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          valore,
          style: tema.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: tema.colorScheme.primary,
            height: 1.1,
          ),
        ),
        Text(
          sotto,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: tema.textTheme.labelSmall?.copyWith(
            color: tema.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _Giorno extends StatelessWidget {
  const _Giorno({
    required this.giorno,
    required this.allenato,
    required this.eOggi,
    required this.nellaSettimana,
    required this.onTap,
  });

  final int giorno;
  final bool allenato;
  final bool eOggi;

  /// Se il giorno cade nella settimana che la pagina sta mostrando.
  ///
  /// 💡 Serve a legare le due cose: senza, il calendario e la griglia sotto
  /// sembrerebbero due schermate accostate invece che una sola.
  final bool nellaSettimana;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return InkWell(
      // ⛔ Solo i giorni con un allenamento rispondono: toccare un giorno vuoto
      // porterebbe a una settimana vuota, cioè a un gesto che sembra rotto.
      onTap: allenato ? onTap : null,
      borderRadius: BorderRadius.circular(Gap.radiusSm),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: nellaSettimana
              ? tema.colorScheme.primaryContainer.withValues(alpha: 0.45)
              : null,
          borderRadius: BorderRadius.circular(Gap.radiusSm),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$giorno',
              style: tema.textTheme.bodySmall?.copyWith(
                fontWeight: eOggi ? FontWeight.w800 : FontWeight.w400,
                color: eOggi
                    ? tema.colorScheme.primary
                    : tema.colorScheme.onSurface,
              ),
            ),

            const SizedBox(height: 2),

            /*
             * 🚨 **Il puntino c'è o non c'è.** Uno spazio riservato sempre —
             * puntino trasparente quando non serve — terrebbe le righe alte
             * uguali, ma un cerchio invisibile è comunque un cerchio: su schermi
             * densi si intravede. Qui lo spazio lo tiene il `SizedBox`.
             */
            SizedBox(
              height: 6,
              width: 6,
              child: allenato
                  ? DecoratedBox(
                      decoration: BoxDecoration(
                        color: tema.colorScheme.error,
                        shape: BoxShape.circle,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
