import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Il cartello che spiega perché le funzioni da trainer sono chiuse — 3b-U.3.1.
///
/// ══ 📌 LA RICHIESTA ═══════════════════════════════════════════════════════
///
/// *«è una merda se esce solo un errore, si deve capire che è perché non ha
/// pagato»* — 29/08/2026.
///
/// ══ 🚨 PERCHE' UN WIDGET E NON UNA STRINGA IN OGNI SCHERMATA ══════════════
///
/// Perché i posti da cui un trainer arriva a questo muro sono più di uno — «i
/// miei utenti», l'invio di una scheda a più persone, gli inviti — e la stessa
/// spiegazione scritta in tre punti diventa **tre spiegazioni diverse** al primo
/// ritocco. ⚠️ Quella che diverge per prima è sempre la copia che si legge meno.
///
/// ══ ⛔ COSA DICE, E COSA NON DEVE FAR CREDERE ═════════════════════════════
///
/// 🚨 **La prima cosa da dire è cosa NON si perde.** Un trainer che vede sparire
/// «i miei utenti» pensa di aver perso il lavoro di mesi: le schede restano sue
/// e continua a usarle da atleta, e questo va detto **sopra**, non in fondo.
///
/// 💡 E il tono non è un errore: non è successo niente di rotto, è scaduto un
/// abbonamento. Un'icona rossa da guasto direbbe la cosa sbagliata.
class AbbonamentoTrainerScaduto extends StatelessWidget {
  const AbbonamentoTrainerScaduto({this.messaggio, super.key});

  /// 💡 Quello del server, se è arrivato di lì: è la stessa frase, ma quando
  /// arriva dal server vuol dire che **il server l'ha appena confermato**.
  final String? messaggio;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Gap.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              // ⚠️ Un lucchetto e non un triangolo di guasto: non è rotto
              // niente, è scaduto qualcosa.
              Icons.lock_clock_outlined,
              size: 56,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: Gap.md),

            Text(
              'Abbonamento da trainer scaduto',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Gap.sm),

            Text(
              messaggio ??
                  'Le funzioni da trainer — i tuoi utenti, gli inviti e l\'invio '
                      'delle schede — tornano appena rinnovi.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Gap.lg),

            /*
             * 🚨 **La rassicurazione sta in evidenza, non in una riga di
             * chiusura.** È la cosa che quella persona sta cercando di capire
             * in quel momento, e metterla in fondo in grigio vuol dire non
             * dirla.
             */
            Container(
              padding: const EdgeInsets.all(Gap.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: Text(
                      'Le tue schede restano tue, e le usi come chiunque altro. '
                      'Non si è perso niente.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
