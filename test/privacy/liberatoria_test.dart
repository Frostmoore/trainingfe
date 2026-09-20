import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/privacy/liberatoria_controller.dart';

/// ✍️ La liberatoria dell'art. 28 letta dall'app — 20/09/2026.
void main() {
  test('quando serve, arrivano tipo, versione e testo', () {
    final stato = StatoLiberatoria.fromJson(const {
      'serve': true,
      'tipo': 'trainer',
      'versione': 'trainer-v1',
      'testo': '# Liberatoria',
    });

    expect(stato.serve, isTrue);
    expect(stato.tipo, 'trainer');
    expect(stato.versione, 'trainer-v1');
    expect(stato.testo, contains('Liberatoria'));
  });

  test('a un iscritto non serve, e non arriva nessun testo', () {
    final stato = StatoLiberatoria.fromJson(const {
      'serve': false,
      'tipo': null,
      'versione': null,
      'testo': null,
    });

    expect(stato.serve, isFalse);
    expect(stato.tipo, isNull);
  });

  /// 🚨 Una risposta storta non deve **bloccare** chi allena: il muro vero sta
  /// sul server, che rifiuta comunque. Qui si sceglie di non sapere.
  test('una risposta senza campi vale «non serve»', () {
    final stato = StatoLiberatoria.fromJson(const {});

    expect(stato.serve, isFalse);
    expect(const StatoLiberatoria.aPosto().serve, isFalse);
  });
}
