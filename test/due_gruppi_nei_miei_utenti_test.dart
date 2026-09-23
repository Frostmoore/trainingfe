import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/trainer/data/utente_seguito.dart';
import 'package:training_companion/src/features/trainer/trainer_controller.dart';
import 'package:training_companion/src/features/trainer/ui/miei_utenti_screen.dart';

import 'aiuto/intestazione.dart';

/// 👥 **«I miei utenti»: due gruppi, perché sono due cose** — 23/09/2026.
///
/// ══ ⛔ IL DIFETTO ══════════════════════════════════════════════════════════
///
/// Il giro UX ha trovato **«15 posti liberi su 15» sopra un elenco di cinque
/// persone**. 🚨 Tutti e due i numeri erano giusti: il banner conta gli allievi
/// **suoi** (zero), l'elenco mostrava anche **gli iscritti della palestra** dove
/// il trainer lavora (cinque).
///
/// ⚠️ Due scopi impilati senza dirlo. Chi legge non può ricomporli: o crede
/// rotto il contatore, o crede di poter invitare quindici persone **oltre** a
/// quelle che già vede.
///
/// 💡 Il dato per distinguerli c'era già (`UtenteSeguito.suo`, dal 16/09) e
/// serviva solo a nascondere un pulsante.
void main() {
  UtenteSeguito persona(String nome, {required bool suo}) => UtenteSeguito(
    id: nome.hashCode,
    nome: nome,
    email: '${nome.toLowerCase()}@esempio.test',
    attivo: true,
    suo: suo,
  );

  Future<void> disegna(
    WidgetTester tester,
    List<UtenteSeguito> utenti, {
    bool allieviPropri = true,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...await intestazioneFinta(),
          mieiUtentiProvider.overrideWith(
            (ref) async => MieiUtenti(
              utenti: utenti,
              posti: PostiDelTrainer(
                rimasti: 15,
                limite: 15,
                allieviPropri: allieviPropri,
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: MieiUtentiScreen()),
      ),
    );

    await tester.pumpAndSettle();
  }

  testWidgets('con tutti e due i tipi, l\'elenco si divide e lo spiega', (
    tester,
  ) async {
    await disegna(tester, [
      persona('Rita', suo: true),
      persona('Marco', suo: false),
    ]);

    expect(find.text('I tuoi allievi'), findsOneWidget);
    expect(find.text('Gli iscritti della palestra'), findsOneWidget);

    // 🚨 La riga che scioglie la contraddizione col contatore dei posti.
    expect(
      find.text('Non occupano i posti del tuo piano: li paga la palestra.'),
      findsOneWidget,
    );
  });

  /// ⚠️ Un gruppo solo non ha niente da distinguere: un'intestazione sarebbe
  /// rumore, e due titoli su un elenco omogeneo fanno sembrare che manchi
  /// qualcosa sotto l'altro.
  testWidgets('con soli allievi suoi non compare nessuna intestazione', (
    tester,
  ) async {
    await disegna(tester, [persona('Rita', suo: true)]);

    expect(find.text('I tuoi allievi'), findsNothing);
    expect(find.text('Gli iscritti della palestra'), findsNothing);
    expect(find.text('Rita'), findsOneWidget);
  });

  /// 🚨 **Il caso trovato davvero sul giro**: nessun allievo suo, cinque
  /// iscritti della palestra, e il contatore che dice «15 posti liberi su 15».
  ///
  /// ⛔ Qui l'etichetta **serve**, anche se il gruppo è uno solo: senza,
  /// restano cinque facce sotto un contatore che le ignora.
  testWidgets('senza allievi suoi ma con i posti a schermo, l\'etichetta c\'è', (
    tester,
  ) async {
    await disegna(tester, [persona('Marco', suo: false)]);

    expect(find.text('Gli iscritti della palestra'), findsOneWidget);
    expect(
      find.text('Non occupano i posti del tuo piano: li paga la palestra.'),
      findsOneWidget,
    );
    expect(find.text('I tuoi allievi'), findsNothing);
  });

  /// ⚠️ Un trainer di **sola palestra** non ha posti suoi: il banner non c'è,
  /// non c'è niente da riconciliare, e l'etichetta sarebbe rumore.
  testWidgets('un trainer di sola palestra non vede nessuna etichetta', (
    tester,
  ) async {
    await disegna(
      tester,
      [persona('Marco', suo: false)],
      allieviPropri: false,
    );

    expect(find.text('Gli iscritti della palestra'), findsNothing);
    expect(find.text('Marco'), findsOneWidget);
  });
}
