import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_client.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../avvisi_controller.dart';
import '../data/avviso.dart';

/// 📣 **La modale di un avviso** — blocco B4, 24/09/2026.
///
/// 📌 Il committente, il 23/09: *«una modale in-app con un tasto per approvare
/// (testo che deciderò di volta in volta) e uno per rifiutare. Il tasto per
/// approvare deve poter fare una serie di cose: dismiss, link, promo, e logga.
/// Rifiuta chiude sempre la modale e logga il rifiuto»*.
///
/// ══ 🚨 I DUE TASTI CI SONO SEMPRE ══════════════════════════════════════════
///
/// ⛔ **Una modale che si può solo approvare non è un avviso, è un pedaggio.**
/// Rifiutare è sempre un'uscita vera, e viene registrata come l'approvazione:
/// *«il numero di chi dice di no è metà del motivo per cui si manda un avviso»*.
///
/// ⚠️ **Le etichette arrivano dal server**, non si inventano qui: le scrive la
/// piattaforma ogni volta.
///
/// 🚨 E **l'azione `promo` non la esegue l'app**: la fa il server dentro la
/// risposta alla decisione. Qui si apre al massimo un link.
class AvvisoModale extends ConsumerStatefulWidget {
  const AvvisoModale({required this.avviso, super.key});

  final Avviso avviso;

  /// ⚠️ Senza `context` di proposito: questa modale la apre un osservatore che
  /// vive **sopra il `Navigator`**, e col proprio contesto non ne troverebbe
  /// nessuno — è la trappola già pagata da `AbbonamentoScaduto`.
  static Future<void> mostra(Avviso avviso, [BuildContext? context]) =>
      showModalBottomSheet<void>(
        context: context ?? chiaveDelNavigatore.currentContext!,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => AvvisoModale(avviso: avviso),
      );

  @override
  ConsumerState<AvvisoModale> createState() => _AvvisoModaleState();
}

class _AvvisoModaleState extends ConsumerState<AvvisoModale> {
  bool _inCorso = false;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final avviso = widget.avviso;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            avviso.titolo,
            style: tema.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: Gap.sm),

          Text(
            avviso.testo,
            style: tema.textTheme.bodyMedium?.copyWith(
              color: tema.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Gap.lg),

          FilledButton(
            onPressed: _inCorso ? null : () => _rispondi(approvato: true),
            child: Text(avviso.tastoApprova),
          ),
          const SizedBox(height: Gap.sm),

          /*
           * ⚠️ **Il rifiuto è un pulsante vero, non una «x» in un angolo.**
           * ⛔ Nascosto, dice che la risposta giusta è una sola — e allora non
           * è una domanda.
           */
          OutlinedButton(
            onPressed: _inCorso ? null : () => _rispondi(approvato: false),
            child: Text(avviso.tastoRifiuta),
          ),
        ],
      ),
    );
  }

  Future<void> _rispondi({required bool approvato}) async {
    setState(() => _inCorso = true);

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await ref
          .read(avvisiActionsProvider)
          .rispondi(widget.avviso.id, approvato: approvato);

      /*
       * 🔗 Il link si apre **dopo** aver registrato la risposta: se si aprisse
       * prima, chi torna indietro dal browser si ritroverebbe la stessa modale
       * — e la risposta non sarebbe arrivata da nessuna parte.
       */
      if (approvato && widget.avviso.apreUnLink) {
        await launchUrl(
          Uri.parse(widget.avviso.url!),
          mode: LaunchMode.externalApplication,
        );
      }

      navigator.pop();
    } on Object catch (errore) {
      /*
       * ⚠️ **Se la risposta non arriva, la modale resta aperta.** ⛔ Chiuderla
       * lo stesso vorrebbe dire far credere di aver risposto: l'avviso
       * tornerebbe alla prossima apertura e sembrerebbe un difetto.
       */
      if (mounted) setState(() => _inCorso = false);

      messenger.showSnackBar(
        SnackBar(content: Text(ApiClient.unwrapError(errore).message)),
      );
    }
  }
}
