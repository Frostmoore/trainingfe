import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:training_companion/src/core/storage/archivio_salute.dart';
import 'package:training_companion/src/features/diary/data/stima_ai.dart';
import 'package:training_companion/src/features/training/data/catalogo_esercizi.dart';
import 'package:training_companion/src/features/training/data/storico_unificato.dart';
import 'package:training_companion/src/features/training/storico_unificato_controller.dart';
import 'package:training_companion/src/features/training/ui/allenamento_orologio_screen.dart';

import 'aiuto/intestazione.dart';

/// La pagina dell'allenamento dell'orologio — 3b-A.9 — e la porzione
/// stimata — 3b-A.10. 24/08/2026.
void main() {
  setUpAll(() => initializeDateFormatting('it'));

  /*
   * 🚨 **L'intestazione condivisa vuole cache e configurazione.** Da 3b-O.1a.6
   * ogni pagina porta `IntestazioneApp`, e `localCacheProvider` /
   * `appConfigProvider` **lanciano apposta** finché `bootstrap()` non li
   * sovrascrive: quel `throw` è una difesa, non un difetto.
   */
  late List<Override> base;

  setUp(() async => base = await intestazioneFinta());

  AllenamentoDaOrologio orologio({
    required int id,
    required String tipo,
    int minuti = 60,
    int? kcal,
    int? metri,
    int? passi,
  }) => AllenamentoDaOrologio(
    id: id,
    fonte: 'com.google.android.apps.fitness',
    tipo: tipo,
    iniziatoIl: DateTime(2026, 8, 24, 18),
    finitoIl: DateTime(2026, 8, 24, 18).add(Duration(minutes: minuti)),
    kcal: kcal,
    distanzaMetri: metri,
    passi: passi,
    nascosto: false,
    staccato: false,
  );

  Future<void> apri(WidgetTester tester, AllenamentoDaOrologio a) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          storicoUnificatoProvider.overrideWith(
            (ref) async => [
              VoceStorico(sedute: const [], dalPolso: [a]),
            ],
          ),
          catalogoEserciziProvider.overrideWith(
            (ref) async => CatalogoEsercizi.vuoto,
          ),
        ],
        child: MaterialApp(home: AllenamentoOrologioScreen(id: a.id)),
      ),
    );

    await tester.pumpAndSettle();
  }

  // ═════════════════════ A.9 ═════════════════════

  group('A.9 — la pagina esiste e dice le cose giuste', () {
    testWidgets('una corsa mostra i km e il ritmo', (tester) async {
      await apri(
        tester,
        orologio(id: 1, tipo: 'RUNNING', metri: 10000, kcal: 700),
      );

      expect(find.text('Corsa'), findsOneWidget);
      expect(find.text('10,0 km'), findsOneWidget);
      // 60 minuti per 10 km = 6:00 al chilometro.
      expect(find.text('6:00'), findsOneWidget);
      expect(find.text('700'), findsOneWidget);
    });

    /// ══ ⛔ IL TEST CHE CONTA DI PIÙ QUI ═══════════════════════════════════
    ///
    /// 📌 *«con le informazioni che si possono prendere e le cose che hanno
    /// **rilevanza**»*.
    ///
    /// 🚨 «0 km» su una seduta di pesi e «— passi» su una nuotata non sono
    /// informazioni: sono spazio riempito, e insegnano a non leggere il
    /// riquadro.
    testWidgets('i pesi NON mostrano i km né il ritmo', (tester) async {
      await apri(tester, orologio(id: 2, tipo: 'STRENGTH_TRAINING', kcal: 300));

      expect(find.text('Pesi'), findsOneWidget);
      expect(find.text('300'), findsOneWidget);
      expect(find.textContaining('km'), findsNothing);
      expect(find.textContaining('percorsi'), findsNothing);
      expect(find.textContaining('passi'), findsNothing);
    });

    /// ⚠️ Sotto il chilometro si scrivono i metri: «0,2 km» per una camminata
    /// in palestra sarebbe una precisione finta.
    testWidgets('e sotto il chilometro scrive i metri', (tester) async {
      await apri(tester, orologio(id: 3, tipo: 'WALKING', metri: 400));

      expect(find.text('400 m'), findsOneWidget);
      // ⛔ Nessun ritmo: su 400 m sarebbe un numero che non vuol dire niente.
      expect(find.textContaining('al chilometro'), findsNothing);
    });

    /// 💡 La figura del corpo è il servizio di A.6.1, riusato qui — che è il
    /// motivo per cui doveva essere riutilizzabile.
    testWidgets('una corsa colora la figura del corpo', (tester) async {
      await apri(tester, orologio(id: 4, tipo: 'RUNNING', metri: 5000));

      expect(find.text('Cosa hai mosso'), findsOneWidget);
    });

    /// ⛔ E uno sport che la tabella non conosce **non** mostra una figura
    /// grigia: sarebbe un riquadro che dice «non hai allenato niente» a chi si
    /// è appena allenato.
    testWidgets('ma uno sport sconosciuto non mostra una figura vuota', (
      tester,
    ) async {
      await apri(tester, orologio(id: 5, tipo: 'CHESS_BUT_ATHLETIC'));

      expect(find.text('Cosa hai mosso'), findsNothing);
    });

    testWidgets('e i tratti si dicono, quando sono più di uno', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...base,
            storicoUnificatoProvider.overrideWith(
              (ref) async => [
                VoceStorico(
                  sedute: const [],
                  dalPolso: [
                    orologio(id: 6, tipo: 'RUNNING', minuti: 20),
                    orologio(id: 7, tipo: 'RUNNING', minuti: 20),
                  ],
                ),
              ],
            ),
            catalogoEserciziProvider.overrideWith(
              (ref) async => CatalogoEsercizi.vuoto,
            ),
          ],
          child: const MaterialApp(home: AllenamentoOrologioScreen(id: 6)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('2 tratti'), findsOneWidget);
    });
  });

  // ═════════════════════ A.10 ═════════════════════

  group('A.10 — la porzione stimata si vede', () {
    /// ══ 🚨 LA SECONDA METÀ DELLA RICHIESTA ════════════════════════════════
    ///
    /// 📌 *«se non ho scritto la quantità, mi deve inserire la quantità normale
    /// di una porzione di quell'alimento»*.
    ///
    /// 💡 **La quantità la stimava già**: il prompt dice da sempre di mettere
    /// la porzione media italiana e `declared: false`. ⛔ Quello che mancava è
    /// che si **vedesse**: un numero inventato che sembra dichiarato è peggio
    /// di nessun numero (O.D.20). Chi non sa che è una stima non la corregge.
    test('una voce non dichiarata si riconosce dal dato', () {
      final v = VoceStimata.fromJson(const {
        'name': 'banana',
        'qty': 120,
        'unit': 'g',
        'grams': 120,
        'declared': false,
      });

      expect(v.dichiarata, isFalse);
      expect(v.grammi, 120);
    });

    test('e una dichiarata pure', () {
      final v = VoceStimata.fromJson(const {
        'name': 'pasta',
        'qty': 100,
        'unit': 'g',
        'grams': 100,
        'declared': true,
      });

      expect(v.dichiarata, isTrue);
    });

    /// ⚠️ **`null` non è `false`.** Una voce vecchia, o un percorso che non
    /// manda il campo, non si etichetta: non si sa, e scrivere «stimata» su una
    /// quantità che magari era dichiarata sarebbe lo stesso errore al
    /// contrario.
    test('ma senza il campo non si sa, e non si inventa', () {
      final v = VoceStimata.fromJson(const {'name': 'riso', 'grams': 80});

      expect(v.dichiarata, isNull);
      expect(v.dichiarata == false, isFalse, reason: 'null non è «stimata».');
    });
  });
}
