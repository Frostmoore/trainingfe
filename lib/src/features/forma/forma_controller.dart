/// Stanchezza e carica, con i dati veri — FASE 2-sexies.
///
/// ══ 🚨 LA REGOLA, DETTA BENE ══════════════════════════════════════════════
///
/// L'indice è un dato sanitario **derivato**, e **si calcola qui**: calcolarlo
/// sul server vorrebbe dire ricreare esattamente ciò che la decisione D9-bis ha
/// smontato.
///
/// ⚠️ **La regola è «non esce», non «non entra».** In una prima stesura c'era
/// scritto *«qui non c'è nessuna chiamata di rete»*, ed era **più stretta del
/// necessario**: leggere le proprie calorie dal nostro server — che allora le
/// aveva già, per T3 — non faceva uscire niente di nuovo da nessuna parte.
///
/// 🚨 Quello che non deve succedere è che **il risultato** finisca fuori, o che
/// a calcolarlo sia qualcun altro. Chi aggiungesse una `POST` con dentro questi
/// numeri starebbe annullando la fase; chi legge un dato che è già nostro no.
///
/// 💡 La differenza conta perché la versione stretta aveva già prodotto un buco:
/// il cibo era rimasto fuori dal calcolo **per una regola scritta male**, non per
/// un limite vero.
///
/// 🆕 **Da I2.5 la questione non si pone più**: anche le calorie vengono
/// dall'archivio locale, e qui dentro non c'è nessuna chiamata di rete — non
/// perché una regola lo vieti, ma perché non c'è più niente da chiedere.

library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../diary/data/diario_locale.dart';
import '../diary/data/serie_del_cibo.dart';
import '../health/analizzatore_sonno.dart';
import '../health/dati_salute.dart';
import '../health/health_controller.dart';
import '../training/data/storico_unificato.dart';
import '../training/storico_unificato_controller.dart';
import 'indici_di_forma.dart';
import 'reattivita.dart';

/// Un pezzo della carica, **con i numeri che l'hanno prodotto**.
///
/// 🚨 Serve alla schermata di dettaglio, e non è una comodità: un indice che
/// mostra solo il risultato chiede di essere creduto sulla parola. ⚠️ Mostrare
/// gli ingredienti è l'unico modo perché chi legge possa **non essere
/// d'accordo** — e su un numero che parla della sua stanchezza ne ha diritto.
class IngredienteCarica {
  const IngredienteCarica({
    required this.nome,
    required this.unita,
    required this.peso,
    this.z,
    this.oggi,
    this.media,
    this.invertito = false,
    this.soloInNegativo = false,
  });

  final String nome;
  final String unita;
  final double peso;

  /// `null` quando l'ingrediente non c'è: senza dati, o senza abbastanza storia.
  final double? z;

  final double? oggi;
  final double? media;

  /// ⚠️ Il battito a riposo: sopra la media personale è **peggio**.
  final bool invertito;

  /// 🚨 Il cibo: mangiare tanto non alza la carica.
  final bool soloInNegativo;

  bool get ceLo => z != null;
}

class Forma {
  const Forma({
    required this.stanchezza,
    required this.prontezza,
    required this.reattivita,
    this.acuto = 0,
    this.cronico = 0,
    this.ingredienti = const [],
    this.caricoPerGiorno = const [],
  });

  final Indice stanchezza;

  /// ⚠️ **Resta**, ma non è più quello che il tachimetro mostra: è lo z-score
  /// contro le proprie medie notturne, cioè *«come stai oggi rispetto al
  /// solito»*. 💡 Serve ancora alla scheda del sonno e al grafico di «Oggi».
  final Indice prontezza;

  /// 🆕 Quanto sei reattivo **adesso** — il modello a tre processi, 06/09/2026.
  ///
  /// ⛔ `null` quando manca la notte: senza sapere da quanto sei sveglio il
  /// modello non ha il suo ingrediente principale, e un numero inventato lì
  /// sarebbe preciso e falso.
  final Reattivita? reattivita;

  /// Il carico degli ultimi 7 giorni, in `EWMA`.
  final double acuto;

  /// Il carico degli ultimi 28, in `EWMA`: **il proprio normale**.
  final double cronico;

  final List<IngredienteCarica> ingredienti;

  /// Le kcal per giorno, dal più vecchio al più recente.
  ///
  /// 💡 Serve alla schermata di dettaglio per mostrare **da dove esce** il
  /// rapporto: due medie da sole non si possono verificare.
  final List<double> caricoPerGiorno;

  FasciaCarico? get fascia {
    final v = stanchezza.valore;

    return v == null ? null : FasciaCarico.da(v);
  }
}

/// Quanti giorni indietro si guarda: la finestra lunga dell'`ACWR`.
const _finestra = IndiciDiForma.giorniCronici;

/// La storia di quanto si è mangiato, per lo z-score del cibo.
///
/// ── 💡 Perché contro la PROPRIA media e non contro il target ──────────────
///
/// Perché «oggi hai mangiato meno del tuo solito» è un confronto fra due misure,
/// mentre «oggi sei sotto il target» mette insieme una misura e un obiettivo —
/// e l'obiettivo cambia con il peso, con il piano del trainer e con le calorie
/// bruciate. ⚠️ Un indice costruito su un bersaglio mobile si muove anche quando
/// la persona non si muove.
///
/// 🚨 Ed è la stessa forma degli altri tre ingredienti: uno `z` contro sé stessi.
/// Un pezzo con una matematica diversa dagli altri sarebbe il primo posto in cui
/// guardare quando l'indice dirà una cosa strana.
final _storiaCalorieProvider = FutureProvider.autoDispose<List<double>>((
  ref,
) async {
  /*
   * ══ 🚨 SI CHIEDEVANO 30 GIORNI PER TENERNE 28, E ADESSO NO — I2.5 ════════
   *
   * ⚠️ **Questa chiamata non ha funzionato per settimane.** Chiedeva
   * `days: _finestra`, cioe' 28, ma `SeriesController` ammetteva solo
   * `0, 7, 30, 90, 365` — i periodi dei pulsanti del grafico, non un intervallo
   * libero. Il server rispondeva `422 validation.in`, il `catch` piu' sotto se
   * lo mangiava, e la **carica veniva calcolata senza l'ingrediente delle
   * calorie**: nessun errore a schermo, un numero plausibile, e nessun modo di
   * accorgersene guardando l'app.
   *
   * 💡 Il ripiego era chiedere 30 e tagliare a 28. 🆕 Da I2.5 la serie si
   * costruisce **qui**, sull'archivio locale: quell'elenco era una scelta di
   * prodotto del server, e adesso non c'e' piu' nessun server in mezzo. Si
   * chiedono i 28 giorni che servono.
   */
  ref.watch(revisioneDiarioProvider);

  final serie = await ref
      .watch(serieDelCiboProvider)
      .calorie(giorni: _finestra);

  final ultimi = serie.consumed;

  // ⚠️ Gli zeri si buttano: sono i giorni in cui non si è segnato niente, non i
  // giorni in cui non si è mangiato. Contarli come «zero calorie» farebbe
  // sembrare a digiuno chi ha solo saltato il diario.
  return ultimi.where((v) => v > 0).toList();
});

final formaProvider = FutureProvider.autoDispose<Forma>((ref) async {
  final archivio = ref.watch(archivioSaluteProvider);
  final oggi = DateTime.now();
  final mezzanotte = DateTime(oggi.year, oggi.month, oggi.day);

  // ── Il carico, un valore per giorno ──────────────────────────────────────
  final voci = await ref.watch(storicoUnificatoProvider.future);

  /*
   * 🚨 **Si parte da 28 zeri e si riempiono i giorni che ci sono.**
   *
   * ⚠️ Non si costruisce la lista dagli allenamenti: un giorno di riposo è un
   * carico di **zero**, non un giorno che non esiste. Saltandolo, il carico
   * acuto sembrerebbe sempre pieno e l'indice non scenderebbe mai — cioè
   * direbbe «sei carico» a chi è fermo da una settimana.
   */
  final carico = List<double>.filled(_finestra, 0);

  for (final v in voci) {
    final giorno = DateTime(v.quando.year, v.quando.month, v.quando.day);
    final quantiFa = mezzanotte.difference(giorno).inDays;

    if (quantiFa < 0 || quantiFa >= _finestra) continue;

    final kcal = v.kcalDalPolso ?? v.kcalDalleSedute;
    if (kcal == null) continue;

    // 💡 L'indice va dal più vecchio (0) al più recente: è l'ordine che
    // `IndiciDiForma.ewma` si aspetta, e invertirlo darebbe un numero
    // plausibile e sbagliato.
    carico[_finestra - 1 - quantiFa] += kcal.toDouble();
  }

  /*
   * ⚠️ **`giorniDiStoria` non è «28 perché la lista è lunga 28».**
   *
   * La lista è sempre piena di zeri; quello che conta è **da quanto tempo
   * l'archivio raccoglie**. 💡 Si prende il giorno più vecchio di cui si sa
   * qualcosa: senza, la nota direbbe «attendibile» a chi ha installato l'app
   * ieri.
   */
  /*
   * ══ 🚨 LA STORIA DEL CARICO È QUELLA DEGLI ALLENAMENTI ═══════════════════
   *
   * ⚠️ **Difetto trovato dal committente il 20/08**: *«non vedo "mancano N
   * giorni"»*. La causa: qui si guardava da quanto tempo l'archivio ha dati di
   * **HRV**, e chi ripristina un backup ne ha subito ventotto giorni. Risultato:
   * l'indice si dichiarava **attendibile** mentre l'`ACWR` era costruito su **un
   * allenamento solo**.
   *
   * 🚨 È l'errore di misurare la storia sbagliata: la finestra lunga
   * dell'`ACWR` ha bisogno di **ventotto giorni di allenamenti osservati**, non
   * di ventotto giorni di battiti.
   *
   * 💡 Si conta dal **primo allenamento** che l'archivio conosce: chi ha
   * cominciato a registrare due giorni fa legge «mancano 26 giorni», che è la
   * verità.
   */
  final storiaCarico = _giorniDagliAllenamenti(voci, mezzanotte);

  // ── La carica: z-score contro le proprie medie ───────────────────────────
  //
  // 💡 Torna anche i numeri grezzi: alla schermata di dettaglio serve poter
  // dire «48 contro una tua media di 65», non solo «−1.7».
  Future<({double? z, double? oggi, double? media})> pezzoDi(
    MetricaSalute m,
  ) async {
    final righe = await archivio.mediePerGiorno(m, giorni: _finestra);

    if (righe.length < 2) return (z: null, oggi: null, media: null);

    final valori = righe.map((r) => r.media).toList();
    final stat = IndiciDiForma.mediaEDeviazione(valori);

    if (stat == null) return (z: null, oggi: valori.last, media: null);

    return (
      z: IndiciDiForma.z(
        valore: valori.last,
        media: stat.$1,
        deviazione: stat.$2,
      ),
      oggi: valori.last,
      media: stat.$1,
    );
  }

  final hrv = await pezzoDi(MetricaSalute.hrv);
  final battito = await pezzoDi(MetricaSalute.battitoARiposo);

  final zHrv = hrv.z;
  final zBattito = battito.z;

  // ── Il sonno ─────────────────────────────────────────────────────────────
  final minuti = <double>[];

  /*
   * 🆕 **L'ultima notte per intero, non solo i suoi minuti** — 06/09/2026.
   *
   * 💡 La Reattività ha bisogno di `GiudizioNotte.a`, cioè **l'ora del
   * risveglio**: è da lì che si contano le ore in piedi, ed è l'ingrediente
   * principale del processo omeostatico.
   *
   * ⛔ Dedurla da «mezzanotte + qualcosa» sarebbe una finzione: chi si sveglia
   * alle 5:30 e chi si sveglia alle 11 hanno giornate diverse, ed è esattamente
   * quello che il modello deve distinguere.
   */
  GiudizioNotte? ultimaNotte;

  for (var i = 0; i < _finestra; i++) {
    final n = await AnalizzatoreSonno.notte(
      archivio,
      mezzanotte.subtract(Duration(days: i)),
    );

    // ⚠️ I buchi non si riempiono: una notte senza dati non è una notte da zero.
    if (n != null) {
      minuti.add(n.minutiDormiti.toDouble());
      ultimaNotte ??= n;
    }
  }

  double? zSonno;
  double? sonnoOggi;
  double? sonnoMedio;

  if (minuti.isNotEmpty) sonnoOggi = minuti.first;

  if (minuti.length >= 2) {
    final stat = IndiciDiForma.mediaEDeviazione(minuti);

    if (stat != null) {
      sonnoMedio = stat.$1;

      zSonno = IndiciDiForma.z(
        // 💡 `minuti` è dal più recente all'indietro: l'ultima notte è la prima.
        valore: minuti.first,
        media: stat.$1,
        deviazione: stat.$2,
      );
    }
  }

  /*
   * ── Il cibo ──────────────────────────────────────────────────────────────
   *
   * 🚨 **Facoltativo davvero.** Passa dalla rete, e senza rete l'indice deve
   * esistere lo stesso: `zCibo` resta `null` e gli altri tre ingredienti fanno
   * il loro lavoro. ⚠️ Un numero che sparisce quando il telefono è offline
   * sarebbe peggio di un numero un po' meno preciso.
   */
  double? zCibo;
  double? ciboOggi;
  double? ciboMedio;

  try {
    final calorie = await ref.watch(_storiaCalorieProvider.future);

    if (calorie.isNotEmpty) ciboOggi = calorie.last;

    if (calorie.length >= 2) {
      final stat = IndiciDiForma.mediaEDeviazione(calorie);

      if (stat != null) {
        ciboMedio = stat.$1;

        zCibo = IndiciDiForma.z(
          valore: calorie.last,
          media: stat.$1,
          deviazione: stat.$2,
        );
      }
    }
  } on Object catch (e) {
    debugPrint('forma: la storia delle calorie non si legge — $e');
  }

  /*
   * 🆕 **La reattività di adesso** — 06/09/2026.
   *
   * ⚠️ Si calcola qui e non dentro il modello perché ha bisogno dell'**ora**, e
   * un `DateTime.now()` dentro `ModelloDellaReattivita` renderebbe la formula
   * impossibile da provare alle quattro di notte — cioè proprio all'ora in cui
   * conta di più.
   */
  final zCarico = _zDelCarico(carico);

  final reattivita = await _reattivitaAdesso(
    adesso: oggi,
    notte: ultimaNotte,
    diario: ref.watch(diarioLocaleProvider),
    zHrv: zHrv,
    zBattito: zBattito,
    zCarico: zCarico,
  );

  final prontezza = IndiciDiForma.prontezza(
    zHrv: zHrv,
    zBattito: zBattito,
    zSonno: zSonno,
    zCibo: zCibo,
    nottiDiStoria: minuti.length,
  );

  return Forma(
    acuto: IndiciDiForma.ewma(
      carico.sublist(carico.length - IndiciDiForma.giorniAcuti),
      IndiciDiForma.giorniAcuti,
    ),
    cronico: IndiciDiForma.ewma(carico, IndiciDiForma.giorniCronici),
    caricoPerGiorno: carico,
    ingredienti: [
      IngredienteCarica(
        nome: 'Variabilità cardiaca',
        unita: 'ms',
        peso: IndiciDiForma.pesoDellHrv,
        z: hrv.z,
        oggi: hrv.oggi,
        media: hrv.media,
      ),
      IngredienteCarica(
        nome: 'Battito a riposo',
        unita: 'bpm',
        peso: IndiciDiForma.pesoDelBattito,
        z: battito.z,
        oggi: battito.oggi,
        media: battito.media,
        invertito: true,
      ),
      IngredienteCarica(
        nome: 'Sonno',
        unita: 'min',
        peso: IndiciDiForma.pesoDelSonno,
        z: zSonno,
        oggi: sonnoOggi,
        media: sonnoMedio,
      ),
      IngredienteCarica(
        nome: 'Cibo',
        unita: 'kcal',
        peso: IndiciDiForma.pesoDelCibo,
        z: zCibo,
        oggi: ciboOggi,
        media: ciboMedio,
        soloInNegativo: true,
      ),
    ],
    stanchezza: IndiciDiForma.stanchezza(carico)._conStoria(storiaCarico),
    prontezza: prontezza,
    reattivita: reattivita,
  );
});

/// Quanto sei reattivo **adesso** — 06/09/2026.
///
/// ══ 🚨 PERCHE' NON E' LA PRONTEZZA DI PRIMA ═══════════════════════════════
///
/// 📌 Il committente: *«deve essere un valore che cambia durante la giornata, in
/// base proprio a quanto sono reattivi gli esseri umani di media»*, e *«non è una
/// batteria, è più un tachimetro»*.
///
/// ⛔ La Prontezza vecchia era uno **z-score contro le proprie medie** di HRV,
/// battito e sonno: tutte misure **notturne**, quindi per costruzione un verdetto
/// del mattino che non si muoveva di un punto fino al giorno dopo.
///
/// 💡 Questa parte dal **modello a tre processi** (Åkerstedt & Folkard) — la
/// stessa matematica dei sistemi di rischio-fatica dell'aviazione — e usa HRV,
/// battito e carico come **modificatori**, non come fondamenta.
Future<Reattivita?> _reattivitaAdesso({
  required DateTime adesso,
  required GiudizioNotte? notte,
  required DiarioLocale diario,
  required double? zHrv,
  required double? zBattito,
  required double? zCarico,
}) async {
  /*
   * ⛔ **Senza notte non c'è reattività**, e non è pigrizia: senza sapere quando
   * ti sei svegliato non si sa da quanto sei in piedi, che è metà del modello.
   * 🚨 Inventare un risveglio alle 7 darebbe un numero preciso e falso a chi si
   * alza alle 5 o alle 11.
   */
  if (notte == null) return null;

  final oreSveglio = (adesso.difference(notte.a).inMinutes / 60)
      .clamp(0, 24)
      .toDouble();

  /*
   * 🍽️ **L'ultimo pasto vero**, non l'ora di pranzo media.
   *
   * 💡 È il pezzo che il modello pubblicato non ha e noi sì: il diario sta sul
   * telefono, quindi sappiamo *quando* e *quanto* ha mangiato davvero. Un pranzo
   * alle 15:30 abbassa la reattività alle 16:30, non alle 14.
   */
  double? oreDalPasto;
  double? kcalDelPasto;

  final pasti = await diario.pastiScrittiDel(adesso);

  if (pasti.isNotEmpty) {
    final ultimo = pasti.reduce(
      (a, b) => a.scrittaIl.isAfter(b.scrittaIl) ? a : b,
    );

    final ore = adesso.difference(ultimo.scrittaIl).inMinutes / 60;

    // ⚠️ Mai negativo: una voce scritta «nel futuro» — succede, con l'orologio
    // storto — darebbe una digestione che non è ancora cominciata.
    if (ore >= 0) {
      oreDalPasto = ore;
      kcalDelPasto = ultimo.kcal.toDouble();
    }
  }

  return ModelloDellaReattivita.calcola(
    // 💡 Con i minuti: alle 14:30 il circadiano non è quello delle 14.
    oraDecimale: adesso.hour + adesso.minute / 60,
    oreSveglio: oreSveglio,
    oreDormite: notte.minutiDormiti / 60,
    oreDalPasto: oreDalPasto,
    kcalDelPasto: kcalDelPasto,
    zHrv: zHrv,
    zBattito: zBattito,
    zCarico: zCarico,
  );
}

/// Quanto è stato pesante il carico di oggi rispetto alla propria finestra.
///
/// ⚠️ `null` con meno di due giorni: uno z-score su un giorno solo non è uno
/// z-score, è quel giorno diviso se stesso.
double? _zDelCarico(List<double> carico) {
  final visti = carico.where((c) => c > 0).toList();

  if (visti.length < 2) return null;

  final stat = IndiciDiForma.mediaEDeviazione(visti);

  if (stat == null) return null;

  // 💡 `carico` è dal più recente all'indietro, come `minuti`.
  return IndiciDiForma.z(
    valore: carico.first,
    media: stat.$1,
    deviazione: stat.$2,
  );
}

/// Da quanti giorni si osservano gli **allenamenti**.
///
/// 💡 `0` quando non ce n'è nessuno: lì il carico non è «poco attendibile», è
/// **non calcolabile** — e ci pensa `IndiciDiForma.stanchezza`.
int _giorniDagliAllenamenti(List<VoceStorico> voci, DateTime mezzanotte) {
  if (voci.isEmpty) return 0;

  var piuVecchio = 0;

  for (final v in voci) {
    final giorno = DateTime(v.quando.year, v.quando.month, v.quando.day);
    final quantiFa = mezzanotte.difference(giorno).inDays;

    if (quantiFa > piuVecchio) piuVecchio = quantiFa;
  }

  // ⚠️ `+1` perché oggi stesso è un giorno di osservazione: chi ha registrato
  // il primo allenamento stamattina ha **un** giorno di storia, non zero.
  return piuVecchio + 1;
}

extension on Indice {
  /// 💡 `IndiciDiForma` è puro e non sa da quanto esiste l'archivio: glielo dice
  /// chi i dati li ha letti.
  Indice _conStoria(int giorni) => Indice(
    valore: valore,
    giorniDiStoria: giorni,
    giorniPerEsserePieno: giorniPerEsserePieno,
  );
}
