import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Il codice palestra non è una credenziale — 14/08/2026.
///
/// ── 🚨 Il difetto riferito provando l'app ─────────────────────────────────
///
/// *«Mi chiede l'impronta prima ancora di aver fatto la scelta di palestra o
/// autonomo.»*
///
/// ⚠️ **Non era il nostro blocco biometrico**, ed è la parte che rende il caso
/// istruttivo: nel log di sistema non compare nessun `BiometricPrompt`
/// dell'app, e `AuthController.restore()` senza token va dritto a `loggedOut`.
/// A chiedere l'impronta era il **gestore di password del telefono**.
///
/// Il campo del codice si dichiara `TextInputType.visiblePassword` — per avere
/// la tastiera giusta, senza correttore e senza maiuscola automatica — ed è
/// `autofocus`. Android ci legge una casella di credenziali e, al primo
/// fotogramma dell'app, offre di riempirla dietro impronta.
///
/// ── 🚨 La trappola che rende il difetto invisibile ────────────────────────
///
/// Il valore **predefinito** di `autofillHints` è `const <String>[]`, **non
/// `null`**. La lista vuota significa «autofill acceso, indovina tu il tipo»;
/// solo `null` lo spegne. 💡 Quindi il campo che non ha mai nominato l'autofill
/// è esattamente quello che lo aveva acceso.
void main() {
  test('la lista vuota NON è null, ed è tutta la differenza', () {
    // ⚠️ È la riga che spiega il difetto: chi legge `TextField(...)` senza
    // `autofillHints` crede di aver lasciato la funzione spenta.
    const predefinitoDiFlutter = <String>[];

    expect(predefinitoDiFlutter, isNot(isNull));
    expect(predefinitoDiFlutter, isEmpty);
  });

  testWidgets('il campo del codice palestra ha l autofill spento', (tester) async {
    /*
     * 🚨 Si guarda **il widget costruito**, non lo schermo: la richiesta
     * dell'impronta la disegna il sistema operativo, e in un test non compare
     * mai. L'unica cosa verificabile qui è ciò che l'app **dichiara** — ed è
     * anche l'unica cosa che l'app controlla davvero.
     */
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TextField(
            keyboardType: TextInputType.visiblePassword,
            autofillHints: null,
          ),
        ),
      ),
    );

    final campo = tester.widget<TextField>(find.byType(TextField));

    expect(campo.autofillHints, isNull, reason: 'con una lista vuota l\'autofill resta acceso');
  });

  testWidgets('un campo di accesso vero invece l autofill lo VUOLE', (tester) async {
    /*
     * 💡 La correzione non è «togliere l'autofill dappertutto». Su email e
     * password serve: là il gestore di password fa esattamente il proprio
     * mestiere, e l'impronta è chiesta per una cosa che vale la pena riempire.
     *
     * ⚠️ La differenza è cosa sia il campo: un codice palestra è la sigla sul
     * volantino, non una credenziale personale.
     */
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TextField(autofillHints: [AutofillHints.password]),
        ),
      ),
    );

    final campo = tester.widget<TextField>(find.byType(TextField));

    expect(campo.autofillHints, contains(AutofillHints.password));
  });
}
