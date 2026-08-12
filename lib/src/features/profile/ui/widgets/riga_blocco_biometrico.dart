import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/auth_controller.dart';

/// L'interruttore dello sblocco rapido — A1.
///
/// 🚨 **Non compare se il telefono non sa farlo.** Un interruttore che si
/// accende e poi fallisce sempre è peggio di un interruttore assente: la
/// persona crede di aver protetto qualcosa, e al riavvio si ritrova davanti a
/// un muro che non capisce.
///
/// ⚠️ Per lo stesso motivo `disponibile()` è `false` anche quando l'hardware
/// c'è ma **nessuna impronta è registrata**.
class RigaBloccoBiometrico extends ConsumerStatefulWidget {
  const RigaBloccoBiometrico({super.key});

  @override
  ConsumerState<RigaBloccoBiometrico> createState() =>
      _RigaBloccoBiometricoState();
}

class _RigaBloccoBiometricoState extends ConsumerState<RigaBloccoBiometrico> {
  bool? _disponibile;
  bool _acceso = false;
  bool _inCorso = false;

  @override
  void initState() {
    super.initState();
    _leggiStato();
  }

  Future<void> _leggiStato() async {
    final blocco = ref.read(bloccoBiometricoProvider);

    final disponibile = await blocco.disponibile();
    final acceso = disponibile && await blocco.attivo();

    if (!mounted) return;

    setState(() {
      _disponibile = disponibile;
      _acceso = acceso;
    });
  }

  Future<void> _cambia(bool acceso) async {
    setState(() => _inCorso = true);

    final fatto = await ref
        .read(bloccoBiometricoProvider)
        .imposta(acceso: acceso);

    if (!mounted) return;

    setState(() {
      _inCorso = false;
      // ⚠️ Si aggiorna solo se il cambio è **riuscito**: dando per scontato il
      // successo, l'interruttore resterebbe acceso dopo una verifica annullata
      // e mentirebbe sullo stato reale.
      if (fatto) _acceso = acceso;
    });

    if (!fatto && acceso) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Non è andata: lo sblocco resta spento.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Finché non si sa, non si disegna niente: mostrare l'interruttore e poi
    // farlo sparire è peggio che aspettare mezzo secondo.
    if (_disponibile != true) return const SizedBox.shrink();

    return Column(
      children: [
        const Divider(height: 1),
        SwitchListTile(
          secondary: const Icon(Icons.fingerprint_rounded),
          title: const Text('Sblocco rapido'),
          subtitle: const Text(
            'Riapri l\'app con l\'impronta invece della password',
          ),
          value: _acceso,
          onChanged: _inCorso ? null : _cambia,
        ),
      ],
    );
  }
}
