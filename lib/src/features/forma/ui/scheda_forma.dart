import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../carica_batteria.dart';
import '../carica_controller.dart';
import '../forma_controller.dart';
import '../indici_di_forma.dart';
import 'barra_carico.dart';
import 'tachimetro_prontezza.dart';

/// La scheda di stanchezza e carica — FASE 2-sexies.
///
/// ── 🚨 L'avvertenza sta SOPRA i numeri ────────────────────────────────────
///
/// Decisione D-2s/B del committente, e la posizione non è un dettaglio: sotto la
/// leggerebbe chi ha già letto i numeri, cioè **troppo tardi**. ⚠️ È la stessa
/// regola già imparata sul consiglio del giorno (§49.4) — chi si è appena
/// allenato deve sapere **mentre** legge che quella è una stima.
class SchedaForma extends ConsumerWidget {
  const SchedaForma({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forma = ref.watch(formaProvider).valueOrNull;

    /*
     * ⚠️ Mentre carica **non si mostra niente**, e non è come il consiglio del
     * giorno: là la card che spariva era un difetto perché il testo c'era già e
     * si poteva ricordare. Qui non c'è niente da ricordare — il calcolo dura
     * un istante, e una scheda che lampeggia sarebbe peggio di una che compare.
     */
    if (forma == null) return const SizedBox.shrink();

    final tema = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,

      /*
       * 🚨 **Si tocca, e si vede che si tocca.**
       *
       * ⚠️ `InkWell` dentro la `Card` e non un `GestureDetector`: senza l'ondina
       * al tocco, una card che apre una pagina è indistinguibile da una che non
       * fa niente, e nessuno la prova due volte.
       */
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(AppRoutes.forma),
        child: Padding(
          padding: const EdgeInsets.all(Gap.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.battery_charging_full_rounded,
                    color: tema.colorScheme.primary,
                  ),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: Text(
                      'Carico e carica',
                      style: tema.textTheme.titleMedium,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: tema.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),

              const SizedBox(height: Gap.sm),
              const AvvertenzaStima(),

              /*
               * ══ 🆕 DUE SEZIONI, UNA SOTTO L'ALTRA — 3b-O.4, 21/08/2026 ═════
               *
               * 📌 Il committente: *«adesso è terribile […] non dovrebbero
               * essere solo numeri […] due sezioni, una sotto l'altra»*.
               *
               * ⚠️ Prima erano **due numeri affiancati**, e la disposizione
               * diceva una cosa falsa: che fossero **la stessa cosa misurata in
               * due modi**. Non lo sono. Il carico è un rapporto con la propria
               * settimana, la carica è uno stato di oggi — e affiancarli
               * invitava a confrontarli.
               *
               * 💡 Uno sotto l'altro, con **forme diverse**, si legge che sono
               * due domande diverse prima ancora di leggere le parole.
               */
              const SizedBox(height: Gap.md),
              _SezioneCarico(forma: forma),

              const Divider(height: Gap.lg),

              _SezioneProntezza(forma: forma),

              /*
               * ══ 🔋 E POI LA CARICA VERA — 3b-K, 28/08/2026 ═══════════════
               *
               * 📌 *«poi voglio che sotto ci metti una vera e propria "Carica"
               * con la batteria»*.
               *
               * 🚨 **Sono due domande diverse, e adesso hanno due forme
               * diverse.** La Prontezza è un tachimetro perché ha un centro —
               * il 50 è il proprio normale; la Carica è una batteria perché ha
               * un pieno e un vuoto, e si scarica davvero.
               *
               * ⛔ La card **non compare** se il TDEE non si sa: senza, non
               * esiste un metro per dire se un allenamento è stato grande o
               * piccolo *per questa persona*, e la batteria si muoverebbe a
               * caso. 💡 Il widget si nasconde da solo.
               */
              const _SezioneCarica(),
            ],
          ),
        ),
      ),
    );
  }

  /// 💡 Pubblica perché la usa `_SezioneCarico`: le frasi restano **le stesse
  /// di prima**, era la richiesta.
  static String fascia(FasciaCarico? f) => switch (f) {
    FasciaCarico.scarico => 'sotto il tuo solito',
    FasciaCarico.normale => 'nella tua norma',
    FasciaCarico.inSalita => 'in salita',
    FasciaCarico.alto => 'molto sopra il solito',
    null => '',
  };
}

class AvvertenzaStima extends StatelessWidget {
  const AvvertenzaStima({super.key});

  static const testo =
      'Stima calcolata dal telefono su sonno, battito, allenamenti e cibo. '
      'Non è una misura e non è un parere medico. '
      'È costruita sulle tue medie: non si confronta con quella di altri.';

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final colore = tema.colorScheme.onSurfaceVariant;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline_rounded, size: 14, color: colore),
        const SizedBox(width: Gap.xs),
        Expanded(
          child: Text(
            testo,
            style: tema.textTheme.labelSmall?.copyWith(
              color: colore,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

/// Il carico: una barra, non un numero — 3b-O.4.3.
class _SezioneCarico extends StatelessWidget {
  const _SezioneCarico({required this.forma});

  final Forma forma;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final v = forma.stanchezza.valore;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('Carico', style: tema.textTheme.labelMedium),
            const SizedBox(width: Gap.sm),
            Text(
              /*
               * 💡 L'ACWR è un rapporto: «142%» vuol dire «il 142% del tuo
               * carico abituale», che è letteralmente quello che è. ⚠️ Non si
               * inventa una scala: quella della carica sì, e infatti è
               * dichiarata.
               */
              v == null ? '—' : '${(v * 100).round()}%',
              style: tema.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: v == null
                    ? tema.colorScheme.outline
                    : tema.colorScheme.primary,
              ),
            ),
          ],
        ),

        const SizedBox(height: Gap.xs),

        BarraCarico(acwr: v),

        const SizedBox(height: Gap.xs),

        Text(
          v == null
              ? 'Serve almeno un allenamento negli ultimi 28 giorni.'
              : SchedaForma.fascia(forma.fascia),
          style: tema.textTheme.bodySmall,
        ),

        /*
         * 💡 La nota dice **quanti giorni mancano**, non «dati insufficienti»:
         * la prima è un'attesa che finisce, la seconda sembra un guasto.
         */
        if (v != null && !forma.stanchezza.eAttendibile)
          Text(
            'stima poco attendibile: mancano '
            '${forma.stanchezza.giorniCheMancano} giorni di dati',
            style: tema.textTheme.labelSmall?.copyWith(
              color: tema.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
      ],
    );
  }
}

/// La Prontezza: un tachimetro col 50 all'apice — 3b-K.
///
/// ══ ⛔ SI CHIAMAVA «CARICA», ED ERA UNA BATTERIA ══════════════════════════
///
/// 📌 *«a ben vedere non analizza la carica vera e propria, ma quanto sto bene o
/// male rispetto al solito, che è 50»*.
///
/// 🚨 **Una batteria al 50% dice «stai finendo»; questo 50 dice «sei nella tua
/// norma»** — cioè il posto migliore in cui stare. La forma diceva una cosa
/// diversa dal contenuto, ed è il tipo di errore che nessuno legge come tale.
class _SezioneProntezza extends StatelessWidget {
  const _SezioneProntezza({required this.forma});

  final Forma forma;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final v = forma.prontezza.valore;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        TachimetroProntezza(valore: v),

        const SizedBox(width: Gap.md),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Prontezza', style: tema.textTheme.labelMedium),
              Text(
                v == null
                    ? 'non calcolabile'
                    : 'come stai rispetto al tuo solito',
                style: tema.textTheme.bodySmall,
              ),

              const SizedBox(height: Gap.xs),

              /*
               * 🚨 **L'avvertenza sta ACCANTO al quadrante** — 3b-O.4.4.
               *
               * 📌 *«accanto le frasi necessarie per comunicare che non è un
               * parere medico eccetera»*.
               *
               * ⚠️ Si sposta dall'alto al fianco, e la regola di D-2s/B regge
               * lo stesso: quella diceva **sopra i numeri**, cioè *letta
               * insieme al numero, non dopo*. Qui il numero è dentro il
               * quadrante e l'avvertenza gli sta a fianco — si leggono nello
               * stesso colpo d'occhio, che era il punto.
               */
              Text(
                'Stima del telefono, non una misura e non un parere medico. '
                'È costruita sulle tue medie: non si confronta con quella di '
                'altri.',
                style: tema.textTheme.labelSmall?.copyWith(
                  color: tema.colorScheme.onSurfaceVariant,
                  height: 1.3,
                ),
              ),

              if (v != null && !forma.prontezza.eAttendibile)
                Text(
                  'stima poco attendibile: mancano '
                  '${forma.prontezza.giorniCheMancano} giorni di dati',
                  style: tema.textTheme.labelSmall?.copyWith(
                    color: tema.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}


/// 🔋 La Carica vera: quanto stress si può ancora sostenere — 3b-K.
///
/// ══ 🚨 QUI LA BATTERIA È LA FORMA GIUSTA ══════════════════════════════════
///
/// Perché questo numero **si scarica davvero**: parte da un pieno, cala con
/// l'attività, e la notte ne recupera una parte. ⚠️ E soprattutto **si
/// trascina**: la fatica che una notte non recupera si somma a quella del giorno
/// dopo. È l'unica cosa in tutta l'app che si comporta come una batteria.
///
/// ⛔ **Non compare se il TDEE non si sa.** Senza, non esiste un metro per dire
/// se un allenamento è stato grande o piccolo *per questa persona*: la batteria
/// si muoverebbe a caso. 💡 Meglio niente che un numero inventato.
class _SezioneCarica extends ConsumerWidget {
  const _SezioneCarica();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final carica = ref.watch(caricaProvider).valueOrNull;

    if (carica == null) return const SizedBox.shrink();

    final tema = Theme.of(context);

    return Column(
      children: [
        const Divider(height: Gap.lg),

        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            BatteriaCarica(livello: carica.adesso),

            const SizedBox(width: Gap.md),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Carica', style: tema.textTheme.labelMedium),

                  Text(
                    'quanto ti resta per allenarti',
                    style: tema.textTheme.bodySmall,
                  ),

                  const SizedBox(height: Gap.xs),

                  /*
                   * 💡 **«Stamattina eri a 86»**, e non solo il numero di
                   * adesso: la Carica cala durante la giornata, e senza il
                   * punto di partenza un 71 non si distingue da un 71 con cui
                   * ci si è svegliati.
                   *
                   * ⚠️ Solo se è **calata davvero**: scriverlo quando i due
                   * numeri coincidono sarebbe rumore.
                   */
                  if (carica.mattina - carica.adesso >= 1)
                    Text(
                      'stamattina eri a ${carica.mattina.round()}',
                      style: tema.textTheme.labelSmall?.copyWith(
                        color: tema.colorScheme.onSurfaceVariant,
                      ),
                    ),

                  const SizedBox(height: Gap.xs),

                  _Affidabilita(carica: carica),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Quanto ci si può fidare, e **cosa manca** — 3b-K.
///
/// 📌 *«impedisce di presentare un 86% del secondo giorno come se avesse la
/// stessa precisione di un 86% calcolato dopo sei mesi di storico»*.
///
/// 🚨 **Dice anche cosa manca**, non solo che la stima è debole: «manca il
/// sonno» è una cosa a cui si può rimediare, «poco affidabile» no.
class _Affidabilita extends StatelessWidget {
  const _Affidabilita({required this.carica});

  final Carica carica;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    final mancano = [
      if (carica.senzaAttivita) 'le calorie di oggi',
      if (carica.senzaSonno) 'il sonno di stanotte',
      if (carica.senzaFisiologia) 'battito e variabilità',
    ];

    final parola = switch (carica.affidabilita) {
      Affidabilita.bassa => 'bassa',
      Affidabilita.media => 'media',
      Affidabilita.alta => 'alta',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.speed_rounded,
              size: 13,
              color: tema.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: Gap.xs),
            Text(
              'Affidabilità $parola · ${carica.giorniValidi} giorni di dati',
              style: tema.textTheme.labelSmall?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),

        if (mancano.isNotEmpty)
          Text(
            'manca ${mancano.join(", ")}',
            style: tema.textTheme.labelSmall?.copyWith(
              color: tema.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
      ],
    );
  }
}
