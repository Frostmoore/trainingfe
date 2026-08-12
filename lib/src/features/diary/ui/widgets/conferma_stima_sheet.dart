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
    builder: (_) => ConfermaStimaSheet(stima: stima, meal: meal, daFoto: daFoto),
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

                if (_stima.haMacroImpossibili) const _AvvisoMacroImpossibili(),

                const SizedBox(height: Gap.sm),

                for (final (i, voce) in _stima.voci.indexed)
                  _RigaVoce(
                    key: ValueKey('${voce.nome}-$i'),
                    voce: voce,
                    apertaDaSola: _stima.voci.length == 1 || _stima.livello.apriDaSola,
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
            puoConfermare: !_stima.vuota,
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
      LivelloConfidenza.alta => (theme.colorScheme.primary, Icons.check_circle_outline),
      LivelloConfidenza.media => (theme.colorScheme.tertiary, Icons.help_outline),
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
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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
              'pesa: è impossibile, quindi la stima è gonfiata. Controlla i '
              'valori prima di aggiungerla.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
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

  static String _testo(double? v) {
    if (v == null) return '';

    return v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
  }

  @override
  void dispose() {
    _qty.dispose();
    _kcal.dispose();
    super.dispose();
  }

  double? _valore(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  /// 🚨 Correggendo la quantità si aggiornano **anche i grammi**, quando l'unità
  /// è già in grammi. Altrimenti si salverebbe «250» con `grams` fermo a 200, e
  /// il server conterebbe i grammi vecchi: un numero corretto a mano che non ha
  /// nessun effetto è peggio di un campo non modificabile.
  void _applica() {
    final q = _valore(_qty);
    final unita = widget.voce.unita ?? 'g';

    widget.onCorretta(
      widget.voce.copyCon(
        qty: q,
        grammi: (unita == 'g' && q != null) ? q : widget.voce.grammi,
        kcal: _valore(_kcal),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final v = widget.voce;

    return Card(
      margin: const EdgeInsets.only(bottom: Gap.sm),
      child: ExpansionTile(
        initiallyExpanded: widget.apertaDaSola || v.macroImpossibili,
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text(v.nome, style: theme.textTheme.titleSmall),
        subtitle: Text(
          [v.quantita, if (v.kcal != null) '${v.kcal!.round()} kcal']
              .where((s) => s.isNotEmpty)
              .join(' · '),
          style: theme.textTheme.bodySmall,
        ),
        trailing: v.macroImpossibili
            ? Icon(Icons.error_outline, color: theme.colorScheme.error)
            : null,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _qty,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Quantità',
                          suffixText: v.unita ?? 'g',
                          isDense: true,
                        ),
                        onChanged: (_) => _applica(),
                      ),
                    ),
                    const SizedBox(width: Gap.sm),
                    Expanded(
                      child: TextField(
                        controller: _kcal,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Calorie',
                          suffixText: 'kcal',
                          isDense: true,
                        ),
                        onChanged: (_) => _applica(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Gap.md),
                Wrap(
                  spacing: Gap.sm,
                  runSpacing: Gap.xs,
                  children: [
                    _Macro(nome: 'Proteine', grammi: v.proteine),
                    _Macro(nome: 'Carboidrati', grammi: v.carboidrati),
                    _Macro(nome: 'Grassi', grammi: v.grassi),
                  ],
                ),
                if (widget.onTolta != null) ...[
                  const SizedBox(height: Gap.sm),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: widget.onTolta,
                      icon: const Icon(Icons.remove_circle_outline, size: 18),
                      label: const Text('Togli'),
                      style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
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

class _Macro extends StatelessWidget {
  const _Macro({required this.nome, required this.grammi});

  final String nome;
  final double? grammi;

  @override
  Widget build(BuildContext context) => Chip(
    label: Text('$nome ${grammi == null ? '—' : '${grammi!.round()} g'}'),
    labelStyle: Theme.of(context).textTheme.labelSmall,
    visualDensity: VisualDensity.compact,
    side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
  );
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
