import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/acquisti/ui/schermata_acquisti.dart';
import '../../features/auth/auth_controller.dart';
import '../../features/auth/ui/gym_inactive_screen.dart';
import '../../features/auth/ui/login_screen.dart';
import '../../features/auth/ui/register_screen.dart';
import '../../features/auth/ui/schermata_di_blocco.dart';
import '../../features/calendar/ui/calendar_screen.dart';
import '../../features/calendar/ui/day_screen.dart';
import '../../features/chat/ui/conversations_screen.dart';
import '../../features/chiavi/ui/porta_delle_chiavi.dart';
import '../../features/chiavi/ui/schermata_backup.dart';
import '../../features/dashboard/ui/dashboard_screen.dart';
import '../../features/diary/ui/diary_screen.dart';
import '../../features/forma/ui/schermata_forma.dart';
import '../../features/home/ui/home_shell.dart';
import '../../features/nutrition/ui/compositore_consigli.dart';
import '../../features/nutrition/ui/importa_piano_screen.dart';
import '../../features/nutrition/ui/miei_piani_screen.dart';
import '../../features/onboarding/branding_controller.dart';
import '../../features/onboarding/ui/schermata_benvenuto.dart';
import '../../features/privacy/ui/schermata_consensi.dart';
import '../../features/profile/ui/credentials_screen.dart';
import '../../features/profile/ui/delete_account_screen.dart';
import '../../features/profile/ui/edit_profile_screen.dart';
import '../../features/profile/ui/profile_screen.dart';
import '../../features/profile/ui/schermata_modello_calorie.dart';
import '../../features/profile/ui/schermata_palestra.dart';
import '../../features/profile/ui/schermata_tu.dart';
import '../../features/progress/ui/progress_screen.dart';
import '../../features/scoperta/ui/catalogo_screen.dart';
import '../../features/sleep/ui/sleep_screen.dart';
import '../../features/trainer/ui/miei_utenti_screen.dart';
import '../../features/training/ui/allenamento_orologio_screen.dart';
import '../../features/training/ui/compositore_scheda.dart';
import '../../features/training/ui/history_screen.dart';
import '../../features/training/ui/mie_schede_screen.dart';
import '../../features/training/ui/plan_editor_screen.dart';
import '../../features/training/ui/plans_screen.dart';
import '../../features/training/ui/player_screen.dart';
import '../../features/training/ui/schermata_settimana.dart';
import '../../features/training/ui/session_summary_screen.dart';
import '../../features/training/ui/widgets/scelta_tipo_scheda.dart';

/// Le rotte dell'app — A1.5.
///
/// 🚨 **Il `redirect` è l'unico punto che decide dove si può stare.**
/// Se ogni schermata controllasse da sé la sessione, basterebbe dimenticarlo su
/// una per lasciare una porta aperta — e in un'app le schermate si aggiungono
/// in fretta. Qui la regola è scritta una volta e vale per tutte.
///
/// L'ordine dei controlli non è casuale:
///  1. **si sta ancora leggendo il token** → splash, senza decidere niente;
///  2. **palestra sospesa** → schermata dedicata, *prima* del controllo di
///     sessione: chi è in questo stato ha le credenziali giuste, e mandarlo al
///     login lo farebbe riprovare all'infinito con la password corretta;
///  3. 🔒 **sessione bloccata** (A1) → schermata di blocco. Stessa logica del
///     punto 2: la sessione **esiste**, manca solo il permesso di usarla;
///  4. 🚨 **sbloccata ma ancora sulla schermata di blocco** → dentro. ⚠️ Serve
///     una regola sua: `/bloccata` non è pubblica, quindi il punto 7 non la
///     riconosce — e senza, l'impronta funzionava e non succedeva niente;
///  5. **nessuna palestra scelta** → codice d'invito;
///  6. **non autenticato** → accesso;
///  7. **autenticato su una schermata di accesso** → dentro.
class AppRoutes {
  const AppRoutes._();

  static const gymCode = '/benvenuto';
  static const login = '/accedi';
  static const register = '/registrati';
  static const gymInactive = '/palestra-sospesa';
  static const bloccata = '/bloccata';

  static const home = '/';
  static const diary = '/diario';
  static const training = '/allenamento';
  static const progress = '/progressi';
  static const chat = '/messaggi';
  static const profile = '/profilo';

  // ── Fase C: le schermate che prima non c'erano ─────────────────────────
  //
  // Sono tutte **sopra** la shell (`push`, non `go`): hanno un percorso
  // proprio con un pulsante «indietro», e non devono far sparire la barra di
  // navigazione dal sotto — è il comportamento che ci si aspetta da un
  // dettaglio, non da una sezione.
  /// «I miei utenti» — F5.1.
  ///
  /// ⚠️ Sotto `/profilo` e non una sesta scheda in barra: **un trainer si
  /// allena anche lui**, e la barra di navigazione è la sua vita da atleta.
  /// Una scheda in più la trasformerebbe in un pannello di gestione con dentro
  /// anche il diario, che è il contrario di come questa app viene usata.
  static const mieiUtenti = '/profilo/i-miei-utenti';

  /// Il catalogo di palestre e trainer — Parte M7.4.
  ///
  /// ⚠️ **Non è una sesta scheda in barra**, ed è la stessa ragione di «i miei
  /// utenti»: una palestra la si cerca **una volta**, quando si comincia o
  /// quando si cambia città. Una scheda permanente in fondo allo schermo per
  /// una cosa che si fa una volta l'anno toglierebbe spazio alle quattro che si
  /// usano ogni giorno.
  ///
  /// 💡 Ci si arriva dai messaggi, che è il posto dove la domanda nasce: «con
  /// chi posso parlare?».
  static const catalogo = '/messaggi/trova';

  /// I piani alimentari scritti dal trainer — G7.
  ///
  /// 💡 Sotto `/profilo` come «i miei utenti», e per la stessa ragione: chi
  /// allena resta prima di tutto un atleta, e una scheda in piu' in fondo
  /// cambierebbe l'app a tutti per servirne pochi.
  static const mieiPiani = '/profilo/i-miei-piani';

  static const compositorePiano = '/profilo/i-miei-piani/nuovo';

  /// Importare un piano alimentare da un PDF — N20.
  ///
  /// 🚨 **Non sta sotto `/profilo/i-miei-piani`**, che e' la roba di chi
  /// allena. Questa e' una funzione **della persona**: importa il piano che le
  /// ha dato il suo professionista, e nessun trainer la vede o la usa.
  static const importaPiano = '/diario/importa-piano';

  /// Le schede scritte dal trainer — G7.2.
  ///
  /// ⚠️ **Non è `/schede`**, che è l'editor delle schede **proprie** di chi si
  /// allena (`planNew`, `/schede/:id/modifica`). Sono due strumenti diversi per
  /// due persone diverse, e stanno sotto due prefissi diversi apposta: un
  /// giorno qualcuno unificherà i percorsi «per pulizia» e si porterà dietro
  /// anche i widget.
  static const mieSchede = '/profilo/le-mie-schede';

  static const compositoreScheda = '/profilo/le-mie-schede/nuova';

  /// 🪪 Come ti vedi e come vedi l'app — 3b-P.1: foto, città, colore.
  ///
  /// 💡 Dietro la card del nome, che fino al 22/08/2026 non faceva niente.
  static const tu = '/profilo/tu';

  /// 🏢 La palestra: dettagli e uscita — 3b-P.13.4.
  static const palestra = '/profilo/palestra';

  static const profileEdit = '/profilo/dati';

  /// ⚖️ Come si contano le calorie: il modello, e poi il livello — 3b-G.1.
  static const modelloCalorie = '/profilo/calorie';
  static const deleteAccount = '/profilo/elimina';
  static const credentials = '/profilo/credenziali';

  /// La copia di sicurezza delle chiavi — M7.3.
  ///
  /// 🚨 Sta nel profilo e non sepolta nelle impostazioni: fino a oggi l'app
  /// sapeva **importare** un file di backup e non crearne nessuno — si poteva
  /// ripristinare da un file che non si poteva fare.
  static const backup = '/profilo/copia-di-sicurezza';

  /// I consensi facoltativi (S9.1). 🚨 Sta nel profilo e non in un sottomenù:
  /// revocare dev'essere facile quanto concedere (art. 7(3)).
  static const consensi = '/profilo/privacy';
  static const sleep = '/sonno';

  /// Il collegamento con Health Connect e la spiegazione dell'uso dei dati.
  ///
  /// 🚨 **Google pretende che questa schermata esista e sia raggiungibile**: il
  /// manifest la aggancia a `ACTION_SHOW_PERMISSIONS_RATIONALE`, ed è quello
  /// che il sistema apre quando chiede all'app di spiegarsi (S3.4).
  static const salute = '/salute';

  /// Il dettaglio di carico e carica.
  ///
  /// 💡 Sta sotto `/salute` perché è la stessa famiglia di dati e la
  /// stessa avvertenza: chi arriva qui deve trovarsi nello stesso posto mentale
  /// di chi arriva dalla schermata dei permessi.
  static const forma = '/salute/forma';

  /// 🆕 Dove si attiva l'assistente — 3b-O.3.1.
  ///
  /// ⚠️ Oggi è una vetrina: i pagamenti non sono collegati, e la schermata lo
  /// dice in cima. Vedi `SchermataAcquisti.inArrivo`.
  static const acquisti = '/acquisti';
  static const calendar = '/calendario';
  static const history = '/allenamento/storico';

  /// 📅 La settimana programmata — 3b-I.B.
  static const settimana = '/allenamento/settimana';
  static const planNew = '/schede/nuova';

  /// `/allenamento/:id` — il player. `/schede/:id/modifica` — l'editor.
  static String player(int sessionId) => '/allenamento/$sessionId';

  /// Il riepilogo di fine allenamento — G7.
  ///
  /// 🚨 È una **rotta di go_router**, non un `Navigator.push` imperativo.
  /// Il player la apre con `pushReplacement`: spingendola con il `Navigator`
  /// del router, go_router continuerebbe a credere che la rotta corrente sia il
  /// player, e «Fine» riporterebbe su una sessione ormai chiusa.
  static String riepilogo(int sessionId) => '/allenamento/$sessionId/riepilogo';

  /// La pagina di un allenamento visto **solo dall'orologio** — 3b-A.9.
  ///
  /// ⚠️ Percorso diverso da `/allenamento/:id`, e non è pignoleria: quello
  /// vuole l'id di una **seduta** del player, questo l'id di una riga
  /// dell'archivio del telefono. Due numerazioni diverse sullo stesso percorso
  /// aprirebbero la pagina sbagliata senza dare nessun errore.
  static String dallOrologio(int id) => '/allenamento/orologio/$id';
  static String planEdit(int planId) => '/schede/$planId/modifica';
  static String day(String date) => '/giorno/$date';

  /// Le schermate raggiungibili senza sessione.
  static const _public = {gymCode, login, register, gymInactive};

  static bool isPublic(String location) => _public.contains(location);
}

/// **Dove si può stare**, come funzione pura — l'unico punto che lo decide.
///
/// ── 🚨 Perché è una funzione e non una closure dentro `GoRouter` ──────────
///
/// Perché è il pezzo di codice **più facile da sbagliare e più difficile da
/// provare** dell'intera app: sette regole in cascata, dove l'ordine conta e
/// dove «nessuna regola si applica» significa **resta dove sei**, cioè il modo
/// più silenzioso di lasciare qualcuno in un vicolo cieco.
///
/// ⚠️ È successo davvero, il 12/08/2026: l'impronta sbloccava, e l'app restava
/// sulla pagina «App bloccata». Nessun errore, nessun log, niente da cercare.
/// Estratta di qui, quella cascata si prova in venti righe di test.
///
/// `null` = «va bene dove sei». Qualunque altra stringa è la rotta da imporre.
///
/// L'ordine dei controlli **non è casuale**:
///  1. si sta ancora leggendo il token → si resta, e l'app mostra lo splash;
///  2. palestra sospesa, prima di tutto il resto;
///  3. 🔒 sessione bloccata;
///  4. 🚨 sbloccata ma ancora sulla schermata di blocco;
///  5. nessuna palestra scelta;
///  6. sessione assente;
///  7. autenticato su una schermata d'accesso.
String? destinazione({
  required AuthStatus stato,

  /// 🚨 **Ha fatto la scelta**, non «ha una palestra» — F3, 13/08/2026.
  ///
  /// ⚠️ Il parametro si chiamava `haPalestra` e leggeva `hasGym`, e da lì
  /// nasceva il difetto: chi toccava «continuo senza palestra» finiva in uno
  /// stato che valeva `false` esattamente come chi non aveva ancora scelto, e
  /// la regola 5 lo rimandava **allo stesso schermo da cui era partito**.
  /// Per lui non succedeva niente — nessun errore, nessun movimento.
  ///
  /// 💡 Il nome è cambiato insieme al significato, di proposito: `haPalestra`
  /// avrebbe continuato a suggerire la domanda sbagliata a chi legge.
  required bool sceltaFatta,
  required String posizione,
}) {
  final autenticato = stato == AuthStatus.loggedIn;

  // 1. Non si sa ancora niente: si resta dove si è, lo splash è mostrato
  //    dall'app stessa. Decidere adesso significherebbe mandare al login
  //    ogni utente a ogni avvio, per la frazione di secondo che serve a
  //    leggere il Keychain — e quel salto si vede.
  if (stato == AuthStatus.unknown) return null;

  // 2. Palestra sospesa: prima di tutto il resto.
  if (stato == AuthStatus.gymInactive) {
    return posizione == AppRoutes.gymInactive ? null : AppRoutes.gymInactive;
  }

  /*
   * 3. 🔒 Sessione bloccata — A1.
   *
   * ⚠️ **Prima del controllo sulla palestra**, e non è un dettaglio: il
   * branding si legge dalla cache locale, quindi anche a schermo bloccato
   * l'app saprebbe di che colore essere e passerebbe oltre. Ma mostrare il
   * codice palestra o qualunque altra schermata a chi non ha ancora
   * sbloccato vorrebbe dire che il blocco non blocca niente.
   */
  if (stato == AuthStatus.locked) {
    return posizione == AppRoutes.bloccata ? null : AppRoutes.bloccata;
  }

  /*
   * 4. 🚨 **Sbloccata: si esce dalla schermata di blocco.**
   *
   * ⚠️ Senza questa riga l'impronta funzionava e **non succedeva niente**: si
   * restava sulla pagina «App bloccata». È il difetto riferito provando l'app
   * il 12/08/2026.
   *
   * Il motivo è che `/bloccata` **non è** in `_public`, quindi la regola 7 —
   * «autenticato su una schermata di accesso → dentro» — non la riconosceva, e
   * nessuna regola successiva spostava: la cascata arrivava in fondo e tornava
   * `null`, cioè «resta dove sei».
   *
   * 🚨 **E `/bloccata` NON va aggiunta a `_public` per rimediare.** Quella
   * lista significa «raggiungibile senza sessione», ed è usata anche dalla
   * regola 6: chi tocca «Entra con la password» finisce `loggedOut`, e con
   * `/bloccata` fra le pubbliche resterebbe **inchiodato lì** invece di andare
   * al login. Si sarebbe scambiato un vicolo cieco con un altro.
   *
   * 💡 Qui basta il caso autenticato: quando non lo è, ci pensa la regola 6
   * proprio perché `/bloccata` non è pubblica.
   */
  if (posizione == AppRoutes.bloccata && autenticato) return AppRoutes.home;

  /*
   * 5. **Non ha ancora scelto**: l'app non sa nemmeno di che colore essere.
   *
   * 🚨 `sceltaFatta` e non `haPalestra` — F3. Chi ha toccato «continuo senza
   * palestra» **ha scelto**, e deve poter andare avanti: con la vecchia
   * condizione veniva rimandato a `gymCode`, cioè alla schermata da cui era
   * appena partito, e per lui non succedeva niente.
   */
  if (!sceltaFatta) {
    return posizione == AppRoutes.gymCode ? null : AppRoutes.gymCode;
  }

  // 6. Sessione assente.
  if (!autenticato) {
    return AppRoutes.isPublic(posizione) ? null : AppRoutes.login;
  }

  // 7. Autenticato ma fermo su una schermata di accesso.
  if (AppRoutes.isPublic(posizione)) return AppRoutes.home;

  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  // `Listenable` costruito dai due controller: go_router rivaluta il
  // `redirect` quando cambia la sessione **o** quando cambia la palestra.
  // Senza, un logout lascerebbe l'utente sulla schermata in cui si trova.
  final refresh = _RouterRefresh(ref);

  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: refresh,
    redirect: (context, state) => destinazione(
      stato: ref.read(authControllerProvider).status,
      sceltaFatta: ref.read(brandingControllerProvider).sceltaFatta,
      posizione: state.matchedLocation,
    ),
    routes: [
      GoRoute(
        path: AppRoutes.gymCode,
        builder: (_, _) => const SchermataBenvenuto(),
      ),
      GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: AppRoutes.register,
        builder: (_, _) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.gymInactive,
        builder: (_, _) => const GymInactiveScreen(),
      ),
      GoRoute(
        path: AppRoutes.bloccata,
        builder: (_, _) => const SchermataDiBlocco(),
      ),

      /*
       * ── F5.1 / F6 — «i miei utenti» ──────────────────────────────────
       *
       * 🚨 **Passa da `PortaDelleChiavi`**, ed è F5.2.
       *
       * Fino alla Parte B le chiavi servivano solo in chat, e la porta stava
       * lì. ⚠️ Con l'interfaccia doppia **la chat non è più il primo posto in
       * cui servono**: un trainer che assegna una scheda ne ha bisogno prima,
       * perché il piano viaggia dentro il canale cifrato (D11/D13). Chi
       * arrivasse qui senza chiave si troverebbe a mandare un invito, ricevere
       * la persona, e scoprire solo aprendo la chat che non può scriverle.
       *
       * 🚨 **Trappola già pagata (S6)**: le schermate delle chiavi sono il
       * **corpo** di `PortaDelleChiavi`, non rotte spinte sopra. Un
       * `Navigator.pop()` là dentro lascia un Navigator vuoto → **pagina nera**.
       * Spostando la porta non si è reintrodotto nessun `pop()`.
       */
      GoRoute(
        path: AppRoutes.mieiUtenti,
        builder: (_, _) => const PortaDelleChiavi(child: MieiUtentiScreen()),
      ),

      /*
       * 🚨 Il catalogo — M7.4 — **dentro `PortaDelleChiavi`**.
       *
       * Da qui si apre una conversazione, e una conversazione richiede le
       * chiavi. ⚠️ Chiederle al momento in cui si tocca una palestra vorrebbe
       * dire fermare qualcuno che ha appena deciso di scrivere: il momento
       * peggiore possibile per far comparire una password.
       */
      GoRoute(
        path: AppRoutes.catalogo,
        builder: (_, _) => const PortaDelleChiavi(child: CatalogoScreen()),
      ),

      /*
       * G7 — l'autore dei piani alimentari.
       *
       * 🚨 **Anche questi dentro `PortaDelleChiavi`**, e non per abitudine: da
       * qui si compone cio' che poi si manda via chat, e mandarlo richiede le
       * chiavi. Chiederle al momento dell'invio vorrebbe dire fermare qualcuno
       * che ha appena finito di scrivere un piano.
       *
       * ⚠️ `/nuovo` **prima** di `/:id`: go_router prende la prima che combacia,
       * e con l'ordine inverso «nuovo» finirebbe come id.
       */
      GoRoute(
        path: AppRoutes.mieiPiani,
        builder: (_, _) => const PortaDelleChiavi(child: MieiPianiScreen()),
      ),
      /*
       * 🚨 **N19.2 — qui ci va il compositore SEMPLICE.**
       *
       * Quello completo (`CompositorePiano`) sa comporre giorni, pasti e
       * grammi: e' un atto riservato, e il server lo rifiuta a un trainer con
       * un 422. ⚠️ Lasciarlo raggiungibile vorrebbe dire far compilare a
       * qualcuno un modulo di venti campi per poi dirgli di no alla fine.
       *
       * 💡 Il compositore completo **non e' stato cancellato**: serve al
       * nutrizionista (N22) e all'importazione di un piano vero (N20). Resta
       * li', senza una rotta che ci porti, finche' non ci sara' chi puo' usarlo.
       */
      /*
       * N20 - l'importazione di un piano da PDF.
       *
       * 🚨 E' della persona, non del trainer: il piano lo ha redatto un
       * professionista abilitato fuori di qui, e chi lo importa e'
       * l'interessato. Il server non ha nessuna rotta che permetta a un
       * trainer di leggerlo, nemmeno impersonando (N20.6).
       */
      GoRoute(
        path: AppRoutes.importaPiano,
        builder: (_, _) => const PortaDelleChiavi(child: ImportaPianoScreen()),
      ),
      GoRoute(
        path: AppRoutes.compositorePiano,
        builder: (_, _) => const PortaDelleChiavi(child: CompositoreConsigli()),
      ),
      GoRoute(
        path: '${AppRoutes.mieiPiani}/:id',
        builder: (_, stato) => PortaDelleChiavi(
          child: CompositoreConsigli(
            pianoId: int.tryParse(stato.pathParameters['id'] ?? ''),
          ),
        ),
      ),

      /*
       * G7.2 — l'autore delle schede. Stesse tre rotte, stesso ordine, stessa
       * `PortaDelleChiavi`: da qui si compone ciò che poi si manda via chat.
       *
       * ⚠️ `/nuova` **prima** di `/:id`, come sopra: go_router prende la prima
       * che combacia, e con l'ordine inverso «nuova» finirebbe come id — che
       * `int.tryParse` non sa leggere, quindi si aprirebbe un compositore vuoto
       * al posto di quello nuovo. Il sintomo assomiglia a «funziona», ed è il
       * motivo per cui la nota sta scritta due volte.
       */
      GoRoute(
        path: AppRoutes.mieSchede,
        builder: (_, _) => const PortaDelleChiavi(child: MieSchedeScreen()),
      ),
      GoRoute(
        path: AppRoutes.compositoreScheda,
        builder: (_, _) => const PortaDelleChiavi(child: CompositoreScheda()),
      ),
      GoRoute(
        path: '${AppRoutes.mieSchede}/:id',
        builder: (_, stato) => PortaDelleChiavi(
          child: CompositoreScheda(
            schedaId: int.tryParse(stato.pathParameters['id'] ?? ''),
          ),
        ),
      ),

      // ── Fase C ────────────────────────────────────────────────────────
      GoRoute(path: AppRoutes.tu, builder: (_, _) => const SchermataTu()),
      GoRoute(
        path: AppRoutes.palestra,
        builder: (_, _) => const SchermataPalestra(),
      ),
      GoRoute(
        path: AppRoutes.profileEdit,
        builder: (_, _) => const EditProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.modelloCalorie,
        builder: (_, _) => const SchermataModelloCalorie(),
      ),
      GoRoute(
        path: AppRoutes.deleteAccount,
        builder: (_, _) => const DeleteAccountScreen(),
      ),
      GoRoute(
        path: AppRoutes.credentials,
        builder: (_, _) => const CredentialsScreen(),
      ),
      GoRoute(
        path: AppRoutes.consensi,
        builder: (_, _) => const SchermataConsensi(),
      ),
      GoRoute(path: AppRoutes.sleep, builder: (_, _) => const SleepScreen()),
      /*
       * ══ 🚨 `/salute` NON SI CANCELLA, RIMANDA — 3b-P.8.4, 22/08/2026 ═════
       *
       * ⛔ **La schermata non esiste piu'**: i suoi contenuti sono sotto
       * l'ipnogramma di `/sonno` (la spiegazione) e in `/profilo/privacy` (il
       * collegamento). Ma **la rotta deve restare viva**.
       *
       * 🚨 Il manifest la aggancia a `ACTION_SHOW_PERMISSIONS_RATIONALE`: e'
       * quello che Android apre quando chiede all'app di spiegare perche' vuole
       * i dati di salute, ed e' un requisito di **pubblicazione**. Cancellarla
       * vorrebbe dire un intent che cade nel vuoto — nessun errore visibile
       * nell'app, e il rifiuto arriva mesi dopo dal negozio.
       *
       * 💡 Rimanda a `/sonno` e non a `/profilo/privacy` perche' e' li' che sta
       * il testo che Google vuole leggere: cosa leggiamo, perche', e dove
       * finisce.
       */
      GoRoute(path: AppRoutes.salute, redirect: (_, _) => AppRoutes.sleep),
      GoRoute(path: AppRoutes.forma, builder: (_, _) => const SchermataForma()),
      GoRoute(
        path: AppRoutes.acquisti,
        builder: (_, _) => const SchermataAcquisti(),
      ),
      GoRoute(
        path: AppRoutes.calendar,
        builder: (_, _) => const CalendarScreen(),
      ),
      GoRoute(
        path: AppRoutes.progress,
        builder: (_, _) => const ProgressScreen(),
      ),
      GoRoute(
        path: AppRoutes.history,
        builder: (_, _) => const HistoryScreen(),
      ),
      GoRoute(
        path: AppRoutes.settimana,
        builder: (_, _) => const SchermataSettimana(),
      ),
      GoRoute(
        path: AppRoutes.planNew,

        // 🆕 3b-D.2: il tipo (un giorno / più giorni) lo si sceglie **prima**
        // di entrare, e arriva da `extra`. ⚠️ `null` = si è arrivati qui senza
        // passare dalla domanda, e vale «un giorno».
        builder: (_, state) =>
            PlanEditorScreen(tipo: state.extra as TipoDiScheda?),
      ),
      GoRoute(
        path: '/schede/:id/modifica',
        builder: (_, state) =>
            PlanEditorScreen(planId: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/giorno/:date',
        builder: (_, state) => DayScreen(date: state.pathParameters['date']!),
      ),
      /*
       * 🆕 3b-A.9 — e **prima** di `/allenamento/:id`, come `storico`: go_router
       * prova le rotte in ordine, e `:id` intercetterebbe anche «orologio»
       * facendo fallire `int.parse`.
       */
      GoRoute(
        path: '/allenamento/orologio/:id',
        builder: (_, state) => AllenamentoOrologioScreen(
          id: int.parse(state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/allenamento/:id/riepilogo',
        builder: (_, state) => SessionSummaryScreen(
          sessionId: int.parse(state.pathParameters['id']!),
        ),
      ),
      // ⚠️ Questa DOPO `/allenamento/storico`: go_router prova le rotte
      // nell'ordine, e `:id` intercetterebbe anche «storico» facendo fallire
      // `int.parse`.
      GoRoute(
        path: '/allenamento/:id',
        builder: (_, state) =>
            PlayerScreen(sessionId: int.parse(state.pathParameters['id']!)),
      ),

      // La shell tiene la barra di navigazione ferma mentre cambia il
      // contenuto: senza, ogni cambio di scheda ricostruirebbe la barra e
      // l'animazione risulterebbe uno sfarfallio.
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(
            // D5 — la prima scheda è il riepilogo di oggi, non la galleria:
            // aprendo l'app la domanda è «come sto andando», non «che foto ho
            // fatto». I progressi restano raggiungibili dal profilo.
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (_, _) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.diary,
                builder: (_, _) => const DiaryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.training,
                builder: (_, _) => const PlansScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            // 🚨 La chat passa dalla porta delle chiavi (S6.7): senza chiave
            // maestra non si può né leggere né scrivere, e la porta decide se
            // chiedere di **creare** la password o di **ripristinare**.
            // ⚠️ L'ordine è la cosa facile da sbagliare — la spiegazione sta
            // per esteso in `PortaDelleChiavi`.
            routes: [
              GoRoute(
                path: AppRoutes.chat,
                builder: (_, _) =>
                    const PortaDelleChiavi(child: ConversationsScreen()),
              ),
            ],
          ),
          /*
           * 🚨 **Il ramo del profilo NON c'è più** — M7.1.
           *
           * ⚠️ Toglierlo dalla barra senza toglierlo da qui avrebbe lasciato un
           * quinto ramo irraggiungibile: `shell.goBranch(4)` non lo chiama
           * nessuno, ma `StatefulShellRoute` continuerebbe a costruirne lo
           * stato e a tenerlo vivo nell'`IndexedStack`.
           *
           * 💡 `/profilo` è diventata una rotta **sopra** la shell, come «i
           * miei utenti»: si spinge con `push`, ha il pulsante «indietro», e la
           * barra in basso resta dov'è.
           */
        ],
      ),

      /*
       * 👤 Il profilo — M7.1. Fuori dalla shell, sopra di essa.
       *
       * ⚠️ **Dopo** `StatefulShellRoute` e non prima: go_router prende la prima
       * rotta che combacia, e `/profilo/...` ha già dei figli dichiarati più in
       * alto (`/profilo/i-miei-utenti`, `/profilo/dati`…). Metterla sopra li
       * intercetterebbe tutti.
       */
      GoRoute(
        path: AppRoutes.profile,
        builder: (_, _) => const ProfileScreen(),
      ),

      /*
       * 💾 M7.3 — la copia di sicurezza delle chiavi.
       *
       * ⚠️ **Fuori da `PortaDelleChiavi`**, e non per dimenticanza: questa
       * schermata serve anche a chi la chat non l'ha mai aperta, e la porta gli
       * chiederebbe di creare una password prima di lasciarlo passare. 🚨 Se
       * non c'è ancora nessuna chiave, la schermata lo dice — che è
       * un'informazione utile, non un ostacolo.
       */
      GoRoute(
        path: AppRoutes.backup,
        builder: (_, _) => const SchermataBackup(),
      ),
    ],
  );
});

/// Trasforma due provider in un `Listenable` per go_router.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(this._ref) {
    _subs = [
      _ref.listen(authControllerProvider, (_, _) => notifyListeners()),
      _ref.listen(brandingControllerProvider, (_, _) => notifyListeners()),
    ];
  }

  final Ref _ref;
  late final List<ProviderSubscription<Object?>> _subs;

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.close();
    }
    super.dispose();
  }
}
