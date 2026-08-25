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
import '../../data/prescrizione.dart';
import '../../data/storico_unificato.dart';
import '../../data/tipo_scelto.dart';
import '../../muscoli_allenati.dart';
import '../../training_controller.dart';
import 'carosello_del_mese.dart';
import 'figura_del_corpo.dart';

class CaroselloDellAllenamento extends ConsumerStatefulWidget {
  const CaroselloDellAllenamento({required this.voce, super.key});

  final VoceStorico voce;

  @override
  ConsumerState<CaroselloDellAllenamento> createState() =>
      _CaroselloDellAllenamentoState();
}

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
          child: RiquadroBianco(
            sempreBianco: true,
            child: FiguraDelCorpo(intensita: intensita),
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
    ];

    return Column(
      children: [
        SizedBox(
          height: altezzaCarosello,

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

    for (final riga in scheda.exercises) {
      totale +=
          Prescrizione.leggi(riga.prescription).volumeCon(riga.targetWeight) ??
          0;
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

    for (final riga in scheda.exercises) {
      totale += Prescrizione.leggi(riga.prescription).serie ?? 0;
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
    final numeri = <(String, String)>[
      ('$minuti', 'minuti'),
      if (kcal != null && kcal > 0)
        ('$kcal', kcalStimate ? 'kcal stimate' : 'kcal'),
      if (volume != null) (_kg(volume), 'kg sollevati'),
      if (esercizi > 0) ('$esercizi', esercizi == 1 ? 'esercizio' : 'esercizi'),
      if (serie > 0) ('$serie', serie == 1 ? 'serie' : 'serie'),
      if (metri != null && metri > 0) (_distanza(metri), 'percorsi'),
      if (metri != null && metri >= 1000 && minuti > 0)
        (_ritmo(metri, minuti), 'al chilometro'),
      if (_passi > 0) ('$_passi', 'passi'),
    ];

    /*
     * ══ 🔢 UNO GRANDE, GLI ALTRI PICCOLI — 25/08/2026 ═══════════════════════
     *
     * 📌 *«La card "L'Allenamento in numeri" dovrebbe avere (in base al tipo di
     * esercizio) un numero al centro più grande degli altri (molto più grande
     * degli altri)»*.
     *
     * 🚨 **«In base al tipo» è la parte che conta.** Sette numeri della stessa
     * dimensione non dicono niente: chi guarda deve decidere da solo quale
     * conta, e la risposta cambia con lo sport. Di una corsa si vogliono i
     * **chilometri**; di una seduta di pesi i **chili sollevati**.
     *
     * ⚠️ E il protagonista **esce dall'elenco sotto**: ripeterlo grande e poi
     * piccolo sarebbe lo stesso numero due volte nella stessa card — il difetto
     * della fiammella di B.19, appena corretto.
     */
    final protagonista = _protagonista(numeri);
    final resto = numeri.where((n) => n != protagonista).toList();

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
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    /*
                     * 🚨 Il protagonista: **molto** più grande, non un po'.
                     * 💡 `FittedBox` perché «12,4 km» e «1.480» non sono larghi
                     * uguale, e un numero che sfora è peggio di uno piccolo.
                     */
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        protagonista.$1,
                        style: tema.textTheme.displayLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: tema.colorScheme.primary,
                          height: 1,
                        ),
                      ),
                    ),
                    Text(
                      protagonista.$2,
                      style: tema.textTheme.titleMedium?.copyWith(
                        color: tema.colorScheme.onSurfaceVariant,
                      ),
                    ),

                    if (resto.isNotEmpty) ...[
                      const SizedBox(height: Gap.md),
                      Wrap(
                        alignment: WrapAlignment.center,
                        runAlignment: WrapAlignment.center,
                        spacing: Gap.lg,
                        runSpacing: Gap.sm,
                        children: [
                          for (final (valore, etichetta) in resto)
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  valore,
                                  style: tema.textTheme.titleLarge?.copyWith(
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
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Quale dei numeri merita di stare grande, **in base al tipo**.
  ///
  /// | Sport | Protagonista |
  /// |---|---|
  /// | corsa, camminata, bici, escursione, scale, nuoto, vogatore | i **chilometri** |
  /// | pesi, corpo libero | i **chili sollevati** |
  /// | tutto il resto | le **calorie**, se ci sono |
  ///
  /// ⚠️ **Con un ripiego a scalare, e non è pigrizia**: una corsa senza GPS i
  /// chilometri non ce li ha, e una seduta a corpo libero non ha chili. 🚨 Una
  /// card che mostra grande un trattino sarebbe peggio di una che sceglie un
  /// numero meno interessante ma vero.
  ///
  /// 💡 L'ultima spiaggia sono i **minuti**, che ci sono sempre: un allenamento
  /// senza durata non esiste.
  (String, String) _protagonista(List<(String, String)> numeri) {
    (String, String)? cerca(String etichetta) {
      for (final n in numeri) {
        if (n.$2 == etichetta) return n;
      }

      return null;
    }

    const diDistanza = {
      'RUNNING',
      'WALKING',
      'HIKING',
      'BIKING',
      'STAIR_CLIMBING',
      'ROWING',
      'SWIMMING',
    };

    const diCarico = {'STRENGTH_TRAINING', 'CALISTHENICS'};

    final tipo = voce.tipo;

    final ordine = <String>[
      if (tipo != null && diDistanza.contains(tipo)) 'percorsi',
      if (tipo != null && diCarico.contains(tipo)) 'kg sollevati',
      // 💡 Senza tipo — una seduta nata nell'app — i chili sollevati sono la
      // cosa che dice se oggi è stato più duro dell'altra volta.
      if (tipo == null) 'kg sollevati',
      'kcal',
      'kcal stimate',
      'percorsi',
      'kg sollevati',
      'minuti',
    ];

    for (final etichetta in ordine) {
      final trovato = cerca(etichetta);
      if (trovato != null) return trovato;
    }

    return numeri.first;
  }

  static String _kg(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  /// 💡 Sotto il chilometro si scrivono i metri, come ovunque nell'app.
  static String _distanza(int metri) => metri < 1000
      ? '$metri m'
      : '${(metri / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';

  /// Minuti e secondi per chilometro.
  static String _ritmo(int metri, int minuti) {
    final secondiPerKm = (minuti * 60) / (metri / 1000);
    final m = secondiPerKm ~/ 60;
    final sec = (secondiPerKm % 60).round();

    return '$m:${sec.toString().padLeft(2, '0')}';
  }
}
