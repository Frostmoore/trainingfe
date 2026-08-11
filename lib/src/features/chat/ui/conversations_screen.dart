import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/crypto/contenuto_messaggio.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/states.dart';
import '../../auth/auth_controller.dart';
import '../../training/schede_ricevute_controller.dart';
import '../chat_controller.dart';

/// L'elenco delle conversazioni — A7.1.
class ConversationsScreen extends ConsumerWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final elenco = ref.watch(conversationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Messaggi')),
      floatingActionButton: const _NuovoMessaggio(),
      body: elenco.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(conversationsProvider)),
        data: (conversazioni) => conversazioni.isEmpty
            ? EmptyState(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'Nessun messaggio',
                message: 'Qui compaiono le conversazioni col tuo trainer.',
                // 🚨 Il vuoto porta all'azione, non si limita a constatarlo.
                // Prima diceva «se non hai un trainer chiedi in palestra» e
                // finiva lì: chi il trainer ce l'aveva restava comunque senza
                // nessun modo di scrivergli.
                action: FilledButton.icon(
                  onPressed: () => _scegliDestinatario(context, ref),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Scrivi al tuo trainer'),
                ),
              )
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(conversationsProvider),
                child: ListView.builder(
                  itemCount: conversazioni.length,
                  itemBuilder: (context, index) {
                    final c = conversazioni[index];

                    return ListTile(
                      leading: CircleAvatar(child: Text(c.withName.characters.first.toUpperCase())),
                      title: Text(c.withName),
                      subtitle: c.lastMessageAt != null
                          ? Text(DateFormat('d MMM, HH:mm', 'it').format(c.lastMessageAt!))
                          : null,
                      trailing: c.unread > 0
                          ? Badge(label: Text(c.unread.toString()))
                          : const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ThreadScreen(id: c.id, titolo: c.withName),
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

/// Il pulsante per cominciare una conversazione — C22.
///
/// 🚨 **`heroTag` esplicito, qui e su ogni altro FAB dell'app.**
///
/// La shell è un `IndexedStack`: le schede **esistono tutte insieme**
/// nell'albero, anche quelle non visibili. Due `FloatingActionButton` senza tag
/// condividono `<default FloatingActionButton tag>`, e a ogni transizione di
/// rotta Flutter lancia «multiple heroes share the same tag».
///
/// ⚠️ Non si vedeva sull'emulatore: capita durante l'animazione fra due rotte,
/// ed è saltato fuori al primo uso su un telefono vero.
class _NuovoMessaggio extends ConsumerWidget {
  const _NuovoMessaggio();

  @override
  Widget build(BuildContext context, WidgetRef ref) => FloatingActionButton.extended(
    heroTag: 'fab-messaggi',
    onPressed: () => _scegliDestinatario(context, ref),
    icon: const Icon(Icons.edit_outlined),
    label: const Text('Scrivi'),
  );
}

/// Chiede a chi scrivere, apre il filo e ci porta dentro.
///
/// ⚠️ **Con un solo contatto non si chiede niente**: se hai un trainer solo —
/// il caso di quasi tutti — un elenco con una voce sola è un tocco in più per
/// scegliere l'unica cosa scegliibile.
Future<void> _scegliDestinatario(BuildContext context, WidgetRef ref) async {
  final contatti = await ref.read(chatContactsProvider.future).catchError(
    (Object _) => const <ChatContact>[],
  );

  if (!context.mounted) return;

  if (contatti.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Non hai ancora un trainer assegnato. Chiedi in palestra di '
          'collegartene uno.',
        ),
      ),
    );

    return;
  }

  final scelto = contatti.length == 1
      ? contatti.first
      : await showModalBottomSheet<ChatContact>(
          context: context,
          builder: (sheet) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ListTile(title: Text('A chi vuoi scrivere?')),
                for (final c in contatti)
                  ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        c.name.isEmpty ? '?' : c.name.characters.first.toUpperCase(),
                      ),
                    ),
                    title: Text(c.name),
                    subtitle: Text(c.ruolo),
                    onTap: () => Navigator.of(sheet).pop(c),
                  ),
                const SizedBox(height: Gap.sm),
              ],
            ),
          ),
        );

  if (scelto == null || !context.mounted) return;

  try {
    final id = await ref.read(apriConversazioneProvider)(scelto.id);

    if (!context.mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ThreadScreen(id: id, titolo: scelto.name),
      ),
    );
  } on Object catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiClient.unwrapError(error).message)),
      );
    }
  }
}

/// Il filo — A7.2 / A7.3.
class ThreadScreen extends ConsumerStatefulWidget {
  const ThreadScreen({required this.id, required this.titolo, super.key});

  final int id;
  final String titolo;

  @override
  ConsumerState<ThreadScreen> createState() => _ThreadScreenState();
}

class _ThreadScreenState extends ConsumerState<ThreadScreen> {
  final _testo = TextEditingController();
  final _scroll = ScrollController();

  bool _inCorso = false;

  @override
  void dispose() {
    _testo.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _invia() async {
    final testo = _testo.text;

    if (testo.trim().isEmpty) return;

    setState(() => _inCorso = true);
    // Si svuota subito: aspettare la risposta del server per pulire il campo fa
    // sembrare l'app lenta, e chi scrive veloce rischia di rimandare lo stesso
    // messaggio.
    _testo.clear();

    try {
      await ref.read(threadProvider(widget.id).notifier).invia(testo);
      _inFondo();
    } on Object {
      if (mounted) {
        // Il testo torna nel campo: perderlo sarebbe la cosa peggiore.
        _testo.text = testo;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Messaggio non inviato. Riprova.')),
        );
      }
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  /// «Manda una scheda» — S7.3.
  ///
  /// 🎯 Non c'è nessun endpoint di assegnazione, nessun caricamento a parte,
  /// nessun permesso in più: la scheda entra **dentro la busta** come farebbe
  /// una frase, e il server la instrada senza sapere cos'è.
  Future<void> _allega() async {
    final modelli = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      showDragHandle: true,
      builder: (_) => const _SceltaModello(),
    );

    if (modelli == null || !mounted) return;

    setState(() => _inCorso = true);

    try {
      await ref
          .read(threadProvider(widget.id).notifier)
          .inviaContenuto(ContenutoScheda(modelli));
      _inFondo();
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Scheda non inviata. Riprova.')),
        );
      }
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  void _inFondo() {
    if (!_scroll.hasClients) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final messaggi = ref.watch(threadProvider(widget.id));
    final mioId = ref.watch(authControllerProvider).user?.id ?? -1;

    // Ogni volta che arriva un messaggio si scende in fondo: una chat che
    // resta ferma mentre l'altro scrive sembra bloccata.
    ref.listen(threadProvider(widget.id), (prima, dopo) => _inFondo());

    return Scaffold(
      appBar: AppBar(title: Text(widget.titolo)),
      body: Column(
        children: [
          Expanded(
            child: messaggi.when(
              loading: () => const LoadingState(),
              error: (e, _) => ErrorState(
                error: e,
                onRetry: () => ref.invalidate(threadProvider(widget.id)),
              ),
              data: (elenco) => ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.all(Gap.md),
                itemCount: elenco.length,
                itemBuilder: (context, index) {
                  final m = elenco[index];
                  final contenuto = m.contenuto;

                  // 🚨 S7 — una scheda si disegna come una scheda, non come una
                  // nuvoletta con dentro un titolo: ha un pulsante, e quel
                  // pulsante è tutto il punto della fase.
                  if (contenuto is ContenutoScheda) {
                    return _SchedaInChat(messaggio: m, contenuto: contenuto);
                  }

                  return _Bolla(messaggio: m, mio: m.senderId == mioId);
                },
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(Gap.sm),
              child: Row(
                children: [
                  // 🚨 S7 — «allega una scheda». Compare **solo a chi allena**:
                  // l'endpoint dei modelli risponde 403 a un iscritto, e un
                  // pulsante che dà sempre errore fa sembrare rotta tutta
                  // l'applicazione, non solo quel pulsante.
                  if (ref.watch(authControllerProvider).user?.isTrainer ?? false)
                    IconButton(
                      onPressed: _inCorso ? null : _allega,
                      icon: const Icon(Icons.assignment_outlined),
                      tooltip: 'Manda una scheda',
                    ),
                  Expanded(
                    child: TextField(
                      controller: _testo,
                      textCapitalization: TextCapitalization.sentences,
                      maxLength: 4000,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Scrivi un messaggio…',
                        counterText: '',
                      ),
                      onSubmitted: (_) => _invia(),
                    ),
                  ),
                  const SizedBox(width: Gap.sm),
                  IconButton.filled(
                    onPressed: _inCorso ? null : _invia,
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bolla extends StatelessWidget {
  const _Bolla({required this.messaggio, required this.mio});

  final ChatMessage messaggio;
  final bool mio;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment: mio ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: Gap.sm),
        padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.sm),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        decoration: BoxDecoration(
          color: mio ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(Gap.radius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              messaggio.body,
              style: TextStyle(
                color: mio ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
              ),
            ),
            if (messaggio.createdAt != null)
              Text(
                DateFormat('HH:mm').format(messaggio.createdAt!),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: (mio ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant)
                      .withValues(alpha: 0.7),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// L'elenco dei modelli della palestra, da cui il trainer sceglie — S7.3.
class _SceltaModello extends ConsumerWidget {
  const _SceltaModello();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modelli = ref.watch(modelliPalestraProvider);

    return SafeArea(
      child: modelli.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(Gap.lg),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: Text('Non riesco a leggere i modelli.\n$e'),
        ),
        data: (elenco) => elenco.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(Gap.lg),
                child: Text(
                  'Non ci sono modelli pubblicati. Creali dal pannello della '
                  'palestra, poi da qui li mandi a chi vuoi.',
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                itemCount: elenco.length,
                itemBuilder: (context, i) {
                  final m = elenco[i];
                  final esercizi = (m['exercises'] as List?)?.length ?? 0;

                  return ListTile(
                    leading: const Icon(Icons.assignment_outlined),
                    title: Text(m['name']?.toString() ?? 'Scheda'),
                    subtitle: Text(
                      esercizi == 1 ? '1 esercizio' : '$esercizi esercizi',
                    ),
                    onTap: () => Navigator.of(context).pop(m),
                  );
                },
              ),
      ),
    );
  }
}

/// La scheda dentro la conversazione, con «Aggiungi alle mie schede» — S7.4.
///
/// 🚨 **L'importazione è un gesto, non un automatismo.** Una scheda che si
/// aggiunge da sola all'elenco sostituirebbe in silenzio quella che si sta
/// seguendo — e chi si allena vuole sapere **quando** cambia programma.
class _SchedaInChat extends ConsumerWidget {
  const _SchedaInChat({required this.messaggio, required this.contenuto});

  final ChatMessage messaggio;
  final ContenutoScheda contenuto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final gia = ref.watch(schedaGiaSalvataProvider(messaggio.id));

    return Container(
      margin: const EdgeInsets.only(bottom: Gap.sm),
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(Gap.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.assignment_outlined),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Text(
                  contenuto.titolo,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.xs),
          Text(
            contenuto.numeroEsercizi == 1
                ? '1 esercizio'
                : '${contenuto.numeroEsercizi} esercizi',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: Gap.sm),
          gia.when(
            loading: () => const SizedBox(height: 36),
            error: (_, _) => const SizedBox(height: 36),
            data: (salvata) => salvata
                ? Row(
                    children: [
                      const Icon(Icons.check_rounded, size: 18),
                      const SizedBox(width: Gap.xs),
                      Text(
                        'Nelle tue schede',
                        style: theme.textTheme.labelLarge,
                      ),
                    ],
                  )
                : FilledButton.tonal(
                    onPressed: () => ref.read(azioniSchedeProvider).importa(
                      messaggioId: messaggio.id,
                      mittenteId: messaggio.senderId,
                      contenuto: contenuto,
                    ),
                    child: const Text('Aggiungi alle mie schede'),
                  ),
          ),
        ],
      ),
    );
  }
}
