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

    return Padding(
      // ⚠️ Un po' d'aria sopra: attaccato al carosello sembrava la sua coda.
      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
