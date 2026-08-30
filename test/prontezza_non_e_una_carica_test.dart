import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 🎯 La prontezza non si traveste da batteria — 3b-X, 30/08/2026.
///
/// ══ 📌 LA RICHIESTA ═══════════════════════════════════════════════════════
///
/// *«nell'header di "Oggi" c'è ancora la scritta "carica" che rappresenta la
/// prontezza. Cambia l'icona e aggiungi anche la carica vera che abbiamo fatto
/// ieri»*.
///
/// ══ 🚨 NON ERA UNA SVISTA: ERA 3b-K RIMASTA A META' ══════════════════════
///
/// Lo stesso errore era **già stato corretto il 28/08**, e la correzione era
/// stata applicata in un posto solo. Le parole di allora:
///
/// > *«la parte della "Carica" non sia una batteria ma una specie di orologio
/// > con il 50 all'apice, perché a ben vedere non analizza la carica vera e
/// > propria, ma quanto sto bene o male rispetto al solito»*.
///
/// ⛔ **Una batteria mente su questo numero**: al 50% dice «sei a metà, stai
/// finendo»; questo numero al 50 dice **«sei esattamente nella tua norma»**.
///
/// ══ ⚠️ PERCHE' QUESTO TEST LEGGE I FILE ══════════════════════════════════
///
/// 🚨 **Il test utile non è «l'header scrive prontezza»**: quello difende una
/// schermata. Questo difende **la regola**, in tutte quelle che verranno.
///
/// ⛔ L'errore è arrivato fin qui proprio così: una correzione applicata dove
/// qualcuno guardava, e non dove nessuno guardava. Un test su un widget solo
/// avrebbe lasciato la porta aperta alla terza schermata.
void main() {
  final lib = Directory('lib/src');

  List<File> dartDiLib() => lib
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList(growable: false);

  /// Il codice senza i commenti.
  ///
  /// 🚨 **Serve, e l'ho scoperto sbagliando**: la prima versione di questo test
  /// segnalava il file che avevo appena corretto, perche' il commento che
  /// spiega l'errore **cita** la parola «carica» accanto alla prontezza.
  ///
  /// ⛔ Un test che non distingue il codice dalla prosa e' un test che punisce
  /// chi spiega le cose — cioe' esattamente il contrario di quello che serve
  /// qui.
  String soloCodice(String testo) => testo
      .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
      .split('\n')
      .where((r) => !r.trimLeft().startsWith('//'))
      .join('\n');

  /// I pezzi di codice che **mostrano** la prontezza.
  ///
  /// ══ ⛔ SPEZZARE SUI `;` NON FUNZIONA, E L'HO SCOPERTO SBAGLIANDO ═════════
  ///
  /// 🚨 Nel codice dell'interfaccia **i punti e virgola non separano niente**:
  /// i widget sono elementi di una lista, divisi da virgole. Tutto
  /// `children: [...]` è una sola «istruzione», e conteneva sia la carica vera
  /// sia la prontezza — così il test segnalava il file appena corretto.
  ///
  /// 💡 Una **finestra** attorno a ogni `prontezza.valore`: 300 caratteri
  /// bastano a coprire i parametri del widget che la disegna, e non di più.
  List<String> doveSiMostraLaProntezza(String codice) {
    final finestre = <String>[];

    for (final m in RegExp('prontezza.valore').allMatches(codice)) {
      final fine = (m.start + 300).clamp(0, codice.length);

      finestre.add(codice.substring(m.start, fine));
    }

    return finestre;
  }

  /// 🚨 **La parola «carica» non deve stare accanto alla prontezza.**
  test('nessuna schermata chiama «carica» la prontezza', () {
    final colpevoli = <String>[];

    for (final file in dartDiLib()) {
      for (final pezzo in doveSiMostraLaProntezza(
        soloCodice(file.readAsStringSync()),
      )) {
        if (pezzo.contains("'carica'") || pezzo.contains('"carica"')) {
          colpevoli.add(file.path);
        }
      }
    }

    expect(
      colpevoli,
      isEmpty,
      reason:
          'Qui la prontezza è etichettata «carica». Una batteria al 50% dice '
          '«stai finendo»; la prontezza a 50 dice «sei nella tua norma». '
          'Sono due numeri diversi e vanno chiamati con due nomi diversi.',
    );
  });

  /// ⛔ E nemmeno l'icona della batteria, che è la stessa bugia disegnata.
  test('nessuna schermata dà alla prontezza l\'icona di una batteria', () {
    final colpevoli = <String>[];

    for (final file in dartDiLib()) {
      for (final pezzo in doveSiMostraLaProntezza(
        soloCodice(file.readAsStringSync()),
      )) {
        if (pezzo.contains('Icons.battery')) colpevoli.add(file.path);
      }
    }

    expect(
      colpevoli,
      isEmpty,
      reason:
          'La prontezza ha l\'icona di una batteria: è la stessa bugia '
          'dell\'etichetta, disegnata. Il 50 è il centro, non la metà di '
          'qualcosa — ci vuole uno strumento di misura.',
    );
  });

  /// 💡 E la carica vera, quella sì, la batteria se la merita: nell'header
  /// deve esserci.
  test('l\'header di «Oggi» mostra la Carica vera', () {
    final header = File(
      'lib/src/features/dashboard/ui/widgets/today_header.dart',
    ).readAsStringSync();

    expect(
      header.contains('caricaProvider'),
      isTrue,
      reason:
          'L\'header non legge la Carica: resterebbe visibile solo entrando '
          'in «Carico e carica».',
    );

    expect(header.contains("etichetta: 'prontezza'"), isTrue);
    expect(header.contains("etichetta: 'carico'"), isTrue);
    expect(header.contains("etichetta: 'carica'"), isTrue);
  });
}
