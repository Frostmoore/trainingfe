import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../auth/ui/widgets/accoglienza.dart';
import '../../auth/ui/widgets/proposta_sblocco.dart';

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
     * 🔒 `PropostaSblocco` sta qui e non in una schermata — A1.
     *
     * È un widget **invisibile** (`SizedBox.shrink`) che al primo frame decide
     * se proporre lo sblocco con l'impronta. Sta nella shell perché è l'unico
     * punto che esiste **subito dopo l'accesso** e **sopravvive al cambio di
     * scheda**: dentro «Oggi» la proposta ricomparirebbe ogni volta che si
     * torna su quella scheda.
     */
    /*
     * 🚨 **`Accoglienza` PRIMA di `PropostaSblocco`** — FASE 2-bis.
     *
     * ⚠️ L'ordine nello `Stack` non decide chi parte prima — lo decidono i due
     * `postFrameCallback` — ma il primo passo dell'accoglienza e' il
     * **ripristino**, e va offerto prima che l'app scriva qualunque cosa. La
     * proposta dell'impronta non scrive niente, quindi convive senza danno.
     *
     * 💡 Se un giorno servisse la certezza dell'ordine, la strada e' spostare
     * l'impronta **dentro** la sequenza, non riordinare lo `Stack`.
     */
    body: Stack(children: [shell, const Accoglienza(), const PropostaSblocco()]),
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
