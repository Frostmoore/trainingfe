import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/training/data/catalogo_esercizi.dart';
import 'package:training_companion/src/features/training/data/gruppo_muscolare.dart';
import 'package:training_companion/src/features/training/data/scheda_allenamento.dart';
import 'package:training_companion/src/features/training/ui/widgets/scelta_muscoli.dart';

import 'aiuto/intestazione.dart';

/// I muscoli di un esercizio, lato app — 3b-A.3.4, 23/08/2026.
///
/// 📌 *«Tutti gli esercizi devono indicare il muscolo o il gruppo muscolare che
/// allenano (anche più di uno). Ovviamente questo va fatto anche dove vengono
/// creati gli esercizi, quindi anche sul server e sul builder delle schede»*.
///
/// 🚨 Il difetto che questi test esistono per prendere non è un errore di
/// calcolo: è **una domanda posta al momento sbagliato**, o una risposta che
/// dice una cosa diversa da quella che è stata data.
void main() {
  EsercizioDelCatalogo esercizio(
    int id,
    String nome,
    GruppoMuscolare? primario,
    List<GruppoMuscolare> secondari,
  ) => EsercizioDelCatalogo(
    id: id,
    nome: nome,
    primario: primario,
    secondari: secondari,
  );

  final catalogo = CatalogoEsercizi([
    esercizio(1, 'Panca piana', GruppoMuscolare.petto, [
      GruppoMuscolare.tricipiti,
      GruppoMuscolare.spalle,
    ]),
    esercizio(2, 'Corsa', GruppoMuscolare.cardio, [
      GruppoMuscolare.quadricipiti,
      GruppoMuscolare.polpacci,
    ]),
    esercizio(3, 'Leg extension', GruppoMuscolare.quadricipiti, const []),
  ]);

  // ───────────────────────── il catalogo ─────────────────────────

  group('il catalogo', () {
    test('riconosce un nome scritto con maiuscole e spazi diversi', () {
      expect(catalogo.perNome('  panca   PIANA ')?.id, 1);
    });

    test('e non riconosce quello che non è suo', () {
      expect(catalogo.perNome('Spinte strane al cavo'), isNull);
    });

    test('cardio non colora nessuna zona, ma le gambe sì', () {
      /*
       * 🚨 **`cardio` non è un muscolo**, e questo è il test che impedisce di
       * colorare una figura del corpo con una parola che non è una zona.
       *
       * 💡 Ma una corsa **le gambe le colora lo stesso**, perché le ha fra i
       * secondari: senza, chi corre e basta avrebbe una figura tutta grigia,
       * che sarebbe falsa.
       */
      final pesi = catalogo.perId(2)!.muscoliConPeso;

      expect(pesi.containsKey(GruppoMuscolare.cardio), isFalse);
      expect(pesi[GruppoMuscolare.quadricipiti], 0.5);
      expect(pesi[GruppoMuscolare.polpacci], 0.5);
    });

    test('il primario pesa il doppio di un secondario', () {
      expect(catalogo.perId(1)!.muscoliConPeso, {
        GruppoMuscolare.petto: 1.0,
        GruppoMuscolare.tricipiti: 0.5,
        GruppoMuscolare.spalle: 0.5,
      });
    });

    test('un esercizio che isola pesa solo il suo muscolo', () {
      expect(catalogo.perId(3)!.muscoliConPeso, {
        GruppoMuscolare.quadricipiti: 1.0,
      });
    });
  });

  // ───────────────────────── i tre stati ─────────────────────────

  group('quello che si manda al server', () {
    test('senza risposta non si manda niente', () {
      /*
       * ⛔ **Questo è il test più importante del file.**
       *
       * 🚨 Mandare `secondary_muscles: []` quando nessuno ha risposto vorrebbe
       * dire scrivere nella libreria che l'esercizio **isola** — cioè una
       * dichiarazione che nessuno ha fatto. La guardia del server che cerca i
       * buchi non ne troverebbe più, e il catalogo marcirebbe in silenzio,
       * sembrando pieno.
       */
      final e = EsercizioDellaScheda(nome: 'Spinte strane');

      expect(e.toJson().containsKey('secondary_muscles'), isFalse);
      expect(e.toJson().containsKey('muscle_group'), isFalse);
    });

    test('un elenco vuoto è una risposta, e si manda', () {
      final e = EsercizioDellaScheda(nome: 'Isolamento strano')
        ..muscoli = (
          primario: GruppoMuscolare.quadricipiti,
          secondari: const [],
        );

      expect(e.toJson()['muscle_group'], 'quads');
      expect(e.toJson()['secondary_muscles'], isEmpty);
    });

    test('i muscoli scelti viaggiano con i valori del server', () {
      final e = EsercizioDellaScheda(nome: 'Spinta strana')
        ..muscoli = (
          primario: GruppoMuscolare.petto,
          secondari: const [GruppoMuscolare.tricipiti, GruppoMuscolare.spalle],
        );

      expect(e.toJson()['muscle_group'], 'chest');
      expect(e.toJson()['secondary_muscles'], ['triceps', 'shoulders']);
    });

    test('e si rileggono da una scheda che arriva dal server', () {
      // ⚠️ In lettura il dato sta dentro `exercise`, in scrittura sulla riga:
      // il ripiego serve, e questo test lo tiene vivo.
      final e = EsercizioDellaScheda.fromJson({
        'name': 'Panca piana',
        'exercise': {
          'name': 'Panca piana',
          'muscle_group': 'chest',
          'secondary_muscles': ['triceps'],
        },
      });

      expect(e.muscoli?.primario, GruppoMuscolare.petto);
      expect(e.muscoli?.secondari, [GruppoMuscolare.tricipiti]);
    });

    test('una riga senza muscoli resta «non lo so», non «nessuno»', () {
      final e = EsercizioDellaScheda.fromJson({'name': 'Panca piana'});

      expect(e.muscoli, isNull);
    });
  });

  // ─────────────── la regola in un posto solo ───────────────

  group('muscoliInJson', () {
    /*
     * 🚨 **È la stessa regola per tutti e tre i mittenti**: il modello della
     * scheda, l'editor della scheda propria e il player.
     *
     * ⛔ Stava scritta in tre posti, e tre copie della stessa regola diventano
     * tre regole diverse alla prima modifica: basta che una mandi sempre `[]`
     * e la libreria si riempie di esercizi che *dichiarano* di isolare.
     */
    test('senza risposta non mette niente nel JSON', () {
      expect(muscoliInJson(null), isEmpty);
    });

    test('un elenco vuoto ci finisce, perché è una risposta', () {
      final j = muscoliInJson((
        primario: GruppoMuscolare.quadricipiti,
        secondari: const [],
      ));

      expect(j['muscle_group'], 'quads');
      expect(j['secondary_muscles'], isEmpty);
      expect(j.containsKey('secondary_muscles'), isTrue);
    });

    test('e i muscoli scelti viaggiano con i valori del server', () {
      final j = muscoliInJson((
        primario: GruppoMuscolare.petto,
        secondari: const [GruppoMuscolare.tricipiti],
      ));

      expect(j, {
        'muscle_group': 'chest',
        'secondary_muscles': ['triceps'],
      });
    });

    test('e il player manda esattamente quello', () {
      /*
       * ⚠️ **Il corpo di `POST /exercises` dal player è lo stesso oggetto.**
       * Da 3b-A.3.5 il server rifiuta di creare un esercizio senza muscoli:
       * se questo corpo perdesse i campi, la prima serie di un movimento
       * inventato prenderebbe un 422 **a metà allenamento**.
       */
      final corpo = <String, dynamic>{
        'name': 'Spinte strane',
        ...muscoliInJson((
          primario: GruppoMuscolare.petto,
          secondari: const [GruppoMuscolare.tricipiti],
        )),
      };

      expect(corpo, {
        'name': 'Spinte strane',
        'muscle_group': 'chest',
        'secondary_muscles': ['triceps'],
      });
    });
  });

  // ───────────────────────── la domanda ─────────────────────────

  group('la riga nel compositore', () {
    late List<Override> base;

    setUp(() async => base = await intestazioneFinta());

    Widget conCatalogo(Widget figlio) => ProviderScope(
      overrides: [
        ...base,
        catalogoEserciziProvider.overrideWith((ref) async => catalogo),
      ],
      child: MaterialApp(home: Scaffold(body: figlio)),
    );

    testWidgets('per un esercizio del catalogo non chiede niente', (
      tester,
    ) async {
      /*
       * 🚨 **La domanda che non serve è peggio di nessuna domanda.**
       *
       * ⛔ Per i 121 esercizi in libreria il server i muscoli li sa già, e non
       * li sovrascrive con quello che scrive un iscritto. Chiederli qui
       * vorrebbe dire far compilare un campo la cui risposta viene buttata via
       * — e chi impara che una domanda non conta smette di leggerla anche
       * quando conta.
       */
      await tester.pumpWidget(
        conCatalogo(
          RigaMuscoli(nome: 'Panca piana', muscoli: null, onScelti: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Che muscoli allena?'), findsNothing);
      expect(find.textContaining('Petto'), findsOneWidget);
    });

    testWidgets('per un esercizio nuovo la domanda c\'è', (tester) async {
      await tester.pumpWidget(
        conCatalogo(
          RigaMuscoli(
            nome: 'Spinte strane al cavo',
            muscoli: null,
            onScelti: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Che muscoli allena?'), findsOneWidget);
    });

    testWidgets('e sparisce quando il campo è vuoto', (tester) async {
      await tester.pumpWidget(
        conCatalogo(RigaMuscoli(nome: '   ', muscoli: null, onScelti: (_) {})),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets('finché il catalogo non è arrivato, chiede', (tester) async {
      /*
       * ⚠️ **Il contrario sarebbe il guasto invisibile**: se la riga tacesse
       * finché il catalogo non c'è, con la rete lenta la domanda non
       * comparirebbe mai — e nessuno collegherebbe le due cose.
       */
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...base,
            catalogoEserciziProvider.overrideWith(
              (ref) async => CatalogoEsercizi.vuoto,
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: RigaMuscoli(
                nome: 'Panca piana',
                muscoli: null,
                onScelti: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Che muscoli allena?'), findsOneWidget);
    });
  });
}
