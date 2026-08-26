import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/avvertenza_nutrizionale.dart';
import '../../../core/ui/intestazione_app.dart';
import '../../../core/ui/states.dart';
import '../data/profile_models.dart';
import '../data/target_scelto.dart';
import '../livello_attivita.dart';
import '../profile_controller.dart';
import '../somma_bruciate.dart';
import '../target_locale_controller.dart';
import 'widgets/manca_per_il_target.dart';
import 'widgets/meal_hours_editor.dart';
import 'widgets/weight_sheet.dart';

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
      appBar: const IntestazioneApp(titolo: 'I tuoi dati'),
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
  late final String? _attivita = widget.profilo.activityLevel;
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
            /*
             * ⚠️ **Rimandato indietro com'era, e non più modificabile qui.**
             * Da 3b-G il livello vive sul telefono (`livelloAttivitaScelto`),
             * come il peso: 📌 *«tanto i calcoli li facciamo lì»*.
             *
             * 🚨 Si continua a spedirlo per **non cancellare** quello che c'è
             * già sul server: è ormai un dato inerte — nessuno lo legge più per
             * calcolare — ma buttarlo via non è compito di un salvataggio del
             * profilo. Sparirà con la migration che toglie la colonna.
             */
            activityLevel: _attivita,
            goal: _obiettivo,
            targetWeightKg: double.tryParse(
              _pesoObiettivo.text.trim().replaceAll(',', '.'),
            ),
            mealHours: _orari,
          );

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profilo salvato')));
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
          onSelectionChanged: (s) =>
              setState(() => _sesso = s.isEmpty ? null : s.first),
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

        /*
         * ══ ⚖️ NON E' PIU' UNA TENDINA — 3b-G.1, 26/08/2026 ═══════════════
         *
         * 📌 *«Livello di attività deve diventare un bottone che rimanda a una
         * pagina con le descrizioni di entrambi i modelli di misura»*.
         *
         * ⛔ La tendina offriva nove voci senza modo di capire che le prime
         * cinque e le ultime quattro rispondono a **due domande diverse** — e
         * sceglierne una dell'elenco sbagliato voleva dire contare gli
         * allenamenti due volte, o non contarli affatto.
         */
        const _BottoneModello(),
        const SizedBox(height: Gap.md),

        TendinaProfilo(
          etichetta: 'Obiettivo',
          icona: Icons.flag_outlined,
          voci: p.goals,
          scelta: _obiettivo,
          onCambio: (v) => setState(() => _obiettivo = v),
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

        /*
         * ══ ⚖️ LA PESATA STA QUI — 3b-P.2.4, 22/08/2026 ═══════════════════
         *
         * 📌 Il committente: *«Uniamoci dentro anche la pagina di
         * registrazione del peso (non ha senso che sia una pagina a parte)»*.
         *
         * 💡 **Ed è la casa giusta**: il peso è l'unico dato del profilo che
         * cambia da solo, e stava in una riga separata due schede più giù —
         * lontano da altezza, età e obiettivo, che sono la stessa domanda.
         *
         * ⛔ **Si riusa `WeightSheet`, non se ne scrive una copia**: la stessa
         * modale la aprono la scheda «Oggi» e questa pagina. Due moduli per
         * salvare la stessa cosa divergono al primo campo aggiunto — ed è
         * successo già una volta in questo progetto, con le due schede del
         * peso.
         */
        const SizedBox(height: Gap.lg),
        Text('Il tuo peso', style: theme.textTheme.titleMedium),
        Text(
          'Serve al fabbisogno e alla stima dei progressi.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: Gap.sm),

        const _RegistraPeso(),

        /*
         * ══ 🔥 L'INTERRUTTORE DELLE BRUCIATE — 3b-P.2.3 ═══════════════════
         *
         * 📌 *«Ci voglio un toggle per decidere se le calorie bruciate si
         * sommano all'obbiettivo calorico o no (default sì)»*.
         *
         * ⚠️ **Sta qui e non nelle impostazioni** perché cambia *questo*
         * numero: l'obiettivo calorico che si vede due dita più su. Un
         * interruttore che modifica un valore, messo in un'altra pagina, è un
         * effetto senza causa visibile.
         */
        const SizedBox(height: Gap.lg),
        const _SommaLeBruciate(),

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
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
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
                  t.aMano
                      ? 'Questi valori li hai scelti tu.'
                      : 'Calcolato sul tuo peso più recente, con Mifflin-St Jeor.',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),

                /*
                 * 🚨 **La stima resta visibile accanto alla scelta** — N18.2.
                 *
                 * ⚠️ Nasconderla trasformerebbe una scelta informata in una a
                 * caso. Ed è anche l'unico modo di accorgersi di uno zero di
                 * troppo: «la stima diceva 2.100» accanto a un 210 scritto per
                 * sbaglio salta all'occhio.
                 */
                if (t.aMano)
                  Text(
                    'La stima diceva ${t.kcalStimato} kcal.',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),

                const SizedBox(height: Gap.sm),

                // 🚨 N17.2 — accanto al numero, ogni volta che il numero si vede.
                const AvvertenzaNutrizionale(compatta: true),

                const SizedBox(height: Gap.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: () => _CambiaObiettivo.mostra(context, ref, t),
                      icon: const Icon(Icons.tune_rounded, size: 18),
                      label: const Text('Cambia i valori'),
                    ),
                    // 💡 N18.3 — «torna alla stima» in un tocco. Senza, chi ha
                    // provato a cambiare resterebbe legato alla propria scelta,
                    // o dovrebbe ricopiare i numeri a mano — cioè sbagliarli.
                    if (t.aMano)
                      TextButton(
                        onPressed: () async {
                          await TargetScelto.dimentica();
                          ref.invalidate(targetLocaleProvider);
                        },
                        child: const Text('Torna alla stima'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Una tendina che **non sfora** quando l'etichetta è lunga.
///
/// ── 🚨 Il difetto, riferito il 13/08/2026 ────────────────────────────────
///
/// *«Il livello sedentario va in overflow nel campo dove appare.»*
///
/// Portando i livelli di attività a cinque, le etichette sono diventate
/// esplicite — «Sedentario (lavoro da fermo, niente allenamenti)» invece di
/// «Sedentario» — perché tre parole in più valgono più di una tendina che
/// costringe a indovinare cosa significhi «moderato». ⚠️ Ma un
/// `DropdownButtonFormField` **non manda a capo e non accorcia**: disegna il
/// testo alla sua larghezza naturale e lascia che sbordi dal campo.
///
/// ── Le due mosse, e perché servono entrambe ──────────────────────────────
///
/// 1. **`isExpanded: true`** — senza, la tendina si dimensiona sul contenuto
///    invece che sul campo, ed è da lì che nasce lo sforo.
/// 2. **`selectedItemBuilder`** — 🚨 è quello che salva l'informazione. Con il
///    solo `isExpanded` il testo verrebbe **troncato con i puntini**, e
///    «Sedentario (lavoro da fer…» è brutto ma soprattutto inutile. Così invece
///    il campo chiuso mostra la parte **prima della parentesi** — cioè il nome
///    del livello, intero — e la spiegazione resta per intero nel menu aperto,
///    che è l'unico momento in cui serve davvero: quando si sta scegliendo.
///
/// 💡 Nel menu le voci possono andare a capo su due righe: lì lo spazio c'è, e
/// la frase intera è il motivo per cui è stata scritta.
///
/// ⚠️ **È pubblica solo perché il test la raggiunga.** Un overflow non lo prende
/// nessun test sui modelli — il dato è giusto ed è il disegno a rompersi —
/// quindi serve un widget test, e un widget test non vede le classi private.
class TendinaProfilo extends StatelessWidget {
  const TendinaProfilo({
    required this.etichetta,
    required this.icona,
    required this.voci,
    required this.scelta,
    required this.onCambio,
    super.key,
  });

  final String etichetta;
  final IconData icona;
  final Map<String, String> voci;
  final String? scelta;
  final ValueChanged<String?> onCambio;

  /// La parte prima della parentesi: «Sedentario (lavoro da fermo)» → «Sedentario».
  ///
  /// ⚠️ Se la parentesi non c'è si restituisce tutto: le etichette degli
  /// obiettivi non ce l'hanno, e questa tendina serve anche a loro.
  static String _breve(String completa) {
    final i = completa.indexOf(' (');

    return i == -1 ? completa : completa.substring(0, i);
  }

  @override
  Widget build(BuildContext context) {
    final valido = voci.containsKey(scelta) ? scelta : null;

    return DropdownButtonFormField<String>(
      initialValue: valido,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: etichetta,
        prefixIcon: Icon(icona),
      ),
      selectedItemBuilder: (context) => voci.values
          .map(
            (v) => Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _breve(v),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      items: voci.entries
          .map(
            (e) => DropdownMenuItem(
              value: e.key,
              child: Text(
                e.value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: onCambio,
    );
  }
}

/// Cambiare a mano calorie e macro — N18.1.
///
/// ── ⚠️ Un valore fuori scala si COMMENTA, non si blocca ──────────────────
///
/// Impedire di scrivere 900 kcal sarebbe un giudizio clinico — cioè esattamente
/// la cosa da cui l'avvertenza di N17 ci sta togliendo. E ci sono ragioni
/// legittime per numeri insoliti: un piano fatto da un professionista, una
/// condizione particolare, un periodo specifico.
///
/// 💡 Quello che si può fare è **dirlo**: un numero molto lontano dalla stima
/// merita una riga che lo faccia notare, non un divieto.
class _CambiaObiettivo extends StatefulWidget {
  const _CambiaObiettivo(this.attuale);

  final TargetLocale attuale;

  static Future<void> mostra(
    BuildContext context,
    WidgetRef ref,
    TargetLocale attuale,
  ) async {
    final scelto = await showDialog<TargetScelto>(
      context: context,
      builder: (_) => _CambiaObiettivo(attuale),
    );

    if (scelto == null) return;

    await scelto.salva();
    ref.invalidate(targetLocaleProvider);
  }

  @override
  State<_CambiaObiettivo> createState() => _CambiaObiettivoState();
}

class _CambiaObiettivoState extends State<_CambiaObiettivo> {
  late final _kcal = TextEditingController(text: '${widget.attuale.kcal}');
  late final _pro = TextEditingController(
    text: '${widget.attuale.macro.proteineG}',
  );
  late final _car = TextEditingController(
    text: '${widget.attuale.macro.carboidratiG}',
  );
  late final _gra = TextEditingController(
    text: '${widget.attuale.macro.grassiG}',
  );

  @override
  void dispose() {
    for (final c in [_kcal, _pro, _car, _gra]) {
      c.dispose();
    }

    super.dispose();
  }

  int? get _kcalScritte => int.tryParse(_kcal.text.trim());

  /// 💡 Quanto ci si allontana dalla stima, per poterlo dire.
  bool get _lontano {
    final k = _kcalScritte;

    if (k == null || widget.attuale.kcalStimato == 0) return false;

    final scarto =
        (k - widget.attuale.kcalStimato).abs() / widget.attuale.kcalStimato;

    return scarto > 0.35;
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    Widget campo(TextEditingController c, String etichetta) => Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: TextField(
        controller: c,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: etichetta),
        onChanged: (_) => setState(() {}),
      ),
    );

    return AlertDialog(
      title: const Text('I tuoi valori'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'La stima dice ${widget.attuale.kcalStimato} kcal, '
              '${widget.attuale.macroStimato.proteineG} g di proteine, '
              '${widget.attuale.macroStimato.carboidratiG} g di carboidrati e '
              '${widget.attuale.macroStimato.grassiG} g di grassi.',
              style: tema.textTheme.bodySmall,
            ),
            const SizedBox(height: Gap.md),
            campo(_kcal, 'kcal al giorno'),
            campo(_pro, 'proteine (g)'),
            campo(_car, 'carboidrati (g)'),
            campo(_gra, 'grassi (g)'),
            if (_lontano)
              Padding(
                padding: const EdgeInsets.only(top: Gap.sm),
                child: Text(
                  'È parecchio distante dalla stima. Se è quello che ti ha '
                  'indicato un professionista va benissimo; se l\'hai scritto '
                  'per sbaglio, controlla.',
                  style: tema.textTheme.labelSmall?.copyWith(
                    color: tema.colorScheme.error,
                  ),
                ),
              ),
            const SizedBox(height: Gap.md),
            const AvvertenzaNutrizionale(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        FilledButton(
          // ⚠️ Si salva solo se i quattro numeri ci sono: metà obiettivo
          // sarebbe peggio di nessun obiettivo.
          onPressed: _valido ? _salva : null,
          child: const Text('Usa questi'),
        ),
      ],
    );
  }

  bool get _valido => [_kcal, _pro, _car, _gra].every((c) {
    final n = int.tryParse(c.text.trim());

    return n != null && n >= 0;
  });

  void _salva() => Navigator.of(context).pop(
    TargetScelto(
      kcal: int.parse(_kcal.text.trim()),
      proteineG: int.parse(_pro.text.trim()),
      carboidratiG: int.parse(_car.text.trim()),
      grassiG: int.parse(_gra.text.trim()),
    ),
  );
}

/// La pesata, dentro «I tuoi dati» — 3b-P.2.4.
///
/// 💡 Mostra l'ultimo peso conosciuto e apre la stessa modale di «Oggi». ⛔ Non
/// e' un campo di testo in piu' nel modulo: il peso **non si salva con
/// «Salva»**, si registra con una data sua, e mescolarlo agli altri campi
/// farebbe credere che si perda annullando.
class _RegistraPeso extends ConsumerWidget {
  const _RegistraPeso();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    /*
     * 🚨 **La stessa fonte della riga che sostituisce**: `weightHistoryProvider`,
     * non il peso dentro il profilo. ⚠️ Sono due numeri che di solito
     * coincidono e non sempre — il profilo si aggiorna al salvataggio, lo
     * storico a ogni pesata — e prendere quello sbagliato qui avrebbe mostrato
     * un peso vecchio accanto al pulsante per cambiarlo.
     */
    final storico = ref.watch(weightHistoryProvider).valueOrNull;
    final peso = (storico == null || storico.isEmpty)
        ? null
        : storico.last.weightKg;

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: const Icon(Icons.monitor_weight_outlined),
        title: Text(
          peso == null ? 'Nessuna pesata' : '${peso.toStringAsFixed(1)} kg',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          peso == null
              ? 'Registrane una per avere il fabbisogno'
              : 'Tocca per registrarne una nuova',
        ),
        trailing: const Icon(Icons.add_rounded),
        onTap: () => WeightSheet.mostra(context, iniziale: peso),
      ),
    );
  }
}

/// Il bottone che porta ai due modelli di calcolo — 3b-G.1, 26/08/2026.
///
/// ══ 🚨 MOSTRA LA SCELTA, NON SOLO LA STRADA ═══════════════════════════════
///
/// ⛔ Un bottone che dicesse solo «Livello di attività ›» costringerebbe ad
/// aprirlo per sapere cosa c'è dentro. 💡 Qui si legge il gradino in uso **e**
/// il modello a cui appartiene, che è l'informazione che cambia il significato
/// di tutti i numeri di «Oggi».
///
/// ⚠️ **E dice quando la domanda non è ancora stata fatta.** Chi ha un livello
/// ereditato dal server (`moderate`, …) ce l'ha, ma non ha mai scelto con quale
/// modello vuole che l'app conti: il richiamo resta finché non risponde, e
/// intanto **niente cambia da solo**.
class _BottoneModello extends ConsumerWidget {
  const _BottoneModello();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final livello = ref.watch(livelloAttivitaProvider);
    final modello = ref.watch(modelloCalorieProvider);
    final daScegliere = ref.watch(deveScegliereIlModelloProvider);

    final gradino = modello?.livello(livello);

    return Card(
      margin: EdgeInsets.zero,
      color: daScegliere ? tema.colorScheme.secondaryContainer : null,
      child: ListTile(
        leading: const Icon(Icons.directions_run_rounded),
        title: const Text('Quanto ti muovi'),
        subtitle: Text(switch ((daScegliere, gradino)) {
          (true, final g?) =>
            '${g.etichetta} — ma non hai ancora scelto come contare '
                'gli allenamenti. Tocca per decidere.',
          (true, null) => 'Da scegliere: senza, non c\'è un obiettivo.',
          (false, final g?) => '${g.etichetta} · ${modello!.titolo}',
          (false, null) => 'Da scegliere: senza, non c\'è un obiettivo.',
        }, style: tema.textTheme.bodySmall),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => context.push(AppRoutes.modelloCalorie),
      ),
    );
  }
}

/// Se le calorie bruciate si sommano all'obiettivo — 3b-P.2.3.
///
/// 🚨 **La spiegazione non e' facoltativa.** Un interruttore che dice solo
/// *«somma le calorie bruciate»* lascia indovinare cosa succede spegnendolo, e
/// chi indovina male scopre l'effetto giorni dopo, su un numero che nel
/// frattempo ha usato per decidere cosa mangiare.
class _SommaLeBruciate extends ConsumerWidget {
  const _SommaLeBruciate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final somma = ref.watch(sommaLeBruciateProvider);

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: const Icon(Icons.local_fire_department_outlined),
        title: Text(
          somma
              ? 'Gli allenamenti si sommano all\'obiettivo'
              : 'Gli allenamenti non alzano l\'obiettivo',
        ),
        subtitle: Text(
          somma
              ? 'Ti muovi di piu\', puoi mangiare di piu\': l\'obiettivo '
                    'cresce con le calorie che bruci.'
              : 'Sono gia\' compresi nel fattore del tuo livello di '
                    'attivita\': sommarli li conterebbe due volte.',
          style: theme.textTheme.bodySmall,
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => context.push(AppRoutes.modelloCalorie),
      ),
    );
  }
}
