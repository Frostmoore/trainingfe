import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:training_companion/src/core/providers.dart';
import 'package:training_companion/src/core/storage/archivio_salute.dart';
import 'package:training_companion/src/core/storage/local_cache.dart';
import 'package:training_companion/src/features/dashboard/ui/widgets/passi_del_giorno.dart';
import 'package:training_companion/src/features/health/dati_salute.dart';
import 'package:training_companion/src/features/health/health_controller.dart';
import 'package:training_companion/src/features/health/obiettivo_passi.dart';

/// La barra dei passi — 07–08/09/2026.
///
/// ══ 🚨 PERCHE' QUESTO TEST ESISTE ════════════════════════════════════════
///
/// Nella notte fra il 6 e il 7 il committente ha detto tre volte *«non li
/// vedo»*, e io ho verificato a mano ogni anello — i dati nell'archivio, il
/// provider, la posizione nella `Column`, il file giusto della card, il tipo di
/// `DateTime` della chiave. **Tornavano tutti.**
///
/// ⛔ Ci è voluta un'ora, una traccia temporanea dentro il widget e una build
/// apposta per scoprire che funzionava: semplicemente il widget non veniva
/// costruito, perché quella card stava in una scheda che non era aperta.
///
/// 💡 **Un test lo dice in mezzo secondo, e lo dirà anche fra sei mesi.** È la
/// differenza fra guardare e misurare, ed è la lezione che è costata di più.
void main() {
  late LocalCache cache;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    cache = LocalCache(await SharedPreferences.getInstance());
  });

  /// Un archivio in memoria, con dentro i passi che si vogliono.
  ///
  /// ⚠️ Si scrive con `riscriviIPassi` e non con una `insert` a mano: così il
  /// test passa dalla **stessa strada** del ponte, e se un giorno quella
  /// cambiasse forma il test se ne accorgerebbe invece di continuare a
  /// preparare un mondo che non esiste più.
  Future<Widget> con({
    required int passi,
    required DateTime giorno,
    int? obiettivo,
  }) async {
    final archivio = ArchivioSalute.inMemoria();

    addTearDown(archivio.close);

    if (passi > 0) {
      await archivio.riscriviIPassi(giorno: giorno, passi: passi);
    }

    if (obiettivo != null) {
      await cache.setInt(ObiettivoPassi.chiave, value: obiettivo);
    }

    return ProviderScope(
      overrides: [
        archivioSaluteProvider.overrideWithValue(archivio),
        localCacheProvider.overrideWithValue(cache),
      ],
      child: MaterialApp(
        home: Scaffold(body: PassiDelGiorno(giorno: giorno)),
      ),
    );
  }

  final oggi = DateTime(2026, 9, 7);

  testWidgets('🚶 con i passi nell\'archivio, la barra si vede', (
    tester,
  ) async {
    await tester.pumpWidget(await con(passi: 8192, giorno: oggi));
    await tester.pumpAndSettle();

    // 💡 Con i punti delle migliaia: a colpo d'occhio si contano da sole.
    expect(find.text('8.192'), findsOneWidget);

    // ⚠️ L'obiettivo di ripiego, quello di chi non l'ha ancora toccato.
    expect(find.text(' / 10.000'), findsOneWidget);
  });

  testWidgets('📊 e ha dieci tacche, qualunque sia l\'obiettivo', (
    tester,
  ) async {
    /*
     * 🚨 **Dieci sempre.** Una tacca ogni mille passi ne darebbe tre a chi ne
     * punta 3.000 e venti a chi ne punta 20.000: la stessa barra vorrebbe dire
     * due cose diverse, e chi cambia obiettivo vedrebbe cambiare il
     * *significato* del disegno invece che il traguardo.
     */
    await tester.pumpWidget(
      await con(passi: 8192, giorno: oggi, obiettivo: 20000),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FractionallySizedBox), findsNWidgets(10));
    expect(find.text(' / 20.000'), findsOneWidget);
  });

  testWidgets('⛔ senza passi non si vede niente, e non si scrive «0»', (
    tester,
  ) async {
    await tester.pumpWidget(await con(passi: 0, giorno: oggi));
    await tester.pumpAndSettle();

    /*
     * 🚨 **Zero vuol dire «non lo sappiamo», non «non hai camminato».** Prima
     * che il permesso venga concesso qui arriva zero, e disegnare una barra
     * vuota accanto a un obiettivo è un **rimprovero**: direbbe una cosa falsa a
     * chi ha camminato tutto il giorno, e gliela direbbe con l'aria di una
     * misura.
     */
    expect(find.textContaining('Passi'), findsNothing);
    expect(find.textContaining('10.000'), findsNothing);
  });

  testWidgets('⚠️ i passi di un altro giorno non finiscono in questo', (
    tester,
  ) async {
    final archivio = ArchivioSalute.inMemoria();

    addTearDown(archivio.close);

    await archivio.riscriviIPassi(
      giorno: oggi.subtract(const Duration(days: 1)),
      passi: 24506,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          archivioSaluteProvider.overrideWithValue(archivio),
          localCacheProvider.overrideWithValue(cache),
        ],
        child: MaterialApp(
          home: Scaffold(body: PassiDelGiorno(giorno: oggi)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    /*
     * ⚠️ Il 04 e il 05 settembre avevano 24.506 e 22.470 passi, contro gli 8.192
     * del 06. 🚨 Se il filtro sul giorno saltasse, la card mostrerebbe il
     * massimo di sempre e sembrerebbe giusta — è il tipo di numero che nessuno
     * va a controllare.
     */
    expect(find.textContaining('24.506'), findsNothing);
  });

  testWidgets('💡 e regge una colonna stretta', (tester) async {
    // 320 px: la larghezza dove il layout della dashboard è già esploso una
    // volta. Si prova dove rompe, non dove sta comodo.
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(await con(passi: 124536, giorno: oggi));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('🎚️ e si tocca per cambiare l\'obiettivo', (tester) async {
    /*
     * ⚠️ **Una cosa che fa qualcosa deve dirlo.** In questa app la card del
     * nome era grande e inerte, e la lezione scritta in `SchermataTu` è che chi
     * tocca e non ottiene niente impara a non toccare più. 🚨 Vale al rovescio:
     * se la barra si tocca, deve aprirsi qualcosa.
     */
    await tester.pumpWidget(await con(passi: 8192, giorno: oggi));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();

    expect(find.text('Obiettivo di passi'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
  });

  group('🏁 il traguardo', () {
    test('⛔ a obiettivo raggiunto non si scrive «ne mancano 0»', () {
      /*
       * 🚨 Uno zero annuncia un fallimento anche quando descrive un successo. A
       * traguardo preso la frase cambia **di tono**, non di numero.
       */
      expect(
        PassiDelGiorno.sottotitolo(passi: 10000, obiettivo: 10000),
        'Obiettivo raggiunto',
      );
    });

    test('✅ e superandolo si dice di quanto', () {
      expect(
        PassiDelGiorno.sottotitolo(passi: 12500, obiettivo: 10000),
        'Obiettivo superato di 2.500',
      );
    });

    test('💡 sotto, si dice quanto manca e quanto vale una tacca', () {
      expect(
        PassiDelGiorno.sottotitolo(passi: 8192, obiettivo: 10000),
        'Ne mancano 1.808 · una tacca = 1.000',
      );
    });
  });

  group('🎯 l\'obiettivo', () {
    ProviderContainer conLaCache() {
      final c = ProviderContainer(
        overrides: [localCacheProvider.overrideWithValue(cache)],
      );

      addTearDown(c.dispose);

      return c;
    }

    test('⚠️ chi non l\'ha mai toccato ne ha uno che sa leggere', () {
      expect(conLaCache().read(obiettivoPassiProvider), 10000);
    });

    test('⛔ e non esce mai dagli estremi chiesti', () async {
      /*
       * 📌 *«diciamo tra i 3000 e i 20000»*. 🚨 Il taglio vale anche in
       * **lettura**: un valore fuori scala può arrivare da un backup vecchio o
       * da una versione futura che allarga l'intervallo, e la barra si
       * disegnerebbe su un fondo che non esiste.
       */
      expect(ObiettivoPassi.entroIlimiti(500), 3000);
      expect(ObiettivoPassi.entroIlimiti(999999), 20000);

      await cache.setInt(ObiettivoPassi.chiave, value: 999999);

      expect(conLaCache().read(obiettivoPassiProvider), 20000);
    });

    test('💾 e sopravvive al riavvio, perché sta in `LocalCache`', () async {
      await conLaCache().read(obiettivoPassiProvider.notifier).scegli(15000);

      expect(cache.getInt(ObiettivoPassi.chiave), 15000);
    });
  });

  test(
    '⚠️ e il numero è quello che il ponte ha scritto, non una somma',
    () async {
      /*
     * 🚨 **Una riga al giorno, dall'aggregato.** Riscrivere lo stesso giorno
     * sostituisce, non impila: senza, il totale di oggi crescerebbe a ogni
     * sincronizzazione e chi guarda la sera vedrebbe il doppio.
     */
      final archivio = ArchivioSalute.inMemoria();

      addTearDown(archivio.close);

      await archivio.riscriviIPassi(giorno: oggi, passi: 4000);
      await archivio.riscriviIPassi(giorno: oggi, passi: 8192);

      expect(await archivio.passiDi(oggi), 8192);
    },
  );

  test('🚨 i passi della seduta escono dal conto delle calorie', () async {
    /*
     * 📌 Il committente: *«basta sottrarre quelli dell'esercizio da quelli della
     * giornata solo per quanto riguarda il conteggio calorico e lasciarli
     * inclusi per quanto riguarda il numero totale»*.
     */
    final archivio = ArchivioSalute.inMemoria();

    addTearDown(archivio.close);

    await archivio.riscriviIPassi(giorno: oggi, passi: 10000);

    // 💡 Senza sedute i due numeri coincidono: è il caso normale.
    expect(await archivio.passiDi(oggi), 10000);
    expect(await archivio.passiFuoriDagliAllenamenti(oggi), 10000);
  });

  test('⛔ e non diventano mai negativi', () async {
    final archivio = ArchivioSalute.inMemoria();

    addTearDown(archivio.close);

    // Nessun passo scritto, ma potrebbero esserci sedute: la sottrazione non
    // deve sfondare lo zero.
    expect(await archivio.passiFuoriDagliAllenamenti(oggi), 0);
  });

  /*
   * ══ 🚨 IL GIORNO CONGELATO — 08/09/2026 ══════════════════════════════════
   *
   * ⛔ **Il test qui sopra passava, e l'app era rotta lo stesso.** Provava che
   * `riscriviIPassi` sostituisce — ed è vero — ma il ponte quella non la
   * chiamava: metteva i passi fra le `letture`, cioè in una INSERT.
   *
   * 🚨 **Misurato sul telefono l'08/09**: 1.195 passi nell'archivio per il
   * 07/09, 4.500 nell'aggregato di Health Connect. Il giorno era stato letto
   * alle 00:38, quando 1.195 era il numero giusto, e non si è più mosso.
   *
   * ⚠️ Un test che sorveglia la porta accanto è peggio di nessun test: dà la
   * sensazione della copertura. Questi due sorvegliano quella vera.
   */
  group('🧊 un giorno già scritto', () {
    LetturaSalute passi(DateTime giorno, int quanti) => LetturaSalute(
      id: 0,
      fonte: 'aggregato',
      metrica: MetricaSalute.passi.codice,
      misurataIl: giorno,
      giorno: giorno,
      valore: quanti.toDouble(),
    );

    test('⛔ con `scriviLetture` NON si aggiorna — ed è la trappola', () async {
      final archivio = ArchivioSalute.inMemoria();

      addTearDown(archivio.close);

      await archivio.scriviLetture([passi(oggi, 1195)]);

      /*
       * 🚨 **E torna 1, cioè «scritta una».** L'indice unico la scarta in
       * silenzio — `insertOrIgnore` fa esattamente il suo mestiere — ma chi
       * legge il valore di ritorno crede di aver aggiornato il giorno.
       */
      expect(await archivio.scriviLetture([passi(oggi, 4500)]), 1);
      expect(
        await archivio.passiDi(oggi),
        1195,
        reason: 'la INSERT su un giorno presente non fa niente',
      );
    });

    test(
      '✅ con `riscriviIPassi` sì, ed è la strada che usa il ponte',
      () async {
        final archivio = ArchivioSalute.inMemoria();

        addTearDown(archivio.close);

        await archivio.scriviLetture([passi(oggi, 1195)]);
        await archivio.riscriviIPassi(giorno: oggi, passi: 4500);

        expect(await archivio.passiDi(oggi), 4500);
      },
    );
  });
}
