import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../catalogo_controller.dart';
import '../../data/alimento_catalogo.dart';

/// Il campo del nome, con i suggerimenti dal catalogo — 17/08/2026.
///
/// ── 🚨 Perché non è un `Autocomplete` di Flutter ───────────────────────────
///
/// Perché `Autocomplete` chiama la funzione di ricerca **a ogni carattere**, e
/// qui ogni chiamata è una richiesta di rete. ⚠️ Scrivere «petto di pollo»
/// sarebbe quindici richieste in tre secondi, e il freno del server (60 al
/// minuto) si consumerebbe scrivendo due alimenti.
///
/// 💡 Qui si aspetta che la persona **smetta di scrivere** per un quarto di
/// secondo. È il tempo che nessuno percepisce e che riduce quindici richieste a
/// una o due.
///
/// ── ⚠️ E il campo resta scrivibile a mano ──────────────────────────────────
///
/// I suggerimenti aiutano, non obbligano. Chi mangia una cosa che nel catalogo
/// non c'è deve poterla scrivere e basta — è anche il modo in cui il catalogo
/// impara le cose nuove.
class CampoAlimento extends ConsumerStatefulWidget {
  const CampoAlimento({
    super.key,
    required this.controller,
    required this.onScelto,
  });

  final TextEditingController controller;

  /// Chiamata quando si sceglie un suggerimento, così chi sta sopra può
  /// riempire i macro. `null` quando la scelta viene annullata scrivendo altro.
  final ValueChanged<AlimentoCatalogo?> onScelto;

  @override
  ConsumerState<CampoAlimento> createState() => _CampoAlimentoState();
}

class _CampoAlimentoState extends ConsumerState<CampoAlimento> {
  static const _attesa = Duration(milliseconds: 250);

  Timer? _rinvio;
  String _cercato = '';
  bool _apertoDaUnaScelta = false;

  @override
  void dispose() {
    _rinvio?.cancel();
    super.dispose();
  }

  void _scritto(String testo) {
    // 🚨 Scegliendo un suggerimento si riscrive il campo, e questo richiama
    // `onChanged`: senza questa guardia, l'elenco si riaprirebbe subito sotto
    // la scelta appena fatta.
    if (_apertoDaUnaScelta) {
      _apertoDaUnaScelta = false;
      return;
    }

    widget.onScelto(null);

    _rinvio?.cancel();
    _rinvio = Timer(_attesa, () {
      if (mounted) setState(() => _cercato = testo.trim());
    });
  }

  void _scegli(AlimentoCatalogo a) {
    _apertoDaUnaScelta = true;
    widget.controller.text = a.nome;
    widget.controller.selection = TextSelection.collapsed(offset: a.nome.length);

    widget.onScelto(a);

    setState(() => _cercato = '');
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final suggerimenti = _cercato.length < 2
        ? const AsyncValue<List<AlimentoCatalogo>>.data([])
        : ref.watch(ricercaAlimentiProvider(_cercato));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.controller,
          textCapitalization: TextCapitalization.sentences,
          onChanged: _scritto,
          decoration: const InputDecoration(
            labelText: 'Cosa hai mangiato',
            helperText: 'Scrivi le prime lettere: se lo conosciamo, lo compiliamo noi.',
          ),
        ),

        suggerimenti.maybeWhen(
          // 💡 Niente rotella e niente messaggio d'errore: è un aiuto, e un
          // aiuto che non arriva non deve diventare un problema da leggere.
          orElse: () => const SizedBox.shrink(),
          data: (elenco) => elenco.isEmpty
              ? const SizedBox.shrink()
              : _Elenco(alimenti: elenco, onScelto: _scegli),
        ),
      ],
    );
  }
}

class _Elenco extends StatelessWidget {
  const _Elenco({required this.alimenti, required this.onScelto});

  final List<AlimentoCatalogo> alimenti;
  final ValueChanged<AlimentoCatalogo> onScelto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      constraints: const BoxConstraints(maxHeight: 260),
      margin: const EdgeInsets.only(top: Gap.sm),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: alimenti.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final a = alimenti[i];

          return ListTile(
            dense: true,
            leading: _Miniatura(url: a.immagineUrl),
            title: Text(a.titolo, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: a.kcal100 == null
                ? null
                : Text('${a.kcal100!.round()} kcal per 100 ${a.basis}'),
            onTap: () => onScelto(a),
          );
        },
      ),
    );
  }
}

/// L'immagine dell'alimento, se la fonte ne ha una.
///
/// ── 🚨 Deve poter non esserci, ed è il caso normale ────────────────────────
///
/// La maggior parte degli alimenti non ha nessuna immagine, e quelle che ci
/// sono stanno **sui server di Open Food Facts** — non sui nostri, perché sono
/// `CC BY-SA` e ricopiarle sarebbe ridistribuzione.
///
/// ⚠️ Quindi: possono mancare, possono tardare, e il server può essere
/// irraggiungibile. In tutti e tre i casi resta il quadratino con la posata, e
/// non un rettangolo rotto in mezzo all'elenco.
class _Miniatura extends StatelessWidget {
  const _Miniatura({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final vuota = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.restaurant_rounded,
        size: 18,
        color: theme.colorScheme.outline,
      ),
    );

    if (url == null || url!.isEmpty) return vuota;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url!,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => vuota,
        // 💡 Niente animazione di comparsa: in un elenco che scorre mentre si
        // scrive, farebbe lampeggiare la riga a ogni tasto.
        loadingBuilder: (context, figlio, avanzamento) =>
            avanzamento == null ? figlio : vuota,
      ),
    );
  }
}
