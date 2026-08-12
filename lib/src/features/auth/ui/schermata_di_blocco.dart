import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/ui/states.dart';
import '../auth_controller.dart';

/// 🔒 La sessione c'è, ma è chiusa a chiave — A1.
///
/// ── 🚨 Perché non è la schermata di accesso ───────────────────────────────
///
/// Chi arriva qui **è già dentro**: il token è valido e la password non serve.
/// Mostrargli il modulo di accesso significherebbe chiedergli di rifare una
/// cosa che ha già fatto, e trasformare una scorciatoia in un peso.
///
/// ── ⚠️ La via d'uscita è sempre visibile, e non in fondo a un menu ────────
///
/// Dito bagnato in palestra, lettore che non legge, impronta riconfigurata dopo
/// un aggiornamento di sistema. Se «usa la password» fosse nascosto, una
/// funzione accesa per comodità chiuderebbe fuori dal proprio account — ed è
/// esattamente il momento in cui una persona disinstalla l'app invece di
/// cercare l'opzione.
class SchermataDiBlocco extends ConsumerStatefulWidget {
  const SchermataDiBlocco({super.key});

  @override
  ConsumerState<SchermataDiBlocco> createState() => _SchermataDiBloccoState();
}

class _SchermataDiBloccoState extends ConsumerState<SchermataDiBlocco> {
  bool _inCorso = false;
  bool _fallito = false;

  @override
  void initState() {
    super.initState();

    /*
     * 💡 Si prova **da soli** appena la schermata compare: nel caso normale la
     * persona vede il lettore aprirsi e appoggia il dito, senza dover prima
     * toccare un bottone che dice «sblocca» per poi fare la cosa vera.
     *
     * ⚠️ Dopo il primo frame e non nel `initState` diretto: la richiesta di
     * sistema ha bisogno di una schermata già montata sotto, altrimenti al
     * ritorno non trova dove tornare.
     */
    WidgetsBinding.instance.addPostFrameCallback((_) => _prova());
  }

  Future<void> _prova() async {
    if (_inCorso) return;

    setState(() {
      _inCorso = true;
      _fallito = false;
    });

    final aperto = await ref
        .read(authControllerProvider.notifier)
        .sbloccaConImpronta();

    // ⚠️ Riuscendo, questo widget sta già sparendo: toccare `setState` dopo
    // significherebbe scrivere su uno `State` smontato.
    if (!mounted || aperto) return;

    setState(() {
      _inCorso = false;
      _fallito = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: EmptyState(
                icon: Icons.lock_outline_rounded,
                title: 'App bloccata',
                message: _fallito
                    ? 'Non è andata. Riprova, oppure entra con la password.'
                    : 'Sblocca con l\'impronta o con il codice del telefono.',
                action: FilledButton.icon(
                  onPressed: _inCorso ? null : _prova,
                  icon: const Icon(Icons.fingerprint_rounded),
                  label: Text(_inCorso ? 'Attendi…' : 'Sblocca'),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Gap.lg),
              child: TextButton(
                // 🚨 Sempre attivo, anche mentre la verifica è in corso: se il
                // dialogo di sistema non si chiude — succede, su certi Android
                // — questo è l'unico modo per uscire.
                onPressed: () => ref
                    .read(authControllerProvider.notifier)
                    .entraConLaPassword(),
                child: const Text('Entra con la password'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
