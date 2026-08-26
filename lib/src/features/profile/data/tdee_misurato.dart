/// Il TDEE **misurato** sui dati veri, invece che stimato — 3b-G.8, 26/08/2026.
///
/// ══ 🚨 PERCHE' ESISTE ═════════════════════════════════════════════════════
///
/// Il 26/08 il gradino di attività del committente è stato scelto facendo **a
/// mano** un conto sui suoi dati: assunte medie, peso perso, allenamenti. ⛔ Se
/// quel conto l'app lo sa fare da sola, la domanda «quale tabella di fattori?»
/// smette di esistere.
///
/// 💡 **Il problema non è quale tabella scegliere: è che una tabella non può
/// sapere.** Nessun numero medio descrive una persona — la fascia FAO diceva
/// 1,50 e la misura ha detto 1,2.
///
/// ══ 📐 LA FORMULA ═════════════════════════════════════════════════════════
///
///     TDEE = media(assunte) + (kg persi × 7.700 / giorni)
///
/// Se hai mangiato 1.800 al giorno e in 30 giorni hai perso 2 kg, hai speso
/// `1.800 + 2×7.700/30 = 2.313`.
///
/// ══ ⚠️ E PERCHE' SERVONO QUATTRO SETTIMANE ════════════════════════════════
///
/// 🚨 **La soglia è aritmetica, non estetica.** L'incertezza è dominata dal
/// rumore della bilancia, e si divide per i giorni:
///
/// | Giorni | Mezzo chilo di rumore vale |
/// |---|---|
/// | 10 | ±385 kcal/giorno |
/// | 30 | ±128 kcal/giorno |
/// | 60 | ±64 kcal/giorno |
///
/// ⛔ Sotto le quattro settimane il numero misurato è **peggio** della tabella,
/// non meglio: sembra preciso perché è specifico, ed è la peggiore combinazione
/// possibile su un numero che decide cosa mangi.
library;

import 'package:flutter/foundation.dart';

/// Le kcal in un chilo di grasso — la costante di sempre.
const kcalPerChilo = 7700.0;

/// Il rumore residuo sul peso, dopo aver mediato tre pesate per estremo.
///
/// ⚠️ Una singola pesata oscilla di ±1 kg fra acqua, glicogeno e intestino.
/// 💡 Mediandone tre resta circa **mezzo etto per quattro**: 0,4 kg è prudente,
/// e la prudenza qui vuol dire dichiarare un'incertezza più grande, non più
/// piccola.
const rumoreDelPesoKg = 0.4;

/// Quanti giorni servono perché la misura valga più della stima.
const giorniMinimi = 28;

/// Quanta parte del periodo deve avere il diario.
///
/// 🚨 **Chi non segna non segna a caso**: si smette di segnare nei giorni in cui
/// si è mangiato di più. ⛔ Con troppi buchi la media delle assunte è
/// sottostimata, e quindi il TDEE misurato pure — cioè si finisce per mangiare
/// meno di quanto si dovrebbe, credendo di avere una misura.
const coperturaMinima = 0.7;

/// Una pesata: il giorno e i chili.
@immutable
class Pesata {
  const Pesata({required this.giorno, required this.kg});

  final DateTime giorno;
  final double kg;
}

/// L'esito della misura — **o il motivo per cui non si può fare**.
@immutable
class TdeeMisurato {
  const TdeeMisurato._({
    required this.kcal,
    required this.incertezza,
    required this.giorni,
    required this.giorniConDiario,
    required this.kgPersi,
  }) : motivo = null;

  const TdeeMisurato._impossibile(this.motivo)
    : kcal = 0,
      incertezza = 0,
      giorni = 0,
      giorniConDiario = 0,
      kgPersi = 0;

  /// Il dispendio misurato, kcal al giorno.
  final double kcal;

  /// Il ± da mostrare **sempre accanto al numero**.
  ///
  /// 🚨 Un numero senza la sua incertezza si legge come esatto, e questo esatto
  /// non è: dirlo nudo sarebbe la stessa bugia della tabella, con l'aggravante
  /// di sembrare una misura.
  final double incertezza;

  final int giorni;
  final int giorniConDiario;

  /// Positivo se il peso è **sceso**.
  final double kgPersi;

  /// `null` quando la misura c'è. Altrimenti dice cosa manca, per esteso.
  final String? motivo;

  bool get riuscita => motivo == null;

  /// Quanta parte del periodo ha il diario.
  double get copertura => giorni == 0 ? 0 : giorniConDiario / giorni;
}

/// La media dei chili di un gruppo di pesate.
double _mediaKg(List<Pesata> p) =>
    p.map((x) => x.kg).reduce((a, b) => a + b) / p.length;

/// Il giorno medio di un gruppo di pesate.
DateTime _giornoMedio(List<Pesata> p) => DateTime.fromMillisecondsSinceEpoch(
  p.map((x) => x.giorno.millisecondsSinceEpoch).reduce((a, b) => a + b) ~/
      p.length,
);

/// Misura il dispendio dai dati veri.
///
/// [assunte] è indicizzata come [giorni]; uno **zero vuol dire «non segnato»**,
/// non «digiuno» — è la stessa convenzione di `saldoMedioDelPeriodo`, e qui
/// contarlo davvero produrrebbe un TDEE più basso del vero.
///
/// ⚠️ Servono almeno **due pesate lontane fra loro**: senza, non c'è nessuna
/// variazione di peso da cui ricavare lo scarto fra mangiato e speso.
TdeeMisurato misuraIlTdee({
  required List<DateTime> giorni,
  required List<double> assunte,
  required List<Pesata> pesate,
}) {
  if (pesate.length < 2) {
    return const TdeeMisurato._impossibile(
      'servono almeno due pesate: senza, non c\'è nessuna variazione da cui '
      'ricavare quanto hai speso',
    );
  }

  final ordinate = [...pesate]..sort((a, b) => a.giorno.compareTo(b.giorno));

  /*
   * 💡 Tre pesate per estremo, non una: una pesata singola porta dentro tutta
   * l'acqua di quel giorno, e su trenta giorni un chilo di acqua vale 256 kcal
   * al giorno di errore. ⚠️ Se ce ne sono meno di sei in tutto si prende quello
   * che c'è, senza mai far sovrapporre i due gruppi.
   */
  final quante = ordinate.length >= 6 ? 3 : 1;

  final prime = ordinate.take(quante).toList();
  final ultime = ordinate.reversed.take(quante).toList();

  final inizio = _giornoMedio(prime);
  final fine = _giornoMedio(ultime);

  final giorniVeri = fine.difference(inizio).inDays;

  if (giorniVeri < giorniMinimi) {
    return TdeeMisurato._impossibile(
      'il periodo fra le pesate è di $giorniVeri giorni: sotto i '
      '$giorniMinimi il rumore della bilancia conta più di quello che stai '
      'misurando',
    );
  }

  // ── Le assunte dei giorni dentro la finestra, saltando i buchi ──────────
  var somma = 0.0;
  var conDiario = 0;

  for (var i = 0; i < giorni.length && i < assunte.length; i++) {
    final g = giorni[i];

    if (g.isBefore(inizio) || g.isAfter(fine)) continue;
    if (assunte[i] <= 0) continue;

    somma += assunte[i];
    conDiario++;
  }

  if (conDiario == 0) {
    return const TdeeMisurato._impossibile(
      'in questo periodo non c\'è nessun giorno di diario',
    );
  }

  final copertura = conDiario / giorniVeri;

  if (copertura < coperturaMinima) {
    return TdeeMisurato._impossibile(
      'hai segnato $conDiario giorni su $giorniVeri: con troppi buchi la media '
      'di quello che mangi è più bassa del vero, e la misura pure',
    );
  }

  final kgPersi = _mediaKg(prime) - _mediaKg(ultime);

  return TdeeMisurato._(
    kcal: somma / conDiario + kgPersi * kcalPerChilo / giorniVeri,
    incertezza: rumoreDelPesoKg * kcalPerChilo / giorniVeri,
    giorni: giorniVeri,
    giorniConDiario: conDiario,
    kgPersi: kgPersi,
  );
}
