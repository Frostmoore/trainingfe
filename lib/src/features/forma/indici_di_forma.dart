/// Quanto carico e quanta carica — FASE 2-sexies, 20/08/2026.
///
/// ══ 🚨 QUESTO FILE PRODUCE UN GIUDIZIO, NON UNA MISURA ═════════════════════
///
/// È la prima volta che il progetto lo fa. `MediaDiRiferimento` dice «il tuo HRV
/// oggi è sotto la tua media»: è un **fatto**. «Sei stanco» è un'**inferenza**, e
/// cambia la natura della cosa.
///
/// ⚠️ **Un numero fa più danni di una frase**, perché suona *misurato*. Chi legge
/// «34» non ha modo di sapere che dietro c'è una formula scritta da noi: una
/// frase si può sfumare, un numero no. 🚨 Per questo ogni schermata che mostra
/// questi valori deve portarsi dietro l'avvertenza, e per questo qui sotto c'è
/// scritto per esteso **cosa questi numeri non sono**.
///
/// ── ⛔ Cosa NON fanno, e non devono fare ──────────────────────────────────
///
/// 1. **Non diagnosticano.** Un valore basso non è una malattia, e la parola
///    «malattia» non compare da nessuna parte.
/// 2. **Non sostituiscono come uno si sente.** Se il numero dice «carico» e la
///    persona sta benissimo, ha ragione la persona.
/// 3. 🚨 **Non sono confrontabili fra persone diverse.** Sono costruiti sulle
///    medie *personali*: il 60 di uno e il 60 di un altro non sono la stessa
///    cosa. ⚠️ Un indice che due amici si confrontano diventa una gara su una
///    formula, ed è il modo più rapido per renderlo dannoso.
/// 4. **Non prevedono.** Niente «domani sarai stanco».
///
/// ── 📚 Da dove vengono le formule *(ricerca del 20/08)* ───────────────────
///
/// | | Metodo | Fonte |
/// |---|---|---|
/// | Stanchezza | **ACWR** — carico 7 giorni ÷ carico 28 giorni, in versione `EWMA` | scienza dello sport, pubblico |
/// | Carica | **z-score** contro la media personale, soglia ±0.5 | idem |
/// | Il cibo dentro la carica | 🚨 **nostro**, non c'è una formula pubblicata | — |
///
/// ⚠️ **Il carico non è misurato dal cuore.** Il `TRIMP` di Banister vuole la
/// frequenza cardiaca durante l'allenamento, che non abbiamo; il sostituto
/// accettato è `sRPE` (intensità × durata) e noi usiamo le **calorie attive**,
/// che sono la stessa famiglia di misura. 💡 Va detto nell'interfaccia.
library;

import 'dart:math' as math;

/// Le fasce dell'`ACWR`, come le usa la letteratura.
enum FasciaCarico {
  /// Sotto il proprio solito.
  scarico,

  /// 🟢 La zona in cui si sta bene.
  normale,

  /// In salita.
  inSalita,

  /// Molto sopra il proprio solito.
  alto;

  static FasciaCarico da(double acwr) => switch (acwr) {
    < 0.8 => FasciaCarico.scarico,
    < 1.3 => FasciaCarico.normale,
    < 1.5 => FasciaCarico.inSalita,
    _ => FasciaCarico.alto,
  };
}

/// Un indice, con **quanto vale davvero**.
///
/// 🚨 Il valore c'è **sempre** che si possa calcolare — decisione D-2s/A del
/// committente: *«certo che si calcola. Si stima, e sotto c'è scritto che è una
/// stima poco veritiera perché mancano x giorni di dati»*.
///
/// ⚠️ **Niente campo vuoto in attesa dei dati**: un numero che compare solo dopo
/// ventotto giorni è, per chi installa l'app, una funzione che **non esiste** — e
/// nessuno torna a controllare se nel frattempo è comparsa.
class Indice {
  const Indice({
    required this.valore,
    required this.giorniDiStoria,
    required this.giorniPerEsserePieno,
  });

  /// `null` **solo** quando il numero non può esistere, non quando è impreciso.
  ///
  /// 💡 Per la stanchezza succede in un caso solo: zero allenamenti nella
  /// finestra lunga, cioè **denominatore zero**. Non è «poco attendibile», è una
  /// divisione impossibile.
  final double? valore;

  final int giorniDiStoria;
  final int giorniPerEsserePieno;

  bool get esiste => valore != null;

  /// Quanti giorni mancano perché la stima sia piena. `0` quando ci siamo.
  ///
  /// 💡 Serve a scrivere «mancano 12 giorni» invece di «dati insufficienti»: la
  /// prima è un'attesa che finisce, la seconda sembra un guasto.
  int get giorniCheMancano =>
      math.max(0, giorniPerEsserePieno - giorniDiStoria);

  bool get eAttendibile => giorniCheMancano == 0;
}

/// Il calcolo, tutto qui dentro e tutto puro.
///
/// 💡 Nessun provider, nessun archivio, nessuna data di sistema: entrano liste di
/// numeri ed esce un indice. È l'unico modo di poterlo verificare davvero.
abstract final class IndiciDiForma {
  /// La finestra corta dell'`ACWR`: il carico **recente**.
  static const giorniAcuti = 7;

  /// La finestra lunga: il proprio **normale**.
  static const giorniCronici = 28;

  /// Quante notti servono perché una media personale esista.
  ///
  /// ⚠️ Sotto questa soglia il valore si calcola lo stesso (D-2s/A) ma la nota
  /// dice quanto manca.
  static const nottiPerLaProntezza = 7;

  /// ⚠️ Soglia della letteratura per lo z-score: fra `−0.5` e `+0.5` si è nella
  /// norma personale.
  static const zNormale = 0.5;

  /// La media pesata esponenziale.
  ///
  /// ── 🚨 Perché `EWMA` e non la media semplice ──────────────────────────────
  ///
  /// Perché pesa di più i giorni vicini, che è **come funziona la fatica**:
  /// l'allenamento di ieri conta più di quello di tre settimane fa. ⚠️ La media
  /// mobile semplice li tratta uguali, e in letteratura risulta meno sensibile.
  ///
  /// 💡 `alfa = 2 / (n + 1)` è la forma standard.
  ///
  /// [giorni] va dal **più vecchio al più recente**: l'ordine conta, e invertirlo
  /// darebbe un numero plausibile e sbagliato.
  static double ewma(List<double> giorni, int finestra) {
    if (giorni.isEmpty) return 0;

    final alfa = 2 / (finestra + 1);
    var media = giorni.first;

    for (var i = 1; i < giorni.length; i++) {
      media = alfa * giorni[i] + (1 - alfa) * media;
    }

    return media;
  }

  /// **La stanchezza**: quanto ti sei caricato rispetto al tuo normale.
  ///
  /// `ACWR` = carico acuto (7 giorni) ÷ carico cronico (28 giorni), entrambi in
  /// `EWMA`.
  ///
  /// [kcalPerGiorno] sono le calorie **attive** bruciate allenandosi, un valore
  /// per giorno, dal **più vecchio al più recente**, zeri compresi.
  ///
  /// 🚨 Gli zeri **ci vogliono**: un giorno di riposo è un carico di zero, non un
  /// giorno che non esiste. ⚠️ Saltarlo farebbe sembrare che ci si alleni tutti i
  /// giorni, e l'`ACWR` non scenderebbe mai.
  ///
  /// ══ ⚠️ L'unico caso in cui torna `null` ══
  ///
  /// Carico cronico **zero**: nessun allenamento in ventotto giorni. Lì il
  /// risultato non è impreciso — **non esiste**, perché è una divisione per zero.
  static Indice stanchezza(List<double> kcalPerGiorno) {
    final storia = kcalPerGiorno.length;

    final cronico = ewma(_ultimi(kcalPerGiorno, giorniCronici), giorniCronici);

    if (cronico <= 0) {
      return Indice(
        valore: null,
        giorniDiStoria: storia,
        giorniPerEsserePieno: giorniCronici,
      );
    }

    final acuto = ewma(_ultimi(kcalPerGiorno, giorniAcuti), giorniAcuti);

    return Indice(
      valore: acuto / cronico,
      giorniDiStoria: storia,
      giorniPerEsserePieno: giorniCronici,
    );
  }

  /// **La prontezza**: come stai oggi rispetto al tuo normale.
  ///
  /// ══ 🚨 SI CHIAMAVA «CARICA», E NON LO ERA — 3b-K, 28/08/2026 ═══════════
  ///
  /// 📌 Il committente: *«a ben vedere non analizza la carica vera e propria, ma
  /// quanto sto bene o male rispetto al solito, che è 50»*.
  ///
  /// ⛔ Ed è giusto: questo numero è uno **z-score contro le proprie medie**
  /// portato su una scala 0–100 con il **50 al centro**. Non dice quanta
  /// capacità resta — dice se oggi si sta sopra o sotto il proprio normale.
  ///
  /// 💡 La Carica vera, quella che si scarica e si ricarica, vive in
  /// [CaricaBatteria] ed è **uno stato persistente**: quella di oggi dipende da
  /// quella di ieri. 🚨 Due cose diverse che si chiamavano uguale sono il modo
  /// più rapido per confonderle nel codice prima ancora che a schermo.
  ///
  /// Ogni ingrediente entra come **z-score** contro la propria media, poi si
  /// fa la media pesata e si porta su una scala `0–100`.
  ///
  /// ── 🚨 Il battito a riposo va INVERTITO ───────────────────────────────────
  ///
  /// Per HRV e sonno «più alto = meglio». Per il battito a riposo è il contrario:
  /// un battito sopra la propria media è un **segnale di stanchezza**. ⚠️ È
  /// l'errore di segno più facile da fare qui dentro, e darebbe un indice che
  /// sale proprio quando dovrebbe scendere.
  ///
  /// ── ⚠️ La scala 0–100 è NOSTRA ────────────────────────────────────────────
  ///
  /// Gli z-score sono la parte con una letteratura dietro; **la mappatura su
  /// cento no**. `z = 0` → `50`, `z = ±2` → `0` e `100`. 💡 L'ordine è onesto —
  /// più alto vuol dire davvero meglio — ma i numeri in mezzo sono una scelta di
  /// presentazione, e va detto.
  ///
  /// [cibo] è facoltativo e pesa poco: vedi [pesoDelCibo].
  static Indice prontezza({
    required double? zHrv,
    required double? zBattito,
    required double? zSonno,
    double? zCibo,
    required int nottiDiStoria,
  }) {
    final pezzi = <(double, double)>[
      if (zHrv != null) (zHrv, pesoDellHrv),

      // 🚨 Invertito: sopra la media personale = peggio.
      if (zBattito != null) (-zBattito, pesoDelBattito),

      if (zSonno != null) (zSonno, pesoDelSonno),
      if (zCibo != null) (math.min(0, zCibo), pesoDelCibo),
    ];

    if (pezzi.isEmpty) {
      return Indice(
        valore: null,
        giorniDiStoria: nottiDiStoria,
        giorniPerEsserePieno: nottiPerLaProntezza,
      );
    }

    var somma = 0.0;
    var pesi = 0.0;

    for (final (z, peso) in pezzi) {
      somma += z * peso;
      pesi += peso;
    }

    final z = somma / pesi;

    return Indice(
      valore: (zAlCentro + z * zQuantoPesa).clamp(0, 100).toDouble(),
      giorniDiStoria: nottiDiStoria,
      giorniPerEsserePieno: nottiPerLaProntezza,
    );
  }

  /// ══ 🚨 Questa parte è NOSTRA, e non viene da nessuno studio ══
  ///
  /// Il committente ha chiesto che il cibo entri. ⚠️ Non esiste una formula
  /// pubblicata che leghi deficit calorico e recupero in un indice: quello che
  /// c'è qui è una scelta ragionevole e **non validata**.
  ///
  /// 💡 Per questo pesa poco (`0.5` contro `1.0` dell'HRV) ed entra **solo in
  /// negativo** — `math.min(0, zCibo)` sopra: mangiare tanto **non** alza la
  /// carica, mangiare troppo poco la abbassa. 🚨 Il verso asimmetrico è
  /// deliberato: del primo effetto non sappiamo niente, del secondo un po' sì.
  static const pesoDelCibo = 0.5;

  static const pesoDellHrv = 1.0;
  static const pesoDelBattito = 1.0;

  /// 💡 Il sonno pesa **più** degli altri: è l'ingrediente con la letteratura
  /// più solida dietro, ed è quello che una persona riconosce da sola.
  static const pesoDelSonno = 1.5;

  /// ⚠️ Dove finisce uno `z` sulla scala 0–100 — la mappatura **nostra**.
  ///
  /// 💡 Sta qui e non sparso nel codice perché la schermata di dettaglio la deve
  /// **scrivere per esteso**, e due copie della stessa costante diventerebbero
  /// prima o poi due numeri diversi.
  static const zAlCentro = 50.0;
  static const zQuantoPesa = 25.0;

  /// 🚨 Lo z-score, in un posto solo.
  ///
  /// ⚠️ Con deviazione standard **zero** — tutti i giorni identici — la divisione
  /// non si può fare, e la risposta giusta è `null`: non «zero», che vorrebbe
  /// dire «perfettamente nella media» e sarebbe una conclusione, non un dato
  /// mancante.
  static double? z({
    required double valore,
    required double media,
    required double deviazione,
  }) {
    if (deviazione <= 0) return null;

    return (valore - media) / deviazione;
  }

  /// Media e deviazione standard di una serie. `null` sotto i due valori.
  static (double media, double deviazione)? mediaEDeviazione(List<double> v) {
    if (v.length < 2) return null;

    final media = v.reduce((a, b) => a + b) / v.length;

    var somma = 0.0;
    for (final x in v) {
      somma += (x - media) * (x - media);
    }

    return (media, math.sqrt(somma / v.length));
  }

  static List<double> _ultimi(List<double> v, int quanti) =>
      v.length <= quanti ? v : v.sublist(v.length - quanti);
}
