import 'package:flutter/material.dart';

import '../../../core/ui/intestazione_app.dart';
import 'modale_acquisti.dart';

/// Dove si attiva l'assistente — 3b-O.3.1, riscritta in 3b-H il 26/08/2026.
///
/// ══ ⛔ ERA UN MOCK, E ADESSO NON LO E' PIU' ═══════════════════════════════
///
/// Fino a stamattina questa schermata aveva un avviso «i pagamenti non sono
/// attivi», i prezzi scritti a mano (*«400 richieste al mese»*, che non era
/// nessuno dei due numeri veri) e i pulsanti **disabilitati**. 📌 Era voluto:
/// *«creala per ora mock poi ci attacchiamo stripe per davvero»*.
///
/// ✅ Stripe adesso c'è, quindi l'interruttore `inArrivo` è sparito **insieme**
/// al mock, come diceva la nota di allora.
///
/// ══ 💡 E IL CONTENUTO E' QUELLO DELLA MODALE ══════════════════════════════
///
/// 🚨 Non una seconda copia: la stessa. Due listini divergono al primo prezzo
/// cambiato, e quello sbagliato è sempre quello che si guarda meno.
///
/// ⚠️ La rotta resta perché la conoscono le notifiche e i collegamenti già in
/// giro; il posto da cui ci si arriva davvero, adesso, è la **modale**.
class SchermataAcquisti extends StatelessWidget {
  const SchermataAcquisti({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
    appBar: IntestazioneApp(titolo: 'Attiva l\'assistente'),
    body: SafeArea(child: CorpoAcquisti(dentroUnaModale: false)),
  );
}
