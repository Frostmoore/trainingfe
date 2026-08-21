import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/stima_ai.dart';
import '../../data/stime_in_coda.dart';
import '../../diary_controller.dart';
import 'conferma_stima_sheet.dart';

/// La stima lasciata a metà, ritrovata — FASE 9.7.
///
/// ══ 🚨 PERCHÉ SERVE ═══════════════════════════════════════════════════════
///
/// Dalla FASE 9 la stima la fa un worker: se l'app viene chiusa mentre pensa —
/// e succede, perché scrivere un piatto è una cosa che si fa in mezzo ad altre
/// — **il lavoro continua sul server**. ⚠️ Senza questo pezzo, quella stima
/// resta lì e la persona riscrive il piatto da capo: **una seconda chiamata al
/// modello per lo stesso pranzo**, pagata due volte e senza che nessuno se ne
/// accorga, perché il piatto arriva comunque.
///
/// ── ⚠️ Perché è un avviso e NON apre il foglio da solo ────────────────────
///
/// Perché chi apre il diario può averlo aperto **per un'altra ragione**: per
/// guardare i totali, per correggere una voce di ieri. 🚨 Un foglio modale che
/// compare da solo, per giunta non chiudibile toccando fuori
/// (`isDismissible: false`), ruba l'interazione a chi non l'aveva chiesta.
///
/// 💡 L'avviso dice che c'è, e chi vuole tocca. Chi non tocca la ritrova al
/// prossimo giro — è nella lista da 24 ore, non da un secondo.
///
/// ── 💡 Nel caso normale non si vede, e non costa niente ───────────────────
///
/// `inSospeso()` guarda **prima** sul telefono: senza id locale la maggior parte
/// delle volte non parte nemmeno una richiesta.
class StimaRitrovata extends ConsumerStatefulWidget {
  const StimaRitrovata({super.key});

  @override
  ConsumerState<StimaRitrovata> createState() => _StimaRitrovataState();
}

enum _Fase { niente, aspetto, pronta, fallita }

class _StimaRitrovataState extends ConsumerState<StimaRitrovata> {
  _Fase _fase = _Fase.niente;
  StimaAi? _stima;
  String _pasto = 'lunch';
  bool _daFoto = false;
  String? _errore;

  @override
  void initState() {
    super.initState();

    /*
     * ⚠️ Dopo il primo frame, non nel `initState` diretto: qui si fa una
     * chiamata di rete, e farla partire mentre l'albero si sta ancora
     * costruendo è il modo di ritrovarsi un `setState` su uno `State` che non
     * è ancora montato.
     */
    WidgetsBinding.instance.addPostFrameCallback((_) => _cerca());
  }

  Future<void> _cerca() async {
    final azioni = ref.read(diaryActionsProvider);

    try {
      /*
       * 💡 Si chiede **prima** se c'è qualcosa, e solo dopo si aspetta: così
       * l'avviso «la sto recuperando» compare solo a chi ha davvero una stima
       * in sospeso. ⚠️ La seconda chiamata non ripaga la prima: l'id è già sul
       * telefono, e `inSospeso()` lo legge da lì.
       */
      final sospesa = await ref.read(stimeInCodaProvider).inSospeso();

      if (sospesa == null || !mounted) return;

      setState(() => _fase = _Fase.aspetto);

      final ritrovata = await azioni.riprendiStimaInSospeso();

      if (!mounted || ritrovata == null) return;

      setState(() {
        _stima = ritrovata.stima;
        _pasto = ritrovata.pasto;
        _daFoto = ritrovata.daFoto;
        _fase = _Fase.pronta;
      });
    } on StimaTroppoLenta {
      /*
       * 💡 Non è un errore: il lavoro va avanti. L'avviso **sparisce** e si
       * riproverà alla prossima apertura del diario — insistere qui vorrebbe
       * dire tenere una richiesta aperta su una schermata che la persona sta
       * usando per altro.
       */
      if (mounted) setState(() => _fase = _Fase.niente);
    } on StimaFallita catch (e) {
      if (mounted) {
        setState(() {
          _errore = e.perUnaPersona;
          _fase = _Fase.fallita;
        });
      }
    } on Object {
      // ⚠️ Muto: è un di più. Un guasto qui non deve disturbare chi sta
      // guardando il diario per tutt'altro.
      if (mounted) setState(() => _fase = _Fase.niente);
    }
  }

  Future<void> _apri() async {
    final stima = _stima;

    if (stima == null) return;

    setState(() => _fase = _Fase.niente);

    await ConfermaStimaSheet.mostra(
      context,
      stima: stima,
      meal: _pasto,
      daFoto: _daFoto,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_fase == _Fase.niente) return const SizedBox.shrink();

    final tema = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.md),
      child: Card(
        margin: EdgeInsets.zero,
        color: tema.colorScheme.secondaryContainer,
        child: InkWell(
          onTap: _fase == _Fase.pronta ? _apri : null,
          borderRadius: BorderRadius.circular(Gap.radius),
          child: Padding(
            padding: const EdgeInsets.all(Gap.md),
            child: Row(
              children: [
                if (_fase == _Fase.aspetto)
                  const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(
                    _fase == _Fase.pronta
                        ? Icons.restaurant_rounded
                        : Icons.error_outline_rounded,
                    color: tema.colorScheme.onSecondaryContainer,
                  ),

                const SizedBox(width: Gap.md),

                Expanded(
                  child: Text(
                    switch (_fase) {
                      _Fase.aspetto =>
                        'Stavi aspettando una stima: la sto recuperando…',
                      _Fase.pronta =>
                        'La stima di prima è pronta. Tocca per guardarla.',
                      _Fase.fallita => _errore ?? 'La stima non è riuscita.',
                      _Fase.niente => '',
                    },
                    style: tema.textTheme.bodyMedium?.copyWith(
                      color: tema.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),

                if (_fase == _Fase.fallita)
                  IconButton(
                    onPressed: () => setState(() => _fase = _Fase.niente),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Chiudi',
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
