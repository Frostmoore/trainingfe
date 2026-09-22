import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/chiavi/ui/ripristino_da_file.dart';

/// ♻️ **Il ripristino si raggiunge da «Backup e dati», e si sceglie il file** —
/// 23/09/2026.
///
/// 📌 Due richieste del committente, la stessa notte:
/// *«non capisco perché per ripristinare il backup devo andare sui messaggi e
/// non su "backup e dati"»* e *«fai sta voce 51 subito! È importante»*.
///
/// ⛔ Prima il ripristino viveva solo dietro alla chat **e** chiedeva un
/// percorso scritto a mano, in una cartella che l'app non ha il permesso di
/// leggere: chi aveva perso tutto non ci arrivava in nessun modo.
void main() {
  group('il dialogo che chiede file e codice', () {
    /// 🚨 Il pulsante resta spento finché i tre pezzi non ci sono: un
    /// ripristino avviato con un codice monco fallisce dopo venti secondi di
    /// argon2id, e sembra che il file sia rotto.
    testWidgets('non si parte senza file, codice e password', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChiediFileECodice(scegli: _selettoreFinto('backup.json')),
          ),
        ),
      );

      FilledButton bottone() =>
          tester.widget<FilledButton>(find.byType(FilledButton));

      expect(bottone().onPressed, isNull, reason: 'acceso senza niente');

      // ── Il file si sceglie: niente percorsi da scrivere.
      await tester.tap(find.text('Scegli il file'));
      await tester.pumpAndSettle();

      // 💡 Il nome compare, così si vede **quale** file si sta per aprire.
      expect(find.text('backup.json'), findsOneWidget);
      expect(find.text('Cambia file'), findsOneWidget);
      expect(bottone().onPressed, isNull, reason: 'basta il file?');

      // ⚠️ 24 caratteri **normalizzati**: i trattini non contano.
      await tester.enterText(
        find.widgetWithText(TextField, 'Codice di ripristino'),
        'ABCD-EFGH-JKLM-NPQR-STUV-WXYZ',
      );
      await tester.pump();
      expect(bottone().onPressed, isNull, reason: 'manca la password');

      await tester.enterText(
        find.widgetWithText(TextField, 'Nuova password di recupero'),
        'corta',
      );
      await tester.pump();
      expect(bottone().onPressed, isNull, reason: 'password sotto gli 8');

      await tester.enterText(
        find.widgetWithText(TextField, 'Nuova password di recupero'),
        'Password-Nuova-9',
      );
      await tester.pump();
      expect(bottone().onPressed, isNotNull);
    });

    /// 🚨 **I byte, non il percorso.** È tutta la correzione della voce 51: il
    /// ripristino non deve mai più passare dal filesystem, o torna a fallire su
    /// qualunque file che non stia nella cartella privata dell'app.
    testWidgets('quello che esce dal dialogo sono i byte del file', (
      tester,
    ) async {
      DatiDelFile? uscito;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async => uscito = await showDialog<DatiDelFile>(
                  context: context,
                  builder: (_) =>
                      ChiediFileECodice(scegli: _selettoreFinto('copia.tcb')),
                ),
                child: const Text('apri'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('apri'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Scegli il file'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Codice di ripristino'),
        'ABCDEFGHJKLMNPQRSTUVWXYZ',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Nuova password di recupero'),
        'Password-Nuova-9',
      );
      await tester.pump();

      await tester.tap(find.text('Ripristina'));
      await tester.pumpAndSettle();

      expect(uscito, isNotNull);
      expect(uscito!.byte, _contenutoFinto);
      expect(uscito!.nome, 'copia.tcb');
    });
  });

  group('le due porte, una sola strada', () {
    /// 💡 Si legge il sorgente, come fa `orientamento_verticale_test`: qui
    /// interessa **che non esistano due ripristini**, e quello non si vede
    /// pompando un widget.
    final backup = File(
      'lib/src/features/chiavi/ui/schermata_backup.dart',
    ).readAsStringSync();

    final chiavi = File(
      'lib/src/features/chiavi/ui/schermata_ripristino.dart',
    ).readAsStringSync();

    final condiviso = File(
      'lib/src/features/chiavi/ui/ripristino_da_file.dart',
    ).readAsStringSync();

    test('«Backup e dati» offre il ripristino da file', () {
      expect(backup, contains('Ripristina da un file'));
      expect(backup, contains('eseguiIlRipristinoDaFile'));
    });

    /// 🚨 **E qui si difende la conferma.** Da questa schermata la chiave c'è
    /// già: aprire un file vecchio la sostituisce, e i messaggi ricevuti da
    /// allora non si riaprono più. Togliere la domanda renderebbe irreversibile
    /// un tocco distratto.
    test('e prima chiede conferma, perché la chiave c\'è già', () {
      expect(backup, contains('Aprire un file di backup?'));
    });

    /// ⛔ La riga che impedisce il ritorno del difetto: se un domani qualcuno
    /// ricopia la logica dentro una schermata, qui si accorge.
    ///
    /// ⚠️ Si guarda `importaQualsiasi` — il gesto di **aprire il file** — e non
    /// `ripristinaDaChiave`: quella la usa legittimamente anche «Ricomincia»,
    /// che non apre niente e genera una chiave nuova di zecca.
    test('nessuna delle due si è fatta la sua copia', () {
      for (final sorgente in [backup, chiavi]) {
        expect(sorgente, contains('eseguiIlRipristinoDaFile'));
        expect(
          sorgente,
          isNot(contains('importaQualsiasi')),
          reason: 'aprire il file sta in ripristino_da_file.dart, non qui',
        );
      }
    });

    /// 🚨 **Voce 51, e non deve tornare.** L'app non ha permessi sull'archivio
    /// condiviso: qualunque ritorno a `File(percorso).readAsBytes()` rimette il
    /// ripristino nello stato in cui funzionava solo da una cartella che
    /// nessuno può raggiungere dal telefono.
    /// ⚠️ Si guarda il **codice**, non i commenti: qui sopra il difetto vecchio
    /// è raccontato per esteso — `File(percorso).readAsBytes()` — e un controllo
    /// ingenuo lo scambierebbe per il difetto stesso.
    test('il file non si apre più per percorso', () {
      final codice = _senzaCommenti(condiviso);

      expect(codice, isNot(contains('readAsBytes')));
      expect(codice, isNot(contains('Percorso del file')));
      expect(codice, contains('pickFiles(withData: true)'));
    });
  });
}

/// Via i commenti: restano solo le righe che il compilatore legge davvero.
String _senzaCommenti(String sorgente) => sorgente
    .split('\n')
    .where((r) {
      final t = r.trimLeft();

      return !t.startsWith('//') && !t.startsWith('*') && !t.startsWith('/*');
    })
    .join('\n');

final _contenutoFinto = Uint8List.fromList([1, 2, 3, 4, 5]);

SceltaDelFile _selettoreFinto(String nome) =>
    () async => (nome: nome, byte: _contenutoFinto);
