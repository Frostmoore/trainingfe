import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/storage/archivio_salute.dart';
import 'package:training_companion/src/features/health/salute_in_piu.dart';
import 'package:training_companion/src/features/training/ui/widgets/forma_del_percorso.dart';

/// Il percorso di un allenamento — 08/09/2026.
///
/// ══ 🚨 COSA DIFENDONO ════════════════════════════════════════════════════
///
/// 📌 *«se non metto la foto ci deve essere la forma del percorso che ho
/// fatto»*.
///
/// ⛔ Il percorso è **il dato più sensibile che l'app legge**: dice dove sei
/// stato e a che ora. 🚨 Un difetto qui non è un pixel storto — è un consenso
/// chiesto due volte, un rifiuto dimenticato, o una traccia salvata dove non
/// doveva.
void main() {
  PuntoDelPercorso punto(
    double lat,
    double lon, {
    double? quota,
    int min = 0,
  }) => PuntoDelPercorso(
    latitudine: lat,
    longitudine: lon,
    quotaMetri: quota,
    istante: DateTime(2026, 9, 8, 10, 49).add(Duration(minutes: min)),
  );

  group('💾 l\'archivio', () {
    test('✅ un percorso salvato si rilegge uguale', () async {
      final archivio = ArchivioSalute.inMemoria();

      addTearDown(archivio.close);

      await archivio.scriviIlPercorso(
        allenamentoId: 7,
        punti: [
          punto(44.4056, 8.9463, quota: 12.5),
          punto(44.4061, 8.9470, min: 1),
        ],
      );

      final riletti = await archivio.percorsoDi(7);

      expect(riletti, hasLength(2));
      expect(riletti!.first.latitudine, closeTo(44.4056, 0.00001));
      expect(riletti.first.quotaMetri, 12.5);

      /*
       * ⚠️ **La quota può mancare punto per punto**, non solo per tutto il
       * percorso: il GPS la perde e la ritrova. 🚨 Se il salvataggio la
       * riempisse con uno zero, una salita diventerebbe piatta.
       */
      expect(riletti.last.quotaMetri, isNull);
    });

    test(
      '⛔ un rifiuto NON è un percorso assente, ed è la distinzione che conta',
      () async {
        final archivio = ArchivioSalute.inMemoria();

        addTearDown(archivio.close);

        // 💡 Lista vuota = la finestra chiusa senza concedere.
        await archivio.scriviIlPercorso(allenamentoId: 7, punti: const []);

        /*
       * 🚨 Senza questa distinzione la pagina richiederebbe il consenso a ogni
       * apertura a chi ha già detto di no: un rifiuto diventerebbe un assillo.
       */
        expect(await archivio.percorsoDi(7), isNull);
        expect(await archivio.percorsoRifiutato(7), isTrue);
      },
    );

    test('⚠️ e «mai chiesto» è ancora un\'altra cosa', () async {
      final archivio = ArchivioSalute.inMemoria();

      addTearDown(archivio.close);

      expect(await archivio.percorsoDi(7), isNull);
      expect(await archivio.percorsoRifiutato(7), isFalse);
    });

    test('🔁 chiederlo di nuovo sostituisce, non impila', () async {
      final archivio = ArchivioSalute.inMemoria();

      addTearDown(archivio.close);

      await archivio.scriviIlPercorso(allenamentoId: 7, punti: const []);
      await archivio.scriviIlPercorso(
        allenamentoId: 7,
        punti: [punto(44.40, 8.94), punto(44.41, 8.95, min: 1)],
      );

      expect(await archivio.percorsoRifiutato(7), isFalse);
      expect(await archivio.percorsoDi(7), hasLength(2));
    });

    test('📋 lo storico sa quali allenamenti hanno un percorso', () async {
      final archivio = ArchivioSalute.inMemoria();

      addTearDown(archivio.close);

      await archivio.scriviIlPercorso(
        allenamentoId: 7,
        punti: [punto(44.40, 8.94), punto(44.41, 8.95, min: 1)],
      );
      await archivio.scriviIlPercorso(allenamentoId: 9, punti: const []);

      /*
       * ⛔ **Il rifiutato non ci sta**: nello storico la sua cella deve mostrare
       * l'icona del tipo, non aspettare un tracciato che non arriverà.
       */
      expect(await archivio.allenamentiConPercorso(), {7});
    });
  });

  group('🗺️ il disegno', () {
    testWidgets('✅ un tracciato vero si disegna senza rompere niente', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 150,
              height: 150,
              child: FormaDelPercorso(
                punti: [
                  for (var i = 0; i < 60; i++)
                    punto(44.40 + i * 0.0004, 8.94 + i * 0.0006, min: i),
                ],
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('⛔ con meno di due punti non si disegna niente', (
      tester,
    ) async {
      /*
       * 🚨 Un punto solo non è un percorso: sarebbe un puntino ingrandito a
       * tutta card, che somiglia a un guasto più che a un dato.
       */
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: FormaDelPercorso(punti: [punto(44.40, 8.94)])),
        ),
      );

      /*
       * ⚠️ Si misura la **dimensione**, non l'assenza di un `CustomPaint`: lo
       * `Scaffold` ne contiene di suoi, e cercare quel tipo avrebbe trovato i
       * suoi invece dei nostri — un test verde per il motivo sbagliato.
       */
      expect(tester.getSize(find.byType(FormaDelPercorso)), Size.zero);
    });

    testWidgets('⚠️ e un percorso fermo non esplode', (tester) async {
      /*
       * ⛔ Sessanta punti tutti nella stessa posizione — succede col GPS che non
       * aggancia — darebbero larghezza e altezza zero, cioè una divisione per
       * zero dentro la scala.
       */
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 100,
              height: 100,
              child: FormaDelPercorso(
                punti: [
                  for (var i = 0; i < 60; i++) punto(44.40, 8.94, min: i),
                ],
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('💡 e regge una cella minuscola', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 24,
              height: 24,
              child: FormaDelPercorso(
                punti: [
                  for (var i = 0; i < 200; i++)
                    punto(44.40 + i * 0.0001, 8.94 + i * 0.0002, min: i),
                ],
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('🔁 andata e ritorno del dato', () {
    test('✅ un punto sopravvive al JSON', () {
      final prima = punto(44.4056, 8.9463, quota: 12.5, min: 3);
      final dopo = PuntoDelPercorso.dalDato(prima.versoIlDato());

      expect(dopo, isNotNull);
      expect(dopo!.latitudine, prima.latitudine);
      expect(dopo.longitudine, prima.longitudine);
      expect(dopo.quotaMetri, prima.quotaMetri);
      expect(dopo.istante, prima.istante);
    });

    test('⛔ e un dato monco non diventa un punto a zero', () {
      /*
       * 🚨 `lat: 0, lon: 0` è un posto vero — in mezzo all'Atlantico, al largo
       * della Guinea. ⛔ Un punto costruito con dei ripieghi finirebbe nel
       * disegno e trascinerebbe tutto il tracciato in fondo alla mappa.
       */
      expect(PuntoDelPercorso.dalDato({'lat': 44.4}), isNull);
      expect(PuntoDelPercorso.dalDato({'lon': 8.9}), isNull);
      expect(PuntoDelPercorso.dalDato('non è una mappa'), isNull);
      expect(PuntoDelPercorso.dalDato(null), isNull);
    });
  });
}
