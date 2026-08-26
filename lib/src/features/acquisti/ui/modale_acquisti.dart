import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/states.dart';
import '../../dashboard/gettoni_controller.dart';
import '../data/listino.dart';

/// La modale che vende l'assistente — 3b-H, 26/08/2026.
///
/// ══ 📌 COME E' STATA CHIESTA ══════════════════════════════════════════════
///
/// *«Mi serve l'interfaccia sotto forma di modale per acquistare gettoni
/// (collegata alla pillola dei gettoni nell'header) e per fare l'abbonamento.
/// Deve essere catchy e invitare gli utenti innanzi tutto ad abbonarsi, poi —
/// se già sono abbonati — ad acquistare altri gettoni»*.
///
/// ══ 🚨 UNA MODALE E NON UNA SCHERMATA, E IL MOTIVO E' COMMERCIALE ═════════
///
/// Ci si arriva **da un momento preciso**: la pillola dei gettoni che sta
/// finendo, o una funzione appena negata. ⛔ Una schermata intera fa perdere il
/// posto in cui si era, e chi torna indietro spesso non ritrova il gesto che
/// stava facendo. 💡 Una modale si chiude e sotto c'è ancora tutto.
///
/// ══ ⚠️ E L'ORDINE NON E' UN GUSTO ═════════════════════════════════════════
///
/// Chi **non** è abbonato vede l'abbonamento grande e i gettoni piccoli;
/// chi lo è vede solo i gettoni. 🚨 Offrire l'abbonamento a chi ce l'ha già è il
/// modo più rapido per fargli credere che non sia attivo.
class ModaleAcquisti {
  const ModaleAcquisti._();

  /// Apre la modale. 💡 Da chiamare ovunque una funzione venga negata.
  static Future<void> mostra(BuildContext context) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => const CorpoAcquisti(),
  );
}

/// Il contenuto, **pubblico di proposito**: lo mostrano sia la modale sia la
/// schermata `/acquisti`.
///
/// 🚨 Due copie dello stesso listino divergerebbero al primo prezzo cambiato, e
/// la copia sbagliata sarebbe quella che il cliente guarda meno — cioè quella
/// che nessuno corregge.
class CorpoAcquisti extends ConsumerStatefulWidget {
  const CorpoAcquisti({this.dentroUnaModale = true, super.key});

  /// ⚠️ Dentro una modale ci si chiude da soli dopo il pagamento; dentro una
  /// schermata no — `pop()` lì porterebbe via la pagina sbagliata.
  final bool dentroUnaModale;

  @override
  ConsumerState<CorpoAcquisti> createState() => _CorpoState();
}

class _CorpoState extends ConsumerState<CorpoAcquisti> {
  /// Quale acquisto sta partendo — per spegnere **solo quel** pulsante.
  ///
  /// ⚠️ Un indicatore globale spegnerebbe anche gli altri, e chi ha toccato per
  /// sbaglio non potrebbe più scegliere il taglio giusto senza riaprire.
  String? _inCorso;

  Future<void> _compra({required String tipo, int? gettoni}) async {
    setState(() => _inCorso = '$tipo${gettoni ?? ''}');

    final errore = await apriIlPagamento(ref, tipo: tipo, gettoni: gettoni);

    if (!mounted) return;

    setState(() => _inCorso = null);

    if (errore != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errore)));

      return;
    }

    /*
     * 🚨 **Si chiude, e si ributtano via i due numeri.** Il pagamento avviene
     * nel browser: quando la persona torna, il webhook potrebbe già essere
     * arrivato — e la pillola dei gettoni con il numero vecchio le direbbe che
     * non è successo niente.
     *
     * ⚠️ Invalidare non basta a garantirlo (il webhook può tardare qualche
     * secondo), ed è il motivo per cui la pagina di ritorno dice «fra qualche
     * secondo» invece di «fatto».
     */
    ref
      ..invalidate(gettoniProvider)
      ..invalidate(listinoProvider);

    if (widget.dentroUnaModale) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final listino = ref.watch(listinoProvider);

    final corpo = listino.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: ErrorState(
          error: ApiClient.unwrapError(e),
          onRetry: () => ref.invalidate(listinoProvider),
        ),
      ),
      data: (l) => ListView(
        padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.xl),
        children: [
          if (!l.abbonato) ...[
            _Insegna(listino: l),
            const SizedBox(height: Gap.lg),
            _BottoneAbbonamento(
              listino: l,
              inCorso: _inCorso == 'abbonamento',
              onTap: () => _compra(tipo: 'abbonamento'),
            ),
            const SizedBox(height: Gap.lg),
            const _Separatore(testo: 'oppure, senza abbonarti'),
            const SizedBox(height: Gap.md),
          ] else ...[
            _GiaAbbonato(listino: l),
            const SizedBox(height: Gap.lg),
            Text(
              'Altri gettoni',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: Gap.xs),
            Text(
              'Servono quando finisci le richieste incluse del mese. '
              'Si comprano una volta e restano: non scadono al rinnovo.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: Gap.md),
          ],

          for (final p in l.pacchetti)
            _CartaPacchetto(
              pacchetto: p,
              migliore: identical(p, l.ilPiuConveniente),
              grande: l.abbonato,
              inCorso: _inCorso == 'gettoni${p.gettoni}',
              onTap: () => _compra(tipo: 'gettoni', gettoni: p.gettoni),
            ),

          const SizedBox(height: Gap.md),
          const _NotaLegale(),
        ],
      ),
    );

    // ⛔ L'altezza fissa vale solo dentro la modale: in una schermata intera
    // lascerebbe un buco sotto, o taglierebbe il contenuto.
    return widget.dentroUnaModale
        ? SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.85,
            child: corpo,
          )
        : corpo;
  }
}

/// L'insegna: cosa ci guadagni, prima di quanto costa.
///
/// 💡 **Prima cosa fa, poi quanto costa.** Chi arriva qui ci arriva perché una
/// funzione gli è stata negata: sapere *cosa* riavrebbe viene prima del prezzo.
/// ⚠️ Una pagina che apre con il listino chiede di decidere prima di aver capito.
class _Insegna extends StatelessWidget {
  const _Insegna({required this.listino});

  final Listino listino;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              color: tema.colorScheme.primary,
              size: 28,
            ),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: Text(
                'L\'IA che ti serve tutti i giorni',
                style: tema.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: Gap.sm),
        /*
         * ══ ⛔ QUI NON SI DICE QUANTE RICHIESTE — 26/08/2026 ═══════════════
         *
         * 📌 *«togli la scritta "150 richieste al mese" non va detto, perché
         * l'abbonamento non fa solo quello»*.
         *
         * 🚨 **Un numero in cima a un'offerta diventa l'offerta.** Chi legge
         * «150 richieste» compra un contatore, lo confronta con i pacchetti di
         * gettoni e fa la divisione — invece di guardare **cosa** si porta a
         * casa. ⚠️ È lo stesso motivo per cui il 16/08 la dotazione inclusa era
         * sparita dalla pillola: è **uso compreso**, non credito da contare.
         *
         * 💡 Il numero resta nell'API (`Listino.chiamateMensili`) perché serve
         * a chi lo cerca — condizioni d'uso, assistenza — ma non è quello che
         * si vende.
         */
        Text(
          'Fotografi il piatto e finisce nel diario, con calorie e macro. '
          'Ogni mattina un consiglio costruito su come hai mangiato, dormito '
          'e ti sei allenato.',
          style: tema.textTheme.bodyMedium?.copyWith(height: 1.35),
        ),
        const SizedBox(height: Gap.md),

        const _Riga(
          icona: Icons.photo_camera_rounded,
          testo: 'Il piatto dalla foto, o da una frase',
        ),
        const _Riga(
          icona: Icons.auto_awesome_outlined,
          testo: 'Il consiglio del giorno, tutti i giorni',
        ),
        /*
         * ⛔ **Il piano alimentare da PDF è uscito da qui** — 26/08/2026.
         * 📌 *«togliamo il riferimento al piano alimentare (ce l'abbiamo ma non
         * voglio spingerlo subito)»*. 💡 La funzione c'è: è una scelta di cosa
         * mettere in vetrina, non una cosa che manca.
         */
        const _Riga(
          icona: Icons.calendar_month_rounded,
          testo: 'Le schede su più giorni, e quante ne vuoi',
        ),
        const _Riga(
          icona: Icons.lock_open_rounded,
          testo: 'E tutto quello che arriva dopo, senza pagare di nuovo',
        ),
      ],
    );
  }
}

class _Riga extends StatelessWidget {
  const _Riga({required this.icona, required this.testo});

  final IconData icona;
  final String testo;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: Row(
        children: [
          Icon(icona, size: 18, color: tema.colorScheme.primary),
          const SizedBox(width: Gap.sm),
          Expanded(child: Text(testo, style: tema.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

/// Il pulsante grande dell'abbonamento — quello che deve saltare all'occhio.
class _BottoneAbbonamento extends StatelessWidget {
  const _BottoneAbbonamento({
    required this.listino,
    required this.inCorso,
    required this.onTap,
  });

  final Listino listino;
  final bool inCorso;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: tema.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(Gap.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                euro(listino.prezzoAbbonamentoCent),
                style: tema.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: tema.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: Gap.xs),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'al mese',
                  style: tema.textTheme.bodyMedium?.copyWith(
                    color: tema.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.xs),
          Text(
            'Tutto compreso, e si rinnova ogni mese.',
            style: tema.textTheme.bodySmall?.copyWith(
              color: tema.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: Gap.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: inCorso ? null : onTap,
              icon: inCorso
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.lock_open_rounded, size: 18),
              label: Text(inCorso ? 'Apro il pagamento…' : 'Attiva ora'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Chi è già abbonato non va convinto: va rassicurato.
class _GiaAbbonato extends StatelessWidget {
  const _GiaAbbonato({required this.listino});

  final Listino listino;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: tema.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(Gap.radius),
      ),
      child: Row(
        children: [
          Icon(
            Icons.verified_rounded,
            color: tema.colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Assistente attivo',
                  style: tema.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: tema.colorScheme.onSecondaryContainer,
                  ),
                ),
                /*
                 * ⚠️ **Nemmeno qui si contano le richieste incluse.** Vale la
                 * stessa regola del 16/08: la dotazione dell'abbonamento è uso
                 * compreso, e mostrarla come un saldo che scende insegna a
                 * risparmiarla — cioè a usare meno l'unica cosa per cui si è
                 * pagato.
                 *
                 * 💡 I gettoni **comprati** invece si dicono: quelli sono suoi,
                 * li ha pagati a parte, e vuole sapere quanti gliene restano.
                 */
                Text(
                  listino.gettoniDisponibili > 0
                      ? '${listino.gettoniDisponibili} gettoni comprati, oltre a quelle incluse'
                      : 'Hai tutto quello che serve. I gettoni servono solo se finisci le richieste incluse.',
                  style: tema.textTheme.bodySmall?.copyWith(
                    color: tema.colorScheme.onSecondaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Un taglio di gettoni.
class _CartaPacchetto extends StatelessWidget {
  const _CartaPacchetto({
    required this.pacchetto,
    required this.migliore,
    required this.grande,
    required this.inCorso,
    required this.onTap,
  });

  final PacchettoGettoni pacchetto;

  /// Se è quello col prezzo per gettone più basso.
  final bool migliore;

  /// Se è la voce principale della modale (chi è già abbonato) o quella di
  /// riserva sotto l'abbonamento.
  final bool grande;

  final bool inCorso;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: Gap.sm),
      color: migliore && grande
          ? tema.colorScheme.surfaceContainerHighest
          : null,
      child: ListTile(
        onTap: inCorso ? null : onTap,
        leading: Icon(
          Icons.toll_outlined,
          color: tema.colorScheme.primary,
          size: grande ? 28 : 22,
        ),
        title: Row(
          children: [
            Text(
              '${pacchetto.gettoni} gettoni',
              style: tema.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (migliore) ...[
              const SizedBox(width: Gap.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: tema.colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'conviene',
                  style: tema.textTheme.labelSmall?.copyWith(
                    color: tema.colorScheme.onTertiaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
        // 💡 Il prezzo per gettone è il numero che fa scegliere, e nessuno ha
        // voglia di calcolarselo.
        subtitle: Text(
          '${pacchetto.nota} · ${_perGettone(pacchetto)} a gettone',
          style: tema.textTheme.bodySmall,
        ),
        trailing: inCorso
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                euro(pacchetto.prezzoCent),
                style: tema.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: tema.colorScheme.primary,
                ),
              ),
      ),
    );
  }

  static String _perGettone(PacchettoGettoni p) {
    final c = p.centPerGettone;

    // ⚠️ Sotto il centesimo si scrive coi decimali: «0 cent» direbbe gratis.
    return c >= 1
        ? '${c.toStringAsFixed(c % 1 == 0 ? 0 : 1).replaceAll('.', ',')} cent'
        : '${c.toStringAsFixed(2).replaceAll('.', ',')} cent';
  }
}

class _Separatore extends StatelessWidget {
  const _Separatore({required this.testo});

  final String testo;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
          child: Text(
            testo,
            style: tema.textTheme.labelSmall?.copyWith(
              color: tema.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

/// ⚠️ **Dire dove si paga non è burocrazia.** Chi tocca «Attiva ora» esce
/// dall'app e finisce in un browser: se non se lo aspetta, la prima reazione è
/// chiudere tutto — e quella è una vendita persa per una frase mancante.
class _NotaLegale extends StatelessWidget {
  const _NotaLegale();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.lock_outline_rounded,
          size: 14,
          color: tema.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: Gap.xs),
        Expanded(
          child: Text(
            'Il pagamento si apre nel browser, su Stripe. La carta non passa '
            'da qui e l\'app non la vede mai.',
            style: tema.textTheme.labelSmall?.copyWith(
              color: tema.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
