import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/ui/aggiornamento.dart';
import '../forma_controller.dart';
import '../indici_di_forma.dart';
import 'scheda_forma.dart';

/// Il dettaglio dei due indici — FASE 2-sexies, richiesta del 20/08/2026.
///
/// *«quando clicco sulla card carico e carica, mi deve aprire una pagina in cui
/// mi mostri i dettagli di entrambi i calcoli, con due card in fondo con la
/// formula e come funziona il calcolo»*.
///
/// ══ 🚨 PERCHÉ QUESTA SCHERMATA È PARTE DELLA CONFORMITÀ, NON UN EXTRA ══════
///
/// `indici_di_forma.dart` dice che *«un numero fa più danni di una frase, perché
/// suona misurato»*. La scheda in dashboard porta l'avvertenza, ma un'avvertenza
/// è una **dichiarazione**: dice che è una stima e chiede di crederci.
///
/// ⚠️ Qui invece si mostrano **gli ingredienti con i numeri veri**, e la
/// differenza è sostanziale: chi legge «sonno 5h12 contro una tua media di 7h05»
/// può accorgersi che quella media è sbagliata perché il telefono ha perso tre
/// notti — cioè può **non essere d'accordo** con l'indice. 🚨 Su un numero che
/// parla della sua stanchezza ne ha diritto, e senza questa pagina non ce l'ha.
///
/// 💡 È anche la ragione per cui le due card finali scrivono le formule per
/// esteso invece di rimandare a «un algoritmo»: la scala `0–100` è **nostra**, e
/// una scala inventata che non si può ispezionare è indistinguibile da una
/// misura vera.
class SchermataForma extends ConsumerWidget {
  const SchermataForma({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stato = ref.watch(formaProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Carico e carica')),
      body: RefreshIndicator(
        onRefresh: () =>
            aggiornaTutto(context, ref, () => ref.invalidate(formaProvider)),
        child: ListView(
          padding: const EdgeInsets.all(Gap.md),
          children: [
            const AvvertenzaStima(),
            const SizedBox(height: Gap.lg),

            ...switch (stato) {
              AsyncData(:final value) => _contenuto(context, value),

              /*
               * ⚠️ L'errore si dice, non si nasconde: qui — a differenza della
               * scheda in dashboard, che sparisce in silenzio — la persona ci è
               * arrivata **apposta**, e una pagina vuota senza spiegazione
               * sembra un guasto dell'app.
               */
              AsyncError() => [
                const _Vuoto(
                  'Il calcolo non è riuscito. Prova a tirare giù '
                  'per aggiornare.',
                ),
              ],
              _ => const [
                Padding(
                  padding: EdgeInsets.symmetric(vertical: Gap.xl),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
            },

            const SizedBox(height: Gap.lg),
            const _CardFormula(),
            const SizedBox(height: Gap.md),
            const _CardComeFunziona(),
            const SizedBox(height: Gap.xl),
          ],
        ),
      ),
    );
  }

  static List<Widget> _contenuto(BuildContext context, Forma forma) => [
    _Carico(forma: forma),
    const SizedBox(height: Gap.lg),
    _Carica(forma: forma),
  ];
}

// ══════════════════════════════════════════════════════════════════════════
// Il carico
// ══════════════════════════════════════════════════════════════════════════

class _Carico extends StatelessWidget {
  const _Carico({required this.forma});

  final Forma forma;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final valore = forma.stanchezza.valore;

    return _Sezione(
      icona: Icons.trending_up_rounded,
      titolo: 'Carico',
      grande: valore == null ? '—' : '${(valore * 100).round()}%',
      sotto: valore == null
          ? 'non calcolabile'
          : 'del tuo carico abituale — ${_fascia(forma.fascia)}',
      indice: forma.stanchezza,
      figli: [
        if (valore == null)
          const _Vuoto(
            'Serve almeno un allenamento negli ultimi 28 giorni: senza, il '
            'confronto sarebbe una divisione per zero.',
          )
        else ...[
          _Riga(
            nome: 'Ultimi ${IndiciDiForma.giorniAcuti} giorni',
            valore: '${forma.acuto.round()} kcal',
            nota: 'quanto ti sei caricato di recente',
          ),
          _Riga(
            nome: 'Ultimi ${IndiciDiForma.giorniCronici} giorni',
            valore: '${forma.cronico.round()} kcal',
            nota: 'il tuo normale',
          ),

          /*
           * 💡 Il grafico non è decorazione: due medie da sole non si possono
           * verificare. ⚠️ Chi vede una barra sola in ventotto giorni capisce
           * da sé perché la percentuale è enorme — con i soli numeri sopra
           * penserebbe a un errore dell'app.
           */
          const SizedBox(height: Gap.md),
          _Barre(giorni: forma.caricoPerGiorno),
          const SizedBox(height: Gap.sm),

          Text(
            'Ogni barra è un giorno, dal più vecchio a oggi. '
            'Le calorie sono quelle attive, quelle dell\'allenamento.',
            style: tema.textTheme.labelSmall?.copyWith(
              color: tema.colorScheme.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: Gap.md),
          const _Fasce(),
        ],
      ],
    );
  }

  static String _fascia(FasciaCarico? f) => switch (f) {
    FasciaCarico.scarico => 'sotto il tuo solito',
    FasciaCarico.normale => 'nella tua norma',
    FasciaCarico.inSalita => 'in salita',
    FasciaCarico.alto => 'molto sopra il solito',
    null => '',
  };
}

/// Le barre del carico giorno per giorno.
class _Barre extends StatelessWidget {
  const _Barre({required this.giorni});

  final List<double> giorni;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    // ⚠️ Il massimo può essere zero (tutti giorni di riposo): dividerci
    // darebbe `NaN`, e `NaN` in un'altezza fa esplodere il layout.
    final massimo = giorni.isEmpty
        ? 0.0
        : giorni.reduce((a, b) => a > b ? a : b);

    if (massimo <= 0) return const SizedBox.shrink();

    return SizedBox(
      height: 56,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < giorni.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Container(
                  // 💡 Minimo 2px: un giorno di riposo deve **vedersi** come
                  // riga vuota, non sparire come se il dato mancasse.
                  height: 2 + (giorni[i] / massimo) * 54,
                  decoration: BoxDecoration(
                    color: giorni[i] > 0
                        ? tema.colorScheme.primary
                        : tema.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Le fasce dell'`ACWR`, scritte per intero.
class _Fasce extends StatelessWidget {
  const _Fasce();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    const fasce = [
      ('sotto 80%', 'stai facendo meno del tuo solito'),
      ('80–130%', 'la zona in cui si sta bene'),
      ('130–150%', 'in salita: occhio a salire ancora'),
      ('oltre 150%', 'molto sopra il solito'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (soglia, cosa) in fasce)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 78,
                  child: Text(
                    soglia,
                    style: tema.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(child: Text(cosa, style: tema.textTheme.labelSmall)),
              ],
            ),
          ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// La carica
// ══════════════════════════════════════════════════════════════════════════

class _Carica extends StatelessWidget {
  const _Carica({required this.forma});

  final Forma forma;

  @override
  Widget build(BuildContext context) {
    final valore = forma.carica.valore;
    final ci = forma.ingredienti.where((i) => i.ceLo).length;

    return _Sezione(
      icona: Icons.battery_charging_full_rounded,
      titolo: 'Carica',
      grande: valore == null ? '—' : valore.round().toString(),
      sotto: valore == null ? 'non calcolabile' : 'su 100',
      indice: forma.carica,
      figli: [
        /*
         * ══ 🚨 SI DICE SU QUANTI INGREDIENTI È FATTA ═════════════════════════
         *
         * ⚠️ **Era un debito dichiarato** (§52.7): senza rete il cibo manca e il
         * numero veniva calcolato su tre pezzi su quattro **senza dirlo**. Un
         * indice che cambia formula in silenzio è peggio di un indice assente,
         * perché chi guarda due giorni di fila crede di confrontare la stessa
         * cosa.
         *
         * 💡 Qui il debito si chiude: la riga sotto lo dichiara sempre, e la
         * tabella qui in fondo mostra **quale** pezzo manca.
         */
        if (valore != null)
          _Nota('Calcolata su $ci ingredienti su ${forma.ingredienti.length}.'),

        const SizedBox(height: Gap.sm),

        for (final i in forma.ingredienti) _Ingrediente(pezzo: i),

        if (valore == null)
          const _Vuoto(
            'Serve almeno un dato fra sonno, variabilità cardiaca e battito a '
            'riposo, con due giorni di storia per avere una media con cui '
            'confrontarlo.',
          ),
      ],
    );
  }
}

/// Una riga di ingrediente: **quanto vale oggi, la tua media, e quanto conta**.
class _Ingrediente extends StatelessWidget {
  const _Ingrediente({required this.pezzo});

  final IngredienteCarica pezzo;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final z = pezzo.z;

    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  pezzo.nome,
                  style: tema.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                z == null ? 'non disponibile' : _scarto(z),
                style: tema.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: z == null
                      ? tema.colorScheme.outline
                      : _colore(tema, z),
                ),
              ),
            ],
          ),

          Text(
            _dettaglio(),
            style: tema.textTheme.labelSmall?.copyWith(
              color: tema.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// 💡 Si scrive `−1.7 dalla tua media`, non `z = −1.7`: la lettera greca non
  /// aggiunge niente a chi legge, e a chi vuole la formula c'è la card in fondo.
  static String _scarto(double z) =>
      '${z >= 0 ? '+' : '−'}${z.abs().toStringAsFixed(1)}';

  /// 🚨 Il colore segue **l'effetto sulla carica**, non il segno del numero: sul
  /// battito a riposo un `+1.2` è un peggioramento, e colorarlo di verde sarebbe
  /// esattamente l'errore di segno contro cui `IndiciDiForma` mette in guardia.
  Color _colore(ThemeData tema, double z) {
    var effetto = pezzo.invertito ? -z : z;
    if (pezzo.soloInNegativo && effetto > 0) effetto = 0;

    if (effetto.abs() < IndiciDiForma.zNormale) {
      return tema.colorScheme.onSurface;
    }

    return effetto > 0 ? Colors.green.shade700 : tema.colorScheme.error;
  }

  String _dettaglio() {
    final pesa = 'pesa ${pezzo.peso.toStringAsFixed(1)}';

    final versi = [
      if (pezzo.invertito) 'più basso è meglio',
      if (pezzo.soloInNegativo) 'conta solo se sei sotto',
    ];

    final coda = [pesa, ...versi].join(' · ');

    if (pezzo.oggi == null) {
      return 'nessun dato — $coda';
    }

    final oggi = '${pezzo.oggi!.round()} ${pezzo.unita}';

    if (pezzo.media == null) {
      return 'oggi $oggi · non c\'è ancora una tua media — $coda';
    }

    return 'oggi $oggi · tua media ${pezzo.media!.round()} ${pezzo.unita} '
        '— $coda';
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Le due card in fondo — richiesta esplicita del committente
// ══════════════════════════════════════════════════════════════════════════

/// 🚨 **La formula, scritta com'è davvero.**
///
/// ⚠️ Non è una versione semplificata «per far capire»: i numeri qui sotto sono
/// gli stessi che stanno in `IndiciDiForma`, costanti comprese. Una formula
/// arrotondata in interfaccia sarebbe una **seconda formula**, e fra le due chi
/// legge non ha modo di sapere quale sta guardando.
class _CardFormula extends StatelessWidget {
  const _CardFormula();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return _CardTesto(
      icona: Icons.functions_rounded,
      titolo: 'La formula',
      figli: [
        const _Formula(
          'carico = media(ultimi ${IndiciDiForma.giorniAcuti} giorni)\n'
          '         ÷ media(ultimi ${IndiciDiForma.giorniCronici} giorni)',
        ),
        const _Testo(
          'Le medie sono **esponenziali**: i giorni vicini pesano più di quelli '
          'lontani, perché è così che funziona la fatica. Il fattore è '
          'α = 2 ÷ (giorni + 1).',
        ),
        const SizedBox(height: Gap.md),

        _Formula(
          'scarto = (valore di oggi − tua media) ÷ deviazione standard\n\n'
          'carica = ${IndiciDiForma.zAlCentro.round()} + '
          '${IndiciDiForma.zQuantoPesa.round()} × media pesata degli scarti',
        ),
        const _Testo(
          'I pesi: sonno ${IndiciDiForma.pesoDelSonno}, '
          'variabilità cardiaca ${IndiciDiForma.pesoDellHrv}, '
          'battito a riposo ${IndiciDiForma.pesoDelBattito} '
          '(col segno invertito), cibo ${IndiciDiForma.pesoDelCibo} '
          '(solo quando sei sotto la tua media). '
          'Il risultato si taglia fra 0 e 100.',
        ),

        const SizedBox(height: Gap.sm),
        Text(
          'Gli ingredienti che mancano escono dalla media: la formula non li '
          'sostituisce con uno zero, perché «dato mancante» e «perfettamente '
          'nella media» non sono la stessa cosa.',
          style: tema.textTheme.bodySmall?.copyWith(
            color: tema.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// ⚠️ **Questa card dice soprattutto cosa i due numeri NON sono.**
///
/// 🚨 È il contenuto che `indici_di_forma.dart` impone all'interfaccia: che il
/// carico **non è misurato dal cuore** ma stimato dalle calorie, che la scala
/// `0–100` è nostra, che il pezzo del cibo non ha nessuno studio dietro, e che
/// fra due persone diverse questi numeri non si confrontano.
///
/// 💡 Sta in fondo e non in cima di proposito: in cima c'è l'avvertenza corta,
/// che si legge sempre. Questa è per chi è arrivato fin qui, e può essere lunga.
class _CardComeFunziona extends StatelessWidget {
  const _CardComeFunziona();

  @override
  Widget build(BuildContext context) {
    return const _CardTesto(
      icona: Icons.help_outline_rounded,
      titolo: 'Come funziona il calcolo',
      figli: [
        _Titoletto('Il carico confronta te con te stesso'),
        _Testo(
          'Non c\'è un valore «giusto» uguale per tutti: si guarda quanto ti sei '
          'allenato nell\'ultima settimana rispetto a quanto ti alleni di solito. '
          'Il 100% vuol dire «come al tuo solito», non «al massimo».',
        ),

        _Titoletto('Il carico è stimato dalle calorie, non dal cuore'),
        _Testo(
          'Il metodo di riferimento vorrebbe la frequenza cardiaca durante '
          'l\'allenamento, che non abbiamo. Usiamo le calorie attive, che sono '
          'una buona approssimazione ma restano un\'approssimazione: due '
          'allenamenti con le stesse calorie possono affaticare in modo diverso.',
        ),

        _Titoletto('La scala da 0 a 100 della carica è nostra'),
        _Testo(
          'Il confronto con la tua media ha una letteratura dietro; il modo di '
          'trasformarlo in un numero su cento no, l\'abbiamo scelto noi. '
          'L\'ordine è onesto — più alto vuol dire davvero meglio — ma i numeri '
          'in mezzo sono una scelta di presentazione.',
        ),

        _Titoletto('Il cibo pesa poco, e apposta'),
        _Testo(
          'Non esiste una formula pubblicata che leghi il mangiare poco al '
          'recupero. Abbiamo scelto che mangiare tanto non alzi la carica, '
          'mentre mangiare molto meno del tuo solito la abbassi un po\'.',
        ),

        _Titoletto('Servono giorni per essere precisi'),
        _Testo(
          'Il numero compare da subito, ma finché mancano dati te lo diciamo '
          'sotto. Con poche notti registrate la «tua media» è fatta di poche '
          'notti, e basta una notte storta a spostarla.',
        ),

        _Titoletto('Non si confronta con quella di altri'),
        _Testo(
          'Sono numeri costruiti sulle tue medie: il 60 tuo e il 60 di un\'altra '
          'persona non vogliono dire la stessa cosa. E se il numero dice una cosa '
          'e tu ti senti diversamente, hai ragione tu.',
        ),

        _Titoletto('Restano sul tuo telefono'),
        _Testo(
          'Il calcolo lo fa il telefono, i due numeri non li mandiamo a nessuno '
          'e non finiscono nemmeno nel consiglio del giorno. Non li salviamo '
          'da nessuna parte: si rifanno ogni volta che apri questa pagina.',
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// I mattoncini
// ══════════════════════════════════════════════════════════════════════════

class _Sezione extends StatelessWidget {
  const _Sezione({
    required this.icona,
    required this.titolo,
    required this.grande,
    required this.sotto,
    required this.indice,
    required this.figli,
  });

  final IconData icona;
  final String titolo;
  final String grande;
  final String sotto;
  final Indice indice;
  final List<Widget> figli;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icona, color: tema.colorScheme.primary, size: 20),
                const SizedBox(width: Gap.sm),
                Text(titolo, style: tema.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: Gap.sm),

            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  grande,
                  style: tema.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: indice.esiste
                        ? tema.colorScheme.primary
                        : tema.colorScheme.outline,
                  ),
                ),
                const SizedBox(width: Gap.sm),
                Expanded(child: Text(sotto, style: tema.textTheme.bodySmall)),
              ],
            ),

            // 💡 Stessa nota della scheda in dashboard, stesse parole: chi ha
            // cliccato sulla card ha letto «mancano 12 giorni» e deve ritrovare
            // la stessa frase, non una sua variante.
            if (indice.esiste && !indice.eAttendibile)
              Padding(
                padding: const EdgeInsets.only(top: Gap.xs),
                child: Text(
                  'stima poco attendibile: mancano '
                  '${indice.giorniCheMancano} giorni di dati',
                  style: tema.textTheme.labelSmall?.copyWith(
                    color: tema.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),

            const SizedBox(height: Gap.md),
            const Divider(height: 1),
            const SizedBox(height: Gap.md),

            ...figli,
          ],
        ),
      ),
    );
  }
}

class _Riga extends StatelessWidget {
  const _Riga({required this.nome, required this.valore, required this.nota});

  final String nome;
  final String valore;
  final String nota;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nome, style: tema.textTheme.bodyMedium),
                Text(
                  nota,
                  style: tema.textTheme.labelSmall?.copyWith(
                    color: tema.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            valore,
            style: tema.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Nota extends StatelessWidget {
  const _Nota(this.testo);

  final String testo;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Text(
      testo,
      style: tema.textTheme.labelSmall?.copyWith(
        color: tema.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _Vuoto extends StatelessWidget {
  const _Vuoto(this.testo);

  final String testo;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Text(
      testo,
      style: tema.textTheme.bodySmall?.copyWith(
        color: tema.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _CardTesto extends StatelessWidget {
  const _CardTesto({
    required this.icona,
    required this.titolo,
    required this.figli,
  });

  final IconData icona;
  final String titolo;
  final List<Widget> figli;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      color: tema.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icona, size: 18, color: tema.colorScheme.onSurfaceVariant),
                const SizedBox(width: Gap.sm),
                Text(titolo, style: tema.textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: Gap.sm),
            ...figli,
          ],
        ),
      ),
    );
  }
}

class _Titoletto extends StatelessWidget {
  const _Titoletto(this.testo);

  final String testo;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: Gap.sm, bottom: 2),
      child: Text(
        testo,
        style: tema.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _Testo extends StatelessWidget {
  const _Testo(this.testo);

  final String testo;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Text(
      // ⚠️ Gli asterischi si tolgono qui: `Text` non è markdown, e lasciarli
      // stampati sarebbe peggio del grassetto mancante.
      testo.replaceAll('**', ''),
      style: tema.textTheme.bodySmall?.copyWith(height: 1.35),
    );
  }
}

/// La formula in **monospaziato**: non è vezzo grafico.
///
/// 💡 Una formula in proporzionale si legge come una frase e si perde
/// l'allineamento fra numeratore e denominatore, che è metà del significato.
class _Formula extends StatelessWidget {
  const _Formula(this.testo);

  final String testo;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: Gap.sm),
      padding: const EdgeInsets.all(Gap.sm),
      decoration: BoxDecoration(
        color: tema.colorScheme.surface,
        borderRadius: BorderRadius.circular(Gap.radiusSm),
      ),
      child: Text(
        testo,
        style: tema.textTheme.labelSmall?.copyWith(
          fontFamily: 'monospace',
          height: 1.5,
        ),
      ),
    );
  }
}
