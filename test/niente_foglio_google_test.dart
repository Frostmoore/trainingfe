import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// ⛔ Il foglio di Google non deve tornare una terza volta — 25/08/2026.
///
/// ══ 🚨 PERCHÉ UN TEST CHE LEGGE IL SORGENTE ═══════════════════════════════
///
/// 📌 24/08: *«appena si apre, parte l'interfaccia di accesso di Google»*.
/// 📌 25/08: *«È ritornato il foglio google all'apertura dell'app!»*.
///
/// ⛔ **Due volte lo stesso difetto**, e la seconda dopo che era stato dato per
/// chiuso. Non è un caso: `attemptLightweightAuthentication()` **sembra** una
/// chiamata silenziosa — il nome lo suggerisce, e la firma non dice niente — e
/// chiunque tocchi questo file può reintrodurla in buona fede.
///
/// ⚠️ Su Android fa **due** tentativi: il secondo è
/// `filterToAuthorized: false, autoSelectEnabled: false`, cioè il One Tap con
/// tutti i conti del telefono. Disegna.
///
/// 💡 **Un test di comportamento qui non è possibile**: chi disegna è Google
/// Play Services, in un processo che un `flutter test` non vede. L'unica cosa
/// che si può difendere davvero è la **regola**: quella chiamata sta in un solo
/// posto, e quel posto è il dito di chi tocca «Attiva il backup».
///
/// 🚨 È un test brutto, e vale più di uno bello che non c'è.
void main() {
  final sorgente = File('lib/src/core/backup/drive_di_backup.dart');

  /// Le righe di codice vero: via i commenti, che di quella chiamata parlano
  /// parecchio proprio per spiegare perché non si usa.
  List<({int numero, String testo})> righeDiCodice() {
    var dentroUnBlocco = false;
    final righe = <({int numero, String testo})>[];

    for (final (indice, riga) in sorgente.readAsLinesSync().indexed) {
      final pulita = riga.trim();

      if (dentroUnBlocco) {
        if (pulita.contains('*/')) dentroUnBlocco = false;
        continue;
      }

      if (pulita.startsWith('/*')) {
        if (!pulita.contains('*/')) dentroUnBlocco = true;
        continue;
      }

      if (pulita.startsWith('///') || pulita.startsWith('//')) continue;

      righe.add((numero: indice + 1, testo: riga));
    }

    return righe;
  }

  test('il sorgente da difendere c\'è', () {
    expect(
      sorgente.existsSync(),
      isTrue,
      reason:
          'se questo file è stato spostato, questo test va spostato con lui — '
          'non cancellato',
    );
  });

  /// 🚨 **Zero volte, non «poche».** La correzione del 24/08 l'aveva tolta dai
  /// percorsi che chiamavano Google senza motivo, e lasciata su quello buono:
  /// il backup davvero dovuto. Ma un backup dovuto capita **ogni giorno**.
  test('nessuno chiama attemptLightweightAuthentication', () {
    final colpevoli = righeDiCodice()
        .where((r) => r.testo.contains('attemptLightweightAuthentication'))
        .map((r) => 'riga ${r.numero}: ${r.testo.trim()}')
        .toList();

    expect(
      colpevoli,
      isEmpty,
      reason:
          'attemptLightweightAuthentication() DISEGNA su Android (One Tap). '
          'Per un gettone Drive senza interfaccia si usa '
          'GoogleSignIn.instance.authorizationClient.authorizationForScopes(), '
          'che torna null invece di chiedere.',
    );
  });

  /// ⚠️ `authorizeScopes()` e `authenticate()` **devono** disegnare: sono il
  /// gesto di chi collega il backup. 💡 Ma stanno in un posto solo, e questo
  /// test lo tiene a uno: se un giorno compaiono altrove, è un percorso
  /// automatico che ha ricominciato a chiedere.
  test('e chi disegna sta solo in `_collega()`', () {
    final quante = righeDiCodice()
        .where(
          (r) =>
              r.testo.contains('.authorizeScopes(') ||
              r.testo.contains('GoogleSignIn.instance.authenticate('),
        )
        .length;

    expect(
      quante,
      2,
      reason:
          'una `authenticate()` e una `authorizeScopes()`, tutte e due dentro '
          '`_collega()`. Di più vuol dire che qualcosa chiede di nuovo.',
    );
  });
}
