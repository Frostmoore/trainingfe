import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
    NavigationDestination(
      icon: Icon(Icons.person_outline_rounded),
      selectedIcon: Icon(Icons.person_rounded),
      label: 'Profilo',
    ),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    body: shell,
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
