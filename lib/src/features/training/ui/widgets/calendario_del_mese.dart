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
    final forma = ref.watch(formaProvider);

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

/// I due numeri sopra il calendario — B.12, con le barre da B.13.
///
/// 📌 *«sulla parte superiore ci dovrebbe essere un valore percentuale che
/// indica la mia costanza … Inoltre, dovrebbe esserci un numero che mi dice
/// quanto sono allenato»* e poi, vedendoli a schermo: *«quanto sei allenato non
/// si capisce, 8 non significa un cazzo. O ci metti una barra … o ci metti
/// qualche termine di paragone»*.
///
/// ══ ⛔ UN NUMERO NUDO NON È UN'INFORMAZIONE ═══════════════════════════════
///
/// 🚨 Il numero era **giusto** e non diceva niente: senza una scala, «8» non
/// distingue «hai appena cominciato» da «sei un atleta». ⚠️ È il difetto del
/// dato che *sembra informato* visto dall'altro lato — qui l'informazione c'è
/// e **non arriva**.
///
/// ── ⚠️ Uno sotto l'altro, non affiancati ─────────────────────────────────
///
/// ⛔ Erano due colonne mezze e mezze: una barra larga metà schermo con sotto
/// una frase di paragone non ci sta, e a carattere grande andava a capo tre
/// volte. 💡 In colonna ognuna ha tutta la larghezza, che è quello che serve a
/// una barra per essere leggibile.
class _Testata extends StatelessWidget {
  const _Testata({required this.costanza, required this.forma});

  final Costanza costanza;
  final Forma forma;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _Misura(
        etichetta: 'Costanza',

        /*
         * ⛔ **Con meno di due settimane finite si scrive un trattino**, non
         * uno zero: «0%» direbbe che sei incostante, quando la verità è che non
         * si sa ancora. È la stessa regola del «0 km».
         */
        valore: costanza.siPuoDire ? '${costanza.percentuale}%' : '—',
        sotto: costanza.siPuoDire
            ? _comeVaLaCostanza(costanza)
            : 'ancora presto — servono due settimane finite',
        frazione: costanza.siPuoDire ? costanza.valore : null,
      ),

      const SizedBox(height: Gap.sm),

      _Misura(
        etichetta: 'Quanto sei allenato',
        valore: '${forma.valore}',
        sotto: _comeVaLaForma(forma),
        frazione: forma.frazione,
        fasce: FasciaDellaForma.values,
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

  /// ══ 💡 IL TERMINE DI PARAGONE ═══════════════════════════════════════════
  ///
  /// 🚨 **Quante sedute a settimana come le tue tengono questo valore**, non un
  /// aggettivo e basta. ⚠️ È calcolato **con le calorie delle tue sedute**: un
  /// paragone su una «seduta tipo» inventata direbbe a chi fa sedute da mille
  /// kcal che si allena il doppio di quanto si allena.
  ///
  /// ⛔ E se di calorie non ce ne sono, il paragone **non si fa**: resta la
  /// fascia, che è vera lo stesso.
  static String _comeVaLaForma(Forma f) {
    final sedute = f.seduteASettimana;

    if (sedute == null || sedute < 0.25) return f.fascia.etichetta;

    final quante = sedute < 1.75
        ? sedute.toStringAsFixed(1).replaceAll('.', ',')
        : sedute.round().toString();

    /*
     * ⚠️ **Il singolare vale solo per l'uno esatto.** In italiano «0,9 seduta»
     * non si dice: mezzo, 0,9 e 1,5 vogliono tutti il plurale. Visto a schermo
     * il 24/08 — scritto giusto in logica e sbagliato in italiano, che è un
     * difetto che nessun test di numeri prende.
     */
    final parola = quante == '1' ? 'seduta' : 'sedute';

    return '${f.fascia.etichetta} — come $quante $parola a settimana';
  }
}

/// Un'etichetta, un numero e una barra.
class _Misura extends StatelessWidget {
  const _Misura({
    required this.etichetta,
    required this.valore,
    required this.sotto,
    required this.frazione,
    this.fasce = const [],
  });

  final String etichetta;
  final String valore;
  final String sotto;

  /// Quanto è piena la barra, da 0 a 1. `null` = non si sa, e non si disegna.
  final double? frazione;

  /// Le fasce da segnare sulla barra, se ce ne sono.
  final List<FasciaDellaForma> fasce;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                etichetta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tema.textTheme.labelMedium?.copyWith(
                  color: tema.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Text(
              valore,
              style: tema.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: tema.colorScheme.primary,
                height: 1,
              ),
            ),
          ],
        ),

        const SizedBox(height: 4),

        if (frazione != null) _Barra(frazione: frazione!, fasce: fasce),

        const SizedBox(height: 2),

        Text(
          sotto,
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

/// La barra, con le tacche delle fasce quando ce ne sono.
///
/// ⚠️ **Le tacche stanno sulla barra, non sotto in una riga di parole.** Quattro
/// etichette («Poco allenato», «Costante», «Allenato», «Molto allenato») sotto
/// una barra larga trecento punti non ci starebbero mai, e a carattere grande
/// nemmeno la metà: il nome della fascia in cui sei sta **nella frase sotto**,
/// dove c'è spazio per scriverlo per intero.
class _Barra extends StatelessWidget {
  const _Barra({required this.frazione, required this.fasce});

  final double frazione;
  final List<FasciaDellaForma> fasce;

  static const _alta = 10.0;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return LayoutBuilder(
      builder: (context, vincoli) => SizedBox(
        height: _alta,
        child: Stack(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: tema.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const SizedBox(width: double.infinity, height: _alta),
            ),

            /*
             * ⚠️ **Un minimo visibile anche a zero.** Una barra vuota e una
             * barra che non c'è si somigliano troppo, e la seconda vuol dire
             * un'altra cosa — «non si sa».
             */
            FractionallySizedBox(
              widthFactor: frazione.clamp(0.03, 1.0),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: tema.colorScheme.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const SizedBox(height: _alta),
              ),
            ),

            /*
             * 💡 Le tacche: dove finisce ogni fascia. ⛔ L'ultima non si segna —
             * è il fondo della barra, e una tacca sul bordo sembra un difetto di
             * disegno invece che un'informazione.
             */
            for (final f in fasce)
              if (f.finoA < formaMassima)
                Positioned(
                  left: (vincoli.maxWidth * f.finoA / formaMassima) - 1,
                  child: Container(
                    width: 2,
                    height: _alta,
                    color: tema.colorScheme.surface.withValues(alpha: 0.85),
                  ),
                ),
          ],
        ),
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
