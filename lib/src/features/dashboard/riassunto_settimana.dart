import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../diary/data/diario_locale.dart';
import '../diary/data/serie_del_cibo.dart';
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
    this.voci = const [],
    this.giorniDallUltimo,
    this.ultimi30 = 0,
    this.volumeKg,
    this.metri,
    this.kcalBruciate,
    this.proteineG,
    this.minutiDormiti,
    this.pesoStimatoKg,
  });

  /// Gli allenamenti dei sette giorni, dal più recente.
  ///
  /// ══ 🚨 QUESTA LISTA CHIUDE UN DIFETTO RIFERITO ═════════════════════════
  ///
  /// 📌 Il committente, 21/08/2026: *«La card allenamento è sbagliata, mi dice
  /// che ho registrato un esercizio e non me lo mostra (quello dell'altro ieri
  /// dall'orologio)»*.
  ///
  /// ⚠️ **E le due metà della scheda parlavano di due elenchi diversi**: il
  /// riassunto contava dallo **storico unificato** (che l'orologio ce l'ha), la
  /// lista sotto disegnava `riepilogo.training.recent`, cioè le sedute del
  /// **server**. Un allenamento registrato solo dall'orologio finiva nel conteggio
  /// e non nella lista.
  ///
  /// 🚨 **Il difetto peggiore non è la riga mancante: è la contraddizione.** Una
  /// scheda che dice «1 allenamento» e sotto non ne mostra nessuno fa dubitare
  /// di tutti e due i numeri, non solo di quello sbagliato.
  ///
  /// 💡 Da qui in poi la scheda ha **una fonte sola**, e per la stessa ragione
  /// ci sono anche [giorniDallUltimo] e [ultimi30]: erano gli altri due numeri
  /// che venivano dal server.
  final List<VoceStorico> voci;

  /// Da quanti giorni non ci si allena. `null` = mai.
  final int? giorniDallUltimo;

  /// Quanti allenamenti negli ultimi 30 giorni.
  final int ultimi30;

  /// Quante volte ci si è allenati nei sette giorni.
  int get sedute => voci.length;

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
      voci.isEmpty &&
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
      final tutte = await ref.watch(storicoUnificatoProvider.future);

      final voci = tutte.where((v) => !v.quando.isBefore(da)).toList()
        // 💡 Dal più recente: è l'ordine in cui la scheda li mostra, e farlo
        // qui evita che chi disegna se lo ricordi (o se lo dimentichi).
        ..sort((a, b) => b.quando.compareTo(a.quando));

      /*
       * 🚨 Anche questi due venivano dal **server** — vedi [voci]. Un
       * allenamento fatto solo con l'orologio non spostava «non ti alleni da N
       * giorni», che è la frase che dovrebbe far tornare in palestra: diceva
       * «da 5 giorni» a chi aveva corso ieri.
       */
      final ultimo = tutte.isEmpty
          ? null
          : tutte.map((v) => v.quando).reduce((a, b) => a.isAfter(b) ? a : b);

      final giorniDallUltimo = ultimo == null
          ? null
          : mezzanotte
                .difference(DateTime(ultimo.year, ultimo.month, ultimo.day))
                .inDays;

      final da30 = mezzanotte.subtract(const Duration(days: 29));
      final ultimi30 = tutte.where((v) => !v.quando.isBefore(da30)).length;

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
        voci: voci,
        giorniDallUltimo: giorniDallUltimo,
        ultimi30: ultimi30,
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
    /*
     * 🆕 **Dal telefono, non da `/series`** — Parte I, I2.5.
     *
     * 🚨 Il diario non sta più sul server: la vecchia chiamata avrebbe risposto
     * sette zeri, e la scheda avrebbe riassunto una settimana a digiuno senza
     * nessun errore.
     */
    ref.watch(revisioneDiarioProvider);

    return await ref.watch(serieDelCiboProvider).calorie(giorni: 7);
  } on Object catch (e) {
    /*
     * ⚠️ Il resto della scheda vive lo stesso: il cibo è **una** delle voci, e
     * un archivio che non risponde non deve portarsi via anche il peso
     * sollevato. 💡 Le voci che dipendono da qui spariscono, che è già la regola.
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
