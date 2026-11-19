import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/acquisti/ui/modale_acquisti.dart';
import '../../features/auth/auth_controller.dart';
import '../../features/auth/data/app_user.dart';
import '../../features/dashboard/gettoni_controller.dart';
import '../../features/onboarding/branding_controller.dart';
import '../../features/onboarding/data/gym_branding.dart';
import '../../features/profile/ui/widgets/bottone_profilo.dart';
import '../theme/app_theme.dart';
import 'testata_scura.dart';

/// L'intestazione dell'app — **una sola, su tutte le schermate**. 3b-O.1a.6,
/// 21/08/2026.
///
/// ══ 🚨 PERCHÉ SOSTITUISCE L'`AppBar` E NON LE STA ACCANTO ═════════════════
///
/// 📌 Il committente: *«questa parte va su TUTTE le pagine, non solo su
/// Oggi»* — la riga con il logo della palestra, il nome, il saldo dei gettoni e
/// l'avatar del profilo.
///
/// ⚠️ **Questa è un'app white-label**, e la riga dell'identità non è
/// decorazione: l'iscritto deve percepirla come l'app della *sua* palestra, non
/// come un prodotto di qualcun altro in cui è entrato con un codice (ADR-A01).
/// 🚨 Un'`AppBar` grigia con scritto «Diario» rompe quel patto ogni volta che si
/// esce da «Oggi» — cioè quasi sempre.
///
/// 💡 E il saldo dei gettoni ha lo stesso motivo, più concreto: è un numero che
/// si guarda **prima** di fare qualcosa. Chi sta per fotografare un piatto dal
/// diario deve sapere di averne dieci **da lì**, non tornando indietro di due
/// schermate.
///
/// ── ⚠️ Due righe, e nessuna è facoltativa ────────────────────────────────
///
/// | Riga | Cosa c'è | Quando |
/// |---|---|---|
/// | **identità** | logo palestra · nome · gettoni · profilo | **sempre** |
/// | **navigazione** | ← · titolo · azioni | quando c'è un [titolo] |
///
/// 🚨 **L'ordine conta**: l'identità sta sopra perché è la cosa che non cambia,
/// e il titolo sotto perché è la cosa che cambia. Invertirle farebbe ballare la
/// riga fissa a ogni pagina.
///
/// ── 🚨 La trappola dell'altezza ──────────────────────────────────────────
///
/// Implementa [PreferredSizeWidget], quindi va in `Scaffold.appBar` come
/// un'`AppBar` qualunque. ⚠️ Ma [preferredSize] è un getter **senza
/// `BuildContext`**: non può misurare né il testo né la barra di sistema.
///
/// 💡 La soluzione è la stessa di Material: **altezze fisse e testi a una riga
/// con i puntini**. Un titolo lungo o un carattere ingrandito **taglia**, non
/// sfora — che è il comportamento di `AppBar` da sempre, e regge perché è già
/// provato su milioni di schermate.
///
/// ⚠️ Lo spazio della barra di sistema **non** va contato in [preferredSize]:
/// lo aggiunge `Scaffold` da solo (`MediaQuery.padding.top`). Contarlo qui
/// vorrebbe dire contarlo due volte, e l'intestazione crescerebbe di 40 px su
/// ogni telefono.
///
/// ── 💡 Fuori da uno `Scaffold` funziona lo stesso ────────────────────────
///
/// È un widget normale: «Oggi» lo mette **dentro il corpo**, come primo figlio
/// della lista, perché lì l'intestazione è alta, porta i numeri della giornata
/// e **deve scorrere via**. In quel caso [preferredSize] è semplicemente
/// ignorato, e [sotto] porta la parte specifica della pagina.
class IntestazioneApp extends ConsumerWidget implements PreferredSizeWidget {
  const IntestazioneApp({
    this.titolo,
    this.sottotitolo,
    this.azioni = const <Widget>[],
    this.indietro = true,
    this.sotto,
    this.altezzaSotto = 0,
    this.arrotondata = true,
    super.key,
  });

  /// Il titolo della pagina. `null` su «Oggi», che non ne ha bisogno: è la
  /// schermata d'ingresso, e il nome della palestra la identifica già.
  final String? titolo;

  /// Una seconda riga sotto il titolo — la usa il player per il cronometro.
  final String? sottotitolo;

  /// Quello che stava in `AppBar.actions`.
  final List<Widget> azioni;

  /// ⛔ `false` dove tornare indietro **non deve** essere possibile: la
  /// password di recupero e il ritrovamento dell'account, dove saltare il passo
  /// lascerebbe un account a metà.
  final bool indietro;

  /// La parte specifica della pagina, sotto le due righe fisse.
  final Widget? sotto;

  /// 🚨 Serve solo quando questa intestazione fa da `Scaffold.appBar`: senza,
  /// `Scaffold` non saprebbe quanto spazio riservare a [sotto] e lo taglierebbe.
  /// 💡 Dentro il corpo — il caso di «Oggi» — si lascia a zero.
  final double altezzaSotto;

  /// 🆕 Gli angoli in basso arrotondati — `plan_interfaccia.md` I1, 19/11/2026.
  ///
  /// `true` quando fa da `Scaffold.appBar`: è la testata della pagina, e sopra
  /// il corpo chiaro si deve vedere finire. ⚠️ `false` quando sta **dentro**
  /// una [TestataScura]: lì gli angoli li fa il blocco intero, e una curva a
  /// metà testata sembrerebbe un pezzo staccato.
  final bool arrotondata;

  /// Alta come una barra Material, così le due si somigliano dove convivono.
  static const altezzaIdentita = 56.0;

  static const altezzaTitolo = 48.0;

  /// 🆕 **La riga del titolo con il sottotitolo sotto** — I5, 19/11/2026.
  ///
  /// 🚨 Visto sull'emulatore nella seduta in corso: «Sessione libera» con il
  /// cronometro sotto **sforava di 5 px** i 48 della riga — *BOTTOM OVERFLOWED*.
  /// In produzione le strisce gialle non si vedono, ma il cronometro esce
  /// tagliato in basso. ⚠️ Un `titleLarge` e un `bodySmall` uno sopra l'altro
  /// non ci stanno in 48: servono 60.
  static const altezzaTitoloConSottotitolo = 60.0;

  double get _altezzaTitolo =>
      sottotitolo == null ? altezzaTitolo : altezzaTitoloConSottotitolo;

  @override
  Size get preferredSize => Size.fromHeight(
    altezzaIdentita + (titolo == null ? 0.0 : _altezzaTitolo) + altezzaSotto,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palestra = ref.watch(brandingControllerProvider).branding;

    /*
     * 🚨 **Il nome: la palestra, o la persona** — 3b-O.1a.3.
     *
     * ⚠️ `haPalestra` e **non** `name != null`: `GymBranding.neutral` ha
     * `name: 'Training Companion'`, e il controllo sul nome scriveva il nome
     * dell'app in cima alla schermata di chi una palestra non ce l'ha. Vedi
     * §56.3 n° 2 dell'atlante.
     */
    final utente = ref.watch(authControllerProvider).user;
    final nome = palestra.haPalestra
        ? palestra.name!
        : (utente?.name ?? 'Training Companion');

    /*
     * ⛔ La freccia indietro c'è **solo se c'è dove tornare**.
     *
     * ⚠️ `canPop()` e non `indietro` da solo: le schermate della barra in basso
     * sono radici di navigazione, e disegnarci una freccia che non fa niente è
     * peggio di non disegnarla — promette un'azione che non c'è.
     *
     * 🚨 **`Navigator` e non `GoRouter`**, e non è un dettaglio: `GoRouter.of`
     * lancia un'asserzione se sopra non c'è un router, e questa intestazione
     * ora sta su **ogni** pagina — compresi i test di widget, che montano un
     * `MaterialApp` liscio. ⚠️ Un componente condiviso non può pretendere metà
     * dell'infrastruttura dell'app per disegnarsi.
     *
     * 💡 Ed è esattamente quello che fa il `BackButton` di Material da sempre:
     * `Navigator.maybePop`. Funziona anche con go_router, perché `context.push`
     * impila sullo stesso `Navigator`.
     */
    final puoTornare = indietro && Navigator.of(context).canPop();

    /*
     * ══ 🌑 SCURA, DAL 19/11/2026 — `plan_interfaccia.md` §3.2 ════════════════
     *
     * ⛔ Fino al 19/11 qui c'era il gradiente `primaryContainer` della palestra.
     * Le tavole approvate vogliono una testata **scura** su tutte le pagine, e
     * farlo qui vuol dire farlo su tutte e 44 in una mossa — comprese quelle
     * che una tavola non ce l'hanno.
     *
     * 🔑 **Lo sfondo si calcola FUORI dal tema scuro**: `sfondoPer` guarda se
     * il telefono è in chiaro o in scuro, e dentro il `Theme` scuro qui sotto
     * la risposta sarebbe sempre «scuro».
     *
     * 💡 Il colore della palestra non sparisce: il logo resta, e dentro il
     * tema scuro `onPrimaryContainer` è il tono chiaro del suo colore — i testi
     * qui sotto lo usavano già, e non serve toccarli.
     */
    final sfondo = TestataScura.sfondoPer(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // 🚨 A2 — le icone di sistema sopra la testata. Ora, batteria e segnale
      // li disegna Android, di serie scuri: sopra un fondo quasi nero
      // sparirebbero. `stileBarraDiSistema` legge lo sfondo e li fa chiari.
      value: stileBarraDiSistema(sfondo),
      child: Theme(
        data: TestataScura.temaPer(palestra),
        child: Builder(
          builder: (context) =>
              _disegna(context, palestra, utente, nome, puoTornare, sfondo),
        ),
      ),
    );
  }

  Widget _disegna(
    BuildContext context,
    GymBranding palestra,
    AppUser? utente,
    String nome,
    bool puoTornare,
    Color sfondo,
  ) {
    // ⚠️ Il tema **scuro** della testata, non quello della pagina: è il
    // `context` del `Builder` sotto il `Theme`.
    final theme = Theme.of(context);

    return Material(
      // 🚨 Rimette il `DefaultTextStyle` del tema scuro: senza, un testo senza
      // stile proprio fra le [azioni] prenderebbe il nero dello `Scaffold`.
      type: MaterialType.transparency,
      child: Container(
        decoration: BoxDecoration(
          color: sfondo,
          borderRadius: arrotondata
              ? const BorderRadius.vertical(
                  bottom: Radius.circular(TestataScura.raggio),
                )
              : null,
        ),

        /*
         * 🚨 **`SafeArea` DENTRO il `Container`, non intorno** — A2.
         *
         * Intorno, il gradiente comincerebbe **sotto** la barra di sistema e
         * dietro l'orologio resterebbe una striscia del colore dello sfondo:
         * sembra un errore di disegno. Qui invece il colore riempie fino in
         * cima e a scendere è solo il **contenuto**.
         *
         * ⚠️ E non un padding fisso: la barra di sistema è alta in modo diverso
         * su ogni telefono, e sui modelli con l'isola è il doppio.
         */
        child: SafeArea(
          bottom: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: altezzaIdentita,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Gap.md),
                  child: Row(
                    children: [
                      LogoPalestra(palestra: palestra),
                      const SizedBox(width: Gap.sm),

                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nome,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),

                            /*
                             * 🆕 **Il nome della persona sotto quello della
                             * palestra** — 3b-O.1a.3/O.1a.4.
                             *
                             * ⚠️ Solo quando la palestra c'è: senza, il nome
                             * della persona è già la riga grande sopra, e
                             * ripeterlo sarebbe la stessa informazione detta
                             * due volte.
                             */
                            if (palestra.haPalestra && utente != null)
                              Text(
                                utente.name,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),

                      /*
                       * 🚨 **Gettoni prima, profilo dopo** — M7.1, 16/08/2026.
                       *
                       * ⚠️ Il saldo si guarda ogni giorno, il profilo una volta
                       * a settimana: l'ordine di lettura va dal più usato al
                       * meno usato.
                       */
                      const SaldoGettoni(),
                      const BottoneProfilo(),
                    ],
                  ),
                ),
              ),

              if (titolo != null)
                SizedBox(
                  height: _altezzaTitolo,
                  child: Padding(
                    padding: EdgeInsets.only(
                      // 💡 Meno padding a sinistra quando c'è la freccia: il
                      // tocco dell'icona ha già il suo margine dentro.
                      left: puoTornare ? Gap.xs : Gap.md,
                      right: Gap.sm,
                    ),
                    child: Row(
                      children: [
                        if (puoTornare)
                          IconButton(
                            onPressed: () => Navigator.maybePop(context),
                            icon: const Icon(Icons.arrow_back_rounded),
                            color: theme.colorScheme.onPrimaryContainer,
                            tooltip: 'Indietro',
                          ),

                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                titolo!,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),

                              if (sottotitolo != null)
                                Text(
                                  sottotitolo!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onPrimaryContainer,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),

                        /*
                         * 🚨 Le azioni ereditano il colore **dell'intestazione**,
                         * non quello dell'`AppBar` che non c'è più.
                         *
                         * ⚠️ Senza questo, un `IconButton` senza colore proprio
                         * resta `onSurface` — cioè scuro sopra il gradiente
                         * della palestra, che su un colore acceso è illeggibile.
                         */
                        ...azioni.map(
                          (a) => IconTheme.merge(
                            data: IconThemeData(
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                            // 🚨 **Anche i `TextButton`**, non solo le icone:
                            // fra le azioni c'e' «Salva» sui due compositori, e
                            // di serie prende `primary` — che sopra il
                            // `primaryContainer` della palestra e' il colore
                            // piu' vicino allo sfondo, cioe' il meno leggibile.
                            child: TextButtonTheme(
                              data: TextButtonThemeData(
                                style: TextButton.styleFrom(
                                  foregroundColor:
                                      theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                              child: a,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              ?sotto,
            ],
          ),
        ),
      ),
    );
  }
}

/// Le icone della barra di sistema, chiare o scure secondo lo sfondo — A2.
///
/// ⚠️ **`Brightness` qui è quella dello SFONDO, e le icone escono al
/// contrario.** È il punto in cui ci si sbaglia: `statusBarIconBrightness`
/// vuole la luminosità *delle icone*, mentre `statusBarBrightness` (iOS) vuole
/// quella *dello sfondo*. Scriverle uguali fa icone bianche su fondo bianco su
/// una delle due piattaforme, e la si scopre solo sull'altra.
SystemUiOverlayStyle stileBarraDiSistema(Color sfondo) {
  final chiaro =
      ThemeData.estimateBrightnessForColor(sfondo) == Brightness.light;

  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: chiaro ? Brightness.dark : Brightness.light,
    statusBarBrightness: chiaro ? Brightness.light : Brightness.dark,
  );
}

/// Il logo della palestra, o il suo ripiego.
class LogoPalestra extends StatelessWidget {
  const LogoPalestra({required this.palestra, super.key});

  final GymBranding palestra;

  @override
  Widget build(BuildContext context) {
    /*
     * 🆕 **L'anello chiaro** — `plan_interfaccia.md` I1, 19/11/2026.
     *
     * 🚨 Visto sull'emulatore col caso A5: il cerchio del logo ha il colore
     * della palestra, e una palestra **blu scuro** sulla testata quasi nera
     * spariva del tutto — restava una «A» che galleggiava. ⚠️ Non è un caso
     * raro: i colori «seri» delle palestre sono spesso scuri.
     *
     * 💡 Un anello sottile del colore del testo lo stacca dal fondo qualunque
     * sia il colore della palestra, senza toccare il colore stesso (che è il
     * marchio del cliente, ADR-A01).
     */
    return DecoratedBox(
      /*
       * 🚨 **`foreground`, non la posizione di serie** — visto sull'emulatore.
       * Di serie la decorazione sta **dietro** il figlio: il `CircleAvatar` è
       * grande esattamente quanto il cerchio, e lo copriva tutto. L'anello
       * c'era e non si vedeva.
       */
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          // ⚠️ 0.3 era troppo poco: sull'emulatore, a una palestra blu scuro,
          // l'anello quasi non si vedeva. 0.55 lo stacca senza fare cornice.
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
          width: 2,
        ),
      ),
      child: _cerchio(context),
    );
  }

  Widget _cerchio(BuildContext context) {
    final theme = Theme.of(context);

    // ⚠️ Il logo può non esserci: molte palestre non lo caricano. L'iniziale su
    // fondo colorato è il ripiego, ed è lo stesso disegno della schermata di
    // accesso — cambiarlo qui farebbe sembrare due app diverse.
    if (palestra.logoUrl == null || palestra.logoUrl!.isEmpty) {
      return CircleAvatar(
        radius: 18,
        backgroundColor: palestra.primary,
        // 💡 Senza palestra resta il cerchio con il simbolo dell'app: un buco
        // in cima alla dashboard la fa sembrare rotta, ed è il motivo per cui
        // questo ripiego esiste. Vedi la nota gemella in `MarchioInCima`.
        child: palestra.haPalestra
            ? Text(
                palestra.name!.characters.first.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              )
            /*
             * 🆕 **Il monogramma anche qui** — 22/09/2026 (DA-FARE 15).
             *
             * 📌 Il committente: *«anche nell'intestazione»*. ⛔ Qui c'era
             * ancora il manubrio di Material, tolto dalle schermate d'accesso il
             * 15/09: l'app si presentava col suo marchio all'ingresso e con
             * un'icona di serie su ogni pagina dopo.
             *
             * 💡 Lo stesso ripiego di `MarchioInCima` se l'asset non arrivasse.
             */
            /*
             * ⚠️ **Niente margine, e il segno ingrandito**: in `segno.png` il
             * disegno occupa solo il 48% del quadrato (il resto è trasparente).
             * A 36 px, col margine della schermata d'accesso, restava un segno
             * di 9 px — illeggibile, visto sull'emulatore. Così è circa due
             * terzi del cerchio.
             */
            : Transform.scale(
                scale: 1.35,
                child: Image.asset(
                  'assets/marchio/segno.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.fitness_center_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
      );
    }

    return CircleAvatar(
      radius: 18,
      backgroundColor: theme.colorScheme.surface,
      backgroundImage: NetworkImage(palestra.logoUrl!),
    );
  }
}

/// Il saldo dei gettoni nell'intestazione — 16/08/2026.
///
/// ── 💡 Perché non mostra niente mentre carica ─────────────────────────────
///
/// Un numero che compare, sparisce e ricompare a ogni apertura è peggio di un
/// numero che arriva mezzo secondo dopo. E se la chiamata fallisce non si
/// scrive «errore» in mezzo al saluto: il saldo semplicemente non c'è, e
/// l'intestazione resta quella di prima.
///
/// ⚠️ **Non blocca niente.** È informativo: il cancello vero è sul server, che
/// risponde `402` con quanti gettoni servivano. Un client non decide mai i
/// permessi — vale qui come per `ai_enabled`.
class SaldoGettoni extends ConsumerWidget {
  const SaldoGettoni({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return ref
        .watch(gettoniProvider)
        .maybeWhen(
          orElse: () => const SizedBox.shrink(),
          data: (g) {
            /*
             * 🚨 Il contatore c'è **sempre**: illimitato, pieno o a zero.
             *
             * ⚠️ Nasconderlo a chi non ha gettoni comprati sembrava gentile e
             * non lo era: chi lo cerca e non lo trova pensa che sia rotto. Uno
             * zero almeno si capisce, e dice pure cosa fare.
             *
             * 💡 `null` = illimitata: si disegna un simbolo, mai uno zero.
             */
            final testo = g.illimitata ? '∞' : '${g.disponibili ?? 0}';

            /*
             * ══ 💳 SI TOCCA, E PORTA A COMPRARE — 3b-H, 26/08/2026 ═════════
             *
             * 📌 *«collegata alla pillola dei gettoni nell'header»*.
             *
             * 💡 È il posto giusto: chi guarda quel numero lo guarda **perché
             * sta finendo**, ed è l'unico momento in cui l'offerta non è
             * un'interruzione ma una risposta.
             *
             * ⚠️ Una modale e non una schermata: si chiude e sotto c'è ancora
             * quello che si stava facendo.
             */
            final pillola = Tooltip(
              message: g.illimitata
                  ? 'Gettoni AI illimitati'
                  // 💡 «comprati», non «questo mese»: sono i soli che questo
                  // numero conta, e chiamarli come non sono farebbe cercare una
                  // ricarica che non è mancata.
                  : 'Ti restano ${g.disponibili ?? 0} gettoni AI comprati',
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Gap.sm,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onPrimaryContainer.withValues(
                    alpha: 0.10,
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.toll_outlined,
                      size: 16,
                      // 💡 Sotto il costo di una foto cambia colore: chi ha 6
                      // gettoni non è a zero, ma la prossima foto non la fa — e
                      // scoprirlo dopo aver inquadrato il piatto è la sequenza
                      // peggiore.
                      color: g.quasiFiniti
                          ? theme.colorScheme.error
                          : theme.colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      testo,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: g.quasiFiniti
                            ? theme.colorScheme.error
                            : theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            );

            return Semantics(
              button: true,
              label: 'Gettoni AI: tocca per comprarne',
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => ModaleAcquisti.mostra(context),
                child: pillola,
              ),
            );
          },
        );
  }
}
