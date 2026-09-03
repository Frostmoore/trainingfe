/// Il consenso a mandare **questo** documento all'AI — Parte K, K1-ter.
///
/// ══ 📌 LA RICHIESTA, ALLA LETTERA ═════════════════════════════════════════
///
/// Il committente, il 03/09/2026: *«si deve richiedere il consenso specifico a
/// mandare quei dati all'AI, con l'avvertimento esplicito e rosso che se
/// sull'immagine o nel documento ci sono dati personali, sarebbe meglio
/// interrompere e nasconderli perché altrimenti arriverebbero all'AI anche
/// quelli, mentre se non ci sono nessuna ai può aver modo di associare i dati
/// del documento o della foto importata all'utente»*.
///
/// ══ 🚨 PERCHE' NON BASTA `ai_consent_at` ══════════════════════════════════
///
/// Quello dice *«puoi usare l'AI»* e si dà una volta nella vita. Questo dice
/// *«puoi mandare **questi byte**»*, e si chiede **ogni volta**, perché il file
/// è diverso ogni volta.
///
/// ⚠️ E la differenza non è formale: un piano alimentare con l'intestazione
/// dello studio, il nome e la data di nascita sopra è un'altra cosa rispetto a
/// un foglio di esercizi. 💡 Chi carica lo sa; noi, che il file non lo apriamo
/// mai, no.
///
/// ══ ⛔ E' UNA SCHERMATA, NON UNA SPUNTA ═══════════════════════════════════
///
/// Una casella in fondo a un modulo si tocca senza leggere. 🚨 Qui la seconda
/// via d'uscita è **la prima**, e dice cosa fare invece di limitarsi a dire di
/// no: *«Torno indietro a coprirli»*.
library;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/ui/intestazione_app.dart';
import '../data/origine_della_bozza.dart';

class ConsensoDelDocumento extends StatelessWidget {
  const ConsensoDelDocumento({
    required this.quanti,
    required this.tipo,
    super.key,
  });

  final int quanti;
  final TipoDiDocumento tipo;

  /// Apre la schermata e torna `true` **solo** se qualcuno ha detto di sì.
  ///
  /// 🚨 `?? false`: chi torna indietro con il gesto di sistema non ha
  /// acconsentito, e un `null` che diventa «sì» è il modo più silenzioso
  /// possibile di mandare un documento sanitario a un fornitore.
  static Future<bool> chiedi(
    BuildContext context, {
    required int quanti,
    required TipoDiDocumento tipo,
  }) async =>
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => ConsensoDelDocumento(quanti: quanti, tipo: tipo),
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rosso = theme.colorScheme.error;

    final cosa = tipo == TipoDiDocumento.pdf
        ? (quanti == 1 ? 'questo documento' : 'questi $quanti documenti')
        : (quanti == 1 ? 'questa fotografia' : 'queste $quanti fotografie');

    return Scaffold(
      appBar: const IntestazioneApp(titolo: 'Prima di mandarlo'),
      body: ListView(
        padding: const EdgeInsets.all(Gap.md),
        children: [
          /*
           * ══ 🔴 IL RIQUADRO ROSSO ════════════════════════════════════════
           *
           * 📌 *«con l'avvertimento esplicito e rosso»*.
           *
           * ⚠️ **Rosso e in cima**, non un'annotazione a piè di pagina: è
           * l'unica cosa in tutta la schermata che qualcuno debba per forza
           * leggere, e l'unico momento in cui può ancora fare qualcosa.
           */
          Card(
            color: theme.colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(Gap.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: rosso),
                      const SizedBox(width: Gap.sm),
                      Expanded(
                        child: Text(
                          'Ci sono dati personali sul foglio?',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onErrorContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Gap.sm),
                  Text(
                    'Se sopra c\'è il tuo nome, la tua data di nascita, un '
                    'codice fiscale o l\'intestazione con i tuoi dati, '
                    'meglio fermarsi qui e coprirli prima di mandare: '
                    'altrimenti arrivano all\'intelligenza artificiale anche '
                    'quelli.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: Gap.sm),
                  Text(
                    'Se non ci sono, quello che parte è un foglio di numeri e '
                    'basta: nessuno, dall\'altra parte, ha modo di collegarlo '
                    'a te.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Gap.md),

          /*
           * 💡 **Cosa parte davvero, detto per esteso.** Chi acconsente deve
           * poter sapere a cosa: un consenso a «il trattamento dei dati» non è
           * un consenso, è una firma.
           */
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Gap.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cosa parte', style: theme.textTheme.titleSmall),
                  const SizedBox(height: Gap.xs),
                  Text(
                    'Parte $cosa, così com\'è, verso Anthropic, che lo legge e '
                    'ci restituisce le righe trascritte.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: Gap.sm),
                  Text(
                    'Non parte il tuo nome, la tua email, il tuo peso né niente '
                    'del tuo profilo: nella richiesta non c\'è nessun modo di '
                    'risalire a chi sei.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: Gap.sm),
                  Text(
                    'Anthropic non lo usa per addestrare i suoi modelli e lo '
                    'cancella entro trenta giorni. Da noi sparisce appena la '
                    'trascrizione è finita: resta solo la copia sul tuo '
                    'telefono.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: Gap.sm),
                  Text(
                    'Senza questo consenso non parte niente, e puoi negarlo '
                    'senza perdere nient\'altro dell\'app.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Gap.lg),

          /*
           * ══ 🚨 LA VIA D'USCITA E' LA PRIMA, E DICE COSA FARE ═══════════
           *
           * ⛔ Non «Annulla»: *«Torno indietro a coprirli»*. Un pulsante che
           * dice cosa succede dopo è l'unico che qualcuno legge davvero, e qui
           * l'uscita è l'opzione **giusta** in tutti i casi dubbi.
           */
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pop(false),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Torno indietro a coprirli'),
          ),
          const SizedBox(height: Gap.sm),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.send),
            label: const Text('Non ci sono dati personali, vai'),
          ),
        ],
      ),
    );
  }
}
