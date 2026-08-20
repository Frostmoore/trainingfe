import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../health/analizzatore_sonno.dart';
import '../health/dati_salute.dart';
import '../health/health_controller.dart';
import '../training/storico_unificato_controller.dart';
import 'indici_di_forma.dart';

/// Stanchezza e carica, con i dati veri — FASE 2-sexies.
///
/// 🚨 **Tutto sul telefono.** L'indice è un dato sanitario **derivato**, e
/// calcolarlo sul server vorrebbe dire ricreare esattamente ciò che la decisione
/// D9-bis ha smontato. ⚠️ Qui non c'è nessuna chiamata di rete, e non ce ne deve
/// finire nessuna: chi ne aggiungesse una starebbe annullando la fase.
class Forma {
  const Forma({required this.stanchezza, required this.carica});

  final Indice stanchezza;
  final Indice carica;

  FasciaCarico? get fascia {
    final v = stanchezza.valore;

    return v == null ? null : FasciaCarico.da(v);
  }
}

/// Quanti giorni indietro si guarda: la finestra lunga dell'`ACWR`.
const _finestra = IndiciDiForma.giorniCronici;

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
  final storiaCarico = await _giorniDiArchivio(ref, oggi);

  // ── La carica: z-score contro le proprie medie ───────────────────────────
  Future<double?> zDi(MetricaSalute m) async {
    final righe = await archivio.mediePerGiorno(m, giorni: _finestra);

    if (righe.length < 2) return null;

    final valori = righe.map((r) => r.media).toList();
    final ultimo = valori.last;

    final stat = IndiciDiForma.mediaEDeviazione(valori);
    if (stat == null) return null;

    return IndiciDiForma.z(
      valore: ultimo,
      media: stat.$1,
      deviazione: stat.$2,
    );
  }

  final zHrv = await zDi(MetricaSalute.hrv);
  final zBattito = await zDi(MetricaSalute.battitoARiposo);

  // ── Il sonno ─────────────────────────────────────────────────────────────
  final minuti = <double>[];

  for (var i = 0; i < _finestra; i++) {
    final n = await AnalizzatoreSonno.notte(
      archivio,
      mezzanotte.subtract(Duration(days: i)),
    );

    // ⚠️ I buchi non si riempiono: una notte senza dati non è una notte da zero.
    if (n != null) minuti.add(n.minutiDormiti.toDouble());
  }

  double? zSonno;

  if (minuti.length >= 2) {
    final stat = IndiciDiForma.mediaEDeviazione(minuti);

    if (stat != null) {
      zSonno = IndiciDiForma.z(
        // 💡 `minuti` è dal più recente all'indietro: l'ultima notte è la prima.
        valore: minuti.first,
        media: stat.$1,
        deviazione: stat.$2,
      );
    }
  }

  return Forma(
    stanchezza: IndiciDiForma.stanchezza(carico)._conStoria(storiaCarico),
    carica: IndiciDiForma.carica(
      zHrv: zHrv,
      zBattito: zBattito,
      zSonno: zSonno,
      nottiDiStoria: minuti.length,
    ),
  );
});

/// Da quanti giorni l'archivio ha qualcosa da dire.
///
/// 💡 Si guarda il **sonno**, che è il dato che arriva ogni notte appena Health
/// Connect è collegato: è il modo più semplice di sapere da quando l'app
/// raccoglie. ⚠️ Guardare gli allenamenti darebbe zero a chi non si allena, e la
/// nota direbbe «mancano 28 giorni» per sempre.
Future<int> _giorniDiArchivio(Ref ref, DateTime oggi) async {
  try {
    final righe = await ref
        .read(archivioSaluteProvider)
        .mediePerGiorno(MetricaSalute.hrv, giorni: _finestra);

    if (righe.isEmpty) return 0;

    final primo = righe.first.giorno;

    return DateTime(oggi.year, oggi.month, oggi.day).difference(primo).inDays + 1;
  } on Object catch (e) {
    debugPrint('forma: non riesco a datare l\'archivio — $e');

    return 0;
  }
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
