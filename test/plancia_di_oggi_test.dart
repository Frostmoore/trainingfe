/// 🎛️ **La plancia di Oggi** — `plan_interfaccia.md` I2, 19/11/2026.
///
/// | Caso | Cosa difende |
/// |---|---|
/// | ci sono i tre strumenti di prima | R1: gli strumenti cambiano posto, non forma (I2.D2) |
/// | le frasi della vecchia card sono venute con loro | la fascia del carico, «stamattina eri a» |
/// | toccarla apre le formule | la strada verso `AppRoutes.forma` non sparisce con la card (I2.D3) |
/// | senza carica non c'è la batteria | *«un TDEE inventato darebbe una scarica inventata»* |
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:training_companion/src/core/router/app_router.dart';
import 'package:training_companion/src/core/storage/archivio_salute.dart';
import 'package:training_companion/src/features/dashboard/ui/widgets/plancia_di_oggi.dart';
import 'package:training_companion/src/features/forma/carica_batteria.dart';
import 'package:training_companion/src/features/forma/carica_controller.dart';
import 'package:training_companion/src/features/forma/forma_controller.dart';
import 'package:training_companion/src/features/forma/indici_di_forma.dart';
import 'package:training_companion/src/features/forma/ui/barra_carico.dart';
import 'package:training_companion/src/features/forma/ui/pezzi_della_forma.dart';
import 'package:training_companion/src/features/forma/ui/tachimetro_prontezza.dart';
import 'package:training_companion/src/features/health/health_controller.dart';

void main() {
  Forma forma() => Forma(
    reattivita: null,
    stanchezza: const Indice(
      valore: 1.12,
      giorniDiStoria: 28,
      giorniPerEsserePieno: IndiciDiForma.giorniCronici,
    ),
    prontezza: const Indice(
      valore: 62,
      giorniDiStoria: 28,
      giorniPerEsserePieno: IndiciDiForma.nottiPerLaProntezza,
    ),
    acuto: 480,
    cronico: 430,
    caricoPerGiorno: List<double>.filled(28, 120),
    ingredienti: const [],
  );

  const carica = Carica(
    adesso: 68,
    mattina: 74,
    affidabilita: Affidabilita.media,
    giorniValidi: 12,
  );

  Future<void> monta(
    WidgetTester tester, {
    Carica? conCarica = carica,
    bool conLeSpiegazioni = false,
  }) async {
    final archivio = ArchivioSalute.inMemoria();
    addTearDown(archivio.close);

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: SingleChildScrollView(
              child: PlanciaDiOggi(conLeSpiegazioni: conLeSpiegazioni),
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.forma,
          builder: (_, _) => const Scaffold(body: Text('LE FORMULE')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          archivioSaluteProvider.overrideWithValue(archivio),
          formaProvider.overrideWith((ref) async => forma()),
          caricaProvider.overrideWith((ref) async => conCarica),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('ci sono batteria, tachimetro e barra del carico', (
    tester,
  ) async {
    await monta(tester);

    expect(find.byType(BatteriaCarica), findsOneWidget);
    expect(find.byType(TachimetroProntezza), findsOneWidget);
    expect(find.byType(BarraCarico), findsOneWidget);
  });

  /// 🆕 20/11/2026 — il committente, sulla 22.9.0: *«Un bugiardino di una
  /// medicina sopra?? deve essere come nella tavola»*. Su «Oggi» la plancia ha
  /// **solo gli strumenti**; le frasi stanno in «Carico e carica».
  testWidgets('su Oggi la plancia ha solo gli strumenti, come nella tavola', (
    tester,
  ) async {
    await monta(tester);

    expect(find.text('112%'), findsOneWidget);
    expect(find.text('stamattina eri a 74'), findsNothing);
    expect(find.byType(AffidabilitaDellaCarica), findsNothing);
  });

  testWidgets('in «Carico e carica» le frasi della vecchia card ci sono', (
    tester,
  ) async {
    // ⛔ Non cancellate: le aveva chieste il committente una per una.
    await monta(tester, conLeSpiegazioni: true);

    expect(find.text('112%'), findsOneWidget);
    expect(find.text('stamattina eri a 74'), findsOneWidget);
    expect(find.byType(AffidabilitaDellaCarica), findsOneWidget);
  });

  /// 🆕 20/11/2026 — dove sono finite le avvertenze. ⚠️ Sul sorgente e senza
  /// commenti: `TodayHeader` vuole mezza app per disegnarsi, e qui conta
  /// **quale** avvertenza c'è, non come si disegna.
  test("Oggi ha l'avvertenza corta; le lunghe stanno in «Carico e carica»", () {
    String codice(String p) => File(p)
        .readAsStringSync()
        .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), ' ')
        .replaceAll(RegExp(r'//[^\n]*'), ' ');

    final oggi = codice(
      'lib/src/features/dashboard/ui/widgets/today_header.dart',
    );
    expect(oggi, contains('AvvertenzaBreve()'));
    expect(oggi, isNot(contains('AvvertenzaStima()')));
    expect(oggi, isNot(contains('AvvertenzaDellaCarica()')));
    // La data in cima, come nella tavola.
    expect(oggi, contains('navigatore: data'));

    final forma = codice('lib/src/features/forma/ui/schermata_forma.dart');
    expect(forma, contains('AvvertenzaStima()'));
    expect(forma, contains('AvvertenzaDellaCarica()'));
    expect(forma, contains('conLeSpiegazioni: true'));
  });

  testWidgets('toccarla apre la pagina delle formule', (tester) async {
    await monta(tester);

    await tester.tap(find.byType(TachimetroProntezza));
    await tester.pumpAndSettle();

    expect(find.text('LE FORMULE'), findsOneWidget);
  });

  testWidgets('senza carica non si disegna la batteria', (tester) async {
    await monta(tester, conCarica: null);

    expect(find.byType(BatteriaCarica), findsNothing);
    expect(find.byType(TachimetroProntezza), findsOneWidget);
  });
}
