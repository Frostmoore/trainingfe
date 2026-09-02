/// La serie delle calorie assunte, **costruita sul telefono** — Parte I, I2.5.
///
/// ══ 🚨 TRASPORTATA, NON REINVENTATA ══════════════════════════════════════
///
/// 📌 Regola R2 della Parte I. Questo file è il ritratto fedele di
/// `App\Services\Training\SeriesService::calories()`: **stessa finestra, stesso
/// raggruppamento, stessa soglia di aggregazione, stesse medie, stesse
/// etichette**. ⛔ Un numero diverso qui non sarebbe un dettaglio: il grafico e
/// il diario mostrerebbero due totali per lo stesso giorno, ed è già successo
/// nell'app storica — è il motivo per cui quel servizio esiste.
///
/// ══ 💡 E CADE UN VINCOLO CHE COSTAVA CARO ════════════════════════════════
///
/// 🚨 `SeriesController` accettava solo `days ∈ {0, 7, 30, 90, 365}`, e chi
/// chiedeva altro prendeva un **422 che qualcuno intercettava in silenzio**. È
/// costato due difetti: la carica calcolata senza le calorie (21/08, chiedeva
/// 28) e il **TDEE misurato che non ha mai funzionato** (chiedeva 60, e il test
/// che sorvegliava la regola cercava un letterale — lì c'era una costante).
///
/// ⛔ Con la serie in casa quel vincolo **non esiste più**: si chiedono i giorni
/// che servono. 💡 `giorniAmmessiPerLeSerie` e il suo test restano finché
/// esistono chiamate a `/series`, e spariscono con I4.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/storage/archivio_salute.dart';
import '../../dashboard/data/serie.dart';
import '../../health/health_controller.dart';
import 'diario_locale.dart';

/// Oltre questa finestra si aggrega per mese.
///
/// ⚠️ Non è un limite tecnico: 400 barre su uno schermo di telefono sono larghe
/// mezzo pixel e non si leggono. Sopra i tre mesi la domanda cambia da «cosa ho
/// fatto martedì» a «come sto andando», e la risposta giusta è una media.
/// 📌 `SeriesService::GIORNI_PRIMA_DI_AGGREGARE`.
const giorniPrimaDiAggregare = 92;

/// Il passato che «tutto lo storico» copre davvero.
///
/// ⚠️ **Dieci anni anche qui**, come sul server, e produce le stesse ~120
/// colonne quasi tutte a zero. 🚨 Non si è "migliorato" partendo dalla prima
/// voce vera: sarebbe stato un grafico diverso da quello di ieri senza che
/// nessuno l'avesse chiesto, e la Parte I sposta i dati — non cambia le viste.
const _anniIndietro = 10;

/// Costruisce la serie delle calorie assunte.
class SerieDelCibo {
  const SerieDelCibo(this._archivio);

  final ArchivioSalute _archivio;

  /// [giorni] `0` = tutto lo storico. [offset] scorre di finestre **intere**.
  Future<Series> calorie({int giorni = 7, int offset = 0}) async {
    final (da, a, tutto) = _finestra(giorni, offset);

    final righe = await _archivio.vociFra(da, a);

    final assunte = <String, int>{};
    final proteine = <String, int>{};

    /*
     * 🚨 **Si somma e POI si arrotonda**, come `$gruppo->sum('kcal')` seguito da
     * `round()`. ⛔ Arrotondare voce per voce e poi sommare darebbe fino a mezza
     * caloria di scarto per riga: su una giornata da quindici voci il grafico
     * direbbe un numero e il diario un altro, per pochi kcal e senza spiegazione.
     */
    final kcalGrezze = <String, double>{};
    final proteineGrezze = <String, double>{};

    for (final r in righe) {
      final g = etichettaDelGiorno(r.mangiatoIl);

      kcalGrezze[g] = (kcalGrezze[g] ?? 0) + (r.kcal ?? 0);
      proteineGrezze[g] = (proteineGrezze[g] ?? 0) + (r.proteine ?? 0);
    }

    for (final e in kcalGrezze.entries) {
      assunte[e.key] = e.value.round();
    }

    for (final e in proteineGrezze.entries) {
      proteine[e.key] = e.value.round();
    }

    final perMese = tutto || giorni > giorniPrimaDiAggregare;

    return perMese
        ? _perMese(da, a, assunte, tutto: tutto)
        : _perGiorno(da, a, assunte, proteine);
  }

  // ───────────────────────── la finestra ─────────────────────────

  /// 🚨 **Parte da «oggi» di chi guarda**, non da UTC — A3. È già così per
  /// costruzione: qui si lavora su `DateTime` locali, che è il fuso del telefono.
  (DateTime, DateTime, bool) _finestra(int giorni, int offset) {
    final adesso = DateTime.now();
    final oggi = DateTime(adesso.year, adesso.month, adesso.day);

    if (giorni <= 0) {
      return (
        DateTime(oggi.year - _anniIndietro, oggi.month, oggi.day),
        oggi,
        true,
      );
    }

    /*
     * ⚠️ `offset` scorre di finestre **INTERE**: con 7 giorni, offset 1 è la
     * settimana prima, non «un giorno prima». Scorrere di un giorno alla volta
     * farebbe ballare le etichette a ogni tocco.
     */
    final a = _menoGiorni(oggi, offset * giorni);
    final da = _menoGiorni(a, giorni - 1);

    return (da, a, false);
  }

  // ───────────────────────── le due granularità ─────────────────────────

  Series _perGiorno(
    DateTime da,
    DateTime a,
    Map<String, int> assunte,
    Map<String, int> proteine,
  ) {
    final etichette = <String>[];
    final giorni = <String>[];
    final consumate = <double>[];
    final grammi = <double>[];

    for (var g = da; !g.isAfter(a); g = _piuGiorni(g, 1)) {
      final chiave = etichettaDelGiorno(g);

      etichette.add(DateFormat('dd/MM').format(g));
      giorni.add(chiave);
      consumate.add((assunte[chiave] ?? 0).toDouble());
      grammi.add((proteine[chiave] ?? 0).toDouble());
    }

    final medie = _medie(consumate);

    return Series(
      labels: etichette,
      dates: giorni,
      consumed: consumate,
      protein: grammi,
      granularity: 'day',
      period:
          '${DateFormat('dd/MM').format(da)} – '
          '${DateFormat('dd/MM/yyyy').format(a)}',
      avgConsumed: medie.$1,
      daysWithData: medie.$2,
      canGoBack: true,
    );
  }

  /// Aggregazione mensile come **media giornaliera**, non come somma.
  ///
  /// 🚨 Una somma mensile accanto a barre giornaliere sembra un'esplosione di
  /// calorie, e confrontata con un target giornaliero non vuol dire niente.
  Series _perMese(
    DateTime da,
    DateTime a,
    Map<String, int> assunte, {
    required bool tutto,
  }) {
    final etichette = <String>[];
    final giorni = <String>[];
    final consumate = <double>[];

    for (
      var mese = DateTime(da.year, da.month);
      !mese.isAfter(a);
      mese = DateTime(mese.year, mese.month + 1)
    ) {
      /*
       * ⚠️ L'ultimo mese si ferma **al giorno chiesto**, non alla fine del mese:
       * altrimenti la media del mese in corso includerebbe giorni non ancora
       * vissuti, contati come zero — cioè una media che cala ogni primo del mese
       * e risale piano, senza che nessuno abbia cambiato come mangia.
       */
      final fineMese = DateTime(mese.year, mese.month + 1, 0);
      final fine = fineMese.isAfter(a) ? a : fineMese;

      etichette.add(DateFormat('MM/yy').format(mese));

      // 💡 Il primo giorno del mese: sull'aggregato l'app non fonde niente, ma
      // la chiave resta leggibile invece che assente.
      giorni.add(etichettaDelGiorno(mese));

      final conDati = <int>[];

      for (var g = mese; !g.isAfter(fine); g = _piuGiorni(g, 1)) {
        final v = assunte[etichettaDelGiorno(g)] ?? 0;

        if (v > 0) conDati.add(v);
      }

      consumate.add(
        conDati.isEmpty
            ? 0
            : (conDati.reduce((x, y) => x + y) / conDati.length)
                  .roundToDouble(),
      );
    }

    final medie = _medie(consumate);

    return Series(
      labels: etichette,
      dates: giorni,
      consumed: consumate,
      granularity: 'month',
      period: tutto
          ? 'tutto lo storico (media al giorno, per mese)'
          : '${DateFormat('MM/yy').format(da)} – '
                '${DateFormat('MM/yy').format(a)} (media al giorno)',
      avgConsumed: medie.$1,
      daysWithData: medie.$2,
      canGoBack: !tutto,
    );
  }

  /// Le medie del periodo, **solo sui giorni con dati**.
  ///
  /// 🚨 Dividere per 7 quando si è registrato 3 giorni su 7 non dà «la media
  /// della settimana»: dà un numero più basso, che fa credere di essere in
  /// deficit. È l'errore che fa fallire un percorso senza che nessuno capisca
  /// perché.
  (int, int) _medie(List<double> consumate) {
    final conDati = consumate.where((v) => v > 0).toList();

    if (conDati.isEmpty) return (0, 0);

    return (
      (conDati.reduce((x, y) => x + y) / conDati.length).round(),
      conDati.length,
    );
  }
}

/*
| ⚠️ **`DateTime(y, m, d ± n)` e non `Duration(days: n)`** — I2.5.
|
| 🚨 Un `Duration` è **tempo assoluto**: nella notte del cambio d'ora aggiunge
| 24 ore a una giornata che ne dura 23, e la data salta o si ripete. 💡 Il
| costruttore normalizza i mesi e i giorni fuori intervallo, quindi
| `DateTime(2026, 3, 0)` è il 28 febbraio — che è esattamente ciò che serve.
*/
DateTime _menoGiorni(DateTime g, int n) => DateTime(g.year, g.month, g.day - n);

DateTime _piuGiorni(DateTime g, int n) => DateTime(g.year, g.month, g.day + n);

final serieDelCiboProvider = Provider<SerieDelCibo>(
  (ref) => SerieDelCibo(ref.watch(archivioSaluteProvider)),
);
