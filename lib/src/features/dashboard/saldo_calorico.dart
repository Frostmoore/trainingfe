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

/// Quanto si è mangiato oltre l'obiettivo del giorno.
///
/// 💡 Positivo = sopra il target, negativo = sotto.
///
/// ══ ⚠️ SUL TARGET, NON SUL CONSUMO — 3b-F.8, 26/08/2026 ═══════════════════
///
/// 📌 *«si dovrebbe capire che è deficit e surplus rispetto AL TARGET, non
/// rispetto alla giornata vera»*.
///
/// 🚨 **E la parola «deficit» è sparita da qui**, di proposito: in palestra
/// vuol dire *rispetto a quanto spendi*, e usarla per la distanza da un
/// obiettivo è esattamente l'ambiguità che il committente stava segnalando.
/// ⛔ Un numero senza il suo riferimento scritto accanto non è un numero, è
/// un'impressione.
///
/// ⚠️ **L'obiettivo lo compone `TargetDelGiorno`**, quindi qui dentro le
/// bruciate ci sono già o no a seconda dell'interruttore. Non si sommano una
/// seconda volta.
double saldoDelGiorno({required double assunte, required double obiettivo}) =>
    assunte - obiettivo;

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

  /// Positivo = **sopra** il target in media, negativo = sotto.
  final double kcalAlGiorno;

  /// Su quanti giorni è calcolata.
  ///
  /// 🚨 **Il contesto della media è parte della media**: «340 di deficit» su due
  /// giorni su sette non è lo stesso numero che su sette, e senza dirlo si legge
  /// come se lo fosse.
  final int giorni;

  /// ⚠️ Si chiama `sotto` e **non `deficit`**: «deficit» in palestra vuol dire
  /// *rispetto a quanto spendi*, e questo è rispetto al target.
  bool get sotto => kcalAlGiorno < 0;
}

/// La media dei saldi di un periodo, **sui soli giorni completi e con diario**.
///
/// ══ ⚠️ E' LA DISTANZA DAL TARGET ══════════════════════════════════════════
///
/// 📌 *«si dovrebbe capire che è deficit e surplus rispetto AL TARGET, non
/// rispetto alla giornata vera»*.
///
/// 💡 Risponde a *«sto seguendo quello che mi ero ripromesso?»*, che è la
/// stessa domanda del riquadro del dito — solo mediata sul periodo invece che
/// su un giorno. ⚠️ **Non** risponde a «sto dimagrendo, e di quanto»: per
/// quello servirebbe il confronto col consumo, ed è un'altra cosa (vedi
/// 3b-F.8.3 nel piano, dove sta scritto perché i grammi a settimana sono spariti
/// da questa riga).
///
/// ══ ⛔ DUE GIORNI NON ENTRANO, E SONO DUE REGOLE DIVERSE ══════════════════
///
/// 1. 🚨 **Un giorno senza diario si salta, non vale zero.** Con `assunte = 0`
///    il saldo sarebbe `−obiettivo`, cioè un digiuno completo: su tre giorni
///    saltati fanno una media da fame che non è successa. ⚠️ È la stessa regola
///    di `pesoDalSaldo`, e lì è già costata una discussione.
/// 2. ⛔ **Oggi non entra**, perché non è finito. Un pomeriggio a metà entra in
///    media come una giornata intera e la tira verso il basso — 💡 e il giorno
///    dopo lo stesso numero cambia da solo, il che è il modo più rapido per far
///    smettere di fidarsi di una media.
///
/// ⚠️ `null` quando non resta nessun giorno: la media di niente non è zero, è
/// assente.
SaldoMedio? saldoMedioDelPeriodo({
  required List<DateTime> giorni,
  required List<double> assunte,
  required List<double> obiettivi,
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
    final obiettivo = i < obiettivi.length ? obiettivi[i] : 0.0;

    // ⛔ Nessun diario, o nessun obiettivo: si salta. Vedi la nota qui sopra.
    if (mangiate <= 0 || obiettivo <= 0) continue;

    totale += saldoDelGiorno(assunte: mangiate, obiettivo: obiettivo);
    contati++;
  }

  if (contati == 0) return null;

  return SaldoMedio(kcalAlGiorno: totale / contati, giorni: contati);
}
