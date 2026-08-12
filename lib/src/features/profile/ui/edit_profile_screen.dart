import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/states.dart';
import '../data/profile_models.dart';
import '../profile_controller.dart';
import '../target_locale_controller.dart';
import 'widgets/manca_per_il_target.dart';
import 'widgets/meal_hours_editor.dart';

/// Modifica del profilo — C8.
///
/// 🚨 **Senza questa schermata metà app resta muta.** Senza sesso, età, altezza
/// e livello di attività non esiste BMR, quindi non esiste target calorico:
/// diario, dashboard e calendario mostrano barre senza riferimento. Fino alla
/// fase C il profilo si poteva modificare **solo dal pannello della palestra**,
/// e l'app diceva «Nessun obiettivo impostato» senza offrire il modo di
/// impostarlo.
class EditProfileScreen extends ConsumerWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilo = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('I tuoi dati')),
      body: profilo.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          error: ApiClient.unwrapError(e),
          onRetry: () => ref.invalidate(profileProvider),
        ),
        data: (p) => _Modulo(profilo: p),
      ),
    );
  }
}

class _Modulo extends ConsumerStatefulWidget {
  const _Modulo({required this.profilo});

  final UserProfile profilo;

  @override
  ConsumerState<_Modulo> createState() => _ModuloState();
}

class _ModuloState extends ConsumerState<_Modulo> {
  late String? _sesso = widget.profilo.sex;
  late DateTime? _nascita = widget.profilo.birthdate;
  late String? _attivita = widget.profilo.activityLevel;
  late String? _obiettivo = widget.profilo.goal;
  late final _altezza = TextEditingController(
    text: widget.profilo.heightCm?.toString() ?? '',
  );
  late final _pesoObiettivo = TextEditingController(
    text: widget.profilo.targetWeightKg?.toStringAsFixed(1) ?? '',
  );
  late Map<String, String> _orari = Map.of(widget.profilo.mealHours);

  bool _inCorso = false;
  String? _errore;

  @override
  void dispose() {
    _altezza.dispose();
    _pesoObiettivo.dispose();
    super.dispose();
  }

  Future<void> _salva() async {
    setState(() {
      _inCorso = true;
      _errore = null;
    });

    try {
      await ref
          .read(profileActionsProvider)
          .save(
            sex: _sesso,
            birthdate: _nascita,
            heightCm: int.tryParse(_altezza.text.trim()),
            activityLevel: _attivita,
            goal: _obiettivo,
            targetWeightKg: double.tryParse(_pesoObiettivo.text.trim().replaceAll(',', '.')),
            mealHours: _orari,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profilo salvato')),
        );
      }
    } on Object catch (error) {
      setState(() => _errore = ApiClient.unwrapError(error).message);
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profilo;
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(Gap.md),
      children: [
        /*
         * 🚨 **Non si chiede al server cosa manca** — difetto riferito il
         * 12/08/2026: *«nel profilo mi dice ancora che non ho inserito il
         * peso»*.
         *
         * Qui c'era `if (!p.isComplete) _CosaManca(profilo: p)`, e
         * `_CosaManca` guardava `profilo.missing` — che arriva **dal server**.
         * Ma `ProfileController::rappresenta()` mette `weight_kg` in `missing`
         * **SEMPRE**, e lo dichiara nel proprio commento: dopo D9-bis il peso
         * sta sul telefono, quindi il server non ce l'ha e non ce l'avrà mai.
         *
         * ⚠️ Risultato: la schermata diceva «manca il peso» **per sempre**,
         * qualunque cosa si registrasse. Non era il salvataggio a non
         * funzionare — era la domanda, fatta a chi non poteva rispondere.
         *
         * 💡 `targetLocaleProvider` risponde alla stessa domanda guardando
         * dove il peso vive davvero, ed è già l'unico punto che sa quali pezzi
         * servono per il calcolo.
         */
        const _ObiettivoCalcolato(),

        const SizedBox(height: Gap.md),
        Text('Chi sei', style: theme.textTheme.titleMedium),
        const SizedBox(height: Gap.sm),

        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'm', label: Text('Uomo')),
            ButtonSegment(value: 'f', label: Text('Donna')),
          ],
          selected: _sesso == null ? <String>{} : {_sesso!},
          emptySelectionAllowed: true,
          onSelectionChanged: (s) => setState(() => _sesso = s.isEmpty ? null : s.first),
        ),
        const SizedBox(height: Gap.md),

        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.cake_outlined),
          title: const Text('Data di nascita'),
          subtitle: Text(
            _nascita == null
                ? 'Non impostata'
                : '${DateFormat('d MMMM y', 'it').format(_nascita!)}'
                      '${p.age != null ? ' · ${p.age} anni' : ''}',
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: _scegliData,
        ),

        TextField(
          controller: _altezza,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Altezza',
            suffixText: 'cm',
            prefixIcon: Icon(Icons.height_rounded),
          ),
        ),
        const SizedBox(height: Gap.md),

        // Le tendine arrivano dal server: aggiungere un livello non richiede
        // una nuova versione dell'app sugli store.
        DropdownButtonFormField<String>(
          initialValue: p.activityLevels.containsKey(_attivita) ? _attivita : null,
          decoration: const InputDecoration(
            labelText: 'Quanto ti muovi',
            prefixIcon: Icon(Icons.directions_run_rounded),
          ),
          items: p.activityLevels.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: (v) => setState(() => _attivita = v),
        ),
        const SizedBox(height: Gap.md),

        DropdownButtonFormField<String>(
          initialValue: p.goals.containsKey(_obiettivo) ? _obiettivo : null,
          decoration: const InputDecoration(
            labelText: 'Obiettivo',
            prefixIcon: Icon(Icons.flag_outlined),
          ),
          items: p.goals.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: (v) => setState(() => _obiettivo = v),
        ),
        const SizedBox(height: Gap.md),

        TextField(
          controller: _pesoObiettivo,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Peso che vuoi raggiungere (facoltativo)',
            suffixText: 'kg',
            prefixIcon: Icon(Icons.flag_circle_outlined),
          ),
        ),

        const SizedBox(height: Gap.lg),
        Text('Orari dei pasti', style: theme.textTheme.titleMedium),
        Text(
          'Servono a mettere ogni cibo nel pasto giusto in base all\'ora.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: Gap.sm),

        MealHoursEditor(
          orari: _orari,
          onChanged: (nuovi) => setState(() => _orari = nuovi),
        ),

        if (_errore != null) ...[
          const SizedBox(height: Gap.md),
          Text(_errore!, style: TextStyle(color: theme.colorScheme.error)),
        ],

        const SizedBox(height: Gap.lg),
        FilledButton(
          onPressed: _inCorso ? null : _salva,
          child: _inCorso
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Salva'),
        ),
        const SizedBox(height: Gap.xl),
      ],
    );
  }

  Future<void> _scegliData() async {
    final oggi = DateTime.now();

    final scelta = await showDatePicker(
      context: context,
      initialDate: _nascita ?? DateTime(oggi.year - 30, oggi.month, oggi.day),
      // ⚠️ `lastDate` è ieri, non oggi: una data di nascita di oggi darebbe
      // età 0, e le formule metaboliche su un neonato non hanno senso. Il
      // server la rifiuta comunque, ma farlo scoprire al salvataggio è un giro
      // inutile.
      firstDate: DateTime(1900),
      lastDate: oggi.subtract(const Duration(days: 1)),
      locale: const Locale('it'),
    );

    if (scelta != null) setState(() => _nascita = scelta);
  }
}
/// L'obiettivo calcolato — oppure cosa manca per calcolarlo.
///
/// ── 🚨 Perché ha preso il posto di due schede ────────────────────────────
///
/// Qui c'erano `_CosaManca`, che leggeva `profilo.missing` **dal server**, e
/// `_Derivati`, che disegnava `profilo.derived` — sempre **dal server**.
///
/// ⚠️ Dopo D9-bis il server **non ha il peso**, quindi `missing` contiene
/// `weight_kg` per sempre e `derived` è `null` per sempre. Il risultato era una
/// schermata che diceva «manca il tuo peso» a chi lo aveva appena registrato, e
/// che non mostrava **mai** il fabbisogno — perché aspettava un calcolo che
/// nessuno poteva più fare.
///
/// 💡 Le due domande — «cosa manca?» e «quanto mi serve?» — hanno la stessa
/// risposta e una sola fonte: `targetLocaleProvider`, che il peso lo prende
/// dove vive, cioè **su questo telefono**.
class _ObiettivoCalcolato extends ConsumerWidget {
  const _ObiettivoCalcolato();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final esito = ref.watch(targetLocaleProvider);

    return esito.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (e) {
        final t = e.target;

        if (t == null) {
          return Card(
            color: theme.colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(Gap.md),
              child: MancaPerIlTarget(esito: e),
            ),
          );
        }

        Widget cella(String valore, String etichetta) => Expanded(
          child: Column(
            children: [
              Text(
                valore,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.primary,
                ),
              ),
              Text(
                etichetta,
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(Gap.md),
            child: Column(
              children: [
                Row(
                  children: [
                    cella('${t.kcal}', 'kcal al giorno'),
                    cella('${t.bmr.round()}', 'metabolismo basale'),
                    cella('${t.tdee.round()}', 'consumo stimato'),
                  ],
                ),
                const Divider(height: Gap.lg),
                Row(
                  children: [
                    cella('${t.macro.proteineG} g', 'proteine'),
                    cella('${t.macro.carboidratiG} g', 'carboidrati'),
                    cella('${t.macro.grassiG} g', 'grassi'),
                  ],
                ),
                const SizedBox(height: Gap.sm),

                // 💡 Da dove viene il numero: senza, sembra deciso dall'app.
                Text(
                  'Calcolato sul tuo peso più recente, con Mifflin-St Jeor.',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
