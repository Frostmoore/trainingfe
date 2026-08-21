import 'package:flutter/foundation.dart';

/// Le calorie di un allenamento, calcolate **sul telefono** — FASE 11.2,
/// 21/08/2026.
///
/// ══ 🚨 È UN TRASPORTO, NON UNA RISCRITTURA ════════════════════════════════
///
/// 📌 Regola del piano (`plan_tutto_sul_telefono.md` R2, ripresa in 11.2.1):
/// *«trasportare, non reinventare»*.
///
/// Questo file è la traduzione in Dart di
/// `trainingbe/app/Services/Training/WorkoutCalorieService.php`. ⚠️ **Se un
/// numero cambia è un difetto, non un arrotondamento diverso**: i test portano
/// gli stessi valori dei test PHP, ed è l'unico modo di accorgersi di aver
/// tradotto male.
///
/// ── 💡 Perché la formula esiste, visto che c'è l'AI ──────────────────────
///
/// 📌 Il committente, 15/08/2026: *«Per stimare le calorie di un allenamento
/// non serve l'AI, è un calcolo matematico quindi offloadiamolo al server.
/// Sarebbe uno spreco perché i dati li abbiamo tutti»*. Aveva ragione allora, e
/// vale ancora adesso che «il server» è diventato «il telefono».
///
/// 🚨 E non è una formula rozza: il MET si legge **esercizio per esercizio** —
/// 120 su 121 del catalogo ce l'hanno, da 3.0 a 11.0 — quindi una seduta di
/// squat e stacchi pesa già più di una di bicipiti, senza chiedere niente a
/// nessuno.
@immutable
class CalorieAllenamento {
  const CalorieAllenamento._();

  /// Il MET di ripiego, per una seduta di soli esercizi senza MET.
  ///
  /// ⚠️ **Prudente di proposito**: sovrastimare le calorie bruciate porta la
  /// persona a mangiare di più credendo di essere in deficit.
  static const met = 5.0;

  /// Il peso di ripiego, quando non se ne conosce nessuno.
  static const pesoDiRipiego = 75.0;

  /// `MET × kg × ore`, arrotondato.
  ///
  /// 💡 Una seduta **senza serie registrate** vale comunque la durata: chi si è
  /// allenato senza segnare niente ha comunque bruciato qualcosa.
  ///
  /// ⛔ Durata nulla o negativa → `0`. Non è un caso limite teorico: è la seduta
  /// aperta e chiusa per sbaglio nello stesso minuto.
  static int formula({
    required Duration durata,
    required double kg,
    required double metMedio,
  }) {
    final ore = durata.inSeconds / 3600;

    if (ore <= 0) return 0;

    return (metMedio * kg * ore).round();
  }

  /// Il MET medio della seduta, letto **serie per serie**.
  ///
  /// ⚠️ I MET nulli o non positivi **non entrano nella media**: contarli come
  /// zero abbasserebbe il risultato di una seduta mista, che è peggio che
  /// ignorarli. 💡 Se non ne resta nessuno, vince [met].
  static double metMedio(Iterable<double?> metDelleSerie) {
    final validi = metDelleSerie
        .whereType<double>()
        .where((m) => m > 0)
        .toList(growable: false);

    if (validi.isEmpty) return met;

    return validi.reduce((a, b) => a + b) / validi.length;
  }

  /// Il numero da mostrare per una seduta.
  ///
  /// 🚨 **Ordine**: quello che è **salvato** vince — qualunque ne sia la fonte —
  /// e solo se non c'è niente si applica la formula.
  ///
  /// ⛔ E non chiama nessuno: è una lettura, e una lettura che fa una chiamata a
  /// pagamento è una trappola per chiunque la usi dentro un ciclo.
  static int kcalDi({
    required int? kcalSalvate,
    required Duration durata,
    required double kg,
    required Iterable<double?> metDelleSerie,
  }) {
    if (kcalSalvate != null) return kcalSalvate;

    return formula(durata: durata, kg: kg, metMedio: metMedio(metDelleSerie));
  }

  /// Le calorie bruciate in un giorno.
  ///
  /// ══ 🚨 IL VALORE A MANO VINCE E **NON SI SOMMA** ════════════════════════
  ///
  /// È una dichiarazione complessiva («oggi ho bruciato 800»), non un
  /// contributo. ⚠️ Sommarlo alle sedute **raddoppierebbe la giornata di chi
  /// corregge il numero dopo essersi allenato** — e il numero resterebbe
  /// credibile, quindi nessuno se ne accorgerebbe.
  ///
  /// 💡 `null` in [aMano] vuol dire «non ha dichiarato niente», e allora si
  /// sommano le sedute. Uno `0` dichiarato è invece una dichiarazione vera —
  /// «oggi fermo» — e vince come qualunque altra.
  static int bruciateDelGiorno({
    required int? aMano,
    required Iterable<int> kcalDelleSedute,
  }) {
    if (aMano != null) return aMano;

    var totale = 0;
    for (final k in kcalDelleSedute) {
      totale += k;
    }

    return totale;
  }
}
