/// La Carica: quanto stress fisico si può ancora sostenere — 3b-K, 28/08/2026.
///
/// ══ 📌 COS'È, E COSA NON È ════════════════════════════════════════════════
///
/// 📌 Dalla specifica del committente: *«una stima da 0 a 100 della capacità
/// residua di sostenere ulteriore stress fisico. Non rappresenta una quantità
/// fisiologica direttamente misurabile»*.
///
/// ⚠️ **È la seconda cosa in questo progetto che produce un giudizio e non una
/// misura**, dopo `IndiciDiForma`. Vale la stessa avvertenza, per esteso: non
/// diagnostica, non sostituisce come uno si sente, e **non è confrontabile fra
/// persone diverse** — perché dal 28° giorno i riferimenti diventano personali.
///
/// ══ 🚨 LA DIFFERENZA DALLA PRONTEZZA, CHE È TUTTO ═════════════════════════
///
/// 📌 *«a differenza della Prontezza, la Carica è uno stato persistente: la
/// Carica di oggi dipende anche dalla Carica di ieri»*.
///
/// | | Prontezza | Carica |
/// |---|---|---|
/// | Cos'è | come stai **rispetto al tuo solito** | quanto **ti resta** |
/// | Come si calcola | z-score di oggi | ieri, meno la fatica, più il recupero |
/// | Se salti un giorno | si ricalcola da capo | **si trascina** |
///
/// 🚨 **La fatica che una notte non recupera resta**, e si somma a quella del
/// giorno dopo. ⛔ Ricalcolare la Carica da zero ogni mattina — che è la cosa che
/// verrebbe naturale — cancellerebbe esattamente la proprietà per cui esiste.
///
/// ══ 💡 TUTTO PURO, COME `IndiciDiForma` ═══════════════════════════════════
///
/// Nessun provider, nessun archivio, nessun `DateTime.now()`: entrano numeri ed
/// esce un numero. È l'unico modo di verificare una formula di diciassette
/// passaggi.
///
/// ══ ⚠️ E DEGRADA, NON SI SPEGNE ═══════════════════════════════════════════
///
/// 📌 *«tutti i valori che non ci sono perché non arrivano dall'orologio devono
/// poter essere approssimati o eliminati dalla formula»*. 🚨 Ogni ingresso è
/// nullable e ogni assenza ha una risposta scritta — vedi [Affidabilita], che è
/// il modo in cui l'app **dichiara** quanto sta tirando a indovinare.
library;

import 'dart:math' as math;

/// Quanto ci si può fidare del numero.
///
/// 📌 *«impedisce di presentare un 86% del secondo giorno come se avesse la
/// stessa precisione di un 86% calcolato dopo sei mesi di storico»*.
///
/// 🚨 **Sta accanto al numero, non al posto suo.** Il numero si mostra sempre —
/// è la decisione D-2s/A, già presa per gli altri indici: *«si stima, e sotto
/// c'è scritto che è una stima poco veritiera»*. Un valore che compare solo al
/// 28° giorno è, per chi installa l'app, una funzione che non esiste.
enum Affidabilita {
  bassa,
  media,
  alta;

  /// 💡 Il giorno decide il **tetto**, i dati mancanti possono solo abbassarlo.
  ///
  /// ⚠️ Non il contrario: nessuna quantità di dati completi rende attendibile
  /// una stima al secondo giorno, perché i riferimenti sono ancora quelli
  /// generici.
  static Affidabilita da({
    required int giorniValidi,
    required bool senzaSonno,
    required bool senzaFisiologia,
    required bool senzaAttivita,
  }) {
    var livello = switch (giorniValidi) {
      < CaricaBatteria.giorniPerLaFisiologia => Affidabilita.bassa,
      < CaricaBatteria.giorniPerIRiferimenti => Affidabilita.media,
      _ => Affidabilita.alta,
    };

    // ⚠️ **Le calorie contano doppio**: senza quelle non si sa nemmeno quanto si
    // è consumato, cioè manca il numeratore di tutta la scarica.
    if (senzaAttivita) livello = Affidabilita.bassa;

    if (senzaSonno && livello == Affidabilita.alta) livello = Affidabilita.media;

    if (senzaFisiologia && livello == Affidabilita.alta) {
      livello = Affidabilita.media;
    }

    return livello;
  }
}

/// La Carica di un giorno: come si è svegliata e come è andata a dormire.
class GiornoDiCarica {
  const GiornoDiCarica({
    required this.giorno,
    required this.mattina,
    required this.sera,
    required this.affidabilita,
  });

  /// Il giorno locale, a mezzanotte.
  final DateTime giorno;

  /// Con quanta carica ci si è svegliati.
  final double mattina;

  /// Quanta ne è rimasta la sera, prima di dormire.
  final double sera;

  final Affidabilita affidabilita;
}

/// Cosa sappiamo di una giornata. ⚠️ **Tutto nullable tranne il giorno**: è la
/// richiesta — quello che l'orologio non manda si approssima o si toglie.
class GiornataPerLaCarica {
  const GiornataPerLaCarica({
    required this.giorno,
    this.calorieAttive,
    this.calorieAllenamento,
    this.minutiDormiti,
    this.zHrv,
    this.zBattito,
  });

  final DateTime giorno;

  /// Tutte le calorie da attività della giornata, allenamenti **compresi**.
  final double? calorieAttive;

  /// La parte attribuita agli allenamenti registrati.
  ///
  /// 🚨 **Non si somma di nuovo** a [calorieAttive]: è un sottoinsieme. ⛔
  /// Sommarla conterebbe due volte lo stesso sforzo, e la batteria crollerebbe
  /// proprio nei giorni in cui ci si allena — cioè sempre nel verso sbagliato.
  final double? calorieAllenamento;

  /// I minuti della notte **che precede** questa giornata.
  final double? minutiDormiti;

  /// Gli z-score contro la baseline personale. `null` finché non ce n'è
  /// abbastanza — vedi [CaricaBatteria.giorniPerLaFisiologia].
  final double? zHrv;
  final double? zBattito;
}

/// Il calcolo, tutto qui dentro.
abstract final class CaricaBatteria {
  // ───────────────────────── le costanti del bootstrap ─────────────────────

  /*
   * ⚠️ **Sono parametri di progetto, non costanti fisiologiche.**
   *
   * 📌 La specifica lo dice per esteso: *«servono a far funzionare la stima fin
   * dai primi giorni e dovrebbero essere progressivamente sostituiti o calibrati
   * sui dati individuali»*.
   *
   * 🚨 Stanno tutte qui e non sparse nelle formule: il giorno che si calibrano
   * sui dati veri, il posto da cambiare è uno solo. È la stessa ragione per cui
   * `IndiciDiForma.zAlCentro` non è scritto dentro il calcolo.
   */

  /// L'obiettivo di sonno quando non ne è stato impostato uno: otto ore.
  static const minutiDiSonnoDiRiferimento = 480.0;

  /// Il tetto al rapporto col sonno obiettivo.
  ///
  /// 💡 `1.20` e non di più: dormire quattordici ore non recupera il doppio di
  /// dormirne dieci, e senza tetto una notte anomala falserebbe la settimana.
  static const rapportoMassimoDiSonno = 1.20;

  /// Quanto pesa un allenamento «di riferimento» sul TDEE.
  static const quotaAllenamento = 0.30;

  /// Quanto pesa l'attività quotidiana non allenante.
  static const quotaAttivita = 0.20;

  /// Punti di scarica per un allenamento pari al riferimento.
  static const scaricaDellAllenamento = 25.0;

  /// Punti di scarica per un'attività quotidiana pari al riferimento.
  ///
  /// 💡 Meno della metà dell'allenamento: *«un allenamento strutturato viene
  /// considerato più affaticante, a parità di calorie»*.
  static const scaricaDellAttivita = 10.0;

  /// ⚠️ **Il tetto alla scarica giornaliera**, ed è una difesa non un'estetica:
  /// *«per impedire che errori del wearable o attività eccezionali distruggano
  /// completamente la scala»*. 🚨 Un orologio che sbaglia una volta non deve
  /// poter azzerare una batteria che si trascina per giorni.
  static const scaricaMassimaAlGiorno = 50.0;

  /// La parte di capacità mancante che si recupera **anche senza dormire**.
  static const recuperoMinimo = 0.15;

  /// Quanto il sonno aggiunge al recupero, a rapporto pieno.
  static const recuperoDalSonno = 0.55;

  /// Quanto la fisiologia sposta il recupero, per punto di z-score.
  ///
  /// 💡 `0.08` è piccolo di proposito: HRV e battito *modificano* la stima del
  /// recupero, non la determinano.
  static const recuperoDallaFisiologia = 0.08;

  static const recuperoMassimo = 0.90;

  /// ⚠️ Il recupero quando **il sonno non si sa**: un valore di mezzo,
  /// dichiarato meno affidabile. 💡 Sta fra `0.15` e `0.70`, cioè fra «notte
  /// pessima» e «notte normale»: è il modo onesto di non sapere.
  static const recuperoSenzaSonno = 0.55;

  /// Quando il primo giorno non ha nemmeno il sonno.
  static const caricaSenzaNiente = 75.0;

  /// I giorni oltre i quali HRV e battito cominciano a contare.
  static const giorniPerLaFisiologia = 7;

  /// I giorni oltre i quali i riferimenti diventano personali.
  static const giorniPerIRiferimenti = 28;

  /// Il tetto allo z-score fisiologico, per lato.
  static const zMassimo = 2.0;

  // ───────────────────────── il sonno ──────────────────────────────────────

  /// Quanto si è dormito rispetto all'obiettivo. `null` se non si sa.
  static double? rapportoDiSonno({
    required double? minutiDormiti,
    double? obiettivo,
  }) {
    if (minutiDormiti == null) return null;

    final target = (obiettivo ?? minutiDiSonnoDiRiferimento);

    // ⛔ Un obiettivo a zero non è un obiettivo: sarebbe una divisione per zero
    // travestita da impostazione.
    if (target <= 0) return null;

    return (minutiDormiti / target).clamp(0.0, rapportoMassimoDiSonno);
  }

  // ───────────────────────── il primo giorno ───────────────────────────────

  /// Con quanta carica si parte, quando non c'è nessuno storico.
  ///
  /// 💡 `55 + 35 × rapporto`, limitato fra `55` e `95`: chi ha dormito otto ore
  /// su otto parte da `90`. ⚠️ **Non da 100**: partire pieni direbbe che si sa
  /// qualcosa che non si sa, e il primo calo sembrerebbe un crollo.
  static double caricaIniziale({double? rapportoDiSonno}) {
    if (rapportoDiSonno == null) return caricaSenzaNiente;

    return (55 + 35 * rapportoDiSonno).clamp(55.0, 95.0).toDouble();
  }

  // ───────────────────────── i riferimenti ─────────────────────────────────

  /// Quanto vale un allenamento «normale» per questa persona.
  ///
  /// ══ 🚨 LA FUSIONE PROGRESSIVA, E PERCHÉ NON UNO SCALINO ═══════════════
  ///
  /// 📌 *«per evitare un passaggio improvviso dai valori iniziali a quelli
  /// personali utilizzare una fusione progressiva»*.
  ///
  /// ⛔ Senza, al 28° giorno la batteria cambierebbe comportamento **da un
  /// giorno all'altro** senza che sia successo niente: chi guarda lo leggerebbe
  /// come un guasto, non come un affinamento.
  ///
  /// 💡 `lambda = giorniValidi / 28`, limitato a `1`.
  static ({double allenamento, double attivita}) riferimenti({
    required double tdeeDiBase,
    required int giorniValidi,
    double? allenamentoPersonale,
    double? attivitaPersonale,
  }) {
    final generico = (
      allenamento: quotaAllenamento * tdeeDiBase,
      attivita: quotaAttivita * tdeeDiBase,
    );

    final lambda = (giorniValidi / giorniPerIRiferimenti).clamp(0.0, 1.0);

    /*
     * ⚠️ **Un riferimento personale a zero non si usa.** Chi non si è mai
     * allenato ha una mediana di zero, e dividerci sopra darebbe infinito — cioè
     * una scarica infinita al primo allenamento. 💡 In quel caso resta il
     * generico, che è esattamente cosa serve a chi comincia.
     */
    final a = (allenamentoPersonale ?? 0) > 0
        ? (1 - lambda) * generico.allenamento + lambda * allenamentoPersonale!
        : generico.allenamento;

    final b = (attivitaPersonale ?? 0) > 0
        ? (1 - lambda) * generico.attivita + lambda * attivitaPersonale!
        : generico.attivita;

    return (allenamento: a, attivita: b);
  }

  // ───────────────────────── la scarica ────────────────────────────────────

  /// Quanto si scarica in una giornata.
  ///
  /// ⚠️ Le calorie dell'allenamento **si tolgono** da quelle attive prima di
  /// contare l'attività quotidiana: sono un sottoinsieme, non un'aggiunta.
  ///
  /// 💡 Se le calorie dell'allenamento non si sanno, tutto diventa attività
  /// quotidiana — *«la stima sarà meno accurata»*, ma esiste.
  static double scarica({
    required double? calorieAttive,
    required double? calorieAllenamento,
    required double riferimentoAllenamento,
    required double riferimentoAttivita,
  }) {
    // ⛔ Senza calorie non si sa quanto si è consumato: la batteria **non
    // scende**. Inventare una scarica media sarebbe far calare la carica a chi
    // ha lasciato l'orologio nel cassetto.
    if (calorieAttive == null) return 0;

    final allenamento = calorieAllenamento ?? 0;
    final quotidiana = math.max(calorieAttive - allenamento, 0);

    final daAllenamento = riferimentoAllenamento > 0
        ? scaricaDellAllenamento * (allenamento / riferimentoAllenamento)
        : 0.0;

    final daAttivita = riferimentoAttivita > 0
        ? scaricaDellAttivita * (quotidiana / riferimentoAttivita)
        : 0.0;

    return (daAllenamento + daAttivita)
        .clamp(0.0, scaricaMassimaAlGiorno)
        .toDouble();
  }

  // ───────────────────────── la fisiologia ─────────────────────────────────

  /// HRV e battito insieme, come **modificatori** del recupero.
  ///
  /// ══ 🚨 IL BATTITO VA INVERTITO ════════════════════════════════════════
  ///
  /// Per l'HRV «più alto = meglio»; per il battito a riposo è il contrario. ⚠️ È
  /// lo stesso errore di segno che `IndiciDiForma.carica` documenta, ed è
  /// altrettanto facile da rifare: darebbe un recupero che cresce proprio quando
  /// dovrebbe calare.
  ///
  /// 💡 Chi chiama passa `zBattito` **già nel verso naturale** (positivo =
  /// battito alto): l'inversione la fa questa funzione, in un posto solo.
  static double punteggioFisiologico({double? zHrv, double? zBattito}) {
    final pezzi = <double>[
      if (zHrv != null) zHrv.clamp(-zMassimo, zMassimo).toDouble(),
      if (zBattito != null) (-zBattito).clamp(-zMassimo, zMassimo).toDouble(),
    ];

    // ⛔ Nessuno dei due: **zero**, cioè «non sposta niente». Non è una
    // conclusione sulla persona, è l'assenza di una correzione.
    if (pezzi.isEmpty) return 0;

    return pezzi.reduce((a, b) => a + b) / pezzi.length;
  }

  // ───────────────────────── il recupero ───────────────────────────────────

  /// Quanta parte della capacità mancante si recupera dormendo.
  ///
  /// 🚨 **Una frazione, non punti fissi.** 📌 *«questo permette alla fatica
  /// residua di sopravvivere automaticamente da un giorno all'altro»*: chi è
  /// molto scarico recupera molto in valore assoluto ma non torna mai pieno, e
  /// il resto si trascina.
  static double frazioneDiRecupero({
    required double? rapportoDiSonno,
    double punteggioFisiologico = 0,
  }) {
    // ⚠️ Sonno mancante: un valore di mezzo, e la stima va marcata meno
    // affidabile — lo fa `Affidabilita.da(senzaSonno: true)`.
    if (rapportoDiSonno == null) return recuperoSenzaSonno;

    return (recuperoMinimo +
            recuperoDalSonno * rapportoDiSonno +
            recuperoDallaFisiologia * punteggioFisiologico)
        .clamp(recuperoMinimo, recuperoMassimo)
        .toDouble();
  }

  /// La carica del mattino dopo.
  ///
  /// `sera + (100 − sera) × frazione`.
  static double mattinoDopo({
    required double caricaDellaSera,
    required double frazioneDiRecupero,
  }) {
    final mancante = 100 - caricaDellaSera;

    return (caricaDellaSera + mancante * frazioneDiRecupero)
        .clamp(0.0, 100.0)
        .toDouble();
  }

  // ───────────────────────── la catena ─────────────────────────────────────

  /// Fa scorrere la Carica lungo i giorni.
  ///
  /// ══ 🚨 È QUI CHE LA CARICA DIVENTA PERSISTENTE ════════════════════════
  ///
  /// 📌 *«la Carica NON deve essere ricalcolata ogni giorno da zero»*.
  ///
  /// [giorni] va dal **più vecchio al più recente**, e i buchi devono essere
  /// già stati riempiti da chi chiama: ⚠️ un giorno che manca **non è** un
  /// giorno saltato, è un giorno senza dati — e senza dati la batteria non
  /// scende ma recupera lo stesso, che è il comportamento giusto per chi ha
  /// lasciato l'orologio a casa.
  ///
  /// [daCapo] permette di ripartire da una carica già nota invece che dal
  /// bootstrap: serve a non ricalcolare mesi di storico a ogni apertura.
  static List<GiornoDiCarica> catena({
    required List<GiornataPerLaCarica> giorni,
    required double tdeeDiBase,
    double? obiettivoDiSonno,
    double? daCapo,
    int giorniValidiIniziali = 0,
    double? allenamentoPersonale,
    double? attivitaPersonale,
  }) {
    final fuori = <GiornoDiCarica>[];

    double? mattina = daCapo;

    for (var i = 0; i < giorni.length; i++) {
      final g = giorni[i];

      final sonno = rapportoDiSonno(
        minutiDormiti: g.minutiDormiti,
        obiettivo: obiettivoDiSonno,
      );

      // 💡 Il primo giorno in assoluto parte dal bootstrap; tutti gli altri
      // dalla mattina calcolata dalla notte precedente.
      mattina ??= caricaIniziale(rapportoDiSonno: sonno);

      final validi = giorniValidiIniziali + i;

      final rif = riferimenti(
        tdeeDiBase: tdeeDiBase,
        giorniValidi: validi,
        allenamentoPersonale: allenamentoPersonale,
        attivitaPersonale: attivitaPersonale,
      );

      final sera = (mattina -
              scarica(
                calorieAttive: g.calorieAttive,
                calorieAllenamento: g.calorieAllenamento,
                riferimentoAllenamento: rif.allenamento,
                riferimentoAttivita: rif.attivita,
              ))
          .clamp(0.0, 100.0)
          .toDouble();

      fuori.add(
        GiornoDiCarica(
          giorno: g.giorno,
          mattina: mattina,
          sera: sera,
          affidabilita: Affidabilita.da(
            giorniValidi: validi,
            senzaSonno: g.minutiDormiti == null,
            senzaFisiologia: g.zHrv == null && g.zBattito == null,
            senzaAttivita: g.calorieAttive == null,
          ),
        ),
      );

      /*
       * ⚠️ **La fisiologia del giorno DOPO decide il recupero di questa
       * notte**, non quella di oggi: si dorme fra i due, e i valori si misurano
       * al risveglio. 💡 Quando il giorno dopo non c'è — l'ultimo della catena —
       * il recupero non serve, perché non c'è nessun mattino da calcolare.
       */
      if (i + 1 < giorni.length) {
        final domani = giorni[i + 1];

        mattina = mattinoDopo(
          caricaDellaSera: sera,
          frazioneDiRecupero: frazioneDiRecupero(
            rapportoDiSonno: rapportoDiSonno(
              minutiDormiti: domani.minutiDormiti,
              obiettivo: obiettivoDiSonno,
            ),
            punteggioFisiologico: punteggioFisiologico(
              zHrv: domani.zHrv,
              zBattito: domani.zBattito,
            ),
          ),
        );
      }
    }

    return fuori;
  }

  /// La carica **adesso**: quella del mattino meno quello che si è già speso.
  ///
  /// 💡 Serve a mostrare un numero che cala durante la giornata invece di uno
  /// che salta la sera. ⚠️ Usa le calorie **accumulate fino a questo momento**,
  /// che è quello che l'orologio ha già mandato.
  static double adesso({
    required double caricaDelMattino,
    required double scaricaFinora,
  }) => (caricaDelMattino - scaricaFinora).clamp(0.0, 100.0).toDouble();
}
