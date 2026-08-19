import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../auth/ui/widgets/accoglienza.dart';

/// La shell con la barra di navigazione — A3.3.
///
/// `StatefulShellRoute` e non un `IndexedStack` fatto a mano: **ogni scheda
/// conserva il proprio stato di navigazione**. Senza, tornare al diario dopo
/// essere passati dall'allenamento riporterebbe in cima alla lista, perdendo la
/// posizione e i filtri — il difetto che fa sembrare un'app «che si dimentica
/// le cose».
class HomeShell extends StatelessWidget {
  const HomeShell({required this.shell, super.key});

  final StatefulNavigationShell shell;

  static const _destinazioni = [
    NavigationDestination(
      icon: Icon(Icons.today_outlined),
      selectedIcon: Icon(Icons.today_rounded),
      label: 'Oggi',
    ),
    NavigationDestination(
      icon: Icon(Icons.restaurant_outlined),
      selectedIcon: Icon(Icons.restaurant_rounded),
      label: 'Diario',
    ),
    NavigationDestination(
      icon: Icon(Icons.fitness_center_outlined),
      selectedIcon: Icon(Icons.fitness_center_rounded),
      label: 'Allenamento',
    ),
    NavigationDestination(
      icon: Icon(Icons.chat_bubble_outline_rounded),
      selectedIcon: Icon(Icons.chat_bubble_rounded),
      label: 'Messaggi',
    ),

    /*
     * 🚨 **Il profilo NON è più qui** — M7.1, 18/08/2026, richiesta del
     * committente.
     *
     * La barra in basso è quello che si fa **ogni giorno**: oggi, diario,
     * allenamento, messaggi. ⚠️ Il profilo non è un'attività — è dove si va a
     * cambiare una cosa, ogni tanto — e teneva un quinto dello spazio più
     * prezioso dell'app per una schermata che si apre una volta a settimana.
     *
     * 💡 Adesso sta in alto a destra con la propria faccia (`BottoneProfilo`),
     * che è anche dove le persone lo cercano già: è la convenzione di ogni
     * applicazione che hanno sul telefono.
     */
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    /*
     * 🚨 **`Accoglienza` e basta** — 19/08/2026, sera.
     *
     * Qui c'era **anche** `PropostaSblocco`, ed e' rimasta quando l'impronta e'
     * stata spostata **dentro** la sequenza. Risultato: due widget invisibili
     * che proponevano la stessa cosa nello stesso fotogramma, e mentre il
     * dialogo era aperto la sequenza tirava dritto e apriva il selettore
     * account di Google **sotto**.
     *
     * ⚠️ Il committente l'ha descritto cosi': *«appena mi chiede l'impronta,
     * parte subito sotto una specie di piccola interfaccia di google»*. Non era
     * Google: era il passo 2 che partiva mentre il passo 1 era ancora aperto.
     *
     * 💡 **Spostare un passo dentro una sequenza vuol dire toglierlo da dove
     * stava.** Sembra ovvio scritto qui; non lo e' stato.
     */
    body: Stack(children: [shell, const Accoglienza()]),
    bottomNavigationBar: NavigationBar(
      selectedIndex: shell.currentIndex,
      destinations: _destinazioni,
      // `initialLocation: true` solo quando si ritocca la scheda già attiva:
      // è il gesto con cui si torna in cima, e su ogni altra app funziona così.
      onDestinationSelected: (index) =>
          shell.goBranch(index, initialLocation: index == shell.currentIndex),
    ),
  );
}
