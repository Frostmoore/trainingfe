/// Le bruciate del giorno prese dalle **sedute**, non dal flusso — 3b-G.3.
///
/// ══ 📌 PERCHE' SI CAMBIA SORGENTE ═════════════════════════════════════════
///
/// Fino al 26/08 il numero veniva dal **flusso giornaliero** delle calorie
/// attive (`ACTIVE_ENERGY_BURNED` di tutta la giornata). ⚠️ Sullo Zepp del
/// committente non cambia niente — verificato: scrive **solo** la finestra della
/// sessione, e nient'altro in tutto il giorno.
///
/// ⛔ **Ma su altri orologi sì, e parecchio.** Garmin, Fitbit e Samsung scrivono
/// nel flusso anche il movimento di tutti i giorni: la camminata fino al bar, le
/// scale, la spesa. 🚨 Nel modello «misurata» quel movimento è **già dentro il
/// fattore di attività quotidiana**, e sommarlo di nuovo lo conterebbe due
/// volte — cioè esattamente il difetto che la 3b-G esiste per chiudere,
/// riaperto da un'altra porta.
///
/// 💡 La seduta invece vuol dire la stessa cosa su tutti gli orologi: **è
/// l'allenamento**, quello che hai deciso di fare e hai avviato.
///
/// ══ 🚨 IL CONFINE, DICHIARATO ═════════════════════════════════════════════
///
/// 📌 *«Per quanto riguarda il 3 non me ne frega un cazzo, va bene così»* — il
/// movimento voluto che **non** è una sessione (18.000 passi senza avviare
/// niente) resta fuori. ⚠️ È una scelta, non una dimenticanza: sta scritta qui
/// perché fra un anno sembrerà un difetto a qualcuno.
library;

import '../../core/storage/archivio_salute.dart';
import 'netto_o_lordo.dart';

/// Quanto vale una seduta: la correzione a mano, se c'è, altrimenti la misura.
///
/// ⚠️ `null` vuol dire **«non lo so»**, non zero: quelle senza numero hanno la
/// loro strada — la stima dai MET in `bruciateLocaliProvider`, che entra come
/// «stima» nella catena. 🚨 Contarle zero qui le farebbe sparire da tutte e due.
int? kcalDellaSeduta(AllenamentoDaOrologio a) => a.kcalCorrette ?? a.kcal;

/// Se due sedute sono lo stesso allenamento visto da due sorgenti.
///
/// 📌 La regola larga di **D-1bis/A**, 20/08: basta **un istante** di
/// sovrapposizione. 💡 Chi si allena col telefono e l'orologio produce due
/// registrazioni della stessa ora, e sommarle raddoppierebbe la seduta.
bool siSovrappongono(AllenamentoDaOrologio a, AllenamentoDaOrologio b) =>
    a.iniziatoIl.isBefore(b.finitoIl) && b.iniziatoIl.isBefore(a.finitoIl);

/// Le calorie delle sedute di un giorno, **senza contarne una due volte**.
///
/// ══ ⚠️ LA REGOLA PER DUE SORGENTI E' QUELLA DI CASA ═══════════════════════
///
/// Dentro un gruppo di sedute sovrapposte: si somma **per sorgente**, e poi si
/// prende la **più alta**. 💡 È la stessa regola di `kcalAttiveDi` — *«due
/// sorgenti non si sommano: vince la più alta»* — e riusarla invece di
/// inventarne un'altra è il motivo per cui le due schermate non possono
/// discordare.
///
/// ⛔ **`nascosto` esce**: è il doppione di una seduta registrata col player, e
/// quella passa dalla sua strada.
/// ⛔ **`staccato` fa gruppo da solo**: è il gesto con cui qualcuno ha detto
/// «questo non si unisce a nessuno», e ignorarlo qui vorrebbe dire che il gesto
/// funziona nello storico e non nel conto delle calorie.
/// [bmr] serve solo alla correzione **netto/lordo** di 3b-G.4: se la sorgente
/// è nota per scrivere calorie lorde, si toglie il basale di quei minuti.
///
/// ⚠️ **Oggi non cambia niente per nessuna sorgente conosciuta** — tutte quelle
/// in `noteSulleSorgenti` scrivono netto — e va bene così: la macchina c'è, la
/// tabella dice quello che sappiamo, e il giorno che compare un orologio che
/// scrive lordo non si riscrive niente.
///
/// ⛔ `null` non corregge. Il ripiego dichiarato è **fidarsi del campo**:
/// sottrarre «per sicurezza» vorrebbe dire togliere cibo a qualcuno sulla base
/// di un sospetto.
int kcalDelleSedute(List<AllenamentoDaOrologio> sedute, {double? bmr}) {
  final buone = sedute.where((a) => !a.nascosto).toList()
    ..sort((a, b) => a.iniziatoIl.compareTo(b.iniziatoIl));

  final gruppi = <List<AllenamentoDaOrologio>>[];

  for (final a in buone) {
    if (a.staccato) {
      gruppi.add([a]);
      continue;
    }

    final gruppo = gruppi.firstWhere(
      (g) => g.any((b) => !b.staccato && siSovrappongono(a, b)),
      orElse: () {
        final nuovo = <AllenamentoDaOrologio>[];
        gruppi.add(nuovo);

        return nuovo;
      },
    );

    gruppo.add(a);
  }

  var totale = 0;

  for (final gruppo in gruppi) {
    final perSorgente = <String, int>{};

    for (final a in gruppo) {
      final kcal = kcalDellaSeduta(a);

      if (kcal == null || kcal <= 0) continue;

      final netto = kcalNetteDellaSeduta(
        kcal: kcal,
        durata: a.finitoIl.difference(a.iniziatoIl),
        bmr: bmr,
        lettura: noteSulleSorgenti[a.fonte] ?? LetturaCalorie.nonSiSa,
      );

      perSorgente[a.fonte] = (perSorgente[a.fonte] ?? 0) + netto;
    }

    if (perSorgente.isEmpty) continue;

    totale += perSorgente.values.reduce((a, b) => a > b ? a : b);
  }

  return totale;
}
