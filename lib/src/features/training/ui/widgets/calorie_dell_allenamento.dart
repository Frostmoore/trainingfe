/// Le calorie di un allenamento: quante, e come correggerle — 3b-C.4.
///
/// ══ 📌 «DEVE ESSERE IDENTICA» ═════════════════════════════════════════════
///
/// *«Ti avevo detto che la pagina di un allenamento dall'orologio a cui ho
/// associato una scheda doveva essere identica a un allenamento partito
/// dall'app. Questo significa che deve essere IDENTICA. Stesse cards, stesso
/// layout, stessi numeri, stesse cose»*.
///
/// ⛔ Questo riquadro viveva **privato dentro** `session_summary_screen` e
/// parlava una `WorkoutSession`. Un allenamento del polso una sessione non ce
/// l'ha — quindi o spariva, o compariva con dentro un numero che non si poteva
/// toccare. 🚨 **Una card identica che non fa la stessa cosa è peggio di una card
/// diversa**: promette e non mantiene.
///
/// 💡 Adesso parla una `VoceStorico`, che è la forma che tiene insieme le due
/// provenienze, e sa scrivere la correzione dove va: sulla seduta se c'è, sulla
/// riga dell'orologio se no.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/storico_unificato.dart';
import '../../session_controller.dart';
import '../../storico_unificato_controller.dart';

class CalorieDellAllenamento extends ConsumerStatefulWidget {
  const CalorieDellAllenamento({required this.voce, super.key});

  final VoceStorico voce;

  @override
  ConsumerState<CalorieDellAllenamento> createState() =>
      _CalorieDellAllenamentoState();
}

class _CalorieDellAllenamentoState
    extends ConsumerState<CalorieDellAllenamento> {
  late final _campo = TextEditingController(
    text: widget.voce.kcal?.toString() ?? '',
  );

  bool _inCorso = false;

  @override
  void dispose() {
    _campo.dispose();
    super.dispose();
  }

  /// Scrive la correzione **dove va**.
  ///
  /// 🚨 Sulla seduta quando c'è, sulla riga dell'orologio quando non c'è: sono
  /// due colonne diverse in due tabelle diverse, e chi guarda la card non deve
  /// saperlo. ⚠️ Se ci sono tutte e due, vince la seduta — è il dato che l'app ha
  /// registrato esercizio per esercizio.
  Future<void> _salva(int? kcal) async {
    setState(() => _inCorso = true);

    try {
      final seduta = widget.voce.seduta;

      if (seduta != null) {
        await ref.read(sessionActionsProvider).setKcal(seduta.id, kcal);
      } else {
        for (final a in widget.voce.dalPolso) {
          await correggiKcalAllenamento(ref, allenamentoId: a.id, kcal: kcal);
        }
      }
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final voce = widget.voce;
    final kcal = voce.kcal;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.local_fire_department_outlined,
                  color: tema.colorScheme.primary,
                ),
                const SizedBox(width: Gap.sm),
                Text('Calorie', style: tema.textTheme.titleMedium),
                const Spacer(),
                Text(
                  kcal == null ? '—' : '$kcal kcal',
                  style: tema.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: tema.colorScheme.primary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: Gap.xs),

            /*
             * ⚠️ **Si dice da dove viene il numero.** Una stima e una misura si
             * leggono allo stesso modo se nessuno dice quale delle due è, e
             * quella riga cambia quanto ci si fida — e quindi se la si corregge.
             */
            Text(
              voce.kcalCorrettaAMano
                  ? 'L\'hai corretta tu.'
                  : voce.kcalDalPolso != null
                  ? 'Misurate dall\'orologio.'
                  : 'Stima calcolata dall\'allenamento, dalla durata e dal tuo peso.',
              style: tema.textTheme.bodySmall?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: Gap.sm),

            if (_inCorso)
              const LinearProgressIndicator()
            else
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _campo,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Correggi',
                        isDense: true,
                        border: OutlineInputBorder(),
                        suffixText: 'kcal',
                      ),
                    ),
                  ),
                  const SizedBox(width: Gap.sm),
                  FilledButton(
                    onPressed: () => _salva(int.tryParse(_campo.text.trim())),
                    child: const Text('Salva'),
                  ),

                  /*
                   * 💡 **Disfare, quando c'è qualcosa da disfare.** Una
                   * correzione che non si può togliere è una trappola: chi
                   * sbaglia a digitare resterebbe con un numero falso e nessun
                   * modo di tornare alla misura.
                   */
                  if (voce.kcalCorrettaAMano)
                    IconButton(
                      tooltip: 'Torna alla stima',
                      onPressed: () {
                        _campo.clear();
                        _salva(null);
                      },
                      icon: const Icon(Icons.undo),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
