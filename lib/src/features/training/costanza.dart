/// Quanto sei costante, e quanto sei allenato — 3b-B.10, 24/08/2026.
///
/// ══ 📌 LA RICHIESTA, PER ESTESO ═══════════════════════════════════════════
///
/// > *«sulla parte superiore ci dovrebbe essere un valore percentuale che indica
/// > la mia costanza negli allenamenti questo mese. Il valore deve tenere in
/// > considerazione la frequenza e le discrepanze nella frequenza (ad esempio:
/// > tre allenamenti a settimana per 4 settimane, tutti di lunedì, mercoledì e
/// > venerdì = alta costanza, differenze nel numero di sessioni tra una
/// > settimana e l'altra o variazioni ampie dei giorni in cui mi sono allenato =
/// > bassa costanza). Inoltre, dovrebbe esserci un numero che mi dice quanto
/// > sono allenato, tenendo in considerazione le calorie bruciate di ciascun
/// > allenamento, da quanto mi alleno con una certa costanza e quanti
/// > allenamenti ho effettivamente fatto»*.
///
/// ══ 🚨 COSA VIENE DA UNA FONTE E COSA È UNA NOSTRA SCELTA ═════════════════
///
/// ⛔ La distinzione va tenuta esplicita, o fra sei mesi nessuno saprà più quale
/// numero si può difendere citando qualcuno e quale invece l'abbiamo deciso noi.
///
/// | Pezzo | Da dove viene |
/// |---|---|
/// | **Quanto sei allenato** | **CTL**, media mobile esponenziale a 42 giorni del carico giornaliero (Banister/TrainingPeaks). `α = 2/(n+1)` |
/// | Discrepanza fra settimane | **coefficiente di variazione**, statistica ordinaria |
/// | Ripetersi dei giorni | **indice di Jaccard** fra gli insiemi dei giorni di settimane vicine |
/// | I tre pesi (40/30/30) e l'obiettivo di 3 sedute | **nostri**, e sono dichiarati qui sotto |
///
/// 💡 Una formula per «quanto sei allenato» **esiste davvero** ed è quella:
/// `CTL(oggi) = α · carico(oggi) + (1 − α) · CTL(ieri)`, con `n = 42` giorni.
/// Sale piano e scende piano, quindi risponde da sola a tutte e tre le cose
/// chieste — **quante** sessioni, **quanto** erano intense e **da quanto** vai
/// avanti — senza che nessuna delle tre vada pesata a mano.
///
/// ⛔ Per la **costanza** una formula canonica non esiste: quello che si trova è
/// la *monotonia* di Foster, che misura una cosa diversa e per cui alto è
/// **male**. ⚠️ Quindi qui la costanza è composta da noi con pezzi standard, e
/// ogni pezzo dice cosa misura.
///
/// ══ ⚠️ TUTTO RESTA SUL TELEFONO ═══════════════════════════════════════════
///
/// 🚨 Questi due numeri si calcolano dalle calorie e dalle date degli
/// allenamenti, e **le calorie bruciate non escono dal telefono**: sono un dato
/// della persona. Qui non si scrive niente da nessuna parte — si legge lo
/// storico che c'è già e si restituisce un numero.
library;

import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/storico_unificato.dart';
import 'settimana_scelta.dart';
import 'storico_unificato_controller.dart';

/// L'obiettivo di sedute a settimana oltre il quale la frequenza vale pieno.
///
/// 📌 **Tre**, ed è il numero dell'esempio del committente: *«tre allenamenti a
/// settimana per 4 settimane … = alta costanza»*. 💡 Coincide anche con la
/// raccomandazione corrente sull'allenamento di forza (2-3 volte a settimana),
/// il che vuol dire che non è un numero campato in aria — ma la ragione per cui
/// sta qui è la prima.
///
/// ⚠️ Oltre non si guadagna: chi si allena sei volte a settimana **non è il
/// doppio di costante** di chi ne fa tre. Sarebbe più allenato, e quello lo dice
/// l'altro numero.
const double sedutePerSettimana = 3;

/// Quanto pesa ciascun pezzo nella costanza.
///
/// ⛔ **Sono scelte nostre, e stanno qui perché si vedano.** La frequenza pesa
/// più delle due regolarità perché chi non si allena non è costante — per quanto
/// regolarmente non lo faccia. ⚠️ Le due regolarità pesano uguale fra loro: il
/// committente le ha nominate come due esempi della stessa cosa.
const double pesoFrequenza = 0.4;
const double pesoRegolaritaNumero = 0.3;
const double pesoRegolaritaGiorni = 0.3;

/// Quanto sei costante, e da cosa viene.
///
/// 💡 I tre pezzi sono esposti **uno per uno** e non solo il totale: un «61%»
/// da solo non dice se il problema è che ti alleni poco o che ti alleni a caso,
/// e sono due consigli opposti.
class Costanza {
  const Costanza({
    required this.settimane,
    required this.sedute,
    required this.seduteASettimana,
    required this.regolaritaNumero,
    required this.regolaritaGiorni,
  });

  /// Le settimane **finite** considerate.
  final int settimane;

  /// Le sedute dentro quelle settimane.
  final int sedute;

  /// La media di sedute a settimana.
  final double seduteASettimana;

  /// Quanto il **numero** di sedute si ripete, da 0 a 1 — `1 − CV`.
  final double regolaritaNumero;

  /// Quanto si ripetono **i giorni**, da 0 a 1 — Jaccard fra settimane vicine.
  final double regolaritaGiorni;

  /// Quanto vale la frequenza, da 0 a 1.
  double get frequenza =>
      (seduteASettimana / sedutePerSettimana).clamp(0.0, 1.0);

  /// La costanza, da 0 a 1.
  double get valore =>
      frequenza * pesoFrequenza +
      regolaritaNumero * pesoRegolaritaNumero +
      regolaritaGiorni * pesoRegolaritaGiorni;

  int get percentuale => (valore * 100).round();

  /// ⛔ **Con meno di due settimane finite non si può dire niente.**
  ///
  /// 🚨 «Discrepanza fra le settimane» su **una** settimana non esiste: il
  /// coefficiente di variazione di un numero solo è zero, e verrebbe fuori una
  /// regolarità perfetta il 2 del mese. ⚠️ Sarebbe il difetto di sempre — un
  /// numero che sembra informato — quindi qui si tace.
  bool get siPuoDire => settimane >= 2;

  static const vuota = Costanza(
    settimane: 0,
    sedute: 0,
    seduteASettimana: 0,
    regolaritaNumero: 0,
    regolaritaGiorni: 0,
  );
}

/// La costanza del mese di [mese], guardando le settimane **già finite**.
///
/// ── ⚠️ Perché solo quelle finite ──────────────────────────────────────────
///
/// ⛔ La settimana in corso ha pochi giorni e quasi sempre poche sedute:
/// contarla schiaccerebbe la percentuale ogni lunedì e la farebbe risalire ogni
/// domenica. 🚨 Sarebbe un numero che **oscilla per come è fatto il calendario**,
/// non per come ti alleni — e chi lo guarda non ha modo di saperlo.
///
/// ── ⛔ E perché solo quelle INTERAMENTE dentro il mese ────────────────────
///
/// 🚨 **Trovato da un test, non a mente.** Prima bastava che la settimana
/// *cominciasse* nel mese: giugno 2026 comincia di lunedì, quindi la quinta
/// settimana partiva il 29 e finiva il 5 di luglio.
///
/// ⚠️ Il guaio è che le sedute arrivano qui **già filtrate per mese**: di quella
/// settimana si vedevano solo i giorni di giugno, e i cinque di luglio no. La
/// settimana risultava quasi vuota **per costruzione**, e trascinava giù la
/// costanza di chiunque si allenasse regolarmente a cavallo del mese.
///
/// 💡 Una settimana entra solo se ci sta **tutta**: lunedì e domenica dentro lo
/// stesso mese. ⛔ Così si perde qualche giorno ai bordi — è il prezzo, ed è
/// preferibile a una settimana raccontata a metà.
Costanza costanzaDelMese({
  required Iterable<VoceStorico> voci,
  required DateTime mese,
  required DateTime adesso,
}) {
  final primo = DateTime(mese.year, mese.month);
  final dopoUltimo = DateTime(mese.year, mese.month + 1);

  // ── Le settimane finite che cominciano dentro il mese ────────────────────
  final settimane = <DateTime>[];

  for (
    var lunedi = lunediDi(primo);
    lunedi.isBefore(dopoUltimo);
    lunedi = lunedi.add(const Duration(days: 7))
  ) {
    if (lunedi.isBefore(primo)) continue;

    final fine = lunedi.add(const Duration(days: 7));

    // ⛔ Tutta dentro il mese, e già finita. Vedi le due note qui sopra.
    if (fine.isAfter(dopoUltimo)) continue;

    if (!fine.isAfter(adesso)) settimane.add(lunedi);
  }

  if (settimane.length < 2) {
    return Costanza(
      settimane: settimane.length,
      sedute: 0,
      seduteASettimana: 0,
      regolaritaNumero: 0,
      regolaritaGiorni: 0,
    );
  }

  // ── Quante sedute, e in che giorni, settimana per settimana ──────────────
  final quante = List<int>.filled(settimane.length, 0);
  final giorni = List<Set<int>>.generate(settimane.length, (_) => <int>{});

  for (final v in voci) {
    for (var i = 0; i < settimane.length; i++) {
      final da = settimane[i];
      final a = da.add(const Duration(days: 7));

      if (v.quando.isBefore(da) || !v.quando.isBefore(a)) continue;

      quante[i]++;
      giorni[i].add(v.quando.weekday);
      break;
    }
  }

  final totale = quante.fold<int>(0, (a, b) => a + b);
  final media = totale / settimane.length;

  /*
   * ── La discrepanza nel NUMERO: coefficiente di variazione ────────────────
   *
   * 💡 `CV = deviazione standard / media`, e la costanza è `1 − CV`. ⚠️ Il CV e
   * non la deviazione standard nuda: due sedute di scarto su una media di tre
   * sono tantissimo, su una media di venti sono niente — e una misura che non
   * lo sa direbbe la stessa cosa nei due casi.
   *
   * ⛔ Il CV può superare 1 (settimane a zero e settimane piene), quindi il
   * risultato si taglia: una «regolarità negativa» non vuol dire niente.
   */
  var regolaritaNumero = 0.0;

  if (media > 0) {
    final varianza =
        quante
            .map((n) => (n - media) * (n - media))
            .fold<double>(0, (a, b) => a + b) /
        settimane.length;

    regolaritaNumero = (1 - math.sqrt(varianza) / media).clamp(0.0, 1.0);
  }

  /*
   * ── La discrepanza nei GIORNI: Jaccard fra settimane vicine ──────────────
   *
   * ══ 🚨 PERCHÉ NON LA CONCENTRAZIONE SU UN GIORNO ═════════════════════════
   *
   * ⛔ La misura ovvia — «quanto le sedute si addensano su pochi giorni» —
   * sarebbe **sbagliata proprio sull'esempio del committente**: lunedì, mercoledì
   * e venerdì sono tre giorni sparsi, e una misura di concentrazione direbbe
   * «poco costante» a chi è l'esempio stesso della costanza.
   *
   * 💡 Quello che conta non è *dove* cadono, è che **si ripetano**: Jaccard fra
   * l'insieme dei giorni di una settimana e quello della successiva. Lun-Mer-Ven
   * seguito da Lun-Mer-Ven fa 1; Lun-Mer-Ven seguito da Mar-Sab fa 0.
   *
   * ⚠️ Due settimane **entrambe vuote** valgono 0 e non 1: sono identiche, ma
   * premiare la regolarità del non allenarsi sarebbe una presa in giro.
   */
  var somma = 0.0;

  for (var i = 1; i < settimane.length; i++) {
    final a = giorni[i - 1];
    final b = giorni[i];

    if (a.isEmpty && b.isEmpty) continue;

    somma += a.intersection(b).length / a.union(b).length;
  }

  return Costanza(
    settimane: settimane.length,
    sedute: totale,
    seduteASettimana: media,
    regolaritaNumero: regolaritaNumero,
    regolaritaGiorni: somma / (settimane.length - 1),
  );
}

/// Il tempo caratteristico di «quanto sei allenato», in giorni.
///
/// 📌 **42**, come nel modello di Banister e come lo usa TrainingPeaks per la
/// *Chronic Training Load*. 💡 Sei settimane: è il tempo che un cambio di
/// abitudini ci mette a farsi sentire davvero, e il motivo per cui questo numero
/// non schizza dopo un allenamento né crolla dopo una settimana di stop.
const int giorniDellaForma = 42;

/// Quante calorie valgono un punto di forma.
///
/// ⛔ **Questa è una scelta nostra**, e va detto: la formula originale lavora in
/// unità di carico (TSS/TRIMP) che si calcolano dalla frequenza cardiaca, e noi
/// abbiamo le calorie. 💡 Dieci kcal per punto mette un allenamento serio da 500
/// kcal intorno ai 50 punti, che è l'ordine di grandezza in cui la scala
/// originale è stata pensata — così i numeri che si leggono in giro restano
/// confrontabili con questo.
const double kcalPerPunto = 10;

/// Quanto sei allenato: la media mobile esponenziale del carico, a 42 giorni.
///
/// ── 🚨 La formula, per esteso ─────────────────────────────────────────────
///
/// `F(oggi) = α · carico(oggi) + (1 − α) · F(ieri)`, con `α = 2/(n+1)` e
/// `n = 42`, quindi `α ≈ 0,0465`.
///
/// 💡 **Risponde da sola a tutte e tre le cose chieste**: le calorie di ogni
/// allenamento sono il carico del giorno, «quanti allenamenti» è quanti giorni
/// hanno un carico, e «da quanto ti alleni con una certa costanza» è il fatto
/// che la media sia *esponenziale* — un mese fa pesa ancora, tre mesi fa no.
///
/// ⚠️ **Parte da zero**, e nei primi giorni il numero è basso perché la storia è
/// corta. ⛔ Farlo partire dalla media del periodo sarebbe una scorciatoia che
/// racconta una forma che non c'è ancora.
///
/// 🚨 Un allenamento **senza calorie non conta**, e non si inventa: non c'è
/// niente da cui dedurle senza sceglierne il valore noi.
int quantoSeiAllenato({
  required Iterable<VoceStorico> voci,
  required DateTime adesso,
}) {
  final oggi = DateTime(adesso.year, adesso.month, adesso.day);
  final da = oggi.subtract(const Duration(days: giorniDellaForma - 1));

  final carico = <DateTime, double>{};

  for (final v in voci) {
    final k = v.kcal;

    if (k == null || k <= 0) continue;

    final giorno = DateTime(v.quando.year, v.quando.month, v.quando.day);

    if (giorno.isBefore(da) || giorno.isAfter(oggi)) continue;

    carico[giorno] = (carico[giorno] ?? 0) + k / kcalPerPunto;
  }

  const alfa = 2 / (giorniDellaForma + 1);
  var forma = 0.0;

  for (var g = da; !g.isAfter(oggi); g = g.add(const Duration(days: 1))) {
    /*
     * ⚠️ **Si passa da tutti i giorni, anche quelli vuoti.** Un giorno senza
     * allenamento ha carico zero e **abbassa** la media: saltarlo vorrebbe dire
     * che chi si allena una volta al mese ha la stessa forma di chi si allena
     * ogni giorno, perché entrambi avrebbero solo giorni pieni nel conto.
     */
    forma =
        alfa * (carico[DateTime(g.year, g.month, g.day)] ?? 0) +
        (1 - alfa) * forma;
  }

  return forma.round();
}

/// La costanza del mese scelto.
final costanzaDelMeseProvider = Provider.family<Costanza, DateTime>((
  ref,
  mese,
) {
  final voci = ref.watch(storicoUnificatoProvider).valueOrNull ?? const [];

  return costanzaDelMese(
    voci: voci.where(
      (v) => v.quando.year == mese.year && v.quando.month == mese.month,
    ),
    mese: mese,
    adesso: DateTime.now(),
  );
});

/// Quanto sei allenato **adesso**.
///
/// ⚠️ Non prende il mese: la forma è un fatto di oggi, e guarda **indietro** di
/// sei settimane a prescindere da quale mese si sta guardando. 💡 Guardare
/// marzo non deve far comparire la forma che avevi a marzo accanto a un
/// calendario di marzo: sarebbero due numeri veri che insieme dicono una cosa
/// falsa.
final quantoSeiAllenatoProvider = Provider<int>((ref) {
  final voci = ref.watch(storicoUnificatoProvider).valueOrNull ?? const [];

  return quantoSeiAllenato(voci: voci, adesso: DateTime.now());
});
