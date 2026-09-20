import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/acquisti/data/listino.dart';
import 'package:training_companion/src/features/acquisti/ui/modale_acquisti.dart';

/// 🎟️ **La modale non vende come incluso quello che si paga a gettoni** —
/// 21/09/2026.
///
/// ══ ⛔ IL DIFETTO, TROVATO DUE VOLTE ══════════════════════════════════════
///
/// La modale apriva con *«Fotografi il piatto e finisce nel diario»* e lo
/// ripeteva nell'elenco di cosa dà l'abbonamento: *«Il piatto dalla foto, o da
/// una frase»*.
///
/// 🚨 **Non è compreso.** `FoodPhoto` e `FoodText` partono con `aRichiesta:
/// true` e si pagano **a gettoni anche da abbonati**: il cancello vero è
/// `CancelloDeiGettoni`, sul server.
///
/// ⚠️ Lo stesso errore era **sul sito**, ed è stato corretto il 20/09
/// (committente: *«l'ia per i pasti servono sempre i gettoni, anche per gli
/// abbonati»*). Nell'app era rimasto: due copie della stessa promessa, e ne è
/// stata corretta una sola.
///
/// ══ 💡 PERCHÉ UN TEST E NON SOLO LA CORREZIONE ════════════════════════════
///
/// Perché è una frase, e le frasi tornano: chi domani vorrà rendere la modale
/// più invitante riscriverà proprio quella, che è la funzione più bella da
/// mostrare. ⛔ Vendere come inclusa una funzione che poi chiede gettoni è il
/// modo di far sentire truffato chi ha appena pagato.
void main() {
  /// Un listino come quello vero, ma senza rete.
  Listino listino({required bool abbonato}) => Listino.fromJson({
    'abbonato': abbonato,
    'livello': abbonato ? 'plus' : 'free',
    'abbonamento': {'prezzo_cent': 800, 'chiamate_mensili': 150},
    'pacchetti': [
      {'gettoni': 200, 'prezzo_cent': 300, 'nota': 'per provare'},
      {'gettoni': 1000, 'prezzo_cent': 1250, 'nota': 'il più scelto'},
    ],
    'gettoni_disponibili': 0,
  });

  Future<void> apri(WidgetTester tester, {required bool abbonato}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          listinoProvider.overrideWith((ref) async => listino(abbonato: abbonato)),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: CorpoAcquisti(dentroUnaModale: false),
          ),
        ),
      ),
    );

    // Il `FutureProvider` si risolve al giro dopo.
    await tester.pumpAndSettle();
  }

  testWidgets('⛔ non promette il piatto dalla foto fra le cose incluse', (
    tester,
  ) async {
    await apri(tester, abbonato: false);

    expect(
      find.text('Il piatto dalla foto, o da una frase'),
      findsNothing,
      reason:
          'È la riga che vendeva come inclusa una funzione che si paga a '
          'gettoni anche da abbonati: chi paga e poi si vede chiedere altri '
          'soldi chiede il rimborso.',
    );

    expect(
      find.textContaining('Fotografi il piatto e finisce nel diario'),
      findsNothing,
      reason: 'stessa promessa, scritta nel paragrafo di apertura',
    );
  });

  testWidgets('✅ e dice chiaro che quella si paga a gettoni', (tester) async {
    await apri(tester, abbonato: false);

    expect(
      find.textContaining('si paga a gettoni, anche con l\'abbonamento'),
      findsOneWidget,
      reason:
          'detta prima è la ragione per cui i pacchetti hanno senso; scoperta '
          'dopo aver pagato è una richiesta di rimborso',
    );
  });

  testWidgets('✅ quello che l\'abbonamento apre davvero, invece, c\'è', (
    tester,
  ) async {
    await apri(tester, abbonato: false);

    // 🚨 L'automatico: è compreso, e lo decide `PianoAttivo::haLaAi()`.
    expect(find.textContaining('Il consiglio del giorno'), findsOneWidget);

    // 🚨 Le cinque card della schermata di oggi, che il gate chiude.
    expect(find.textContaining('Spunto di oggi'), findsOneWidget);

    // 🚨 `allenamentiAlGiornoSenzaAbbonamento = 1`.
    expect(find.textContaining('ne parte uno al giorno'), findsOneWidget);
  });

  /// ⛔ **Diceva «i gettoni servono solo se finisci le richieste incluse»**, e
  /// la stessa modale lo smentiva venti righe più sotto: le richieste incluse
  /// coprono quello che l'app fa **da sola**, i gettoni quello che **chiedi
  /// tu**. 🚨 Non è che finiscono le une e cominciano gli altri.
  testWidgets('🎟️ a chi è già abbonato non si dice la frase sbagliata', (
    tester,
  ) async {
    await apri(tester, abbonato: true);

    expect(
      find.textContaining('solo se finisci le richieste incluse'),
      findsNothing,
    );

    expect(
      find.textContaining('per quello che chiedi tu'),
      findsWidgets,
      reason: 'la spiegazione giusta resta, ed è quella che vende i gettoni',
    );
  });
}
