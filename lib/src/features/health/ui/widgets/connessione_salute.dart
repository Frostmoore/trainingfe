import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../health_controller.dart';

/// Il collegamento a Health Connect — 3b-P.8.3, 22/08/2026.
///
/// ══ 📌 PERCHE' STA IN «PRIVACY E CONSENSI» ════════════════════════════════
///
/// Il committente: *«la parte di connessione a Google Health Connect deve
/// andare in privacy e consensi»*.
///
/// 💡 **Ed e' coerente con quello che e'**: collegare Health Connect e' un
/// consenso, non un'impostazione. Sta accanto agli altri consensi, che si danno
/// e si tolgono nello stesso posto.
///
/// ── 🚨 L'osservatore del ciclo di vita viene con il pulsante ─────────────
///
/// ⚠️ Questo widget e' `Stateful` per una ragione precisa, ereditata dalla
/// schermata che lo conteneva: **il permesso si concede fuori dall'app**. Si
/// apre Health Connect, si spunta, si torna indietro — e senza un osservatore
/// del ciclo di vita l'app non ha modo di accorgersene, e continua a dire
/// «collega» a chi ha appena concesso tutto.
///
/// ⛔ Chi sposta questo widget deve portarsi dietro l'osservatore, o
/// ripresenta un difetto gia' riferito e gia' corretto.
class ConnessioneSalute extends ConsumerStatefulWidget {
  const ConnessioneSalute({super.key});

  @override
  ConsumerState<ConnessioneSalute> createState() => _ConnessioneSaluteState();
}

class _ConnessioneSaluteState extends ConsumerState<ConnessioneSalute>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    /*
     * ⚠️ **Anche all'apertura, non solo al rientro.**
     *
     * Ci si arriva anche dal collegamento che Health Connect stesso propone
     * (`ACTION_SHOW_PERMISSIONS_RATIONALE`), e in quel caso l'app non e' mai
     * andata in secondo piano: senza questa riga si aprirebbe dicendo
     * «collega» a chi ha appena concesso tutto.
     *
     * 💡 `addPostFrameCallback` perche' toccare un provider durante
     * `initState` modifica lo stato mentre l'albero si sta ancora costruendo.
     */
    WidgetsBinding.instance.addPostFrameCallback((_) => _provaACollegarti());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState stato) {
    // 🚨 Solo al **rientro**: `paused` e `inactive` scattano anche mentre si
    // apre il dialogo di sistema, e reagire li' vorrebbe dire leggere i
    // permessi prima che la persona abbia finito di concederli.
    if (stato == AppLifecycleState.resumed) _provaACollegarti();
  }

  /// ⚠️ Non chiede **niente** a nessuno: se il permesso manca, non succede
  /// nulla. Aprire il dialogo di sistema da qui sarebbe la cosa che
  /// `PonteSalute` vieta — un permesso chiesto prima che si capisca a cosa
  /// serve viene negato, e su Android un rifiuto ripetuto **non si ripropone
  /// piu'**.
  void _provaACollegarti() {
    if (!mounted) return;

    unawaited(ref.read(healthControllerProvider.notifier).aggiornaInSilenzio());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stato = ref.watch(healthControllerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (stato.errore != null) ...[
          Text(stato.errore!, style: TextStyle(color: theme.colorScheme.error)),
          const SizedBox(height: Gap.sm),
        ],

        FilledButton.icon(
          style: bottonePieno(altezza: 52),
          onPressed: stato.inCorso
              ? null
              : () => ref.read(healthControllerProvider.notifier).collega(),
          icon: stato.inCorso
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.link_rounded),
          label: Text(
            stato.collegato ? 'Aggiorna adesso' : 'Collega Health Connect',
          ),
        ),

        if (stato.collegato) ...[
          const SizedBox(height: Gap.sm),
          Center(
            child: Text(
              stato.ultimaSincronizzazione == null
                  ? 'Collegato'
                  : 'Ultimo aggiornamento: ${stato.ultimaSincronizzazione}',
              style: theme.textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: Gap.md),

          /*
             * 🚨 La cancellazione sta QUI, accanto al collegamento, e non
             * sepolta nelle impostazioni.
             *
             * Con i dati sul telefono il server non puo' cancellarli per conto
             * di nessuno: se questo pulsante non c'e', l'unico modo di
             * liberarsene e' disinstallare l'app. Il diritto alla cancellazione
             * non puo' dipendere dal disinstallare un'applicazione.
             */
          OutlinedButton.icon(
            style: bottonePieno(),
            onPressed: stato.inCorso
                ? null
                : () => _confermaCancellazione(context, ref),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Cancella i dati salvati sul telefono'),
          ),
        ],
      ],
    );
  }

  Future<void> _confermaCancellazione(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final conferma = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancellare i dati?'),
        content: const Text(
          'Sonno, HRV, battito, calorie e allenamenti salvati su questo telefono '
          'vengono cancellati. '
          'Non si possono recuperare: non ne esiste nessuna copia altrove.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancella'),
          ),
        ],
      ),
    );

    if (conferma != true) return;

    await ref.read(healthControllerProvider.notifier).cancellaTutto();
  }
}
