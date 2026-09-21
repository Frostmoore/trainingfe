import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/intestazione_app.dart';
import '../data/promozioni.dart';

/// 🎁 **Le offerte per te** — 24/09/2026, P8 di `plan_promozioni.md`.
///
/// 📌 Opzione 38: *«Dove si vede: nella pagina "Offerta per te" dell'app»*.
///
/// | Parte | Cosa fa |
/// |---|---|
/// | «Hai un codice?» | verifica un codice; se regala qualcosa, lo si riscatta da lì |
/// | l'elenco | le offerte che il server dice di mostrare (e quelle già tue) |
///
/// ⚠️ Gli sconti **non** si usano da qui: si applicano da soli al pagamento. La
/// schermata lo dice, così nessuno cerca un tasto «usa» che non c'è.
class SchermataOfferte extends ConsumerStatefulWidget {
  const SchermataOfferte({super.key, this.codiceIniziale});

  /// Un codice arrivato da fuori (un link), da verificare subito.
  final String? codiceIniziale;

  @override
  ConsumerState<SchermataOfferte> createState() => _SchermataOfferteState();
}

class _SchermataOfferteState extends ConsumerState<SchermataOfferte> {
  late final TextEditingController _codice = TextEditingController(
    text: widget.codiceIniziale ?? '',
  );

  bool _inCorso = false;
  String? _esito;
  Offerta? _trovata;

  @override
  void initState() {
    super.initState();

    if ((widget.codiceIniziale ?? '').isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _verifica());
    }
  }

  @override
  void dispose() {
    _codice.dispose();
    super.dispose();
  }

  Future<void> _verifica() async {
    if (_codice.text.trim().isEmpty) return;

    setState(() {
      _inCorso = true;
      _esito = null;
      _trovata = null;
    });

    final risposta = await verificaIlCodice(ref, _codice.text);

    if (!mounted) return;

    setState(() {
      _inCorso = false;
      _trovata = risposta.offerta;
      _esito = risposta.errore;
    });
  }

  Future<void> _riscatta(Offerta offerta) async {
    setState(() => _inCorso = true);

    final risposta = await riscatta(ref, offerta.codice);

    if (!mounted) return;

    setState(() => _inCorso = false);
    ref.invalidate(offertePerTeProvider);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          risposta.errore ??
              (risposta.gettoni > 0
                  ? 'Hai ricevuto ${risposta.gettoni} gettoni.'
                  : 'Fatto: l\'offerta è tua.'),
        ),
      ),
    );

    if (risposta.errore == null) {
      setState(() => _trovata = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final offerte = ref.watch(offertePerTeProvider);
    final tema = Theme.of(context);

    return Scaffold(
      appBar: const IntestazioneApp(titolo: 'Offerte per te'),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(offertePerTeProvider),
        child: ListView(
          padding: const EdgeInsets.all(Gap.lg),
          children: [
            Text('Hai un codice?', style: tema.textTheme.titleMedium),
            const SizedBox(height: Gap.sm),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codice,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      hintText: 'Scrivilo qui',
                      prefixIcon: Icon(Icons.confirmation_number_outlined),
                    ),
                    onSubmitted: (_) => _verifica(),
                  ),
                ),
                const SizedBox(width: Gap.sm),
                FilledButton(
                  onPressed: _inCorso ? null : _verifica,
                  child: const Text('Verifica'),
                ),
              ],
            ),
            if (_esito != null) ...[
              const SizedBox(height: Gap.sm),
              Text(
                _esito!,
                style: tema.textTheme.bodyMedium?.copyWith(
                  color: tema.colorScheme.error,
                ),
              ),
            ],
            if (_trovata != null) ...[
              const SizedBox(height: Gap.md),
              _SchedaOfferta(
                offerta: _trovata!,
                inCorso: _inCorso,
                onRiscatta: _riscatta,
                daCodice: true,
              ),
            ],
            const SizedBox(height: Gap.lg),
            Text('Le tue offerte', style: tema.textTheme.titleMedium),
            const SizedBox(height: Gap.sm),
            offerte.when(
              data: (elenco) => elenco.isEmpty
                  ? Text(
                      'In questo momento non ci sono offerte per te.',
                      style: tema.textTheme.bodyMedium,
                    )
                  : Column(
                      children: [
                        for (final o in elenco)
                          Padding(
                            padding: const EdgeInsets.only(bottom: Gap.md),
                            child: _SchedaOfferta(
                              offerta: o,
                              inCorso: _inCorso,
                              onRiscatta: _riscatta,
                            ),
                          ),
                      ],
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const Text(
                'Non riesco a leggere le offerte. Tira giù per riprovare.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SchedaOfferta extends StatelessWidget {
  const _SchedaOfferta({
    required this.offerta,
    required this.inCorso,
    required this.onRiscatta,
    this.daCodice = false,
  });

  final Offerta offerta;
  final bool inCorso;
  final Future<void> Function(Offerta) onRiscatta;

  /// Trovata col codice: se si usa pagando, lo si ricorda al pagamento.
  final bool daCodice;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(offerta.nome, style: tema.textTheme.titleMedium),
            const SizedBox(height: Gap.xs),
            Text(offerta.cosa, style: tema.textTheme.bodyLarge),
            if ((offerta.descrizione ?? '').isNotEmpty) ...[
              const SizedBox(height: Gap.xs),
              Text(offerta.descrizione!, style: tema.textTheme.bodyMedium),
            ],
            if (offerta.scadeIl != null) ...[
              const SizedBox(height: Gap.xs),
              Text(
                'Fino al ${DateFormat('d/M/y').format(offerta.scadeIl!)}',
                style: tema.textTheme.bodySmall,
              ),
            ],
            if (offerta.siUsaPagando) ...[
              const SizedBox(height: Gap.sm),
              Text(
                daCodice && !offerta.inSospeso
                    ? 'Per lo sconto, scrivi questo codice quando paghi.'
                    : 'Lo sconto si applica da solo al prossimo pagamento.',
                style: tema.textTheme.bodySmall,
              ),
            ],
            if (offerta.riscattabile) ...[
              const SizedBox(height: Gap.md),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: inCorso ? null : () => onRiscatta(offerta),
                  icon: const Icon(Icons.card_giftcard_rounded),
                  label: const Text('Riscatta'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
