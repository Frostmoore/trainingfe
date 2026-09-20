import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/import/data/origine_della_bozza.dart';
import 'package:training_companion/src/features/import/ui/barra_del_documento.dart';
import 'package:training_companion/src/features/training/data/scheda_allenamento.dart';
import 'package:training_companion/src/features/training/ui/compositore_scheda.dart';

import '../aiuto/intestazione.dart';

/// 🔬 **La revisione dell'import deve VEDERSI** — 20/09/2026.
///
/// ⛔ Sull'emulatore «Controlla la scheda» si apriva **vuota**: il titolo e la
/// barra in fondo c'erano, delle righe da controllare nemmeno una.
///
/// 🚨 **La causa**: `BarraDelDocumento` conteneva un `Align` senza
/// `heightFactor`. Un `Align` con vincoli larghi si prende **tutta** l'altezza
/// disponibile, e quella barra è la `bottomNavigationBar` dello `Scaffold`:
/// diventava alta quanto lo schermo, e al corpo restava **zero**.
///
/// 💡 Per questo il test misura le **altezze** invece di cercare solo del
/// testo: il difetto non era un dato mancante, era spazio mancante — e un
/// controllo sul testo, da solo, non avrebbe detto perché.
void main() {
  SchedaAllenamento scheda() => SchedaAllenamento(
    nome: 'Scheda Palestra 3 Giorni',
    giorni: [
      GiornoDellaScheda(
        nome: 'Giorno 1',
        esercizi: [EsercizioDellaScheda(nome: 'Squat guidato')],
      ),
    ],
  );

  const origine = OrigineDellaBozza(
    importazioneId: 1,
    documenti: ['/finto/scheda.pdf'],
    tipo: TipoDiDocumento.pdf,
    righeDaControllare: 21,
  );

  testWidgets('in revisione le righe da controllare hanno spazio e si vedono', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: await intestazioneFinta(),
        child: MaterialApp(
          home: CompositoreScheda(bozza: scheda(), origine: origine),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Controlla la scheda'), findsOneWidget);
    expect(find.text('21 righe da controllare'), findsOneWidget);

    // 🚨 La barra è una barra: se si prende lo schermo, il corpo sparisce.
    expect(
      tester.getSize(find.byType(BarraDelDocumento)).height,
      lessThan(200),
      reason: 'La barra del documento si è ripresa tutta l\'altezza.',
    );

    // 🚨 E il corpo ha spazio vero, con dentro i campi da correggere.
    expect(
      tester.getSize(find.byType(ListView)).height,
      greaterThan(100),
      reason: 'Il corpo della revisione è alto zero.',
    );
    expect(find.byType(TextField), findsWidgets);

    /*
     * ⚠️ La schermata lascia in piedi un timer (il salvataggio differito del
     * modulo): senza questo, il framework fa fallire il test con
     * `!timersPending`, un errore che non nomina né la schermata né il timer.
     */
    await tester.pumpAndSettle(const Duration(seconds: 2));
  });
}
