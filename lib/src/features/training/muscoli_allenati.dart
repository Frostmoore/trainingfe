/// Quali muscoli hai allenato, e quanto — 3b-A.6, 24/08/2026.
///
/// ══ 🚨 IL CALCOLO STA QUI, NON NEL DISEGNO ════════════════════════════════
///
/// 📌 Il committente: *«un'immagine di un uomo in cui i muscoli e i gruppi
/// muscolari più allenati hanno un colore rosso più intenso»* e *«un grafico a
/// stella con tutti i gruppi muscolari»*.
///
/// 💡 **Due disegni, un conto solo.** La figura del corpo e la stella dicono la
/// stessa cosa in due modi: se il conto stesse dentro i widget, il giorno che
/// cambia il peso di un secondario ne cambierebbe uno solo — e le due card
/// direbbero cose diverse nella stessa schermata, una accanto all'altra.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/catalogo_esercizi.dart';
import 'data/gruppo_muscolare.dart';
import 'data/storico_unificato.dart';
import 'data/tipo_scelto.dart';
import 'storico_unificato_controller.dart';
import 'training_controller.dart';

/// Quanto ogni zona è stata allenata, da 0 a 1.
///
/// ── 🚨 Il punteggio, e perché è il **tempo** e non il numero di serie ─────
///
/// ⛔ Contare le serie metterebbe sullo stesso piano dieci serie di alzate
/// laterali e dieci di squat. ⚠️ Contare i **chili** escluderebbe la corsa, che
/// di chili non ne ha nessuno.
///
/// 💡 Il **minutaggio** è l'unica unità che tutte e due le provenienze hanno:
/// una seduta dura, una corsa dura. Ogni allenamento distribuisce i suoi minuti
/// sui muscoli che ha mosso, con i pesi di `muscoliConPeso` quando li conosce.
///
/// ── ⚠️ E il risultato è **relativo**, non assoluto ────────────────────────
///
/// 🚨 Il massimo vale sempre 1: la figura dice **cosa hai allenato di più**,
/// non «quanto è tanto». ⛔ Una scala assoluta avrebbe voluto dire scegliere
/// quanti minuti sono «rosso pieno» — un numero inventato che nessuno può
/// difendere, e che sarebbe sbagliato per chiunque non si alleni come chi l'ha
/// scelto.
///
/// ══ ⛔ I MUSCOLI NON ARRIVANO MAI DALL'OROLOGIO — B.9, 24/08/2026 ═════════
///
/// 📌 Il committente, correggendo una scelta che era nostra: *«I gruppi
/// muscolari **NON** arrivano dall'orologio. Al massimo possono arrivare dalla
/// scheda che ho associato a un allenamento che arriva solo dall'orologio (e
/// quindi sono quelli della scheda)»*.
///
/// 🚨 **Prima c'era una tabella `MuscoliDelTipo` che indovinava**: `RUNNING` →
/// gambe, `STRENGTH_TRAINING` → tutto il corpo. Sembrava prudente e non lo era:
/// l'orologio sa che ti sei mosso per un'ora, **non sa cosa hai fatto**. Un
/// «STRENGTH_TRAINING» può essere un giorno di sole braccia, e colorare tutto
/// il corpo è una figura che *sembra informata* — il difetto che questa
/// schermata continua a rifare in forme diverse.
///
/// 💡 Restano **due sole fonti, tutte e due vere**: le serie registrate
/// nell'app, e — per un allenamento visto solo dal polso — **la scheda che la
/// persona gli ha associato**. Quella è una risposta, non una deduzione.
///
/// ⚠️ **Conseguenza dichiarata**: una corsa senza scheda associata adesso non
/// colora niente. È voluto — meglio una zona spenta che una accesa per finta —
/// ed è la ragione per cui associare una scheda a un allenamento del polso ora
/// conta davvero.
Map<GruppoMuscolare, double> intensitaDeiMuscoli({
  required Iterable<VoceStorico> voci,
  required CatalogoEsercizi catalogo,

  /// I pesi dei muscoli di ogni scheda, per **id firmato** — negativo se
  /// arrivata in chat, positivo se dal server. Stessa convenzione di
  /// `schedeUniteProvider`.
  Map<int, Map<GruppoMuscolare, double>> pesiDelleSchede = const {},
}) {
  final grezzi = <GruppoMuscolare, double>{};

  void aggiungi(GruppoMuscolare m, double quanto) {
    if (!m.eUnMuscolo || quanto <= 0) return;

    grezzi[m] = (grezzi[m] ?? 0) + quanto;
  }

  for (final v in voci) {
    // ── Le serie registrate nell'app: si sa esercizio per esercizio ──────
    for (final seduta in v.sedute) {
      /*
       * 💡 I minuti della seduta si dividono fra le serie: venti serie in
       * un'ora sono tre minuti l'una. ⚠️ Non è il tempo vero di quella serie —
       * quello nessuno lo misura — ma è la ripartizione che rispetta sia la
       * durata sia quanto lavoro c'è dentro.
       */
      if (seduta.sets.isEmpty) continue;

      final minuti = (seduta.durationMinutes ?? 0).toDouble();

      if (minuti <= 0) continue;

      final perSerie = minuti / seduta.sets.length;

      for (final serie in seduta.sets) {
        final esercizio =
            catalogo.perId(serie.exerciseId) ??
            catalogo.perNome(serie.exerciseName);

        if (esercizio == null) continue;

        esercizio.muscoliConPeso.forEach(
          (muscolo, peso) => aggiungi(muscolo, perSerie * peso),
        );
      }
    }

    /*
     * ══ 🚨 SE L'APP SA GLI ESERCIZI, L'OROLOGIO NON INDOVINA ══════════════
     *
     * ⛔ Prima i due contributi si **sommavano**: una seduta registrata
     * esercizio per esercizio prendeva anche la spalmata generica del suo
     * gemello dall'orologio. Risultato, il dato preciso veniva annacquato da
     * quello approssimato — e chi si prende la briga di registrare le serie
     * otteneva una figura **peggiore** di quella che meritava.
     *
     * 💡 Il gruppo che ha delle serie dice gia' tutto: l'orologio, li', serve
     * per le calorie e la durata, non per i muscoli.
     */
    final conSerie = v.sedute.any((s) => s.sets.isNotEmpty);

    if (conSerie) continue;

    /*
     * ── La scheda che la persona ha associato all'allenamento del polso ───
     *
     * 💡 Non è una deduzione: è una **risposta**. Se ha detto «quel giorno ho
     * fatto il Giorno 2», i muscoli sono quelli del Giorno 2.
     *
     * ⛔ Senza scheda non si colora niente, e va bene così: vedi la nota in
     * cima alla funzione.
     */
    /*
     * ══ 🚨 IL TIPO CHE HAI DICHIARATO TU — 3b-B.20.5, 25/08/2026 ═══════════
     *
     * 📌 *«voglio poterci assegnare anche un tipo di allenamento diverso dalla
     * scheda … in modo che possa stimare i muscoli coinvolti»*.
     *
     * ⚠️ **Non contraddice B.9**, e va letto bene. Quel giorno era stata
     * cancellata `MuscoliDelTipo`, che indovinava i muscoli dal codice che
     * l'orologio scrive **da solo**: *«I gruppi muscolari NON arrivano
     * dall'orologio»*. Quella regola resta.
     *
     * 💡 Qui la fonte è un'altra: `tipoScelto` la scrive **una persona**, ed è
     * una dichiarazione, non un'ipotesi — esattamente come la scheda associata
     * qui sotto. ⛔ Se ha detto «era una nuotata», rifiutarsi di colorare le
     * spalle vorrebbe dire farglielo scrivere per niente.
     *
     * 🚨 **Viene prima della scheda**: chi ha dichiarato «corsa» su un
     * allenamento a cui aveva attaccato una scheda di pesi ha corretto proprio
     * quello, e la correzione più recente vince.
     */
    /*
     * ══ 🚨 LA SCHEDA VINCE SUL TIPO — corretto il 25/08 ═══════════════════
     *
     * 📌 *«se gli ho assegnato una scheda, vuol dire che in quell'allenamento
     * ho usato la scheda. Quindi va usata quella, anche per i pesi e per i
     * muscoli coinvolti»*.
     *
     * ⛔ **Qui l'ordine era rovesciato, ed era un errore mio.** Il tipo
     * dichiarato scavalcava la scheda: chi aveva assegnato «Giorno 1» e poi
     * detto «era una seduta di pesi» si vedeva colorare il generico «tutto il
     * corpo» invece dei muscoli veri di quella scheda.
     *
     * 💡 **Una scheda è più specifica di un'etichetta.** «Pesi» dice che hai
     * usato dei pesi; «Giorno 1» dice quali esercizi hai fatto, e da quelli i
     * muscoli si sanno uno per uno. ⚠️ Il tipo resta come **ripiego**, per gli
     * allenamenti a cui una scheda non si può attaccare — una corsa, una
     * nuotata.
     */
    final pesi =
        pesiDelleSchede[v.schedaId] ??
        TipoScelto.per(v.tipoDichiarato)?.muscoli;

    if (pesi == null || pesi.isEmpty) continue;

    final minuti = v.durata.inMinutes.toDouble();

    if (minuti <= 0) continue;

    /*
     * ⚠️ **I minuti si dividono, non si moltiplicano.** Un'ora è un'ora, che i
     * muscoli della scheda siano tre o dieci: darne una intera a ognuno farebbe
     * valere un allenamento di corpo intero il triplo di uno di braccia.
     *
     * 💡 E si dividono **in proporzione ai pesi**: un primario prende il doppio
     * di un secondario, esattamente come nella strada delle serie. Le due fonti
     * devono dire la stessa cosa nello stesso modo, o la figura cambierebbe a
     * seconda di **come** hai registrato invece che di **cosa** hai fatto.
     */
    final totale = pesi.values.fold<double>(0, (a, b) => a + b);

    if (totale <= 0) continue;

    pesi.forEach((muscolo, peso) => aggiungi(muscolo, minuti * peso / totale));
  }

  if (grezzi.isEmpty) return const {};

  final massimo = grezzi.values.reduce((a, b) => a > b ? a : b);

  return {
    for (final e in grezzi.entries) e.key: (e.value / massimo).clamp(0.0, 1.0),
  };
}

/// I numeri della stella, per la colonna accanto al grafico — B.14.
///
/// 📌 Il committente: *«visto che c'è anche troppa aria a dx e sx, metti qualche
/// valore a sx e il quadrato a dx»*.
///
/// 💡 **Sono le tre domande che la stella fa venire in mente e non risponde**:
/// quanti gruppi ho toccato, qual è il più allenato, e quale sto trascurando.
/// ⛔ Leggerle dal disegno si può, ma solo contando i raggi a occhio.
class NumeriDeiMuscoli {
  const NumeriDeiMuscoli({
    required this.toccati,
    required this.possibili,
    required this.equilibrio,
    this.piuAllenato,
    this.trascurato,
  });

  /// Quanti gruppi hanno preso almeno un po' di lavoro.
  final int toccati;

  /// Quanti gruppi esistono in tutto.
  final int possibili;

  /// Da 0 a 1: la media delle intensità su **tutti** i gruppi.
  ///
  /// ⚠️ La media e non il rapporto fra massimo e minimo: il massimo vale 1 per
  /// costruzione e il minimo di un gruppo appena sfiorato è quasi zero, quindi
  /// quel rapporto sarebbe enorme sempre e direbbe «sbilanciato» a chiunque.
  final double equilibrio;

  final GruppoMuscolare? piuAllenato;

  /// Il meno allenato **fra quelli che esistono**, non fra quelli toccati.
  ///
  /// 🚨 Il gruppo che non hai mai allenato è quello che ti interessa di più, ed
  /// è proprio quello che una classifica dei toccati non nominerebbe mai.
  final GruppoMuscolare? trascurato;

  int get percentualeEquilibrio => (equilibrio * 100).round();
}

NumeriDeiMuscoli numeriDeiMuscoli(Map<GruppoMuscolare, double> intensita) {
  final tutti = GruppoMuscolare.values.where((g) => g.eUnMuscolo).toList();

  if (intensita.isEmpty) {
    return NumeriDeiMuscoli(toccati: 0, possibili: tutti.length, equilibrio: 0);
  }

  final ordinati = intensita.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  final trascurati = tutti.map((g) => (g, intensita[g] ?? 0.0)).toList()
    ..sort((a, b) => a.$2.compareTo(b.$2));

  return NumeriDeiMuscoli(
    toccati: intensita.values.where((v) => v >= 0.15).length,
    possibili: tutti.length,
    equilibrio:
        intensita.values.fold<double>(0, (a, b) => a + b) / tutti.length,
    piuAllenato: ordinati.first.key,
    trascurato: trascurati.first.$1,
  );
}

/// Una riga in italiano che dice **cosa** hai allenato, **quanto** e **come**.
///
/// 📌 Il committente, sulla card della stella: *«sotto ci deve essere una breve
/// spiegazione di cosa ho allenato, quanto e come»*.
///
/// ── 🚨 Tre affermazioni, e nessuna inventata ──────────────────────────────
///
/// | | Da cosa esce |
/// |---|---|
/// | **cosa** | i due gruppi con l'intensità più alta |
/// | **quanto** | quanti gruppi hanno preso almeno un po' di lavoro |
/// | **come** | la media delle intensità: alta = lavoro sparso, bassa = concentrato |
///
/// ⚠️ **La media e non il rapporto max/min.** Il massimo vale 1 per costruzione
/// e il minimo di un gruppo appena sfiorato è quasi 0: quel rapporto sarebbe
/// enorme sempre, e direbbe «sbilanciato» a chiunque.
///
/// ⛔ Con la mappa vuota **non si scrive una frase incoraggiante**: si dice che
/// non c'è niente da dire. Una spiegazione allegra sopra una figura grigia è la
/// cosa peggiore che questa card possa fare.
String spiegazioneDeiMuscoli(
  Map<GruppoMuscolare, double> intensita, {
  Map<GruppoMuscolare, double> quote = const {},
}) {
  if (intensita.isEmpty) {
    return 'Nessun allenamento di cui si sappiano i muscoli, questo mese.';
  }

  final ordinati = intensita.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  /*
   * ══ 📊 LA QUOTA ACCANTO AL NOME — 3b-S, 28/08/2026 ═══════════════════════
   *
   * 📌 *«mi devi fare un calcolo proporzionale di quanto ho usato ciascuno dei
   * muscoli»*.
   *
   * 🚨 **`intensita` non può dirlo**: è normalizzata sul massimo, quindi la
   * prima voce vale 1 sempre. Scrivere «spalle 100%» sarebbe falso — dice solo
   * che sono la cosa più allenata, non quanto lavoro hanno preso.
   *
   * 💡 Perciò la percentuale arriva da `quote`, che è una proporzione vera. ⚠️
   * E se non arriva, la frase resta quella di prima invece di inventarsi un
   * numero: **meglio nessuna percentuale che una sbagliata**.
   */
  String conQuota(GruppoMuscolare g) {
    final nome = g.etichetta.toLowerCase();

    if (quote[g] case final q? when q >= 1) {
      return '$nome (${q.round()}%)';
    }

    return nome;
  }

  final primi = ordinati.take(2).map((e) => conQuota(e.key)).toList();

  final quanti = intensita.values.where((v) => v >= 0.15).length;
  final possibili = GruppoMuscolare.values.where((g) => g.eUnMuscolo).length;

  final media = intensita.values.fold<double>(0, (a, b) => a + b) / possibili;

  final come = media >= 0.5
      ? 'in modo molto equilibrato'
      : media >= 0.25
      ? 'in modo abbastanza equilibrato'
      : 'concentrandoti su pochi gruppi';

  final cosa = primi.length == 1
      ? 'Soprattutto ${primi.first}'
      : 'Soprattutto ${primi.first} e ${primi.last}';

  return '$cosa. Hai toccato $quanti gruppi su $possibili, $come.';
}

/// I pesi dei muscoli di una scheda, dai suoi esercizi.
///
/// 💡 **Passa dal catalogo**, non da un campo suo: così i muscoli di un
/// esercizio stanno scritti **in un posto solo**, e la scheda e la serie
/// registrata dicono la stessa cosa. ⚠️ Prima per id — che è l'identità vera —
/// e per nome solo come ripiego, esattamente come nella strada delle serie.
Map<GruppoMuscolare, double> pesiDellaScheda(
  WorkoutPlan scheda,
  CatalogoEsercizi catalogo,
) {
  final pesi = <GruppoMuscolare, double>{};

  for (final riga in scheda.exercises) {
    final esercizio =
        catalogo.perId(riga.exerciseId) ?? catalogo.perNome(riga.name);

    if (esercizio == null) continue;

    /*
     * ══ 🚨 SI CONTANO LE SERIE, NON GLI ESERCIZI — 3b-S, 28/08/2026 ═══════
     *
     * 📌 *«Deve essere un peso ponderato. Cioè se io alleno al 70% spalle e al
     * 30 petto i numeri non possono essere calcolati in questo modo»*.
     *
     * ⛔ **Prima ogni riga pesava 1, e basta.** Un esercizio da quattro serie
     * contava come uno da una sola: la figura diceva che una scheda con
     * quattro serie di panca e una di curl allena petto e bicipiti quasi
     * uguale.
     *
     * 🚨 È l'errore più grosso dei due, ed era invisibile: il numero c'era, la
     * figura si colorava, e nessuno aveva modo di accorgersi che il volume non
     * entrava nel conto. 💡 La strada delle serie **registrate** lo faceva già
     * giusto — passa serie per serie — quindi le due fonti dicevano cose
     * diverse sulla stessa scheda.
     *
     * ⚠️ **Almeno una**: una riga senza serie compilate vale comunque un
     * esercizio. ⛔ Contarla zero la farebbe sparire dalla figura, e «non l'ho
     * ancora compilata» non vuol dire «non allena niente».
     */
    final quanteSerie = riga.serie.isEmpty ? 1 : riga.serie.length;

    esercizio.muscoliConPeso.forEach((muscolo, peso) {
      if (!muscolo.eUnMuscolo) return;

      pesi[muscolo] = (pesi[muscolo] ?? 0) + peso * quanteSerie;
    });
  }

  return pesi;
}

/// Quanto vale ciascun muscolo **in percentuale sul totale** — 3b-S.
///
/// ══ 📌 LA RICHIESTA ═══════════════════════════════════════════════════════
///
/// *«se io alleno al 70% spalle e al 30 petto i numeri non possono essere
/// calcolati in questo modo… mi devi fare un calcolo proporzionale di quanto ho
/// usato ciascuno dei muscoli»*.
///
/// ══ 🚨 PERCHÉ [intensitaDeiMuscoli] NON POTEVA DIRLO ══════════════════════
///
/// ⛔ Quella normalizza **sul massimo**: la zona più allenata vale 1 sempre, per
/// costruzione. Quindi non può dire «il 70% del lavoro è andato alle spalle» —
/// dice solo «le spalle sono la cosa che hai fatto di più», anche quando sono
/// il 12% del totale.
///
/// 💡 Servono tutte e due, e dicono cose diverse: quella colora la figura (un
/// disegno che si legge a colpo d'occhio vuole il confronto col massimo),
/// questa dà **il numero**, che deve essere una proporzione vera.
///
/// @return muscolo → quota da 0 a 100, che sommate fanno 100
Map<GruppoMuscolare, double> quoteDeiMuscoli(
  Map<GruppoMuscolare, double> pesi,
) {
  final totale = pesi.values.fold<double>(0, (a, b) => a + b);

  // ⛔ Zero non è «tutti a zero»: è «non lo sappiamo», e una mappa vuota lo
  // dice senza far comparire una fila di 0%.
  if (totale <= 0) return const {};

  return {for (final e in pesi.entries) e.key: e.value / totale * 100};
}

/// Le schede che compaiono nello storico, coi loro muscoli.
///
/// ⚠️ **Solo quelle davvero associate a qualcosa**: chiedere al server tutte le
/// schede per colorarne due sarebbe traffico per niente, e in palestra la rete
/// è quella che è.
///
/// ⛔ Una scheda che non si legge **non colora niente** e non fa fallire le
/// altre: `catchError` per riga, non sul gruppo. Un 404 su una scheda cancellata
/// non deve spegnere la figura intera.
final muscoliDelleSchedeProvider =
    FutureProvider<Map<int, Map<GruppoMuscolare, double>>>((ref) async {
      final voci = await ref.watch(storicoUnificatoProvider.future);
      final catalogo = await ref.watch(catalogoEserciziProvider.future);

      final quali = <int>{
        for (final v in voci)
          if (v.schedaId != null && v.sedute.every((s) => s.sets.isEmpty))
            v.schedaId!,
      };

      final pesi = <int, Map<GruppoMuscolare, double>>{};

      for (final id in quali) {
        try {
          final scheda = await ref.watch(planDetailProvider(id).future);

          pesi[id] = pesiDellaScheda(scheda, catalogo);
        } on Object catch (e) {
          debugPrint('muscoli: la scheda $id non si legge — $e');
        }
      }

      return pesi;
    });

/// I muscoli allenati **nel mese** di una data.
///
/// ⚠️ **Il mese e non la settimana**, anche se l'intestazione naviga per
/// settimane: una settimana sola dice poco di come ti alleni — chi fa un
/// «giorno gambe» avrebbe la figura mezza spenta il martedì e mezza accesa il
/// giovedì. 💡 Il mese è anche il periodo delle altre due card del carosello e
/// del calendario sotto, quindi il blocco in cima parla di **una cosa sola**.
final muscoliDelMeseProvider =
    Provider.family<Map<GruppoMuscolare, double>, DateTime>((ref, mese) {
      final voci = ref.watch(storicoUnificatoProvider).valueOrNull ?? const [];
      final catalogo =
          ref.watch(catalogoEserciziProvider).valueOrNull ??
          CatalogoEsercizi.vuoto;

      return intensitaDeiMuscoli(
        voci: voci.where(
          (v) => v.quando.year == mese.year && v.quando.month == mese.month,
        ),
        catalogo: catalogo,
        pesiDelleSchede:
            ref.watch(muscoliDelleSchedeProvider).valueOrNull ?? const {},
      );
    });

/// L'intensita' dei muscoli di **una scheda**, da 0 a 1 — 3b-D.16.
///
/// 💡 Serve alla figura sotto una scheda che si sta **guardando**, non
/// eseguendo: qui l'intensita' viene da quello che la scheda **prescrive**,
/// mentre nello storico viene da quello che si e' fatto. Stessa forma, tempo
/// verbale diverso.
///
/// ⚠️ **Normalizzata sul gruppo piu' coinvolto della scheda**, esattamente come
/// `intensitaDeiMuscoli`: cosi' il rosso vuol dire «il piu' allenato **di
/// questa scheda**», non una soglia assoluta che nessuna scheda raggiungerebbe.
///
/// ⛔ Vuota quando il catalogo non conosce nessuno degli esercizi: meglio
/// nessuna figura che una figura spenta, che sembra un difetto.
Map<GruppoMuscolare, double> intensitaDellaScheda(
  WorkoutPlan scheda,
  CatalogoEsercizi catalogo,
) {
  final pesi = pesiDellaScheda(scheda, catalogo);

  if (pesi.isEmpty) return const {};

  final massimo = pesi.values.reduce((a, b) => a > b ? a : b);

  if (massimo <= 0) return const {};

  return {for (final voce in pesi.entries) voce.key: voce.value / massimo};
}
