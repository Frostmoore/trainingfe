import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/intestazione_app.dart';
import '../../auth/auth_controller.dart';
import '../../dashboard/consiglio_da_mostrare.dart';
import '../../onboarding/branding_controller.dart';
import '../../scoperta/ui/scelta_citta.dart';
import '../colore_accento.dart';
import '../profile_controller.dart';
import 'widgets/entra_in_palestra_sheet.dart';
import 'widgets/riga_blocco_biometrico.dart';
import 'widgets/voce_avatar.dart';
import 'widgets/weight_sheet.dart';

/// Il profilo — A8.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final utente = ref.watch(authControllerProvider).user;
    final palestra = ref.watch(brandingControllerProvider).branding;

    return Scaffold(
      appBar: const IntestazioneApp(titolo: 'Profilo'),
      body: ListView(
        padding: const EdgeInsets.all(Gap.md),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Gap.md),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: palestra.primary,
                    child: Text(
                      utente?.initials ?? '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          utente?.name ?? '—',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          utente?.email ?? '',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: Gap.md),

          // ── C8: le voci che prima non c'erano ────────────────────────
          Card(
            child: Column(
              children: [
                Consumer(
                  builder: (context, ref, _) {
                    final profilo = ref.watch(profileProvider);

                    return ListTile(
                      leading: const Icon(Icons.tune_rounded),
                      title: const Text('I tuoi dati'),
                      // Il sottotitolo dice a colpo d'occhio se il fabbisogno
                      // esiste: è la domanda che porta qui.
                      subtitle: Text(
                        profilo.maybeWhen(
                          data: (p) => p.isComplete
                              ? 'Fabbisogno: ${p.derived!.targetKcal} kcal al giorno'
                              : 'Da completare per avere il tuo fabbisogno',
                          orElse: () => 'Sesso, età, altezza, obiettivo',
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.push(AppRoutes.profileEdit),
                    );
                  },
                ),
                const Divider(height: 1),
                Consumer(
                  builder: (context, ref, _) {
                    final peso = ref.watch(weightHistoryProvider);

                    return ListTile(
                      leading: const Icon(Icons.monitor_weight_outlined),
                      title: const Text('Registra il peso'),
                      subtitle: Text(
                        peso.maybeWhen(
                          data: (lista) => lista.isEmpty
                              ? 'Nessuna pesata registrata'
                              : 'Ultima: ${lista.last.weightKg.toStringAsFixed(1)} kg',
                          orElse: () => '',
                        ),
                      ),
                      trailing: const Icon(Icons.add_rounded),
                      onTap: () => WeightSheet.mostra(
                        context,
                        iniziale: peso.valueOrNull?.isNotEmpty ?? false
                            ? peso.value!.last.weightKg
                            : null,
                      ),
                    );
                  },
                ),
                const Divider(height: 1),

                /*
                 * ⚠️ Qui c'era la voce «Sonno» che portava all'ipnogramma;
                 * nascosta in S2.2 perche' dopo S1 non c'era piu' nessuna
                 * sorgente. **Torna in S4.3**, quando l'archivio locale
                 * comincera' a produrre il giudizio della notte.
                 *
                 * Al suo posto, da S3.4, c'e' il collegamento: prima si collega
                 * la sorgente, poi ha senso mostrarne il risultato.
                 */
                /*
                 * 🆕 **«I miei utenti» — F5.1, solo per chi allena.**
                 *
                 * ⚠️ Sta qui e non in una sesta scheda della barra: **un
                 * trainer si allena anche lui**, e la barra è la sua vita da
                 * atleta. Una scheda in più la trasformerebbe in un pannello di
                 * gestione con dentro anche il diario — il contrario di come
                 * questa app viene usata.
                 *
                 * 💡 `isTrainer` copre sia il trainer di palestra sia quello
                 * indipendente: per l'app sono la stessa cosa — gente che segue
                 * altre persone — e la differenza la fa il server.
                 */
                if (utente?.isTrainer ?? false) ...[
                  ListTile(
                    leading: const Icon(Icons.groups_2_outlined),
                    title: const Text('I miei utenti'),
                    subtitle: const Text(
                      'Invita, segui e gestisci le persone che alleni',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push(AppRoutes.mieiUtenti),
                  ),
                  const Divider(height: 1),

                  /*
                   * G7 — l'autore dei piani alimentari.
                   *
                   * 💡 Sta accanto a «i miei utenti» e non in una scheda in
                   * fondo: chi allena resta prima di tutto un atleta, e una
                   * scheda in più cambierebbe l'app a tutti per servirne pochi.
                   */
                  ListTile(
                    leading: const Icon(Icons.restaurant_menu_outlined),
                    title: const Text('I miei piani alimentari'),
                    subtitle: const Text(
                      'Scrivili qui, poi mandali dalla chat',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push(AppRoutes.mieiPiani),
                  ),
                  const Divider(height: 1),

                  /*
                   * G7.2 — l'autore delle schede.
                   *
                   * ⚠️ **Non è «Schede» della barra**, che sono le schede che
                   * questa persona esegue. Queste sono quelle che **scrive per
                   * altri**, ed è una distinzione che il titolo deve reggere da
                   * solo: chi allena vede entrambe le voci nella stessa app.
                   */
                  ListTile(
                    leading: const Icon(Icons.fitness_center_outlined),
                    title: const Text('Le mie schede'),
                    subtitle: const Text(
                      'Quelle che scrivi per i tuoi allievi',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push(AppRoutes.mieSchede),
                  ),
                  const Divider(height: 1),
                ],

                /*
                 * 📍 La città — M1.2.
                 *
                 * 🚨 Sta **sopra** «sonno e recupero» e non in fondo: è il
                 * campo che accende la vicinanza nel catalogo, e senza di esso
                 * chi cerca una palestra riceve un elenco in ordine alfabetico
                 * senza capire perché.
                 *
                 * ⚠️ E non è obbligatoria: si può togliere.
                 */
                // 📷 M7.2 — la foto sta in cima al gruppo: è la prima cosa che
                // una persona vede di sé in questa schermata.
                const VoceAvatar(),
                const Divider(height: 1),

                const VoceCitta(),
                const Divider(height: 1),

                /*
                 * 💾 M7.3 — la copia di sicurezza.
                 *
                 * 🚨 Fino a oggi l'app sapeva **importare** un file di backup e
                 * non crearne nessuno: si poteva ripristinare da un file che
                 * non si poteva fare. Era il buco più silenzioso di tutto
                 * l'impianto delle chiavi, perché si scopre solo quando serve.
                 */
                ListTile(
                  leading: const Icon(Icons.shield_outlined),
                  title: const Text('Copia di sicurezza'),
                  subtitle: const Text(
                    'Se perdi il telefono, è quello che ti fa rientrare',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push(AppRoutes.backup),
                ),
                const Divider(height: 1),

                /*
                 * 🆕 **Dove si riaccende il consiglio nascosto** — 3b-O.3.2.
                 *
                 * 🚨 È la metà che rende accettabile il pulsante «nascondi»
                 * sulla card: un elemento che sparisce senza un posto dove
                 * tornare è un elemento **perso**, e chi l'ha nascosto per
                 * sbaglio non ha modo di rimediare.
                 *
                 * ⚠️ Compare **solo quando è nascosta**: una voce che dice
                 * «mostra una cosa che stai già vedendo» è rumore in un elenco
                 * che ne ha già abbastanza.
                 */
                /*
                 * 🆕 **Il colore d'accento, solo senza palestra** — 3b-O.1a.1.
                 *
                 * 🚨 Chi una palestra ce l'ha **non lo vede**, e non è una
                 * dimenticanza: il colore è l'identità del cliente (ADR-A01), e
                 * lasciarlo cambiare a un iscritto vorrebbe dire che può
                 * spegnere il marchio della palestra che lo paga.
                 */
                /*
                 * 🚨 **`haPalestra`, e qui era rimasto il controllo sbagliato**
                 * — difetto O.D.2, secondo giro, 22/08/2026.
                 *
                 * ⚠️ Il 21/08 quel controllo era stato corretto in quattro
                 * punti. **Questo era il quinto**, e non è stato trovato per un
                 * motivo stupido: era spezzato su sei righe, e il `grep` cercava
                 * `name?.isNotEmpty ?? false` su una riga sola.
                 *
                 * ⛔ Risultato: `GymBranding.neutral` ha `name: 'Training
                 * Companion'`, quindi «ha una palestra» era **vero** per tutti,
                 * e il selettore del colore **non lo vedeva nessuno**. Il
                 * committente: *«non mi hai messo nessuna interfaccia per
                 * selezionare il colore di accento»*. C'era, ed era invisibile.
                 *
                 * 💡 Adesso c'è un test che legge il sorgente e non si fa
                 * ingannare dagli a capo: `niente_nome_per_la_palestra_test.dart`.
                 */
                if (!ref
                    .watch(brandingControllerProvider)
                    .branding
                    .haPalestra) ...[
                  const _ScegliColore(),
                  const Divider(height: 1),
                ],

                if (ref.watch(consiglioNascostoProvider)) ...[
                  ListTile(
                    leading: const Icon(Icons.auto_awesome_outlined),
                    title: const Text('Consiglio del giorno'),
                    subtitle: const Text('Nascosto dalla schermata Oggi'),
                    trailing: const Text('Mostra'),
                    onTap: () => ref
                        .read(consiglioNascostoProvider.notifier)
                        .imposta(nascosto: false),
                  ),
                  const Divider(height: 1),
                ],

                ListTile(
                  leading: const Icon(Icons.monitor_heart_outlined),
                  title: const Text('Sonno e recupero'),
                  subtitle: const Text(
                    'Collega Health Connect · i dati restano sul telefono',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push(AppRoutes.salute),
                ),
                const Divider(height: 1),
                // La galleria ha lasciato la prima scheda alla dashboard: si
                // guarda ogni tanto, non ogni volta che si apre l'app.
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Foto dei progressi'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push(AppRoutes.progress),
                ),

                // 🚨 **Solo per chi ha una password che conosce** — G8.
                //
                // Chi entra con Google o Apple ne ha una, ma casuale e mai
                // vista: il modulo gli chiederebbe «quella attuale» e non
                // potrebbe compilarlo. Al suo posto, la riga qui sotto dice
                // con che cosa accede.
                // 🚨 S9.1 — i consensi devono essere **raggiungibili quanto
                // sono stati facili da dare**: sepolti in un sottomenù non
                // sarebbero «revocabili con la stessa facilità» (art. 7(3)).
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Privacy e consensi'),
                  subtitle: const Text(
                    'Decidi cosa può leggere l\'app e cosa può uscire da qui',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push(AppRoutes.consensi),
                ),

                // 🔒 A1 — si disegna da solo, e **sparisce** sui telefoni che
                // non sanno fare il riconoscimento.
                const RigaBloccoBiometrico(),

                if (utente?.passwordIsSet ?? true) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.key_outlined),
                    title: const Text('Email e password'),
                    subtitle: const Text(
                      'Cambia le tue credenziali di accesso',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push(AppRoutes.credentials),
                  ),
                ] else if ((utente?.social ?? const []).isNotEmpty) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.verified_user_outlined),
                    title: const Text('Accesso'),
                    subtitle: Text(
                      'Entri con ${utente!.social.map(_nomeFornitore).join(' e ')}. '
                      'Non c\'è nessuna password da cambiare.',
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: Gap.md),

          // 🚨 La scheda della palestra c'è **solo se una palestra c'è** — F3.
          //
          // ⚠️ Per chi si è iscritto senza codice questa card diceva «La tua
          // palestra» seguita da un ripiego. Meglio non mostrarla: una sezione
          // vuota fa cercare un dato che non manca — semplicemente non esiste.
          if (palestra.haPalestra)
            Card(
              child: ListTile(
                leading: const Icon(Icons.storefront_outlined),
                title: const Text('La tua palestra'),
                subtitle: Text(palestra.name!),
              ),
            )
          else
            /*
             * 🆕 **«Entra in una palestra»** — requisito B4, chiesto il
             * 13/08/2026.
             *
             * ⚠️ **Non è un cambio di etichetta: dietro c'è una migrazione di
             * dati.** Diario, allenamenti, piani e foto sono marcati con il
             * tenant personale, e senza spostarli il `TenantScope` li
             * renderebbe **invisibili** a chi entra in palestra. Il lavoro sta
             * in `UnisciAUnaPalestra`, lato server.
             *
             * 💡 Sta al posto della card «La tua palestra», non accanto: per
             * chi non ne ha una, questa **è** quella sezione.
             */
            Card(
              child: ListTile(
                leading: const Icon(Icons.storefront_outlined),
                title: const Text('Entra in una palestra'),
                subtitle: const Text(
                  'Ti sei iscritto da solo. Se hai il codice di una palestra, '
                  'puoi entrarci portandoti dietro tutto.',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                isThreeLine: true,
                onTap: () => EntraInPalestraSheet.mostra(context),
              ),
            ),

          const SizedBox(height: Gap.lg),

          OutlinedButton.icon(
            onPressed: () => _esci(context, ref),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Esci'),
          ),

          const SizedBox(height: Gap.md),

          // ⚠️ In fondo e in colore d'errore, ma **presente**: Apple pretende
          // che l'eliminazione sia raggiungibile dall'app. Nasconderla dietro
          // un contatto via email è motivo di rifiuto.
          TextButton.icon(
            onPressed: () => context.push(AppRoutes.deleteAccount),
            icon: Icon(
              Icons.delete_forever_outlined,
              color: Theme.of(context).colorScheme.error,
            ),
            label: Text(
              'Elimina account',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
          const SizedBox(height: Gap.xl),
        ],
      ),
    );
  }

  /// 🚨 La conferma non è cortesia: uscire cancella il token, e rientrare
  /// richiede la password. Un tocco accidentale sull'ultima voce di un elenco
  /// non deve costare all'utente il ritrovarsi fuori.
  Future<void> _esci(BuildContext context, WidgetRef ref) async {
    final conferma = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Uscire?'),
        content: const Text('Dovrai reinserire la password per rientrare.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Esci'),
          ),
        ],
      ),
    );

    if (conferma ?? false) {
      await ref.read(authControllerProvider.notifier).logout();
    }
  }
}

/// `google` → «Google». Le stringhe sono quelle del backend.
String _nomeFornitore(String id) => switch (id) {
  'google' => 'Google',
  'apple' => 'Apple',
  _ => id,
};

/// La tavolozza dell'accento — 3b-O.1a.1.
///
/// ⚠️ **Otto colori e non un selettore libero**, ed è una scelta di sicurezza
/// oltre che del committente: questo colore diventa lo sfondo
/// dell'intestazione, e sopra ci vanno testo e icone di sistema. 🚨 Con un
/// colore qualunque quel testo **sparisce**, e non c'è modo di impedirlo a
/// valle.
class _ScegliColore extends ConsumerWidget {
  const _ScegliColore();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scelto = ref.watch(accentoSceltoProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.palette_outlined),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Text(
                  "Colore dell'app",
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ],
          ),

          const SizedBox(height: Gap.sm),

          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.sm,
            children: [
              for (final voce in ColoreAccento.tavolozza.entries)
                GestureDetector(
                  onTap: () =>
                      ref.read(accentoSceltoProvider.notifier).scegli(voce.key),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: voce.value,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: scelto == voce.key
                            ? Theme.of(context).colorScheme.onSurface
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    // 💡 Il segno di spunta oltre al bordo: chi non distingue
                    // bene i colori non vedrebbe quale è selezionato.
                    child: scelto == voce.key
                        ? const Icon(
                            Icons.check_rounded,
                            size: 18,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
