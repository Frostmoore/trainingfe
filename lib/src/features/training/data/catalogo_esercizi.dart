/// Il catalogo degli esercizi, con i muscoli — 3b-A.3.4, 23/08/2026.
///
/// ══ 🚨 PERCHÉ L'APP HA BISOGNO DEL CATALOGO ════════════════════════════════
///
/// Da FASE 11 gli allenamenti stanno **sul telefono**: il server sa che esiste
/// «Panca piana», non che io l'ho fatta. ⛔ Ma la figura del corpo (A.6.1) e il
/// grafico a stella (A.6.2) devono colorare i muscoli di **quello che ho
/// fatto** — e negli allenamenti salvati in locale c'è il nome dell'esercizio,
/// non i suoi muscoli.
///
/// 💡 Quindi il catalogo scende una volta e resta: è dato **pubblico e
/// condiviso**, uguale per tutti, e non ha niente di personale dentro.
///
/// ── ⚠️ La copia locale, e perché non è nel backup ─────────────────────────
///
/// 🚨 La regola di questo progetto è che ogni dato nuovo finisce nel backup.
/// Questa copia **no**, ed è l'unica eccezione motivata: non è un dato della
/// persona, è uno **specchio** di una tabella del server che si riscarica in
/// una chiamata. Rimetterla in un backup vorrebbe dire salvare il catalogo di
/// ieri e ripristinarlo sopra quello di oggi.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../health/health_controller.dart';
import '../training_controller.dart' show revisioneSchedeProvider;
import 'gruppo_muscolare.dart';

/// Quanto conta una serie per il muscolo che fa il lavoro.
///
/// 💡 È il riferimento, e vale **1** per definizione: gli altri pesi si leggono
/// rispetto a questo.
const pesoDelPrimario = 1.0;

/// Quanto conta una serie per un muscolo **secondario** — 3b-S, 28/08/2026.
///
/// ══ 📚 NON È UN NUMERO SCELTO DA NOI ══════════════════════════════════════
///
/// È il *fractional set counting*, la convenzione standard nella letteratura
/// sull'ipertrofia: una serie in cui il muscolo è motore principale conta
/// **1**, una in cui è secondario conta **0,5**. Tre serie di rematore più tre
/// di curl fanno **4,5** serie per i bicipiti.
///
/// 🚨 **E ha una fonte vera**: una meta-analisi su 67 studi ha confrontato i
/// tre modi di contare — tutto uguale, solo diretto, frazionario — e il
/// frazionario è quello che spiega meglio i risultati, con evidenza da forte a
/// molto forte su ogni misura.
///
/// ── ⚠️ Il limite, dichiarato ──────────────────────────────────────────────
///
/// Questo 0,5 nasce per contare le **serie** nei volumi settimanali, non per
/// dire «quanto ho usato questo muscolo». La contribuzione vera cambia molto da
/// esercizio a esercizio: il capo lungo del tricipite prende circa il **2%**
/// nella panca e il **18%** in uno skullcrusher.
///
/// ⛔ Il modello giusto sarebbe una tabella di contribuzione **per esercizio**.
/// Non ne esiste una pubblica per 314 esercizi, e riempirla a mano vorrebbe
/// dire 314 righe di numeri inventati — che è peggio di un'approssimazione
/// dichiarata.
///
/// 💡 **Sta qui, in un posto solo, apposta**: 📌 *«se è un coefficiente va
/// bene»*. Cambiarlo è una riga.
const pesoDelSecondario = 0.5;

/// Da dove viene un esercizio — 3b-N, 28/08/2026.
///
/// ══ ⚠️ TRE CASI, NON DUE ══════════════════════════════════════════════════
///
/// ⛔ `is_global` diceva «della piattaforma o no», e da 3b-M quel «no»
/// comprende due cose molto diverse: quelli che ho scritto **io** e quelli che
/// vedo perché me li passa qualcuno.
///
/// 💡 «Condivisa» e non «del trainer»: può arrivare anche da una palestra da
/// cui si è usciti, e chiamarla «del trainer» sarebbe una bugia in un caso su
/// due.
enum OrigineEsercizio {
  piattaforma(
    'Della piattaforma',
    'Fa parte della libreria di base: ce l\'hanno tutti.',
  ),
  mia('I miei', 'L\'hai aggiunto tu. Lo vedi solo tu e chi alleni.'),
  condivisa(
    'Condivisi con me',
    'Arriva da chi ti allena, o da una palestra in cui sei stato. '
        'Resta tuo da leggere anche se quel rapporto finisce.',
  );

  const OrigineEsercizio(this.titolo, this.spiegazione);

  /// Il titolo del gruppo nell'elenco.
  final String titolo;

  /// La riga sotto il nome, nel dettaglio.
  ///
  /// 💡 Serve a rispondere alla domanda che questa pagina fa nascere: «e questo
  /// da dove salta fuori?». ⛔ Un'etichetta sola — «condiviso» — la lascerebbe
  /// aperta, e una libreria di cui non si capisce la provenienza è una libreria
  /// di cui non ci si fida.
  final String spiegazione;

  /// ⚠️ Un valore che non conosciamo ricade su **piattaforma**, che è il caso
  /// innocuo: la pagina lo mostra fra quelli di tutti invece di dire «è tuo» a
  /// qualcosa che non lo è.
  static OrigineEsercizio da(Object? valore) => switch (valore?.toString()) {
    'mia' => OrigineEsercizio.mia,
    'condivisa' => OrigineEsercizio.condivisa,
    _ => OrigineEsercizio.piattaforma,
  };
}

/// Un esercizio come lo conosce il server.
@immutable
class EsercizioDelCatalogo {
  const EsercizioDelCatalogo({
    required this.id,
    required this.nome,
    required this.primario,
    required this.secondari,
    this.met,
    this.immagine,
    this.credito,
    this.origine = OrigineEsercizio.piattaforma,
  });

  factory EsercizioDelCatalogo.fromJson(Map<String, dynamic> j) =>
      EsercizioDelCatalogo(
        id: (j['id'] as num).toInt(),
        nome: j['name']?.toString() ?? '',
        primario: GruppoMuscolare.da(j['muscle_group']),
        secondari: ((j['secondary_muscles'] as List?) ?? const [])
            .map(GruppoMuscolare.da)
            .nonNulls
            .toList(growable: false),
        met: (j['met'] as num?)?.toDouble(),
        immagine: j['image_url']?.toString(),
        credito: j['image_credit']?.toString(),
        origine: OrigineEsercizio.da(j['origine']),
      );

  final int id;
  final String nome;
  final GruppoMuscolare? primario;
  final List<GruppoMuscolare> secondari;
  final double? met;
  final String? immagine;

  /// Da dove viene questo esercizio — 3b-N.
  ///
  /// 💡 Lo decide il **server**, che è l'unico a sapere di che tenant è la
  /// riga: l'app non ha il `tenant_id` e non deve averlo.
  final OrigineEsercizio origine;

  /// Chi ha fatto il disegno, quando l'attribuzione è dovuta — 3b-L.
  ///
  /// ══ ⚖️ DUE COSE DIPENDONO DA QUESTO CAMPO ═════════════════════════════
  ///
  /// 1. **La riga di credito** sotto l'esercizio, nella pagina della scheda:
  ///    le illustrazioni del catalogo sono CC BY-SA 4.0 e l'attribuzione è una
  ///    condizione della licenza, non una cortesia.
  /// 2. 🚨 **La tinta.** Il disegno è bianco su trasparente: su una card
  ///    chiara sarebbe invisibile, e va colorato a schermo.
  ///
  /// 💡 Non sono due significati diversi: è **una** informazione — «questa è
  /// una nostra illustrazione al tratto» — da cui seguono tutte e due.
  ///
  /// ⛔ `null` quando la foto l'ha caricata la palestra. Allora niente credito
  /// (sarebbe falso: non l'ha fatta Bryl Lim) e niente tinta (è una
  /// fotografia, e tingerla la distruggerebbe).
  final String? credito;

  /// Tutti i muscoli con quanto pesano — vedi [pesoDelSecondario].
  ///
  /// 🚨 **Stessa proporzione di `Exercise::muscoliConPeso()` sul server**, e sta
  /// scritta in tutti e due i posti perché tutti e due la usano — il server per
  /// il pannello, l'app per colorare la figura. ⚠️ Se un giorno i pesi
  /// diventano veri, vanno cambiati insieme.
  ///
  /// ⛔ `cardio` e `full_body` non entrano: non sono zone del corpo.
  Map<GruppoMuscolare, double> get muscoliConPeso {
    final pesi = <GruppoMuscolare, double>{};

    if (primario != null && primario!.eUnMuscolo) {
      pesi[primario!] = pesoDelPrimario;
    }

    for (final m in secondari) {
      if (!m.eUnMuscolo) continue;

      // ⚠️ Il massimo e non la somma: un muscolo che comparisse in tutti e due
      // i posti conta come primario, non uno e mezzo.
      pesi[m] = (pesi[m] ?? 0) > pesoDelSecondario
          ? pesi[m]!
          : pesoDelSecondario;
    }

    return pesi;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': nome,
    'muscle_group': primario?.valore,
    'secondary_muscles': secondari.map((m) => m.valore).toList(),
    'met': met,
    'image_url': immagine,
    'image_credit': credito,

    // ⚠️ **I nomi dell'enum sono quelli che manda il server**, apposta: così
    // la copia locale si rilegge con lo stesso `da()` della rete, e non c'è
    // una seconda traduzione che può divergere.
    'origine': origine.name,
  };
}

/// Il catalogo intero, con le due ricerche che servono davvero.
@immutable
class CatalogoEsercizi {
  CatalogoEsercizi(this.tutti)
    : _perId = {for (final e in tutti) e.id: e},
      _perNome = {for (final e in tutti) normalizza(e.nome): e};

  final List<EsercizioDelCatalogo> tutti;
  final Map<int, EsercizioDelCatalogo> _perId;
  final Map<String, EsercizioDelCatalogo> _perNome;

  static const CatalogoEsercizi vuoto = CatalogoEsercizi._vuoto();

  const CatalogoEsercizi._vuoto()
    : tutti = const [],
      _perId = const {},
      _perNome = const {};

  EsercizioDelCatalogo? perId(int? id) => id == null ? null : _perId[id];

  /// L'esercizio che corrisponde a un nome scritto a mano, se c'è.
  ///
  /// ⚠️ **È un indizio, non la riconciliazione.** Quella vera la fa
  /// `ExerciseMatcher` sul server, che conosce anche i sinonimi e le
  /// corrispondenze parziali. 🚨 Qui serve solo a non chiedere i muscoli di una
  /// panca piana a chi ha appena scritto «Panca piana»: se sbaglia, sbaglia
  /// chiedendo una cosa in più, non scrivendo un dato falso.
  EsercizioDelCatalogo? perNome(String nome) => _perNome[normalizza(nome)];

  /// La stessa forma di `Exercise::normalize()` sul server.
  ///
  /// 💡 Non c'è `ascii()`: in italiano gli accenti negli esercizi non
  /// compaiono, e una traslitterazione fatta a metà sarebbe peggio di nessuna —
  /// darebbe corrispondenze che il server non conferma.
  static String normalizza(String nome) => nome
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// ⚠️ **La chiave è cambiata con 3b-L**, e non per capriccio: la copia vecchia
/// non ha `image_credit`, e senza quel campo l'app non tinge il disegno — che
/// essendo bianco su trasparente resterebbe **invisibile** su fondo chiaro.
/// 💡 Meglio nessuna copia che una copia che disegna il vuoto.
const _chiaveCache = 'catalogo.esercizi.2';

/// Quanti esercizi si chiedono in una volta.
///
/// 🚨 **Sopra il catalogo intero**, che con 3b-L è di 314 esercizi della
/// piattaforma più quelli della palestra. ⛔ Chiederne meno non darebbe «una
/// pagina»: darebbe un catalogo con dei buchi, e i buchi qui diventano
/// esercizi senza figura e senza muscoli.
const _quantiNeChiediamo = 1000;

/// Il catalogo, dalla rete se si può e dalla copia locale se non si può.
///
/// 🚨 **Non è `autoDispose`**: lo leggeranno la figura del corpo, il grafico a
/// stella e il compositore, e ricaricarlo a ogni cambio di schermata sarebbe
/// una chiamata di rete per niente.
///
/// ⛔ Un errore di rete **non** diventa un errore del provider quando c'è una
/// copia: in palestra il telefono spesso non prende, e una figura del corpo
/// vuota per quello sarebbe un guasto inventato da noi.
final catalogoEserciziProvider = FutureProvider<CatalogoEsercizi>((ref) async {
  final cache = ref.watch(localCacheProvider);

  Future<CatalogoEsercizi?> dallaCopia() async {
    final salvato = cache.getString(_chiaveCache);

    if (salvato == null) return null;

    try {
      final righe = (jsonDecode(salvato) as List)
          .map((e) => EsercizioDelCatalogo.fromJson((e as Map).cast()))
          .toList(growable: false);

      return CatalogoEsercizi(righe);
    } on Object catch (e) {
      debugPrint('catalogo: la copia locale non si legge — $e');

      return null;
    }
  }

  try {
    /*
     * ══ 🚨 `unwrap: false`, E NON SI PUÒ FARE ALTRIMENTI — 3b-O ═══════════
     *
     * La risposta porta **due** cose: `data` (il catalogo) e
     * `riconciliazioni` (gli esercizi fusi in altri). ⛔ Con lo srotolamento
     * automatico arriverebbe solo la prima, e i rinvii sparirebbero senza un
     * errore — cioè lo storico resterebbe attaccato a id che non esistono più
     * nell'elenco.
     *
     * ⚠️ E non si rende «più intelligente» `_unwrap`: il suo docblock spiega
     * per esteso perché una regola implicita che indovina è costata un
     * pomeriggio di login rotto. Chi non vuole l'inviluppo lo dice.
     */
    final risposta = await ref
        .watch(apiClientProvider)
        .get<Map<String, dynamic>>(
          '/exercises',
          query: {'limit': '$_quantiNeChiediamo'},
          unwrap: false,
        );

    final dati = (risposta['data'] as List?) ?? const [];

    /*
     * 🔁 **I rinvii si applicano prima di costruire il catalogo.** Chi legge
     * subito dopo — la progressione per esercizio, i primati — deve trovare
     * lo storico già spostato, o mostrerebbe una scheda «mai fatta» per un
     * istante e poi cambierebbe idea da sola.
     */
    final rinvii = <int, int>{
      for (final r in (risposta['riconciliazioni'] as List?) ?? const [])
        if (r is Map && r['da'] is int && r['a'] is int)
          r['da'] as int: r['a'] as int,
    };

    final righe = dati
        .map((e) => EsercizioDelCatalogo.fromJson((e as Map).cast()))
        .toList(growable: false);

    if (rinvii.isNotEmpty) {
      /*
       * 🚨 **Servono anche i nomi.** Il rinvio dice solo «questo id diventa
       * quello»: senza il nome, la scheda sul telefono terrebbe l'etichetta
       * vecchia sopra il disegno nuovo — e il nome scritto nella scheda vince
       * su quello del catalogo (3b-D.17).
       */
      final toccate = await ref
          .read(archivioSaluteProvider)
          .applicaLeRiconciliazioni(
            rinvii,
            nomi: {for (final e in righe) e.id: e.nome},
          );

      /*
       * 💡 **Le schede si ridisegnano solo se qualcosa è cambiato davvero.**
       * `schedeUniteProvider` legge il telefono e non si accorge da solo che
       * l'abbiamo riscritto sotto: senza questo, la fusione si vedrebbe al
       * riavvio dopo — cioè sembrerebbe non aver funzionato.
       */
      if (toccate > 0) {
        ref.read(revisioneSchedeProvider.notifier).state++;
      }
    }

    /*
     * ⚠️ **Un troncamento non deve poter passare in silenzio.** Se ne
     * arrivano esattamente quanti ne abbiamo chiesti, quasi certamente ce ne
     * sono altri che non abbiamo. 🚨 È il difetto che questa riga esiste per
     * far vedere: un catalogo incompleto non dà nessun errore, dà solo
     * esercizi senza figura e senza muscoli — e sembra un'importazione
     * fallita, non una pagina mancante.
     */
    if (dati.length >= _quantiNeChiediamo) {
      debugPrint(
        'catalogo: arrivati ${dati.length} esercizi, cioè il massimo '
        'richiedibile — molto probabilmente ne mancano. Serve la paginazione.',
      );
    }

    await cache.setString(
      _chiaveCache,
      jsonEncode(righe.map((e) => e.toJson()).toList()),
    );

    return CatalogoEsercizi(righe);
  } on Object catch (e) {
    debugPrint('catalogo: dalla rete non arriva — $e');

    return await dallaCopia() ?? CatalogoEsercizi.vuoto;
  }
});
