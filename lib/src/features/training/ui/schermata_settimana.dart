import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/ui/intestazione_app.dart';
import '../../acquisti/ui/modale_acquisti.dart';
import '../data/settimana_programmata.dart';
import '../settimana_controller.dart';
import '../training_controller.dart';

/// La settimana programmata — 3b-I.B, 27/08/2026.
///
/// ══ 📌 COS'E' ═════════════════════════════════════════════════════════════
///
/// 📌 *«2 si può fare. Addirittura si può fare in automatico, vede i gruppi
/// muscolari delle schede e li divide per la settimana (l'utente decide quanti
/// giorni)»*.
///
/// ══ 🔒 E' PREMIUM, MA SI VEDE TUTTA ══════════════════════════════════════
///
/// 📌 *«i tasti per fare quella cosa ci devono essere e si deve capire che sono
/// bloccati dietro un abbonamento»*.
///
/// ⛔ Quindi la schermata **non è chiusa**: si apre, si legge, si capisce cosa
/// farebbe. Sono i **gesti** a essere bloccati, e toccarli porta alla modale.
/// 🚨 Un'attività premium invisibile non converte nessuno: la scopre solo chi è
/// già abbonato, cioè chi non serve convincere.
class SchermataSettimana extends ConsumerStatefulWidget {
  const SchermataSettimana({super.key});

  @override
  ConsumerState<SchermataSettimana> createState() => _SchermataSettimanaState();
}

class _SchermataSettimanaState extends ConsumerState<SchermataSettimana> {
  /// Quante volte a settimana. 💡 Tre è il numero più comune, ed è un punto di
  /// partenza migliore di uno.
  int _quantiGiorni = 3;

  /// Le schede scelte, **nell'ordine in cui sono state toccate**.
  ///
  /// 🚨 L'ordine conta: a pari merito la distribuzione lo rispetta, ed è l'unico
  /// modo di essere deterministici senza sembrare arbitrari.
  final _scelte = <int>[];

  bool _inizializzato = false;

  /// Riempie la scelta con quello che c'è già in settimana, una volta sola.
  void _preselezione(List<int?> settimana) {
    if (_inizializzato) return;

    _inizializzato = true;

    final dentro = settimana.whereType<int>().toSet();

    if (dentro.isEmpty) return;

    _scelte.addAll(dentro);
    _quantiGiorni = settimana.whereType<int>().length;
  }

  Future<void> _distribuisci() async {
    final proposta = await proponiLaSettimana(
      ref,
      schede: _scelte,
      quantiGiorni: _quantiGiorni,
    );

    await salvaLaSettimana(ref, proposta);
  }

  void _bloccato() => ModaleAcquisti.mostra(context);

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final puo = ref.watch(puoProgrammareProvider);
    final schede = ref.watch(schedeUniteProvider).valueOrNull ?? const [];
    final settimana = ref.watch(settimanaProvider).valueOrNull;

    if (settimana != null) _preselezione(settimana);

    final nomi = {for (final s in schede) s.id: s.name};

    return Scaffold(
      appBar: const IntestazioneApp(titolo: 'La tua settimana'),
      body: ListView(
        padding: const EdgeInsets.all(Gap.md),
        children: [
          if (!puo) ...[const _Lucchetto(), const SizedBox(height: Gap.md)],

          Text(
            'Dì quante volte a settimana ti alleni e quali schede vuoi usare: '
            'le dispongo allontanando quelle che pesano sugli stessi muscoli.',
            style: tema.textTheme.bodyMedium,
          ),
          const SizedBox(height: Gap.lg),

          Text('Quante volte a settimana', style: tema.textTheme.titleSmall),
          const SizedBox(height: Gap.sm),
          Wrap(
            spacing: Gap.sm,
            children: [
              for (var n = 1; n <= giorniDellaSettimana; n++)
                ChoiceChip(
                  label: Text('$n'),
                  selected: _quantiGiorni == n,
                  onSelected: (_) =>
                      puo ? setState(() => _quantiGiorni = n) : _bloccato(),
                ),
            ],
          ),
          const SizedBox(height: Gap.lg),

          Text('Quali schede', style: tema.textTheme.titleSmall),
          const SizedBox(height: Gap.sm),

          if (schede.isEmpty)
            Text(
              'Non hai ancora nessuna scheda sul telefono.',
              style: tema.textTheme.bodySmall,
            )
          else
            Wrap(
              spacing: Gap.sm,
              runSpacing: Gap.xs,
              children: [
                for (final s in schede)
                  FilterChip(
                    label: Text(s.name),
                    selected: _scelte.contains(s.id),
                    onSelected: (dentro) {
                      if (!puo) {
                        _bloccato();

                        return;
                      }

                      setState(() {
                        // ⚠️ Si aggiunge in **coda**: l'ordine di selezione è
                        // quello che la distribuzione rispetta a pari merito.
                        dentro ? _scelte.add(s.id) : _scelte.remove(s.id);
                      });
                    },
                  ),
              ],
            ),

          const SizedBox(height: Gap.lg),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: !puo
                  ? _bloccato
                  : _scelte.isEmpty
                  ? null
                  : _distribuisci,
              icon: Icon(puo ? Icons.auto_awesome_rounded : Icons.lock_rounded),
              label: const Text('Distribuisci'),
            ),
          ),

          const SizedBox(height: Gap.lg),
          const Divider(),
          const SizedBox(height: Gap.md),

          Text('La settimana', style: tema.textTheme.titleSmall),
          const SizedBox(height: Gap.sm),

          if (settimana == null)
            const Center(child: CircularProgressIndicator())
          else
            for (var i = 0; i < giorniDellaSettimana; i++)
              _Giorno(
                nome: _nomiDeiGiorni[i],
                scheda: settimana[i],
                nomi: nomi,
                bloccata: !puo,
                onTap: () async {
                  if (!puo) {
                    _bloccato();

                    return;
                  }

                  final scelta = await _scegliScheda(context, schede, nomi);

                  if (scelta == null) return;

                  final nuova = [...settimana];

                  // 💡 `-1` è il valore che il foglio usa per «riposo»: `null`
                  // non si distingue da «ha chiuso senza scegliere».
                  nuova[i] = scelta == -1 ? null : scelta;

                  await salvaLaSettimana(ref, nuova);
                },
              ),

          const SizedBox(height: Gap.xl),
        ],
      ),
    );
  }
}

const _nomiDeiGiorni = [
  'Lunedì',
  'Martedì',
  'Mercoledì',
  'Giovedì',
  'Venerdì',
  'Sabato',
  'Domenica',
];

/// Il foglio per cambiare il giorno. `-1` = riposo, `null` = ha chiuso.
Future<int?> _scegliScheda(
  BuildContext context,
  List<dynamic> schede,
  Map<int, String> nomi,
) => showModalBottomSheet<int>(
  context: context,
  showDragHandle: true,
  builder: (_) => SafeArea(
    child: ListView(
      shrinkWrap: true,
      children: [
        ListTile(
          leading: const Icon(Icons.bedtime_outlined),
          title: const Text('Riposo'),
          onTap: () => Navigator.of(context).pop(-1),
        ),
        const Divider(height: 1),
        for (final voce in nomi.entries)
          ListTile(
            leading: const Icon(Icons.fitness_center_rounded),
            title: Text(voce.value),
            onTap: () => Navigator.of(context).pop(voce.key),
          ),
      ],
    ),
  ),
);

class _Giorno extends StatelessWidget {
  const _Giorno({
    required this.nome,
    required this.scheda,
    required this.nomi,
    required this.bloccata,
    required this.onTap,
  });

  final String nome;
  final int? scheda;
  final Map<int, String> nomi;
  final bool bloccata;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    /*
     * 🚨 **Una scheda cancellata lascia il giorno pieno e lo dice.** ⛔ Se
     * tornasse «riposo» l'app direbbe che quel giorno non ti alleni, invece di
     * dire che la scheda che avevi messo non c'è più — due cose diverse, e la
     * seconda si corregge.
     */
    final sparita = scheda != null && !nomi.containsKey(scheda);

    return Card(
      margin: const EdgeInsets.only(bottom: Gap.xs),
      child: ListTile(
        onTap: onTap,
        leading: Text(
          nome.substring(0, 3).toUpperCase(),
          style: tema.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: tema.colorScheme.onSurfaceVariant,
          ),
        ),
        title: Text(
          sparita ? 'La scheda non c\'è più' : nomi[scheda] ?? 'Riposo',
          style: tema.textTheme.bodyMedium?.copyWith(
            color: sparita
                ? tema.colorScheme.error
                : scheda == null
                ? tema.colorScheme.onSurfaceVariant
                : null,
            fontWeight: scheda != null ? FontWeight.w600 : null,
          ),
        ),
        trailing: Icon(
          bloccata ? Icons.lock_outline_rounded : Icons.chevron_right_rounded,
          size: 18,
          color: bloccata ? tema.colorScheme.error : null,
        ),
      ),
    );
  }
}

/// Il cartello per chi non è abbonato.
///
/// ⛔ **Non nasconde niente**: sta in cima e spiega, e sotto la schermata resta
/// leggibile per intero. 💡 È il ponte: senza, questa funzione la scoprirebbe
/// solo chi è già abbonato.
class _Lucchetto extends StatelessWidget {
  const _Lucchetto();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: tema.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(Gap.radius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lock_rounded,
            color: tema.colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Serve l\'abbonamento',
                  style: tema.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: tema.colorScheme.onSecondaryContainer,
                  ),
                ),
                Text(
                  'Puoi guardarla, ma per programmare la settimana serve '
                  'l\'abbonamento. Tocca qualsiasi cosa per attivarlo.',
                  style: tema.textTheme.bodySmall?.copyWith(
                    color: tema.colorScheme.onSecondaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
