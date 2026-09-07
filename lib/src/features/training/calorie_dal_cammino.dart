/// Le calorie del **movimento quotidiano**, stimate dai passi — 07/09/2026.
///
/// ══ 🚨 PERCHE' ESISTE: L'OROLOGIO NON LE SCRIVE ═══════════════════════════
///
/// La sonda del 07/09/2026 (`sonda_delle_attive.dart`) ha guardato Health
/// Connect per due giorni e ha trovato:
///
///     ATTIVE nessun campione
///     PASSI  319 campioni · da orologio e telefono
///
/// ⛔ **Zero calorie attive.** Non «solo dentro l'allenamento», come diceva il
/// commento del 26/08 in `bruciate_dalle_sedute.dart`: **niente del tutto**. I
/// 269 kcal che il committente vede li calcola l'app dell'orologio e non li
/// scrive mai fuori.
///
/// 💡 I passi invece ci sono, e sono fitti. Quindi la stima del movimento
/// quotidiano si fa da lì — è l'unico segnale che abbiamo, ed è un buon segnale.
///
/// ══ 📐 LA FORMULA, E DA DOVE VIENE ════════════════════════════════════════
///
///     km   = passi × falcata
///     kcal = [costoAlKgPerKm] × peso_kg × km
///
/// 🚨 **Il costo è NETTO, non lordo.** Camminare costa circa 1 kcal per kg e per
/// chilometro *in tutto*, ma metà di quella spesa è il metabolismo basale che
/// sarebbe avvenuto comunque, stando fermi. ⛔ Il nostro obiettivo calorico è già
/// un **TDEE**, che il basale ce l'ha dentro: usare il lordo lo conterebbe due
/// volte — lo stesso difetto per cui non si legge mai
/// `TOTAL_CALORIES_BURNED`.
///
/// ⚠️ **Il conto torna con la realtà, ed è la ragione per cui ci si può
/// fidare**: 8.500 passi, 175 cm, 87 kg danno ~268 kcal — e l'orologio del
/// committente, quel giorno, ne diceva **269**.
library;

abstract final class CalorieDalCammino {
  /// Il costo **netto** del cammino, in kcal per kg e per km.
  ///
  /// 💡 La letteratura sul costo energetico del cammino in piano dà un lordo
  /// intorno a `1.0` e un netto fra `0.5` e `0.6`. 🚨 Si prende **il basso**
  /// dell'intervallo: una stima che sbaglia per difetto toglie qualche caloria
  /// dall'obiettivo, una che sbaglia per eccesso ne regala — e qui il numero
  /// decide **quanto qualcuno può mangiare**.
  static const costoAlKgPerKm = 0.5;

  /// La falcata come frazione dell'altezza.
  ///
  /// 💡 `0.415` è il rapporto usato normalmente per il passo di cammino: su
  /// 175 cm fa 72,6 cm.
  ///
  /// ⚠️ È una **media**: chi cammina piano fa passi più corti e chi corre più
  /// lunghi. 🚨 Ma l'errore che introduce è dell'ordine del 10%, mentre non
  /// stimare niente è un errore del 100% — ed è quello che c'è oggi.
  static const frazioneDellAltezza = 0.415;

  /// L'altezza di ripiego, in cm, quando il profilo non ce l'ha.
  ///
  /// ⚠️ **Non si rinuncia alla stima per un'altezza mancante**: il peso conta
  /// molto di più, e una falcata media sbagliata di qualche centimetro sposta il
  /// risultato meno di quanto lo sposti non contare le calorie affatto.
  static const altezzaDiRipiego = 170.0;

  /// Il peso di ripiego, in kg.
  ///
  /// 🚨 **Prudente**, come `CalorieAllenamento.pesoDiRipiego`: chi non si è mai
  /// pesato non deve ricevere un margine calorico generoso basato su un peso
  /// inventato al rialzo.
  static const pesoDiRipiego = 70.0;

  /// Sotto questi passi non si stima niente.
  ///
  /// ⛔ **Cinquecento passi non sono «movimento quotidiano»**: sono andare in
  /// bagno e tornare. 💡 Stimare venti calorie da lì darebbe un numero
  /// preciso su un rumore.
  static const passiMinimi = 500;

  /// Quanti km valgono quei passi.
  static double km({required int passi, double? altezzaCm}) =>
      passi *
      ((altezzaCm ?? altezzaDiRipiego) / 100) *
      frazioneDellAltezza /
      1000;

  /// Le calorie **nette** del cammino di una giornata.
  ///
  /// ⚠️ [passi] devono essere quelli **fuori dagli allenamenti**
  /// (`ArchivioSalute.passiFuoriDagliAllenamenti`). 🚨 Quelli fatti correndo
  /// hanno già le loro calorie, dall'orologio o dalla formula sui MET: contarli
  /// anche qui li sommerebbe a se stessi.
  ///
  /// 📌 Il committente: *«è vero che i passi vengono conteggiati nell'esercizio,
  /// ma solo per quanto riguarda le calorie bruciate DURANTE quell'esercizio;
  /// per il resto della giornata cammino lo stesso»*.
  static int kcal({required int passi, double? pesoKg, double? altezzaCm}) {
    if (passi < passiMinimi) return 0;

    final distanza = km(passi: passi, altezzaCm: altezzaCm);

    return (costoAlKgPerKm * (pesoKg ?? pesoDiRipiego) * distanza).round();
  }
}
