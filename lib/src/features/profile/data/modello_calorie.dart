/// I due modi di stimare il fabbisogno, e i loro livelli — 3b-G.1, 26/08/2026.
///
/// ══ 📌 LA DECISIONE ═══════════════════════════════════════════════════════
///
/// Il committente: *«noi non dobbiamo decidere se usare il PAL occupazionale o i
/// moltiplicatori normali. Lo chiediamo all'utente quando registra i suoi
/// dati»*.
///
/// ══ ⛔ COSA C'ERA PRIMA, E PERCHE' ERA ROTTO ══════════════════════════════
///
/// Il livello di attività **dichiarava gli allenamenti** («3-4 a settimana») e
/// l'app **ci sommava sopra** gli allenamenti misurati dall'orologio. 🚨 Chi non
/// aveva scelto «sedentario» se li vedeva contati **due volte**, e il difetto
/// non poteva saltare fuori da nessuna parte: l'obiettivo restava un numero
/// plausibile.
///
/// ⚠️ **Il difetto non era la formula: era la domanda.** «Quanto ti alleni» sta
/// nelle formule su carta perché quando sono state scritte non c'era un
/// orologio che lo misurasse.
///
/// ══ 💡 LA CHIAVE PORTA IL MODELLO ═════════════════════════════════════════
///
/// Le chiavi dei due modelli **non si sovrappongono** (`sedentary…very_active`
/// contro `desk…labour`), ed è una scelta, non una coincidenza: così il modello
/// si **deduce** dal livello salvato e non serve un secondo campo da tenere
/// allineato. ⛔ Tenere le stesse chiavi cambiandogli sotto il significato
/// avrebbe voluto dire che un profilo salvato ieri cambia senso senza che niente
/// lo dica — che è il modo più rapido per rendere un difetto invisibile.
library;

import 'calcolatore_calorie.dart';

/// Un gradino di attività, con tutto quello che serve per **spiegarlo**.
///
/// 🚨 `dettaglio` non è decorazione: un'etichetta come «Moderatamente attivo»
/// non dice a nessuno se lui ci rientra. La descrizione del mestiere e i passi
/// tipici sono ciò che rende la scelta possibile invece che casuale.
class LivelloAttivita {
  const LivelloAttivita({
    required this.chiave,
    required this.etichetta,
    required this.dettaglio,
    this.passiFinoA,
  });

  /// Il valore salvato: `desk`, `moderate`, …
  final String chiave;

  final String etichetta;

  /// La riga sotto l'etichetta, quella che fa capire se sei tu.
  final String dettaglio;

  /// Il tetto di passi al giorno di questo gradino — solo per il modello
  /// misurato, e solo per **suggerire**.
  ///
  /// ⚠️ `null` sull'ultimo gradino (non ha tetto) e su tutto il modello a stima,
  /// dove i gradini parlano di allenamenti e non di passi.
  final int? passiFinoA;

  /// Il moltiplicatore, preso dal calcolatore.
  ///
  /// 🚨 **Non è scritto qui.** Averlo in due posti vuol dire che prima o poi ne
  /// cambia uno solo, e da quel momento la pagina che spiega il calcolo e il
  /// calcolo dicono due numeri diversi.
  double get fattore => CalcolatoreCalorie.fattoreDi(chiave)!;
}

/// Come l'app stima il fabbisogno di una persona.
enum ModelloCalorie {
  /// Il fattore contiene già gli allenamenti: l'orologio non si somma.
  stima(
    titolo: 'Stimalo tu dal mio stile di vita',
    promessa:
        'Lascio che l\'app stimi le mie calorie con i fattori di '
        'Harris-Benedict, e registro solo gli allenamenti fuori dal solito.',
    formula: 'fabbisogno = metabolismo basale × fattore',
    comeFunziona:
        'Il fattore che scegli comprende già lo sport che fai di solito, '
        'perché i gradini sono descritti ad allenamenti a settimana. Per '
        'questo gli allenamenti registrati non alzano l\'obiettivo: '
        'sarebbero contati due volte.',
    precisione:
        'Media sulla settimana: i giorni di palestra e quelli di '
        'riposo hanno lo stesso obiettivo.',
    livelli: [
      LivelloAttivita(
        chiave: 'sedentary',
        etichetta: 'Sedentario',
        dettaglio: 'Lavoro da fermo, nessun allenamento',
      ),
      LivelloAttivita(
        chiave: 'light',
        etichetta: 'Leggermente attivo',
        dettaglio: '1-2 allenamenti a settimana',
      ),
      LivelloAttivita(
        chiave: 'moderate',
        etichetta: 'Moderatamente attivo',
        dettaglio: '3-4 allenamenti a settimana',
      ),
      LivelloAttivita(
        chiave: 'active',
        etichetta: 'Molto attivo',
        dettaglio: '5-6 allenamenti a settimana',
      ),
      LivelloAttivita(
        chiave: 'very_active',
        etichetta: 'Estremamente attivo',
        dettaglio: 'Ogni giorno, o due sedute al giorno',
      ),
    ],
  ),

  /// Il fattore descrive solo la vita fuori dalla palestra: lo sport si misura.
  misurata(
    titolo: 'Registro ogni allenamento',
    promessa:
        'Registro ogni mio allenamento, e l\'app somma quello che brucio '
        'davvero al fabbisogno della giornata.',
    formula:
        'fabbisogno = metabolismo basale × fattore + allenamenti del giorno',
    comeFunziona:
        'Il fattore che scegli descrive solo quanto ti muovi nella vita di '
        'tutti i giorni, senza contare palestra e corsa: quelle le misura '
        'l\'orologio e si sommano al giorno in cui le hai fatte.',
    precisione:
        'Giorno per giorno: quando ti alleni puoi mangiare di più, e solo '
        'quel giorno.',
    livelli: [
      LivelloAttivita(
        chiave: 'desk',
        etichetta: 'Scrivania',
        dettaglio: 'Fermo quasi tutto il giorno, e poco movimento anche fuori',
        passiFinoA: 4000,
      ),
      LivelloAttivita(
        chiave: 'standing',
        etichetta: 'Un po\' in piedi',
        dettaglio: 'Scrivania ma attivo fuori, oppure mezza giornata in piedi',
        passiFinoA: 8000,
      ),
      LivelloAttivita(
        chiave: 'on_feet',
        etichetta: 'Sempre in movimento',
        dettaglio: 'In piedi quasi tutta la giornata: cameriere, magazzino',
        passiFinoA: 13000,
      ),
      LivelloAttivita(
        chiave: 'labour',
        etichetta: 'Lavoro fisico pesante',
        dettaglio: 'Edilizia, agricoltura, carichi per tutto il turno',
      ),
    ],
  );

  const ModelloCalorie({
    required this.titolo,
    required this.promessa,
    required this.formula,
    required this.comeFunziona,
    required this.precisione,
    required this.livelli,
  });

  /// Il titolo della scelta.
  final String titolo;

  /// La frase in prima persona: è quella che la persona sta accettando.
  ///
  /// 💡 In prima persona di proposito. *«L'app stima le calorie»* si legge come
  /// una descrizione; *«registro ogni mio allenamento»* si legge come un
  /// impegno — ed è un impegno: se poi non li registra, il modello mente.
  final String promessa;

  /// La formula, scritta per esteso.
  ///
  /// 📌 Chiesta esplicitamente: *«dovrà essere accuratamente dettagliato anche
  /// con la formula usata»*.
  final String formula;

  final String comeFunziona;
  final String precisione;

  /// I gradini di questo modello, dal più fermo al più attivo.
  final List<LivelloAttivita> livelli;

  /// Se in questo modello gli allenamenti si sommano all'obiettivo.
  ///
  /// 🚨 **È una conseguenza del modello, non una preferenza.** Fino al 26/08 era
  /// un interruttore libero nelle impostazioni, e si poteva stare su
  /// «moderato» (che dichiara 3-4 allenamenti) **e** avere la somma accesa: il
  /// doppio conteggio non era un difetto di calcolo, era due scelte che devono
  /// muoversi insieme lasciate indipendenti.
  bool get sommaGliAllenamenti => this == ModelloCalorie.misurata;

  /// Il livello con questa chiave, se appartiene a questo modello.
  LivelloAttivita? livello(String? chiave) {
    for (final l in livelli) {
      if (l.chiave == chiave) return l;
    }

    return null;
  }
}

/// A quale modello appartiene un livello — **`null` se non lo sappiamo**.
///
/// 🚨 `null` non è un caso da riempire: vuol dire «questa persona non ha ancora
/// scelto», ed è uno stato vero. Chi lo collassa su uno dei due modelli sta
/// scegliendo al posto suo — e su un obiettivo calorico.
ModelloCalorie? modelloDelLivello(String? chiave) {
  if (chiave == null) return null;

  for (final m in ModelloCalorie.values) {
    if (m.livello(chiave) != null) return m;
  }

  return null;
}

/// Il gradino che i passi misurati suggeriscono — 3b-G.1.4.
///
/// ══ 💡 PERCHE' ESISTE ═════════════════════════════════════════════════════
///
/// «Quanto ti muovi?» è la domanda peggiore di tutta la registrazione: nessuno
/// sa rispondere, e chi prova indovina. ⚠️ Ma il numero che risponde davvero
/// **l'app ce l'ha già** — legge i passi da Health Connect.
///
/// 🚨 Quindi non si chiede: si **misura e si fa confermare**. È la stessa
/// differenza che passa fra una domanda e una verifica.
///
/// ⛔ Solo il modello **misurato**: nell'altro i gradini parlano di allenamenti,
/// e i passi non dicono niente su quelli.
LivelloAttivita? livelloSuggeritoDaiPassi(int passiAlGiorno) {
  if (passiAlGiorno <= 0) return null;

  for (final l in ModelloCalorie.misurata.livelli) {
    final tetto = l.passiFinoA;

    if (tetto == null || passiAlGiorno < tetto) return l;
  }

  return ModelloCalorie.misurata.livelli.last;
}
