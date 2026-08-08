# Training Companion — App (`trainingfe`)

App **Flutter** per gli iscritti delle palestre clienti di **Training Companion**.

App **unica** sugli store, **white-label a runtime**: all'onboarding l'utente inserisce il
codice della propria palestra, l'app scarica il branding (logo, colori, nome) dal backend e
applica il tema dinamicamente. Una nuova palestra è attiva senza toccare gli store.

Cosa fa l'iscritto: esegue le schede assegnate dal trainer, segue il piano alimentare, usa il
diario cibo con AI (testo, foto, manuale), registra peso e foto progressi, vede la dashboard
e chatta col proprio trainer.

## 📘 Documentazione

| Documento | Dove | Cos'è |
|---|---|---|
| [`plan_trainingfe.md`](./plan_trainingfe.md) | qui | **La specsheet operativa dell'app.** Fasi A0–A8, ADR con le motivazioni, contratto con il backend, trappole note |
| `plan_trainingbe.md` | [`trainingbe`](https://github.com/Frostmoore/trainingbe) | La specsheet operativa del backend (fasi B0–B10) |
| `codebase_reference.md` | qui | Atlante del codice app. *Non esiste ancora: nasce a fine **A1*** |
| `codebase_reference.md` | `trainingbe` | Atlante del codice backend. *Nasce a fine **B1*** |
| `codebase_reference.md` generale | *da decidere* | Atlante di piattaforma. Vedi [`plan_trainingfe.md` §14](./plan_trainingfe.md) |

Ogni piano è **self-contained**: non serve avere entrambi i repo per lavorare su uno dei due.
Se questo README e il piano divergono, **vince il piano**.

## Stack

Flutter **3.44.9** · Dart **3.12.2** — target iOS e Android.

> ⚠️ La versione di Flutter è **pinnata con FVM su questo repository** (`.fvmrc`), non installata
> globalmente: l'SDK di sistema resta quello che era, così gli altri progetti Flutter della
> macchina non si rompono (ADR-A02).
>
> **Ogni comando va prefissato con `fvm`.**

## Backend

Le API sono servite da [`trainingbe`](https://github.com/Frostmoore/trainingbe) sotto `/api/v1`,
autenticate con token Sanctum (`Authorization: Bearer …`). Il contratto completo è in
[`plan_trainingfe.md` §8](./plan_trainingfe.md).

## Avvio in locale

```bash
dart pub global activate fvm     # una volta sola, per macchina
fvm install                      # legge .fvmrc e scarica la versione giusta
fvm flutter --version            # atteso: 3.44.9 / Dart 3.12.2
fvm flutter pub get
fvm flutter run
```

## Versionamento

I branch si chiamano come le versioni, da `v1.0.0`. `trainingbe` e `trainingfe` avanzano di
versione **in modo indipendente**. Due remote: `origin` → Gitea (rete privata, Tailscale)
· `github` → vetrina pubblica.

## Licenza

Proprietario. Tutti i diritti riservati.
