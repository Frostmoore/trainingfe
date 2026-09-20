import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../liberatoria_controller.dart';

/// ✍️ **La firma dell'art. 28, per chi allena** — 20/09/2026.
///
/// 🚨 **Non si chiude toccando fuori, e non ha una X.** Non è un avviso: è
/// l'atto che permette a questa persona di vedere i dati di un'altra. Chi non
/// vuole firmare esce dall'app — che è una risposta legittima, e infatti c'è
/// il pulsante per farlo.
///
/// 💡 Il riassunto sta qui, il testo intero sul sito: l'app non ha un lettore
/// di markdown, e aggiungerne uno per una schermata sola vorrebbe dire un
/// pacchetto in più da mantenere per sempre.
class AvvisoLiberatoria extends ConsumerStatefulWidget {
  const AvvisoLiberatoria({required this.tipo, super.key});

  /// `palestra` o `trainer`: cambia solo il link al testo completo.
  final String tipo;

  /// Mostra l'avviso e non torna finché non è firmato (o non si esce).
  static Future<void> mostra(BuildContext context, {required String tipo}) =>
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AvvisoLiberatoria(tipo: tipo),
      );

  @override
  ConsumerState<AvvisoLiberatoria> createState() => _AvvisoLiberatoriaState();
}

class _AvvisoLiberatoriaState extends ConsumerState<AvvisoLiberatoria> {
  bool _inCorso = false;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('Prima di seguire qualcuno'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Da qui in avanti vedrai i dati di altre persone: nome, email, '
                'e le conversazioni che avrete. Prima di cominciare devi '
                'accettare cosa puoi farci e cosa no.',
              ),
              const SizedBox(height: Gap.md),
              const Text('In breve:'),
              const SizedBox(height: Gap.xs),
              const Text('· I dati dei tuoi allievi restano loro.'),
              const Text(
                '· Non puoi usarli per promozioni, né portarteli via.',
              ),
              const Text(
                '· Peso, misure, diario e sonno non li vedi: te li racconta '
                'l\'allievo, se vuole.',
              ),
              const Text(
                '· Se perdi il telefono o qualcuno entra nel tuo account, '
                'avvisaci entro 24 ore.',
              ),
              const SizedBox(height: Gap.md),
              TextButton.icon(
                onPressed: _apriIlTesto,
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Leggi il testo completo'),
              ),
              Text(
                'Restano registrati il tuo nome, la data e l\'ora, e la '
                'versione del testo che stai accettando.',
                style: tema.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _inCorso ? null : _esci,
            child: const Text('Esci'),
          ),
          FilledButton(
            onPressed: _inCorso ? null : _firma,
            child: const Text('Ho letto e accetto'),
          ),
        ],
      ),
    );
  }

  Future<void> _apriIlTesto() async {
    final base = ref
        .read(appConfigProvider)
        .apiBaseUrl
        .replaceFirst(RegExp(r'/api/v1/?$'), '');

    await launchUrl(
      Uri.parse('$base/liberatoria-${widget.tipo}'),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _firma() async {
    setState(() => _inCorso = true);
    final navigatore = Navigator.of(context);
    final messaggeria = ScaffoldMessenger.of(context);

    try {
      await ref.read(liberatoriaProvider).firma();
      navigatore.pop();
    } on Object {
      messaggeria.showSnackBar(
        const SnackBar(
          content: Text('Non riesco a registrare la firma. Riprova.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  /// 💡 Non firmare è una risposta: si esce, e il resto dell'app resta com'era.
  void _esci() => Navigator.of(context).pop();
}
