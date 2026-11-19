import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/backup/backup_controller.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/intestazione_app.dart';
import '../../../core/ui/sezioni.dart';
import '../../../core/ui/testata_scura.dart';
import '../../auth/auth_controller.dart';
import '../../auth/data/app_user.dart';
import '../../dashboard/consiglio_da_mostrare.dart';
import '../../onboarding/branding_controller.dart';
import '../../onboarding/data/gym_branding.dart';
import '../profile_controller.dart';
import 'widgets/riga_blocco_biometrico.dart';
import 'widgets/voce_del_profilo.dart';

/// Il profilo — A8; ridisegnato in `plan_interfaccia.md` I7, 19/11/2026.
///
/// 📌 Tavola «Profilo»: in testata la persona, la tessera della palestra e
/// quella dell'abbonamento (I7.D1); sotto, le sezioni «Tu», «Dati e privacy»,
/// «Per te», con le voci corte a coppie e le lunghe a tutta larghezza (I7.D2).
///
/// 🚨 **Chi vede cosa non è cambiato** (I7.D4): ogni voce che prima era
/// condizionale lo è ancora, con la stessa condizione — trainer, gestore,
/// consiglio nascosto, password o accesso social, palestra o no. Il ridisegno
/// sposta le voci, non decide chi le vede.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final utente = ref.watch(authControllerProvider).user;
    final palestra = ref.watch(brandingControllerProvider).branding;

    const spazio = SizedBox(height: 10);

    return Scaffold(
      // 🌑 Senza angoli: sotto c'è il seguito scuro con la persona — I7.
      appBar: const IntestazioneApp(titolo: 'Profilo', arrotondata: false),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          CodaDellaTestata(
            child: _TestaDelProfilo(utente: utente, palestra: palestra),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── TU ───────────────────────────────────────────────────
                const TitoloDiSezione('Tu'),
                spazio,
                Consumer(
                  builder: (context, ref, _) {
                    final profilo = ref.watch(profileProvider);

                    return VoceDelProfilo(
                      icona: Icons.tune_rounded,
                      titolo: 'I tuoi dati',
                      // Il sottotitolo dice a colpo d'occhio se il fabbisogno
                      // esiste: è la domanda che porta qui.
                      sottotitolo: profilo.maybeWhen(
                        data: (p) => p.isComplete
                            ? 'Fabbisogno: ${p.derived!.targetKcal} kcal al giorno'
                            : 'Da completare per avere il tuo fabbisogno',
                        orElse: () => 'Sesso, età, altezza, obiettivo',
                      ),
                      onTap: () => context.push(AppRoutes.profileEdit),
                    );
                  },
                ),
                /*
                 * ⛔ **«Registra il peso» non e' piu' una voce qui** — 3b-P.2.4:
                 * sta dentro «I tuoi dati», accanto ad altezza, eta' e
                 * obiettivo. ⛔ Nemmeno «Sonno e recupero» (3b-P.8.5) e «Foto
                 * dei progressi» (3b-P.9.3, terzo segmento di «Allenamento»).
                 * ⛔ Foto, città e colore stanno in `/profilo/tu`, dietro la
                 * persona in testata (3b-P.1).
                 */
                spazio,
                /*
                 * ⏰ **«Promemoria»** — voce 62, 27/09/2026: è la cosa che si
                 * cerca quando una notifica da' fastidio, e chi la cerca la
                 * cerca **adesso**, prima di spegnere tutto dal sistema.
                 */
                VoceDelProfilo(
                  icona: Icons.notifications_active_outlined,
                  titolo: 'Promemoria',
                  sottotitolo:
                      'Allenamento, diario e misure: quali vuoi e a che ora',
                  onTap: () => context.push(AppRoutes.promemoria),
                ),

                /*
                 * 🆕 **Dove si riaccende il consiglio nascosto** — 3b-O.3.2.
                 * Un elemento che sparisce senza un posto dove tornare è un
                 * elemento **perso**. ⚠️ Compare **solo quando è nascosto**.
                 */
                if (ref.watch(consiglioNascostoProvider)) ...[
                  spazio,
                  VoceDelProfilo(
                    icona: Icons.auto_awesome_outlined,
                    titolo: 'Consiglio del giorno',
                    sottotitolo: 'Nascosto dalla schermata Oggi',
                    coda: const Text('Mostra'),
                    onTap: () => ref
                        .read(consiglioNascostoProvider.notifier)
                        .imposta(nascosto: false),
                  ),
                ],

                /*
                 * ══ 🆕 IN PALESTRA SI ENTRA DA UN LINK, NON DA UN CODICE ════
                 *
                 * 📌 Il committente, 15/09/2026: *«Il codice d'ingresso va
                 * tolto»*. ⛔ Qui c'era il modulo del codice (B4, 13/08): un
                 * codice finito in una chat di gruppo fa entrare venti persone,
                 * un invito è monouso e scade. ✅ Con F11 (24/09) il codice non
                 * esiste più nemmeno sul server.
                 *
                 * 💡 La riga resta — chi non ha una palestra deve sapere che può
                 * averne una — ma dice dove si prende l'invito. 🚨 Solo **senza**
                 * palestra (F3): chi ce l'ha la trova in testata.
                 */
                if (!palestra.haPalestra) ...[
                  spazio,
                  const VoceDelProfilo(
                    icona: Icons.storefront_outlined,
                    titolo: 'Entrare in una palestra',
                    sottotitolo:
                        'Ti sei iscritto da solo. Per entrare in una palestra '
                        'serve un invito: chiedilo a loro, e apri il link che '
                        'ti mandano. Ti porti dietro tutto.',
                  ),
                ],

                // ── SE ALLENI ────────────────────────────────────────────
                if ((utente?.gestisceUnaPalestra ?? false) ||
                    (utente?.isTrainer ?? false)) ...[
                  const TitoloDiSezione('Se alleni'),
                  spazio,
                ],

                /*
                 * 🏋️ **«Inviti della palestra» — blocco B2, 24/09/2026.**
                 *
                 * ⚠️ **FUORI dalla condizione di chi allena**: chi gestisce una
                 * palestra può non allenare nessuno — è un cappello diverso,
                 * non un grado in più. Chi ha tutti e due i cappelli vede tutte
                 * e due le cose.
                 */
                if (utente?.gestisceUnaPalestra ?? false) ...[
                  VoceDelProfilo(
                    icona: Icons.mail_outline,
                    titolo: 'Inviti della palestra',
                    sottotitolo:
                        'Invita iscritti e trainer, e vedi i posti che restano',
                    onTap: () => context.push(AppRoutes.invitiDellaPalestra),
                  ),
                  spazio,
                ],

                /*
                 * 🆕 **Le voci di chi allena — F5.1, G7, G7.2.**
                 *
                 * ⚠️ Stanno qui e non in una sesta scheda della barra: **un
                 * trainer si allena anche lui**, e la barra è la sua vita da
                 * atleta. `isTrainer` copre il trainer di palestra e quello
                 * indipendente.
                 *
                 * ⛔ **Scaduta, «I miei utenti» NON sparisce** — 3b-U.3.1: *«si
                 * deve capire che è perché non ha pagato»*. Resta, e lo dice.
                 *
                 * ⚠️ **«Le mie schede» non è «Schede» della barra**: queste sono
                 * quelle che **scrive per altri**.
                 */
                if (utente?.isTrainer ?? false) ...[
                  VoceDelProfilo(
                    icona: utente?.abbonato == false
                        ? Icons.lock_clock_outlined
                        : Icons.groups_2_outlined,
                    titolo: 'I miei utenti',
                    sottotitolo: utente?.abbonato == false
                        ? 'Abbonamento scaduto — tocca per sapere cosa resta'
                        : 'Invita, segui e gestisci le persone che alleni',
                    avviso: utente?.abbonato == false,
                    onTap: () => context.push(AppRoutes.mieiUtenti),
                  ),
                  spazio,
                  Coppia(
                    sinistra: VoceDelProfilo(
                      larga: false,
                      icona: Icons.restaurant_menu_outlined,
                      titolo: 'I miei consigli alimentari',
                      sottotitolo: 'Scrivili qui, poi mandali dalla chat',
                      onTap: () => context.push(AppRoutes.mieiPiani),
                    ),
                    destra: VoceDelProfilo(
                      larga: false,
                      icona: Icons.fitness_center_outlined,
                      titolo: 'Le mie schede',
                      sottotitolo: 'Quelle che scrivi per i tuoi allievi',
                      onTap: () => context.push(AppRoutes.mieSchede),
                    ),
                  ),
                ],

                // ── DATI E PRIVACY ───────────────────────────────────────
                const TitoloDiSezione('Dati e privacy'),
                spazio,
                const _VoceBackup(),
                spazio,
                Coppia(
                  sinistra: VoceDelProfilo(
                    larga: false,
                    icona: Icons.privacy_tip_outlined,
                    titolo: 'Privacy e consensi',
                    sottotitolo: 'Cosa può leggere l\'app e cosa esce da qui',
                    onTap: () => context.push(AppRoutes.consensi),
                  ),
                  destra: _VoceAccesso(utente: utente),
                ),

                // 🔒 A1 — si disegna da solo, e **sparisce** sui telefoni che
                // non sanno fare il riconoscimento (con la sua carta).
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: RigaBloccoBiometrico(),
                ),

                // ── PER TE ───────────────────────────────────────────────
                /*
                 * 🎁 P8 di plan_promozioni.md — le offerte e «porta un amico».
                 * 💡 Sempre visibili: un'offerta può arrivare in qualunque
                 * momento, e il posto per trovarla deve esserci prima.
                 */
                const TitoloDiSezione('Per te'),
                spazio,
                Coppia(
                  sinistra: VoceDelProfilo(
                    larga: false,
                    piena: true,
                    icona: Icons.card_giftcard_rounded,
                    titolo: 'Offerte per te',
                    sottotitolo: 'Regali e sconti',
                    onTap: () => context.push(AppRoutes.offerte),
                  ),
                  destra: VoceDelProfilo(
                    larga: false,
                    icona: Icons.group_add_rounded,
                    titolo: 'Porta un amico',
                    sottotitolo: 'Il tuo link da condividere',
                    onTap: () => context.push(AppRoutes.portaUnAmico),
                  ),
                ),

                const SizedBox(height: Gap.lg),

                OutlinedButton.icon(
                  onPressed: () => _esci(context, ref),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Esci'),
                ),

                const SizedBox(height: Gap.md),

                // ⚠️ In fondo e in colore d'errore, ma **presente**: Apple
                // pretende che l'eliminazione sia raggiungibile dall'app.
                // Nasconderla dietro un contatto via email è motivo di rifiuto.
                TextButton.icon(
                  onPressed: () => context.push(AppRoutes.deleteAccount),
                  icon: Icon(
                    Icons.delete_forever_outlined,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  label: Text(
                    'Elimina account',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),

                const SizedBox(height: Gap.lg),
                const _QualeVersione(),
                const SizedBox(height: Gap.xl),
              ],
            ),
          ),
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

/// 🪪 **La testa del profilo, nel seguito scuro** — I7.D1, 19/11/2026.
///
/// ══ 🪪 LA PERSONA È UNA PORTA — 3b-P.1, 22/08/2026 ═══════════════════════
///
/// 📌 Il committente: *«Questa non ha senso se non fa nulla. Ci mettiamo che se
/// ci clicchi manda a una pagina per mettere l'avatar, cambiare i colori
/// dell'app e la tua città»*. 🚨 Una cosa grande e inerte insegna che qui le
/// cose grandi non si toccano. ⚠️ **La freccia non è decorazione**: è quello
/// che dice che si tocca.
///
/// 💡 Sotto, le due tessere della tavola: **palestra** e **abbonamento**.
/// La palestra si tocca solo se c'è (porta alla sua pagina, F3); senza, dice
/// «Nessuna» e la spiegazione sta nella sezione «Tu».
class _TestaDelProfilo extends StatelessWidget {
  const _TestaDelProfilo({required this.utente, required this.palestra});

  final AppUser? utente;
  final GymBranding palestra;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final tenue = tema.colorScheme.onSurfaceVariant;
    final valore = tema.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w700,
    );
    final nota = tema.textTheme.bodySmall?.copyWith(
      color: tema.colorScheme.primary,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.push(AppRoutes.tu),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Gap.sm),
              child: Row(
                children: [
                  /*
                   * 🚨 **Il colore del tema scuro, non quello della palestra**
                   * — I9, 19/11/2026, visto sul giro con A6: una palestra blu
                   * notte dava un cerchio blu notte su fondo quasi nero, e la
                   * persona spariva. ⚠️ È lo stesso difetto già chiuso per il
                   * logo in I1. `colorScheme.primary` qui è quello del tema
                   * scuro della palestra: stesso colore, schiarito apposta per
                   * stare su questo fondo.
                   */
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: tema.colorScheme.primary,
                    child: Text(
                      utente?.initials ?? '?',
                      style: TextStyle(
                        color: tema.colorScheme.onPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          utente?.name ?? '—',
                          style: tema.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          utente?.email ?? '',
                          style: tema.textTheme.bodySmall?.copyWith(
                            color: tenue,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Foto, città e colore',
                          style: tema.textTheme.labelSmall?.copyWith(
                            color: tenue,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: tenue),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: Gap.sm),
        Coppia(
          sinistra: Tessera(
            etichetta: 'Palestra',
            onTap: palestra.haPalestra
                ? () => context.push(AppRoutes.palestra)
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  palestra.haPalestra ? palestra.name! : 'Nessuna',
                  style: valore,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  palestra.haPalestra ? 'iscritto' : 'serve un invito',
                  style: palestra.haPalestra
                      ? nota
                      : tema.textTheme.bodySmall?.copyWith(color: tenue),
                ),
              ],
            ),
          ),
          /*
           * 💳 **L'abbonamento dice solo se c'è** — I7.D1.
           *
           * ⚠️ `abbonato` è `PianoAttivo::eAbbonato()` del server, e in questo
           * impianto paga il **tenant**: chi è in una palestra abbonata è
           * coperto da quella, e qui legge «Attivo» — che è vero. ⛔ Nessuna
           * promessa su cosa comprende: le regole su gettoni e AI stanno
           * altrove, e una frase qui divergerebbe alla prima che cambia.
           */
          destra: Tessera(
            etichetta: 'Abbonamento',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (utente?.abbonato ?? false) ? 'Attivo' : 'Non attivo',
                  style: valore,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 💾 **La frase sotto «Backup e dati», e se è un avviso** — I7.D3.
///
/// 💡 Pubblica e pura perché è **la regola**, e una regola si prova senza
/// disegnare niente: `profilo_in_testata_test.dart` passa tutti i casi.
/// L'ordine conta: spento prima di «da ricollegare» e «non riuscito», perché
/// da spento le altre due non hanno senso.
({String testo, bool avviso}) fraseDelBackup(StatoBackup? s) {
  if (s == null || !s.disponibile) {
    return (
      testo: 'Se perdi il telefono, è quello che ti fa rientrare',
      avviso: false,
    );
  }
  if (!s.acceso) return (testo: 'Backup automatico spento', avviso: true);
  if (s.daRicollegare) {
    return (testo: 'Backup automatico da ricollegare', avviso: true);
  }
  if (s.inErrore) {
    return (testo: 'L\'ultimo backup non è riuscito', avviso: true);
  }
  return (testo: 'Backup automatico acceso', avviso: false);
}

/// 💾 **«Backup e dati», che dice se il backup automatico è spento** — I7.D3.
///
/// 📌 Il 19/11/2026, sul telefono del committente, il backup automatico era
/// **spento** e nessuno se n'era accorto: lo si è scoperto il giorno in cui
/// serviva. 🚨 Una protezione spenta che non si vede è peggio di una che non
/// c'è, perché fa credere di esserlo.
///
/// 💡 L'avviso compare **solo quando il cloud c'è** (`disponibile`): senza un
/// cloud configurato non c'è niente da accendere, e un avviso su una cosa che
/// non si può fare è solo rumore. Durante il caricamento o su un errore di
/// lettura resta la frase di sempre: un arancio a intermittenza spaventa.
///
/// 💾 M7.3 — la voce porta alla copia di sicurezza: fino ad allora l'app
/// sapeva importare un backup e non crearne nessuno.
class _VoceBackup extends ConsumerWidget {
  const _VoceBackup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = fraseDelBackup(ref.watch(backupAutomaticoProvider).valueOrNull);

    return VoceDelProfilo(
      icona: Icons.shield_outlined,
      titolo: 'Backup e dati',
      sottotitolo: f.testo,
      avviso: f.avviso,
      onTap: () => context.push(AppRoutes.backup),
    );
  }
}

/// 🔑 **«Email e password», o «Accesso» per chi entra con Google/Apple.**
///
/// ⚠️ Stesse condizioni di prima: con una password si cambia; senza password
/// e con un accesso social si dice con cosa si entra; senza nessuna delle due
/// (caso che il server non dovrebbe produrre) la carta non si disegna.
class _VoceAccesso extends StatelessWidget {
  const _VoceAccesso({required this.utente});

  final AppUser? utente;

  @override
  Widget build(BuildContext context) {
    if (utente?.passwordIsSet ?? true) {
      return VoceDelProfilo(
        larga: false,
        icona: Icons.key_outlined,
        titolo: 'Email e password',
        sottotitolo: 'Cambia le credenziali di accesso',
        onTap: () => context.push(AppRoutes.credentials),
      );
    }

    if ((utente?.social ?? const []).isNotEmpty) {
      return VoceDelProfilo(
        larga: false,
        icona: Icons.verified_user_outlined,
        titolo: 'Accesso',
        sottotitolo:
            'Entri con ${utente!.social.map(_nomeFornitore).join(' e ')}. '
            'Nessuna password da cambiare.',
      );
    }

    return const SizedBox.shrink();
  }
}

/// `google` → «Google». Le stringhe sono quelle del backend.
String _nomeFornitore(String id) => switch (id) {
  'google' => 'Google',
  'apple' => 'Apple',
  _ => id,
};

/// 🏷️ **«Che versione hai?»** — aggiunta il 23/09/2026.
///
/// ⛔ **Prima non c'era risposta.** Il numero di versione esisteva solo dentro
/// il pacchetto Android, leggibile con `adb`.
///
/// 💡 Sta **in fondo al profilo**, dove sta la stessa riga in ogni app del
/// mondo: non è una cosa che si cerca, è una cosa che si trova quando serve.
///
/// ⚠️ **Si mostrano tutti e due i numeri** (`18.31.0 (183100)`): quello fra
/// parentesi è il `versionCode`, ed è **l'unico che conta** quando si guarda
/// perché il server ha rifiutato quella copia (`VersioneMinima` confronta
/// `X-App-Build`).
///
/// ⛔ Se la lettura fallisce non si scrive niente.
class _QualeVersione extends StatelessWidget {
  const _QualeVersione();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final info = snapshot.data;

        if (info == null) return const SizedBox.shrink();

        return Center(
          child: Text(
            'Versione ${info.version} (${info.buildNumber})',
            style: tema.textTheme.labelSmall?.copyWith(
              color: tema.colorScheme.outline,
            ),
          ),
        );
      },
    );
  }
}
