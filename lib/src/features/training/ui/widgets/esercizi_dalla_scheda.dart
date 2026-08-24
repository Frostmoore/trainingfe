/// Gli esercizi della scheda attaccata a un allenamento — 3b-B.20.4.
///
/// 📌 *«nel caso di allenamenti con l'orologio, se ci ho allegato una scheda, la
/// pagina deve diventare IDENTICA a quella di un allenamento nato nell'app»*.
///
/// ══ 🚨 «IDENTICA» QUANDO LE SERIE NON CI SONO ═════════════════════════════
///
/// Un allenamento letto dal polso non ha ripetizioni registrate: l'orologio
/// misura tempo, battito e calorie, non quanto hai caricato.
///
/// 💡 Quindi la pagina ha **la stessa forma** — le stesse card, nello stesso
/// posto, disegnate dallo stesso widget — e dentro dice quello che sa: cosa
/// c'era scritto sulla scheda. ⛔ Riempirle di carichi inventati per far tornare
/// la somiglianza darebbe una pagina che *sembra* informata, che è la specie di
/// dato peggiore di nessun dato.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../training_controller.dart';
import 'esercizi_fatti.dart';

class EserciziDallaScheda extends ConsumerWidget {
  const EserciziDallaScheda({required this.schedaId, super.key});

  /// `null` quando a questo allenamento non è stata attaccata nessuna scheda.
  final int? schedaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = schedaId;

    // ⛔ Senza scheda non si mostra un titolo con sotto il vuoto: chi non ne ha
    // attaccata una non deve nemmeno vedere che esiste una sezione.
    if (id == null) return const SizedBox.shrink();

    final scheda = ref.watch(planDetailProvider(id)).valueOrNull;

    /*
     * ⚠️ **Silenzio anche quando la scheda non c'è più.** Si può cancellare una
     * scheda e tenere l'allenamento a cui era attaccata: `planDetailProvider`
     * lancia, `valueOrNull` dà `null`, e qui non si disegna niente. ⛔ Un
     * messaggio d'errore direbbe che si è rotto qualcosa, e invece è successa
     * una cosa normale.
     */
    if (scheda == null || scheda.exercises.isEmpty) {
      return const SizedBox.shrink();
    }

    final tema = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Cosa hai fatto', style: tema.textTheme.titleMedium),
        Text(
          scheda.name,
          style: tema.textTheme.bodySmall?.copyWith(
            color: tema.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Gap.sm),

        for (final e in scheda.exercises)
          CardEsercizioFatto(
            esercizio: EsercizioFatto(
              nome: e.name,
              prescrizione: e.prescription.trim().isEmpty
                  ? null
                  : e.prescription,
              note: e.notes,
            ),
          ),
      ],
    );
  }
}
