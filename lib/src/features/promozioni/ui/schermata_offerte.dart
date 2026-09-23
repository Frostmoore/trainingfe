import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/intestazione_app.dart';
import '../data/promozioni.dart';

/// 🎁 **Le offerte per te** — 24/09/2026, P8 di `plan_promozioni.md`.
///
/// 📌 Opzione 38: *«Dove si vede: nella pagina "Offerta per te" dell'app»*.
///
/// ⛔ **Niente codici sconto** (24/09/2026): 📌 *«il codice sconto non deve
/// esistere, le promo si attivano solo in automatico o con il link di
/// attivazione»*. Qui non si scrive niente:
///
/// | Parte | Da dove arriva |
/// |---|---|
/// | l'offerta in cima | un **link** (`…/promo/{codice}`) o il **tocco su una notifica** — `codiceIniziale`, o quella messa da parte prima dell'accesso |
/// | l'elenco | le offerte che il server dice di mostrare, e quelle già attivate |
///
/// ⚠️ Gli sconti **non** si usano da qui: si applicano da soli al pagamento. La
/// schermata lo dice, così nessuno cerca un tasto «usa» che non c'è.
class SchermataOfferte extends ConsumerStatefulWidget {
  const SchermataOfferte({super.key, this.codiceIniziale});

  /// L'offerta di un link o di una notifica, da mostrare in cima.
  final String? codiceIniziale;

  @override
  ConsumerState<SchermataOfferte> createState() => _SchermataOfferteState();
}

class _SchermataOfferteState extends ConsumerState<SchermataOfferte> {
  bool _inCorso = false;
  String? _esito;
  Offerta? _dalLink;

  @override
  void initState() {
    super.initState();

    /*
     * 💡 Il codice arriva dal percorso, o dalla cache se il link era stato
     * aperto **prima dell'accesso** (`SchermataPromo`): in quel caso si usa una
     * volta sola e si toglie, o ricomparirebbe per sempre.
     */
    final cache = ref.read(localCacheProvider);
    final inAttesa = cache.getString(chiaveOffertaInAttesa) ?? '';
    final codice = (widget.codiceIniziale ?? '').isNotEmpty
        ? widget.codiceIniziale!
        : inAttesa;

    if (inAttesa.isNotEmpty) cache.setString(chiaveOffertaInAttesa, '');

    if (codice.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _carica(codice));
    }
  }

  Future<void> _carica(String codice) async {
    setState(() => _inCorso = true);

    final risposta = await offertaDelLink(ref, codice);

    if (!mounted) return;

    setState(() {
      _inCorso = false;
      _dalLink = risposta.offerta;
      _esito = risposta.errore;
    });
  }

  Future<void> _attiva(Offerta offerta) async {
    setState(() => _inCorso = true);

    final risposta = await attiva(ref, offerta.codice);

    if (!mounted) return;

    setState(() => _inCorso = false);
    ref.invalidate(offertePerTeProvider);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          risposta.errore ??
              (risposta.gettoni > 0
                  ? 'Hai ricevuto ${risposta.gettoni} gettoni.'
                  : risposta.scontoPronto
                  ? 'Attivata: lo sconto si applica da solo al prossimo pagamento.'
                  : 'Fatto: l\'offerta è tua.'),
        ),
      ),
    );

    if (risposta.errore == null) {
      setState(() => _dalLink = null);
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
            if (_esito != null) ...[
              Text(
                _esito!,
                style: tema.textTheme.bodyMedium?.copyWith(
                  color: tema.colorScheme.error,
                ),
              ),
              const SizedBox(height: Gap.lg),
            ],
            if (_dalLink != null) ...[
              _SchedaOfferta(
                offerta: _dalLink!,
                inCorso: _inCorso,
                onAttiva: _attiva,
              ),
              const SizedBox(height: Gap.lg),
            ],
            Text('Le tue offerte', style: tema.textTheme.titleMedium),
            const SizedBox(height: Gap.sm),
            offerte.when(
              data: (elenco) => elenco.isEmpty
                  ? const _NessunaOfferta()
                  : Column(
                      children: [
                        for (final o in elenco)
                          Padding(
                            padding: const EdgeInsets.only(bottom: Gap.md),
                            child: _SchedaOfferta(
                              offerta: o,
                              inCorso: _inCorso,
                              onAttiva: _attiva,
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
    required this.onAttiva,
  });

  final Offerta offerta;
  final bool inCorso;
  final Future<void> Function(Offerta) onAttiva;

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
                offerta.attivabile
                    ? 'Attivala: poi lo sconto si applica da solo al prossimo pagamento.'
                    : 'Lo sconto si applica da solo al prossimo pagamento.',
                style: tema.textTheme.bodySmall,
              ),
            ],
            if (offerta.attivabile) ...[
              const SizedBox(height: Gap.md),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: inCorso ? null : () => onAttiva(offerta),
                  icon: const Icon(Icons.card_giftcard_rounded),
                  label: const Text('Attiva'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Lo stato vuoto delle offerte — 23/09/2026, dal giro UX.
///
/// ⛔ **Prima era una riga sola**: *«In questo momento non ci sono offerte per
/// te»*, sotto un titolo, con duemila pixel di bianco sotto. ⚠️ Non è solo
/// spoglia: non dice **cosa sia** un'offerta né **come** ne arrivino, e chi apre
/// questa voce lo fa proprio per scoprirlo. Una schermata che risponde «no» a
/// una domanda che non ha spiegato sembra rotta.
///
/// 💡 Stessa forma degli altri vuoti dell'app (icona, titolo, una frase che
/// dice cosa fare): vedi `_Vuoto` nel catalogo e in «Esercizi». ⚠️ Non è un
/// componente condiviso perché non ne esiste uno — ogni schermata ha il suo, ed
/// è debito noto, non una scelta.
class _NessunaOfferta extends StatelessWidget {
  const _NessunaOfferta();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(
            Icons.card_giftcard_outlined,
            size: 48,
            color: tema.colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text('Nessuna offerta, per ora', style: tema.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            'Le offerte arrivano da sole: quando porti un amico, quando la tua '
            'palestra ne prepara una, o quando ne facciamo una per tutti. '
            'Non c\'è niente da cercare.',
            textAlign: TextAlign.center,
            style: tema.textTheme.bodyMedium?.copyWith(
              color: tema.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}
