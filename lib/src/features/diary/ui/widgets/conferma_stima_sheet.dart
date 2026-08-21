import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/stima_ai.dart';
import '../../diary_controller.dart';

/// Cosa il modello ha capito, **prima** che diventi diario — A4.8.
///
/// ── 🚨 Perché questo foglio esiste ────────────────────────────────────────
///
/// Il 12/08/2026 il committente ha chiesto perché il modello non avesse capito
/// che una cotoletta di pollo è impanata. La risposta è che **non lo aveva
/// capito e lo aveva anche scritto**:
///
/// > «cotte in padella con olio. Se cucinate diversamente (fritte, panate
/// > pesantemente) i valori cambiano significativamente.»
///
/// Quel testo arrivava sul telefono in `estimate.note` e finiva nel niente:
/// l'app chiamava con `save: true`, il backend scriveva, e la voce entrava nei
/// totali con zero carboidrati e sedici grammi di proteine in più del vero.
///
/// ⚠️ **La regola c'era già**, in `FoodEstimate` lato server: *«`confidence`
/// non è decorazione: sotto una soglia l'app deve chiedere conferma invece di
/// scrivere nel diario»*. Nessuna riga di codice la eseguiva — la dodicesima di
/// una serie che ormai ha una forma riconoscibile.
///
/// ── Le tre scelte di questo foglio ────────────────────────────────────────
///
/// 1. **La nota si mostra sempre**, quando c'è. Non è un dettaglio da aprire:
///    è l'unica cosa che dice *dove* la stima può sbagliare.
/// 2. **I valori sono collassati**, uno per voce. Chi mangia una mela non deve
///    leggere sette numeri; chi ha una stima incerta li apre.
/// 3. **«Precisa» riapre la frase originale**, non un campo vuoto. Chi deve
///    ridigitare da capo non precisa: conferma e basta.
class ConfermaStimaSheet extends ConsumerStatefulWidget {
  const ConfermaStimaSheet({
    required this.stima,
    required this.meal,
    required this.daFoto,
    super.key,
  });

  final StimaAi stima;
  final String meal;
  final bool daFoto;

  /// Restituisce la frase da **precisare**, oppure `null` se si è chiuso.
  ///
  /// 🚨 Il valore di ritorno è il modo in cui «Precisa» torna indietro: chi
  /// apre questo foglio riceve la frase e riapre il campo di testo con dentro.
  static Future<String?> mostra(
    BuildContext context, {
    required StimaAi stima,
    required String meal,
    required bool daFoto,
  }) => showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // ⚠️ Non si chiude toccando fuori: si è appena speso un pezzo di quota per
    // questa stima, e perderla con un tocco distratto vorrebbe dire rifarla.
    isDismissible: false,
    enableDrag: false,
    builder: (_) =>
        ConfermaStimaSheet(stima: stima, meal: meal, daFoto: daFoto),
  );

  @override
  ConsumerState<ConfermaStimaSheet> createState() => _ConfermaStimaSheetState();
}

class _ConfermaStimaSheetState extends ConsumerState<ConfermaStimaSheet> {
  late StimaAi _stima = widget.stima;

  bool _inCorso = false;
  String? _errore;

  Future<void> _conferma() async {
    setState(() {
      _inCorso = true;
      _errore = null;
    });

    try {
      await ref
          .read(diaryActionsProvider)
          .confermaStima(_stima, meal: widget.meal, daFoto: widget.daFoto);

      if (mounted) Navigator.of(context).pop();
    } on Object catch (error) {
      /*
       * 🚨 **Il foglio resta aperto con la stima dentro.**
       *
       * È la risposta all'obiezione che teneva `save: true`: «se la seconda
       * richiesta fallisce, l'utente resta con una stima che non ha salvato».
       * Vero — ma resta con la stima *davanti*, e il pulsante è ancora lì.
       * Prima, quando falliva la scrittura, si perdeva comunque tutto: solo
       * senza averla mai vista.
       */
      setState(() {
        _errore = ApiClient.unwrapError(error).message;
        _inCorso = false;
      });
    }
  }

  /// Sostituisce una voce con quella corretta a mano.
  void _correggi(int indice, VoceStimata nuova) {
    final voci = [..._stima.voci]..[indice] = nuova;

    setState(() => _stima = _stima.conVoci(voci));
  }

  void _togli(int indice) {
    final voci = [..._stima.voci]..removeAt(indice);

    setState(() => _stima = _stima.conVoci(voci));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scroll) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, Gap.sm),
            child: _Intestazione(stima: _stima),
          ),

          Expanded(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md),
              children: [
                if (_stima.nota != null) _NotaDelModello(testo: _stima.nota!),

                /*
                 * 🚨 **Gli avvisi del backend si mostrano separati dalla nota**,
                 * e non e' pignoleria: la nota e' un'opinione del modello, questi
                 * sono controlli deterministici che hanno **gia' corretto** un
                 * numero o trovato un valore fuori scala. Chi legge deve poter
                 * distinguere «il modello dice di non essere sicuro» da «il
                 * sistema ha rifatto il conto al posto suo».
                 */
                for (final avviso in _stima.avvisi)
                  _AvvisoDelSistema(testo: avviso),

                if (_stima.haMacroImpossibili) const _AvvisoMacroImpossibili(),

                const SizedBox(height: Gap.sm),

                for (final (i, voce) in _stima.voci.indexed)
                  _RigaVoce(
                    key: ValueKey('${voce.nome}-$i'),
                    voce: voce,
                    apertaDaSola:
                        _stima.voci.length == 1 || _stima.livello.apriDaSola,
                    onCorretta: (nuova) => _correggi(i, nuova),
                    onTolta: _stima.voci.length > 1 ? () => _togli(i) : null,
                  ),

                if (_stima.vuota)
                  Padding(
                    padding: const EdgeInsets.all(Gap.lg),
                    child: Text(
                      'Non ho riconosciuto nessun alimento.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),

                if (_errore != null) ...[
                  const SizedBox(height: Gap.md),
                  Text(
                    _errore!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],
              ],
            ),
          ),

          _Azioni(
            inCorso: _inCorso,
            /*
             * 🚨 **I macro impossibili BLOCCANO il salvataggio** — 12/08/2026.
             *
             * Il committente: *«la guardia sull'impossibilità della massa è
             * hard-blocking perché non è possibile che un alimento abbia più
             * macro che peso»*. Il server lo rifiuta con un 422, e l'app deve
             * fermarsi **prima**: un pulsante che si preme e restituisce un
             * errore è peggio di un pulsante spento, perché non dice cosa fare.
             *
             * ⚠️ Qui invece la riga sbagliata è **già aperta** con i suoi campi
             * modificabili: si corregge il numero e il pulsante si riaccende da
             * solo. È l'unica ragione per cui bloccare qui è accettabile.
             */
            puoConfermare: !_stima.vuota && !_stima.haMacroImpossibili,
            // ⚠️ Da una foto non c'è niente da precisare a parole: si offre di
            // rifare lo scatto solo tornando indietro, e i numeri si correggono
            // qui sopra.
            frasePrecisabile: _stima.frase,
            onConferma: _conferma,
            onPrecisa: () => Navigator.of(context).pop(_stima.frase),
            onAnnulla: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

/// Totale e livello di confidenza, in cima.
class _Intestazione extends StatelessWidget {
  const _Intestazione({required this.stima});

  final StimaAi stima;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    /// 💡 Il colore segue il livello, non il numero: tre stati si distinguono
    /// a colpo d'occhio, una scala continua no.
    final (colore, icona) = switch (stima.livello) {
      LivelloConfidenza.alta => (
        theme.colorScheme.primary,
        Icons.check_circle_outline,
      ),
      LivelloConfidenza.media => (
        theme.colorScheme.tertiary,
        Icons.help_outline,
      ),
      LivelloConfidenza.bassa => (theme.colorScheme.error, Icons.error_outline),
    };

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ecco cosa ho capito',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: Gap.xs),
              Text(
                '${stima.kcal.round()} kcal · '
                'P ${stima.proteine.round()} · '
                'C ${stima.carboidrati.round()} · '
                'G ${stima.grassi.round()}',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        Chip(
          avatar: Icon(icona, size: 18, color: colore),
          label: Text(stima.livello.etichetta),
          labelStyle: theme.textTheme.labelSmall?.copyWith(color: colore),
          side: BorderSide(color: colore.withValues(alpha: 0.4)),
          backgroundColor: colore.withValues(alpha: 0.08),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}

/// 🚨 Quello che il modello ha da dire su cosa **non** sa.
///
/// Si mostra sempre e per intero. È il segnale affidabile: sulla cotoletta la
/// confidenza diceva 0.85 — «alta» — e la nota diceva «non è stato specificato
/// se sono panate». Aveva ragione la nota.
class _NotaDelModello extends StatelessWidget {
  const _NotaDelModello({required this.testo});

  final String testo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(top: Gap.sm),
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Gap.radiusSm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: theme.colorScheme.outline),
          const SizedBox(width: Gap.sm),
          Expanded(child: Text(testo, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}

/// Un controllo deterministico del backend: una densità implausibile, i grammi
/// di alcol rifatti dalla gradazione, un valore fuori scala.
///
/// 🚨 **Non è la nota del modello, ed è disegnato diverso apposta.** La nota è
/// un'opinione di chi ha stimato; questo è il sistema che ha misurato — e in
/// qualche caso ha già corretto. Confonderli farebbe sembrare opinabile una cosa
/// che non lo è.
class _AvvisoDelSistema extends StatelessWidget {
  const _AvvisoDelSistema({required this.testo});

  final String testo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(top: Gap.sm),
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Gap.radiusSm),
        border: Border.all(
          color: theme.colorScheme.tertiary.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.rule_rounded, size: 18, color: theme.colorScheme.tertiary),
          const SizedBox(width: Gap.sm),
          Expanded(child: Text(testo, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}

/// ⚠️ Una voce dichiara più macronutrienti di quanto pesa.
///
/// Si segnala e **non si corregge**: aggiustarla vorrebbe dire inventare al
/// posto del modello. Serve a far guardare quella riga.
class _AvvisoMacroImpossibili extends StatelessWidget {
  const _AvvisoMacroImpossibili();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(top: Gap.sm),
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(Gap.radiusSm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.scale_outlined, size: 18, color: theme.colorScheme.error),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: Text(
              'Una voce dichiara più proteine, carboidrati e grassi di quanto '
              'pesa: è impossibile. Correggi i valori qui sotto — finché non '
              'tornano, non si può aggiungere al diario.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Una voce, con i suoi valori **collassati**.
///
/// 💡 Chiusa mostra le due cose che servono a riconoscerla — nome e quantità —
/// più le calorie. Aperta mostra i macro e permette di correggere quantità e
/// calorie: è il minimo per rimediare a una stima storta senza uscire di qui.
class _RigaVoce extends StatefulWidget {
  const _RigaVoce({
    required this.voce,
    required this.apertaDaSola,
    required this.onCorretta,
    this.onTolta,
    super.key,
  });

  final VoceStimata voce;
  final bool apertaDaSola;
  final ValueChanged<VoceStimata> onCorretta;
  final VoidCallback? onTolta;

  @override
  State<_RigaVoce> createState() => _RigaVoceState();
}

class _RigaVoceState extends State<_RigaVoce> {
  late final _qty = TextEditingController(
    text: _testo(widget.voce.qty ?? widget.voce.grammi),
  );
  late final _kcal = TextEditingController(text: _testo(widget.voce.kcal));
  late final _proteine = TextEditingController(
    text: _testo(widget.voce.proteine),
  );
  late final _carbo = TextEditingController(
    text: _testo(widget.voce.carboidrati),
  );
  late final _grassi = TextEditingController(text: _testo(widget.voce.grassi));

  /// I valori che chi legge ha corretto a mano.
  ///
  /// 🚨 **Da quel momento non si riscalano più.** Chi scrive «32» nelle proteine
  /// sta dicendo che ne sa più del modello, e vedersele riscrivere da una
  /// proporzione al carattere successivo sarebbe un campo che si rifiuta di
  /// obbedire.
  final _toccati = <String>{};

  static String _testo(double? v) {
    if (v == null) return '';

    return v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
  }

  @override
  void dispose() {
    _qty.dispose();
    _kcal.dispose();
    _proteine.dispose();
    _carbo.dispose();
    _grassi.dispose();
    super.dispose();
  }

  double? _valore(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  /// La quantità è cambiata: **tutto si riscala mentre si digita**.
  ///
  /// ── 🚨 Perché il ricalcolo è qui e non solo sul server ───────────────────
  ///
  /// Il committente, il 12/08/2026: *«quando modifico i grammi, i calcoli li
  /// deve fare in tempo reale mentre scrivo»*. Ed è la richiesta giusta: senza,
  /// si corregge una porzione da 200 a 250 g e si conferma un pasto vedendo
  /// ancora le calorie di prima — cioè si accetta un numero che si sa sbagliato,
  /// fidandosi che qualcun altro lo sistemi.
  ///
  /// ⚠️ **Non è una seconda formula da tenere allineata**: è la proporzione da
  /// `per100`, la stessa che il backend rifà comunque al salvataggio. Qui serve
  /// a **mostrare** dove si sta andando, non a decidere cosa si salva.
  ///
  /// 🚨 Si aggiornano anche i **grammi** quando l'unità è già in grammi: salvare
  /// «250» con `grams` fermo a 200 farebbe contare al server i grammi vecchi, e
  /// un numero corretto a mano senza effetto è peggio di un campo bloccato.
  void _quantitaCambiata() {
    final q = _valore(_qty);

    if (q == null || q <= 0) {
      _applica();

      return;
    }

    final unita = widget.voce.unita ?? 'g';

    // ⚠️ Su un'unità che non è in grammi non si può riscalare: quanto pesi un
    // cucchiaio lo sa la tabella del server, non l'app. Si manda la quantità e
    // si lascia fare a lui, come prima.
    if (unita != 'g') {
      _applica();

      return;
    }

    final riscalata = widget.voce.riscalataA(q, intoccabili: _toccati);

    // I campi non toccati si riscrivono con il valore nuovo, gli altri no.
    if (!_toccati.contains('kcal')) _kcal.text = _testo(riscalata.kcal);
    if (!_toccati.contains('protein'))
      _proteine.text = _testo(riscalata.proteine);
    if (!_toccati.contains('carbs'))
      _carbo.text = _testo(riscalata.carboidrati);
    if (!_toccati.contains('fat')) _grassi.text = _testo(riscalata.grassi);

    _applica();
  }

  /// Manda alla stima quello che c'è **adesso** nei campi.
  void _applica() {
    final q = _valore(_qty);
    final unita = widget.voce.unita ?? 'g';

    widget.onCorretta(
      widget.voce.copyCon(
        qty: q,
        grammi: (unita == 'g' && q != null) ? q : widget.voce.grammi,
        kcal: _valore(_kcal),
        proteine: _valore(_proteine),
        carboidrati: _valore(_carbo),
        grassi: _valore(_grassi),
      ),
    );
  }

  /// Un campo numerico che non taglia la propria etichetta.
  ///
  /// ⚠️ **`isDense: true` con `labelText` è la trappola**: l'etichetta, quando
  /// sale, esce **sopra** il bordo del campo, e dentro un `ExpansionTile` con
  /// padding superiore zero finiva tagliata a metà. Qui il padding verticale è
  /// esplicito e l'etichetta ha lo spazio in cui salire.
  Widget _campo(
    TextEditingController controller,
    String etichetta,
    String suffisso, {
    String? chiave,
  }) => TextField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    style: Theme.of(context).textTheme.bodyMedium,
    decoration: InputDecoration(
      labelText: etichetta,
      suffixText: suffisso,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Gap.sm,
        vertical: Gap.sm,
      ),
    ),
    onChanged: (_) {
      if (chiave == null) {
        _quantitaCambiata();

        return;
      }

      _toccati.add(chiave);
      _applica();
    },
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final v = widget.voce;

    return Card(
      margin: const EdgeInsets.only(bottom: Gap.sm),
      child: ExpansionTile(
        initiallyExpanded:
            widget.apertaDaSola ||
            v.macroImpossibili ||
            v.stato == StatoCottura.ambiguo,
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text(
          v.marca != null ? '${v.nome} · ${v.marca}' : v.nome,
          style: theme.textTheme.titleSmall,
        ),
        subtitle: Text(
          [
            v.quantita,
            if (v.kcal != null) '${v.kcal!.round()} kcal',
            // 💡 Lo stato si mostra solo quando dice qualcosa: «non applicabile»
            // su uno yogurt e' rumore.
            if (v.stato != null && v.stato!.etichetta.isNotEmpty)
              v.stato!.etichetta,
          ].where((s) => s.isNotEmpty).join(' · '),
          style: theme.textTheme.bodySmall?.copyWith(
            color: v.stato == StatoCottura.ambiguo
                ? theme.colorScheme.tertiary
                : null,
          ),
        ),
        trailing: v.macroImpossibili
            ? Icon(Icons.error_outline, color: theme.colorScheme.error)
            /*
             * 🚨 **L'incertezza si segna sulla RIGA, non solo in cima.**
             *
             * «Il pasto ha confidenza 0.68» non serve a nessuno: chi legge deve
             * sapere **quale** ingrediente e' quello da guardare, perche' e'
             * l'unico che ha senso correggere.
             *
             * ⚠️ Una quantita' **dichiarata** non si segna mai, anche se la sua
             * confidenza e' bassa: la persona ha scritto «100 g», e rimetterlo in
             * discussione e' il modo piu' rapido per farle smettere di scrivere
             * le quantita'.
             */
            : (v.daGuardare && v.dichiarata != true
                  ? Icon(Icons.help_outline, color: theme.colorScheme.tertiary)
                  : null),
        children: [
          Padding(
            // ⚠️ Il padding superiore NON è zero: le etichette dei campi salgono
            // sopra il bordo, e senza spazio finivano tagliate.
            padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: _campo(_qty, 'Quantità', v.unita ?? 'g')),
                    const SizedBox(width: Gap.sm),
                    Expanded(
                      child: _campo(_kcal, 'Calorie', 'kcal', chiave: 'kcal'),
                    ),
                  ],
                ),
                const SizedBox(height: Gap.md),

                /*
                 * 🚨 **I macro sono campi, non etichette.**
                 *
                 * Il committente: *«i macro devo poterli modificare nella pagina
                 * di conferma dell'alimento»*. Prima erano tre pastiglie da
                 * leggere, e chi vedeva 48 g di proteine su una cotoletta
                 * impanata poteva solo confermare il numero sbagliato e poi
                 * rientrare dal diario a correggerlo — cioè passare comunque per
                 * un totale storto.
                 */
                Row(
                  children: [
                    Expanded(
                      child: _campo(
                        _proteine,
                        'Proteine',
                        'g',
                        chiave: 'protein',
                      ),
                    ),
                    const SizedBox(width: Gap.sm),
                    Expanded(
                      child: _campo(
                        _carbo,
                        'Carboidrati',
                        'g',
                        chiave: 'carbs',
                      ),
                    ),
                    const SizedBox(width: Gap.sm),
                    Expanded(
                      child: _campo(_grassi, 'Grassi', 'g', chiave: 'fat'),
                    ),
                  ],
                ),

                if (v.unita != null && v.unita != 'g') ...[
                  const SizedBox(height: Gap.sm),
                  Text(
                    // 🚨 Si dice **se** il ricalcolo avverrà: quanto pesa un
                    // cucchiaio lo sa la tabella del server, non l'app.
                    'Cambiando la quantità in ${v.unita}, calorie e macro li '
                    'ricalcola il server al salvataggio.',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],

                if (widget.onTolta != null) ...[
                  const SizedBox(height: Gap.sm),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: widget.onTolta,
                      icon: const Icon(Icons.remove_circle_outline, size: 18),
                      label: const Text('Togli'),
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// I tre pulsanti, nell'ordine in cui servono.
///
/// 🚨 **«Aggiungi» è il primo e il pieno**: nella maggior parte dei casi la
/// stima è giusta, e rendere faticosa la strada comune per proteggere quella
/// rara fa smettere di registrare — che è il modo in cui un diario alimentare
/// muore davvero.
class _Azioni extends StatelessWidget {
  const _Azioni({
    required this.inCorso,
    required this.puoConfermare,
    required this.frasePrecisabile,
    required this.onConferma,
    required this.onPrecisa,
    required this.onAnnulla,
  });

  final bool inCorso;
  final bool puoConfermare;
  final String? frasePrecisabile;
  final VoidCallback onConferma, onPrecisa, onAnnulla;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.md),
      child: Column(
        children: [
          FilledButton.icon(
            style: bottonePieno(),
            onPressed: (inCorso || !puoConfermare) ? null : onConferma,
            icon: inCorso
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded),
            label: const Text('Aggiungi al diario'),
          ),
          const SizedBox(height: Gap.sm),
          Row(
            children: [
              if (frasePrecisabile != null) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: inCorso ? null : onPrecisa,
                    icon: const Icon(Icons.edit_note_rounded, size: 20),
                    label: const Text('Precisa'),
                  ),
                ),
                const SizedBox(width: Gap.sm),
              ],
              Expanded(
                child: TextButton(
                  onPressed: inCorso ? null : onAnnulla,
                  child: const Text('Annulla'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
