import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/health/dati_salute.dart';
import 'package:training_companion/src/features/health/recupero_controller.dart';
import 'package:training_companion/src/features/health/serie_salute_controller.dart';
import 'package:training_companion/src/features/health/ui/widgets/grafico_metrica.dart';

/// 📊 **L'asse verticale è un righello regolare** — 23/09/2026.
///
/// ⛔ Sul telefono del committente, su `/sonno`, il grafico dell'HRV scriveva
/// **30 e 28 uno sopra l'altro**, e quello del battito **82 e 80**: due numeri
/// a due unità di distanza, che su quella scala sono un paio di pixel.
///
/// 🚨 **La causa**: `fl_chart` disegna le etichette a intervalli suoi **più due
/// ai bordi dell'asse** (`minY` e `maxY`). Quelle dei bordi non stanno sul
/// passo delle altre: cadono dove capita, e quando capita vicino a una della
/// griglia i due numeri si sovrappongono.
///
/// ⚠️ **La stessa trappola era già disinnescata sull'asse orizzontale**, nello
/// stesso file: *«Non una data per punto: con trenta giorni si sovrappongono e
/// non si legge niente»*. Sul verticale ci si era affidati al comportamento di
/// serie. 💡 Un asse non è più furbo dell'altro.
///
/// ══ 🚨 PERCHE' IL TEST GUARDA IL PASSO, E NON LA DISTANZA MINIMA ════════════
///
/// ⛔ **Il primo tentativo era vacuo, e se n'è accorto solo rimettendo il codice
/// vecchio**: chiedeva «nessuna coppia più vicina di 4 unità», e su questa
/// serie il codice rotto produceva `[28, 32, 49, 61]` — la coppia peggiore
/// distava esattamente 4, quindi passava. Il difetto vero sul telefono era a 2
/// unità: **con che serie si accavallano dipende dall'aritmetica interna di
/// `fl_chart`**, e una soglia scelta a mano è una scommessa su quell'aritmetica.
///
/// 💡 La proprietà che invece **non dipende dai numeri**: le etichette devono
/// essere a **passo costante**. Un righello con due tacche in più stipate agli
/// estremi è rotto sempre, anche le volte in cui per fortuna non si toccano.
/// Su `[28, 32, 49, 61]` i passi sono `4, 17, 12`: il test fallisce, come deve.
void main() {
  /// Una serie che con il codice di prima produceva quattro etichette e due
  /// passi diversi. ⚠️ Provata davvero, rimettendo il difetto.
  List<MediaGiornaliera> serieHrv() => [
    for (var i = 0; i < 30; i++)
      MediaGiornaliera(
        giorno: DateTime(2026, 8, 25).add(Duration(days: i)),
        media: [31.0, 58.0, 45.0, 39.0, 52.0][i % 5],
        minimo: 28,
        massimo: 60,
        quante: 1,
      ),
  ];

  /// I numeri interi scritti a schermo: sono le etichette verticali.
  ///
  /// ⛔ Le date dell'asse orizzontale («25/8») e le frasi della card restano
  /// fuori perché non sono interi puri.
  Future<List<int>> etichetteVerticali(
    WidgetTester tester,
    List<MediaGiornaliera> serie,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serieSaluteProvider(
            MetricaSalute.hrv,
          ).overrideWith((_) async => serie),
          // ⏳ Non si completa mai: al grafico serve solo per scrivere
          // «−20% dalla tua media» nell'intestazione, che qui non si guarda.
          recuperoProvider.overrideWith((_) => Completer<Recupero>().future),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: GraficoMetrica(metrica: MetricaSalute.hrv),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    return tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => int.tryParse(t.data ?? ''))
        .nonNulls
        .toList()
      ..sort();
  }

  testWidgets('le etichette stanno a passo costante', (tester) async {
    final valori = await etichetteVerticali(tester, serieHrv());

    expect(
      valori.length,
      greaterThanOrEqualTo(3),
      reason:
          'Zittendo i bordi sono sparite quasi tutte le etichette: un asse '
          'muto è peggio di un asse con due numeri appiccicati.',
    );

    final passi = [
      for (var i = 1; i < valori.length; i++) valori[i] - valori[i - 1],
    ];

    // ⚠️ Una tolleranza di 1 e non zero: le etichette sono arrotondate
    // all'intero, quindi un passo di 8,25 si legge come 8 e come 9.
    for (final passo in passi) {
      expect(
        (passo - passi.first).abs(),
        lessThanOrEqualTo(1),
        reason:
            'I passi fra le etichette sono $passi: non è un righello, è un '
            'righello con delle tacche in più agli estremi. È il difetto del '
            '23/09 — su questa serie il codice rotto dava [28, 32, 49, 61].',
      );
    }
  });

  testWidgets('una serie piatta non fa sparire l\'asse', (tester) async {
    /*
     * ⚠️ Il caso che rompe i grafici: tutti i valori uguali. Lì
     * `massimo - minimo` è zero, e un passo calcolato come frazione di zero
     * sarebbe zero — cioè nessuna etichetta, o infinite. 💡 Il margine ha un
     * `clamp` a 1.0 proprio per questo, e questo test lo tiene fermo.
     */
    final piatta = [
      for (var i = 0; i < 5; i++)
        MediaGiornaliera(
          giorno: DateTime(2026, 9, 19).add(Duration(days: i)),
          media: 45,
          minimo: 45,
          massimo: 45,
          quante: 1,
        ),
    ];

    expect(
      await etichetteVerticali(tester, piatta),
      isNotEmpty,
      reason: 'Con una serie piatta l\'asse verticale resta muto.',
    );
  });
}
