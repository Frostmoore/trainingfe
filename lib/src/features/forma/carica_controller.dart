/// La Carica, dai dati veri del telefono — 3b-K, 28/08/2026.
///
/// ══ 🚨 IL CALCOLO NON STA QUI ═════════════════════════════════════════════
///
/// Qui si **raccolgono** i dati e si chiama [CaricaBatteria.catena]. La formula
/// vive in un file puro, perché è di diciassette passaggi e ogni errore produce
/// un numero plausibile: doverla provare con un telefono vorrebbe dire non
/// provarla.
///
/// ══ ⚠️ E SI RICALCOLA OGNI VOLTA, DA UNA FINESTRA ═════════════════════════
///
/// 📌 La specifica dice *«la Carica NON deve essere ricalcolata ogni giorno da
/// zero»*, e la catena infatti **trascina** la fatica. 💡 Ma la catena si può
/// ricostruire: ripartendo da [giorniDaRicostruire] giorni fa, la Carica di oggi
/// è la stessa che si otterrebbe salvandola ogni sera.
///
/// 🚨 **È deliberato non conservarla in una tabella.** Uno stato salvato che
/// dipende dai dati diventa sbagliato ogni volta che i dati arrivano in ritardo
/// — e l'orologio manda le calorie di ieri stamattina. ⛔ Una Carica scritta
/// ieri sera resterebbe quella di ieri sera per sempre, anche dopo che il
/// telefono ha scoperto com'era andata davvero la giornata.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/archivio_salute.dart';
import '../health/analizzatore_sonno.dart';
import '../health/dati_salute.dart';
import '../health/health_controller.dart';
import '../profile/target_locale_controller.dart';
import '../training/storico_unificato_controller.dart';
import 'carica_batteria.dart';
import 'indici_di_forma.dart';

/// Quanti giorni si ricostruiscono a ogni lettura.
///
/// 💡 **Quarantadue e non ventotto**: servono ventotto giorni *validi* perché i
/// riferimenti diventino personali, e in mezzo ci sono i giorni senza orologio.
/// ⚠️ Più indietro non serve: la fatica di sei settimane fa è già stata
/// recuperata da qualunque catena di notti normali.
const giorniDaRicostruire = 42;

/// La Carica come la legge la schermata.
class Carica {
  const Carica({
    required this.adesso,
    required this.mattina,
    required this.affidabilita,
    required this.giorniValidi,
    this.senzaSonno = false,
    this.senzaFisiologia = false,
    this.senzaAttivita = false,
  });

  /// Quella da mostrare: la mattina meno quello che si è già speso oggi.
  final double adesso;

  /// Con quanta ci si è svegliati. 💡 Serve a dire «eri a 86, sei a 71».
  final double mattina;

  final Affidabilita affidabilita;

  /// Su quanti giorni è costruita.
  final int giorniValidi;

  /// ⚠️ Servono a **dire cosa manca**, non solo che la stima è debole: «manca il
  /// sonno» è una cosa a cui si può rimediare, «poco affidabile» no.
  final bool senzaSonno;
  final bool senzaFisiologia;
  final bool senzaAttivita;
}

final caricaProvider = FutureProvider.autoDispose<Carica?>((ref) async {
  final archivio = ref.watch(archivioSaluteProvider);

  final oggi = DateTime.now();
  final mezzanotte = DateTime(oggi.year, oggi.month, oggi.day);

  /*
   * ══ ⚠️ IL TDEE È L'UNICO INGREDIENTE SENZA IL QUALE NON SI PARTE ═════════
   *
   * 🚨 I riferimenti del bootstrap sono **quote del TDEE** (30% e 20%): senza,
   * non esiste un metro con cui misurare se un allenamento è stato grande o
   * piccolo *per questa persona*. ⛔ Un TDEE inventato darebbe una scarica
   * inventata, e la batteria sarebbe un numero che si muove a caso.
   *
   * 💡 `null` e non un valore di ripiego: la card non compare, e chi apre il
   * profilo trova cosa manca. È la stessa scelta di `PezzoMancante`.
   */
  final target = (await ref.watch(targetLocaleProvider.future)).target;

  if (target == null) return null;

  final tdee = target.tdee;

  // ── Le calorie degli allenamenti, giorno per giorno ──────────────────────
  final voci = await ref.watch(storicoUnificatoProvider.future);

  final allenamenti = <int, double>{};

  for (final v in voci) {
    final giorno = DateTime(v.quando.year, v.quando.month, v.quando.day);
    final quantiFa = mezzanotte.difference(giorno).inDays;

    if (quantiFa < 0 || quantiFa >= giorniDaRicostruire) continue;

    final kcal = v.kcalDalPolso ?? v.kcalDalleSedute;

    if (kcal == null) continue;

    allenamenti[quantiFa] = (allenamenti[quantiFa] ?? 0) + kcal;
  }

  /*
   * ── Le baseline di HRV e battito ────────────────────────────────────────
   *
   * 💡 Le stesse di `IndiciDiForma`: due medie personali per la stessa persona
   * sarebbero due verità diverse sullo stesso dato.
   *
   * ⚠️ **Una lettura per metrica, non una al giorno.** Quarantadue giorni per
   * due metriche sarebbero ottantaquattro query per disegnare una batteria:
   * si legge tutta la finestra e si indicizza in memoria.
   */
  final hrv = await _serie(archivio, MetricaSalute.hrv);
  final battito = await _serie(archivio, MetricaSalute.battitoARiposo);

  final giorni = <GiornataPerLaCarica>[];

  var validi = 0;

  for (var quantiFa = giorniDaRicostruire - 1; quantiFa >= 0; quantiFa--) {
    final giorno = mezzanotte.subtract(Duration(days: quantiFa));

    final attive = await archivio.kcalAttiveDi(giorno);

    /*
     * ⚠️ **Zero calorie attive vuol dire «non lo sappiamo», non «fermo».**
     * `kcalAttiveDi` torna `0` sia per il giorno senza campioni sia per il
     * giorno passato a letto — e sono due cose diverse. 🚨 Trattandoli uguali,
     * chi lascia l'orologio a casa si vedrebbe la batteria salire come se avesse
     * riposato: sarebbe una bugia consolante, che è il tipo peggiore.
     */
    final calorieAttive = attive > 0 ? attive.toDouble() : null;

    if (calorieAttive != null) validi++;

    final notte = await AnalizzatoreSonno.notte(archivio, giorno);

    /*
     * 🚨 **HRV e battito entrano solo dopo sette giorni.** 📌 *«fino ad allora
     * physiologyScore = 0»*: una baseline costruita su tre notti non è una
     * baseline, è un caso.
     */
    final abbastanza = validi >= CaricaBatteria.giorniPerLaFisiologia;

    giorni.add(
      GiornataPerLaCarica(
        giorno: giorno,
        calorieAttive: calorieAttive,
        calorieAllenamento: allenamenti[quantiFa],
        minutiDormiti: notte?.minutiDormiti.toDouble(),
        zHrv: abbastanza ? hrv.zDi(giorno) : null,
        zBattito: abbastanza ? battito.zDi(giorno) : null,
      ),
    );
  }

  final catena = CaricaBatteria.catena(giorni: giorni, tdeeDiBase: tdee);

  if (catena.isEmpty) return null;

  /*
   * ══ 🌙 QUALE GIORNO SI STA ANCORA VIVENDO — 3b-AD, 31/08/2026 ═══════════
   *
   * 📌 Il committente, alle 00:50: *«è mezzanotte e 50, non è possibile che la
   * carica mi dica che ho il 94% di carica»* · *«Ovviamente la giornata inizia
   * al risveglio»*.
   *
   * ⛔ **Prima si prendeva `catena.last` e basta.** A mezzanotte quello
   * diventava un giorno nuovo, con due conseguenze che si sommavano: il suo
   * mattino era stato calcolato accreditando il recupero di una notte **non
   * ancora avvenuta**, e la sua scarica ripartiva da zero.
   *
   * 💡 Adesso il giorno in corso è **l'ultimo la cui notte è stata
   * registrata**: finché non ti sei svegliato, la Carica resta quella di ieri.
   *
   * ⚠️ L'ora si legge qui e si passa: `CaricaBatteria` è un file puro, e un
   * `DateTime.now()` là dentro renderebbe la formula impossibile da provare
   * alle 00:50 — cioè proprio all'ora in cui sbagliava.
   */
  final inCorso = CaricaBatteria.indiceDelGiornoInCorso(
    giorni: giorni,
    oraLocale: oggi.hour,
  );

  final ultimo = catena[inCorso];
  final oggiCosi = giorni[inCorso];

  /*
   * 🚨 **La mezzanotte non azzera la scarica.** Se si sta ancora vivendo ieri,
   * i minuti dopo le 00:00 fanno parte della stessa giornata sveglia: le loro
   * calorie si sommano, non aprono un conto nuovo.
   */
  final spese = CaricaBatteria.speseDalRisveglio(giorni: giorni, da: inCorso);

  /*
   * 💡 **La scarica di oggi si ricalcola qui** invece di riusare `ultimo.sera`:
   * quella è la sera *finita*, questa è quanto si è già consumato **finora**. ⚠️
   * Sono lo stesso numero solo a fine giornata, e mostrare la sera alle nove del
   * mattino direbbe che si è già speso tutto.
   */
  final rif = CaricaBatteria.riferimenti(
    tdeeDiBase: tdee,
    giorniValidi: validi,
  );

  return Carica(
    mattina: ultimo.mattina,
    adesso: CaricaBatteria.adesso(
      caricaDelMattino: ultimo.mattina,
      scaricaFinora: CaricaBatteria.scarica(
        calorieAttive: spese.attive,
        calorieAllenamento: spese.allenamento,
        riferimentoAllenamento: rif.allenamento,
        riferimentoAttivita: rif.attivita,
      ),
    ),
    affidabilita: ultimo.affidabilita,
    giorniValidi: validi,
    senzaSonno: oggiCosi.minutiDormiti == null,
    senzaFisiologia: oggiCosi.zHrv == null && oggiCosi.zBattito == null,
    senzaAttivita: spese.attive == null,
  );
});

/// Una metrica letta una volta sola, con la sua baseline.
///
/// 💡 Sa rispondere «lo z-score di questo giorno» senza tornare al database.
class _Serie {
  const _Serie(this._perGiorno, this._baseline);

  final Map<DateTime, double> _perGiorno;
  final (double media, double deviazione)? _baseline;

  double? zDi(DateTime giorno) {
    final base = _baseline;
    final valore = _perGiorno[giorno];

    if (base == null || valore == null) return null;

    return IndiciDiForma.z(
      valore: valore,
      media: base.$1,
      deviazione: base.$2,
    );
  }
}

/// Legge la finestra intera e ne calcola media e deviazione.
Future<_Serie> _serie(ArchivioSalute archivio, MetricaSalute m) async {
  try {
    final righe = await archivio.mediePerGiorno(m, giorni: giorniDaRicostruire);

    final perGiorno = {
      for (final r in righe)
        DateTime(r.giorno.year, r.giorno.month, r.giorno.day): r.media,
    };

    /*
     * ⚠️ **La baseline vuole almeno due valori**, e con deviazione zero
     * `IndiciDiForma.z` torna `null`: tutti i giorni identici non vogliono dire
     * «perfettamente nella media», vogliono dire che non c'è niente da
     * confrontare.
     */
    final base = righe.length < 2
        ? null
        : IndiciDiForma.mediaEDeviazione(righe.map((r) => r.media).toList());

    return _Serie(perGiorno, base);
  } on Object catch (e) {
    debugPrint('carica: la serie di ${m.codice} non si legge — $e');

    return const _Serie({}, null);
  }
}
