# `plan_trainingfe.md` — Specsheet operativa · **App Flutter**

> **Documento self-contained.** Copre il repository `trainingfe`. Il gemello per il backend è
> `trainingbe/plan_trainingbe.md`. I due si riferiscono a vicenda per ID di fase (`A4`, `B6`) ma
> ciascuno è leggibile da solo: chi riprende il progetto su un'altra macchina non deve avere
> entrambi i repo per poter lavorare su uno dei due.
>
> **Stato:** fase **A0** in corso · versione documento `v1.1.0` · aggiornato **2026-08-08**.

## Mappa dei documenti del progetto

| Documento | Dove | Cosa |
|---|---|---|
| `plan_trainingfe.md` | `trainingfe/` | **Questo file.** Piano di sviluppo dell'app |
| `plan_trainingbe.md` | `trainingbe/` | Piano di sviluppo del backend |
| `codebase_reference.md` | `trainingfe/` | Atlante del codice app — *nasce a fine A1* |
| `codebase_reference.md` | `trainingbe/` | Atlante del codice backend — *nasce a fine B1* |
| `codebase_reference.md` (generale) | *da decidere, vedi §14* | Atlante di piattaforma: contratto API, flusso dati end-to-end |

---

## 0. Cos'è questo documento

Il `codebase_reference.md` è **l'atlante**: dice *dov'è* e *che firma ha* ogni cosa già scritta.
Questo piano è la **specsheet operativa**: dice *cosa costruire, in che ordine, come e perché*.

**Criterio guida (non negoziabile):** se il progetto viene abbandonato su questa macchina e
ripreso su un'altra, un coding agent o un programmatore umano deve poter riprendere lo sviluppo
**senza perdere nulla**, seguendo questo documento passo per passo.

**Come si usa:** §6 (Tracking) → prima sottofase non spuntata → §7, ID stabile (`grep -n "A4.2"`)
→ esegui i passi → a fine **fase** esegui il **Rituale di fine fase** (§4), senza aspettare che
ti venga chiesto.

---

## 1. Il prodotto in una pagina

**Training Companion** è una piattaforma SaaS multi-tenant white-label per palestre: tracking
allenamento + alimentazione con AI. Questo repo è **l'app degli iscritti**.

### 1.1 Chi la usa e cosa ci fa

L'utente dell'app è **sempre e solo un `member`**: un iscritto a una palestra cliente. Non esiste
un'app per trainer o per gestori — quelli usano i pannelli web (`/admin` e `/god`) serviti dal
backend.

L'iscritto:
- **Esegue le schede** che il suo trainer gli ha assegnato, nel *player* (log serie, timer di
  riposo, foto, stima kcal a fine sessione).
- **Segue il piano alimentare** assegnato dal trainer.
- **Tiene il diario cibo** in tre modi: AI da testo («100 ml di birra, un cucchiaio d'olio»),
  AI da foto del piatto, o manuale — più i preferiti (singolo alimento o intero pasto).
- **Registra peso e foto progressi**, e vede dashboard, calendario e consiglio del giorno.
- **Chatta col proprio trainer.**

### 1.2 Cosa NON fa l'app

Non crea schede né piani alimentari (li riceve), non gestisce altri utenti, non ha un pannello
amministrativo. Non ha una modalità offline completa in v1 (vedi §13).

---

## 2. Decisioni architetturali (ADR)

### ADR-A01 — White-label: **app unica sugli store, tema applicato a runtime**
Una sola app pubblicata. All'onboarding l'utente inserisce il **codice della palestra** (o apre un
deep link d'invito); l'app chiama `GET /api/v1/branding/lookup?code=…`, scarica nome, logo e
colori, li mette in cache e costruisce il `ThemeData` da quelli.

**Perché.** Un solo build, una sola release, una sola coppia di account store. Una palestra nuova è
operativa in minuti senza toccare gli store, senza review, senza attese.
**La conseguenza vincolante:** **nessun colore, logo o nome prodotto può essere hardcodato fuori da
`lib/core/theme/`.** È la regola che tiene in piedi l'intero white-label; se si sfalda, si sfalda
in mille punti contemporaneamente ed è irrecuperabile senza un refactor.
**Come non chiudersi la porta.** `main.dart` resta sottile e la configurazione passa da
`lib/app/app_config.dart` con un `flavor`: generare un build dedicato per il cliente premium che
vuole la *sua* icona sugli store diventa un'aggiunta, non un refactor.

### ADR-A02 — **Toolchain scoped al progetto: FVM**
Flutter **non** viene aggiornato a livello di macchina. Si usa **FVM** per pinnare la versione solo
in `trainingfe`, con `.fvmrc` committato.
**Perché.** La macchina ospita altri progetti Flutter fermi su 3.27. Un `flutter upgrade` globale
li rompe silenziosamente, e il danno si scopre settimane dopo su un progetto che nessuno stava
toccando. Con FVM la versione è **un dato del repository**, non dell'ambiente: chi clona ottiene la
stessa identica toolchain.

### ADR-A03 — **Il backend è l'unica fonte di verità**
L'app non calcola target calorici, non stima kcal, non decide macro. Chiede al backend e mostra.
**Perché.** Nell'app storica le stesse calorie comparivano diverse in tre schermate perché tre
punti le ricalcolavano. Duplicare la logica su un secondo linguaggio moltiplica quel problema, e
una divergenza fra app e pannello del trainer è una telefonata di assistenza garantita.
**L'unica logica ammessa lato app** è di presentazione: formattazione, ordinamento locale,
validazione dei form prima dell'invio.

### ADR-A04 — **Chat: WebSocket con fallback di polling obbligatorio**
L'app si connette a Reverb sul canale privato, ma **deve** ricadere su polling a 15s se il socket
non si apre entro un timeout.
**Perché.** Su rete mobile, dietro captive portal o proxy aziendali, il WebSocket non si apre e
basta. Una chat che «non arriva» distrugge la fiducia nel prodotto molto più di una chat lenta.

### ADR-A05 — **Nessuna dipendenza pesante prima di A1**
I pacchetti si fissano in **A0.3**, dopo il pin della versione Flutter, e ogni aggiunta successiva
va motivata in questo documento.
**Perché.** Pinnare pacchetti su un Flutter di dicembre 2024 e poi aggiornare significa rifare il
`pubspec.lock` da zero, con giorni di incompatibilità da sbrogliare.

---

## 3. Stack e versioni (verificate 2026-08-08)

| Componente | Vincolo | Stato |
|---|---|---|
| Flutter | `3.44.x` stable, **via FVM** | globale: **3.27.1** (dic 2024) · ultima stable: **3.44.9** (2026-08-06) → pin in A0.2 |
| Dart | `>= 3.12` | globale `3.6.0` → arriva con Flutter 3.44 (`3.12.2`) |
| Target | iOS · Android | |
| Backend | `trainingbe`, API `/api/v1` | Sanctum bearer token |

I pacchetti Dart si fissano in **A0.3** (ADR-A05). Candidati previsti, da confermare al momento:
client HTTP con interceptor, secure storage, state management, routing, grafici, image picker,
cache immagini, client WebSocket.

---

## 4. ⚠️ RITUALE DI FINE FASE — obbligatorio

Alla fine di ciascuna **fase** (non sottofase), **senza aspettare che venga chiesto**, in ordine:

**4.1 — Aggiorna `plan_trainingfe.md`.** Spunta le checkbox in §6. Decisioni nuove → §2 come ADR;
trappole nuove → §12; rinvii → §13. Aggiorna la riga «Stato» in testa.

**4.2 — Aggiorna i `codebase_reference.md`.** Quello **di progetto** (`trainingfe/`) e quello
**generale di piattaforma** (§14) se la fase ha toccato il contratto con il backend.
Devono contenere: indice «dove sta cosa», albero dei file annotato, ogni classe/widget con ogni
metodo e **firma completa**, ogni modello dati con i campi, ogni schermata con il suo stato e le
sue dipendenze, ogni chiave di configurazione, catalogo test, regole non negoziabili, trappole
disinnescate, debito tecnico, e il *perché* delle scelte non ovvie.

**Verifica meccanica obbligatoria** prima di chiudere il punto:
```bash
fvm flutter analyze
grep -rn --include=*.dart -E '^\s*(Future<[^>]*>|void|[A-Z][A-Za-z0-9_<>,\? ]*)\s+[a-z_][A-Za-z0-9_]*\(' lib/
fvm flutter test
```
Confronta l'output con quanto documentato. **Un atlante sbagliato è peggio di nessun atlante.**

**4.3 — Messaggio di fine fase, ESTREMAMENTE DETTAGLIATO.** Un solo messaggio con: stato
dell'implementazione complessiva; **checkbox** della fase e di tutte le sue sottofasi con lo stato
reale; **commento** sullo stato generale del progetto **e** su quello specifico della fase (cosa
funziona, cosa è stato verificato e come, cosa è rimasto fuori e perché); file creati/modificati e
test aggiunti con **l'esito reale dell'esecuzione** (se falliscono si dice, con l'output).

**4.4 — Commit e push su un branch con versione nuova** (§5), su entrambe le remote.

---

## 5. Versionamento

Branch = versione, da `v1.0.0`. Avanza **a ogni commit**: piccola `+0.0.1` · media `+0.1.0` ·
grande `+1.0.0` (fine fase, breaking change, nuova area).

```bash
git checkout -b vX.Y.Z
git add -A && git commit -m "<tipo>: <descrizione>"
git push -u origin vX.Y.Z      # Gitea (push-to-create)
git push github vX.Y.Z         # GitHub
```

| Remote | URL |
|---|---|
| `origin` (Gitea, via Tailscale) | `https://git.home.varitest.ovh/smp-webmaster/trainingfe.git` |
| `github` | `https://github.com/Frostmoore/trainingfe.git` |

`trainingfe` e `trainingbe` avanzano di versione **in modo indipendente**. Utente Gitea:
**`smp-webmaster`**. Se il push `origin` fallisce, verificare Tailscale **prima di ogni altra cosa**.

---

## 6. TRACKING DELLE FASI — App

`[ ]` da fare · `[~]` in corso · `[x]` fatto e verificato.

Nella colonna «Dipende da» sono indicate le fasi del backend che devono essere chiuse prima.

### `[~]` A0 — Bootstrap del repository e del toolchain
- `[x]` **A0.1** `git init`, `.gitignore`, README, remote Gitea + GitHub, push `v1.0.0`
- `[x]` **A0.2** Stesura di `plan_trainingfe.md`
- `[x]` **A0.3** FVM: pin Flutter `3.44.9` **solo in questo repo** (ADR-A02) — *verificato: `fvm flutter --version` → 3.44.9 / Dart 3.12.2; `flutter --version` globale → ancora 3.27.1*
- `[ ]` **A0.4** Scaffolding `flutter create`, struttura cartelle, linting, CI-ready
- `[ ]` **A0.5** Pacchetti fissati in `pubspec.yaml` con motivazione per ciascuno

### `[ ]` A1 — Fondamenta *(dipende da: B1)*
- `[ ]` **A1.1** `bootstrap()`, dependency injection, gestione errori globale
- `[ ]` **A1.2** `AppConfig` + flavor + ambienti (locale / staging / prod)
- `[ ]` **A1.3** Client API tipizzato: interceptor token, mappatura errori, retry
- `[ ]` **A1.4** Secure storage (token) e cache locale (branding, dati sfogliabili)
- `[ ]` **A1.5** Router e struttura di navigazione
- `[ ]` **A1.6** Creazione di `trainingfe/codebase_reference.md`

### `[ ]` A2 — Onboarding white-label e autenticazione *(dipende da: B1)*
- `[ ]` **A2.1** Schermata «inserisci il codice della tua palestra» + deep link d'invito
- `[ ]` **A2.2** Fetch branding, cache, **costruzione del `ThemeData` a runtime** — ADR-A01
- `[ ]` **A2.3** Login, registrazione, logout
- `[ ]` **A2.4** Gestione 401 (sessione scaduta) e 403 `tenant_inactive` (palestra sospesa)
- `[ ]` **A2.5** Splash con logo della palestra + avvio a caldo dalla cache

### `[ ]` A3 — Design system e shell
- `[ ]` **A3.1** Token di design derivati dal branding (colori, tipografia, spaziature, raggi)
- `[ ]` **A3.2** Componenti comuni (card, stat tile, empty state, error state, loader, bottom sheet)
- `[ ]` **A3.3** Shell di navigazione e home a tile
- `[ ]` **A3.4** Tema chiaro e scuro derivati dallo stesso branding

### `[ ]` A4 — Diario cibo *(dipende da: B5, B6)*
- `[ ]` **A4.1** Vista giorno: voci per pasto, totali, **rosso quando si sfora il target**
- `[ ]` **A4.2** Inserimento AI da testo
- `[ ]` **A4.3** Inserimento AI da foto (fotocamera e galleria, compressione prima dell'upload)
- `[ ]` **A4.4** Inserimento manuale con **select unità di misura** e ricalcolo qty→grammi
- `[ ]` **A4.5** Preferiti: singolo alimento e intero pasto
- `[ ]` **A4.6** Modifica ed eliminazione voce
- `[ ]` **A4.7** Gestione degli errori AI (quota superata, servizio non disponibile) — §12

### `[ ]` A5 — Allenamento *(dipende da: B4)*
- `[ ]` **A5.1** Elenco schede assegnate e dettaglio
- `[ ]` **A5.2** Player: log serie, progressione fra esercizi
- `[ ]` **A5.3** Timer di riposo (con l'app in background)
- `[ ]` **A5.4** Foto di sessione
- `[ ]` **A5.5** Chiusura sessione, stima kcal, **override manuale**
- `[ ]` **A5.6** Storico allenamenti a card per settimana, lazy load

### `[ ]` A6 — Nutrizione assegnata, progressi, calendario *(dipende da: B4, B5)*
- `[ ]` **A6.1** Piano alimentare assegnato dal trainer
- `[ ]` **A6.2** Peso: inserimento e grafico della serie storica
- `[ ]` **A6.3** Galleria foto progressi (griglia lazy)
- `[ ]` **A6.4** Calendario mese/settimana con barra di progresso
- `[ ]` **A6.5** Dashboard: grafici peso e calorie, medie a 7 giorni, consiglio del giorno

### `[ ]` A7 — Chat col trainer *(dipende da: B8)*
- `[ ]` **A7.1** Elenco conversazioni
- `[ ]` **A7.2** Thread con storico paginato all'indietro
- `[ ]` **A7.3** Invio messaggi, stato di lettura
- `[ ]` **A7.4** WebSocket + **fallback polling a 15s** — ADR-A04
- `[ ]` **A7.5** Registrazione device token per le push

### `[ ]` A8 — Profilo, hardening, rilascio
- `[ ]` **A8.1** Profilo: sesso, età, altezza, attività, obiettivo, orari dei pasti
- `[ ]` **A8.2** Impostazioni, cambio palestra, logout, eliminazione account
- `[ ]` **A8.3** Notifiche push (ricezione e deep link)
- `[ ]` **A8.4** Accessibilità, stati di caricamento/errore/vuoto su ogni schermata
- `[ ]` **A8.5** Test: unit, widget, integrazione dei percorsi critici
- `[ ]` **A8.6** Icone, splash, firma, build di staging (TestFlight / internal testing)

---

## 7. GUIDA ALLO SVILUPPO

---

### A0 — Bootstrap

#### A0.3 — FVM: la versione di Flutter è un dato del repository (ADR-A02)

```powershell
dart pub global activate fvm          # installa FVM senza toccare l'SDK globale
cd trainingfe
fvm install 3.44.9                    # scarica la versione, non la attiva altrove
fvm use 3.44.9                        # crea .fvmrc e .fvm/ (pin del repo)
fvm flutter --version                 # atteso: 3.44.9 / Dart 3.12.2
flutter --version                     # atteso: ANCORA 3.27.1 — il globale non si tocca
```

Da qui in poi **ogni comando Flutter di questo repo si prefissa con `fvm`**: `fvm flutter pub get`,
`fvm flutter run`, `fvm flutter test`, `fvm dart …`.

Committare `.fvmrc`; **ignorare `.fvm/flutter_sdk`** (è un symlink alla cache locale, non ha senso
in git). Configurare l'IDE perché usi l'SDK di `.fvm/` invece di quello globale, altrimenti analyzer
e run useranno due versioni diverse — vedi §12.

#### A0.4 — Scaffolding e struttura

```bash
fvm flutter create --org ovh.varitest --project-name trainingfe \
                   --platforms=ios,android .
```

Struttura di `lib/` (da creare subito, anche se vuota: rende ovvio dove va ogni cosa):
```
main.dart                      # solo runApp(await bootstrap())
app/
  bootstrap.dart               # DI, config, error handling, inizializzazione
  app_config.dart              # baseUrl, flavor, feature flag
  router.dart
core/
  api/                         # client HTTP, interceptor token, mappatura errori
  storage/                     # secure storage token, cache branding
  theme/                       # ⚠️ UNICO posto dove esistono colori e logo (ADR-A01)
  widgets/                     # componenti comuni
  errors/                      # tipi di errore dell'app
features/
  onboarding/  auth/  dashboard/  diary/  workout/  nutrition_plan/
  progress/  calendar/  chat/  profile/
```
Ogni feature ha tre livelli: `data/` (DTO + repository), `domain/` (entità + use case),
`presentation/` (schermate + stato).

#### A0.5 — Pacchetti
Fissare `pubspec.yaml` **dopo** il pin di Flutter. Per ogni pacchetto aggiunto, una riga di
motivazione in questo documento: un pacchetto senza un perché scritto è un pacchetto che nessuno
oserà rimuovere fra sei mesi.

---

### A1 — Fondamenta *(richiede B1 chiusa)*

- **A1.1 `bootstrap()`** — inizializza binding, DI, error handler globale (`FlutterError.onError` +
  `PlatformDispatcher.instance.onError`), carica la config, restituisce il widget radice.
  `main.dart` non contiene altro che `runApp(await bootstrap())`: tutto ciò che può fallire
  all'avvio deve poter essere testato senza far partire l'app.
- **A1.2 `AppConfig`** — `baseUrl`, `flavor`, `enableLogging`. Tre ambienti: locale
  (`http://10.0.2.2:8000` su emulatore Android, `http://localhost:8000` su iOS), staging, produzione.
  > ⚠️ `localhost` dall'emulatore Android **non** è la macchina host: è l'emulatore stesso. Serve
  > `10.0.2.2`. È l'errore che fa perdere il primo pomeriggio a chiunque non lo sappia.
- **A1.3 Client API** — un solo punto d'ingresso. Interceptor che inietta
  `Authorization: Bearer …`; mappatura degli errori HTTP in tipi dell'app
  (`UnauthorizedError`, `TenantInactiveError`, `AiQuotaExceededError`, `ValidationError`,
  `NetworkError`, `ServerError`); retry con backoff **solo** su errori di rete e 5xx, **mai** su 4xx.
- **A1.4 Storage** — token in secure storage (Keychain / Keystore), **mai** in
  `SharedPreferences`. Il branding in cache normale: non è un segreto e deve essere leggibile
  all'avvio a freddo prima di qualsiasi rete.

---

### A2 — Onboarding white-label e autenticazione *(richiede B1 chiusa)*

**È la fase che rende reale il white-label.** Flusso all'avvio:

1. C'è un branding in cache? → **applicalo subito** (niente flash di tema di default), poi
   rinfrescalo in background.
2. Non c'è? → schermata «Inserisci il codice della tua palestra» →
   `GET /api/v1/branding/lookup?code=…` → salva in cache → costruisci il tema.
3. C'è un token valido? → home. Altrimenti → login, già vestito coi colori della palestra.

**Deep link d'invito.** `trainingcompanion://join/{code}` e link universale HTTPS: saltano il passo 2
e portano dritti alla registrazione. È il canale con cui la palestra fa entrare gli iscritti senza
dettare un codice a voce.

**Costruzione del tema (A2.2).** Dal payload `{colors:{primary,secondary,accent}, logo_url, name}`
si costruisce un `ColorScheme` completo — non solo tre colori sparsi: servono anche le varianti di
superficie, i colori «on» con contrasto sufficiente e gli stati di errore. Vive tutto in
`core/theme/brand_theme.dart` con una funzione pura `ThemeData buildTheme(Branding b, Brightness br)`,
testabile senza rete.
> ⚠️ Verificare il **contrasto**: una palestra sceglierà prima o poi un giallo acceso come
> `primary`. Il testo bianco sopra diventa illeggibile. Il tema deve calcolare il colore «on»
> dalla luminanza, non assumerlo.

**Errori (A2.4).** `401` → pulisci token, torna al login. `403 tenant_inactive` → schermata
dedicata «la tua palestra non è attiva, contatta la struttura», **non** un errore generico: è
l'unico caso in cui l'utente non può fare nulla da solo e dirglielo chiaramente evita una
telefonata all'assistenza sbagliata.

---

### A3 — Design system e shell

- **A3.1** Token derivati dal branding, non costanti. Un file `core/theme/tokens.dart` che espone
  spaziature, raggi e tipografia; i colori **arrivano sempre dal `ColorScheme`** costruito in A2.2.
- **A3.2** Componenti comuni con i tre stati (caricamento, vuoto, errore) previsti da subito:
  aggiungerli dopo significa ritoccare ogni schermata.
- **A3.4** Tema chiaro e scuro derivati dallo **stesso** branding: la palestra sceglie i colori una
  volta e devono funzionare in entrambi.

---

### A4 — Diario cibo *(richiede B5 e B6 chiuse)*

È la schermata più usata dell'app: qui si gioca la ritenzione.

- **A4.1** Voci raggruppate nei 6 pasti, totali del giorno confrontati col target, **rosso quando
  si sfora**. Il target arriva dal backend (`GET /api/v1/diary?date=…`) già comprensivo delle
  calorie bruciate del giorno — l'app **non lo ricalcola** (ADR-A03).
- **A4.3 Foto.** Comprimere prima dell'upload: lato lungo max **1568 px**. Oltre non migliora la
  stima e costa token — è una scelta di costo che si prende lato client perché è lì che nasce il file.
- **A4.4 Manuale.** Select delle unità di misura popolata dal backend; il ricalcolo
  quantità→grammi avviene lato server, l'app mostra il risultato.
- **A4.7 Errori AI.** Tre casi distinti, tre messaggi distinti: `429 ai_quota_exceeded` → «la tua
  palestra ha esaurito il credito AI di questo mese» + suggerimento di inserire a mano; `502
  ai_unavailable` → «servizio momentaneamente non disponibile, riprova» + inserimento manuale;
  errore di rete → retry. Un errore generico su tutti e tre lascia l'utente bloccato senza sapere
  che può comunque inserire il pasto a mano.

---

### A5 — Allenamento *(richiede B4 chiusa)*

- **A5.2 Player.** Deve reggere il caso reale: telefono in tasca fra una serie e l'altra, schermo
  che si spegne, rientro nell'app. Lo stato della sessione va persistito **a ogni serie loggata**,
  non a fine allenamento.
- **A5.3 Timer di riposo.** Deve continuare con l'app in background e notificare a scadenza.
  È la funzione che l'utente usa 15 volte per sessione: se sbaglia, l'app è inutilizzabile in palestra.
- **A5.5** Stima kcal dal backend a fine sessione, **modificabile a mano**: il valore manuale vince
  sempre (regola di piattaforma, vedi `plan_trainingbe.md` §B4.3).

---

### A6 — Nutrizione assegnata, progressi, calendario

- **A6.1** Il piano del trainer è **in sola lettura** nell'app: si consulta, non si modifica.
  Le modifiche passano dal trainer, altrimenti la prescrizione perde senso.
- **A6.5 Dashboard.** Grafici peso e calorie (assunte e bruciate) con storici scorrevoli, medie a 7
  giorni **sui soli giorni con dati** (una media che conta gli zeri dei giorni non registrati è
  falsa e demoralizzante), consiglio del giorno renderizzato da markdown.

---

### A7 — Chat *(richiede B8 chiusa)*

- **A7.4** Ordine di tentativo: apri il WebSocket; se non si connette entro il timeout **o cade**,
  passa al polling a 15s e continua a ritentare il socket in sottofondo. La UI **non deve mai
  mostrare quale dei due canali è attivo**: è un dettaglio implementativo, e mostrarlo trasforma un
  fallback trasparente in un difetto percepito.

---

### A8 — Profilo, hardening, rilascio

- **A8.2 Cambio palestra.** Un utente che cambia palestra deve poter ripartire dall'onboarding:
  logout + pulizia della cache di branding + ritorno alla schermata del codice.
- **A8.6** Icone e splash **dell'app unica**, non di una palestra (ADR-A01): il branding del
  cliente compare dopo l'onboarding, non sull'icona.

---

## 8. Contratto con il backend (riepilogo)

Autenticazione: `Authorization: Bearer <token Sanctum>`. Base: `/api/v1`.

| Area | Endpoint | Fase BE |
|---|---|---|
| Branding | `GET /branding/lookup?code=` **(pubblico)** | B1 |
| Auth | `POST /auth/register` · `/auth/login` · `/auth/logout` · `GET /auth/me` · `GET /auth/devices` | B1 |
| Allenamento | `GET /workout-plans` · `/workout-plans/{id}` · `POST /workout-sessions` · `POST /workout-sessions/{id}/sets` · `/finish` · `PATCH /workout-sessions/{id}/kcal` | B4 |
| Corpo e foto | `POST\|GET /body-metrics` · `POST\|GET /photos` · `GET /photos/{id}/file` | B4 |
| Diario | `GET /diary?date=` · `POST\|PATCH\|DELETE /food-entries` · `/food-favorites` · `POST /daily-burn` · `GET /targets` | B5 |
| Piano alimentare | `GET /nutrition-plan` | B5 |
| AI | `POST /ai/food/text` · `POST /ai/food/photo` · `GET /ai/advice` | B6 |
| Chat | `GET /conversations` · `GET /conversations/{id}/messages?before=` · `POST …/messages` · `POST …/read` | B8 |

**Codici d'errore che l'app deve trattare in modo distinto:** `401` (sessione scaduta),
`403 tenant_inactive` (palestra sospesa), `429 ai_quota_exceeded` (credito AI esaurito),
`502 ai_unavailable` (AI momentaneamente giù), `422` (validazione).

---

## 9. Regole non negoziabili

1. **Nessun colore, logo o nome prodotto hardcodato fuori da `lib/core/theme/`** (ADR-A01).
2. **Nessuna logica di dominio duplicata dal backend** (ADR-A03): target, macro e kcal si chiedono.
3. **Il token sta in secure storage**, mai in `SharedPreferences`, mai nei log.
4. **Ogni comando Flutter si prefissa con `fvm`** (ADR-A02).
5. **La chat ha sempre un fallback di polling** (ADR-A04).
6. **Ogni schermata ha i tre stati**: caricamento, vuoto, errore.
7. **Le immagini si comprimono prima dell'upload** (lato lungo max 1568 px).
8. **Nessun test tocca la rete**: il client API si sostituisce con un fake.

---

## 10. Catalogo dei test

| Test | Cosa dimostra | Fase |
|---|---|---|
| `brand_theme_test` | `buildTheme()` produce contrasti leggibili anche con `primary` chiarissimo o scurissimo | A2 |
| `api_error_mapping_test` | Ogni codice HTTP finisce nel tipo di errore giusto; nessun 4xx viene ritentato | A1 |
| `token_storage_test` | Il token finisce in secure storage e viene pulito al logout | A1 |
| `onboarding_flow_test` | Codice valido → branding in cache → tema applicato; codice ignoto → messaggio corretto | A2 |
| `diary_totals_widget_test` | Il totale diventa rosso al superamento del target | A4 |
| `player_persistence_test` | Chiudere e riaprire l'app a metà sessione non perde le serie loggate | A5 |
| `chat_fallback_test` | Socket non disponibile → il polling subentra senza cambiare la UI | A7 |

---

## 11. Configurazione

| Chiave | Dove | Significato |
|---|---|---|
| `API_BASE_URL` | `--dart-define` / `AppConfig` | Backend di destinazione per ambiente |
| `FLAVOR` | `--dart-define` | `dev` \| `staging` \| `prod` |
| `ENABLE_LOGGING` | `--dart-define` | Log di rete, **mai attivo in prod** |

> Nessun segreto nell'app. Le chiavi API dei provider AI vivono **solo sul backend**: l'app non
> parla mai direttamente con un fornitore AI. Un segreto dentro un binario distribuito sugli store
> è un segreto pubblico.

---

## 12. Trappole note

- **FVM e IDE.** Se l'IDE punta all'SDK globale invece che a `.fvm/`, analyzer e run usano due
  versioni diverse e gli errori non hanno senso. Configurare il path dell'SDK per progetto.
- **`localhost` dall'emulatore Android** è l'emulatore, non la macchina host: usare `10.0.2.2`.
  Su iOS Simulator `localhost` funziona.
- **Flash di tema.** Se il branding si carica dopo il primo frame, l'utente vede l'app coi colori di
  default e poi un cambio brusco. Il tema in cache va applicato **prima** del primo `build`.
- **Contrasto sui colori del cliente.** Prima o poi qualcuno sceglie un giallo fluo come `primary`:
  i colori «on» vanno calcolati dalla luminanza, non assunti.
- **Timer in background.** Su iOS l'esecuzione in background è limitata: il timer di riposo va
  implementato con una notifica programmata, non con un `Timer` che presume che l'app resti viva.
- **Upload di foto grandi.** Senza compressione lato client l'upload da rete mobile fallisce e i
  token immagine costano il triplo.
- **Errori AI generici.** Trattare `429`, `502` e gli errori di rete allo stesso modo lascia
  l'utente bloccato senza sapere che può inserire il pasto a mano.

---

## 13. Debito tecnico / cosa NON esiste

- **Modalità offline completa:** non c'è. L'app fa cache di lettura, ma senza rete non si può
  registrare un pasto o una serie. Da valutare dopo il primo cliente reale, con dati d'uso in mano.
- **App per il trainer:** non esiste e non è pianificata; il trainer usa il pannello web.
- **Flavor per-palestra sugli store:** possibile per architettura (ADR-A01), non pianificato.
- **Test di integrazione end-to-end:** solo unit e widget test fino a A8.5.
- **Notifiche push:** i token si registrano in A7.5, la ricezione arriva in A8.3, l'invio è lato
  backend in B10.6.
- **Localizzazione:** solo italiano in v1. Le stringhe stanno comunque in un file di traduzione,
  così aggiungere una lingua non è un refactor.

---

## 14. ⚠️ Punto aperto: dove vive il `codebase_reference.md` generale

Servono **tre** atlanti: quello di questo repo, quello di `trainingbe`, e uno **generale di
piattaforma** (contratto API, flusso dati end-to-end, matrice «feature → fase backend + fase app»).

I primi due hanno una casa ovvia. Il terzo no, perché la cartella padre
`E:\coding\XAMPP\htdocs\TrainingCompanionAI\` non è un repository. La discussione completa delle
opzioni è in `trainingbe/plan_trainingbe.md` §16; la raccomandazione è **versionare la cartella
padre come terzo repository**, perché è l'unica opzione che non perde il documento cambiando
macchina. Decisione da confermare **prima di chiudere A1**.
