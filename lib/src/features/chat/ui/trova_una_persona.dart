import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../account/data/nome_pubblico.dart';
import '../../account/nome_pubblico_controller.dart';
import '../../scoperta/catalogo_controller.dart';
import '../../scoperta/data/scheda_catalogo.dart';

/// 🔎 **«Trova qualcuno»** — blocco B3 (24/09/2026), allargato il 24/09 con le
/// schede pubbliche.
///
/// 📌 Il committente, il 23/09: *«bisognerà inventarsi un sistema di username
/// per poter scrivere a chiunque»*. E il 24/09, sul catalogo: *«per il momento
/// mettiamole semplicemente che si mostrano tutte nella ricerca della chat, con
/// un criterio di vicinanza»*.
///
/// ══ 🚨 DUE DOMANDE DIVERSE, UNA PORTA SOLA ══════════════════════════════════
///
/// | Domanda | Come si risponde |
/// |---|---|
/// | *«dov'è finita quella persona?»* | col **nome utente**, che si sa già |
/// | *«chi c'è vicino a me?»* | con le **schede pubbliche**, per vicinanza |
///
/// ⛔ Prima erano due icone separate nei Messaggi, e la seconda portava a una
/// schermata che **si apriva vuota** finché non cercavi. 💡 Adesso le palestre e
/// i trainer si vedono **appena apri**, senza scrivere niente: è la risposta
/// giusta a una domanda che uno non sa ancora come formulare.
///
/// ══ ⚠️ LA RICERCA E' UNA SOLA, E PARTE AL TOCCO ════════════════════════════
///
/// ⛔ **Niente filtro a ogni tasto.** Ogni chiamata al catalogo conta una
/// visualizzazione per le schede sponsorizzate — cioè una riga di fattura — e
/// far partire una richiesta per ogni lettera vorrebbe dire far pagare
/// a qualcuno i ripensamenti di chi scrive.
///
/// ══ 🚨 L'INTERRUTTORE STA QUI DENTRO, E IN CIMA ════════════════════════════
///
/// 💡 È **la stessa domanda vista da due lati**: «chi trovo?» e «mi faccio
/// trovare?». ⚠️ In cima e non in fondo: un interruttore nascosto sotto un
/// elenco di risultati si trova per accenderlo e non si ritrova per spegnerlo.
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

  /*
   * 🚨 **Il testo con cui il catalogo è stato cercato, non quello nel campo.**
   *
   * ⛔ Guardando `_cerca.text` l'elenco si rifarebbe a ogni lettera: una
   * richiesta per tasto, e una visualizzazione fatturata per ognuna. 💡 Questo
   * cambia **solo** quando si tocca «Cerca».
   */
  String _cercatoNelCatalogo = '';

  @override
  void dispose() {
    _cerca.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final mio = ref.watch(nomePubblicoProvider);
    final schede = ref.watch(catalogoProvider(_cercatoNelCatalogo));

    return ConstrainedBox(
      /*
       * ⚠️ **Un tetto all'altezza, o la scheda va in overflow.** Con l'elenco
       * dentro il contenuto non sta più in una colonna che cresce: si scorre.
       */
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          Gap.lg,
          0,
          Gap.lg,
          MediaQuery.viewInsetsOf(context).bottom + Gap.lg,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              'Trova qualcuno',
              style: tema.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: Gap.sm),

            Text(
              'Le palestre e i trainer che hanno una scheda pubblica si vedono '
              'qui sotto, dai più vicini. Col nome utente trovi anche le '
              'persone: solo chi ha scelto di farsi trovare, e gli iscritti '
              'soltanto i loro trainer o la loro palestra.',
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
                labelText: 'Nome utente, palestra o città',
                helperText: 'Per il nome utente servono almeno tre lettere.',
                prefixIcon: Icon(Icons.search),
              ),
              onSubmitted: (_) => _cercaAdesso(),
            ),
            const SizedBox(height: Gap.sm),

            FilledButton.icon(
              onPressed: _inCorso ? null : _cercaAdesso,
              icon: const Icon(Icons.search),
              label: const Text('Cerca'),
            ),
            const SizedBox(height: Gap.lg),

            // ── 👤 Le persone trovate col nome utente ───────────────────────
            if (_cercato) ...[
              _Titoletto(testo: 'Persone', tema: tema),

              if (_trovati.isEmpty && !_inCorso)
                Padding(
                  padding: const EdgeInsets.only(bottom: Gap.md),
                  child: Text(
                    'Nessuno con questo nome utente. ⚠️ Può anche voler dire '
                    'che non ha scelto di farsi trovare.',
                    style: tema.textTheme.bodySmall?.copyWith(
                      color: tema.colorScheme.onSurfaceVariant,
                    ),
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

              const SizedBox(height: Gap.md),
            ],

            // ── 🏋️ Le schede pubbliche, per vicinanza ───────────────────────
            _Titoletto(
              testo: _cercatoNelCatalogo.isEmpty
                  ? 'Palestre e trainer vicino a te'
                  : 'Palestre e trainer',
              tema: tema,
            ),

            schede.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: Gap.md),
                child: LinearProgressIndicator(),
              ),

              /*
               * ⚠️ **Un errore qui non deve svuotare la scheda.** La ricerca
               * per nome utente è un'altra cosa e continua a funzionare: se il
               * catalogo non risponde, si dice e basta.
               */
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: Gap.md),
                child: Text(
                  ApiClient.unwrapError(e).message,
                  style: tema.textTheme.bodySmall?.copyWith(
                    color: tema.colorScheme.error,
                  ),
                ),
              ),
              data: (elenco) => elenco.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: Gap.md),
                      child: Text(
                        _cercatoNelCatalogo.isEmpty
                            ? 'Ancora nessuna palestra o trainer con una scheda '
                                  'pubblica.'
                            : 'Nessuna palestra o trainer con questo nome.',
                        style: tema.textTheme.bodySmall?.copyWith(
                          color: tema.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        for (final scheda in elenco)
                          _RigaDelCatalogo(
                            scheda: scheda,
                            spenta: _inCorso,
                            onTap: () => _scriviAllaScheda(scheda),
                          ),
                      ],
                    ),
            ),
          ],
        ),
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

  /// 🔍 **Un tocco solo cerca tutte e due le cose.**
  ///
  /// ⚠️ Il nome utente vuole almeno tre lettere e il catalogo no: quindi con
  /// meno di tre si filtrano **solo** le schede, invece di dire «troppo corto»
  /// e non fare niente.
  Future<void> _cercaAdesso() async {
    final testo = _cerca.text.trim();

    setState(() {
      _inCorso = true;
      _cercatoNelCatalogo = testo;
    });

    final messenger = ScaffoldMessenger.of(context);

    if (testo.length < 3) {
      setState(() {
        _inCorso = false;
        _cercato = false;
        _trovati = const [];
      });

      return;
    }

    try {
      final trovati = await ref
          .read(nomePubblicoActionsProvider)
          .cerca(testo);

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

  /// 💬 Lo stesso, ma partendo da una scheda.
  ///
  /// 🚨 Si manda **l'id della scheda**, non quello di una persona: chi sia il
  /// destinatario lo decide il server. ⛔ Altrimenti il catalogo — che è
  /// pubblico — pubblicherebbe gli identificativi di tutti i titolari.
  Future<void> _scriviAllaScheda(SchedaCatalogo scheda) async {
    if (!scheda.contattabile) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Questa scheda non ha nessuno a cui scrivere.'),
        ),
      );

      return;
    }

    setState(() => _inCorso = true);

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final esito = await ref.read(apriDalCatalogoProvider)(scheda.id);

      navigator.pop(esito.id);
    } on Object catch (errore) {
      if (mounted) setState(() => _inCorso = false);

      messenger.showSnackBar(
        SnackBar(content: Text(ApiClient.unwrapError(errore).message)),
      );
    }
  }
}

class _Titoletto extends StatelessWidget {
  const _Titoletto({required this.testo, required this.tema});

  final String testo;
  final ThemeData tema;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Gap.sm),
    child: Text(
      testo.toUpperCase(),
      style: tema.textTheme.labelSmall?.copyWith(
        color: tema.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    ),
  );
}

/// Una scheda pubblica, nell'elenco.
///
/// 🚨 **Lo sponsorizzato si etichetta, mai si mimetizza**: presentare a
/// pagamento qualcosa che sembra un risultato di ricerca è pubblicità occulta.
/// ⏳ Oggi non ce ne sono — le campagne sono spente dal 23/09 — ma l'etichetta
/// c'è già, così il giorno che tornano nessuno deve ricordarsi di aggiungerla.
class _RigaDelCatalogo extends StatelessWidget {
  const _RigaDelCatalogo({
    required this.scheda,
    required this.spenta,
    required this.onTap,
  });

  final SchedaCatalogo scheda;
  final bool spenta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    final sotto = [
      scheda.ePalestra ? 'Palestra' : 'Trainer',
      if (scheda.comune != null) scheda.comune!,
      if (scheda.distanzaLeggibile != null) scheda.distanzaLeggibile!,
    ].join(' · ');

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        child: Icon(
          scheda.ePalestra ? Icons.fitness_center : Icons.sports_outlined,
        ),
      ),
      title: Row(
        children: [
          Flexible(child: Text(scheda.titolo)),
          if (scheda.sponsorizzato) ...[
            const SizedBox(width: Gap.sm),
            Chip(
              label: const Text('Sponsorizzata'),
              labelStyle: tema.textTheme.labelSmall,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
            ),
          ],
        ],
      ),
      subtitle: Text(sotto),
      trailing: const Icon(Icons.chat_bubble_outline),
      onTap: spenta ? null : onTap,
    );
  }
}
