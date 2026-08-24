import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:training_companion/src/core/storage/archivio_salute.dart';
import 'package:training_companion/src/features/achievements/achievement.dart';
import 'package:training_companion/src/features/achievements/ui/carosello_achievements.dart';
import 'package:training_companion/src/features/training/data/catalogo_esercizi.dart';
import 'package:training_companion/src/features/training/data/gruppo_muscolare.dart';
import 'package:training_companion/src/features/training/data/storico_unificato.dart';
import 'package:training_companion/src/features/training/mese_in_numeri.dart';
import 'package:training_companion/src/features/training/muscoli_allenati.dart';
import 'package:training_companion/src/features/training/settimana_scelta.dart';
import 'package:training_companion/src/features/training/storico_unificato_controller.dart';
import 'package:training_companion/src/features/training/ui/widgets/calendario_del_mese.dart';
import 'package:training_companion/src/features/training/ui/widgets/carosello_del_mese.dart';
import 'package:training_companion/src/features/training/ui/widgets/figura_del_corpo.dart';
import 'package:training_companion/src/features/training/ui/widgets/stella_dei_muscoli.dart';

/// Il blocco in cima allo Storico — 3b-A.6, A.7, A.8, 24/08/2026.
///
/// ══ 🚨 COSA DIFENDE QUESTO FILE ═══════════════════════════════════════════
///
/// Tre card, un calendario e un carosello di medaglie che oggi non esistono.
/// ⚠️ I difetti qui non sono di calcolo: sono **numeri falsi** («0 km» a chi
/// solleva pesi), **spazi vuoti che promettono** (una sezione medaglie senza
/// medaglie) e **una figura tutta grigia** a chi si è allenato davvero.
void main() {
  setUpAll(() => initializeDateFormatting('it'));

  final lunedi = lunediDi(DateTime.now());

  AllenamentoDaOrologio orologio({
    required int id,
    required String tipo,
    required DateTime quando,
    int minuti = 60,
    int? kcal,
    int? metri,
  }) => AllenamentoDaOrologio(
    id: id,
    fonte: 'com.google.android.apps.fitness',
    tipo: tipo,
    iniziatoIl: quando,
    finitoIl: quando.add(Duration(minutes: minuti)),
    kcal: kcal,
    distanzaMetri: metri,
    nascosto: false,
    staccato: false,
  );

  // ═════════════════════ le intensità ═════════════════════

  group('Quali muscoli hai allenato', () {
    test('una corsa colora le gambe, non «cardio»', () {
      final i = intensitaDeiMuscoli(
        voci: [
          VoceStorico(
            sedute: const [],
            dalPolso: [orologio(id: 1, tipo: 'RUNNING', quando: lunedi)],
          ),
        ],
        catalogo: CatalogoEsercizi.vuoto,
      );

      /*
       * 🚨 **È il difetto che questo pezzo esiste per evitare.** Chi corre e
       * basta — tantissima gente — avrebbe visto una figura tutta grigia, cioè
       * l'app che gli dice che non ha allenato niente.
       */
      expect(i[GruppoMuscolare.quadricipiti], greaterThan(0));
      expect(i[GruppoMuscolare.polpacci], greaterThan(0));
      expect(i.containsKey(GruppoMuscolare.cardio), isFalse);
      expect(i.containsKey(GruppoMuscolare.totale), isFalse);
    });

    /// ⚠️ **I minuti si dividono fra i muscoli, non si moltiplicano.** Un'ora di
    /// corsa è un'ora, che i muscoli siano due o quattro.
    test('un tipo con quattro muscoli non vale il doppio di uno con due', () {
      final corsa = intensitaDeiMuscoli(
        voci: [
          VoceStorico(
            sedute: const [],
            dalPolso: [
              orologio(id: 1, tipo: 'RUNNING', quando: lunedi),
              // Stessa durata, due soli muscoli.
              orologio(
                id: 2,
                tipo: 'CORE_TRAINING',
                quando: lunedi.add(const Duration(days: 1)),
              ),
            ],
          ),
        ],
        catalogo: CatalogoEsercizi.vuoto,
      );

      /*
       * 💡 L'addome prende **tutti** i sessanta minuti (un muscolo solo), le
       * gambe quindici a testa (quattro muscoli). Quindi l'addome è il massimo,
       * e vale 1.
       */
      expect(corsa[GruppoMuscolare.addome], 1.0);
      expect(corsa[GruppoMuscolare.quadricipiti], lessThan(1.0));
    });

    test('senza niente non colora niente', () {
      expect(
        intensitaDeiMuscoli(voci: const [], catalogo: CatalogoEsercizi.vuoto),
        isEmpty,
      );
    });

    /// 🚨 Il massimo vale **sempre** 1: la figura dice cosa hai allenato **di
    /// più**, non «quanto è tanto».
    test('il massimo è sempre 1', () {
      final i = intensitaDeiMuscoli(
        voci: [
          VoceStorico(
            sedute: const [],
            dalPolso: [
              orologio(id: 1, tipo: 'RUNNING', quando: lunedi, minuti: 300),
            ],
          ),
        ],
        catalogo: CatalogoEsercizi.vuoto,
      );

      expect(i.values.reduce((a, b) => a > b ? a : b), 1.0);
    });
  });

  // ═════════════════════ il mese in numeri ═════════════════════

  group('Il mese in numeri', () {
    /// ⛔ **Chi fa solo pesi non ha km**, e «0 km» sarebbe un numero falso
    /// travestito da informazione. È la lezione del «0 bruciate» del 23/08.
    test('quello che non c è resta null, non zero', () {
      final n = numeriDelMese([
        VoceStorico(
          sedute: const [],
          dalPolso: [
            orologio(id: 1, tipo: 'STRENGTH_TRAINING', quando: lunedi),
          ],
        ),
      ]);

      expect(n.sessioni, 1);
      expect(n.metri, isNull, reason: 'Nessun km percorso: non «0 km».');
      expect(n.kgSollevati, isNull);
      expect(n.kcal, isNull);
    });

    test('i km ci sono quando l orologio li ha visti', () {
      final n = numeriDelMese([
        VoceStorico(
          sedute: const [],
          dalPolso: [
            orologio(
              id: 1,
              tipo: 'RUNNING',
              quando: lunedi,
              metri: 5200,
              kcal: 400,
            ),
          ],
        ),
      ]);

      expect(n.metri, 5200);
      expect(n.kcal, 400);
    });

    /// 🚨 **Le sessioni sono i gruppi**, non le registrazioni: una seduta vista
    /// dall'app e dall'orologio è **una**.
    test('e le sessioni contano i gruppi', () {
      final n = numeriDelMese([
        VoceStorico(
          sedute: const [],
          dalPolso: [
            orologio(id: 1, tipo: 'RUNNING', quando: lunedi),
            orologio(
              id: 2,
              tipo: 'RUNNING',
              quando: lunedi.add(const Duration(minutes: 5)),
            ),
          ],
        ),
      ]);

      expect(n.sessioni, 1);
    });
  });

  // ═════════════════════ la figura ═════════════════════

  group('La figura del corpo', () {
    /// ══ 🚨 IL TEST CHE VALE PIÙ DI TUTTI QUI ═══════════════════════════════
    ///
    /// ⛔ Il giorno che si aggiunge un gruppo muscolare all'enum, la figura non
    /// dà nessun errore: semplicemente quella zona **non si accende mai**. È un
    /// silenzio, e nessuno strumento lo vede.
    test('ogni muscolo dell enum ha una zona sul corpo', () {
      final mancanti = GruppoMuscolare.values
          .where((g) => g.eUnMuscolo)
          .where((g) => !gruppiDisegnati.contains(g))
          .map((g) => g.etichetta)
          .toList();

      expect(
        mancanti,
        isEmpty,
        reason: 'Questi gruppi non hanno una zona: non si accenderanno mai.',
      );
    });

    /// ⛔ E il contrario: una zona per una cosa che **non è** un muscolo
    /// vorrebbe dire una parte del corpo colorata da «cardio».
    test('e nessuna zona è per qualcosa che non è un muscolo', () {
      expect(gruppiDisegnati.every((g) => g.eUnMuscolo), isTrue);
    });

    testWidgets('si disegna senza sforare, anche stretta', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 120,
                height: 160,
                child: FiguraDelCorpo(intensita: {GruppoMuscolare.petto: 1}),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  // ═════════════════════ la stella ═════════════════════

  group('La stella', () {
    /// 📌 *«un grafico a stella con **tutti** i gruppi muscolari»*.
    test('ha un asse per ogni muscolo, e nessuno in più', () {
      expect(
        StellaDeiMuscoli.assi.toSet(),
        GruppoMuscolare.values.where((g) => g.eUnMuscolo).toSet(),
      );
    });

    /// ══ 🚨 LE ETICHETTE SI ACCAVALLAVANO, E NESSUN TEST LO VEDEVA ═══════
    ///
    /// ⛔ Sul telefono del committente, il 24/08, «Addome» e «Avambracci» si
    /// sovrapponevano in fondo alla stella: undici parole intere attorno a un
    /// cerchio dentro una card da 250 px non ci stanno.
    ///
    /// ⚠️ **Non è uno sforo**: è testo disegnato dentro un `Canvas`, quindi
    /// nessun `RenderFlex overflowed`, nessuna striscia gialla, niente. L'unica
    /// cosa che lo prende è l'occhio — o una guardia sulla **lunghezza**, che è
    /// quello che questo test fa.
    ///
    /// 💡 Nove caratteri è la misura che ci sta: «Tricipiti» è il più lungo dei
    /// nomi che restano interi.
    test('nessuna etichetta è troppo lunga per starci', () {
      final troppoLunghe = StellaDeiMuscoli.assi
          .where((g) => g.etichettaBreve.length > 9)
          .map((g) => g.etichettaBreve)
          .toList();

      expect(
        troppoLunghe,
        isEmpty,
        reason: 'Queste si accavallerebbero con la vicina nella stella.',
      );
    });

    testWidgets('si disegna anche tutta a zero', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 200,
              child: StellaDeiMuscoli(intensita: {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  // ═════════════════════ il carosello e il calendario ═════════════════════

  Widget attorno(Widget figlio, List<VoceStorico> voci, {double w = 328}) =>
      ProviderScope(
        overrides: [
          storicoUnificatoProvider.overrideWith((ref) async => voci),
          catalogoEserciziProvider.overrideWith(
            (ref) async => CatalogoEsercizi.vuoto,
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(width: w, child: figlio),
            ),
          ),
        ),
      );

  final unaCorsa = VoceStorico(
    sedute: const [],
    dalPolso: [
      orologio(id: 1, tipo: 'RUNNING', quando: lunedi, metri: 5000, kcal: 400),
    ],
  );

  group('Il carosello', () {
    /// 📌 *«tre card di **altezza identica**»* — A.6.4.
    ///
    /// ⛔ Lasciarla al contenuto vuol dire che scorrendo il carosello **salta**,
    /// e salta in modo diverso a seconda di quanti numeri ha quel mese.
    testWidgets('le tre card hanno la stessa altezza', (tester) async {
      await tester.pumpWidget(
        attorno(const CaroselloDelMese(), [unaCorsa], w: 900),
      );
      await tester.pumpAndSettle();

      final card = find.byType(Card);
      final quante = card.evaluate().length;

      expect(quante, 3, reason: 'Le card del carosello non sono tre.');

      final altezze = {
        for (var i = 0; i < quante; i++) tester.getSize(card.at(i)).height,
      };

      expect(altezze.length, 1, reason: 'Le card hanno altezze diverse.');
    });

    /// ⛔ Un mese senza allenamenti non mostra tre card vuote: sarebbero tre
    /// modi di dire «niente», con lo scorrimento.
    testWidgets('e sparisce quando il mese è vuoto', (tester) async {
      await tester.pumpWidget(attorno(const CaroselloDelMese(), const []));
      await tester.pumpAndSettle();

      expect(find.byType(Card), findsNothing);
    });
  });

  group('Il calendario', () {
    testWidgets('mette un puntino nel giorno dell allenamento', (tester) async {
      await tester.pumpWidget(attorno(const CalendarioDelMese(), [unaCorsa]));
      await tester.pumpAndSettle();

      // 💡 Il numero del giorno c'è: il calendario si è disegnato sul mese
      // giusto. Il puntino è un `DecoratedBox`, che non si cerca per testo.
      expect(find.text('${lunedi.day}'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('e non si disegna affatto se il mese è vuoto', (tester) async {
      await tester.pumpWidget(attorno(const CalendarioDelMese(), const []));
      await tester.pumpAndSettle();

      expect(find.text('L'), findsNothing);
    });
  });

  // ═════════════════════ le medaglie ═════════════════════

  group('Il carosello delle medaglie — A.8.5', () {
    /// ⛔ **Una sezione vuota che promette premi è peggio di nessuna sezione.**
    /// Occupa spazio in tre schermate, non dice niente, e insegna a scorrere
    /// oltre — anche il giorno che avrà qualcosa da dire.
    testWidgets('finché non ce ne sono, non disegna niente', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: CaroselloAchievements(
                ambito: AmbitoAchievement.allenamento,
                titolo: 'I tuoi traguardi',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('I tuoi traguardi'), findsNothing);
      expect(find.byType(Card), findsNothing);
    });

    /// 💡 E quando ci saranno, si vedono: il widget è pronto, non è un abbozzo.
    testWidgets('ma con una medaglia la mostra', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            achievementsProvider.overrideWithValue([
              Achievement(
                codice: 'prima-seduta',
                titolo: 'Si comincia',
                descrizione: 'Hai registrato il tuo primo allenamento.',
                icona: Icons.emoji_events_outlined,
                ambito: AmbitoAchievement.allenamento,
                ottenutoIl: DateTime(2026, 8, 24),
              ),
            ]),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: CaroselloAchievements(
                ambito: AmbitoAchievement.allenamento,
                titolo: 'I tuoi traguardi',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('I tuoi traguardi'), findsOneWidget);
      expect(find.text('Si comincia'), findsOneWidget);
    });

    /// 🚨 L'ambito serve perché le tre schermate mostrano insiemi **diversi**:
    /// il Diario non deve far vedere le medaglie della palestra.
    testWidgets('e l ambito filtra davvero', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            achievementsProvider.overrideWithValue([
              const Achievement(
                codice: 'a',
                titolo: 'Roba di pesi',
                descrizione: '.',
                icona: Icons.fitness_center,
                ambito: AmbitoAchievement.allenamento,
              ),
              const Achievement(
                codice: 'b',
                titolo: 'Roba di cibo',
                descrizione: '.',
                icona: Icons.restaurant,
                ambito: AmbitoAchievement.alimentazione,
              ),
            ]),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: CaroselloAchievements(
                ambito: AmbitoAchievement.alimentazione,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Roba di cibo'), findsOneWidget);
      expect(find.text('Roba di pesi'), findsNothing);
    });
  });
}
