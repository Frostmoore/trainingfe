import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/ui/intestazione_app.dart';
import '../data/inviti_ricevuti.dart';

/// ✉️ **«I tuoi inviti»** — voce 62.6, 28/09/2026.
///
/// ══ 📌 PERCHE' ESISTE ═════════════════════════════════════════════════════
///
/// ⛔ Fino al 28/09 un invito si poteva accettare **solo dal link nella mail**.
/// 🚨 Chi la perdeva non aveva nessuna strada, e il DMARC del dominio è in
/// `p=none` da ieri: quelle mail possono finire nello spam.
///
/// 💡 Ora la notifica «Hai un invito» porta **qui**, e qui l'app se li va a
/// prendere da sola.
///
/// ══ 🔑 I TRE STATI, E PERCHE' NESSUNO E' UN ERRORE ════════════════════════
///
/// | Cosa vede | Quando |
/// |---|---|
/// | l'elenco | tutto a posto |
/// | *«conferma il tuo indirizzo»* col bottone | il server ha risposto **403** |
/// | *«nessun invito»* | l'elenco è vuoto |
///
/// 🚨 **Il 403 non si mostra come un guasto.** ⛔ «Qualcosa è andato storto»
/// manderebbe a cercare un problema che non c'è: la persona deve solo confermare
/// l'indirizzo, e il bottone glielo fa fare in un tocco.
class SchermataInvitiRicevuti extends ConsumerWidget {
  const SchermataInvitiRicevuti({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final esito = ref.watch(invitiRicevutiProvider);

    return Scaffold(
      appBar: const IntestazioneApp(titolo: 'I tuoi inviti'),
      body: esito.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _Messaggio(
          icona: Icons.wifi_off_outlined,
          titolo: 'Non riusciamo a controllare',
          testo: 'Riprova fra poco: gli inviti restano validi.',
          azione: 'Riprova',
          onAzione: () => ref.invalidate(invitiRicevutiProvider),
        ),
        data: (dati) {
          if (dati.serveVerificare) return const _ConfermaLIndirizzo();

          if (dati.inviti.isEmpty) {
            return const _Messaggio(
              icona: Icons.mail_outline,
              titolo: 'Nessun invito',
              testo:
                  'Quando una palestra o un trainer ti invita, lo trovi qui.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: dati.inviti.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _UnInvito(invito: dati.inviti[i]),
          );
        },
      ),
    );
  }
}

/// 📧 Lo stato «devi confermare l'indirizzo», col bottone che lo risolve.
class _ConfermaLIndirizzo extends ConsumerStatefulWidget {
  const _ConfermaLIndirizzo();

  @override
  ConsumerState<_ConfermaLIndirizzo> createState() =>
      _ConfermaLIndirizzoState();
}

class _ConfermaLIndirizzoState extends ConsumerState<_ConfermaLIndirizzo> {
  bool _sto = false;
  bool? _andata;

  @override
  Widget build(BuildContext context) {
    final colori = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mark_email_unread_outlined, size: 48, color: colori.primary),
            const SizedBox(height: 16),

            Text(
              'Conferma il tuo indirizzo',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            Text(
              'Per farti vedere gli inviti dobbiamo essere sicuri che questo indirizzo '
              'sia davvero tuo. Ti mandiamo una mail con un link: un tocco e hai finito.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            if (_andata == true) ...[
              Text(
                '✅ Mail mandata. Controlla la posta — anche nello spam.',
                style: TextStyle(color: colori.primary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => ref.invalidate(invitiRicevutiProvider),
                child: const Text('Ho confermato, ricontrolla'),
              ),
            ] else ...[
              FilledButton(
                onPressed: _sto ? null : _chiedi,
                child: Text(_sto ? 'Un momento…' : 'Mandami la mail'),
              ),

              if (_andata == false)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'Non è partita. Riprova fra qualche minuto.',
                    style: TextStyle(color: colori.error),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],

            const SizedBox(height: 32),

            /*
             * 🔑 **Si dice che l'accesso non dipende da questo**, ed è la voce 63
             * applicata a una schermata: ⛔ chi legge «conferma il tuo indirizzo»
             * teme di essere sul punto di perdere l'account, e quella paura è
             * esattamente quello che fa abbandonare.
             */
            Text(
              '⚠️ Non serve per entrare: continui a usare l\'app come sempre. '
              'Serve solo a farti vedere gli inviti.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colori.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _chiedi() async {
    setState(() => _sto = true);

    final andata = await chiediLaMailDiConferma(ref);

    if (!mounted) return;

    setState(() {
      _sto = false;
      _andata = andata;
    });
  }
}

/// 🎟️ Un invito, con chi lo manda e quanto resta.
class _UnInvito extends StatelessWidget {
  const _UnInvito({required this.invito});

  final InvitoRicevuto invito;

  @override
  Widget build(BuildContext context) {
    final colori = Theme.of(context).colorScheme;
    final giorni = invito.giorniRimasti;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  invito.tipo == TipoDiInvito.palestra
                      ? Icons.fitness_center
                      : Icons.person_outline,
                  color: colori.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    invito.da,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Text(
              invito.tipo == TipoDiInvito.palestra
                  ? 'Ti ha invitato a iscriverti.'
                  : 'Ti ha invitato a farti seguire.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),

            if (giorni != null) ...[
              const SizedBox(height: 4),
              Text(
                giorni <= 0
                    ? 'Scade oggi'
                    : giorni == 1
                    ? 'Scade domani'
                    : 'Scade fra $giorni giorni',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: giorni <= 1 ? colori.error : colori.onSurfaceVariant,
                ),
              ),
            ],

            const SizedBox(height: 12),

            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                /*
                 * 🔑 **Si va alla schermata che esiste già**, quella del link:
                 * mostra chi invita, cosa comporta accettare, e fa accettare.
                 * ⛔ Riscriverla qui vorrebbe dire due strade per lo stesso
                 * gesto, e quella meno usata diverge per prima.
                 */
                onPressed: () => context.push(
                  '${invito.tipo == TipoDiInvito.palestra ? AppRoutes.invito : AppRoutes.invitoTrainer}'
                  '/${invito.codice}',
                ),
                child: const Text('Apri'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 💬 Un messaggio al centro, con un'azione facoltativa.
class _Messaggio extends StatelessWidget {
  const _Messaggio({
    required this.icona,
    required this.titolo,
    required this.testo,
    this.azione,
    this.onAzione,
  });

  final IconData icona;
  final String titolo;
  final String testo;
  final String? azione;
  final VoidCallback? onAzione;

  @override
  Widget build(BuildContext context) {
    final colori = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icona, size: 48, color: colori.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              titolo,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              testo,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colori.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (azione != null && onAzione != null) ...[
              const SizedBox(height: 20),
              FilledButton(onPressed: onAzione, child: Text(azione!)),
            ],
          ],
        ),
      ),
    );
  }
}
