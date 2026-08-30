import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/storage/archivio_salute.dart';
import 'package:training_companion/src/features/dashboard/ui/widgets/scheda_composizione.dart';
import 'package:training_companion/src/features/profile/corpo_controller.dart';

/// 🎯 La card della composizione, e **le tre strade quando il dato non c'è**.
///
/// 📌 *«ovviamente sempre con la guardia che se quei dati non ci sono si
/// chiedono, si stimano o si nasconde la card»*.
///
/// | Manca | Cosa deve fare |
/// |---|---|
/// | il **peso** | 🫥 sparire del tutto |
/// | la **massa grassa** | 🙋 chiederla, con una riga |
/// | la **storia** | 📸 mostrare la fotografia, e dire fra quanto |
///
/// ⛔ **E non stimare mai.** Esistono formule che tirano fuori una massa grassa
/// da BMI, età e sesso: sbagliano di cinque punti, cioè cinque chili su cento.
/// 🚨 Una composizione stimata avrebbe l'aria di una misura e non lo sarebbe.
void main() {
  final oggi = DateTime.now();

  MisuraCorpo m(int giorniFa, {double? kg, double? pct}) => MisuraCorpo(
    id: 0,
    giorno: DateTime(
      oggi.year,
      oggi.month,
      oggi.day,
    ).subtract(Duration(days: giorniFa)),
    pesoKg: kg,
    massaGrassaPct: pct,
  );

  Future<void> monta(WidgetTester tester, List<MisuraCorpo> storico) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [storicoCorpoProvider.overrideWith((ref) async => storico)],
        child: const MaterialApp(home: Scaffold(body: SchedaComposizione())),
      ),
    );

    await tester.pumpAndSettle();
  }

  /// 🫥 **Senza peso la card non esiste**, e non dice nemmeno che manca: lo
  /// dice già la scheda del peso qui sopra, e due inviti alla stessa cosa uno
  /// sotto l'altro sembrano un difetto.
  testWidgets('senza peso non si disegna niente', (tester) async {
    await monta(tester, const []);

    expect(find.byType(Card), findsNothing);
    expect(find.textContaining('grasso'), findsNothing);
  });

  /// 🙋 **Con il peso ma senza massa grassa: si chiede.**
  ///
  /// ⚠️ Una riga, non una card grande: chi non ha una bilancia a bioimpedenza
  /// non deve trovarsi un invito grosso quanto le card che contengono dati.
  testWidgets('con il peso ma senza grasso, la chiede', (tester) async {
    await monta(tester, [m(0, kg: 95.9)]);

    expect(find.textContaining('massa grassa'), findsOneWidget);

    /*
     * 🚨 **E non inventa un numero.** Se comparisse una percentuale, sarebbe
     * stimata — cioè plausibile e falsa.
     */
    expect(find.textContaining('%'), findsNothing);
    expect(find.textContaining('kg'), findsNothing);
  });

  /// 📸 **Con una misura sola: la fotografia c'è, la conclusione no.**
  ///
  /// 💡 E si dice **quando** arriva: «servono 21 giorni» è un'informazione,
  /// tacere è un muro.
  testWidgets('con poca storia mostra la fotografia e dice fra quanto', (
    tester,
  ) async {
    await monta(tester, [m(0, kg: 100, pct: 25)]);

    expect(find.textContaining('25.0 kg'), findsOneWidget);
    expect(find.textContaining('75.0 kg'), findsOneWidget);

    expect(find.textContaining('21 giorni'), findsOneWidget);

    // ⛔ Nessun verdetto: non c'è niente da confrontare.
    expect(find.textContaining('Stai perdendo'), findsNothing);
  });

  /// 🎯 **Con tre settimane di storia arriva la conclusione.**
  testWidgets('con abbastanza storia conclude', (tester) async {
    await monta(tester, [
      for (var i = 0; i <= 2; i++) m(i, kg: 97.5, pct: 25.6),
      for (var i = 20; i <= 22; i++) m(i, kg: 100, pct: 28),
    ]);

    expect(find.textContaining('Stai perdendo grasso'), findsOneWidget);

    // 💡 E i due numeri sotto la frase, con il segno.
    expect(find.textContaining('grasso −'), findsOneWidget);
  });

  /// 🚨 **Il caso che giustifica tutta la card**: lo stesso calo di peso, ma se
  /// ne va anche il muscolo. ⛔ Sulla bilancia i due casi sono identici.
  testWidgets('e sa dire quando se ne va anche il muscolo', (tester) async {
    await monta(tester, [
      for (var i = 0; i <= 2; i++) m(i, kg: 97.5, pct: 27.4),
      for (var i = 20; i <= 22; i++) m(i, kg: 100, pct: 28),
    ]);

    expect(find.textContaining('massa magra'), findsWidgets);
    expect(
      find.textContaining('Stai perdendo anche massa magra'),
      findsOneWidget,
      reason:
          'Con lo stesso calo di peso del test precedente la card dice la '
          'stessa cosa: è l\'unica differenza che la massa grassa aggiunge, '
          'ed è il motivo per cui questa card esiste.',
    );
  });

  /// ⛔ Una percentuale a zero è una misura fallita, non «zero grasso»: la card
  /// torna a chiedere invece di disegnare un corpo senza grasso.
  testWidgets('una percentuale impossibile non diventa una composizione', (
    tester,
  ) async {
    await monta(tester, [m(0, kg: 95.9, pct: 0)]);

    expect(find.textContaining('massa grassa'), findsOneWidget);
    expect(find.textContaining('0.0 kg'), findsNothing);
  });
}
