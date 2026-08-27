/// 🤖 «Generato con l'AI» — l'etichetta, 3b-J.4, 27/08/2026.
///
/// ══ 📌 LA RICHIESTA ═══════════════════════════════════════════════════════
///
/// 📌 *«dovunque ci sia qualcosa di generato da ai, ci deve essere chiaramente
/// scritto che la cosa è stata generata con l'ai»*.
///
/// ══ 🚨 PERCHÉ UN WIDGET SOLO, E NON UNA RIGA SCRITTA OGNI VOLTA ═══════════
///
/// Perché è una regola, e le regole scritte a mano in sette posti diventano sei
/// posti al primo che dimentica. ⛔ Con un widget solo, «dove manca» è una
/// domanda a cui si risponde con un `grep` — ed è quello che fa il test che la
/// difende.
///
/// 💡 E cambiare la formula un domani è una modifica sola.
///
/// ══ ⚠️ NON SOSTITUISCE L'AVVERTENZA DEL CONSIGLIO ═════════════════════════
///
/// Sotto il consiglio del giorno c'è un testo più lungo — *«non è un parere
/// medico… parlane con un medico dello sport»* — ed è un'altra cosa: quella
/// **avverte**, questa **attribuisce**. 🚨 Dove serve avvertire non basta
/// etichettare.
library;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// La formula, in un posto solo.
///
/// 💡 «con l'AI» e non «da un'AI»: lo strumento è nostro e la responsabilità di
/// mostrartelo è nostra. ⛔ «Da un'intelligenza artificiale» suona come uno
/// scarico di responsabilità verso qualcun altro.
const testoEtichettaAi = 'Generato con l\'AI';

class EtichettaAi extends StatelessWidget {
  const EtichettaAi({this.aggiunta, super.key});

  /// Qualcosa da dire accanto: «1 gettone», «può sbagliare», la data.
  ///
  /// ⚠️ **Non ci va l'avvertenza legale**: quella è più lunga e va sotto il
  /// testo, non appiccicata all'etichetta in caratteri piccoli.
  final String? aggiunta;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    /*
     * 💡 **Un'icona e una riga, non un riquadro colorato.** Questa etichetta
     * compare accanto a cose che vanno lette: se gridasse più del contenuto,
     * il contenuto lo si leggerebbe meno — e il contenuto è quello di cui
     * bisogna diffidare.
     */
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.auto_awesome_rounded,
          size: 13,
          color: tema.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: Gap.xs),
        Flexible(
          child: Text(
            aggiunta == null
                ? testoEtichettaAi
                : '$testoEtichettaAi · ${aggiunta!}',
            style: tema.textTheme.labelSmall?.copyWith(
              color: tema.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
