import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/auth_controller.dart';
import '../data/promozioni.dart';

/// 🤝 **Il link «porta un amico», aperto nell'app** — 24/09/2026, P8 di
/// `plan_promozioni.md`.
///
/// Si arriva da `https://…/amico/{codice}` (App Links). ⚠️ Il codice si mette
/// **da parte** nella cache: la registrazione lo ritrova e lo manda al server
/// subito dopo l'iscrizione (`POST /account/amico`). ⛔ Tenerlo solo in memoria
/// vorrebbe dire perderlo se la persona chiude l'app a metà registrazione.
///
/// Chi ha già un account lo collega da qui, se è ancora nei primi 7 giorni (il
/// server lo dice, e noi mostriamo il suo messaggio).
class SchermataAmico extends ConsumerStatefulWidget {
  const SchermataAmico({required this.codice, super.key});

  final String codice;

  @override
  ConsumerState<SchermataAmico> createState() => _SchermataAmicoState();
}

class _SchermataAmicoState extends ConsumerState<SchermataAmico> {
  bool _inCorso = false;
  String? _esito;

  @override
  void initState() {
    super.initState();
    ref
        .read(localCacheProvider)
        .setString(chiaveCodiceAmicoInAttesa, widget.codice.toUpperCase());
  }

  Future<void> _collega() async {
    setState(() => _inCorso = true);

    final errore = await collegaLAmico(
      ref.read(apiClientProvider),
      widget.codice,
    );

    if (!mounted) return;

    if (errore == null) {
      await ref
          .read(localCacheProvider)
          .setString(chiaveCodiceAmicoInAttesa, '');
    }

    setState(() {
      _inCorso = false;
      _esito =
          errore ??
          'Fatto: il tuo account è legato a quello di chi ti ha invitato.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final dentro =
        ref.watch(authControllerProvider).status == AuthStatus.loggedIn;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.group_add_rounded, size: 64),
              const SizedBox(height: Gap.md),
              Text(
                'Un amico ti ha invitato',
                textAlign: TextAlign.center,
                style: tema.textTheme.headlineSmall,
              ),
              const SizedBox(height: Gap.sm),
              Text(
                'Codice amico: ${widget.codice.toUpperCase()}',
                textAlign: TextAlign.center,
                style: tema.textTheme.titleMedium,
              ),
              const SizedBox(height: Gap.md),

              /*
               * ⚠️ **Si dice cosa succede premendo** — 23/09/2026, giro UX.
               *
               * ⛔ Qui c'era il titolo, il codice e il pulsante: si chiedeva di
               * **collegare il proprio account a quello di un'altra persona**
               * senza dire cosa comporti, cosa se ne ricavi, né che è
               * irreversibile.
               *
               * 🚨 E le due regole vere non erano scritte da nessuna parte:
               * `AmicoController` le dichiara — *«una volta sola, e solo nei
               * primi 7 giorni»* — ma chi è iscritto da mesi lo scopriva
               * **premendo**, e si prendeva un rifiuto al posto di una
               * spiegazione.
               *
               * 💡 La frase sull'offerta è **la stessa** di «Porta un amico»:
               * le due facce dello stesso patto devono raccontarlo uguale.
               */
              Text(
                'Collegandoti dici che è stato lui a portarti. Se c\'è '
                'un\'offerta per chi porta un amico, arriva da sola.',
                textAlign: TextAlign.center,
                style: tema.textTheme.bodyMedium,
              ),
              const SizedBox(height: Gap.sm),
              Text(
                'Si può fare una volta sola, entro 7 giorni dall\'iscrizione.',
                textAlign: TextAlign.center,
                style: tema.textTheme.bodySmall?.copyWith(
                  color: tema.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Gap.lg),
              if (_esito != null) ...[
                Text(_esito!, textAlign: TextAlign.center),
                const SizedBox(height: Gap.md),
              ],
              if (dentro) ...[
                FilledButton(
                  onPressed: _inCorso || _esito != null ? null : _collega,
                  child: const Text('Collega il mio account'),
                ),
                const SizedBox(height: Gap.sm),
                TextButton(
                  onPressed: () => context.go(AppRoutes.home),
                  child: const Text('Vai all\'app'),
                ),
              ] else ...[
                FilledButton(
                  onPressed: () => context.go(AppRoutes.register),
                  child: const Text('Crea un account'),
                ),
                const SizedBox(height: Gap.sm),
                TextButton(
                  onPressed: () => context.go(AppRoutes.login),
                  child: const Text('Ho già un account'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
