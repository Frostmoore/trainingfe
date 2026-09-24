import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../account/data/nome_pubblico.dart';
import '../../account/nome_pubblico_controller.dart';

/// 🔎 **«Trova una persona»** — blocco B3, 24/09/2026.
///
/// 📌 Il committente, il 23/09: *«bisognerà inventarsi un sistema di username
/// per poter scrivere a chiunque»*. E il 24/09, sull'interruttore: *«va messo un
/// toggle nella finestra della chat, in modo che non sia troppo invasivo»*.
///
/// ══ 🚨 PERCHE' L'INTERRUTTORE STA QUI DENTRO, E IN CIMA ═════════════════════
///
/// 💡 È **la stessa domanda vista da due lati**: «chi trovo?» e «mi faccio
/// trovare?». Chi apre questa scheda per cercare qualcuno è la stessa persona
/// che in quel momento capisce cosa vuol dire essere cercabile.
///
/// ⚠️ **In cima e non in fondo**: un interruttore nascosto sotto un elenco di
/// risultati è un interruttore che si trova per accenderlo e non si ritrova più
/// per spegnerlo.
///
/// ⛔ **Nasce spento** (decisione 53.1), e questa scheda è l'unico posto da cui
/// si accende.
class TrovaUnaPersona extends ConsumerStatefulWidget {
  const TrovaUnaPersona({super.key});

  /// Apre la scheda. Torna l'id della conversazione aperta, se ne è nata una.
  static Future<int?> mostra(BuildContext context) => showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const TrovaUnaPersona(),
  );

  @override
  ConsumerState<TrovaUnaPersona> createState() => _TrovaUnaPersonaState();
}

class _TrovaUnaPersonaState extends ConsumerState<TrovaUnaPersona> {
  final _cerca = TextEditingController();

  List<PersonaTrovata> _trovati = const [];
  bool _inCorso = false;
  bool _cercato = false;

  @override
  void dispose() {
    _cerca.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final mio = ref.watch(nomePubblicoProvider);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        Gap.lg,
        0,
        Gap.lg,
        MediaQuery.viewInsetsOf(context).bottom + Gap.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Trova una persona',
            style: tema.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: Gap.sm),

          Text(
            'Si cerca col nome utente, e solo chi ha scelto di farsi trovare. '
            'Gli iscritti li trovano soltanto i loro trainer o la loro palestra.',
            style: tema.textTheme.bodySmall?.copyWith(
              color: tema.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Gap.md),

          mio.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => const SizedBox.shrink(),
            data: _interruttore,
          ),

          const Divider(height: Gap.xl),

          TextField(
            controller: _cerca,
            enabled: !_inCorso,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Nome utente',
              helperText: 'Almeno tre lettere.',
              prefixIcon: Icon(Icons.alternate_email),
            ),
            onSubmitted: (_) => _cercaAdesso(),
          ),
          const SizedBox(height: Gap.sm),

          FilledButton.icon(
            onPressed: _inCorso ? null : _cercaAdesso,
            icon: const Icon(Icons.search),
            label: const Text('Cerca'),
          ),
          const SizedBox(height: Gap.md),

          if (_cercato && _trovati.isEmpty && !_inCorso)
            Text(
              'Nessuno con questo nome. ⚠️ Può anche voler dire che non ha '
              'scelto di farsi trovare.',
              style: tema.textTheme.bodySmall?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),

          for (final persona in _trovati)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundImage: persona.avatar == null
                    ? null
                    : NetworkImage(persona.avatar!),
                child: persona.avatar == null
                    ? Text(persona.nome.characters.first.toUpperCase())
                    : null,
              ),
              title: Text(persona.nome),
              subtitle: Text('@${persona.username}'),
              trailing: const Icon(Icons.chat_bubble_outline),
              onTap: _inCorso ? null : () => _scriviA(persona),
            ),
        ],
      ),
    );
  }

  /// 🔦 L'interruttore, con dentro il nome utente quando c'è.
  ///
  /// ⛔ **Senza un nome non si può accendere**: sarebbe un interruttore che non
  /// fa niente, e chi lo accende crederebbe di essere trovabile. 💡 Quindi al
  /// posto dell'interruttore si mostra cosa manca.
  Widget _interruttore(NomePubblico mio) {
    if (!mio.ceL) {
      return const Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: Icon(Icons.badge_outlined),
          title: Text('Non hai ancora un nome utente'),
          subtitle: Text('Serve per farti trovare: lo scegli dal profilo.'),
        ),
      );
    }

    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      value: mio.trovabile,
      onChanged: _inCorso ? null : (si) => _famiTrovare(si: si),
      title: const Text('Fatti trovare'),
      subtitle: Text(
        mio.trovabile
            ? 'Ti trovano cercando @${mio.username}.'
            : 'Nessuno può trovarti cercando @${mio.username}.',
      ),
    );
  }

  Future<void> _famiTrovare({required bool si}) async {
    setState(() => _inCorso = true);

    final messenger = ScaffoldMessenger.of(context);

    try {
      await ref.read(nomePubblicoActionsProvider).famiTrovare(si: si);
    } on Object catch (errore) {
      messenger.showSnackBar(
        SnackBar(content: Text(ApiClient.unwrapError(errore).message)),
      );
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  Future<void> _cercaAdesso() async {
    setState(() => _inCorso = true);

    final messenger = ScaffoldMessenger.of(context);

    try {
      final trovati = await ref
          .read(nomePubblicoActionsProvider)
          .cerca(_cerca.text);

      if (mounted) setState(() => _trovati = trovati);
    } on Object catch (errore) {
      messenger.showSnackBar(
        SnackBar(content: Text(ApiClient.unwrapError(errore).message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _inCorso = false;
          _cercato = true;
        });
      }
    }
  }

  /// 💬 Apre un filo **di presentazione**: tre messaggi, il limite che c'era già.
  Future<void> _scriviA(PersonaTrovata persona) async {
    setState(() => _inCorso = true);

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final id = await ref.read(nomePubblicoActionsProvider).scriviA(persona.id);

      navigator.pop(id);
    } on Object catch (errore) {
      if (mounted) setState(() => _inCorso = false);

      messenger.showSnackBar(
        SnackBar(content: Text(ApiClient.unwrapError(errore).message)),
      );
    }
  }
}
