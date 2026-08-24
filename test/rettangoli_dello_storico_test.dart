import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:training_companion/src/core/storage/archivio_salute.dart';
import 'package:training_companion/src/features/training/data/storico_unificato.dart';
import 'package:training_companion/src/features/progress/progress_controller.dart';
import 'package:training_companion/src/features/training/settimana_scelta.dart';
import 'package:training_companion/src/features/training/storico_unificato_controller.dart';
import 'package:training_companion/src/features/training/ui/history_screen.dart';

/// Gli allenamenti come rettangoli, due per riga — 3b-A.5, 24/08/2026.
///
/// ══ 🚨 «DUE PER RIGA» È LA CLASSE DI DIFETTO DI QUESTO PROGETTO ═══════════
///
/// 📌 Il committente: *«Gli allenamenti dello storico devono essere rettangoli
/// verticali (due per riga) con la foto sopra e il dettaglio sotto»*.
///
/// ⚠️ È già successo **due volte**: una larghezza fissa dentro un contenitore
/// che manda a capo decide il numero di colonne per caso. Compila, passa
/// l'analizzatore, e a schermo ne fa tre.
///
/// ⛔ L'unico modo di saperlo è **misurare le posizioni vere** dopo aver
/// disegnato: due card sulla stessa riga hanno la stessa `dy`.
void main() {
  setUpAll(() => initializeDateFormatting('it'));

  final lunedi = lunediDi(DateTime.now());

  VoceStorico voce(int i, {String tipo = 'STRENGTH_TRAINING'}) => VoceStorico(
    sedute: const [],
    dalPolso: [
      AllenamentoDaOrologio(
        id: i,
        fonte: 'com.google.android.apps.fitness',
        tipo: tipo,
        // ⚠️ Sempre dentro la settimana in corso: è quella che la pagina
        // mostra, e un allenamento fuori settimana qui sparirebbe — dando un
        // «zero card» che sembrerebbe un difetto della griglia.
        iniziatoIl: lunedi.add(Duration(days: i % 7, hours: 18)),
        finitoIl: lunedi.add(Duration(days: i % 7, hours: 19)),
        kcal: 300 + i,
        nascosto: false,
        staccato: false,
      ),
    ],
  );

  Future<void> disegna(
    WidgetTester tester,
    List<VoceStorico> voci, {
    double larghezza = 328,
    double scalaTesto = 1,
  }) async {
    tester.view.physicalSize = Size(larghezza * 2, 1600 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storicoUnificatoProvider.overrideWith((ref) async => voci),
          // 💡 Nessuna foto: è il caso normale, ed è anche quello che mette in
          // difficoltà la griglia (A.5.2).
          fotoSessioneProvider.overrideWith((ref, id) async => const []),
        ],
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scalaTesto)),
            child: const Scaffold(body: StoricoAllenamenti()),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  // ───────────────────────── due per riga ─────────────────────────

  testWidgets('due card stanno sulla stessa riga', (tester) async {
    await disegna(tester, [voce(0), voce(1)]);

    final card = tester.widgetList<Card>(find.byType(Card)).toList();

    expect(card.length, 2, reason: 'Le card disegnate non sono due.');

    final righe = {
      for (var i = 0; i < card.length; i++)
        tester.getTopLeft(find.byType(Card).at(i)).dy,
    };

    expect(
      righe.length,
      1,
      reason:
          'Le due card sono finite su righe diverse: non sono due per riga.',
    );
  });

  testWidgets('e quattro card fanno due righe, non tre', (tester) async {
    await disegna(tester, [voce(0), voce(1), voce(2), voce(3)]);

    final quante = find.byType(Card).evaluate().length;
    final righe = {
      for (var i = 0; i < quante; i++)
        tester.getTopLeft(find.byType(Card).at(i)).dy,
    };

    expect(righe.length, 2);
  });

  /// ⚠️ 280 px è lo schermo più stretto che questo progetto controlla: è lì che
  /// i difetti di disposizione si misurano.
  testWidgets('restano due per riga anche a 280 px', (tester) async {
    await disegna(tester, [voce(0), voce(1)], larghezza: 280);

    final quante = find.byType(Card).evaluate().length;
    final righe = {
      for (var i = 0; i < quante; i++)
        tester.getTopLeft(find.byType(Card).at(i)).dy,
    };

    expect(righe.length, 1);
    expect(tester.takeException(), isNull);
  });

  // ───────────────────────── niente sfori ─────────────────────────

  /// 🚨 Un `RenderFlex overflowed` **non è una striscia gialla estetica**: è un
  /// layout che ha smesso di funzionare. ⛔ E nessun test sui modelli lo prende,
  /// perché il dato è giusto ed è il disegno a rompersi.
  testWidgets('nessuno sforo con dieci allenamenti', (tester) async {
    await disegna(tester, [for (var i = 0; i < 10; i++) voce(i)]);

    expect(tester.takeException(), isNull);
  });

  /// ⚠️ **L'altezza del testo è fissa** (`altezzaTesto`), quindi il carattere
  /// ingrandito è il caso che la rompe. È anche il caso che una persona che
  /// fatica a leggere ha **sempre** acceso.
  testWidgets('nemmeno a carattere ingrandito', (tester) async {
    await disegna(tester, [voce(0), voce(1)], scalaTesto: 1.3);

    expect(tester.takeException(), isNull);
  });

  // ───────────────────────── il ripiego della foto ─────────────────────────

  /// 🚨 **La maggior parte degli allenamenti non ha una foto**, e con la foto
  /// larga tutto il rettangolo la mancanza occupa i due terzi della card.
  /// ⛔ Un rettangolo grigio ripetuto otto volte sembra una pagina rotta.
  testWidgets('senza foto compare l icona del tipo, non un vuoto', (
    tester,
  ) async {
    await disegna(tester, [voce(0, tipo: 'RUNNING')]);

    // 💡 Qualunque icona: il punto è che **qualcosa** riempie lo spazio della
    // foto. Fissare *quale* legherebbe il test alla tabella dei tipi.
    expect(find.byType(Icon), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  // ───────────────────────── la settimana vuota ─────────────────────────

  testWidgets('una settimana senza allenamenti offre dove andare', (
    tester,
  ) async {
    // Un allenamento di tre settimane fa: la settimana mostrata è vuota.
    await disegna(tester, [
      VoceStorico(
        sedute: const [],
        dalPolso: [
          AllenamentoDaOrologio(
            id: 99,
            fonte: 'com.google.android.apps.fitness',
            tipo: 'STRENGTH_TRAINING',
            iniziatoIl: lunedi.subtract(const Duration(days: 21)),
            finitoIl: lunedi.subtract(const Duration(days: 21, hours: -1)),
            nascosto: false,
            staccato: false,
          ),
        ],
      ),
    ]);

    expect(find.text('Niente in questa settimana'), findsOneWidget);
    expect(find.text('Vai all\'ultimo allenamento'), findsOneWidget);
  });

  /// ⛔ **«Non ti sei mai allenato» e «non in questa settimana» sono diverse.**
  /// Dirle uguali è scoraggiante per la prima e inutile per la seconda.
  testWidgets('ma chi non si è mai allenato legge un altra cosa', (
    tester,
  ) async {
    await disegna(tester, const []);

    expect(find.text('Nessun allenamento'), findsOneWidget);
    expect(find.text('Vai all\'ultimo allenamento'), findsNothing);
  });
}
