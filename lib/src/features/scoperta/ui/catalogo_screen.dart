import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
// 💡 `ThreadScreen` vive dentro `conversations_screen.dart`, non in un file
// proprio: è dove sta oggi, e spostarlo sarebbe una modifica che non c'entra
// niente con la Parte M.
import '../../chat/ui/conversations_screen.dart';
import '../catalogo_controller.dart';
import '../data/scheda_catalogo.dart';

/// Il catalogo di palestre e trainer — Parte M7.4, 18/08/2026.
///
/// ── 🚨 Si apre a chiunque, e mostra qualcosa fin dal primo istante ─────────
///
/// Senza scrivere niente si vede **chi c'è vicino**: è il caso normale quando
/// si apre la schermata. ⚠️ Un catalogo che parte vuoto e aspetta che si digiti
/// è un catalogo in cui metà delle persone non trova niente, perché non sanno
/// cosa cercare — il nome della palestra sotto casa non lo conoscono, è per
/// quello che stanno guardando.
class CatalogoScreen extends ConsumerStatefulWidget {
  const CatalogoScreen({super.key});

  @override
  ConsumerState<CatalogoScreen> createState() => _CatalogoScreenState();
}

class _CatalogoScreenState extends ConsumerState<CatalogoScreen> {
  final _campo = TextEditingController();
  Timer? _attesa;
  String _cercato = '';

  @override
  void dispose() {
    _attesa?.cancel();
    _campo.dispose();
    super.dispose();
  }

  /// 🚨 **Si aspetta che smetta di scrivere.**
  ///
  /// ⚠️ Senza, ogni tasto premuto è una richiesta: il freno del server (30 al
  /// minuto) si esaurirebbe scrivendo «palestra». E ogni chiamata al catalogo
  /// conta una visualizzazione per le schede sponsorizzate — cioè lavoro che
  /// qualcuno paga.
  void _cerca(String testo) {
    _attesa?.cancel();
    _attesa = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _cercato = testo);
    });
  }

  @override
  Widget build(BuildContext context) {
    final risultati = ref.watch(catalogoProvider(_cercato));

    return Scaffold(
      appBar: AppBar(title: const Text('Trova una palestra')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _campo,
              onChanged: _cerca,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Nome, città, o cosa cerchi',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _campo.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _campo.clear();
                          _cerca('');
                        },
                      ),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: risultati.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => const _Vuoto(
                icona: Icons.cloud_off_rounded,
                titolo: 'Non riesco a caricare il catalogo',
                testo: 'Controlla la connessione e riprova.',
              ),
              data: (schede) => schede.isEmpty
                  ? _Vuoto(
                      icona: Icons.travel_explore_rounded,
                      titolo: _cercato.isEmpty
                          ? 'Ancora nessuno qui intorno'
                          : 'Nessun risultato',
                      // 💡 Se non ha detto dove sta, il consiglio utile è
                      // quello — non «riprova più tardi».
                      testo: _cercato.isEmpty
                          ? 'Imposta la tua città dal profilo per vedere chi c\'è vicino a te.'
                          : 'Prova con un altro nome, o con il nome della città.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                      itemCount: schede.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _Scheda(scheda: schede[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Scheda extends ConsumerWidget {
  const _Scheda({required this.scheda});

  final SchedaCatalogo scheda;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: scheda.contattabile ? () => _apri(context, ref) : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    scheda.ePalestra
                        ? Icons.fitness_center_rounded
                        : Icons.person_rounded,
                    size: 20,
                    color: tema.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      scheda.titolo,
                      style: tema.textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  /*
                   * 🚨 **L'etichetta «Sponsorizzato», e non è facoltativa.**
                   *
                   * ⚠️ Presentare a pagamento qualcosa che sembra un risultato
                   * di ricerca è pubblicità occulta. Sta accanto al nome e non
                   * in fondo alla scheda: in fondo si legge dopo aver già
                   * deciso.
                   */
                  if (scheda.sponsorizzato)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: tema.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Sponsorizzato',
                        style: tema.textTheme.labelSmall,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  if (scheda.comune != null)
                    Text(scheda.comune!, style: tema.textTheme.bodySmall),
                  if (scheda.distanzaLeggibile != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      '· ${scheda.distanzaLeggibile}',
                      style: tema.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
              if (scheda.descrizione != null &&
                  scheda.descrizione!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  scheda.descrizione!,
                  style: tema.textTheme.bodyMedium,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              /*
               * 💡 Se non è contattabile lo si dice **qui**, non quando la
               * persona ha già scritto un messaggio che non arriverebbe da
               * nessuna parte.
               */
              if (!scheda.contattabile) ...[
                const SizedBox(height: 8),
                Text(
                  'Non raggiungibile in questo momento.',
                  style: tema.textTheme.bodySmall?.copyWith(
                    color: tema.colorScheme.outline,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _apri(BuildContext context, WidgetRef ref) async {
    final messaggeria = ScaffoldMessenger.of(context);

    try {
      final esito = await ref.read(apriDalCatalogoProvider)(scheda.id);

      if (!context.mounted) return;

      /*
       * 💡 Si dice **prima** quanti messaggi restano — M4.3 — non dopo aver
       * premuto invio. Chi sta per scrivere a una palestra deve sapere che ne
       * ha tre, non scoprirlo al quarto.
       *
       * 🚨 `restanti == null` vuol dire **senza limite**: non si mostra niente.
       */
      if (esito.restanti != null) {
        messaggeria.showSnackBar(
          SnackBar(
            content: Text(
              esito.restanti == 1
                  ? 'Ti resta 1 messaggio di presentazione.'
                  : 'Hai ${esito.restanti} messaggi di presentazione.',
            ),
          ),
        );
      }

      if (!context.mounted) return;

      // 💡 `Navigator.push` come fa il resto della chat: il filo è un
      // dettaglio sopra la schermata, non una sezione.
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              ThreadScreen(id: esito.id, titolo: esito.nome ?? scheda.titolo),
        ),
      );
    } on Object catch (errore) {
      messaggeria.showSnackBar(
        SnackBar(content: Text(ApiClient.unwrapError(errore).message)),
      );
    }
  }
}

class _Vuoto extends StatelessWidget {
  const _Vuoto({
    required this.icona,
    required this.titolo,
    required this.testo,
  });

  final IconData icona;
  final String titolo;
  final String testo;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icona, size: 48, color: tema.colorScheme.outline),
            const SizedBox(height: 12),
            Text(titolo, style: tema.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              testo,
              textAlign: TextAlign.center,
              style: tema.textTheme.bodyMedium?.copyWith(
                color: tema.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
