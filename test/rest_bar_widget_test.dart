import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/training/rest_timer.dart';
import 'package:training_companion/src/features/training/ui/widgets/rest_bar.dart';

/// La barra del riposo, disegnata davvero.
///
/// 🚨 **Il primo widget test dell'app, e c'è un motivo preciso.**
/// Sul telefono la barra del recupero non compariva: sembrava che il timer non
/// partisse. La causa era un `RenderFlex overflowed` durante il layout — che
/// **non è solo una striscia gialla**: lascia il `Material` senza dimensione, e
/// da lì parte una cascata di «RenderBox was not laid out» che finisce col non
/// disegnare niente. Nessun test poteva accorgersene, perché tutti gli altri
/// sono unit test su modelli e controller.
///
/// La disposizione riprodotta è quella vera del player: `Column` con un
/// `Expanded(ListView)` sopra e la barra in fondo.
void main() {
  Widget dentroIlPlayer(RestTimer timer) => MaterialApp(
    home: Scaffold(
      body: Column(
        children: [
          Expanded(child: ListView(children: const [SizedBox(height: 400)])),
          RestBar(timer: timer),
        ],
      ),
    ),
  );

  /// Esegue il corpo con un recupero avviato, e lo **ferma comunque**.
  ///
  /// ⚠️ Deve fermarsi dentro il corpo del test, non in `addTearDown`: il
  /// controllo «nessun timer pendente» del framework gira **prima** dei
  /// tearDown, e fallirebbe su un timer perfettamente sano.
  Future<void> conRecupero(int secondi, Future<void> Function(RestTimer) corpo) async {
    final timer = RestTimer()..notificheAttive = false;

    await timer.avvia(secondi);

    try {
      await corpo(timer);
    } finally {
      await timer.salta();
      timer.dispose();
    }
  }

  testWidgets('si disegna dentro la colonna del player senza esplodere', (tester) async {
    await conRecupero(90, (timer) async {
      await tester.pumpWidget(dentroIlPlayer(timer));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('recupero'), findsOneWidget);
      expect(find.text('−15 s'), findsOneWidget);
      expect(find.text('+15 s'), findsOneWidget);
      expect(find.text('Salta'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });
  });

  /// 🚨 Il test che riproduce il difetto vero: a 320 px la vecchia riga unica
  /// sforava di 114 pixel.
  testWidgets('su uno schermo stretto non trabocca', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await conRecupero(90, (timer) async {
      await tester.pumpWidget(dentroIlPlayer(timer));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  /// ⚠️ E nemmeno con il testo ingrandito: chi ingrandisce i caratteri di
  /// sistema non deve perdere una funzione.
  testWidgets('con il testo ingrandito non trabocca', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await conRecupero(90, (timer) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
          child: dentroIlPlayer(timer),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('«−15 s» accorcia, e sotto zero il recupero finisce', (tester) async {
    await conRecupero(20, (timer) async {
      await tester.pumpWidget(dentroIlPlayer(timer));
      await tester.pump();

      await tester.tap(find.text('−15 s'));
      await tester.pump();

      expect(timer.rimanenti, lessThanOrEqualTo(5));

      // Il secondo colpo porterebbe sotto zero: il recupero deve **finire**,
      // non restare piantato su «0:00» finché non lo si salta a mano.
      await tester.tap(find.text('−15 s'));
      await tester.pump();

      expect(timer.attivo, isFalse);
    });
  });

  testWidgets('«+15 s» allunga', (tester) async {
    await conRecupero(60, (timer) async {
      await tester.pumpWidget(dentroIlPlayer(timer));
      await tester.pump();

      final prima = timer.rimanenti;

      await tester.tap(find.text('+15 s'));
      await tester.pump();

      expect(timer.rimanenti, greaterThan(prima));
    });
  });

  testWidgets('«Salta» ferma il recupero e la barra sparisce', (tester) async {
    await conRecupero(90, (timer) async {
      await tester.pumpWidget(dentroIlPlayer(timer));
      await tester.pump();

      await tester.tap(find.text('Salta'));
      await tester.pump();

      expect(timer.attivo, isFalse);
      expect(find.text('recupero'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('a riposo fermo non occupa spazio', (tester) async {
    final timer = RestTimer()..notificheAttive = false;
    addTearDown(timer.dispose);

    await tester.pumpWidget(dentroIlPlayer(timer));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('recupero'), findsNothing);
  });
}
