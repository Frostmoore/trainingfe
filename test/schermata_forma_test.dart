import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/forma/forma_controller.dart';
import 'package:training_companion/src/features/forma/carica_batteria.dart';
import 'package:training_companion/src/features/forma/indici_di_forma.dart';
import 'package:training_companion/src/features/forma/ui/schermata_forma.dart';

import 'aiuto/intestazione.dart';

/// Il dettaglio di carico e carica — 20/08/2026.
///
/// ── 🚨 Cosa difende questo file ────────────────────────────────────────────
///
/// 📌 Il committente: *«quando clicco sulla card carico e carica, mi deve aprire
/// una pagina in cui mi mostri i dettagli di entrambi i calcoli, con due card in
/// fondo con la formula e come funziona il calcolo»*.
///
/// ⚠️ Ma la cosa che questo file protegge davvero è **un'altra**, e non si vede
/// guardando la schermata: che i numeri scritti nella card della formula siano
/// **gli stessi** che il calcolo usa. 🚨 Una formula in interfaccia è una
/// **seconda copia** delle costanti, e due copie prima o poi divergono — con il
/// risultato peggiore possibile: una pagina che spiega con precisione un calcolo
/// che il programma non fa.
void main() {
  IngredienteCarica pezzo(
    String nome, {
    double? z,
    double? oggi,
    double? media,
    double peso = 1,
    bool invertito = false,
    bool soloInNegativo = false,
  }) => IngredienteCarica(
    nome: nome,
    unita: 'ms',
    peso: peso,
    z: z,
    oggi: oggi,
    media: media,
    invertito: invertito,
    soloInNegativo: soloInNegativo,
  );

  Forma forma({
    double? carico = 1.42,
    double? carica = 61,
    int storiaCarico = 28,
    int notti = 28,
    double acuto = 480,
    double cronico = 338,
    List<IngredienteCarica>? ingredienti,
    List<double>? giorni,
  }) => Forma(
    stanchezza: Indice(
      valore: carico,
      giorniDiStoria: storiaCarico,
      giorniPerEsserePieno: IndiciDiForma.giorniCronici,
    ),
    prontezza: Indice(
      valore: carica,
      giorniDiStoria: notti,
      giorniPerEsserePieno: IndiciDiForma.nottiPerLaProntezza,
    ),
    acuto: acuto,
    cronico: cronico,
    caricoPerGiorno: giorni ?? List<double>.filled(28, 120),
    ingredienti:
        ingredienti ??
        [
          pezzo('Variabilità cardiaca', z: -1.2, oggi: 48, media: 65),
          pezzo(
            'Battito a riposo',
            z: 0.9,
            oggi: 58,
            media: 54,
            invertito: true,
          ),
          pezzo('Sonno', z: 0.3, oggi: 430, media: 415, peso: 1.5),
          pezzo(
            'Cibo',
            z: -0.8,
            oggi: 1800,
            media: 2200,
            peso: 0.5,
            soloInNegativo: true,
          ),
        ],
  );

  Future<void> apri(WidgetTester tester, Forma f) async {
    /*
     * ⚠️ **Uno schermo finto molto alto**, come già fa
     * `compositore_scheda_widget_test.dart`.
     *
     * La pagina è una `ListView`, e una `ListView` costruisce **solo ciò che
     * si vede**: con lo schermo di default le due card in fondo non esistono
     * proprio, e i `find` tornerebbero vuoti dando l'impressione che manchino.
     *
     * 💡 Alzare la finestra è più onesto che scorrere: qui si verifica
     * **cosa la pagina dice**, non come si scorre.
     */
    tester.view.physicalSize = const Size(656, 4200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        // 🚨 Da 3b-O.1a.6 ogni pagina porta l'intestazione condivisa, che
        // vuole cache e configurazione. Senza, il `throw` di difesa di
        // `core/providers.dart` fa fallire il `build` — vedi il file d'aiuto.
        overrides: [
          ...await intestazioneFinta(),
          formaProvider.overrideWith((ref) async => f),
        ],
        child: const MaterialApp(home: SchermataForma()),
      ),
    );

    await tester.pumpAndSettle();
  }

  testWidgets('mostra i due numeri e le medie da cui escono', (tester) async {
    await apri(tester, forma());

    // Il carico, con i due `EWMA` che lo producono.
    expect(find.text('142%'), findsOneWidget);

    // ⚠️ Esatto e non `textContaining`: «in salita» compare **anche** nella
    // legenda delle fasce qui sotto, e un `contains` passerebbe pure se la
    // fascia sopra il numero fosse sbagliata.
    expect(find.text('del tuo carico abituale — in salita'), findsOneWidget);
    expect(find.text('480 kcal'), findsOneWidget);
    expect(find.text('338 kcal'), findsOneWidget);

    // La carica.
    expect(find.text('61'), findsOneWidget);

    /*
     * 🚨 **Il numero grezzo accanto allo scarto.** È il motivo per cui questa
     * pagina esiste: «−1.2» da solo chiede di essere creduto, «48 contro una tua
     * media di 65» si può controllare — e smentire, se le medie sono sballate
     * perché il telefono ha perso dei giorni.
     */
    expect(find.textContaining('oggi 48 ms · tua media 65 ms'), findsOneWidget);

    // ⚠️ Il verso, scritto: senza, un `+0.9` sul battito sembrerebbe una buona
    // notizia.
    expect(find.textContaining('più basso è meglio'), findsOneWidget);
    expect(find.textContaining('conta solo se sei sotto'), findsOneWidget);
  });

  testWidgets('dice su quanti ingredienti è fatta la carica', (tester) async {
    /*
     * ══ 🚨 IL DEBITO DICHIARATO IN §52.7, CHIUSO ═════════════════════════════
     *
     * Senza rete il cibo manca e la carica si calcolava su tre pezzi su quattro
     * **senza dirlo**. ⚠️ Un indice che cambia formula in silenzio è peggio di
     * un indice assente: chi lo guarda due giorni di fila crede di confrontare
     * la stessa cosa, e invece confronta due formule diverse.
     */
    await apri(
      tester,
      forma(
        ingredienti: [
          pezzo('Variabilità cardiaca', z: -1.2, oggi: 48, media: 65),
          pezzo(
            'Battito a riposo',
            z: 0.9,
            oggi: 58,
            media: 54,
            invertito: true,
          ),
          pezzo('Sonno', z: 0.3, oggi: 430, media: 415, peso: 1.5),
          pezzo('Cibo', peso: 0.5, soloInNegativo: true),
        ],
      ),
    );

    expect(find.text('Calcolata su 3 ingredienti su 4.'), findsOneWidget);
    expect(find.textContaining('non disponibile'), findsOneWidget);
  });

  testWidgets('il carico non calcolabile spiega perché', (tester) async {
    await apri(tester, forma(carico: null, storiaCarico: 0));

    expect(find.text('—'), findsOneWidget);
    expect(find.text('non calcolabile'), findsOneWidget);
    expect(find.textContaining('Serve almeno un allenamento'), findsOneWidget);

    // 💡 Le righe delle due medie spariscono: senza denominatore non vogliono
    // dire niente, e mostrarle inviterebbe a fare il rapporto a mano.
    expect(find.text('480 kcal'), findsNothing);
  });

  testWidgets('la stima incompleta dice quanti giorni mancano', (tester) async {
    await apri(tester, forma(storiaCarico: 4, notti: 3));

    // 📌 Decisione D-2s/A: il numero **si mostra lo stesso**, con sotto quanto
    // manca. E la frase è **la stessa** della card in dashboard: chi ha cliccato
    // lì deve ritrovarla identica, non una sua variante.
    expect(find.text('142%'), findsOneWidget);
    expect(
      find.text('stima poco attendibile: mancano 24 giorni di dati'),
      findsOneWidget,
    );
    expect(
      find.text('stima poco attendibile: mancano 4 giorni di dati'),
      findsOneWidget,
    );
  });

  testWidgets('le due card in fondo ci sono sempre', (tester) async {
    // ⚠️ Anche quando il calcolo non riesce: chi è arrivato qui voleva capire
    // come funziona, e la spiegazione non dipende dai dati.
    await apri(tester, forma(carico: null, carica: null));

    expect(find.text('La formula'), findsOneWidget);
    expect(find.text('Come funziona il calcolo'), findsOneWidget);
  });

  testWidgets('e anche quella della Carica', (tester) async {
    await apri(tester, forma());

    /*
     * 🚨 **Stessa regola della formula sopra**, e qui vale di più: la Carica ha
     * più costanti scelte da noi di tutti gli altri indici messi insieme. ⛔ Una
     * pagina che spiega una formula diversa da quella che gira non è una
     * spiegazione incompleta: è una spiegazione **falsa**, e su un numero che
     * parla di fatica è peggio che non averla.
     */
    expect(
      find.textContaining(
        'scarica = ${CaricaBatteria.scaricaDellAllenamento} ×',
      ),
      findsOneWidget,
    );

    expect(
      find.textContaining(
        'recupero = ${CaricaBatteria.recuperoMinimo} + '
        '${CaricaBatteria.recuperoDalSonno} ×',
      ),
      findsOneWidget,
    );

    expect(
      find.textContaining(
        'riferimento allenamento = ${CaricaBatteria.quotaAllenamento} × TDEE',
      ),
      findsOneWidget,
    );

    // 💡 E la riga che dice **perché** la Carica non è come gli altri due.
    expect(
      find.textContaining('La Carica è una batteria, e si trascina'),
      findsOneWidget,
    );
  });

  testWidgets('la formula scritta è quella che il calcolo usa', (tester) async {
    await apri(tester, forma());

    /*
     * 🚨 **Il test che conta.** Non verifica che ci sia scritto qualcosa: lega
     * il testo alle costanti di `IndiciDiForma`. Chi domani cambiasse il peso
     * del sonno o la scala 0–100 senza toccare la pagina troverebbe qui il
     * fallimento, invece di lasciare in giro una spiegazione falsa.
     */
    expect(
      find.textContaining('media(ultimi ${IndiciDiForma.giorniAcuti} giorni)'),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'media(ultimi ${IndiciDiForma.giorniCronici} giorni)',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'carica = ${IndiciDiForma.zAlCentro.round()} + '
        '${IndiciDiForma.zQuantoPesa.round()} ×',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('sonno ${IndiciDiForma.pesoDelSonno}'),
      findsOneWidget,
    );
    expect(
      find.textContaining('cibo ${IndiciDiForma.pesoDelCibo}'),
      findsOneWidget,
    );
  });

  testWidgets('la spiegazione dice cosa i numeri non sono', (tester) async {
    await apri(tester, forma());

    /*
     * ══ ⚠️ QUESTE FRASI NON SONO CONTENUTO REDAZIONALE ═══════════════════════
     *
     * `indici_di_forma.dart` le impone all'interfaccia, e T18 del registro dei
     * trattamenti le dà per presenti. 🚨 Toglierne una è una modifica alla
     * conformità, non alla grafica — e deve costare un test rosso.
     */
    expect(find.textContaining('non li mandiamo a nessuno'), findsOneWidget);
    expect(
      find.textContaining('non finiscono nemmeno nel consiglio del giorno'),
      findsOneWidget,
    );
    expect(find.textContaining('scala da 0 a 100'), findsWidgets);
    expect(find.textContaining('l\'abbiamo scelto noi'), findsOneWidget);
    expect(find.textContaining('Usiamo le calorie attive'), findsOneWidget);
    expect(
      find.textContaining('non vogliono dire la stessa cosa'),
      findsOneWidget,
    );
    expect(find.textContaining('hai ragione tu'), findsOneWidget);
  });
}
