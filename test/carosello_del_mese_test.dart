import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:training_companion/src/core/storage/archivio_salute.dart';
import 'package:training_companion/src/core/theme/app_theme.dart';
import 'package:training_companion/src/features/achievements/achievement.dart';
import 'package:training_companion/src/features/achievements/ui/carosello_achievements.dart';
import 'package:training_companion/src/features/profile/data/profile_models.dart';
import 'package:training_companion/src/features/profile/profile_controller.dart';
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
/// Un profilo qualunque: alla figura serve **solo** il sesso.
const _profiloFinto = UserProfile(
  mealHours: <String, String>{},
  missing: <String>[],
  activityLevels: <String, String>{},
  goals: <String, String>{},
  sex: 'male',
);

/// La sagoma finta, costruita una volta sola.
ui.Image? _sagoma;

void main() {
  setUpAll(() async {
    initializeDateFormatting('it');
    _sagoma = await sagomaFinta();
  });

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

    /// ══ 🚨 IL TEST CHE IMPEDISCE AL DIFETTO DI TORNARE UNA TERZA VOLTA ═════
    ///
    /// ⛔ Due volte in un giorno, lo stesso errore: prima *«non mi ha segnato i
    /// bicipiti»* (l'elenco ne aveva cinque), poi i **polpacci** (l'elenco
    /// corretto ne aveva nove, e mancavano polpacci e avambracci).
    ///
    /// 🚨 **Il difetto non era la riga mancante: era che fosse un elenco.** Una
    /// lista scritta a mano che deve contenere *tutto* si sbaglia la prima
    /// volta, si sbaglia correggendola, e si sbaglierà al prossimo gruppo che
    /// entra nell'enum — **senza dare nessun errore**: quella zona semplicemente
    /// non si accende mai.
    test('«pesi» colora tutto il corpo, e tutto vuol dire tutto', () {
      final tutti = GruppoMuscolare.values.where((g) => g.eUnMuscolo).toSet();

      expect(
        MuscoliDelTipo.tuttoIlCorpo.toSet(),
        tutti,
        reason: 'Un allenamento di pesi lascia fuori una zona del corpo.',
      );

      /// ⚠️ E il contrario: `cardio` e `full_body` non sono zone, e colorarle
      /// vorrebbe dire una parte del corpo accesa da una cosa che non è un
      /// muscolo.
      expect(MuscoliDelTipo.tuttoIlCorpo.every((g) => g.eUnMuscolo), isTrue);
    });

    /// 💡 E la prova dal lato di chi guarda: un allenamento di pesi visto
    /// dall'orologio deve accendere **anche** i polpacci, che sono la zona su
    /// cui il difetto si è visto.
    test('un allenamento di pesi dall orologio accende anche i polpacci', () {
      final i = intensitaDeiMuscoli(
        voci: [
          VoceStorico(
            sedute: const [],
            dalPolso: [
              orologio(id: 1, tipo: 'STRENGTH_TRAINING', quando: lunedi),
            ],
          ),
        ],
        catalogo: CatalogoEsercizi.vuoto,
      );

      expect(i[GruppoMuscolare.polpacci], greaterThan(0));
      expect(i[GruppoMuscolare.avambracci], greaterThan(0));
      expect(i[GruppoMuscolare.bicipiti], greaterThan(0));
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

    /// ⚠️ **La sagoma è finta.** Un test di widget non legge gli asset veri —
    /// `rootBundle` non ha i PNG — e un quadrato opaco dimostra la stessa cosa:
    /// che il pittore disegna, che non sfora e che a zero tace.
    testWidgets('si disegna senza sforare, anche stretta', (tester) async {
      /*
       * ⚠️ **La sagoma si costruisce in `setUpAll`, non qui.**
       *
       * ⛔ Dentro `testWidgets` il tempo è finto, e decodificare un'immagine è
       * una cosa vera: `await sagomaFinta()` non si completa **mai**, e il test
       * resta appeso finché non scade dopo dieci minuti — senza dire perché.
       *
       * 💡 In `setUpAll` invece si sta fuori dall'orologio finto.
       */
      final sagoma = _sagoma!;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sagomaDelCorpoProvider.overrideWith((ref, nome) async => sagoma),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 120,
                  height: 160,
                  child: FiguraDelCorpo(
                    intensita: {GruppoMuscolare.petto: 1},
                    corpo: CorpoDa.uomo,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    /// 📌 *«Ovviamente un uomo deve vedere quella da uomo e una donna quella da
    /// donna»*.
    ///
    /// ⚠️ E chi il sesso non l'ha dichiarato vede quella maschile: una delle
    /// due va scelta comunque, e non c'è una terza immagine da mostrare.
    test('il sesso sceglie la figura, e senza sesso è quella da uomo', () {
      expect(CorpoDa.dalSesso('female'), CorpoDa.donna);
      expect(CorpoDa.dalSesso('FEMALE'), CorpoDa.donna);
      expect(CorpoDa.dalSesso('male'), CorpoDa.uomo);
      expect(CorpoDa.dalSesso(null), CorpoDa.uomo);
      expect(CorpoDa.dalSesso(''), CorpoDa.uomo);
      expect(CorpoDa.dalSesso('boh'), CorpoDa.uomo);
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

          /*
           * 🚨 **Il profilo va sovrascritto o il test resta appeso.**
           *
           * ⛔ Da 3b-B.1 la figura chiede il sesso al profilo, e quello fa una
           * chiamata di rete. In un test la chiamata non risponde mai e lascia
           * un **timer pendente**: `pumpAndSettle` aspetta anche quelli, e va
           * in timeout dopo dieci minuti senza dire perché.
           *
           * ⚠️ Non è un difetto dell'app: è che un widget che parla con la rete
           * va isolato, e questo prima non lo faceva.
           */
          profileProvider.overrideWith((ref) async => _profiloFinto),
          sagomaDelCorpoProvider.overrideWith((ref, nome) async => _sagoma!),
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
    ///
    /// ⚠️ **Da B.7 le card non sono più tutte in scena insieme**: un `PageView`
    /// costruisce quella che si vede. Quindi si misura scorrendo, una per una —
    /// che è anche il modo in cui il difetto si vedrebbe davvero.
    testWidgets('le tre card hanno la stessa altezza', (tester) async {
      await tester.pumpWidget(
        attorno(const CaroselloDelMese(), [unaCorsa], w: 360),
      );
      await tester.pumpAndSettle();

      final altezze = <double>{};

      for (var i = 0; i < 3; i++) {
        altezze.add(tester.getSize(find.byType(Card).first).height);

        if (i < 2) {
          await tester.fling(
            find.byType(PageView),
            const Offset(-400, 0),
            1000,
          );
          await tester.pumpAndSettle();
        }
      }

      expect(altezze.length, 1, reason: 'Le card hanno altezze diverse.');
    });

    /// 📌 *«dovrebbero essere larghe tutta la pagina»* — B.7.
    ///
    /// ⚠️ **Due misure e non una**, perché sono due cose diverse: la *pagina*
    /// occupa tutta la larghezza (è quello che fa scorrere una card alla volta),
    /// e la *superficie* della card sta dentro con lo stesso margine laterale
    /// del resto della schermata. ⛔ Una card larga «quasi tutto» con un margine
    /// suo sarebbe disallineata da tutto il contenuto sotto, e si vedrebbe.
    ///
    /// 💡 `getSize` su una `Card` **comprende il margine**: la superficie vera è
    /// il `Material` che ci sta dentro. Misurare la `Card` e aspettarsi 328
    /// dava 360 — il test sbagliato, non il widget.
    testWidgets('la card è larga quanto la pagina, meno i margini', (
      tester,
    ) async {
      await tester.pumpWidget(
        attorno(const CaroselloDelMese(), [unaCorsa], w: 360),
      );
      await tester.pumpAndSettle();

      final card = find.byType(Card).first;

      expect(tester.getSize(card).width, 360);
      expect(
        tester
            .getSize(
              find.descendant(of: card, matching: find.byType(Material)).first,
            )
            .width,
        360 - Gap.md * 2,
      );
    });

    /// 📌 *«e scorrere una per una»* — B.7.
    ///
    /// ══ 🚨 È LA RAGIONE PER CUI NON È PIÙ UNA `ListView` ═══════════════════
    ///
    /// ⛔ Una lista orizzontale si ferma **dove la lasci**. Con card strette non
    /// si notava; a tutta pagina vuol dire restare quasi sempre a cavallo di
    /// due, con mezza figura di qua e mezza stella di là.
    ///
    /// 💡 Si provano **tutti e due** gli esiti, perché la garanzia è che finisca
    /// sempre su un numero intero: un trascinamento corto **deve** tornare
    /// indietro (e va bene così), uno lungo deve arrivare alla seconda. Quello
    /// che non deve mai succedere è restare in mezzo.
    testWidgets('e si ferma sempre su una card, mai a metà', (tester) async {
      await tester.pumpWidget(
        attorno(const CaroselloDelMese(), [unaCorsa], w: 360),
      );
      await tester.pumpAndSettle();

      double? dove() =>
          tester.widget<PageView>(find.byType(PageView)).controller?.page;

      // Un terzo di schermo: non basta, e torna dov'era.
      await tester.drag(find.byType(PageView), const Offset(-120, 0));
      await tester.pumpAndSettle();

      expect(dove(), 0.0, reason: 'È rimasto fra due card.');

      // Oltre metà: passa alla seconda, e ci si ferma esatto.
      await tester.drag(find.byType(PageView), const Offset(-260, 0));
      await tester.pumpAndSettle();

      expect(dove(), 1.0, reason: 'Non è arrivato in fondo alla seconda.');
    });

    /// 🚨 **I puntini non sono un vezzo.** Prima si vedeva spuntare la card
    /// accanto, e quello diceva da solo che ce n'era un'altra. ⛔ A tutta pagina
    /// quel segnale sparisce: senza, due card su tre restano invisibili a chi
    /// non prova a trascinare.
    testWidgets('e dice quante ce ne sono', (tester) async {
      await tester.pumpWidget(
        attorno(const CaroselloDelMese(), [unaCorsa], w: 360),
      );
      await tester.pumpAndSettle();

      for (var i = 0; i < 3; i++) {
        expect(find.byKey(chiavePuntino(i)), findsOneWidget);
      }

      expect(find.byKey(chiavePuntino(3)), findsNothing);
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
