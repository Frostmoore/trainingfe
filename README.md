# Training Companion — App (`trainingfe`)

App **Flutter** per gli iscritti delle palestre clienti di **Training Companion**.

App **unica** sugli store, **white-label a runtime**: all'onboarding l'utente inserisce il
codice della propria palestra, l'app scarica il branding (logo, colori, nome) dal backend e
applica il tema dinamicamente. Una nuova palestra è attiva senza toccare gli store.

Cosa fa l'iscritto: esegue le schede assegnate dal trainer, segue il piano alimentare, usa il
diario cibo con AI (testo, foto, manuale), registra peso e foto progressi, vede la dashboard
e chatta col proprio trainer.

## 📘 Documentazione — fonte di verità nel backend

> **Il piano di sviluppo di questo progetto NON vive qui.**
>
> La specsheet operativa è **[`trainingbe/plan_training_companion.md`](https://github.com/Frostmoore/trainingbe/blob/main/plan_training_companion.md)**
> e copre backend **e** app. Le fasi che riguardano questo repo sono **F9** (fondamenta:
> scaffolding, tema a runtime, auth, client API) e **F10** (funzionalità: diario, player
> allenamento, piano alimentare, progressi, chat).
>
> Se questo file e il piano divergono, **vince il piano**.

## Stack

Flutter ≥ 3.44 · Dart ≥ 3.12 — target iOS e Android.
I pacchetti Dart vengono fissati in **F9.1**, dopo l'aggiornamento del toolchain.

## Backend

Le API sono servite da [`trainingbe`](https://github.com/Frostmoore/trainingbe) sotto `/api/v1`,
autenticate con token Sanctum (`Authorization: Bearer …`).

## Avvio in locale

```bash
flutter --version     # atteso >= 3.44
flutter pub get
flutter run
```

## Versionamento

I branch si chiamano come le versioni, da `v1.0.0`. `trainingbe` e `trainingfe` avanzano di
versione **in modo indipendente**. Due remote: `origin` → Gitea (rete privata, Tailscale)
· `github` → vetrina pubblica.

## Licenza

Proprietario. Tutti i diritti riservati.
