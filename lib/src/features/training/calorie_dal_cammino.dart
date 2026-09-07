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
/// ══ ⛔ QUESTA FORMULA NON E' ANCORA STATA VERIFICATA SUL VERO ═════════════
///
/// 🚨 **E qui c'era scritto il contrario.** Il 07/09/2026 questo commento
/// diceva: *«il conto torna con la realtà: 8.500 passi, 175 cm, 87 kg danno
/// ~268 kcal — e l'orologio del committente ne diceva 269»*.
///
/// ⛔ **Non era una verifica.** Peso e altezza venivano dal **profilo demo del
/// PDF di prova** (*«uomo di 30 anni, 1.75 m, 85 kg»*), non dal committente —
/// che ne pesa **95/96**; e i passi di quel giorno non erano stati misurati, ma
/// scelti. 💡 Due incognite adattate a una sola osservazione danno sempre un
/// risultato che «torna»: è il modo classico di scambiare un'ipotesi per una
/// prova.
///
/// ⚠️ **Con i numeri veri il conto resta plausibile** — a 95 kg servono circa
/// 7.400–7.800 passi per fare 269 kcal, che è una giornata normale — ma
/// *plausibile* non è *verificato*.
///
/// ══ ✅ E ADESSO LA VERIFICA C'E' — 07/09/2026 ═════════════════════════════
///
/// I tre ingredienti che mancavano sono arrivati insieme:
///
///   1. **i passi veri**, dall'aggregato di Health Connect (non da una somma
///      di record grezzi, e non scelti da me): il **06/09** erano **8.192**;
///   2. **il peso vero**, dichiarato dal committente: **95/96 kg**;
///   3. **il numero dell'orologio quello stesso giorno**: **269 kcal**.
///
/// | altezza | stima | scarto |
/// |---|---|---|
/// | 170 cm | 275 kcal | **+2%** |
/// | 175 cm | 283 kcal | +5% |
/// | 180 cm | 291 kcal | +8% |
///
/// 💡 **Fra il 2% e l'8% a seconda dell'altezza**, e sempre per **eccesso**.
/// ⚠️ Non e' una coincidenza costruita a posteriori: gli ingredienti sono stati
/// misurati **prima** di guardare il risultato, e nessuno di loro e' stato
/// scelto per farlo tornare.
///
/// 🚨 **Resta una stima**, e la banda dice quanto: un errore dell'8% su 270 kcal
/// sono venti calorie, che nell'obiettivo giornaliero non spostano niente. ⛔ Ma
/// se un giorno la falcata o il costo al kg venissero cambiati, e' questo il
/// confronto da rifare — non un numero inventato.
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
