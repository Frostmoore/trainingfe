/// Le calorie di una sorgente sono **nette o lorde**? — 3b-G.4, 26/08/2026.
///
/// ══ 📌 LA DOMANDA ═════════════════════════════════════════════════════════
///
/// *«non si può fare un semplice calcolo che determini se effettivamente mi
/// arrivano le calorie lorde o nette, con i dati che riceviamo?»* — e poi, per
/// tutti gli orologi e non solo per il suo.
///
/// ⚠️ **Vale 80-130 kcal a seduta.** Un'ora di palestra a 96 kg fa ~80 kcal di
/// metabolismo basale: se la sorgente le ha già dentro e noi le sommiamo
/// all'obiettivo, quelle 80 diventano permesso di mangiare che non c'è.
///
/// ══ 🚨 I TRE CONTROLLI CHE FUNZIONANO ═════════════════════════════════════
///
/// Sono **certezze logiche**, non statistica: ognuno, quando scatta, chiude la
/// questione per quella sorgente **per sempre**.
///
/// | # | Controllo | Perché è decisivo |
/// |---|---|---|
/// | 1 | Una finestra **sotto il basale della sua durata** | un lordo non può stare sotto il metabolismo di quei minuti |
/// | 2 | Una finestra **notturna a ritmo basale** | dormendo il netto è ~0; se vale 70 kcal l'ora, è lordo |
/// | 3 | `totale del giorno − attive del giorno ≈ basale` | se la differenza è il basale, le attive sono nette |
///
/// ══ ⛔ E I DUE CHE NON FUNZIONANO, SCRITTI PERCHE' NON SI RIPROVINO ═══════
///
/// 1. **Il residuo del giorno.** Con un'ora di finestre, la differenza fra netto
///    e lordo è ~75 kcal su ~1.700: il **4%**, cioè dentro il rumore di
///    qualunque stima di basale.
/// 2. **Il confronto col MET.** Il segnale sarebbe del 10-20%, il rumore degli
///    algoritmi a frequenza cardiaca è del ±30%. 🚨 Cercarlo lì non è una misura
///    imprecisa: è **un'illusione di misura**, che è peggio.
///
/// ══ ⚠️ E IL CASO INDECIDIBILE ESISTE ══════════════════════════════════════
///
/// Una sorgente che scrive **un numero per allenamento e nient'altro** non dà
/// nessun appiglio: l'informazione non è nei dati. ⛔ Lì «non lo so» dev'essere
/// **uno stato vero**, non collassato in silenzio su una delle due letture — è
/// lo stesso difetto dello zero che sembra un conto.
///
/// 💡 Il ripiego dichiarato: **ci si fida del campo**. `ActiveCaloriesBurned` per
/// contratto è netto, e chi lo riempie di lordo sta sbagliando lui.
library;

import 'package:flutter/foundation.dart';

/// Come vanno lette le calorie di una sorgente.
enum LetturaCalorie {
  /// Solo lo sforzo: si somma all'obiettivo così com'è.
  netta,

  /// Comprende il metabolismo basale di quei minuti: va tolto.
  lorda,

  /// 🚨 Uno stato vero, non un caso da riempire.
  nonSiSa,
}

/// Il verdetto su una sorgente, **con il motivo scritto**.
///
/// 💡 Il motivo non è decorazione: fra sei mesi qualcuno vorrà sapere perché
/// l'app toglie 80 kcal alle sedute di un certo orologio, e «lo dice la
/// cascata» non è una risposta.
@immutable
class VerdettoCalorie {
  const VerdettoCalorie({required this.lettura, required this.motivo});

  final LetturaCalorie lettura;
  final String motivo;
}

/// Una finestra misurata: quanto è durata e quante calorie le sono state date.
@immutable
class FinestraMisurata {
  const FinestraMisurata({
    required this.inizio,
    required this.durata,
    required this.kcal,
  });

  final DateTime inizio;
  final Duration durata;
  final int kcal;

  /// ⚠️ Fra le 23 e le 6: è lì che il netto e il lordo sono più lontani.
  bool get eNotturna => inizio.hour >= 23 || inizio.hour < 6;
}

/// Le kcal di metabolismo basale in un intervallo.
double basaleIn(Duration durata, double bmr) =>
    bmr * durata.inSeconds / Duration.secondsPerDay;

/// Quanto si può stare sotto il basale prima di dire «è netta».
///
/// ⚠️ Non zero: il BMR è **una stima** (Mifflin sbaglia del ±10% sui singoli), e
/// un margine stretto darebbe verdetti sicuri su una base che sicura non è.
const _margine = 0.85;

/// Quanto due valori possono discostarsi per dirli «uguali» nel controllo 3.
const _tolleranzaBasale = 0.25;

/// La durata minima perché una finestra notturna dica qualcosa.
const _notteUtile = Duration(minutes: 30);

/// La cascata — 3b-G.4.
///
/// 🚨 **L'ordine conta**: i primi due sono certezze logiche su una singola
/// finestra, il terzo è un confronto fra totali e ha più rumore. Il primo che
/// scatta vince.
VerdettoCalorie giudicaLaSorgente({
  required List<FinestraMisurata> finestre,
  required double bmr,
  int? totaleDelGiorno,
  int? attiveDelGiorno,
}) {
  if (bmr <= 0) {
    return const VerdettoCalorie(
      lettura: LetturaCalorie.nonSiSa,
      motivo: 'senza metabolismo basale non c\'è niente con cui confrontare',
    );
  }

  // ── 1. Sotto il basale della sua durata ⇒ NETTA ────────────────────────
  for (final f in finestre) {
    if (f.durata <= Duration.zero || f.kcal <= 0) continue;

    final basale = basaleIn(f.durata, bmr);

    if (f.kcal < basale * _margine) {
      return VerdettoCalorie(
        lettura: LetturaCalorie.netta,
        motivo:
            '${f.kcal} kcal in ${f.durata.inMinutes} minuti, dove il solo '
            'basale ne farebbe ${basale.round()}: un lordo non può starci '
            'sotto',
      );
    }
  }

  // ── 2. Notturna a ritmo basale ⇒ LORDA ─────────────────────────────────
  for (final f in finestre) {
    if (!f.eNotturna || f.durata < _notteUtile) continue;

    final basale = basaleIn(f.durata, bmr);

    if (basale <= 0) continue;

    final rapporto = f.kcal / basale;

    if (rapporto > 1 - _tolleranzaBasale && rapporto < 1 + _tolleranzaBasale) {
      return VerdettoCalorie(
        lettura: LetturaCalorie.lorda,
        motivo:
            '${f.durata.inMinutes} minuti di notte valgono ${f.kcal} kcal, '
            'cioè il basale di quei minuti: dormendo il netto sarebbe ~0',
      );
    }
  }

  // ── 3. Totale − attive ≈ basale ⇒ le attive sono NETTE ─────────────────
  if (totaleDelGiorno != null && attiveDelGiorno != null) {
    final differenza = totaleDelGiorno - attiveDelGiorno;

    if (differenza > 0) {
      final rapporto = differenza / bmr;

      if (rapporto > 1 - _tolleranzaBasale &&
          rapporto < 1 + _tolleranzaBasale) {
        return VerdettoCalorie(
          lettura: LetturaCalorie.netta,
          motivo:
              '$totaleDelGiorno − $attiveDelGiorno = $differenza, cioè circa '
              'il basale (${bmr.round()}): le attive non lo contengono',
        );
      }
    }
  }

  return const VerdettoCalorie(
    lettura: LetturaCalorie.nonSiSa,
    motivo:
        'nessun controllo ha trovato una prova: ci si fida del campo, che per '
        'contratto è netto',
  );
}

/// Quello che si sa già di alcune sorgenti — 3b-G.4.6.
///
/// ⚠️ **È un punto di partenza, non una sentenza**: i controlli automatici, se
/// trovano una prova, vincono. 🚨 Serve a coprire il caso indecidibile con
/// qualcosa di meglio di un'alzata di spalle, e a far scoprire — invece che
/// subire — l'aggiornamento di firmware che cambia le carte.
///
/// 💡 `zepp` è **verificato sui dati veri** il 26/08: un record da 6 Cal su 11
/// minuti, dove il solo basale ne farebbe ~14.
const noteSulleSorgenti = <String, LetturaCalorie>{
  'com.huami.watch.hmwatchmanager': LetturaCalorie.netta,
  'com.xiaomi.wearable': LetturaCalorie.netta,
  'com.google.android.apps.fitness': LetturaCalorie.netta,
  'com.garmin.android.apps.connectmobile': LetturaCalorie.netta,
  'com.samsung.android.health': LetturaCalorie.netta,
};

/// Le calorie di una seduta **portate al netto**, se serve.
///
/// ⚠️ Con [LetturaCalorie.nonSiSa] non si tocca niente: il ripiego dichiarato è
/// fidarsi del campo. ⛔ Sottrarre «per sicurezza» vorrebbe dire togliere cibo a
/// chi non ha fatto niente di sbagliato, sulla base di un sospetto.
///
/// 🚨 Non scende mai sotto zero: una sottrazione che porta in negativo vuol dire
/// che la premessa era sbagliata, non che la seduta è costata meno di niente.
int kcalNetteDellaSeduta({
  required int kcal,
  required Duration durata,
  required double? bmr,
  required LetturaCalorie lettura,
}) {
  if (lettura != LetturaCalorie.lorda || bmr == null || bmr <= 0) return kcal;

  final netto = kcal - basaleIn(durata, bmr).round();

  return netto > 0 ? netto : 0;
}
