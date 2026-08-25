/// Il saldo calorico di un giorno, e la media di un periodo — 3b-F, 26/08/2026.
///
/// ══ 📌 LA SEGNALAZIONE ════════════════════════════════════════════════════
///
/// *«nella card delle calorie in fondo alla schermata oggi, non capisco che
/// calcoli vengono fatti … se passo il dito sull'ultimo giorno mi dice che sono
/// sotto di 570 kcal. Le calorie effettivamente consumate sono 2259 e quelle
/// bruciate 2403 (secondo la prima card delle calorie), quindi non capisco bene
/// cosa stia succedendo»*.
///
/// ══ 🚨 AVEVA RAGIONE: IL MOVIMENTO SI CONTAVA DUE VOLTE ═══════════════════
///
/// ⛔ Il riquadro del dito calcolava `assunte − TDEE − attive`.
///
/// 🚨 **Il TDEE è `BMR × fattore di attività`** (1.2 sedentario, 1.55 attivo…):
/// dentro c'è **già** una previsione di quanto ti muovi in un giorno. Togliergli
/// sopra le calorie attive **misurate** conta lo stesso movimento due volte —
/// una prevista e una vera.
///
/// ⚠️ **E la trappola era già scritta**, in cima a `barra_del_consumo.dart`:
/// *«Mappare il TDEE sull'ora conterebbe due volte il movimento»*. La barra la
/// evitava, il grafico ci è cascato — 💡 due schermate della stessa pagina, e la
/// regola scritta in una sola delle due.
///
/// ── 🔢 I conti della segnalazione, che tornano esatti ─────────────────────
///
/// | | Formula | Valore |
/// |---|---|---|
/// | la prima card | `BMR fino a adesso + attive` | 2403 |
/// | il riquadro del dito | `assunte − TDEE − attive` | −570 |
/// | quello che si aspettava | `assunte − bruciate` | −144 |
///
/// 🚨 Lo scarto fra i due — **426 kcal** — non è un caso: è esattamente
/// `TDEE − (BMR fino a adesso)`, cioè **il margine di attività già dentro il
/// TDEE** più il basale che il giorno non ha ancora bruciato.
///
/// ── ⚠️ E c'era un secondo scarto, più piccolo e più insidioso ─────────────
///
/// ⛔ Il riquadro confrontava le assunte **di adesso** con il TDEE **di tutta la
/// giornata**: alle sei del pomeriggio dichiarava un deficit che era solo la
/// giornata non ancora finita. 💡 Su un giorno passato è giusto usare il basale
/// intero; su oggi va mappato sull'ora, come fa la barra.
library;

import 'package:flutter/foundation.dart';

import 'ui/widgets/barra_del_consumo.dart';

/// Quanto si è mangiato oltre quello che si è **davvero** bruciato.
///
/// 💡 Positivo = surplus, negativo = deficit.
///
/// ⚠️ `basale` va passato **già mappato sull'ora** per il giorno in corso — vedi
/// [basaleFinora] — e intero per i giorni passati. 🚨 Non si mappa qui dentro:
/// questa funzione non sa che giorno sta guardando, e indovinarlo è esattamente
/// il modo in cui nascono i due conteggi diversi che si stanno correggendo.
double saldoDelGiorno({
  required double assunte,
  required double basale,
  required double attive,
}) => assunte - (basale + attive);

/// Il basale di un giorno: intero se è passato, fino a **adesso** se è oggi.
///
/// 🚨 **Il confronto dev'essere fra grandezze dello stesso momento.** Le calorie
/// assunte oggi sono quelle di finora; metterle contro il basale di ventiquattro
/// ore dichiara un deficit che è soltanto la giornata non ancora finita.
double basaleDelGiorno({
  required double bmr,
  required DateTime giorno,
  required DateTime adesso,
}) {
  final eOggi =
      giorno.year == adesso.year &&
      giorno.month == adesso.month &&
      giorno.day == adesso.day;

  return eOggi ? basaleFinora(bmr: bmr, adesso: adesso) : bmr;
}

/// La media dei saldi di un periodo.
@immutable
class SaldoMedio {
  const SaldoMedio({required this.kcalAlGiorno, required this.giorni});

  /// Positivo = surplus medio, negativo = deficit medio.
  final double kcalAlGiorno;

  /// Su quanti giorni è calcolata.
  ///
  /// 🚨 **Il contesto della media è parte della media**: «340 di deficit» su due
  /// giorni su sette non è lo stesso numero che su sette, e senza dirlo si legge
  /// come se lo fosse.
  final int giorni;

  bool get deficit => kcalAlGiorno < 0;
}

/// Il saldo medio di un periodo, **sui soli giorni completi e con diario**.
///
/// ══ ⛔ DUE GIORNI NON ENTRANO, E SONO DUE REGOLE DIVERSE ══════════════════
///
/// 1. 🚨 **Un giorno senza diario si salta, non vale zero.** Con `assunte = 0` il
///    saldo sarebbe `−(basale + attive)`, cioè un digiuno completo: su tre
///    giorni saltati fanno una media da fame che non è successa. ⚠️ È la stessa
///    regola di `pesoDalSaldo`, e lì è già costata una discussione.
/// 2. ⛔ **Oggi non entra**, perché non è finito. Un pomeriggio a metà entra in
///    media come una giornata intera e la tira verso il deficit — 💡 e il giorno
///    dopo lo stesso numero cambia da solo, il che è il modo più rapido per far
///    smettere di fidarsi di una media.
///
/// ⚠️ `null` quando non resta nessun giorno: la media di niente non è zero, è
/// assente.
SaldoMedio? saldoMedioDelPeriodo({
  required List<DateTime> giorni,
  required List<double> assunte,
  required List<double> attive,
  required double bmr,
  required DateTime adesso,
}) {
  var totale = 0.0;
  var contati = 0;

  for (var i = 0; i < giorni.length; i++) {
    final giorno = giorni[i];

    // ⛔ Oggi e il futuro: non sono giornate finite.
    if (!giorno.isBefore(DateTime(adesso.year, adesso.month, adesso.day))) {
      continue;
    }

    final mangiate = i < assunte.length ? assunte[i] : 0.0;

    // ⛔ Nessun diario: si salta. Vedi la nota qui sopra.
    if (mangiate <= 0) continue;

    totale += saldoDelGiorno(
      assunte: mangiate,
      basale: bmr,
      attive: i < attive.length ? attive[i] : 0.0,
    );

    contati++;
  }

  if (contati == 0) return null;

  return SaldoMedio(kcalAlGiorno: totale / contati, giorni: contati);
}
