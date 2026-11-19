/// 📋 **L'ordine dei pezzi di Oggi** — `plan_interfaccia.md` I2, 19/11/2026.
///
/// Ogni caso è una regola del committente che è già stata rotta una volta:
///
/// | Caso | Regola |
/// |---|---|
/// | «Com'è fatto» subito sotto il peso | 30/08/2026, solo per l'abbonato |
/// | per chi non è abbonato, il suo prima delle sfumate | 08/09/2026: *«quelle visibili siano le prime»* |
/// | le medaglie sopra il consiglio | 3b-A.8.3 |
/// | il titolo «Con l'abbonamento» apre le sfumate | 19/11: le sfumate stanno insieme, e si dice perché |
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/dashboard/ordine_di_oggi.dart';

void main() {
  final abbonato = pezziDiOggi(abbonato: true);
  final libero = pezziDiOggi(abbonato: false);

  test('per l’abbonato, «Com’è fatto» viene subito dopo il peso', () {
    expect(
      abbonato.indexOf(PezzoDiOggi.composizione),
      abbonato.indexOf(PezzoDiOggi.peso) + 1,
    );
  });

  test('per chi non è abbonato, niente di sfumato prima di una cosa sua', () {
    final ultimoLibero = libero.lastIndexWhere(
      (p) =>
          !pezziSottoAbbonamento.contains(p) &&
          p != PezzoDiOggi.titoloConLAbbonamento,
    );
    final primoSfumato = libero.indexWhere(pezziSottoAbbonamento.contains);

    expect(ultimoLibero, lessThan(primoSfumato));
  });

  test('il titolo «Con l’abbonamento» sta subito sopra la prima sfumata', () {
    expect(
      libero.indexOf(PezzoDiOggi.titoloConLAbbonamento),
      libero.indexWhere(pezziSottoAbbonamento.contains) - 1,
    );
    expect(abbonato, isNot(contains(PezzoDiOggi.titoloConLAbbonamento)));
  });

  test('le medaglie stanno sopra il consiglio, per tutti', () {
    for (final ordine in [abbonato, libero]) {
      expect(
        ordine.indexOf(PezzoDiOggi.achievements),
        lessThan(ordine.indexOf(PezzoDiOggi.spunto)),
      );
    }
  });

  test('nessuno perde un pezzo: abbonato e no hanno le stesse cose', () {
    final soloContenuto = {...PezzoDiOggi.values}
      ..remove(PezzoDiOggi.titoloConLAbbonamento);

    expect(abbonato.toSet(), soloContenuto);
    expect(libero.toSet(), {...soloContenuto, PezzoDiOggi.titoloConLAbbonamento}
      ..remove(PezzoDiOggi.titoloAllenamento));
  });
}
