import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../citta_controller.dart';

/// La riga «la tua città» nel profilo, e il foglio per sceglierla — M1.2.
///
/// ── 🚨 Perché è una ricerca e non un campo di testo ────────────────────────
///
/// Perché «Rimini», «rimini» e «Rimini (RN)» sarebbero tre posti diversi, e la
/// vicinanza non troverebbe niente. ⚠️ La normalizzazione esiste sul server
/// (`ChiaveComune`) proprio perché i nomi scritti a mano non si confrontano:
/// lasciare scrivere qui vorrebbe dire buttarla via.
class VoceCitta extends ConsumerWidget {
  const VoceCitta({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final citta = ref.watch(cittaProvider);

    return ListTile(
      leading: const Icon(Icons.location_city_outlined),
      title: const Text('La tua città'),
      subtitle: citta.when(
        loading: () => const Text('…'),
        error: (_, _) => const Text('Non riesco a leggerla'),
        data: (c) => Text(
          c == null
              // 💡 Il sottotitolo dice **a cosa serve**, non «non impostata»:
              // chi legge deve capire cosa ci guadagna a compilarla.
              ? 'Serve a farti trovare palestre e trainer vicino a te'
              : c.attivo
              ? c.esteso
              // ⚠️ Il comune è stato accorpato da un aggiornamento ISTAT: si
              // dice, invece di lasciare la persona fuori da ogni ricerca
              // senza spiegazione.
              : '${c.esteso} · non più esistente, scegline un altro',
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => _scegli(context, ref),
    );
  }

  Future<void> _scegli(BuildContext context, WidgetRef ref) async {
    // 💡 Si prende **prima** dell'`await`: dopo, il `context` potrebbe non
    // essere più nell'albero e usarlo sarebbe un errore che compare solo a chi
    // chiude la schermata mentre salva.
    final messaggeria = ScaffoldMessenger.of(context);

    final scelto = await showModalBottomSheet<Object?>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _FoglioCitta(),
    );

    // 🚨 `null` = ha chiuso il foglio senza scegliere; `_Azzera` = ha premuto
    // «togli». Sono due cose diverse, e confonderle azzererebbe la città a
    // chiunque chiuda il foglio per sbaglio.
    if (scelto == null) return;

    try {
      await ref.read(salvaCittaProvider)(scelto is Comune ? scelto.id : null);
    } catch (_) {
      messaggeria.showSnackBar(
        const SnackBar(content: Text('Non riesco a salvare la città.')),
      );
    }
  }
}

/// Il valore che il foglio restituisce quando si sceglie «togli».
class _Azzera {
  const _Azzera();
}

class _FoglioCitta extends ConsumerStatefulWidget {
  const _FoglioCitta();

  @override
  ConsumerState<_FoglioCitta> createState() => _FoglioCittaState();
}

class _FoglioCittaState extends ConsumerState<_FoglioCitta> {
  Timer? _attesa;
  String _cercato = '';

  @override
  void dispose() {
    _attesa?.cancel();
    super.dispose();
  }

  /// ⚠️ Il campo città parte **mentre si scrive**: senza attesa, digitare
  /// «bologna» sono sette richieste.
  void _cerca(String testo) {
    _attesa?.cancel();
    _attesa = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _cercato = testo);
    });
  }

  @override
  Widget build(BuildContext context) {
    final risultati = ref.watch(ricercaComuniProvider(_cercato));

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              const ListTile(title: Text('Dove ti alleni?')),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  autofocus: true,
                  onChanged: _cerca,
                  decoration: const InputDecoration(
                    hintText: 'Scrivi il nome del tuo comune',
                    prefixIcon: Icon(Icons.search_rounded),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              Expanded(
                child: risultati.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) => const Center(
                    child: Text('Non riesco a cercare i comuni.'),
                  ),
                  data: (comuni) => comuni.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              _cercato.trim().length < 2
                                  ? 'Scrivi almeno due lettere.'
                                  : 'Nessun comune con questo nome.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: comuni.length,
                          itemBuilder: (_, i) => ListTile(
                            title: Text(comuni[i].esteso),
                            onTap: () => Navigator.of(context).pop(comuni[i]),
                          ),
                        ),
                ),
              ),

              /*
               * 🚨 **Si deve poter togliere.**
               *
               * ⚠️ È la differenza fra un dato che si è scelto di dare e uno
               * che non si può più ritirare — e la città non è obbligatoria.
               */
              const Divider(height: 1),
              TextButton.icon(
                onPressed: () => Navigator.of(context).pop(const _Azzera()),
                icon: const Icon(Icons.location_off_outlined),
                label: const Text('Preferisco non dirlo'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
