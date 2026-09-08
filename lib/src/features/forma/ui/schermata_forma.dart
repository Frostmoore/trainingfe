import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/ui/aggiornamento.dart';
import '../../../core/ui/intestazione_app.dart';
import '../carica_batteria.dart';
import '../carica_controller.dart';
import '../forma_controller.dart';
import '../indice_di_effetto.dart';
import '../indice_di_effetto_controller.dart';
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
      appBar: const IntestazioneApp(titolo: 'Carico e carica'),
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
    _Prontezza(forma: forma),

    /*
     * 🔋 **La terza card** — 28/08/2026: *«mettine anche una con i dettagli di
     * Carica»*.
     *
     * ⚠️ Sta **fuori** da `_contenuto(forma)` come widget suo perché la Carica
     * non viene da `formaProvider`: ha un provider proprio, e legarla a questo
     * vorrebbe dire non mostrarla quando l'altro fallisce. 💡 Sono due calcoli
     * indipendenti e devono poter fallire separatamente.
     */
    /*
     * 🏃 **L'Effetto** — 08/09/2026.
     *
     * ⛔ **Era comparso nella card di «Oggi» senza una riga qui**, e questa è la
     * pagina che promette di spiegare come si calcola tutto. 🚨 Un indice
     * visibile e non spiegato è peggio di un indice assente: chi lo guarda si
     * costruisce una teoria sua, e quella non si può correggere.
     */
    const SizedBox(height: Gap.lg),
    const _Effetto(),

    /*
     * 🔋 **La terza card** — 28/08/2026: *«mettine anche una con i dettagli di
     * Carica»*.
     *
     * ⚠️ Sta **fuori** da `_contenuto(forma)` come widget suo perché la Carica
     * non viene da `formaProvider`: ha un provider proprio, e legarla a questo
     * vorrebbe dire non mostrarla quando l'altro fallisce.
     */
    const SizedBox(height: Gap.lg),
    const _DettaglioCarica(),
  ];
}

/// Una frazione scritta come la leggerebbe una persona: `0.425` → `42,5%`.
///
/// 💡 **Toglie lo zero inutile**: `0.30` diventa `30%` e non `30,0%`. ⚠️ E la
/// virgola e' quella italiana, come nel resto della pagina.
String percentuale(double frazione) {
  final v = frazione * 100;
  final testo = v == v.roundToDouble()
      ? v.round().toString()
      : v.toStringAsFixed(1).replaceAll('.', ',');
  return '$testo%';
}

/// 🏃 L'Effetto, spiegato — 08/09/2026.
class _Effetto extends ConsumerWidget {
  const _Effetto();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tei = ref.watch(indiceDiEffettoProvider).valueOrNull;
    final mostrabile = tei != null && tei.affidabile;

    return _Sezione(
      icona: Icons.directions_run_rounded,
      titolo: 'Effetto',
      grande: mostrabile ? tei.punti.round().toString() : '—',
      sotto: mostrabile ? 'su 100 nella settimana' : 'non calcolabile',
      nota: mostrabile
          ? '${tei.minutiUtili} minuti utili negli ultimi '
                '${ModelloDiEffetto.giorni} giorni'
          : 'Servono l\'età nel profilo, un battito a riposo misurato e '
                'l\'orologio al polso con continuità.',
      figli: [
        const _Testo(
          'Quanto dei tuoi ultimi sette giorni è arrivato **al cuore**. Non '
          'conta i minuti: conta a che intensità li hai passati.',
        ),

        const SizedBox(height: Gap.md),

        const _Formula(
          'riserva = (battito − riposo) ÷ (massima − riposo)\n\n'
          'punti/min = ${ModelloDiEffetto.coefficiente} × '
          '(riserva − ${ModelloDiEffetto.soglia})^'
          '${ModelloDiEffetto.esponente}',
        ),
        /*
         * ⚠️ **`.round()` qui era un errore** — 08/09/2026: mostrava `43%`
         * mentre il codice usa `42,5%`. 🚨 Su una pagina che esiste apposta
         * perche' uno possa **rifare il conto**, un numero arrotondato nella
         * formula non e' una semplificazione: e' una formula diversa da quella
         * che gira, e chi la rifa' ottiene un risultato che non torna.
         */
        _Testo(
          'Sotto il **${percentuale(ModelloDiEffetto.soglia)}** della '
          'riserva non si accumula niente: è più o meno la vita normale, e se '
          'contasse l\'indice lo farebbe anche chi non si allena. La massima si '
          'stima con Tanaka (208 − 0,7 × età) quando non è misurata. Con un '
          'riposo di 75 e una massima di 181 fa **120 battiti**.',
        ),

        const SizedBox(height: Gap.md),

        _Formula(
          'mostrato = ${ModelloDiEffetto.tettoAssoluto.round()} × '
          '(1 − e^(−grezzo ÷ '
          '${ModelloDiEffetto.costanteDiSaturazione.round()}))',
        ),
        _Testo(
          'I primi punti valgono più degli ultimi: 50 grezzi diventano '
          '${ModelloDiEffetto.conRendimentiDecrescenti(50).round()}, cento '
          'diventano cento esatti, e oltre '
          '${ModelloDiEffetto.tettoAssoluto.round()} non si va. **Cento è il '
          'traguardo**, e superarlo si può — ma non per sbaglio.',
        ),

        const SizedBox(height: Gap.md),

        _Nota(
          'Massimo ${ModelloDiEffetto.tettoAlGiorno.round()} punti in un '
          'giorno: un indice che si sfonda in una giornata smette di '
          'descrivere un\'abitudine.',
        ),

        const SizedBox(height: Gap.sm),

        /*
         * ══ 🚨 SI DICE QUALE NUMERO E' MISURATO E QUALE E' SCELTO ══════════
         *
         * ⛔ È la cosa più importante di questa card, e la più facile da
         * omettere: una formula scritta per intero **sembra** tutta derivata.
         * 🚨 Qui un pezzo non lo è, e chi legge ha diritto di sapere quale.
         */
        const _Testo(
          'Da dove vengono i numeri: l\'ancora è **60 minuti al 70% della '
          'riserva = 100**, che viene dallo studio HUNT (NTNU) sul PAI. '
          'L\'**esponente ${ModelloDiEffetto.esponente} l\'abbiamo scelto '
          'noi**, per dare più peso ai battiti alti: su attività moderata '
          'questo indice è circa la metà del PAI, ed è voluto.',
        ),
      ],
    );
  }
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

class _Prontezza extends StatelessWidget {
  const _Prontezza({required this.forma});

  final Forma forma;

  @override
  Widget build(BuildContext context) {
    /*
     * ══ 🚨 QUESTA CARD SPIEGAVA UN NUMERO CHE NON SI VEDE PIU' ═══════════════
     *
     * ⛔ Fino all'08/09 mostrava `forma.prontezza` — sonno, HRV, battito, cibo
     * — mentre la card di «Oggi» e l'intestazione mostrano la **reattività**,
     * che è un altro modello. 🚨 Stesso nome, due numeri, e la pagina che
     * dovrebbe spiegarli spiegava quello sbagliato.
     *
     * ⚠️ **È il caso peggiore fra i tre trovati oggi**: una formula sbagliata si
     * corregge, ma una spiegazione convincente di un numero diverso insegna una
     * cosa falsa e la fa ricordare.
     *
     * 💡 La prontezza vecchia **non sparisce**: risponde a *«come stai rispetto
     * al tuo solito»* e alimenta la scheda del sonno. Qui sotto resta, con il
     * suo nome vero.
     */
    final reattivita = forma.reattivita;
    final valore = reattivita?.valore ?? forma.prontezza.valore;
    final ci = forma.ingredienti.where((i) => i.ceLo).length;

    return _Sezione(
      /*
       * 🚨 **Era `battery_charging_full`, ed era rimasta indietro** — 3b-X.
       *
       * ⛔ Il 28/08 la Prontezza aveva smesso di essere una batteria: il
       * tachimetro l'ha sostituita e il titolo e' cambiato. **L'icona della
       * sezione no.** Nessuno l'ha notata per due giorni.
       *
       * 💡 L'ha trovata `prontezza_non_e_una_carica_test.dart`, che cerca la
       * regola in **tutti** i file invece che in una schermata sola. E l'ha
       * trovata al primo giro, in un posto che non stavo guardando.
       */
      icona: Icons.speed_rounded,
      titolo: 'Prontezza',
      grande: valore == null ? '—' : valore.round().toString(),
      sotto: valore == null ? 'non calcolabile' : 'su 100',
      nota: reattivita == null
          ? null
          : 'Cambia durante la giornata: non è una media, è adesso.',
      indice: reattivita == null ? forma.prontezza : null,
      figli: [
        const _Testo(
          'Quanto sei **reattivo adesso**. Non è un confronto con le tue medie: '
          'è il modello di come cala e risale la lucidità in una giornata, '
          'spostato dai tuoi dati.',
        ),

        const SizedBox(height: Gap.md),

        const _Formula(
          'prontezza = S (quanto sei sveglio da tempo)\n'
          '          + C (l\'ora del giorno, onda a 24 h)\n'
          '          + U (onda a 12 h)\n'
          '          + W (inerzia del risveglio)\n'
          '          + pasto + modificatori',
        ),
        const _Testo(
          'È il **modello a tre processi** della regolazione dell\'allerta, lo '
          'stesso impianto usato nei sistemi di rischio-fatica dell\'aviazione. '
          'I parametri sono quelli pubblicati (Ingre e altri, 2014), non scelti '
          'da noi.',
        ),

        const SizedBox(height: Gap.md),

        const _Testo(
          'Due pezzi invece sono **nostri**: il **pasto**, perché il diario sa '
          '*quando* e *quanto* hai mangiato e un pranzo alle 15:30 abbassa la '
          'reattività alle 16:30; e i **modificatori** — HRV, battito e carico — '
          'che pesano poco di proposito: il modello descrive l\'essere umano '
          'medio, i sensori dicono solo se oggi stai sopra o sotto il tuo '
          'normale.',
        ),

        const SizedBox(height: Gap.md),

        /*
         * ══ 🚨 LA PRONTEZZA VECCHIA RESTA, E VA DETTO ═══════════════════════
         *
         * ⛔ Cancellarla dalla pagina l'avrebbe fatta sparire dagli occhi ma non
         * dal codice: alimenta ancora la scheda del sonno. 💡 Un indice che
         * esiste e non è spiegato da nessuna parte è il difetto che questa
         * pagina esiste per evitare.
         */
        const Divider(height: Gap.lg),

        const _Testo(
          '**E il confronto con il tuo solito**, che è un\'altra domanda: '
          'quanto stai bene o male rispetto alle tue medie di sonno, '
          'variabilità cardiaca, battito e cibo. Alimenta la scheda del sonno, '
          'e qui sotto trovi da cosa è fatto oggi.',
        ),

        if (forma.prontezza.valore != null)
          _Nota(
            'Vale ${forma.prontezza.valore!.round()} su 100, calcolato su $ci '
            'ingredienti su ${forma.ingredienti.length}.',
          ),

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

        /*
         * ══ 🔋 E LA CARICA, CHE È LA PIÙ LUNGA DELLE TRE ═════════════════
         *
         * 📌 Richiesta il 28/08: *«nella pagina con le formule, ci va messa
         * anche quella»*.
         *
         * 🚨 **Va scritta tutta**, come le altre due: è la formula con più
         * costanti scelte da noi, cioè quella su cui chi legge ha più diritto
         * di sapere da dove escono i numeri. ⛔ Scriverne metà «per non
         * spaventare» sarebbe il contrario del motivo per cui questa pagina
         * esiste.
         */
        const Divider(height: Gap.lg),

        const _Formula(
          'scarica = ${CaricaBatteria.scaricaDellaVeglia} × '
          '(ore sveglio ÷ ${CaricaBatteria.oreSveglioDiRiferimento})\n'
          '        + ${CaricaBatteria.scaricaDellAllenamento} × '
          '(kcal allenamento ÷ riferimento)\n'
          '        + ${CaricaBatteria.scaricaDellAttivita} × '
          '(altre kcal ÷ riferimento)\n\n'
          'sera   = mattina − scarica\n'
          'domani = sera + (100 − sera) × recupero',
        ),
        const _Testo(
          'La **prima riga** è la stanchezza di stare svegli, e c\'è perché una '
          'giornata senza allenamento stanca lo stesso: senza, la Carica non '
          'scendeva mai per chi non si allena.',
        ),
        const _Testo(
          'L\'ultima riga è tutto il senso della Carica: la notte recupera una '
          '**percentuale di quello che manca**, non un tot di punti. Così la '
          'fatica che non recuperi resta, e si somma a quella del giorno dopo.',
        ),

        const SizedBox(height: Gap.md),

        const _Formula(
          'recupero = ${CaricaBatteria.recuperoMinimo} + '
          '${CaricaBatteria.recuperoDalSonno} × (sonno ÷ obiettivo)\n'
          '         + ${CaricaBatteria.recuperoDallaFisiologia} × fisiologia',
        ),
        _Testo(
          'Con un sonno nella norma il recupero è del '
          '${((CaricaBatteria.recuperoMinimo + CaricaBatteria.recuperoDalSonno) * 100).round()}%. '
          'La «fisiologia» è la media fra lo scarto della variabilità cardiaca e '
          'quello del battito a riposo (col segno invertito), e conta solo dopo '
          '${CaricaBatteria.giorniPerLaFisiologia} giorni. '
          'Senza il sonno il recupero vale '
          '${(CaricaBatteria.recuperoSenzaSonno * 100).round()}%, e la stima è '
          'meno affidabile.',
        ),

        const SizedBox(height: Gap.md),

        const _Formula(
          'riferimento allenamento = ${CaricaBatteria.quotaAllenamento} × TDEE\n'
          'riferimento attività    = ${CaricaBatteria.quotaAttivita} × TDEE',
        ),
        const _Testo(
          'Sono i valori di partenza. Dopo '
          '${CaricaBatteria.giorniPerIRiferimenti} giorni diventano i **tuoi**: '
          'la mediana delle calorie dei tuoi allenamenti e delle tue giornate. '
          'Il passaggio è graduale, non da un giorno all\'altro.',
        ),

        const SizedBox(height: Gap.sm),
        Text(
          'La scarica di una giornata non supera mai '
          '${CaricaBatteria.scaricaMassimaAlGiorno.round()} punti: serve a '
          'impedire che un errore dell\'orologio azzeri una batteria che si '
          'trascina da giorni.',
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
    return _CardTesto(
      icona: Icons.help_outline_rounded,
      titolo: 'Come funziona il calcolo',
      figli: [
        const _Titoletto('Il carico confronta te con te stesso'),
        const _Testo(
          'Non c\'è un valore «giusto» uguale per tutti: si guarda quanto ti sei '
          'allenato nell\'ultima settimana rispetto a quanto ti alleni di solito. '
          'Il 100% vuol dire «come al tuo solito», non «al massimo».',
        ),

        const _Titoletto('Il carico è stimato dalle calorie, non dal cuore'),
        const _Testo(
          'Il metodo di riferimento vorrebbe la frequenza cardiaca durante '
          'l\'allenamento, che non abbiamo. Usiamo le calorie attive, che sono '
          'una buona approssimazione ma restano un\'approssimazione: due '
          'allenamenti con le stesse calorie possono affaticare in modo diverso.',
        ),

        const _Titoletto('La scala da 0 a 100 della carica è nostra'),
        const _Testo(
          'Il confronto con la tua media ha una letteratura dietro; il modo di '
          'trasformarlo in un numero su cento no, l\'abbiamo scelto noi. '
          'L\'ordine è onesto — più alto vuol dire davvero meglio — ma i numeri '
          'in mezzo sono una scelta di presentazione.',
        ),

        const _Titoletto('Il cibo pesa poco, e apposta'),
        const _Testo(
          'Non esiste una formula pubblicata che leghi il mangiare poco al '
          'recupero. Abbiamo scelto che mangiare tanto non alzi la carica, '
          'mentre mangiare molto meno del tuo solito la abbassi un po\'.',
        ),

        const _Titoletto('Servono giorni per essere precisi'),
        const _Testo(
          'Il numero compare da subito, ma finché mancano dati te lo diciamo '
          'sotto. Con poche notti registrate la «tua media» è fatta di poche '
          'notti, e basta una notte storta a spostarla.',
        ),

        const _Titoletto('Non si confronta con quella di altri'),
        const _Testo(
          'Sono numeri costruiti sulle tue medie: il 60 tuo e il 60 di un\'altra '
          'persona non vogliono dire la stessa cosa. E se il numero dice una cosa '
          'e tu ti senti diversamente, hai ragione tu.',
        ),

        const _Titoletto('Restano sul tuo telefono'),
        const _Testo(
          'Il calcolo lo fa il telefono, i numeri non li mandiamo a nessuno '
          'e non finiscono nemmeno nel consiglio del giorno. Non li salviamo '
          'da nessuna parte: si rifanno ogni volta che apri questa pagina.',
        ),

        /*
         * ══ 🔋 LA CARICA HA UNA SUA SEZIONE ══════════════════════════════
         *
         * 📌 *«va fatto anche il come funziona il calcolo anche per quello»*.
         *
         * 🚨 **E dice più delle altre che è un modello**, perché lo è di più:
         * carico e prontezza escono da dati misurati, la Carica esce da una
         * catena di parametri scelti da noi.
         */
        const _Titoletto('La Carica è una batteria, e si trascina'),
        const _Testo(
          'Carico e prontezza si rifanno ogni giorno da capo. La Carica no: '
          'parte da quella di ieri, cala con quello che fai e ne recupera una '
          'parte dormendo. Se una notte non recuperi tutto, quello che manca '
          'te lo porti dietro — che è il motivo per cui esiste.',
        ),

        const _Titoletto('I numeri di partenza li abbiamo scelti noi'),
        _Testo(
          'Un allenamento «pieno» vale '
          '${CaricaBatteria.scaricaDellAllenamento.round()} punti, una '
          'giornata attiva ${CaricaBatteria.scaricaDellAttivita.round()}, una '
          'notte normale recupera il '
          '${((CaricaBatteria.recuperoMinimo + CaricaBatteria.recuperoDalSonno) * 100).round()}% '
          'di quello che manca. Non sono costanti '
          'fisiologiche: sono valori scelti perché il calcolo funzioni fin dal '
          'primo giorno, e si affinano man mano che ci sono i tuoi dati.',
        ),

        const _Titoletto('Le calorie del wearable non sono una misura precisa'),
        const _Testo(
          'Sono utili come segnale relativo dentro la stessa persona — se oggi '
          'ne segna il doppio di ieri, probabilmente hai fatto il doppio — ma il '
          'numero assoluto è una stima. Per questo la Carica confronta te con te '
          'stesso e mai con qualcun altro.',
        ),

        const _Titoletto('Quello che manca non si inventa'),
        const _Testo(
          'Se un giorno l\'orologio non manda le calorie, la Carica non scende: '
          'non sappiamo cosa hai fatto, e dirti che sei stanco sarebbe '
          'inventarlo. Se manca il sonno, il recupero prende un valore di mezzo '
          'e te lo diciamo. Quello che manca lo trovi scritto sotto il numero.',
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
    required this.figli,
    this.indice,
    this.nota,
  });

  final IconData icona;
  final String titolo;
  final String grande;
  final String sotto;

  /// ⚠️ **Facoltativo**: la Carica non è un [Indice] — non ha «giorni che
  /// mancano», ha un'affidabilità che si racconta a parole. 💡 Chi non ce l'ha
  /// passa [nota].
  final Indice? indice;

  /// La riga sotto il numero, quando non la scrive [indice].
  final String? nota;

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
                    color: (indice?.esiste ?? true)
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
            if (nota != null ||
                (indice != null && indice!.esiste && !indice!.eAttendibile))
              Padding(
                padding: const EdgeInsets.only(top: Gap.xs),
                child: Text(
                  nota ??
                      'stima poco attendibile: mancano '
                          '${indice!.giorniCheMancano} giorni di dati',
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

// ══════════════════════════════════════════════════════════════════════════
// La Carica
// ══════════════════════════════════════════════════════════════════════════

/// I dettagli della Carica — 3b-K, 28/08/2026.
///
/// ══ 🚨 COSA DEVE FAR CAPIRE ═══════════════════════════════════════════════
///
/// Che **non è una fotografia di oggi**: è la somma di quello che è successo
/// nei giorni scorsi. ⛔ Senza questa card, un `71` è un numero che scende e
/// sale senza che si veda perché — e un numero così, su un'app di allenamento,
/// si finisce per crederci o per ignorarlo, mai per capirlo.
///
/// 💡 Per questo mostra **la mattina, quello che si è già speso, e cosa manca**:
/// sono i tre pezzi con cui il numero si ricostruisce a mente.
class _DettaglioCarica extends ConsumerWidget {
  const _DettaglioCarica();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final carica = ref.watch(caricaProvider).valueOrNull;

    /*
     * ⛔ **Senza TDEE non compare.** È la stessa regola della card in dashboard:
     * senza un metro personale la batteria si muoverebbe a caso, e mostrarla
     * vuota inviterebbe a chiedersi cosa si è rotto.
     */
    if (carica == null) return const SizedBox.shrink();

    final speso = carica.mattina - carica.adesso;

    final mancano = [
      if (carica.senzaAttivita) 'le calorie di oggi',
      if (carica.senzaSonno) 'il sonno di stanotte',
      if (carica.senzaFisiologia) 'battito e variabilità',
    ];

    return _Sezione(
      icona: Icons.battery_charging_full_rounded,
      titolo: 'Carica',
      grande: carica.adesso.round().toString(),
      sotto: 'su 100',
      nota: switch (carica.affidabilita) {
        Affidabilita.bassa =>
          'affidabilità bassa: è ancora quasi tutta una stima di partenza',
        Affidabilita.media =>
          'affidabilità media: comincia a usare i tuoi dati',
        Affidabilita.alta => null,
      },
      figli: [
        _Riga(
          nome: 'Stamattina',
          valore: carica.mattina.round().toString(),
          nota: 'con quanta ti sei svegliato',
        ),

        _Riga(
          nome: 'Speso oggi',
          valore: speso < 0.5 ? '—' : '−${speso.round()}',
          nota: 'da allenamenti e movimento',
        ),

        _Riga(
          nome: 'Giorni di dati',
          valore: carica.giorniValidi.toString(),
          nota: carica.giorniValidi >= CaricaBatteria.giorniPerIRiferimenti
              ? 'i riferimenti sono i tuoi'
              : 'dai ${CaricaBatteria.giorniPerIRiferimenti} giorni '
                    'i riferimenti diventano i tuoi',
        ),

        if (mancano.isNotEmpty) ...[
          const SizedBox(height: Gap.xs),
          _Nota('Oggi manca ${mancano.join(", ")}.'),
        ],

        const SizedBox(height: Gap.sm),

        /*
         * ⚠️ **La frase più importante della card**, e sta in fondo perché è
         * quella che si legge dopo aver capito i numeri: la Carica **si
         * trascina**. 🚨 È l'unica cosa che la distingue dagli altri due indici,
         * e senza saperlo un calo di oggi sembrerebbe colpa di oggi.
         */
        const _Nota(
          'La Carica non riparte da capo ogni mattina: quello che una notte non '
          'recupera te lo porti nel giorno dopo. Per questo conta più '
          'l\'andamento su più giorni che il numero di adesso.',
        ),
      ],
    );
  }
}
