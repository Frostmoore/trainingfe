import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/errors/api_exception.dart';
import '../../../../core/media/photo_picker.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/auth_controller.dart';
import '../../../nutrition/data/piano_alimentare.dart';
import '../../../privacy/consensi_controller.dart';
import '../../data/stima_ai.dart';
import '../../diary_controller.dart';
import 'conferma_stima_sheet.dart';
import 'dal_piano_tab.dart';

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
  /*
   * 🚨 **Quattro linguette da G9**, e la nuova sta **prima** di «A mano»: chi
   * ha un piano lo segue, e chi lo segue non deve digitare quello che e' gia'
   * scritto.
   *
   * ⚠️ Gli indici sono usati altrove (`_tabs.animateTo(2)` dal pannello senza
   * AI): «A mano» e' passata da 2 a **3**.
   */
  late final TabController _tabs = TabController(length: 4, vsync: this);

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

  /// Stima → conferma → diario — A4.8.
  ///
  /// ── 🚨 Perché non si scrive più direttamente ────────────────────────────
  ///
  /// Fino al 12/08/2026 questo metodo chiamava l'AI con `save: true` e chiudeva
  /// il foglio: la stima entrava in diario senza che nessuno l'avesse vista.
  /// Su «due cotolette di pollo» il modello ha risposto con **zero
  /// carboidrati** — cioè petto di pollo, non una cotoletta impanata — e nella
  /// propria `note` aveva scritto di non sapere se fossero panate. Quella nota
  /// arrivava sul telefono e non la leggeva nessuno.
  ///
  /// ⚠️ **«Precisa» ricomincia da qui**: il foglio di conferma restituisce la
  /// frase originale, la si rimette nel campo con il cursore in fondo, e si
  /// riscrive aggiungendo il pezzo che mancava. Costa una seconda chiamata al
  /// modello, ed è il punto: una stima giusta vale più di un token risparmiato.
  Future<void> _stimaEConferma(
    Future<StimaAi> Function() stimatore, {
    required bool daFoto,
  }) async {
    setState(() {
      _inCorso = true;
      _errore = null;
    });

    try {
      final stima = await stimatore();

      if (!mounted) return;

      setState(() => _inCorso = false);

      final daPrecisare = await ConfermaStimaSheet.mostra(
        context,
        stima: stima,
        meal: widget.meal,
        daFoto: daFoto,
      );

      if (!mounted) return;

      if (daPrecisare != null) {
        /*
         * 💡 Il cursore va **in fondo**, non all'inizio: quello che manca alla
         * frase si aggiunge in coda («due cotolette di pollo *impanate*»), e
         * trovare il cursore all'inizio costringe a un gesto in più ogni volta.
         */
        _testo
          ..text = daPrecisare
          ..selection = TextSelection.collapsed(offset: daPrecisare.length);

        _tabs.animateTo(0);

        return;
      }

      // Confermata o annullata: in entrambi i casi qui non c'è più niente da
      // fare, e il diario si è già aggiornato da solo.
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

  /// Registra nel diario quello che si e' scelto dal piano — G9.2.
  ///
  /// ── 💡 Perche' NON passa dal foglio di conferma ──────────────────────────
  ///
  /// Il foglio di conferma esiste perche' una stima dell'AI puo' sbagliare, e
  /// va guardata prima di entrare nei totali. Qui i numeri li ha scritti **il
  /// trainer**: farli riguardare all'allievo non aggiunge nessuna informazione,
  /// e trasformerebbe «ho mangiato quello che c'era scritto» in sei conferme.
  ///
  /// ⚠️ `FoodSource::Plan` lo mette il server quando riconosce la provenienza;
  /// qui si scrive con `addManual` perche' **il server non conosce piu' quel
  /// piano** (D4). Vedi il debito §7.2 del piano: `food_entries.nutrition_plan_id`
  /// resta `null`, ed e' il prezzo dichiarato dell'anonimato.
  Future<void> _registra(DiaryActions azioni, List<AlimentoDelPiano> alimenti) async {
    for (final a in alimenti) {
      if (a.descrizione.trim().isEmpty) continue;

      await azioni.addManual(
        description: a.descrizione,
        meal: widget.meal,
        grams: a.grammi,
        qty: a.qty,
        unit: a.unita,
        kcal: a.kcal,
        protein: a.proteine,
        carbs: a.carboidrati,
        fat: a.grassi,
      );
    }
  }

  /// L'inserimento **a mano**: qui non c'è niente da confermare.
  ///
  /// ⚠️ I numeri li ha scritti la persona. Farle rivedere quello che ha appena
  /// digitato sarebbe un passaggio che non aggiunge nessuna informazione — e il
  /// foglio di conferma esiste per un motivo preciso, non per simmetria.
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

    /*
     * 🚨 **Due motivi diversi per cui l'AI può non esserci, e due schermate
     * diverse** — difetto riferito il 13/08/2026.
     *
     * *«La stima da testo mi dice correttamente che non ho le funzioni AI, ma
     * me lo dovrebbe proprio mostrare come disattivato.»*
     *
     * ⚠️ Prima l'unico caso previsto era il **consenso**. Con F4 se n'è
     * aggiunto un secondo — il **piano** — e senza distinguerli l'app avrebbe
     * mandato ai consensi chi ha già acconsentito e deve invece cambiare piano.
     *
     * 💡 L'ordine è quello del server (`ai.plan` prima di `ai.consent`): se il
     * piano non comprende l'AI, chiedere il consenso non serve a niente.
     */
    final pianoOk = ref.watch(authControllerProvider).user?.aiAbilitata ?? true;
    final consensoOk = _aiPermessa(consensi);
    final aiOk = pianoOk && consensoOk;

    /*
     * ⚠️ Se l'AI non c'è, si parte da «A mano» invece che dalla scheda
     * bloccata: aprire il foglio su un pannello che dice «non puoi» sarebbe
     * corretto e inutile — quello che la persona vuole fare è comunque
     * registrare quel che ha mangiato.
     */
    if (!aiOk && !consensi.isLoading && _tabs.index < 2) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // ⚠️ Da G9 «A mano» e' la **quarta**: con `2` si finiva su «Dal piano».
        if (mounted && _tabs.index < 3) _tabs.animateTo(3);
      });
    }

    return Padding(
      // Alza il foglio sopra la tastiera: senza, il campo su cui si scrive
      // finisce coperto e non si vede cosa si digita.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          /*
           * 🚨 **Le due linguette dell'AI si vedono spente** — 13/08/2026.
           *
           * ⚠️ Prima erano identiche alle altre e il rifiuto arrivava **dopo**
           * aver scritto la frase: si compilava un campo per sentirsi dire di
           * no. Grigie in partenza, la risposta c'è **prima** del gesto.
           *
           * 💡 Restano toccabili di proposito: chi le tocca trova la
           * spiegazione e il pulsante per andare avanti a mano. Toglierle
           * lascerebbe due funzioni sparite senza dire perché — e chi le ha
           * viste ieri penserebbe a un guasto.
           */
          TabBar(
            controller: _tabs,
            tabs: [
              Tab(
                icon: Icon(
                  aiOk ? Icons.auto_awesome_outlined : Icons.auto_awesome_outlined,
                  color: aiOk ? null : Theme.of(context).colorScheme.outline,
                ),
                child: Text(
                  'Scrivi',
                  style: aiOk
                      ? null
                      : TextStyle(color: Theme.of(context).colorScheme.outline),
                ),
              ),
              Tab(
                icon: Icon(
                  Icons.photo_camera_outlined,
                  color: aiOk ? null : Theme.of(context).colorScheme.outline,
                ),
                child: Text(
                  'Foto',
                  style: aiOk
                      ? null
                      : TextStyle(color: Theme.of(context).colorScheme.outline),
                ),
              ),
              const Tab(icon: Icon(Icons.restaurant_menu_outlined), text: 'Dal piano'),
              const Tab(icon: Icon(Icons.edit_outlined), text: 'A mano'),
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
                // 🚨 Il piano **prima** del consenso, come sul server: se l'AI
                // non è compresa, chiedere il consenso non serve a niente.
                else if (!pianoOk)
                  _SenzaPianoAi(onInserisciAMano: () => _tabs.animateTo(3))
                else if (!consensoOk)
                  const _SenzaConsensoAi()
                else
                  _Testo(
                    controller: _testo,
                    inCorso: _inCorso,
                    onInvia: () => _stimaEConferma(
                      () => azioni.stimaDaTesto(_testo.text, widget.meal),
                      daFoto: false,
                    ),
                  ),

                if (consensi.isLoading)
                  const Center(child: CircularProgressIndicator())
                // 🚨 Il piano **prima** del consenso, come sul server: se l'AI
                // non è compresa, chiedere il consenso non serve a niente.
                else if (!pianoOk)
                  _SenzaPianoAi(onInserisciAMano: () => _tabs.animateTo(3))
                else if (!consensoOk)
                  const _SenzaConsensoAi()
                else
                  _Foto(
                    inCorso: _inCorso,
                    onScelta: (path) => _stimaEConferma(
                      () => azioni.stimaDaFoto(path, widget.meal),
                      daFoto: true,
                    ),
                  ),
                DalPianoTab(onScelti: (alimenti) => _esegui(() => _registra(azioni, alimenti))),

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
/// «Il tuo piano non comprende l'AI» — F4, difetto riferito il 13/08/2026.
///
/// ── 🚨 Perché non basta il `403` del server ────────────────────────────────
///
/// *«Mi dice correttamente che non ho le funzioni AI, ma me lo dovrebbe proprio
/// mostrare come disattivato: quando cerco di inserire un alimento mi deve dire
/// "non hai accesso alle funzioni AI, inserisci a mano" e mandarmi
/// all'inserimento manuale.»*
///
/// ⚠️ Un rifiuto che arriva **dopo** aver scritto la frase è un modulo
/// compilato per niente. E soprattutto **lascia lì**: la persona voleva
/// registrare quello che ha mangiato, e si ritrova con un errore e nessuna
/// strada.
///
/// 💡 Per questo il pulsante non porta al listino ma **all'inserimento
/// manuale**: la cosa che quella persona stava cercando di fare è registrare un
/// pasto, non comprare un abbonamento.
///
/// ⚠️ **E il listino qui non c'è affatto**, non per dimenticanza: nessuna
/// schermata dell'app ci porta, perché F9.3 — il pagamento — non ha ancora un
/// fornitore. Un rimando a un listino da cui non si può comprare sarebbe una
/// seconda strada chiusa dopo quella appena chiusa. Quando F9.3 sarà fatta,
/// **questo è il posto**: una riga sotto il pulsante, mai al posto suo.
class _SenzaPianoAi extends StatelessWidget {
  const _SenzaPianoAi({required this.onInserisciAMano});

  final VoidCallback onInserisciAMano;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(Gap.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_awesome_outlined, size: 40, color: theme.colorScheme.outline),
          const SizedBox(height: Gap.md),
          Text(
            'Non hai accesso alle funzioni AI',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Gap.sm),
          Text(
            'La stima da una frase o da una foto è compresa nei piani a '
            'pagamento. Puoi comunque registrare quello che hai mangiato '
            'inserendolo a mano.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: Gap.md),

          // 🚨 La via d'uscita è **fare la cosa che si stava facendo**, non
          // comprare qualcosa.
          FilledButton.tonalIcon(
            onPressed: onInserisciAMano,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Inserisci a mano'),
          ),
        ],
      ),
    );
  }
}

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
