/// Le tre card, ristrette a **un allenamento solo** — 3b-B.20.1, 25/08/2026.
///
/// ══ 📌 LA RICHIESTA ═══════════════════════════════════════════════════════
///
/// *«aggiungere sopra le tre cards a carosello come nella sezione storico, ma
/// limitate allo specifico allenamento»*.
///
/// ══ 🚨 «COME NELLA SEZIONE STORICO» VUOL DIRE *LE STESSE* ═════════════════
///
/// ⛔ La vestizione — la card, il riquadro bianco, la stella, i puntini — **non
/// è riscritta qui**: vive in `carosello_del_mese.dart`, dove era privata, e da
/// oggi è pubblica. Rifarla di qua avrebbe prodotto due caroselli che si
/// somigliano finché qualcuno non tocca uno dei due.
///
/// 💡 Quello che cambia non è il disegno: è **da dove vengono i dati**. Là un
/// mese, qui una `VoceStorico`.
///
/// ══ ⚠️ E LA TERZA CARD NON È LA STESSA, DI PROPOSITO ══════════════════════
///
/// 🚨 Su un allenamento solo, *«il numero di sessioni del mese»* dice sempre
/// **1**, e il grafico degli ultimi mesi non ha niente da confrontare. ⛔ Ridurre
/// a uno un contatore mensile non lo restringe: lo rende muto.
///
/// 💡 Al suo posto i numeri di **quella seduta**: durata, volume, distanza,
/// calorie, serie. E ognuno compare solo se c'è — un «0 km» su una seduta di
/// pesi è spazio riempito con niente, ed è la regola che
/// `allenamento_orologio_screen` seguiva già.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../profile/corpo_controller.dart';
import '../../data/calorie_allenamento.dart';
import '../../data/catalogo_esercizi.dart';
import '../../data/storico_unificato.dart';
import '../../data/tipo_scelto.dart';
import '../../muscoli_allenati.dart';
import '../../../health/tipo_allenamento.dart';
import '../../statistiche_allenamento.dart';
import '../../statistiche_controller.dart';
import '../../training_controller.dart';
import 'carosello_del_mese.dart';
import 'figura_del_corpo.dart';
import 'percorso_dell_allenamento.dart';

class CaroselloDellAllenamento extends ConsumerStatefulWidget {
  const CaroselloDellAllenamento({required this.voce, super.key});

  final VoceStorico voce;

  @override
  ConsumerState<CaroselloDellAllenamento> createState() =>
      _CaroselloDellAllenamentoState();
}

/// Quanto è alta questa card, **secondo cosa c'è dentro**.
///
/// ══ 📌 DUE ALTEZZE, NON UNA ═══════════════════════════════════════════════
///
/// Il committente: *«l'altezza delle card del carosello deve essere diversa tra
/// gli allenamenti di pesi e quelli con il gps: sul gps ci sono molti dati in
/// più quindi ovviamente la card sarà più lunga, mentre sulla card di pesi c'è
/// proprio il carosello e le cose vanno in tre card diverse»*.
///
/// ⛔ **Un'altezza sola sbagliava tutti e due i casi**: a 420 l'uscita col GPS
/// nascondeva dieci cifre dietro uno scorrimento interno; a 560 la seduta di
/// pesi mostrava mezzo riquadro vuoto sotto otto numeri.
///
/// | Allenamento | Cosa c'è dentro | Altezza |
/// |---|---|---|
/// | Con percorso | tracciato + **undici** numeri | **560** |
/// | Di pesi | otto numeri, e i muscoli su due pagine loro | **420** |
///
/// 🚨 **La condizione è la stessa che decide se il percorso si disegna**, e non
/// è una coincidenza: è quel blocco a occupare lo spazio in più. ⚠️ Se un giorno
/// le due si separassero, la card resterebbe alta per allenamenti che non hanno
/// niente da metterci.
///
/// 💡 Il carosello del **mese** resta a `altezzaCarosello` e non c'entra: lì
/// dentro c'è un grafico solo.
double _altezza(VoceStorico voce) =>
    TipoAllenamento.conPercorso(voce.dalPolso.firstOrNull?.tipo ?? '')
    ? 560
    : altezzaCarosello;

class _CaroselloDellAllenamentoState
    extends ConsumerState<CaroselloDellAllenamento> {
  /// ⛔ Fuori da `build`, come nel carosello del mese: crearlo dentro lo
  /// rifarebbe a ogni ridisegno, e la pagina tornerebbe alla prima card ogni
  /// volta che cambia un numero.
  final _pagine = PageController();
  int _pagina = 0;

  @override
  void dispose() {
    _pagine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final voce = widget.voce;

    final catalogo =
        ref.watch(catalogoEserciziProvider).valueOrNull ??
        CatalogoEsercizi.vuoto;

    /*
     * ⚠️ **I muscoli passano anche dalla scheda associata** — B.9. Senza, la
     * pagina di un allenamento del polso sarebbe l'unico posto in cui la scheda
     * che gli hai attaccato non colora niente: la stessa domanda, due risposte
     * diverse a seconda di dove la guardi.
     */
    final intensita = intensitaDeiMuscoli(
      voci: [voce],
      catalogo: catalogo,
      pesiDelleSchede:
          ref.watch(muscoliDelleSchedeProvider).valueOrNull ?? const {},
    );

    final quando = DateFormat('d MMMM, HH:mm', 'it').format(voce.quando);

    /*
     * ⛔ **Senza muscoli non si mostrano due card mute.** Uno sport che la
     * tabella non conosce darebbe una figura tutta grigia e una stella
     * schiacciata al centro: due modi di dire «non hai allenato niente» a chi si
     * è appena allenato. 💡 I numeri invece ci sono sempre, e restano da soli.
     */
    final card = <Widget>[
      if (intensita.isNotEmpty) ...[
        CardDelCarosello(
          titolo: 'Cosa hai mosso',
          sottotitolo: quando,
          // 📌 Nel quadrato bianco, come nello storico: il PNG è disegnato
          // per un fondo chiaro.
          child: Column(
            children: [
              Expanded(
                child: RiquadroBianco(
                  child: FiguraDelCorpo(intensita: intensita),
                ),
              ),
              const SizedBox(height: Gap.xs),
              const LegendaDeiMuscoli(),
            ],
          ),
        ),
        CardDelCarosello(
          titolo: 'I gruppi muscolari',
          sottotitolo: quando,
          child: StellaInRiquadro(intensita: intensita),
        ),
      ],
      CardDelCarosello(
        titolo: 'L\'allenamento in numeri',
        sottotitolo: quando,
        child: _NumeriDellAllenamento(voce: voce),
      ),

      /*
       * ⛔ **Il percorso NON è una pagina a sé** — 08/09/2026, secondo giro.
       *
       * 📌 *«Il percorso però deve stare nella stessa card dei numeri»*. 💡 Sta
       * dentro [_NumeriDellAllenamento], sopra la griglia: sfogliare per
       * mettere insieme il tracciato e la velocità era la stessa fatica di
       * prima, solo in orizzontale.
       */
    ];

    return Column(
      children: [
        SizedBox(
          height: _altezza(voce),

          // 🚨 `PageView` e non `ListView`: le card sono larghe tutta la pagina
          // e devono **scattare** una per una, o si resta a cavallo di due.
          child: PageView(
            controller: _pagine,
            onPageChanged: (i) => setState(() => _pagina = i),
            children: card,
          ),
        ),
        if (card.length > 1)
          SizedBox(
            height: altezzaPuntiniDelCarosello,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < card.length; i++)
                  PuntinoDelCarosello(acceso: i == _pagina),
              ],
            ),
          ),
      ],
    );
  }
}

/// I numeri di **questo** allenamento.
class _NumeriDellAllenamento extends ConsumerWidget {
  const _NumeriDellAllenamento({required this.voce});

  final VoceStorico voce;

  /// Il volume sollevato: ripetizioni × peso, su tutte le serie del gruppo.
  ///
  /// ══ 🚨 E SE LE SERIE NON CI SONO, LO DICE LA SCHEDA — 3b-C.5 ════════════
  ///
  /// 📌 *«se gli ho assegnato una scheda, vuol dire che in quell'allenamento ho
  /// usato la scheda. Quindi va usata quella, anche per i pesi»*.
  ///
  /// ⛔ Prima un allenamento del polso dava sempre `null`, anche con una scheda
  /// attaccata: la card mostrava «—» dove c'erano quattro serie da dodici a
  /// quaranta chili scritte nero su bianco.
  ///
  /// ⚠️ **Le serie registrate vincono sulla scheda**, e non è la stessa regola
  /// dei muscoli: lì la scheda dice *quali* esercizi, qui i carichi **veri**
  /// sono un dato migliore di quelli previsti. 💡 Chi ha registrato le serie ha
  /// fatto la fatica di dire cosa ha davvero sollevato.
  double? _volumeCon(WorkoutPlan? scheda) {
    var totale = 0.0;

    for (final s in voce.sedute) {
      for (final serie in s.sets) {
        totale += (serie.reps ?? 0) * (serie.weight ?? 0);
      }
    }

    if (totale > 0) return totale;

    if (scheda == null) return null;

    /*
     * ══ 💡 LE RIGHE VERE, NON LA STRINGA — 3b-E.12 ══════════════════════════
     *
     * ⛔ Qui si rileggeva `'4 × 12'` e si moltiplicava per **un** peso: una
     * piramide 12×40, 10×45, 8×50 diventava `4 × 12 × 40` = 1920 kg invece di
     * 1330. Quasi il 45% in più, su un numero che si mostra come se fosse
     * misurato.
     *
     * 🚨 Non era una svista: `PlanExercise` non aveva le serie separate e
     * leggere la stringa era l'unico modo. Da 3b-D.1 le ha.
     */
    for (final riga in scheda.exercises) {
      totale += riga.volume ?? 0;
    }

    return totale == 0 ? null : totale;
  }

  /// Quante serie: quelle registrate, o quelle **previste** dalla scheda.
  int _serieCon(WorkoutPlan? scheda) {
    var totale = 0;

    for (final s in voce.sedute) {
      totale += s.sets.length;
    }

    if (totale > 0 || scheda == null) return totale;

    // 💡 Le righe **sono** le serie previste: non c'è niente da rileggere.
    for (final riga in scheda.exercises) {
      totale += riga.serie.length;
    }

    return totale;
  }

  int get _passi {
    var totale = 0;

    for (final a in voce.dalPolso) {
      totale += a.passi ?? 0;
    }

    return totale;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final metri = voce.distanzaMetri;

    /*
     * 💡 La scheda associata, quando c'è: è quello che permette di dire i chili
     * e le serie di un allenamento che l'orologio ha visto e basta.
     * ⚠️ `valueOrNull` e non `await`: mentre carica si mostra quello che si sa,
     * e i numeri della scheda compaiono un istante dopo. Una card che aspetta
     * per riempirsi lampeggia a ogni apertura.
     */
    final scheda = voce.schedaId == null
        ? null
        : ref.watch(planDetailProvider(voce.schedaId!)).valueOrNull;

    final volume = _volumeCon(scheda);
    final serie = _serieCon(scheda);

    /*
     * 🚨 **Anche gli esercizi si contano dalla scheda.** Sono il numero che dice
     * quanto era lunga la seduta in termini di lavoro, e su un allenamento del
     * polso con una scheda attaccata si sanno esattamente.
     */
    final esercizi = voce.sedute.isEmpty
        ? (scheda?.exercises.length ?? 0)
        : {
            for (final s in voce.sedute)
              for (final serie in s.sets) serie.exerciseName,
          }.length;

    /*
     * ══ 🔥 LE CALORIE STIMATE DAL TIPO CHE HAI DICHIARATO — 3b-B.20.5 ══════
     *
     * 📌 *«in modo che possa stimare i muscoli coinvolti e le calorie tanto le
     * facciamo con una formula»*.
     *
     * ⚠️ **Solo quando non ce ne sono di vere.** `voce.kcal` è una catena di
     * priorità documentata — correzione a mano, poi orologio, poi stima — e
     * questa formula sta **sotto** tutte: se l'orologio le ha misurate, una
     * moltiplicazione non le migliora. ⛔ Sostituirle vorrebbe dire buttare una
     * misura per un'ipotesi.
     *
     * 💡 `MET × kg × ore`, la stessa formula delle sedute. Il peso è quello che
     * hai registrato; senza, il ripiego prudente di `CalorieAllenamento`.
     */
    final sport = TipoScelto.per(voce.tipoDichiarato);

    final stimate = sport == null
        ? null
        : CalorieAllenamento.formula(
            durata: voce.durata,
            kg:
                ref.watch(corpoOggiProvider).valueOrNull?.weightKg ??
                CalorieAllenamento.pesoDiRipiego,
            metMedio: sport.met,
          );

    final kcal = voce.kcal ?? (stimate == 0 ? null : stimate);
    final kcalStimate = voce.kcal == null && kcal != null;

    final minuti = voce.durata.inMinutes;

    /*
     * ⚠️ **Una lettura sola per tutti i numeri nuovi.** Ognuno di loro
     * chiedendoselo da sé vorrebbe dire sette letture dell'archivio per una
     * card — e sette occasioni perché due di loro non siano d'accordo.
     */
    final StatisticheAllenamento? stat = voce.dalPolso.isEmpty
        ? null
        : ref.watch(statisticheAllenamentoProvider(voce.dalPolso)).valueOrNull;

    /*
     * ══ 🚨 «LE COSE CHE HANNO RILEVANZA» ═══════════════════════════════════
     *
     * ⛔ Ogni numero compare **solo se c'è**. Un «0 km» su una seduta di pesi o
     * un «— passi» su una nuotata non sono informazioni: sono spazio riempito,
     * e insegnano a non leggere il riquadro. È la regola che questa pagina
     * seguiva già prima che i numeri si spostassero qui dentro.
     *
     * 💡 Il ritmo si calcola solo quando ci sono dei metri: «5:30 /km» su un
     * allenamento di pesi sarebbe una divisione per zero travestita da dato.
     */
    /*
     * ══ 📌 CON L'ICONA E L'ETICHETTA, COME NELLA CARD DI PRIMA ═════════════
     *
     * Il committente: *«i numeri mi piacevano ordinati com'erano nella card
     * sotto»*.
     *
     * ⛔ **Qui c'era un numero grande al centro e gli altri sparsi in un
     * `Wrap`** — la disposizione chiesta il 25/08. 🚨 Reggeva con sette numeri;
     * con quindici era diventata un mucchio, e trovare il battito medio voleva
     * dire leggerli tutti.
     *
     * 💡 Due colonne con l'icona a sinistra si **scorrono**: l'occhio segue una
     * riga sola e le icone fanno da segnalibro.
     */
    final numeri = <(IconData, String, String)>[
      (Icons.timer_outlined, 'Tempo', '$minuti min'),
      if (kcal != null && kcal > 0)
        (
          Icons.local_fire_department_rounded,
          kcalStimate ? 'Calorie stimate' : 'Calorie',
          '$kcal kcal',
        ),
      if (volume != null)
        (Icons.fitness_center_rounded, 'Sollevati', '${_kg(volume)} kg'),
      if (esercizi > 0)
        (
          Icons.list_alt_rounded,
          esercizi == 1 ? 'Esercizio' : 'Esercizi',
          '$esercizi',
        ),
      if (serie > 0) (Icons.repeat_rounded, 'Serie', '$serie'),
      if (metri != null && metri > 0)
        (Icons.straighten_rounded, 'Distanza', _distanza(metri)),
      /*
       * ══ 🚨 IL PASSO VIENE DALLA STESSA FONTE DELLA CARD, O SONO DUE ══════
       *
       * ⛔ **Qui c'era `_ritmo(metri, minuti)` e basta**, cioè distanza diviso
       * durata. 🚨 Sulla camminata dell'08/09 dava **21:16 /km** mentre la card
       * «I numeri», due dita più giù, diceva **15:43** — perché quella usa la
       * velocità dell'orologio, che tiene conto delle soste.
       *
       * ⚠️ **Due passi diversi nella stessa schermata**, tutti e due plausibili:
       * è esattamente il difetto che questo progetto insegue da settimane, e
       * l'ho introdotto io sistemando solo una delle due.
       *
       * 💡 Adesso il numero è **uno**: quello di `StatisticheAllenamento`, che
       * sa quale fonte preferire. ⛔ Il calcolo locale resta solo per gli
       * allenamenti che una riga dell'orologio non ce l'hanno.
       */
      if (metri != null && metri >= 1000 && minuti > 0)
        (
          Icons.timeline_rounded,
          'Passo',
          '${_passoDelloStesso(ref, voce) ?? _ritmo(metri, minuti)} /km',
        ),
      if (_passi > 0)
        (Icons.follow_the_signs_rounded, 'Passi', _conIPunti(_passi)),

      /*
       * ══ 📌 E QUI ARRIVANO GLI ALTRI — 08/09/2026 ════════════════════
       *
       * Il committente: *«la card "I Numeri" deve essere spostata nella card
       * "L'allenamento in numeri"»*.
       *
       * ⛔ **Erano in una card separata più sotto**, ed era una divisione senza
       * senso: velocità e battito sono «l'allenamento in numeri» quanto i minuti
       * e le calorie. 💡 Chi voleva il quadro completo doveva scorrere e tenerne
       * metà a memoria.
       *
       * ⚠️ **Vengono tutti da `StatisticheAllenamento`**, che sa già quali hanno
       * senso per questo tipo e quale fonte preferire: qui non si decide niente,
       * si scrive.
       */
      if (stat?.velocitaKmH case final v?)
        (
          Icons.speed_rounded,
          /*
           * 🚨 **L'etichetta dice da dove viene, e non è un dettaglio.** Sulla
           * camminata dell'08/09 le due strade danno 3,79 km/h (l'orologio) e
           * 2,8 (distanza ÷ durata): il 34% di scarto, che è la sosta al bar.
           * ⚠️ Chiamarle uguali farebbe sembrare rotta l'app a chi confronta.
           */
          stat!.velocitaDallOrologio
              ? 'Velocità media'
              : 'Velocità media stimata',
          '${_conLaVirgola(v, 1)} km/h',
        ),
      if (stat?.cadenzaAlMinuto case final c?)
        (Icons.directions_walk_rounded, 'Cadenza', '${c.round()} passi/min'),
      if (stat?.lunghezzaDelPasso case final l?)
        (Icons.height_rounded, 'Falcata', '${_conLaVirgola(l, 2)} m'),
      if (stat?.battitoMedio case final b?)
        (Icons.favorite_rounded, 'Battito medio', '$b bpm'),
      if (stat?.battitoMassimo case final b?)
        (Icons.favorite_border_rounded, 'Battito massimo', '$b bpm'),
      if (stat?.dislivelloMetri case final d?)
        (Icons.terrain_rounded, 'Dislivello', '${d.round()} m'),
      if (stat?.kcalAlMinuto case final k?)
        (Icons.bolt_rounded, 'Intensità', '${_conLaVirgola(k, 1)} kcal/min'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        /*
         * 🥇 **L'intenso si dice qui, non solo col bordo.** Nello storico l'oro
         * intorno alla card è un segnale che si coglie di sfuggita; chi apre
         * l'allenamento vuole leggerlo scritto.
         */
        if (voce.intenso)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.local_fire_department_rounded,
                  size: 18,
                  color: oroDellIntenso,
                ),
                const SizedBox(width: 4),
                Text(
                  'Allenamento intenso',
                  style: tema.textTheme.labelLarge?.copyWith(
                    color: oroDellIntenso,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

        Expanded(
          child: RiquadroBianco(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  /*
                   * ══ 🗺️ IL PERCORSO STA QUI, SOPRA I NUMERI ════════════════
                   *
                   * 📌 Il committente: *«il percorso deve stare nella stessa
                   * card dei numeri»*.
                   *
                   * ⛔ **È il terzo posto in cui finisce in un giorno**: prima
                   * una card sotto, poi una pagina sua del carosello, adesso
                   * qui. 💡 E qui ha senso: la forma dell'uscita e i suoi numeri
                   * si guardano insieme, non si sfogliano.
                   *
                   * ⚠️ Compare **solo per i tipi che un percorso possono
                   * averlo**: su una seduta di pesi non lascia nemmeno lo
                   * spazio vuoto.
                   */
                  if (TipoAllenamento.conPercorso(
                    voce.dalPolso.firstOrNull?.tipo ?? '',
                  )) ...[
                    PercorsoDellAllenamento(voce: voce),
                    const SizedBox(height: Gap.md),
                    Divider(height: 1, color: tema.colorScheme.outlineVariant),
                    const SizedBox(height: Gap.md),
                  ],

                  /*
                   * ══ 📌 DUE COLONNE, COME NELLA CARD DI PRIMA ══════════════
                   *
                   * *«i numeri mi piacevano ordinati com'erano nella card
                   * sotto»*.
                   *
                   * ⚠️ `Wrap` e non `GridView`: siamo dentro uno scorrevole, e
                   * una griglia con altezza propria lì dentro è la strada più
                   * breve per un `RenderBox was not laid out`.
                   */
                  LayoutBuilder(
                    builder: (context, vincoli) {
                      // ⚠️ `- 1` e non `/ 2` netto: a metà esatta un pixel di
                      // arrotondamento manda la seconda colonna a capo.
                      final larghezza = (vincoli.maxWidth - Gap.md) / 2 - 1;

                      return Wrap(
                        spacing: Gap.md,
                        runSpacing: Gap.md,
                        children: [
                          for (final (icona, etichetta, valore) in numeri)
                            SizedBox(
                              width: larghezza,
                              child: _Numero(
                                icona: icona,
                                etichetta: etichetta,
                                valore: valore,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 💡 `10.482` e non `10482`: a colpo d'occhio le migliaia si contano da sole.
  static String _conIPunti(int n) {
    final testo = n.toString();
    final fuori = StringBuffer();

    for (var i = 0; i < testo.length; i++) {
      if (i > 0 && (testo.length - i) % 3 == 0) fuori.write('.');

      fuori.write(testo[i]);
    }

    return fuori.toString();
  }

  /*
   * ⛔ **`_protagonista` non c'è più** — 08/09/2026.
   *
   * 📌 Sceglieva quale numero mostrare grande al centro, ed era la richiesta
   * del 25/08: *«un numero al centro più grande degli altri»*.
   *
   * 🚨 **Quella disposizione è stata sostituita**, non tolta per svista: con
   * quindici numeri il mucchio sotto il protagonista era illeggibile, e il
   * committente ha chiesto la griglia della card «I numeri» — *«mi piacevano
   * ordinati com'erano nella card sotto»*.
   *
   * ⚠️ Se un giorno il numero grande dovesse tornare, la regola che sceglieva
   * quale sta nella storia di questo file: dipendeva dal **tipo**, perché di una
   * corsa si vogliono i chilometri e di una seduta di pesi i chili.
   */

  static String _kg(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  /// 💡 Sotto il chilometro si scrivono i metri, come ovunque nell'app.
  static String _distanza(int metri) => metri < 1000
      ? '$metri m'
      : '${(metri / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';

  /// 💡 La virgola, non il punto: `7,4`. Qui si scrive in italiano.
  static String _conLaVirgola(double n, int decimali) =>
      n.toStringAsFixed(decimali).replaceAll('.', ',');

  /// Il passo **come lo dice `StatisticheAllenamento`**, se c'è.
  ///
  /// 🚨 Torna `null` quando non c'è una riga dell'orologio o quando il tipo un
  /// passo non ce l'ha: in quel caso chi chiama ricade su [_ritmo], che è la
  /// vecchia divisione — giusta, quando non c'è di meglio.
  static String? _passoDelloStesso(WidgetRef ref, VoceStorico voce) {
    if (voce.dalPolso.isEmpty) return null;

    final passo = ref
        .watch(statisticheAllenamentoProvider(voce.dalPolso))
        .valueOrNull
        ?.passoAlKm;

    if (passo == null) return null;

    return StatisticheAllenamento.passoScritto(passo);
  }

  /// Minuti e secondi per chilometro.
  static String _ritmo(int metri, int minuti) {
    final secondiPerKm = (minuti * 60) / (metri / 1000);
    final m = secondiPerKm ~/ 60;
    final sec = (secondiPerKm % 60).round();

    return '$m:${sec.toString().padLeft(2, '0')}';
  }
}

/// Un numero con la sua icona e la sua etichetta.
///
/// 📌 Recuperato dalla card «I numeri» quando è stata assorbita qui:
/// *«i numeri mi piacevano ordinati com'erano nella card sotto»*.
///
/// 💡 L'icona a sinistra fa da segnalibro: con quindici voci, ritrovare il
/// battito medio senza leggerle tutte dipende da quella.
class _Numero extends StatelessWidget {
  const _Numero({
    required this.icona,
    required this.etichetta,
    required this.valore,
  });

  final IconData icona;
  final String etichetta;
  final String valore;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icona, size: 18, color: tema.colorScheme.primary),
        const SizedBox(width: Gap.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                valore,
                style: tema.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                etichetta,
                style: tema.textTheme.bodySmall?.copyWith(
                  color: tema.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
