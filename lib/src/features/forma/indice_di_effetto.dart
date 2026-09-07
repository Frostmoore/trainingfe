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
  /// 💡 Il 30% è più o meno stare in piedi a fare le cose: se contasse, il TEI
  /// lo farebbe anche chi dorme dodici ore e cammina fino al bar.
  static const soglia = 0.30;

  /// L'esponente e il coefficiente della curva, dalle due ancore.
  ///
  /// 🚨 **Non si toccano separatamente.** Sono la soluzione di un sistema a due
  /// equazioni: cambiarne uno solo sposta la curva senza più passare per
  /// nessuna delle due ancore, e a quel punto i numeri non vengono più da
  /// nessuna parte.
  static const esponente = 1.31;
  static const coefficiente = 5.56;

  /// Ogni quanti minuti, al massimo, deve arrivare un campione perché la
  /// misura valga.
  ///
  /// ⚠️ **Dieci minuti**: un campione ogni mezz'ora non dice cosa è successo in
  /// mezzo, e attribuirgli trenta minuti della sua intensità inventerebbe
  /// mezz'ora di corsa da un battito preso mentre si saliva una rampa di scale.
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
          : math.min(
              prossimo.difference(c.quando).inMinutes,
              minutiFraCampioni,
            );

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

    return IndiceDiEffetto(
      punti: perGiorno.fold<double>(0, (a, b) => a + b),
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
