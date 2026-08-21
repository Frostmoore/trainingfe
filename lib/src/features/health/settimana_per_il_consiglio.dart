import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../training/storico_unificato_controller.dart';
import 'analizzatore_sonno.dart';
import 'dati_salute.dart';
import 'health_controller.dart';
import 'tipo_allenamento.dart';

/// La settimana che il consiglio del giorno deve vedere — 20/08/2026.
///
/// ══ 🚨 IL DIFETTO CHE CHIUDE ═══════════════════════════════════════════════
///
/// Il committente, leggendo il consiglio: *«non vede il mio allenamento di ieri
/// (dice che non mi alleno da un po')»* e *«non è vero che di solito dormo
/// bene»*.
///
/// Erano **due difetti con la stessa radice**: il modello riceveva **una notte
/// sola** e **zero allenamenti dell'orologio**, e da lì tirava a indovinare
/// tutto il resto.
///
/// ⚠️ Un modello a cui manca il contesto **non tace**: lo inventa. «Dormi bene
/// di solito» non era un errore del modello — era l'unica frase possibile per
/// chi non ha mai visto le altre sei notti.
///
/// 💡 Per questo la risposta non è «scrivi un prompt migliore»: è **dargli i
/// dati che stava supplendo**.
///
/// ── 🚨 E gli allenamenti adesso partono davvero ───────────────────────────
///
/// Stamattina la decisione era: al consiglio vanno solo le sedute registrate
/// nell'app. ⚠️ **La conseguenza si è vista in un giorno**: chi si allena con
/// l'orologio e non apre il player risulta uno che non si allena — e il consiglio
/// glielo dice.
///
/// 📌 Il committente l'ha ribaltata la sera stessa: *«allenamenti dell'ultima
/// settimana con tipo e kcal bruciate»*. 🚨 Quindi da qui parte **anche** quello
/// che l'orologio ha registrato da solo, e T17 e §3.3-ter sono stati riscritti
/// di conseguenza.
class SettimanaPerIlConsiglio {
  const SettimanaPerIlConsiglio({
    required this.notti,
    required this.hrv,
    required this.battito,
    required this.allenamenti,
  });

  /// Le ultime notti, dalla più recente. `null` dove non c'è una notte.
  final List<Map<String, Object>> notti;

  /// Media per giorno di HRV e battito a riposo.
  final List<Map<String, Object>> hrv;
  final List<Map<String, Object>> battito;

  /// Gli allenamenti della settimana, **da qualunque fonte**.
  final List<Map<String, Object>> allenamenti;

  /// I nomi sono quelli della lista bianca del server.
  ///
  /// ⚠️ Quello che non ha esattamente questi nomi **non parte**, e non lo dice a
  /// nessuno.
  Map<String, Object> get payload => {
    if (notti.isNotEmpty) 'week_sleep': notti,
    if (hrv.isNotEmpty) 'week_hrv': hrv,
    if (battito.isNotEmpty) 'week_resting_hr': battito,
    if (allenamenti.isNotEmpty) 'week_workouts': allenamenti,
  };
}

/// Quanti giorni indietro. **Sette**, come chiesto.
const _giorni = 7;

/// 💡 `d/M` e non l'ISO: al modello serve sapere «martedì 19», non il
/// millisecondo, e ogni carattere in meno è un token in meno per una cosa che
/// viene ripetuta sette volte.
String _giorno(DateTime d) => '${d.day}/${d.month}';

final settimanaPerIlConsiglioProvider =
    FutureProvider.autoDispose<SettimanaPerIlConsiglio>((ref) async {
      final archivio = ref.watch(archivioSaluteProvider);
      final oggi = DateTime.now();

      // ── Le notti ────────────────────────────────────────────────────────────
      final notti = <Map<String, Object>>[];

      for (var i = 0; i < _giorni; i++) {
        final quale = DateTime(
          oggi.year,
          oggi.month,
          oggi.day,
        ).subtract(Duration(days: i));

        final n = await AnalizzatoreSonno.notte(archivio, quale);

        /*
     * ⚠️ **I buchi non si riempiono.** Una notte senza dati non compare: un
     * valore inventato per la notte in cui l'orologio era scarico e'
     * indistinguibile da una misura vera, ed e' peggio del silenzio.
     *
     * 💡 E il prompt lo sa: «se una notte manca, non c'era il sensore».
     */
        if (n == null) continue;

        notti.add({
          'day': _giorno(quale),
          'hours': (n.minutiDormiti / 60).toStringAsFixed(1),
          'deep_min': n.minutiProfondo,
          'rem_min': n.minutiRem,
          'awake_min': n.minutiSvegli,
        });
      }

      // ── HRV e battito, media per giorno ─────────────────────────────────────
      Future<List<Map<String, Object>>> serie(MetricaSalute m) async {
        final righe = await archivio.mediePerGiorno(m, giorni: _giorni);

        return righe.reversed
            .map(
              (r) => <String, Object>{
                'day': _giorno(r.giorno),
                'v': r.media.round(),
              },
            )
            .toList();
      }

      final hrv = await serie(MetricaSalute.hrv);
      final battito = await serie(MetricaSalute.battitoARiposo);

      // ── Gli allenamenti, da qualunque fonte ─────────────────────────────────
      final voci = await ref.watch(storicoUnificatoProvider.future);
      final da = oggi.subtract(const Duration(days: _giorni));

      final allenamenti = <Map<String, Object>>[];

      for (final v in voci) {
        if (v.quando.isBefore(da)) continue;

        final tipo = v.dalPolso.isEmpty
            ? null
            : TipoAllenamento.da(v.dalPolso.first.tipo);

        allenamenti.add({
          'day': _giorno(v.quando),
          'minutes': v.durata.inMinutes,

          /*
       * 🚨 **Il tipo tradotto, non il codice** — e qui, a differenza di
       * `training_types`, e' giusto cosi'.
       *
       * 💡 La' il codice serviva perche' il server doveva **filtrare** testo
       * libero con una regex. Qui il valore nasce da `TipoAllenamento`, che e'
       * un elenco chiuso scritto da noi: non c'e' testo libero da cui
       * difendersi, e «Pesi» il modello lo legge meglio di
       * `STRENGTH_TRAINING`.
       */
          if (tipo != null) 'type': tipo.nome,

          /*
       * ⚠️ Le calorie **attive**, mai le totali: vedi la nota su
       * `AllenamentiDaOrologio.kcal`. E se l'orologio non c'era, la stima del
       * server e' meglio di niente.
       */
          if (v.kcalDalPolso != null)
            'kcal': v.kcalDalPolso!
          else if (v.kcalDalleSedute != null)
            'kcal': v.kcalDalleSedute!,
        });
      }

      return SettimanaPerIlConsiglio(
        notti: notti,
        hrv: hrv,
        battito: battito,
        allenamenti: allenamenti,
      );
    });
