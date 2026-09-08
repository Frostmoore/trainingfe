/// Il **Training Effect Index** (TEI) — 07/09/2026.
///
/// ══ 📌 DA DOVE VIENE, E PERCHE' NON SI CHIAMA PAI ═════════════════════════
///
/// Il committente, il 06/09: *«ho scoperto una nuova misura che si chiama PAI,
/// va implementata nella stessa card del carico e scarico»*, e il 07/09:
/// *«per quanto riguarda il pai chiamiamolo "Training Effect Index" TEI»*.
///
/// 🚨 **Il PAI non si può implementare: la formula non è pubblica.** Nasce dallo
/// studio HUNT alla NTNU, è **brevettato**, ed è un marchio di PAI Health. La
/// letteratura pubblica descrive i **principi** — finestra mobile di sette
/// giorni, punteggio sulla frequenza cardiaca di riserva, personalizzato su
/// età, sesso, battito a riposo e massimo, obiettivo 100, tetto giornaliero —
/// ma **non le equazioni**.
///
/// 💡 Quindi questo è un indice **nostro** che segue quei principi. ⚠️ E il nome
/// diverso non è timidezza: chiamarlo PAI vorrebbe dire prendersi un marchio
/// altrui e insieme promettere una validazione clinica che il nostro conto **non
/// ha**.
///
/// ══ 🚨 LA CURVA E' NOSTRA, E SI DICE SU COSA E' ANCORATA ══════════════════
///
/// I punti al minuto crescono con l'intensità, e la curva passa per **due
/// ancore** prese dalla letteratura invece che da un'impressione:
///
///   · **40 minuti all'85% della riserva = 100** — è l'affermazione principale
///     pubblicata sul PAI: *«only 40 minutes of high-intensity PA (~85% of the
///     heart rate reserve) is needed to obtain 100 PAI»*;
///   · **150 minuti al 50% = 100** — la raccomandazione OMS sull'attività
///     moderata settimanale, con cui il PAI è dichiaratamente allineato.
///
/// ⛔ Da lì escono esponente e coefficiente, e **non sono stati scelti perché il
/// numero venisse bello**: due ancore dichiarate si possono discutere, un
/// coefficiente aggiustato a occhio no.
library;

import 'dart:math' as math;

/// Un campione di battito: quanto e per quanto.
class BattitoNelTempo {
  const BattitoNelTempo({required this.bpm, required this.quando});

  final double bpm;
  final DateTime quando;
}

/// Il risultato.
class IndiceDiEffetto {
  const IndiceDiEffetto({
    required this.punti,
    required this.perGiorno,
    required this.minutiUtili,
    required this.affidabile,
  });

  /// I punti sulla finestra di sette giorni. 🎯 L'obiettivo è **100**.
  final double punti;

  /// Quanti punti ha fatto ogni giorno, dal più vecchio al più recente.
  ///
  /// 💡 Serve al grafico: un TEI a 100 fatto tutto ieri e uno spalmato su sette
  /// giorni sono la stessa cifra e due storie diverse.
  final List<double> perGiorno;

  /// I minuti che hanno prodotto punti.
  final int minutiUtili;

  /// ⛔ `false` quando i campioni di battito sono troppo radi per dire
  /// qualcosa.
  ///
  /// 🚨 **Un TEI basso e un TEI non misurabile sono due cose diverse**, e
  /// mostrarle uguali direbbe «sei fermo» a chi ha solo lasciato l'orologio nel
  /// cassetto — che è la stessa bugia consolante al contrario.
  final bool affidabile;
}

abstract final class ModelloDiEffetto {
  /// La finestra, in giorni.
  static const giorni = 7;

  /// 🎯 L'obiettivo settimanale.
  static const obiettivo = 100.0;

  /// ⚠️ **Il tetto giornaliero.** Senza, una gara di quattro ore porterebbe il
  /// TEI a 400 e per sei giorni il numero non direbbe più niente. 💡 È la stessa
  /// idea di `scaricaMassimaAlGiorno`: un indice che si può sfondare in un
  /// giorno smette di descrivere un'abitudine.
  static const tettoAlGiorno = 75.0;

  /// Sotto questa frazione della riserva non si accumula niente.
  ///
  /// ══ 🚨 ERA 0.30, E QUEL NUMERO HA PRODOTTO UN 175 ═════════════════════════
  ///
  /// 📌 Il committente, l'08/09: *«è impossibile che io stia a 175/100, mi sono
  /// allenato relativamente poco in questi giorni»*. ⛔ **Aveva ragione, e la
  /// colpa era tutta qui.**
  ///
  /// 🚨 **Il 30% della riserva non è una soglia di esercizio: è una soglia di
  /// vita.** Con un battito a riposo di 75 e una massima di 181, il 30% cade a
  /// **107 bpm** — cioè salire le scale, portare la spesa, avere fretta. Il
  /// conto ci ha trovato dentro **1.092 minuti in una settimana**: diciotto ore
  /// di «allenamento» che erano una vita normale.
  ///
  /// 💡 Il 40% cadeva a **117 bpm** per la stessa persona. 📌 Il committente:
  /// *«117 bpm secondo me sono pochi, facciamo 120 che è un valore più o meno
  /// standard»* — e **42,5% è esattamente 120 bpm** con riposo 75 e massima 181.
  ///
  /// ══ ⚠️ RESTA UNA FRAZIONE, E NON DIVENTA «120 BPM» ═══════════════════════
  ///
  /// ⛔ **Scrivere 120 secco sarebbe stato più semplice e sbagliato.** Per chi ha
  /// il riposo a 50 e la massima a 195, 120 bpm sono il 48% della riserva — uno
  /// sforzo diverso dallo stesso numero su un cuore diverso. 🚨 È la ragione per
  /// cui tutto l'indice lavora sulla **riserva di Karvonen**: rinunciarci sulla
  /// soglia vorrebbe dire tenerla dove non serve e buttarla dove conta.
  ///
  /// 💡 E il 42,5% cade dentro la fascia **moderata** dell'ACSM (40–59% della
  /// riserva): non è un numero inventato per far tornare il conto, è il
  /// principio dell'allenamento vero appena sopra il suo confine.
  ///
  /// ⛔ **Non si abbassa «perché così il numero è più incoraggiante»**: sarebbe
  /// tornare esattamente al difetto che questa riga documenta.
  static const soglia = 0.425;

  /// L'esponente e il coefficiente della curva, dalle due ancore.
  ///
  /// ══ 🚨 LE ANCORE SONO CAMBIATE, E LE VECCHIE ERANO SBAGLIATE ══════════════
  ///
  /// ⛔ Prima erano *«40 min all'85% della **riserva** = 100»* e *«150 min al
  /// 50% = 100»*, e la prima l'avevo attribuita al PAI. 🚨 **Il PAI non dice
  /// quello.** La fonte (NTNU/CERG, che il PAI l'ha inventato) dice:
  ///
  /// > *«two sessions totalling one hour of exercise to reach 100 PAI if the
  /// > intensity is at least 80% of your **maximum heart rate**»*
  ///
  /// ⚠️ **Percentuale della massima, non della riserva**: sono due grandezze
  /// diverse, e scambiarle sposta l'ancora di venti punti percentuali.
  ///
  /// 💡 Convertita per una persona tipo (riposo 60, massima 180): l'80% della
  /// massima è 144 bpm, cioè il **70% della riserva**. Da lì la prima ancora.
  ///
  /// ══ 🚨 UNA E' MISURATA, L'ALTRO E' SCELTO — E VA DETTO QUALE ═════════════
  ///
  /// | Numero | Da dove |
  /// |---|---|
  /// | **Ancora: 60 min al 70% della riserva = 100** | ✅ NTNU/CERG, convertita dall'80% della massima |
  /// | **Esponente `1.5`** | ⚠️ **Scelto da noi**, non ricavato |
  /// | **Coefficiente `11.56`** | ✅ Ricavato: è quello che fa passare la curva per l'ancora |
  ///
  /// ── ⛔ Perché l'esponente non si ricava più da una seconda ancora ─────────
  ///
  /// Prima veniva da *«200 min al 50% = 100»*, che è l'altra affermazione
  /// pubblicata. 🚨 **Con la soglia alzata a 0.425 quel sistema dà `e = 0.93`**,
  /// cioè una curva **concava**: i battiti alti varrebbero *meno* che
  /// proporzionalmente.
  ///
  /// 📌 E il committente ha chiesto l'opposto: *«i battiti alti sono più
  /// importanti di quelli medi, anche per la salute cardiaca»*. ⛔ Tenere le due
  /// ancore avrebbe voluto dire un modello che contraddice la richiesta per cui
  /// è stato rifatto.
  ///
  /// 💡 Quindi: **si tiene l'ancora forte** — quella con dietro lo studio HUNT —
  /// e la ripidità è una **nostra scelta dichiarata**. ⚠️ `1.5` è un numero
  /// tondo apposta: dice «scelto», mentre un `1.47` fingerebbe di essere il
  /// risultato di un conto.
  ///
  /// ── 📉 Cosa comporta, detto senza addolcirlo ──────────────────────────────
  ///
  /// | | Il nostro | Il PAI |
  /// |---|---|---|
  /// | 60 min al 70% | **100** | 100 |
  /// | 30 min all'85% | **~96** | meno |
  /// | 200 min al 50% | **~47** | 100 |
  ///
  /// 🚨 **Sull'attività moderata siamo la metà del PAI**, ed è voluto: è
  /// esattamente la richiesta *«i battiti alti sono più importanti di quelli
  /// medi»*. ⛔ Chi un giorno volesse riallinearsi al PAI deve rimettere
  /// `e ≈ 0.93` **e** riabbassare la soglia — non toccarne uno solo.
  static const esponente = 1.5;
  static const coefficiente = 11.56;

  /// ══ 📉 I RENDIMENTI DECRESCENTI — 08/09/2026 ═══════════════════════════
  ///
  /// 📌 Il committente: *«deve essere una rotazione settimanale in cui 100 è la
  /// perfezione»*.
  ///
  /// ⛔ **Prima non c'erano affatto**, e il PAI invece li ha: la sua fonte dice
  /// *«è più facile arrivare ai primi 50 che ai secondi 50»* e *«se ripeti lo
  /// stesso allenamento il giorno dopo, il secondo ne vale meno»*.
  ///
  /// 💡 Qui la saturazione è **sul totale della settimana**, ed è la nostra —
  /// la formula del PAI non è pubblica:
  ///
  ///     punti = tetto × (1 − e^(−grezzo / costante))
  ///
  /// 🚨 **La costante non è scelta a occhio**: è quella per cui **100 grezzi
  /// fanno esattamente 100**, cioè `100 / ln 3` con il tetto a 150. Così
  /// «cento» resta il traguardo vero e non un numero riscalato.
  ///
  /// | Grezzo | Mostrato |
  /// |---|---|
  /// | 50 | **63** — i primi punti valgono di più |
  /// | 100 | **100** — il traguardo |
  /// | 200 | **133** |
  /// | ∞ | **150**, e non oltre |
  ///
  /// ⚠️ **Superare 100 resta possibile**, ed è giusto: chi si allena molto più
  /// del minimo deve vederlo. ⛔ Ma un 175 non può più uscire da una settimana
  /// di vita normale, e un 300 non può uscire affatto.
  static const tettoAssoluto = 150.0;

  /// 🚨 Ricavata, non scelta: `obiettivo / ln(tetto / (tetto − obiettivo))`.
  static const costanteDiSaturazione = 91.02;

  /// Il punteggio mostrato, a partire da quello grezzo.
  static double conRendimentiDecrescenti(double grezzo) =>
      tettoAssoluto * (1 - math.exp(-grezzo / costanteDiSaturazione));

  /// Ogni quanti minuti, al massimo, deve arrivare un campione perché la
  /// misura valga.
  ///
  /// ══ 🚨 UNA COSTANTE PER DUE DOMANDE, ED ERA UN DIFETTO ═══════════════════
  ///
  /// ⛔ Fino all'08/09 `minutiFraCampioni` rispondeva a **due domande diverse**
  /// con lo stesso numero:
  ///
  /// 1. *quanti minuti può valere un campione?* — l'attribuzione;
  /// 2. *quanto radi possono essere i campioni prima che la misura non valga?* —
  ///    l'affidabilità.
  ///
  /// 🚨 **Abbassandolo a 3 per la prima, la seconda diventava severissima**: un
  /// orologio che campiona ogni cinque minuti sarebbe stato dichiarato
  /// inaffidabile, pur misurando benissimo. L'ha scoperto un test, che è
  /// diventato rosso per il motivo giusto.
  ///
  /// 💡 Adesso sono due.
  ///
  /// ── Quanto vale un campione ──────────────────────────────────────────────
  ///
  /// ⚠️ **Tre minuti.** L'orologio del committente campiona una volta al
  /// minuto: un buco di tre è una disattenzione del sensore, uno di dieci è
  /// l'orologio sul comodino. ⛔ Attribuire dieci minuti al battito *prima* del
  /// buco ha pesato sul 175 dell'08/09.
  static const minutiAttribuiti = 3;

  /// ── Quanto radi possono essere i campioni ────────────────────────────────
  ///
  /// ⚠️ **Dieci minuti**, e resta com'era: è la domanda *«questo orologio sta
  /// misurando?»*, non *«cosa è successo in quel buco?»*. 💡 Un campione ogni
  /// cinque minuti descrive una corsa; uno ogni mezz'ora no.
  static const minutiFraCampioni = 10;

  /// La frequenza massima stimata dall'età — **Tanaka**, non `220 − età`.
  ///
  /// 💡 `220 − età` è una regola del 1970 nata da un grafico, e sbaglia
  /// sistematicamente sugli over 40. 🚨 `208 − 0.7 × età` viene da una
  /// meta-analisi ed è quella che si usa oggi.
  ///
  /// ⚠️ Se il massimo **misurato** c'è, vince: una stima da tabella non batte
  /// mai un numero visto davvero.
  static double frequenzaMassima({required int eta, double? misurata}) =>
      misurata ?? (208 - 0.7 * eta);

  /// La frazione di **riserva** a cui si sta lavorando — Karvonen.
  ///
  /// 🚨 **Non è «battito diviso massimo»**, ed è l'errore che rende l'indice
  /// inutile: un battito a riposo di 45 e uno di 75 danno lo stesso rapporto
  /// grezzo e sforzi completamente diversi. 💡 La riserva è ciò che rende il
  /// numero **personale**, che è il punto di tutta la misura.
  static double riserva({
    required double bpm,
    required double aRiposo,
    required double massima,
  }) {
    final ampiezza = massima - aRiposo;

    // ⛔ Un riposo sopra il massimo è un dato rotto: meglio zero che una
    // divisione che esplode o, peggio, un numero enorme che sembra uno sforzo.
    if (ampiezza <= 0) return 0;

    return ((bpm - aRiposo) / ampiezza).clamp(0.0, 1.0);
  }

  /// Quanti punti vale **un minuto** a quell'intensità.
  ///
  /// 💡 Cresce più che proporzionalmente: dieci minuti forti valgono più di
  /// venti blandi, ed è esattamente ciò che la ricerca sul PAI dice.
  static double puntiAlMinuto(double frazioneDiRiserva) {
    if (frazioneDiRiserva <= soglia) return 0;

    return coefficiente * math.pow(frazioneDiRiserva - soglia, esponente);
  }

  /// Il TEI di una finestra di sette giorni.
  ///
  /// [campioni] va dal più vecchio al più recente e può avere buchi: quello che
  /// conta è **quanto distano fra loro**.
  ///
  /// ⚠️ [aRiposo] è il battito a riposo **misurato**, non una costante: è metà
  /// della riserva, ed è il numero che rende il TEI di una persona diverso da
  /// quello di un'altra a parità di corsa.
  static IndiceDiEffetto calcola({
    required List<BattitoNelTempo> campioni,
    required double aRiposo,
    required int eta,
    double? massimaMisurata,
    DateTime? adesso,
  }) {
    final fine = adesso ?? DateTime.now();
    final inizio = DateTime(
      fine.year,
      fine.month,
      fine.day,
    ).subtract(const Duration(days: giorni - 1));

    final massima = frequenzaMassima(eta: eta, misurata: massimaMisurata);

    final perGiorno = List<double>.filled(giorni, 0);
    var minutiUtili = 0;

    final dentro = campioni.where((c) => !c.quando.isBefore(inizio)).toList()
      ..sort((a, b) => a.quando.compareTo(b.quando));

    for (var i = 0; i < dentro.length; i++) {
      final c = dentro[i];

      /*
       * ⚠️ **Quanto dura questo campione**: fino al prossimo, e mai più di
       * [minutiFraCampioni]. 🚨 Senza il tetto, l'ultimo battito prima di
       * togliersi l'orologio varrebbe tutte le ore in cui l'orologio è stato sul
       * comodino.
       */
      final prossimo = i + 1 < dentro.length ? dentro[i + 1].quando : null;

      final durata = prossimo == null
          ? 1
          : math.min(prossimo.difference(c.quando).inMinutes, minutiAttribuiti);

      if (durata <= 0) continue;

      final punti =
          puntiAlMinuto(
            riserva(bpm: c.bpm, aRiposo: aRiposo, massima: massima),
          ) *
          durata;

      if (punti <= 0) continue;

      final quale = DateTime(
        c.quando.year,
        c.quando.month,
        c.quando.day,
      ).difference(inizio).inDays;

      if (quale < 0 || quale >= giorni) continue;

      perGiorno[quale] += punti;
      minutiUtili += durata;
    }

    /*
     * 🚨 **Il tetto si applica giorno per giorno, non al totale.** Applicarlo
     * alla somma lascerebbe passare una gara da 300 punti in un giorno solo, che
     * è esattamente ciò che il tetto esiste per impedire.
     */
    for (var i = 0; i < perGiorno.length; i++) {
      perGiorno[i] = math.min(perGiorno[i], tettoAlGiorno);
    }

    /*
     * 📉 **I rendimenti decrescenti si applicano al TOTALE, non ai giorni.**
     *
     * 🚨 Applicarli giorno per giorno vorrebbe dire che sette giorni da 20
     * grezzi fanno più di un giorno da 140 — cioè premiare la costanza due
     * volte, visto che il tetto giornaliero già la premia una.
     *
     * 💡 `perGiorno` resta **grezzo**: serve al grafico, e un grafico di valori
     * saturati non si sommerebbe più a quello che c'è scritto sopra.
     */
    final grezzo = perGiorno.fold<double>(0, (a, b) => a + b);

    return IndiceDiEffetto(
      punti: conRendimentiDecrescenti(grezzo),
      perGiorno: perGiorno,
      minutiUtili: minutiUtili,
      affidabile: _abbastanzaFitti(dentro),
    );
  }

  /// Se i campioni sono abbastanza fitti da dire qualcosa.
  ///
  /// ══ 🚨 UN TEI BASSO E UN TEI NON MISURABILE SONO DUE COSE DIVERSE ══════
  ///
  /// ⛔ Con un battito ogni due ore il conto **esce lo stesso**, e viene basso:
  /// si direbbe «sei fermo» a chi magari ha corso, solo perché l'orologio non
  /// stava guardando. 💡 È la stessa regola per cui `calorieAttive` a `null` non
  /// diventa zero.
  ///
  /// ⚠️ La soglia è **la mediana degli intervalli**, non la media: un solo buco
  /// di otto ore — la notte, che c'è sempre — sposterebbe la media e boccerebbe
  /// una giornata misurata benissimo.
  static bool _abbastanzaFitti(List<BattitoNelTempo> campioni) {
    if (campioni.length < 30) return false;

    final intervalli = <int>[];

    for (var i = 1; i < campioni.length; i++) {
      intervalli.add(
        campioni[i].quando.difference(campioni[i - 1].quando).inMinutes,
      );
    }

    intervalli.sort();

    return intervalli[intervalli.length ~/ 2] <= minutiFraCampioni;
  }
}
