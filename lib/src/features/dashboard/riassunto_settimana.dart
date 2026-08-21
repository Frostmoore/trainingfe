import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../health/analizzatore_sonno.dart';
import '../health/health_controller.dart';
import '../profile/target_locale_controller.dart';
import '../training/data/storico_unificato.dart';
import '../training/storico_unificato_controller.dart';
import 'dashboard_controller.dart';

/// Gli ultimi sette giorni, in un numero per voce — 3b-O.7, 21/08/2026.
///
/// ══ 🚨 PERCHÉ SETTE GIORNI E NON OGGI ═════════════════════════════════════
///
/// 📌 Il committente: *«la card allenamento così non mi piace, mostra solo gli
/// allenamenti di oggi (che di solito sono max 1). Dovrebbe essere più
/// esplicativa. Diciamo che mostra tutti gli ultimi 7 giorni»*.
///
/// ⚠️ **E ha ragione sul fatto, non sul gusto**: un allenamento non si giudica
/// dal giorno. Una scheda che mostra «oggi» è vuota sei giorni su sette per chi
/// si allena tre volte a settimana — cioè racconta il contrario di quello che
/// sta succedendo.
///
/// ── ⚠️ Da dove vengono i numeri, e perché da lì ──────────────────────────
///
/// | Voce | Fonte | Perché non un'altra |
/// |---|---|---|
/// | Peso sollevato | `LoggedSet.reps × weight` | È l'unico posto dove il carico esiste davvero |
/// | Km | `VoceStorico.distanzaMetri` | Solo l'orologio la misura; le sedute a mano non hanno distanza |
/// | Kcal bruciate | `kcalDalPolso ?? kcalDalleSedute` | 🚨 La stessa catena dell'intestazione, o due numeri diversi per la stessa cosa |
/// | Proteine | `Series.protein` | Una chiamata sola invece di sette a `/diary` |
/// | Riposo | `AnalizzatoreSonno.notte` | L'archivio locale: il sonno non esce dal telefono |
///
/// 🚨 **Non `riepilogo.training`**, che è il riassunto del **server**: quello le
/// cose dell'orologio non le ha, e chi corre senza registrare una seduta si
/// vedrebbe una settimana vuota.
///
/// ── ⛔ Una voce senza dati SPARISCE ──────────────────────────────────────
///
/// È la regola già decisa in O.1b.1 e ribadita dal difetto O.D.4: uno zero
/// afferma qualcosa («non ti sei mosso»), un'assenza no. ⚠️ E qui è più grave
/// che altrove, perché questi numeri si sommano su sette giorni: uno zero da
/// «dato mancante» abbassa una media che qualcuno guarderà per decidere.
@immutable
class RiassuntoSettimana {
  const RiassuntoSettimana({
    this.sedute = 0,
    this.volumeKg,
    this.metri,
    this.kcalBruciate,
    this.proteineG,
    this.minutiDormiti,
    this.pesoStimatoKg,
  });

  /// Quante volte ci si è allenati nei sette giorni.
  final int sedute;

  /// Il peso sollevato in totale: `reps × weight`, sommato su tutte le serie.
  final double? volumeKg;

  /// I metri percorsi — corsa, camminata, bici.
  final int? metri;

  final int? kcalBruciate;
  final int? proteineG;
  final int? minutiDormiti;

  /// Quanto peso si sarebbe perso o guadagnato **rispettando il consumo**.
  ///
  /// ══ 🚨 È UNA STIMA GROSSOLANA, E VA DETTO ═══════════════════════════════
  ///
  /// 📌 *«facendo un calcolo di calorie assunte e bruciate […] quanto peso avrei
  /// perso o guadagnato rispettando il target precisamente»*.
  ///
  /// **La formula**: `Σ(assunte − consumo − bruciate) ÷ 7700`.
  ///
  /// ⚠️ **7.700 kcal per chilo** è la costante di Wishnofsky, del 1958: assume
  /// che il chilo perso sia tutto grasso. 🚨 Non lo è — c'è acqua, c'è
  /// glicogeno, e il metabolismo si adatta scendendo. Nelle prime settimane
  /// sbaglia **per eccesso**, e chi la legge come una misura si demoralizza
  /// quando la bilancia non conferma.
  ///
  /// 💡 Per questo accanto ci va sempre l'avvertenza, come per carico e carica.
  /// ⛔ E se manca il consumo — niente profilo, niente peso — **il numero non si
  /// mostra affatto**: meglio niente che un numero costruito su un'invenzione.
  final double? pesoStimatoKg;

  /// I chilogrammi di grasso corrispondenti a una kcal di scarto — Wishnofsky.
  static const kcalPerChilo = 7700.0;

  bool get vuoto =>
      sedute == 0 &&
      volumeKg == null &&
      metri == null &&
      kcalBruciate == null &&
      proteineG == null &&
      minutiDormiti == null;
}

/// I giorni che la scheda riassume.
const giorniDellaSettimana = 7;

/// I tipi che percorrono una distanza — 3b-O.7.3.
///
/// ⚠️ **Non tutti gli allenamenti con una distanza sono uno spostamento**: un
/// tapis roulant la registra, e sommarla ai chilometri fatti fuori è comunque
/// onesto (le gambe hanno fatto la stessa strada). 💡 Quello che va escluso è il
/// resto — la palestra, il nuoto, i corsi — dove `distanzaMetri` o non c'è o
/// vuol dire un'altra cosa.
const tipiConDistanza = {
  'RUNNING',
  'RUNNING_TREADMILL',
  'WALKING',
  'HIKING',
  'BIKING',
  'BIKING_STATIONARY',
};

final riassuntoSettimanaProvider =
    FutureProvider.autoDispose<RiassuntoSettimana>((ref) async {
      final oggi = DateTime.now();
      final mezzanotte = DateTime(oggi.year, oggi.month, oggi.day);
      final da = mezzanotte.subtract(
        const Duration(days: giorniDellaSettimana - 1),
      );

      // ── 🏋️ Allenamento: dallo storico unificato ──────────────────────────
      final voci = (await ref.watch(
        storicoUnificatoProvider.future,
      )).where((v) => !v.quando.isBefore(da)).toList();

      double? volume;
      int? metri;
      int? bruciate;

      for (final v in voci) {
        for (final seduta in v.sedute) {
          for (final serie in seduta.sets) {
            final peso = serie.weight;
            final ripetizioni = serie.reps;

            // ⚠️ A corpo libero il peso è `null`, e non è zero: quella serie
            // non entra nel volume, ma la seduta conta lo stesso.
            if (peso == null || ripetizioni == null) continue;

            volume = (volume ?? 0) + peso * ripetizioni;
          }
        }

        if (_haDistanza(v)) {
          final d = v.distanzaMetri;
          if (d != null && d > 0) metri = (metri ?? 0) + d;
        }

        final k = v.kcalDalPolso ?? v.kcalDalleSedute;
        if (k != null && k > 0) bruciate = (bruciate ?? 0) + k;
      }

      // ── 😴 Riposo: sette notti dall'archivio locale ───────────────────────
      final archivio = ref.watch(archivioSaluteProvider);

      int? dormiti;
      for (var i = 0; i < giorniDellaSettimana; i++) {
        final notte = await AnalizzatoreSonno.notte(
          archivio,
          da.add(Duration(days: i)),
        );

        final minuti = notte?.minutiDormiti;
        if (minuti != null && minuti > 0) dormiti = (dormiti ?? 0) + minuti;
      }

      // ── 🍽️ Cibo: una chiamata sola, sette giorni ─────────────────────────
      final serie = await _serieDellaSettimana(ref);

      int? proteine;
      for (final g in serie?.protein ?? const <double>[]) {
        if (g > 0) proteine = (proteine ?? 0) + g.round();
      }

      return RiassuntoSettimana(
        sedute: voci.length,
        volumeKg: volume,
        metri: metri,
        kcalBruciate: bruciate,
        proteineG: proteine,
        minutiDormiti: dormiti,
        pesoStimatoKg: _pesoStimato(ref, serie, bruciate),
      );
    });

bool _haDistanza(VoceStorico v) =>
    v.dalPolso.any((a) => tipiConDistanza.contains(a.tipo.toUpperCase()));

/// La serie dei sette giorni.
///
/// ⛔ **Non `caloriesSeriesProvider`**, che segue il selettore del grafico: se
/// qualcuno lo mette su «3 mesi», questa scheda comincerebbe a riassumere tre
/// mesi chiamandoli «ultimi 7 giorni». 🚨 Due lettori dello stesso provider con
/// due intenzioni diverse è il modo più rapido per farne divergere una.
Future<Series?> _serieDellaSettimana(Ref ref) async {
  try {
    final dati = await ref
        .watch(apiClientProvider)
        .get<Map<String, dynamic>>(
          '/series',
          // 🚨 `7` è fra `giorniAmmessiPerLeSerie`: vedi §56.3 n° 3.
          query: {'metric': 'calories', 'days': 7, 'offset': 0},
        );

    return Series.fromJson(dati);
  } on Object catch (e) {
    /*
     * ⚠️ Il resto della scheda vive lo stesso: il cibo è **una** delle voci, e
     * una rete che non risponde non deve portarsi via anche il peso sollevato,
     * che sta sul telefono. 💡 Le voci che dipendono da qui spariscono, che è
     * già la regola.
     */
    debugPrint('riassunto settimana: la serie del cibo non si legge — $e');

    return null;
  }
}

/// Il peso stimato dal saldo calorico — vedi [RiassuntoSettimana.pesoStimatoKg].
double? _pesoStimato(Ref ref, Series? serie, int? bruciate) {
  final consumo = ref.watch(targetLocaleProvider).valueOrNull?.target?.tdee;

  // ⛔ Senza consumo non si stima niente: sarebbe un numero su un'invenzione.
  if (consumo == null || serie == null) return null;

  return pesoDalSaldo(
    assunte: serie.consumed,
    consumo: consumo,
    bruciate: bruciate,
  );
}

/// La stima del peso, **senza Riverpod attorno** — 3b-O.7.4.
///
/// 💡 È una funzione pura di proposito: la regola che conta — «un giorno senza
/// diario si salta» — è quella che si sbaglia, ed è quella che va provata senza
/// dover montare mezza applicazione per farlo.
///
/// Ritorna `null` quando **nessun** giorno ha dati: una stima su zero giorni non
/// è zero chili, è nessuna stima.
@visibleForTesting
double? pesoDalSaldo({
  required List<double> assunte,
  required double consumo,
  int? bruciate,
  int giorni = giorniDellaSettimana,
}) {
  var saldo = 0.0;
  var giorniConDati = 0;

  for (final kcal in assunte) {
    /*
     * 🚨 **Un giorno senza diario si salta, non vale zero.**
     *
     * ⚠️ Con `assunte = 0` il saldo di quel giorno sarebbe `−consumo`, cioè un
     * digiuno completo: **−2.400 kcal**. Su tre giorni saltati fanno quasi un
     * chilo di dimagrimento che non è successo — un numero credibile e falso,
     * che è il tipo di difetto peggiore (vedi §56.3 n° 3 dell'atlante).
     */
    if (kcal <= 0) continue;

    saldo += kcal - consumo;
    giorniConDati++;
  }

  if (giorniConDati == 0) return null;

  /*
   * ⚠️ Le bruciate si tolgono **in proporzione ai giorni contati**: sono la
   * somma di tutta la settimana, e sottrarle intere a un saldo calcolato su tre
   * giorni gonfierebbe il dimagrimento di quei tre.
   */
  if (bruciate != null && bruciate > 0) {
    saldo -= bruciate * giorniConDati / giorni;
  }

  return saldo / RiassuntoSettimana.kcalPerChilo;
}
