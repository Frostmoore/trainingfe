import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/onboarding/data/invito_in_palestra.dart';

/// 🖼️ 📍 **Testata e indirizzo nella pagina dell'invito** — F6.2 (A2, A3).
///
/// 📌 Il committente, sulla scheda pubblica: *«mettiamoci anche un'immagine di
/// testata (si dovrà vedere nell'app)»* · *«serve anche l'indirizzo preciso
/// (con cap provincia e tutto)»*.
///
/// ⚠️ La pagina dell'invito è il posto in cui oggi una persona incontra la
/// scheda di una palestra: il catalogo, ha detto il committente, *«proprio non
/// esiste ancora»*.
void main() {
  Map<String, dynamic> risposta({Map<String, dynamic> extra = const {}}) => {
    'palestra': {'name': 'Olimpia'},
    'descrizione': 'Sala pesi e corsi.',
    'cosa_ottieni': const [],
    'ruolo': 'member',
    ...extra,
  };

  test('legge testata, indirizzo e mappa', () {
    final invito = InvitoInPalestra.fromJson(
      risposta(
        extra: {
          'immagine_testata': 'https://esempio/sala.jpg',
          'indirizzo': 'Via Roma, 12 · 01036 Nepi (VT)',
          'mappa': 'https://www.google.com/maps/search/?api=1&query=Via%20Roma',
        },
      ),
    );

    expect(invito.immagineTestata, 'https://esempio/sala.jpg');
    expect(invito.indirizzo, 'Via Roma, 12 · 01036 Nepi (VT)');
    expect(invito.mappa, startsWith('https://www.google.com/maps/'));
  });

  test('un server vecchio non li manda, e l\'invito si legge lo stesso', () {
    final invito = InvitoInPalestra.fromJson(risposta());

    expect(invito.immagineTestata, isNull);
    expect(invito.indirizzo, isNull);
    expect(invito.mappa, isNull);

    // 💡 E il resto è quello di prima: un campo nuovo non deve rompere niente.
    expect(invito.descrizione, 'Sala pesi e corsi.');
  });

  test('una stringa vuota vale quanto un campo che manca', () {
    final invito = InvitoInPalestra.fromJson(
      risposta(extra: {'indirizzo': '   ', 'immagine_testata': ''}),
    );

    expect(
      invito.indirizzo,
      isNull,
      reason:
          'Un indirizzo vuoto disegnerebbe l\'icona del segnaposto accanto a '
          'niente, e un pulsante «apri nelle mappe» che porta al vuoto.',
    );
    expect(invito.immagineTestata, isNull);
  });
}
