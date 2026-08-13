import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Dove un banner può stare, e dove **non deve stare mai** — F9.4, decisione D7.
///
/// ── 🚨 Perché è un enum e non un booleano passato al widget ────────────────
///
/// Perché un booleano si passa sbagliato in silenzio. Con un enum chiuso, ogni
/// punto che vuole un banner deve **dichiarare in che schermata si trova**, e
/// le schermate vietate non hanno un valore da passare: non si può chiedere un
/// banner per l'allenamento, perché `Collocazione.allenamento` non esiste.
///
/// ⚠️ **Il rischio non è il progetto, è l'incidente.** Nessuno metterà mai un
/// annuncio nel riepilogo di fine allenamento di proposito. Il modo realistico
/// in cui succede è che qualcuno, mesi dopo, aggiunga un banner «anche qui» per
/// alzare il riempimento — e questo enum è ciò che glielo impedisce senza che
/// debba conoscere D7.
enum Collocazione {
  /// Il diario alimentare: si consulta, si scorre, si torna.
  diario,

  /// Lo storico degli allenamenti e i progressi.
  storico,
}

/// Un banner pubblicitario **contestuale**, mai profilato — F9.4.
///
/// ── ✅ Cosa è stato deciso, e perché conta più del codice (D7) ─────────────
///
/// **Contestuale, non profilata** → **niente CMP e niente consenso
/// pubblicitario**. In un'app che deve già chiedere il consenso per i dati
/// sanitari, una casella in meno vale più di quanto la profilazione renderebbe.
///
/// 🚨 **Nessun dato dell'utente va a un circuito pubblicitario. Nessuno.**
/// Né sanitario, né di allenamento, né il peso — **nemmeno travestito da
/// "contesto della schermata"**. Se un circuito lo pretende, si cambia circuito.
///
/// ⚠️ Questo widget non accetta **nessun** parametro oltre alla collocazione, ed
/// è deliberato: non c'è un posto dove infilare un dato dell'utente nemmeno
/// volendo. Chi un giorno vorrà «targettizzare meglio» dovrà cambiare la firma,
/// e a quel punto leggerà questo commento.
///
/// ── 💡 E renderà poco ──────────────────────────────────────────────────────
///
/// In un'app di nicchia, pochi centesimi al mese per utente. Non è un motivo per
/// non farla — è un motivo per **non aspettarsi un ricavo**. La funzione vera
/// del piano gratuito è la **conversione**, non la cassa.
///
/// ── ⏸ Cosa manca ─────────────────────────────────────────────────────────
///
/// Il circuito pubblicitario **non è stato scelto** (come il fornitore di
/// pagamento, F9.3). Finché non c'è, questo widget disegna un segnaposto interno
/// che invita al piano a pagamento: è onesto, non chiede consensi, e non manda
/// niente a nessuno.
class BannerContestuale extends StatelessWidget {
  const BannerContestuale({required this.dove, this.mostra = true, super.key});

  /// In quale schermata di **consultazione** ci si trova.
  final Collocazione dove;

  /// 🚨 Chi ha un piano a pagamento non vede niente. È il senso del piano.
  final bool mostra;

  @override
  Widget build(BuildContext context) {
    if (!mostra) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: Gap.sm),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Row(
          children: [
            Icon(Icons.auto_awesome_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Text(
                'Con il piano Plus la stima da foto e il consiglio del giorno.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
