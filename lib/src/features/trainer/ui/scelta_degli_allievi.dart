import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/ui/states.dart';
import '../data/utente_seguito.dart';
import '../invio_multiplo.dart';
import '../trainer_controller.dart';

/// Il foglio che chiede **a chi** mandare una scheda — 3b-U.1.2.
///
/// 📌 *«Nella finestra delle chat deve poter selezionare tutti i suoi
/// allievi»*.
///
/// ── ⚠️ «Tutti» sta in cima, e non è un vezzo ─────────────────────────────
///
/// Il caso normale di un trainer è mandare la scheda **a tutti**, o quasi.
/// Costringerlo a venti tocchi per farlo è il modo di non farglielo usare mai:
/// dopo due volte torna a mandarla una per una, che è precisamente quello che
/// questa schermata dovrebbe togliere di mezzo.
///
/// ── ⛔ Chi è disattivato non compare ─────────────────────────────────────
///
/// `attivo == false` non vuol dire «cancellato», vuol dire **canale chiuso**
/// (D5). Mandare una scheda dentro un canale chiuso non fallirebbe in modo
/// utile: il trainer vedrebbe un errore tecnico invece di ricordarsi che quel
/// rapporto l'ha sospeso lui.
Future<List<UtenteSeguito>?> scegliGliAllievi(BuildContext context) {
  return showModalBottomSheet<List<UtenteSeguito>>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const _SceltaDegliAllievi(),
  );
}

class _SceltaDegliAllievi extends ConsumerStatefulWidget {
  const _SceltaDegliAllievi();

  @override
  ConsumerState<_SceltaDegliAllievi> createState() =>
      _SceltaDegliAllieviState();
}

class _SceltaDegliAllieviState extends ConsumerState<_SceltaDegliAllievi> {
  final _scelti = <int>{};

  @override
  Widget build(BuildContext context) {
    final utenti = ref.watch(mieiUtentiProvider);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: utenti.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(Gap.lg),
            child: LoadingState(),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(Gap.lg),
            child: ErrorState(
              error: e,
              onRetry: () => ref.invalidate(mieiUtentiProvider),
            ),
          ),
          data: (dati) => _elenco(
            dati.utenti.where((u) => u.attivo).toList(growable: false),
          ),
        ),
      ),
    );
  }

  Widget _elenco(List<UtenteSeguito> attivi) {
    if (attivi.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(Gap.lg),
        child: EmptyState(
          icon: Icons.people_outline_rounded,
          title: 'Nessuno da seguire',
          message:
              'Quando avrai dei tuoi utenti attivi, potrai mandare una scheda '
              'a più persone insieme.',
        ),
      );
    }

    final tutti = _scelti.length == attivi.length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.sm),
          child: Text(
            'A chi mandarla',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),

        // ⚠️ In cima, e con un contorno che lo stacca: è la riga che si cerca.
        CheckboxListTile(
          value: tutti,
          title: const Text('Tutti i miei utenti'),
          subtitle: Text('${attivi.length} persone'),
          onChanged: (_) => setState(() {
            if (tutti) {
              _scelti.clear();
            } else {
              _scelti
                ..clear()
                ..addAll(attivi.map((u) => u.id));
            }
          }),
        ),
        const Divider(height: 1),

        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: attivi.length,
            itemBuilder: (_, i) {
              final persona = attivi[i];

              return CheckboxListTile(
                value: _scelti.contains(persona.id),
                title: Text(persona.nome),
                subtitle: Text(persona.email),
                onChanged: (scelto) => setState(() {
                  if (scelto ?? false) {
                    _scelti.add(persona.id);
                  } else {
                    _scelti.remove(persona.id);
                  }
                }),
              );
            },
          ),
        ),

        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              /*
               * ⛔ Spento con zero scelti, e non «manda a tutti se non scegli
               * niente»: un invio a venti persone non deve poter partire da un
               * tocco distratto.
               */
              onPressed: _scelti.isEmpty
                  ? null
                  : () => Navigator.of(context).pop(
                      attivi
                          .where((u) => _scelti.contains(u.id))
                          .toList(growable: false),
                    ),
              child: Text(
                _scelti.isEmpty
                    ? 'Scegli chi'
                    : 'Manda a ${_scelti.length} '
                          '${_scelti.length == 1 ? 'persona' : 'persone'}',
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Il resoconto: **chi sì e chi no** — 3b-U.1.3.
///
/// ── 🚨 Perché non basta uno «snack» ──────────────────────────────────────
///
/// Con venti invii qualcuno fallisce, ed è normale: rete, chiave mancante,
/// conversazione mai aperta. ⛔ Un «non è riuscito» solo **non dice a chi è
/// arrivata**, e il trainer non ha nessun modo di scoprirlo: rimanderebbe a
/// tutti — e chi l'aveva già ricevuta se la ritrova due volte, con due schede
/// identiche in chat e nessuna idea di quale seguire — oppure a nessuno.
///
/// 💡 Perciò si mostrano i nomi, e si può ritentare **solo i falliti**.
Future<void> mostraIlResoconto(
  BuildContext context,
  List<EsitoInvio> esiti, {
  required Future<void> Function(List<UtenteSeguito>) riprova,
}) {
  final falliti = esiti.where((e) => !e.riuscito).toList(growable: false);
  final riusciti = esiti.length - falliti.length;

  // 💡 Quando è andato tutto bene non si apre niente: un foglio che dice
  // «tutto a posto» è un tocco in più per un'informazione che non serve.
  if (falliti.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Scheda mandata a $riusciti '
          '${riusciti == 1 ? 'persona' : 'persone'}.',
        ),
      ),
    );

    return Future.value();
  }

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (foglio) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.sm),
            child: Text(
              riusciti == 0
                  ? 'Non è arrivata a nessuno'
                  : 'Arrivata a $riusciti su ${esiti.length}',
              style: Theme.of(foglio).textTheme.titleMedium,
            ),
          ),

          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final esito in esiti)
                  ListTile(
                    leading: Icon(
                      esito.riuscito
                          ? Icons.check_circle_outline_rounded
                          : Icons.error_outline_rounded,
                      color: esito.riuscito
                          ? Theme.of(foglio).colorScheme.primary
                          : Theme.of(foglio).colorScheme.error,
                    ),
                    title: Text(esito.persona.nome),
                    subtitle: esito.riuscito ? null : const Text('Non inviata'),
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(Gap.lg),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                /*
                 * 🚨 **Solo i falliti.** Rimandarla a tutti lascerebbe due
                 * schede identiche nella chat di chi l'aveva già ricevuta, e
                 * nessun modo di sapere quale delle due è quella buona.
                 */
                onPressed: () {
                  Navigator.of(foglio).pop();
                  riprova(
                    falliti.map((e) => e.persona).toList(growable: false),
                  );
                },
                child: Text(
                  'Riprova con ${falliti.length} '
                  '${falliti.length == 1 ? 'persona' : 'persone'}',
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
