import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../health/ui/widgets/collega_un_dispositivo.dart';
import '../../../training/avvia_un_allenamento.dart';

/// ➕ Il tasto che aggiunge tutto — 08/09/2026.
///
/// 📌 Il committente: *«Mi serve un tasto floating sulla pagina Oggi (in basso a
/// destra di colore verde con un + in mezzo - icona, non emoji) che serva ad
/// aggiungere tutto quello che si può aggiungere»*.
///
/// ══ 🚨 PERCHÉ UN FOGLIO E NON UN VENTAGLIO DI PALLINI ═════════════════════
///
/// ⛔ Il «speed dial» — i bottoncini che si aprono a ventaglio sopra il tasto —
/// regge **tre o quattro voci**. Qui ce ne sono **sei**, con nomi lunghi
/// («Piano alimentare», «Integratore alimentare») che in una pallina non ci
/// stanno: si finirebbe con sei icone da indovinare.
///
/// 💡 Un foglio in basso le mostra con **nome e spiegazione**, va a capo da
/// solo, e lascia spazio a quella disattivata per dire *perché* lo è.
class AggiungiQualcosa extends ConsumerWidget {
  const AggiungiQualcosa({super.key});

  /// ⚠️ **Il verde è chiesto, e non viene dal tema della palestra.**
  ///
  /// 🚨 Questa app è white-label: quasi tutto prende il colore del cliente, e
  /// questo tasto **no**. È una scelta esplicita — 📌 *«di colore verde»* — e va
  /// saputa, perché su una palestra col branding rosso o arancio questo sarà
  /// l'unico elemento verde dello schermo.
  ///
  /// 💡 Il tono è scuro abbastanza da reggere un'icona bianca sopra: un verde
  /// più chiaro avrebbe costretto a un'icona scura, che su uno sfondo colorato
  /// si legge peggio.
  static const verde = Color(0xFF2E7D32);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FloatingActionButton(
      // 💡 `heroTag` esplicito: due FAB in due schede della stessa `Navigator`
      // con lo stesso tag di serie fanno esplodere l'animazione di transizione.
      heroTag: 'fab-aggiungi',
      backgroundColor: verde,
      foregroundColor: Colors.white,
      tooltip: 'Aggiungi',
      onPressed: () => _apri(context, ref),
      // ⛔ Un'icona, non un'emoji: 📌 chiesto esplicitamente, ed è giusto — una
      // emoji cambia disegno da un telefono all'altro e non segue il colore.
      child: const Icon(Icons.add_rounded),
    );
  }

  Future<void> _apri(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,

      /*
       * ⚠️ **`isScrollControlled` più `SingleChildScrollView`, e non è zelo.**
       *
       * ⛔ Senza, sei voci con sottotitolo **sfondano** il foglio: su uno
       * schermo alto 600 px sono 215 px di troppo, e Flutter disegna le strisce
       * gialle e nere.
       *
       * 🚨 **L'ha trovato un test, non lo schermo.** Sul telefono del
       * committente ci stavano: sarebbe uscito da qualcun altro — o da chi
       * ingrandisce i caratteri, che è il caso peggiore, perché quella persona
       * non pensa mai che sia un difetto dell'app.
       *
       * 💡 Con questi due il foglio cresce fino a dove serve e poi **scorre**,
       * invece di tagliare.
       */
      isScrollControlled: true,
      builder: (foglio) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text(
                  'Cosa vuoi aggiungere?',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),

              _Voce(
                icona: Icons.fitness_center_rounded,
                titolo: 'Allenamento',
                sotto: 'Scegli una scheda, o vai senza',
                /*
                 * 🚨 **La stessa funzione del pulsante «Inizia»**, non una
                 * copia. ⛔ Dentro ci sono tre regole delicate — le schede
                 * bloccate, il limite di uno al giorno, e la seduta già aperta
                 * — e una di quelle è già stata scritta in modo che **non
                 * scattasse mai**, senza dare nessun errore. Vedi
                 * `avvia_un_allenamento.dart`.
                 */
                fai: () => avviaUnAllenamento(context, ref),
              ),

              _Voce(
                icona: Icons.restaurant_rounded,
                titolo: 'Cibo',
                sotto: 'Apre il diario alimentare',
                fai: () => context.push(AppRoutes.diary),
              ),

              /*
               * ⏳ **Disattivata, e lo dice.** 📌 *«per una sezione futura, per
               * adesso lascialo mock e disabilitato con scritto "In Arrivo"»*.
               *
               * 💡 Sta nell'elenco invece di essere omessa perché **annuncia**:
               * chi cerca dove segnare le vitamine trova la risposta — «non
               * ancora» — invece di continuare a cercarla.
               */
              const _Voce(
                icona: Icons.medication_outlined,
                titolo: 'Integratore alimentare',
                sotto: 'Vitamine, proteine, creatina',
                inArrivo: true,
              ),

              _Voce(
                icona: Icons.watch_rounded,
                titolo: 'Dispositivo smart',
                sotto: 'Orologio, braccialetto, bilancia',
                /*
                 * ══ 🚨 NON SI «AGGIUNGE» UN DISPOSITIVO, E VA DETTO ════════
                 *
                 * 📌 Il committente: *«se io ho uno smartwatch non è che lo
                 * devo aggiungere, devo solo chiedere a google health / apple
                 * health di darmi i permessi per leggerne i dati, corretto?»* —
                 * ✅ **Sì.**
                 *
                 * 💡 Health Connect è un **magazzino**: ci scrivono Zepp,
                 * Garmin, Fitbit, Strava, la bilancia. Noi non parliamo con
                 * nessun dispositivo, non ne conosciamo il modello e non ci
                 * accoppiamo a niente — chiediamo al magazzino il permesso di
                 * **leggere**.
                 *
                 * ⚠️ Per questo la voce si chiama «Dispositivo smart» ma quello
                 * che apre è un consenso: è il nome con cui la cerca una
                 * persona, non la descrizione di cosa succede.
                 */
                fai: () => ColleghiUnDispositivo.mostra(context),
              ),

              _Voce(
                icona: Icons.assignment_outlined,
                titolo: 'Scheda',
                sotto: 'Da una foto o da un PDF',
                fai: () => context.push(AppRoutes.importaScheda),
              ),

              _Voce(
                icona: Icons.menu_book_rounded,
                titolo: 'Piano alimentare',
                sotto: 'Da una foto o da un PDF',
                fai: () => context.push(AppRoutes.importaPiano),
              ),

              const SizedBox(height: Gap.md),
            ],
          ),
        ),
      ),
    );
  }
}

/// Una riga del foglio.
class _Voce extends StatelessWidget {
  const _Voce({
    required this.icona,
    required this.titolo,
    required this.sotto,
    this.fai,
    this.inArrivo = false,
  });

  final IconData icona;
  final String titolo;
  final String sotto;
  final VoidCallback? fai;
  final bool inArrivo;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return ListTile(
      /*
       * ⚠️ **`enabled: false` e non solo `onTap: null`.** Il secondo blocca il
       * tocco ma lascia la riga scritta con il colore normale: sembra
       * premibile, e chi la preme conclude che l'app si è inceppata. 💡 `enabled`
       * la scolorisce, cioè lo dice **prima** del tocco.
       */
      enabled: !inArrivo,
      leading: Icon(icona),
      title: Text(titolo),
      subtitle: Text(sotto),
      trailing: inArrivo
          ? Chip(
              label: const Text('In arrivo'),
              labelStyle: tema.textTheme.labelSmall,
              visualDensity: VisualDensity.compact,
            )
          : const Icon(Icons.chevron_right_rounded),
      onTap: inArrivo
          ? null
          : () {
              /*
               * 🚨 **Prima si chiude il foglio, poi si va.** ⛔ Al contrario,
               * chi torna indietro dal diario o dall'importazione si ritrova il
               * foglio ancora aperto sopra la pagina — e sembra che il tocco
               * non sia servito a niente.
               *
               * ⚠️ E `avviaUnAllenamento` apre **un altro** foglio: due fogli
               * impilati sono la strada breve per un `Navigator` con due pop da
               * fare e uno solo che si capisce.
               */
              Navigator.of(context).pop();
              fai?.call();
            },
    );
  }
}
