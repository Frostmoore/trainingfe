/// Il saldo calorico di un giorno, e la media di un periodo — 3b-F, 26/08/2026.
///
/// ══ 📌 LA SEGNALAZIONE, E LA CORREZIONE ALLA CORREZIONE ═══════════════════
///
/// *«se passo il dito sull'ultimo giorno mi dice che sono sotto di 570 kcal. Le
/// calorie effettivamente consumate sono 2259 e quelle bruciate 2403»*.
///
/// ⛔ **La prima risposta era sbagliata, e l'ha corretta il committente**: avevo
/// chiamato «doppio conteggio» la somma `TDEE + allenamento`, e ho fatto il
/// saldo sul **BMR**. 📌 La sua obiezione: *«il TDEE è il consumo ad attività
/// praticamente 0 (1.2) … riguarda la vita quotidiana di un uomo che sta seduto
/// al pc a lavorare e magari si fa una passeggiata la sera dopo cena, non ha
/// nulla a che vedere con gli allenamenti»*.
///
/// ══ 🚨 CHI HA RAGIONE, E PERCHE' DIPENDE DAL LIVELLO SCELTO ═══════════════
///
/// Il PAL della letteratura è **`TEE / BMR`**: per definizione contiene *tutto*,
/// allenamenti compresi. Quello che distingue i gradini è **quanto** sport
/// contengono, ed è scritto nelle loro descrizioni standard:
///
/// | Fattore | Descrizione standard | Gli allenamenti |
/// |---|---|---|
/// | **1.2** | *sedentario, poco o nessun esercizio* | ⛔ **non ci sono** |
/// | 1.375 | esercizio leggero 1-3 giorni a settimana | ✅ dentro |
/// | 1.55 | esercizio moderato 3-5 giorni | ✅ dentro |
/// | 1.725 | esercizio intenso 6-7 giorni | ✅ dentro |
/// | 1.9 | due sedute al giorno, o lavoro fisico | ✅ dentro |
///
/// 💡 Quindi **su 1.2 il committente ha ragione**: il suo TDEE descrive la vita
/// da scrivania, e le calorie dell'allenamento vanno **sommate**. È il metodo
/// additivo, lo stesso che usa MyFitnessPal, ed è **più preciso giorno per
/// giorno** — il PAL spalma gli allenamenti sulla settimana, quindi sottostima
/// i giorni in cui ci si allena e sovrastima quelli di riposo.
///
/// ⛔ **Ma vale solo su 1.2.** Chi sceglie «moderato (3-4 allenamenti)» ha già
/// dichiarato quegli allenamenti dentro il fattore: sommargli sopra quelli
/// misurati li conta due volte. ⏳ Sta nel piano come decisione aperta.
library;

import 'package:flutter/foundation.dart';

import 'ui/widgets/barra_del_consumo.dart';

/// Quanto si è mangiato oltre quello che si è **davvero** speso.
///
/// 💡 Positivo = surplus, negativo = deficit.
///
/// ⚠️ `consumo` è il **TDEE**, cioè la vita quotidiana, e va passato **già
/// mappato sull'ora** per il giorno in corso — vedi [consumoFinora]. 🚨 Non si
/// mappa qui dentro: questa funzione non sa che giorno sta guardando, e
/// indovinarlo è il modo in cui nascono due conteggi diversi per la stessa cosa.
double saldoDelGiorno({
  required double assunte,
  required double consumo,
  required double allenamento,
}) => assunte - (consumo + allenamento);

/// Il consumo di un giorno: intero se è passato, fino a **adesso** se è oggi.
///
/// 🚨 **Il confronto dev'essere fra grandezze dello stesso momento.** Le calorie
/// assunte oggi sono quelle di finora; metterle contro ventiquattro ore di
/// consumo dichiara un deficit che è soltanto la giornata non ancora finita.
double consumoDelGiorno({
  required double tdee,
  required DateTime giorno,
  required DateTime adesso,
}) {
  final eOggi =
      giorno.year == adesso.year &&
      giorno.month == adesso.month &&
      giorno.day == adesso.day;

  return eOggi ? consumoFinora(kcalDelGiorno: tdee, adesso: adesso) : tdee;
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
/// ══ ⚠️ IL CONFRONTO E' COL CONSUMO, NON CON L'OBIETTIVO ═══════════════════
///
/// 🚨 «Deficit» e «surplus» vogliono dire *rispetto a quanto spendi*, non
/// rispetto a quanto ti eri ripromesso. ⛔ Chi ha un obiettivo di dimagrimento
/// del 20% e lo centra ogni giorno è a **zero** rispetto all'obiettivo e a
/// **−20%** rispetto al consumo: il secondo numero è quello che diventa peso, ed
/// è quello che la parola «deficit» promette a chi la legge.
///
/// 💡 Il riquadro del dito invece parla dell'**obiettivo**, perché quella è la
/// linea di base del grafico. ⚠️ Sono due domande diverse, e le risposte portano
/// scritto a cosa si riferiscono.
///
/// ══ ⛔ DUE GIORNI NON ENTRANO, E SONO DUE REGOLE DIVERSE ══════════════════
///
/// 1. 🚨 **Un giorno senza diario si salta, non vale zero.** Con `assunte = 0` il
///    saldo sarebbe `−(consumo + allenamento)`, cioè un digiuno completo: su tre
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
  required List<double> allenamento,
  required double tdee,
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
      consumo: tdee,
      allenamento: i < allenamento.length ? allenamento[i] : 0.0,
    );

    contati++;
  }

  if (contati == 0) return null;

  return SaldoMedio(kcalAlGiorno: totale / contati, giorni: contati);
}
