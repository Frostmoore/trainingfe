import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/errors/api_exception.dart';
import '../../../../core/media/photo_picker.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../privacy/consensi_controller.dart';
import '../../diary_controller.dart';

/// I tre modi di aggiungere qualcosa al diario — A4.2 / A4.3 / A4.4.
///
/// 🚨 **L'ordine delle schede non è casuale.** Il testo è primo perché è il
/// modo più veloce e quello che si usa dieci volte al giorno; il manuale è
/// ultimo perché è quello che nessuno vuole usare — ma deve esserci, perché è
/// l'unico che funziona quando la quota AI è finita o il servizio è giù.
class AddFoodSheet extends ConsumerStatefulWidget {
  const AddFoodSheet({required this.meal, super.key});

  final String meal;

  static Future<void> show(BuildContext context, {String? meal}) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => AddFoodSheet(meal: meal ?? _pastoDaOra()),
  );

  /// Il pasto plausibile a quest'ora: chiederlo ogni volta è attrito, e le
  /// stesse soglie le usa il backend quando l'app non lo manda.
  static String _pastoDaOra() {
    final h = DateTime.now().hour;

    return switch (h) {
      < 10 => 'breakfast',
      < 12 => 'morning_snack',
      < 15 => 'lunch',
      < 18 => 'afternoon_snack',
      < 22 => 'dinner',
      _ => 'evening_snack',
    };
  }

  @override
  ConsumerState<AddFoodSheet> createState() => _AddFoodSheetState();
}

class _AddFoodSheetState extends ConsumerState<AddFoodSheet> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  final _testo = TextEditingController();
  final _descrizione = TextEditingController();
  final _quantita = TextEditingController();
  final _kcal = TextEditingController();

  String _unita = 'g';
  bool _inCorso = false;
  String? _errore;

  /// Le unità sono le stesse di `FoodUnit` lato backend, nello stesso ordine:
  /// un elenco diverso qui produrrebbe unità che il server non sa convertire.
  static const _unitaAmmesse = [
    'g', 'kg', 'ml', 'l', 'cucchiaio', 'cucchiaino', 'bicchiere', 'tazza', 'scoop',
  ];

  @override
  void dispose() {
    _tabs.dispose();
    _testo.dispose();
    _descrizione.dispose();
    _quantita.dispose();
    _kcal.dispose();
    super.dispose();
  }

  Future<void> _esegui(Future<void> Function() azione) async {
    setState(() {
      _inCorso = true;
      _errore = null;
    });

    try {
      await azione();

      if (mounted) Navigator.of(context).pop();
    } on Object catch (error) {
      final tradotto = ApiClient.unwrapError(error);

      setState(() {
        // 🚨 La quota finita ha un messaggio suo e **non invita a riprovare**:
        // non si sblocca fino al mese prossimo, e un «riprova» qui farebbe
        // martellare l'utente contro un muro.
        _errore = switch (tradotto) {
          AiQuotaExceededException() =>
            '${tradotto.message}\nPuoi comunque inserire a mano.',
          RateLimitedException() => 'Il servizio è occupato. Riprova fra poco.',
          _ => tradotto.message,
        };
      });
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  /// 🔒 L'AI si può usare? — S9 / difetto trovato provando l'app il 12/08.
  ///
  /// ── 🚨 Il server rifiutava già, l'app continuava a offrirla ────────────
  ///
  /// Le rotte `ai/food/*` hanno il middleware `ai.consent` e rispondono **403**
  /// senza consenso: da quel lato non è mai uscito niente verso Anthropic. Ma
  /// l'app mostrava lo stesso le schede «Scrivi» e «Foto», e chi aveva revocato
  /// il consenso le trovava lì, apparentemente funzionanti, per scoprire solo
  /// **dopo aver scritto** che non andavano.
  ///
  /// ⚠️ **Non basta che il server dica di no.** Un'interfaccia che offre una
  /// cosa vietata non è un problema di sicurezza — è un problema di fiducia:
  /// chi ha appena revocato un consenso e ritrova il pulsante pensa che la
  /// revoca non abbia funzionato.
  ///
  /// 💡 **Si spiega invece di nascondere.** Togliere le schede farebbe credere
  /// che la funzione non esista; così si vede che c'è, perché non è
  /// disponibile, e come riattivarla.
  ///
  /// 🚨 In dubbio si risponde **`false`** — errore di rete compreso: come per
  /// il consenso sanitario, non poter verificare vale quanto un no.
  bool _aiPermessa(AsyncValue<Consensi> consensi) =>
      consensi.valueOrNull?.aiDato ?? false;

  @override
  Widget build(BuildContext context) {
    final azioni = ref.read(diaryActionsProvider);
    final consensi = ref.watch(consensiProvider);
    final aiOk = _aiPermessa(consensi);

    /*
     * ⚠️ Se l'AI non c'è, si parte da «A mano» invece che dalla scheda
     * bloccata: aprire il foglio su un pannello che dice «non puoi» sarebbe
     * corretto e inutile — quello che la persona vuole fare è comunque
     * registrare quel che ha mangiato.
     */
    if (!aiOk && !consensi.isLoading && _tabs.index < 2) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _tabs.index < 2) _tabs.animateTo(2);
      });
    }

    return Padding(
      // Alza il foglio sopra la tastiera: senza, il campo su cui si scrive
      // finisce coperto e non si vede cosa si digita.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TabBar(
            controller: _tabs,
            tabs: const [
              Tab(icon: Icon(Icons.auto_awesome_outlined), text: 'Scrivi'),
              Tab(icon: Icon(Icons.photo_camera_outlined), text: 'Foto'),
              Tab(icon: Icon(Icons.edit_outlined), text: 'A mano'),
            ],
          ),

          if (_errore != null)
            Padding(
              padding: const EdgeInsets.all(Gap.md),
              child: Text(
                _errore!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),

          SizedBox(
            height: 320,
            child: TabBarView(
              controller: _tabs,
              children: [
                if (consensi.isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (!aiOk)
                  const _SenzaConsensoAi()
                else
                  _Testo(
                    controller: _testo,
                    inCorso: _inCorso,
                    onInvia: () => _esegui(() => azioni.addFromText(_testo.text, widget.meal)),
                  ),

                if (consensi.isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (!aiOk)
                  const _SenzaConsensoAi()
                else
                  _Foto(
                    inCorso: _inCorso,
                    onScelta: (path) => _esegui(() => azioni.addFromPhoto(path, widget.meal)),
                  ),
                _Manuale(
                  descrizione: _descrizione,
                  quantita: _quantita,
                  kcal: _kcal,
                  unita: _unita,
                  unitaAmmesse: _unitaAmmesse,
                  inCorso: _inCorso,
                  onUnita: (u) => setState(() => _unita = u),
                  onSalva: () => _esegui(
                    () => azioni.addManual(
                      description: _descrizione.text,
                      meal: widget.meal,
                      qty: double.tryParse(_quantita.text.replaceAll(',', '.')),
                      unit: _unita,
                      kcal: double.tryParse(_kcal.text.replaceAll(',', '.')),
                    ),
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

/// Il pannello che prende il posto delle schede AI quando manca il consenso.
///
/// 🚨 **Spiega invece di sparire.** Togliere le schede farebbe credere che la
/// funzione non esista; così si vede che c'è, **perché** non è disponibile, e
/// come riattivarla — che è l'unica cosa che la persona può fare.
///
/// ⚠️ Il pulsante porta ai consensi e **non** accende niente da qui: il
/// consenso si concede dalla schermata che lo spiega, non da un foglio in cui
/// si stava facendo altro. Un consenso raccolto di sfuggita non è «informato».
class _SenzaConsensoAi extends StatelessWidget {
  const _SenzaConsensoAi();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(Gap.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.privacy_tip_outlined,
            size: 40,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: Gap.md),
          Text(
            'Serve il tuo consenso',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: Gap.sm),
          Text(
            'Per stimare un pasto da una frase o da una foto, il testo o '
            'l\'immagine devono uscire da qui e raggiungere il fornitore '
            'dell\'AI. Senza il tuo consenso non parte niente.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: Gap.md),
          FilledButton.tonalIcon(
            onPressed: () {
              Navigator.of(context).pop();
              context.push(AppRoutes.consensi);
            },
            icon: const Icon(Icons.tune_rounded),
            label: const Text('Privacy e consensi'),
          ),
          const SizedBox(height: Gap.sm),
          Text(
            'Nel frattempo puoi inserire a mano.',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}

class _Testo extends StatelessWidget {
  const _Testo({required this.controller, required this.inCorso, required this.onInvia});

  final TextEditingController controller;
  final bool inCorso;
  final VoidCallback onInvia;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(Gap.md),
    child: Column(
      children: [
        TextField(
          controller: controller,
          maxLines: 3,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Un piatto di pasta al pomodoro e due fette di pane',
            helperText: 'Scrivi come parleresti: le quantità le stima lui.',
          ),
        ),
        const Spacer(),
        FilledButton.icon(
          style: bottonePieno(),
          onPressed: inCorso ? null : onInvia,
          icon: inCorso
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.auto_awesome),
          label: const Text('Riconosci e aggiungi'),
        ),
      ],
    ),
  );
}

class _Foto extends StatelessWidget {
  const _Foto({required this.inCorso, required this.onScelta});

  final bool inCorso;
  final ValueChanged<String> onScelta;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(Gap.md),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (inCorso)
          const CircularProgressIndicator()
        else ...[
          FilledButton.icon(
            style: bottonePieno(),
            onPressed: () async {
              final path = await PhotoPicker.dallaFotocamera();

              if (path != null) onScelta(path);
            },
            icon: const Icon(Icons.photo_camera_rounded),
            label: const Text('Scatta una foto'),
          ),
          const SizedBox(height: Gap.md),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: () async {
              final path = await PhotoPicker.dallaGalleria();

              if (path != null) onScelta(path);
            },
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Scegli dalla galleria'),
          ),
          const SizedBox(height: Gap.md),
          Text(
            'Inquadra il piatto dall\'alto: le porzioni si stimano meglio.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    ),
  );
}

class _Manuale extends StatelessWidget {
  const _Manuale({
    required this.descrizione,
    required this.quantita,
    required this.kcal,
    required this.unita,
    required this.unitaAmmesse,
    required this.inCorso,
    required this.onUnita,
    required this.onSalva,
  });

  final TextEditingController descrizione, quantita, kcal;
  final String unita;
  final List<String> unitaAmmesse;
  final bool inCorso;
  final ValueChanged<String> onUnita;
  final VoidCallback onSalva;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(Gap.md),
    child: Column(
      children: [
        TextField(
          controller: descrizione,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Cosa hai mangiato'),
        ),
        const SizedBox(height: Gap.md),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: quantita,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Quantità'),
              ),
            ),
            const SizedBox(width: Gap.sm),
            Expanded(
              flex: 3,
              child: DropdownButtonFormField<String>(
                initialValue: unita,
                decoration: const InputDecoration(labelText: 'Unità'),
                items: [
                  for (final u in unitaAmmesse) DropdownMenuItem(value: u, child: Text(u)),
                ],
                onChanged: (v) => v != null ? onUnita(v) : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: Gap.md),
        TextField(
          controller: kcal,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Calorie',
            helperText: 'Se non le sai, lascia vuoto.',
          ),
        ),
        const SizedBox(height: Gap.lg),
        FilledButton(
          style: bottonePieno(),
          onPressed: inCorso ? null : onSalva,
          child: const Text('Aggiungi'),
        ),
      ],
    ),
  );
}
