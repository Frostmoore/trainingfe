import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../features/health/dati_salute.dart';
import '../../features/health/sessioni_di_sonno.dart';

part 'archivio_salute.g.dart';

/// L'archivio dei dati del corpo, **sul telefono e solo lì** — S3.
///
/// 🚨 **Perché non `LocalCache`.** `LocalCache` è `SharedPreferences`:
/// chiave-valore, nessuna query per intervallo, nessun indice. Qui serve una
/// **serie temporale** su cui si calcola una media a sette giorni e si legge una
/// notte intera: con le preferenze bisognerebbe caricare tutto in memoria e
/// filtrare in Dart a ogni apertura della dashboard.
///
/// 🚨 **Perché esiste**: la decisione **D9** di `todo-2026-08-11.md` — sonno,
/// HRV, battito, e da S5 anche peso, misure e foto **non stanno sul server**.
/// Il backend non li riceve, non li conserva e non li manda a nessun modello.
/// Questo file è la loro unica casa.
///
/// ⚠️ **Non è un'ottimizzazione, è una necessità**: Health Connect di serie
/// lascia rileggere solo ~30 giorni indietro. La media di riferimento su una
/// finestra più lunga esiste **solo** se l'app accumula dal momento
/// dell'installazione.
@DriftDatabase(
  tables: [
    LettureSalute,
    CampioniSonno,
    MisureCorpo,
    FotoProgressi,
    SchedeRicevute,
    PianiRicevuti,
    ContenutiRifiutati,
    AllenamentiDaOrologio,
    SeduteAllenamento,
    SerieDelleSedute,
    BruciateDichiarate,
  ],
)
class ArchivioSalute extends _$ArchivioSalute {
  ArchivioSalute() : super(_apri());

  /// Per i test: un archivio in memoria, che non tocca il disco.
  ArchivioSalute.inMemoria() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 12;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, da, a) async {
      // v1 → v2 (S5.2): peso e misure escono dal server e arrivano qui.
      if (da < 2) await m.createTable(misureCorpo);

      // v2 → v3 (S5.3): e le foto dei progressi con loro.
      if (da < 3) await m.createTable(fotoProgressi);

      // v3 → v4 (S7.4): le schede ricevute dal trainer via chat.
      if (da < 4) await m.createTable(schedeRicevute);

      // v4 → v5 (12/08/2026): `notteDi()` ha cambiato regola.
      if (da < 5) await _riaccreditaLeNotti();

      /*
           * v5 → v6 (G8): i piani alimentari ricevuti, i rifiutati, e
           * l'identita' stabile sulle schede.
           *
           * 🚨 **Il bump di `schemaVersion` non e' facoltativo.** Senza, il
           * guasto si manifesta come un errore SQL **sul telefono di chi
           * aggiorna** — mai su quello di chi installa da zero, cioe' mai sui
           * nostri.
           */
      if (da < 6) {
        await m.createTable(pianiRicevuti);
        await m.createTable(contenutiRifiutati);
        await m.addColumn(schedeRicevute, schedeRicevute.origineId);
        await m.addColumn(schedeRicevute, schedeRicevute.aggiornatoIl);
      }

      /*
           * v6 -> v7 (18/08/2026): notti e pennichelle si riconoscono davvero.
           *
           * La regola precedente decideva la giornata guardando l'ora d'inizio
           * del **singolo segmento di fase**: dopo le 18 apparteneva al giorno
           * dopo. Una pennichella cominciata alle 18:09 finiva quindi
           * accreditata all'indomani, e la giornata risultava sfasata.
           *
           * 🚨 **Va rifatto anche su chi era gia' alla v5 o alla v6.** Il
           * riaccredito qui sopra scatta solo `se da < 5`: senza questa riga,
           * chi ha gia' aggiornato una volta si terrebbe i dati sbagliati per
           * sempre — e il difetto sembrerebbe corretto solo a chi installa da
           * zero, cioe' a noi.
           */
      if (da < 7) await _riaccreditaLeNotti();

      /*
           * v7 -> v8 (N20): il piano importato da PDF, e il suo originale.
           *
           * 🚨 **Due colonne nullable e nessuna tabella nuova**, di
           * proposito: un piano importato e' un piano, e tenerlo altrove
           * vorrebbe dire due elenchi da mostrare, due backup da fare e due
           * posti dove cercarlo. Le colonne dicono *da dove viene*, non
           * *cos'e'*.
           *
           * ⚠️ `pdfOriginale` e' il percorso relativo dentro
           * `Documents/foto/piani`, che e' **nel backup**: l'originale deve
           * restare consultabile anche quando la riga sul server e' scaduta,
           * altrimenti fra un mese non c'e' piu' niente con cui confrontare i
           * numeri che si stanno seguendo.
           */
      if (da < 8) {
        await m.addColumn(pianiRicevuti, pianiRicevuti.pdfOriginale);
        await m.addColumn(pianiRicevuti, pianiRicevuti.importato);
      }

      /*
           * v8 -> v9 (FASE 1.8): gli allenamenti registrati dall'orologio.
           *
           * 🚨 **Una tabella nuova e non due colonne**, al contrario di v7->v8:
           * li' un piano importato *era* un piano, qui una seduta rilevata dal
           * polso **non e'** una seduta del player. Non ha serie, non ha
           * ripetizioni, non ha un carico — ha un tipo, una durata e delle
           * calorie. Metterle nella stessa tabella vorrebbe dire una tabella
           * per meta' vuota qualunque riga si guardi.
           *
           * 💡 E finisce nel backup **da sola**: `esportaPerBackup()` enumera
           * `allTables` invece di elencare a mano, proprio perche' una tabella
           * aggiunta dopo non resti fuori senza che nessuno se ne accorga.
           */
      if (da < 9) await m.createTable(allenamentiDaOrologio);

      /*
           * v9 -> v10 (FASE 1-bis): «questo allenamento non si unisce a
           * nessuno».
           *
           * 🚨 Serve perche' dal 20/08 basta **un istante** di sovrapposizione
           * perche' due registrazioni siano lo stesso allenamento. Una regola
           * cosi' larga prima o poi unisce due cose diverse, e senza questa
           * colonna l'errore non sarebbe riparabile: uno dei due allenamenti
           * sparirebbe dallo storico per sempre.
           */
      if (da < 10) {
        await m.addColumn(
          allenamentiDaOrologio,
          allenamentiDaOrologio.staccato,
        );
      }

      /*
       * ══ 🏋️ v10 → v11 (FASE 11): gli allenamenti tornano a casa ═══════════
       *
       * 📌 Il committente, 21/08/2026: *«Nessun allenamento deve risiedere sul
       * server, devono stare tutti nell'app»*.
       *
       * ⚠️ **Le tabelle si creano vuote, e nessuno ci scrive ancora**: chi
       * riempie è la migrazione dei dati (11.3), che gira **una volta sola** e
       * solo dopo aver verificato i conteggi. 🚨 Creare le tabelle e spostare
       * il player nello stesso passo vorrebbe dire perdere le sedute di chi
       * aggiorna prima che la migrazione abbia girato.
       *
       * 💡 Finiscono nel backup **da sole**: `esportaPerBackup()` enumera
       * `allTables`, non un elenco scritto a mano.
       */
      if (da < 11) {
        await m.createTable(seduteAllenamento);
        await m.createTable(serieDelleSedute);
        await m.createTable(bruciateDichiarate);
      }

      /*
       * ⚠️ v11 → v12 (FASE 11.3, poche ore dopo): da dove viene una bruciata.
       *
       * 🚨 Senza, `conteggiDelTrasloco()` contava **tutte** le righe locali. Oggi
       * torna lo stesso perché nessuno scrive in locale, ma dalla 11.4 in poi
       * una dichiarazione fatta prima del trasloco avrebbe fatto rispondere
       * `409` al server **per sempre**.
       */
      if (da < 12) {
        await m.addColumn(bruciateDichiarate, bruciateDichiarate.daServer);
      }
    },
  );

  /// Ricalcola `notte` su tutti i campioni già salvati — v4 → v5, e di nuovo
  /// v6 → v7.
  ///
  /// ── 🚨 Perché una migrazione, e non «si sistema alla prossima lettura» ──
  ///
  /// Il ponte scrive con `InsertMode.insertOrIgnore` su `(fonte, iniziatoIl)`:
  /// rileggendo la stessa finestra da Health Connect, le righe già presenti
  /// vengono **ignorate**, non aggiornate. Senza questa migrazione le notti
  /// vecchie resterebbero accreditate al giorno sbagliato **per sempre**, e
  /// l'archivio conterrebbe due convenzioni mescolate — che è peggio di una
  /// convenzione sbagliata, perché non si può nemmeno correggere a mente.
  ///
  /// ── 💡 Perché si ricalcola invece di sommare un giorno ─────────────────
  ///
  /// `notte = notte + 1` sarebbe giusto per il sonno notturno e **sbagliato per
  /// i riposini**, che con la regola nuova non si spostano. L'unica cosa che
  /// non mente è rifare il conto da `iniziatoIl`, che è il dato di partenza.
  ///
  /// ⚠️ Nessun dato si perde e niente si cancella: si riscrive una colonna
  /// derivata. `notte` non fa parte di nessun vincolo di unicità — quello è su
  /// `(fonte, iniziatoIl)` — quindi non ci sono collisioni possibili.
  Future<void> _riaccreditaLeNotti() async {
    final righe = await select(campioniSonno).get();

    if (righe.isEmpty) return;

    /*
     * \U0001F6A8 Si ricompongono le dormite **su tutto l'archivio insieme**, non
     * riga per riga.
     *
     * ⚠️ È il punto in cui la versione precedente sbagliava: chiamava
     * `notteDi(iniziatoIl)` su ogni segmento separatamente, e un segmento da
     * solo non sa se fa parte di una notte o di una pennichella. Una pennica
     * delle 18:09 finiva accreditata al giorno dopo.
     *
     * \U0001F4A1 Nessun dato si perde: si riscrive una colonna **derivata**, e
     * `notte` non fa parte di nessun vincolo di unicita' — quello e' su
     * `(fonte, iniziatoIl)`.
     */
    final giornate = SessioniDiSonno.giornatePerSegmento(
      righe.map((r) => (inizio: r.iniziatoIl, fine: r.finitoIl)),
    );

    await batch((b) {
      for (final riga in righe) {
        final giusta = giornate[riga.iniziatoIl];

        if (giusta == null || giusta == riga.notte) continue;

        b.update(
          campioniSonno,
          CampioniSonnoCompanion(notte: Value(giusta)),
          where: (t) => t.id.equals(riga.id),
        );
      }
    });
  }

  // ─────────────────────────── scrittura ───────────────────────────

  /// Scrive le letture, **senza duplicare**.
  ///
  /// 🚨 `InsertMode.insertOrIgnore` sull'indice `(fonte, metrica, misurataIl)`.
  /// Sul server la stessa regola era un `UNIQUE`, e serviva perché **il ponte
  /// rilegge sempre una finestra**, non solo il nuovo: senza, ogni
  /// sincronizzazione avrebbe raddoppiato i campioni già presenti.
  ///
  /// ⚠️ E i duplicati qui non sarebbero un fastidio estetico: la media di
  /// riferimento è una media, e contare tre volte lo stesso valore la sposta.
  Future<int> scriviLetture(List<LetturaSalute> letture) async {
    if (letture.isEmpty) return 0;

    // Le implausibili non arrivano nemmeno al database: vedi
    // `MetricaSalute.plausibile()` per il perché non si salvano «tanto poi si
    // filtrano».
    final buone = letture.where((l) {
      final m = MetricaSalute.daCodice(l.metrica);
      return m != null && m.plausibile(l.valore);
    }).toList();

    if (buone.isEmpty) return 0;

    await batch(
      (b) => b.insertAll(
        lettureSalute,
        buone.map(_companionLettura).toList(),
        mode: InsertMode.insertOrIgnore,
      ),
    );

    return buone.length;
  }

  /// Scrive i campioni del sonno, senza duplicare su `(fonte, iniziatoIl)`.
  Future<int> scriviCampioniSonno(List<CampioneSonno> campioni) async {
    if (campioni.isEmpty) return 0;

    await batch(
      (b) => b.insertAll(
        campioniSonno,
        campioni.map(_companionCampione).toList(),
        mode: InsertMode.insertOrIgnore,
      ),
    );

    return campioni.length;
  }

  /// Scrive gli allenamenti letti dall'orologio — FASE 1.8.
  ///
  /// ── 🚨 `insertOrIgnore`, e qui non è solo per non duplicare ───────────────
  ///
  /// Sulle letture e sul sonno serve a non riscrivere lo stesso campione. Qui
  /// difende **una scelta della persona**: `schedaAssegnata` e `nascosto` sono
  /// gli unici due campi che non arrivano dall'orologio, e si rileggono sempre
  /// gli ultimi sette giorni.
  ///
  /// ⚠️ Con `insertOrReplace` l'assegnazione fatta ieri sparirebbe al prossimo
  /// avvio dell'app, sostituita dal record originale. Il sintomo sarebbe «ogni
  /// tanto si dimentica la scheda che gli ho detto», che è la specie di difetto
  /// che nessuno riesce a riprodurre.
  ///
  /// ── 🚨 E però i dati del sensore si AGGIORNANO ────────────────────────────
  ///
  /// L'inserimento da solo non basta, e il 20/08 si è visto perché: gli
  /// allenamenti già salvati portavano le calorie **sbagliate** — quelle col
  /// metabolismo basale dentro — e nessuna risincronizzazione le avrebbe mai
  /// corrette, perché la riga c'era già.
  ///
  /// 💡 Quindi la regola giusta non è «non toccare niente», è **chi possiede
  /// cosa**:
  ///
  /// | Campo | Di chi è | A una rilettura |
  /// |---|---|---|
  /// | `tipo`, `finitoIl`, `kcal`, `distanzaMetri`, `passi` | dell'orologio | si **riscrive** |
  /// | `schedaAssegnata`, `nascosto` | di chi usa l'app | non si tocca **mai** |
  ///
  /// ⚠️ In transazione: a metà strada ci sarebbero righe inserite e non
  /// aggiornate, cioè di nuovo il numero vecchio su una parte dell'elenco.
  Future<int> scriviAllenamenti(List<AllenamentoDaOrologio> allenamenti) async {
    if (allenamenti.isEmpty) return 0;

    await transaction(() async {
      await batch(
        (b) => b.insertAll(
          allenamentiDaOrologio,
          allenamenti.map(_companionAllenamento).toList(),
          mode: InsertMode.insertOrIgnore,
        ),
      );

      for (final a in allenamenti) {
        await (update(allenamentiDaOrologio)..where(
              (t) =>
                  t.fonte.equals(a.fonte) & t.iniziatoIl.equals(a.iniziatoIl),
            ))
            .write(
              AllenamentiDaOrologioCompanion(
                tipo: Value(a.tipo),
                finitoIl: Value(a.finitoIl),
                kcal: Value(a.kcal),
                distanzaMetri: Value(a.distanzaMetri),
                passi: Value(a.passi),
              ),
            );
      }
    });

    return allenamenti.length;
  }

  // ══════════════════════════════════════════════════════════════════════
  // 🏋️ Le sedute registrate con l'app — FASE 11.1
  // ══════════════════════════════════════════════════════════════════════

  /// Apre una seduta e restituisce il suo `id` locale.
  ///
  /// 🚨 **`finitaIl` resta `null` finché non si chiude**, ed è quello che la
  /// rende «aperta». ⚠️ Deve sopravvivere alla chiusura dell'app: chi si allena
  /// mette giù il telefono, e il sistema può ucciderlo in qualunque momento.
  Future<int> apriSeduta({
    int? schedaServerId,
    String? nomeScheda,
    DateTime? quando,
  }) => into(seduteAllenamento).insert(
    SeduteAllenamentoCompanion.insert(
      schedaServerId: Value(schedaServerId),
      nomeScheda: Value(nomeScheda),
      iniziataIl: quando ?? DateTime.now(),
    ),
  );

  /// La seduta ancora aperta, se ce n'è una.
  ///
  /// ⚠️ **La più recente**, non «l'unica»: se per un difetto ne restassero due
  /// aperte, riprendere la più vecchia sarebbe la scelta peggiore — si
  /// scriverebbero le serie di oggi dentro la seduta di ieri.
  Future<SedutaAllenamento?> sedutaAperta() =>
      (select(seduteAllenamento)
            ..where((t) => t.finitaIl.isNull())
            ..orderBy([(t) => OrderingTerm.desc(t.iniziataIl)])
            ..limit(1))
          .getSingleOrNull();

  /// Chiude una seduta.
  ///
  /// 💡 `kcal` si scrive solo se arriva: passare `null` **non azzera** un numero
  /// già calcolato. ⚠️ La differenza fra «non lo so» e «zero» vale anche qui.
  Future<void> chiudiSeduta(
    int id, {
    DateTime? quando,
    int? kcal,
    bool? kcalAMano,
  }) => (update(seduteAllenamento)..where((t) => t.id.equals(id))).write(
    SeduteAllenamentoCompanion(
      finitaIl: Value(quando ?? DateTime.now()),
      kcal: kcal == null ? const Value.absent() : Value(kcal),
      kcalAMano: kcalAMano == null ? const Value.absent() : Value(kcalAMano),
    ),
  );

  /// Scrive le calorie **a mano** su una seduta — 🚨 e segna che sono a mano.
  ///
  /// ⛔ Le due scritture non si separano mai: `kcal` senza `kcalAMano` fa
  /// credere a un ricalcolo automatico di poter sovrascrivere una correzione
  /// della persona, ed è esattamente il difetto che `kcal_source` evitava sul
  /// server.
  Future<void> correggiKcalSeduta(int id, int kcal) =>
      (update(seduteAllenamento)..where((t) => t.id.equals(id))).write(
        SeduteAllenamentoCompanion(
          kcal: Value(kcal),
          kcalAMano: const Value(true),
        ),
      );

  /// Cancella una seduta **e le sue serie**.
  ///
  /// ══ 🚨 IL `cascade` DICHIARATO NON BASTA, E SI SCOPRE SOLO PROVANDO ═════
  ///
  /// `SerieDelleSedute.sedutaId` dichiara `onDelete: KeyAction.cascade`, ma
  /// **SQLite non applica le chiavi esterne se non gliele si accende** con
  /// `PRAGMA foreign_keys = ON`. ⚠️ Questo archivio non lo fa, e non è una
  /// dimenticanza da rimediare qui:
  ///
  /// 🚨 `ripristinaDaBackup()` svuota tutte le tabelle e le riscrive **in
  /// ordine di enumerazione**. Con i vincoli attivi, riscrivere le serie prima
  /// delle sedute fallirebbe — cioè il ripristino, che è l'unica copia dei dati
  /// dopo la FASE 11, si romperebbe per una precauzione.
  ///
  /// 💡 Quindi le serie si cancellano a mano, in transazione. ⛔ Senza,
  /// resterebbero righe orfane: nessuna schermata le mostra, ma il backup se le
  /// porta in giro per sempre.
  Future<void> cancellaSeduta(int id) => transaction(() async {
    await (delete(serieDelleSedute)..where((t) => t.sedutaId.equals(id))).go();
    await (delete(seduteAllenamento)..where((t) => t.id.equals(id))).go();
  });

  /// Le sedute, dalla più recente.
  Future<List<SedutaAllenamento>> sedute({int quante = 200, DateTime? da}) =>
      (select(seduteAllenamento)
            ..where(
              (t) => da == null
                  ? const Constant(true)
                  : t.iniziataIl.isBiggerOrEqualValue(da),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.iniziataIl)])
            ..limit(quante))
          .get();

  /// Importa una seduta che veniva dal server — FASE 11.3.
  ///
  /// 🚨 **Riconosce dall'`idServer`**: una seconda passata del trasloco non
  /// crea doppioni, aggiorna la riga che c'è già. ⚠️ Senza, chi apre l'app due
  /// volte prima che il server segni «fatto» si ritroverebbe lo storico
  /// duplicato — e con esso il volume settimanale e le calorie.
  ///
  /// 💡 Restituisce l'`id` **locale**, che è quello a cui le serie si legano.
  Future<int> importaSeduta({
    required int idServer,
    required DateTime iniziataIl,
    int? schedaServerId,
    String? nomeScheda,
    DateTime? finitaIl,
    int? kcal,
    bool kcalAMano = false,
  }) async {
    final esistente = await (select(
      seduteAllenamento,
    )..where((t) => t.idServer.equals(idServer))).getSingleOrNull();

    final valori = SeduteAllenamentoCompanion(
      idServer: Value(idServer),
      schedaServerId: Value(schedaServerId),
      nomeScheda: Value(nomeScheda),
      iniziataIl: Value(iniziataIl),
      finitaIl: Value(finitaIl),
      kcal: Value(kcal),
      kcalAMano: Value(kcalAMano),
    );

    if (esistente != null) {
      await (update(
        seduteAllenamento,
      )..where((t) => t.id.equals(esistente.id))).write(valori);

      return esistente.id;
    }

    return into(seduteAllenamento).insert(valori);
  }

  /// Quante righe di allenamento ci sono davvero nell'archivio — FASE 11.3.
  ///
  /// ⛔ **Si contano dall'archivio, non da quello che si è ricevuto.** Contare
  /// il pacchetto proverebbe che il server ha mandato qualcosa, non che il
  /// telefono l'abbia scritto: è la differenza fra un controllo e un rito.
  ///
  /// 🚨 Le chiavi sono quelle che il server si aspetta (`sessions`, `sets`,
  /// `daily_burns`): tradurle qui e non a metà strada evita che i due lati
  /// contino cose diverse chiamandole allo stesso modo.
  Future<Map<String, int>> conteggiDelTrasloco() async {
    Future<int> quante(TableInfo<Table, Object?> t, String dove) async {
      final riga = await customSelect(
        'SELECT COUNT(*) AS n FROM "${t.actualTableName}" $dove',
      ).getSingle();

      return riga.read<int>('n');
    }

    return {
      'sessions': await quante(
        seduteAllenamento,
        'WHERE id_server IS NOT NULL',
      ),

      /*
       * 🚨 Le serie **delle sedute venute dal server**, non tutte: dopo la 11.4
       * ci saranno anche quelle registrate qui, e non appartengono a nessun
       * conteggio del server.
       */
      'sets': await quante(
        serieDelleSedute,
        'WHERE seduta_id IN '
        '(SELECT id FROM sedute_allenamento WHERE id_server IS NOT NULL)',
      ),

      'daily_burns': await quante(bruciateDichiarate, 'WHERE da_server = 1'),
    };
  }

  /// Le serie di una seduta, nell'ordine in cui sono state fatte.
  Future<List<SerieSeduta>> serieDi(int sedutaId) =>
      (select(serieDelleSedute)
            ..where((t) => t.sedutaId.equals(sedutaId))
            ..orderBy([(t) => OrderingTerm.asc(t.numero)]))
          .get();

  /// Le serie di **più** sedute in una query sola.
  ///
  /// 🚨 Serve allo storico e al riassunto della settimana: chiamarne una per
  /// seduta vorrebbe dire trenta query per disegnare una schermata, su un
  /// database che sta sullo stesso telefono che deve restare fluido.
  Future<Map<int, List<SerieSeduta>>> serieDiPiuSedute(
    List<int> seduteIds,
  ) async {
    if (seduteIds.isEmpty) return const {};

    final righe =
        await (select(serieDelleSedute)
              ..where((t) => t.sedutaId.isIn(seduteIds))
              ..orderBy([(t) => OrderingTerm.asc(t.numero)]))
            .get();

    final per = <int, List<SerieSeduta>>{};
    for (final r in righe) {
      (per[r.sedutaId] ??= []).add(r);
    }

    return per;
  }

  /// Registra una serie. Se esiste già `(seduta, esercizio, numero)`, la
  /// **sostituisce**.
  ///
  /// 💡 È il gesto giusto per questa tabella, al contrario di
  /// [scriviAllenamenti]: qui non c'è nessun campo «di chi usa l'app» da
  /// difendere — riscrivere la terza serie di panca **è** quello che si vuole
  /// quando si corregge un numero sbagliato.
  Future<void> registraSerie(SerieDelleSeduteCompanion serie) =>
      into(serieDelleSedute).insert(serie, mode: InsertMode.insertOrReplace);

  Future<void> cancellaSerie(int id) =>
      (delete(serieDelleSedute)..where((t) => t.id.equals(id))).go();

  /// Le calorie dichiarate a mano per un giorno, o `null`.
  Future<int?> bruciateAManoDel(DateTime giorno) async {
    final riga =
        await (select(bruciateDichiarate)..where(
              (t) => t.giorno.equals(
                DateTime(giorno.year, giorno.month, giorno.day),
              ),
            ))
            .getSingleOrNull();

    return riga?.kcal;
  }

  /// Le calorie dichiarate a mano in un intervallo, per giorno.
  Future<Map<DateTime, int>> bruciateAManoFra(DateTime da, DateTime a) async {
    final righe =
        await (select(bruciateDichiarate)..where(
              (t) =>
                  t.giorno.isBiggerOrEqualValue(da) &
                  t.giorno.isSmallerOrEqualValue(a),
            ))
            .get();

    return {for (final r in righe) r.giorno: r.kcal};
  }

  /// Dichiara le calorie bruciate di un giorno.
  ///
  /// ⚠️ **Una riga per giorno**: è una dichiarazione complessiva, non un
  /// contributo. 🚨 Permetterne due vorrebbe dire sommarle, e chi corregge il
  /// numero si ritroverebbe il doppio.
  Future<void> dichiaraBruciate(
    DateTime giorno,
    int kcal, {
    bool daServer = false,
  }) => into(bruciateDichiarate).insert(
    BruciateDichiarateCompanion.insert(
      giorno: DateTime(giorno.year, giorno.month, giorno.day),
      kcal: kcal,
      daServer: Value(daServer),
    ),
    mode: InsertMode.insertOrReplace,
  );

  Future<void> togliBruciateAMano(DateTime giorno) =>
      (delete(bruciateDichiarate)..where(
            (t) => t.giorno.equals(
              DateTime(giorno.year, giorno.month, giorno.day),
            ),
          ))
          .go();

  /// Gli allenamenti dell'orologio, dal più recente.
  ///
  /// 💡 `nascosto` non si filtra qui: lo storico vuole nasconderli, la schermata
  /// che permette di **rimetterli** deve poterli vedere. Filtrare alla fonte
  /// renderebbe la scelta irreversibile.
  Future<List<AllenamentoDaOrologio>> allenamentiDellOrologio({
    int quanti = 200,
  }) =>
      (select(allenamentiDaOrologio)
            ..orderBy([(t) => OrderingTerm.desc(t.iniziatoIl)])
            ..limit(quanti))
          .get();

  /// Assegna (o toglie) la scheda che questa persona dice di aver fatto.
  Future<void> assegnaSchedaAllenamento(int id, int? schedaId) =>
      (update(allenamentiDaOrologio)..where((t) => t.id.equals(id))).write(
        AllenamentiDaOrologioCompanion(schedaAssegnata: Value(schedaId)),
      );

  /// Nasconde o rimette un allenamento nello storico.
  Future<void> nascondiAllenamento(int id, {required bool nascosto}) =>
      (update(allenamentiDaOrologio)..where((t) => t.id.equals(id))).write(
        AllenamentiDaOrologioCompanion(nascosto: Value(nascosto)),
      );

  /// Stacca (o riattacca) un allenamento dal gruppo — FASE 1-bis.
  ///
  /// 🚨 **Non e' `nascondiAllenamento` con un altro nome.** Nascondere toglie
  /// una riga dallo storico; staccare ne aggiunge una, perche' separa due cose
  /// che erano state messe insieme. ⚠️ Chi confonde i due gesti corregge un
  /// raggruppamento sbagliato facendo sparire un allenamento vero.
  Future<void> staccaAllenamento(int id, {required bool staccato}) =>
      (update(allenamentiDaOrologio)..where((t) => t.id.equals(id))).write(
        AllenamentiDaOrologioCompanion(staccato: Value(staccato)),
      );

  /*
   * 🚨 **L'`id` va lasciato ASSENTE, non messo a zero.**
   *
   * Le classi generate da drift hanno l'`id` obbligatorio, quindi chi costruisce
   * una `LetturaSalute` a mano e' costretto a mettercene uno — e il valore
   * naturale e' `0`. Ma `id` e' la **chiave primaria autoincrementale**: con lo
   * zero esplicito ogni riga arriva al database con la stessa chiave, e
   * `insertOrIgnore` scarta in silenzio tutte quelle dopo la prima.
   *
   * ⚠️ Il sintomo e' crudele: nessun errore, nessuna eccezione, e un archivio
   * che contiene **una riga sola** per ogni sincronizzazione. L'ha trovato il
   * test `si scrivono e si rileggono dalla piu' recente` — a mano non si sarebbe
   * visto, perche' una lettura al giorno arriva comunque.
   */
  LettureSaluteCompanion _companionLettura(LetturaSalute l) =>
      LettureSaluteCompanion.insert(
        fonte: l.fonte,
        metrica: l.metrica,
        misurataIl: l.misurataIl,
        giorno: l.giorno,
        valore: l.valore,
      );

  CampioniSonnoCompanion _companionCampione(CampioneSonno c) =>
      CampioniSonnoCompanion.insert(
        fonte: c.fonte,
        notte: c.notte,
        iniziatoIl: c.iniziatoIl,
        finitoIl: c.finitoIl,
        fase: c.fase,
      );

  /// ⚠️ `schedaAssegnata` e `nascosto` **non si passano**: sono di chi usa
  /// l'app, non dell'orologio. Lasciarli assenti li fa nascere `null` e `false`,
  /// e — insieme a `insertOrIgnore` — garantisce che una rilettura non li tocchi.
  AllenamentiDaOrologioCompanion _companionAllenamento(
    AllenamentoDaOrologio a,
  ) => AllenamentiDaOrologioCompanion.insert(
    fonte: a.fonte,
    tipo: a.tipo,
    iniziatoIl: a.iniziatoIl,
    finitoIl: a.finitoIl,
    kcal: Value(a.kcal),
    distanzaMetri: Value(a.distanzaMetri),
    passi: Value(a.passi),
  );

  // ─────────────────────────── lettura ───────────────────────────

  /// Le letture di una metrica in una finestra di giorni, **dalla più recente**.
  Future<List<LetturaSalute>> lettureRecenti(
    MetricaSalute metrica, {
    required int giorni,
  }) {
    final da = DateTime.now().subtract(Duration(days: giorni));

    return (select(lettureSalute)
          ..where(
            (t) =>
                t.metrica.equals(metrica.codice) &
                t.misurataIl.isBiggerOrEqualValue(da),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.misurataIl)]))
        .get();
  }

  /// Una media **per giorno**, per disegnare un grafico.
  ///
  /// ── 🚨 Perché aggregato e non grezzo ──────────────────────────────────
  ///
  /// Un orologio manda l'HRV in continuazione: sul telefono del committente
  /// sono **8.557 letture in trenta giorni**, contro 104 di battito a riposo.
  /// Disegnarle tutte darebbe una linea che oscilla dieci volte al minuto —
  /// cioè rumore del sensore, non un andamento.
  ///
  /// 💡 Ed è anche la stessa scala con cui si legge il dato: `MediaDiRiferimento`
  /// confronta il valore di **oggi** con la media dei giorni prima. Un grafico a
  /// granularità diversa dal giudizio racconterebbe un'altra storia.
  ///
  /// ⚠️ I giorni senza letture **non compaiono**: non si riempiono i buchi. Un
  /// valore inventato per un giorno in cui l'orologio era scarico è
  /// indistinguibile da una misura vera.
  Future<List<MediaGiornaliera>> mediePerGiorno(
    MetricaSalute metrica, {
    int giorni = 30,
  }) async {
    /*
     * ══ ⚠️ «31 GIORNI CON DATI NEGLI ULTIMI 30» — corretto il 23/08/2026 ═══
     *
     * ⛔ Era `subtract(giorni)` con il confronto `>=`: da *oggi meno trenta* a
     * *oggi* ci sono **trentuno** giorni, estremi compresi. La schermata lo
     * diceva a chiare lettere, e faceva sembrare che l'app non sappia contare.
     *
     * 💡 `giorni - 1`: oggi è il primo dei trenta, non il trentunesimo.
     */
    final da = _soloGiorno(DateTime.now().subtract(Duration(days: giorni - 1)));

    final righe = await customSelect(
      'SELECT giorno, AVG(valore) AS media, MIN(valore) AS minimo, '
      'MAX(valore) AS massimo, COUNT(*) AS quante '
      'FROM letture_salute WHERE metrica = ?1 AND giorno >= ?2 '
      'GROUP BY giorno ORDER BY giorno ASC',
      variables: [
        Variable.withString(metrica.codice),
        Variable.withDateTime(da),
      ],
      readsFrom: {lettureSalute},
    ).get();

    return righe
        .map(
          (r) => MediaGiornaliera(
            giorno: r.read<DateTime>('giorno'),
            media: r.read<double>('media'),
            minimo: r.read<double>('minimo'),
            massimo: r.read<double>('massimo'),
            quante: r.read<int>('quante'),
          ),
        )
        .toList();
  }

  /// L'ultima lettura di una metrica, se c'è.
  Future<LetturaSalute?> ultimaLettura(MetricaSalute metrica) {
    return (select(lettureSalute)
          ..where((t) => t.metrica.equals(metrica.codice))
          ..orderBy([(t) => OrderingTerm.desc(t.misurataIl)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Le letture di una metrica in un intervallo di **giorni** (estremi inclusi).
  ///
  /// ⚠️ Serve alla media di riferimento, che deve poter dire «i sette giorni
  /// **prima** di quello dell'ultima misura» — e non «gli ultimi sette da
  /// adesso», che con una misura vecchia darebbe una finestra vuota.
  Future<List<LetturaSalute>> lettureFraGiorni(
    MetricaSalute metrica, {
    required DateTime da,
    required DateTime a,
  }) {
    return (select(lettureSalute)
          ..where(
            (t) =>
                t.metrica.equals(metrica.codice) &
                t.giorno.isBiggerOrEqualValue(_soloGiorno(da)) &
                t.giorno.isSmallerOrEqualValue(_soloGiorno(a)),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.misurataIl)]))
        .get();
  }

  /// Le calorie bruciate con l'attività in un giorno — FASE 1.
  ///
  /// ── 🚨 Perché il MASSIMO fra le sorgenti, e non la somma ─────────────
  ///
  /// Health Connect può ricevere le calorie attive da **più applicazioni
  /// insieme**: l'orologio le misura, e intanto il telefono le stima dai passi.
  /// Sommando tutto, una camminata verrebbe contata **due volte** — e il numero
  /// resterebbe plausibile.
  ///
  /// 💡 Si somma **dentro ogni sorgente** e si tiene la **più alta**: chi ha
  /// misurato di più è quasi sempre il dispositivo che la persona indossava,
  /// mentre la stima dai passi del telefono in tasca è la più povera. ⚠️ Non è
  /// perfetto — due orologi diversi darebbero comunque il maggiore invece della
  /// realtà — ma sbaglia **per difetto**, che sul margine calorico è il verso
  /// giusto.
  ///
  /// ── ⚠️ E non esce mai da questo telefono ─────────────────────────────────
  ///
  /// È un dato di salute: vive qui e finisce **nel backup**, e il server non lo
  /// vede. La somma con l'obiettivo si fa **a runtime** nell'app.
  Future<int> kcalAttiveDi(DateTime giorno) async {
    final righe =
        await (select(lettureSalute)..where(
              (t) =>
                  t.metrica.equals(MetricaSalute.calorieAttive.codice) &
                  t.giorno.equals(_soloGiorno(giorno)),
            ))
            .get();

    if (righe.isEmpty) return 0;

    final perSorgente = <String, double>{};

    for (final r in righe) {
      perSorgente[r.fonte] = (perSorgente[r.fonte] ?? 0) + r.valore;
    }

    return perSorgente.values.reduce((a, b) => a > b ? a : b).round();
  }

  /// I campioni di una notte, in ordine di inizio.
  Future<List<CampioneSonno>> campioniDellaNotte(DateTime notte) {
    return (select(campioniSonno)
          ..where((t) => t.notte.equals(_soloGiorno(notte)))
          ..orderBy([(t) => OrderingTerm.asc(t.iniziatoIl)]))
        .get();
  }

  /// La notte più recente per cui esiste almeno un campione.
  Future<DateTime?> ultimaNotteConDati() async {
    final riga =
        await (select(campioniSonno)
              ..orderBy([(t) => OrderingTerm.desc(t.notte)])
              ..limit(1))
            .getSingleOrNull();

    return riga?.notte;
  }

  // ─────────────────────────── corpo (S5.2) ───────────────────────────

  /// Registra una misura del corpo.
  ///
  /// 🚨 **UPSERT su `(giorno)`, non `insert`.** Pesarsi due volte lo stesso
  /// giorno è una **correzione**, non un secondo punto sul grafico: la bilancia
  /// si guarda spesso due volte di seguito, e due punti a distanza di un minuto
  /// renderebbero il grafico illeggibile.
  ///
  /// ⚠️ Era `UNIQUE(user_id, date)` sul server. La regola non cambia perché
  /// cambia casa.
  Future<void> registraMisura(MisuraCorpo misura) async {
    final riga = MisureCorpoCompanion.insert(
      giorno: _soloGiorno(misura.giorno),
      pesoKg: Value(misura.pesoKg),
      massaGrassaPct: Value(misura.massaGrassaPct),
      vitaCm: Value(misura.vitaCm),
      toraceCm: Value(misura.toraceCm),
      braccioCm: Value(misura.braccioCm),
      cosciaCm: Value(misura.cosciaCm),
      note: Value(misura.note),
    );

    /*
     * 🚨 `target: [giorno]` e NON `insertOnConflictUpdate()` da solo.
     *
     * `insertOnConflictUpdate()` risolve il conflitto sulla **chiave
     * primaria**, che qui e' `id` — un autoincrement che non collide mai.
     * L'unicita' che ci interessa e' su `giorno`, ed e' un vincolo separato:
     * senza indicarlo esplicitamente, la seconda pesata dello stesso giorno
     * **lancia** `UNIQUE constraint failed` invece di correggere la prima.
     *
     * ⚠️ Il sintomo sarebbe arrivato all'utente, non a noi: si pesa, si
     * ripesa un minuto dopo perche' la bilancia ballava, e l'app da' errore.
     */
    await into(misureCorpo).insert(
      riga,
      onConflict: DoUpdate((_) => riga, target: [misureCorpo.giorno]),
    );
  }

  /// Lo storico delle misure, **dalla più recente**.
  Future<List<MisuraCorpo>> storicoMisure({int? ultimiGiorni}) {
    final q = select(misureCorpo)
      ..orderBy([(t) => OrderingTerm.desc(t.giorno)]);

    if (ultimiGiorni != null) {
      final da = _soloGiorno(
        DateTime.now().subtract(Duration(days: ultimiGiorni)),
      );
      q.where((t) => t.giorno.isBiggerOrEqualValue(da));
    }

    return q.get();
  }

  /// L'ultimo peso registrato, se c'è.
  ///
  /// ⚠️ **L'ultimo con un peso**, non l'ultima riga: una misura può portare solo
  /// la circonferenza della vita, e in quel caso il peso non è cambiato — è solo
  /// assente da quella riga.
  Future<MisuraCorpo?> ultimoPeso() {
    return (select(misureCorpo)
          ..where((t) => t.pesoKg.isNotNull())
          ..orderBy([(t) => OrderingTerm.desc(t.giorno)])
          ..limit(1))
        .getSingleOrNull();
  }

  // ─────────────────────────── foto (S5.3) ───────────────────────────

  Future<int> registraFoto(FotoProgressiCompanion foto) =>
      into(fotoProgressi).insert(foto);

  /// La galleria, dalla più recente.
  Future<List<FotoProgresso>> galleria() {
    return (select(
      fotoProgressi,
    )..orderBy([(t) => OrderingTerm.desc(t.scattataIl)])).get();
  }

  /// Le foto di una sessione di allenamento.
  Future<List<FotoProgresso>> fotoDellaSessione(int sessioneId) {
    return (select(fotoProgressi)
          ..where((t) => t.sessioneId.equals(sessioneId))
          ..orderBy([(t) => OrderingTerm.desc(t.scattataIl)]))
        .get();
  }

  Future<FotoProgresso?> foto(int id) =>
      (select(fotoProgressi)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> dimenticaFoto(int id) =>
      (delete(fotoProgressi)..where((t) => t.id.equals(id))).go();

  // ─────────────────────────── cancellazione ───────────────────────────

  /// Cancella tutto.
  ///
  /// 🚨 **Non è un metodo di servizio: è un obbligo.** Con i dati sul telefono,
  /// «cancella il mio account» e «esci» **devono** cancellare anche questo
  /// archivio — il server non può farlo per conto suo, perché non ha mai avuto
  /// niente da cancellare.
  ///
  /// ⚠️ Va agganciato al logout **e** alla cancellazione dell'account (S9.3).
  /// Dimenticarlo significa lasciare i dati sanitari di una persona sul
  /// telefono dopo che ha chiesto di sparire.
  Future<void> svuota() async {
    /*
     * ⚠️ **I FILE delle foto vanno cancellati a parte.**
     *
     * Qui spariscono solo le righe. Le immagini sono file su disco, e una
     * `DELETE` sulla tabella li lascerebbe li' senza piu' niente che ne ricordi
     * l'esistenza — il peggiore dei due esiti, perche' occupano spazio e
     * contengono il corpo di una persona che ha chiesto di sparire.
     *
     * Se ne occupa `AzioniFoto.cancellaTutto()`, che passa di qui **dopo** aver
     * cancellato i file. E' la stessa avvertenza che il backend aveva su
     * `Media::delete()` in `AccountEraser::cancellaFoto()`.
     */
    await batch((b) {
      b.deleteAll(lettureSalute);
      b.deleteAll(campioniSonno);
      b.deleteAll(misureCorpo);
      b.deleteAll(fotoProgressi);
      b.deleteAll(schedeRicevute);
      b.deleteAll(pianiRicevuti);
      /*
       * ⚠️ **Anche i rifiutati.** Sono una decisione di **questa** persona: chi
       * arriva dopo su questo telefono non deve ereditare i piani che qualcun
       * altro aveva buttato — se ne riceve uno, deve vederlo.
       */
      b.deleteAll(contenutiRifiutati);
    });
  }

  // ───────────────── le schede ricevute dal trainer (S7.4) ─────────────────

  /// Salva una scheda arrivata via chat.
  ///
  /// 🚨 **La chiave è l'id del messaggio, non quello della scheda.** Lo stesso
  /// modello può arrivare due volte — il trainer lo rimanda dopo averlo
  /// corretto — e sono **due schede diverse** nella vita di chi le riceve: la
  /// vecchia va tenuta finché non la si butta, o sparirebbe lo storico di cosa
  /// si stava facendo il mese scorso.
  ///
  /// ⚠️ Toccare due volte «aggiungi» sullo stesso messaggio invece non deve
  /// produrre due copie: da qui `insertOrIgnore` sull'unique di `messaggioId`.
  Future<bool> salvaScheda({
    required int messaggioId,
    required int mittenteId,
    required String nome,
    required String scheda,
    String? origineId,
  }) async {
    if (origineId != null && await eRifiutato(origineId)) return false;

    if (origineId != null) {
      final esistente = await (select(
        schedeRicevute,
      )..where((t) => t.origineId.equals(origineId))).getSingleOrNull();

      if (esistente != null) {
        // ⚠️ Fuori ordine: una versione piu' vecchia che arriva dopo non
        // sovrascrive quella buona. Vedi `salvaPiano()`.
        if (esistente.messaggioId >= messaggioId) return false;

        await (update(
          schedeRicevute,
        )..where((t) => t.id.equals(esistente.id))).write(
          SchedeRicevuteCompanion(
            messaggioId: Value(messaggioId),
            mittenteId: Value(mittenteId),
            nome: Value(nome),
            scheda: Value(scheda),
            aggiornatoIl: Value(DateTime.now()),
          ),
        );

        return true;
      }
    }

    await into(schedeRicevute).insert(
      SchedeRicevuteCompanion.insert(
        messaggioId: messaggioId,
        mittenteId: mittenteId,
        nome: nome,
        scheda: scheda,
        origineId: Value(origineId),
        ricevutaIl: DateTime.now(),
      ),
      mode: InsertMode.insertOrIgnore,
    );

    return true;
  }

  Future<List<SchedaRicevuta>> schede() {
    return (select(
      schedeRicevute,
    )..orderBy([(t) => OrderingTerm.desc(t.ricevutaIl)])).get();
  }

  /// C'è già? Serve alla chat per dire «aggiunta» invece di «aggiungi».
  Future<bool> schedaGiaSalvata(int messaggioId) async {
    final riga = await (select(
      schedeRicevute,
    )..where((t) => t.messaggioId.equals(messaggioId))).getSingleOrNull();

    return riga != null;
  }

  /// Butta una scheda, e **ricorda che e' stata buttata** — G8.10.
  Future<void> dimenticaScheda(int id) async {
    final riga = await (select(
      schedeRicevute,
    )..where((t) => t.id.equals(id))).getSingleOrNull();

    if (riga?.origineId != null) {
      await into(contenutiRifiutati).insert(
        ContenutiRifiutatiCompanion.insert(
          origineId: riga!.origineId!,
          rifiutatoIl: DateTime.now(),
        ),
        mode: InsertMode.insertOrIgnore,
      );
    }

    await (delete(schedeRicevute)..where((t) => t.id.equals(id))).go();
  }

  // ───────────────── i piani alimentari ricevuti (G8) ─────────────────

  /// Salva un piano arrivato via chat, o **sostituisce** quello che c'era.
  ///
  /// ── 🚨 La regola di D15, per intero ───────────────────────────────────
  ///
  /// | Caso | Cosa succede |
  /// |---|---|
  /// | `origineId` mai visto | si salva |
  /// | gia' in archivio, busta **piu' recente** | si **sostituisce**, conservando `ricevutaIl` |
  /// | gia' in archivio, busta **piu' vecchia** | si ignora |
  /// | rifiutato in passato | non si salva |
  /// | busta senza `origineId` (v1) | si cade su `messaggioId`, come prima |
  ///
  /// ⚠️ **«Piu' recente» si misura sull'id del messaggio**, non sull'ora: i
  /// messaggi possono arrivare fuori ordine — l'app riprende una conversazione
  /// vecchia, o due dispositivi si sincronizzano — e una versione vecchia che
  /// arriva dopo non deve sovrascrivere quella buona.
  ///
  /// 🚨 **`ricevutaIl` non si sposta.** E' la data che l'allievo riconosce
  /// («quello di marzo»): spostarla a ogni correzione del trainer gli farebbe
  /// sembrare nuovo un piano che segue da mesi.
  ///
  /// @return `true` se qualcosa e' stato scritto.
  Future<bool> salvaPiano({
    required int messaggioId,
    required int mittenteId,
    required String nome,
    required String piano,
    String? origineId,
  }) async {
    if (origineId != null && await eRifiutato(origineId)) return false;

    if (origineId != null) {
      final esistente = await (select(
        pianiRicevuti,
      )..where((t) => t.origineId.equals(origineId))).getSingleOrNull();

      if (esistente != null) {
        if (esistente.messaggioId >= messaggioId) return false;

        await (update(
          pianiRicevuti,
        )..where((t) => t.id.equals(esistente.id))).write(
          PianiRicevutiCompanion(
            messaggioId: Value(messaggioId),
            mittenteId: Value(mittenteId),
            nome: Value(nome),
            piano: Value(piano),
            aggiornatoIl: Value(DateTime.now()),
          ),
        );

        return true;
      }
    }

    await into(pianiRicevuti).insert(
      PianiRicevutiCompanion.insert(
        messaggioId: messaggioId,
        mittenteId: mittenteId,
        nome: nome,
        piano: piano,
        origineId: Value(origineId),
        ricevutaIl: DateTime.now(),
      ),
      // ⚠️ Sull'unique di `messaggioId`: toccare due volte lo stesso messaggio
      // non deve produrre due copie.
      mode: InsertMode.insertOrIgnore,
    );

    return true;
  }

  /// Salva un piano che la persona ha **importato da un PDF** — N20.
  ///
  /// ── 🚨 Perche' finisce nella STESSA tabella dei piani ricevuti ────
  ///
  /// Perche' un piano importato **e' un piano**. Metterlo altrove vorrebbe dire
  /// due elenchi da mostrare, due strade nel backup e due posti dove cercarlo —
  /// e il giorno che una delle due si dimentica di una colonna, il difetto si
  /// vede solo su meta' dei piani.
  ///
  /// ── ⚠️ L'id del messaggio, che qui un messaggio non c'e' ────────────────
  ///
  /// `messaggioId` e' `unique` e serve a non duplicare un piano toccando due
  /// volte lo stesso messaggio. Un'importazione non ha un messaggio: si usa
  /// **l'id dell'importazione col segno meno**, che non puo' collidere con
  /// nessun id di messaggio (quelli sono positivi) e resta stabile se si
  /// riprova.
  ///
  /// 💡 `mittenteId: 0` vuol dire «nessuno me l'ha mandato, l'ho portato
  /// io»: e' l'unico valore che non somiglia all'id di una persona vera.
  Future<void> salvaPianoImportato({
    required int importazioneId,
    required String nome,
    required String piano,
    String? pdfOriginale,
  }) async {
    await into(pianiRicevuti).insert(
      PianiRicevutiCompanion.insert(
        messaggioId: -importazioneId,
        mittenteId: 0,
        nome: nome,
        piano: piano,
        origineId: Value('importato:$importazioneId'),
        pdfOriginale: Value(pdfOriginale),
        importato: const Value(true),
        ricevutaIl: DateTime.now(),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<List<PianoRicevuto>> piani() {
    return (select(
      pianiRicevuti,
    )..orderBy([(t) => OrderingTerm.desc(t.ricevutaIl)])).get();
  }

  Future<bool> pianoGiaSalvato(int messaggioId) async {
    final riga = await (select(
      pianiRicevuti,
    )..where((t) => t.messaggioId.equals(messaggioId))).getSingleOrNull();

    return riga != null;
  }

  /// Butta un piano, e **ricorda che e' stato buttato** — G8.10.
  ///
  /// 🚨 Senza la seconda meta', il salvataggio automatico glielo rimetterebbe
  /// davanti al messaggio successivo. Buttare e' una decisione.
  Future<void> dimenticaPiano(int id) async {
    final riga = await (select(
      pianiRicevuti,
    )..where((t) => t.id.equals(id))).getSingleOrNull();

    if (riga?.origineId != null) {
      await into(contenutiRifiutati).insert(
        ContenutiRifiutatiCompanion.insert(
          origineId: riga!.origineId!,
          rifiutatoIl: DateTime.now(),
        ),
        mode: InsertMode.insertOrIgnore,
      );
    }

    await (delete(pianiRicevuti)..where((t) => t.id.equals(id))).go();
  }

  Future<bool> eRifiutato(String origineId) async {
    final riga = await (select(
      contenutiRifiutati,
    )..where((t) => t.origineId.equals(origineId))).getSingleOrNull();

    return riga != null;
  }

  // ───────────────────────── la copia di sicurezza ─────────────────────────

  /// 🚨 La chiave con cui si riconosce la versione dello schema dentro un
  /// backup. Se cambia, i file vecchi smettono di essere leggibili.
  static const chiaveSchema = '_schema';

  /// Tutto l'archivio in una mappa, pronta per il file di backup — N1.1.
  ///
  /// ── 🚨 Si ENUMERANO le tabelle, non si scrive un elenco ────────────────
  ///
  /// `allTables` viene dal codice generato da drift, quindi una tabella
  /// aggiunta domani entra qui **da sola**. ⚠️ Un elenco scritto a mano
  /// invecchia: la prima tabella di una fase futura resterebbe fuori dal
  /// backup, e nessuno se ne accorgerebbe finché qualcuno non prova a
  /// ripristinare e scopre che manca qualcosa.
  ///
  /// 💡 È lo stesso principio che il progetto usa già altrove — il gate
  /// dell'isolamento fra palestre e lo spostamento dei dati quando si entra in
  /// una palestra enumerano entrambi invece di elencare.
  ///
  /// ── ⚠️ `SELECT *` e non le classi generate ─────────────────────────────
  ///
  /// Le righe tornano come `Map<String, Object?>` di valori primitivi — interi,
  /// reali, testo, `null`. Passando dalle classi di drift servirebbe un
  /// `toJson()` per tabella, cioè di nuovo del codice per tabella, cioè di
  /// nuovo qualcosa che invecchia.
  ///
  /// 🚨 **Nessuna colonna è un blob**, verificato: le foto sono **percorsi**,
  /// non byte. Se un giorno ne comparisse una, questa funzione andrebbe
  /// cambiata — `Uint8List` non passa da `jsonEncode`.
  Future<Map<String, dynamic>> esportaPerBackup() async {
    final dati = <String, dynamic>{
      /*
       * 🚨 La versione dello schema viaggia **dentro** il backup.
       *
       * ⚠️ Senza, ripristinare un file vecchio su un'app nuova sarebbe un tiro
       * di dadi: le colonne potrebbero non esserci più, o essercene di nuove
       * senza valore. Con il numero, il ripristino sa cosa ha in mano.
       */
      chiaveSchema: schemaVersion,
    };

    for (final tabella in allTables) {
      final nome = tabella.actualTableName;
      final righe = await customSelect('SELECT * FROM "$nome"').get();

      dati[nome] = righe.map((r) => r.data).toList(growable: false);
    }

    return dati;
  }

  /// Riscrive l'archivio da un backup — N1.2.
  ///
  /// ── 🚨 In una transazione, e non è una precauzione di stile ────────────
  ///
  /// A metà strada l'archivio è **svuotato e non ancora riempito**. ⚠️ Se
  /// qualcosa fallisse lì — disco pieno, file rovinato, app uccisa dal sistema
  /// — senza transazione la persona resterebbe con un archivio vuoto **e senza
  /// più quello di prima**: il ripristino avrebbe distrutto esattamente ciò che
  /// doveva salvare.
  ///
  /// ── ⚠️ La regola sugli schemi ──────────────────────────────────────────
  ///
  /// | Backup | Cosa si fa |
  /// |---|---|
  /// | Schema **più vecchio** | si scrive, e drift fa girare le migrazioni |
  /// | Schema **uguale** | si scrive |
  /// | Schema **più nuovo** | 🚨 **si rifiuta** |
  ///
  /// Un backup più nuovo dell'app contiene tabelle e colonne che questa
  /// versione non conosce. Scriverle sarebbe impossibile; ignorarle
  /// silenziosamente vorrebbe dire ripristinare **meno di quello che c'era**
  /// facendo credere di aver ripristinato tutto — che è il modo per perdere
  /// dati con un messaggio verde davanti.
  ///
  /// 💡 Le colonne sconosciute **dentro una tabella nota** si scartano invece:
  /// è il caso normale di un backup vecchio letto da un'app nuova, e lì
  /// scartare è giusto — quella colonna non esisteva.
  ///
  /// @throws [BackupTroppoNuovo] se lo schema del file supera quello dell'app.
  Future<void> ripristinaDaBackup(Map<String, dynamic> dati) async {
    final schemaDelFile = (dati[chiaveSchema] as num?)?.toInt();

    if (schemaDelFile != null && schemaDelFile > schemaVersion) {
      throw BackupTroppoNuovo(delFile: schemaDelFile, dellApp: schemaVersion);
    }

    await transaction(() async {
      for (final tabella in allTables) {
        final nome = tabella.actualTableName;
        final righe = dati[nome];

        /*
         * ⚠️ Una tabella assente dal backup si **salta**, non si svuota.
         *
         * 🚨 È il caso di un backup vecchio: quella tabella non esisteva
         * ancora. Svuotarla cancellerebbe dati che il file non poteva
         * contenere — cioè il ripristino distruggerebbe qualcosa che non stava
         * ripristinando.
         */
        if (righe is! List) continue;

        await customStatement('DELETE FROM "$nome"');

        // 💡 I nomi delle colonne che questa versione dell'app conosce.
        final colonne = tabella.$columns.map((c) => c.name).toSet();

        for (final riga in righe) {
          if (riga is! Map) continue;

          final valori = <String, Object?>{};

          for (final voce in riga.entries) {
            final colonna = voce.key.toString();

            // ⚠️ Le colonne che non esistono più si scartano: il file è più
            // vecchio dell'app, e quella colonna è stata tolta apposta.
            if (colonne.contains(colonna)) valori[colonna] = voce.value;
          }

          if (valori.isEmpty) continue;

          final campi = valori.keys.map((c) => '"$c"').join(', ');
          final segnaposto = List.filled(valori.length, '?').join(', ');

          await customInsert(
            'INSERT INTO "$nome" ($campi) VALUES ($segnaposto)',
            variables: valori.values.map(_variabile).toList(growable: false),
          );
        }
      }
    });
  }

  /// 💡 Da valore JSON a variabile drift. I tipi che possono uscire da un
  /// `SELECT *` su questo archivio sono quattro, e `jsonDecode` li restituisce
  /// tutti come tipi Dart nativi.
  static Variable<Object> _variabile(Object? valore) => switch (valore) {
    null => const Variable<String>(null),
    final int v => Variable<int>(v),
    final double v => Variable<double>(v),
    final bool v => Variable<bool>(v),
    _ => Variable<String>(valore.toString()),
  };

  static DateTime _soloGiorno(DateTime d) => DateTime(d.year, d.month, d.day);

  static QueryExecutor _apri() {
    return LazyDatabase(() async {
      final cartella = await getApplicationDocumentsDirectory();

      /*
       * ⚠️ **Documents, non la cache.**
       *
       * La cache il sistema la svuota quando ha bisogno di spazio, e senza
       * avvisare. Un archivio di dati sanitari che sparisce da solo non e' un
       * problema di prestazioni: e' la media di riferimento che riparte da zero
       * e la funzione che smette di funzionare senza che nessuno capisca
       * perche'.
       */
      final file = File(p.join(cartella.path, 'salute.sqlite'));

      return NativeDatabase.createInBackground(file);
    });
  }
}

/// Il backup viene da una versione dell'app più nuova di questa — N1.2.
///
/// ── 🚨 Perché si rifiuta invece di provarci ────────────────────────────────
///
/// Un file più nuovo contiene tabelle e colonne che questa versione non
/// conosce. Scriverle è impossibile; ignorarle in silenzio vorrebbe dire
/// ripristinare **meno di quello che c'era** facendo credere di aver
/// ripristinato tutto — cioè perdere dati con un messaggio verde davanti.
///
/// 💡 La via d'uscita è semplice e va detta a chi legge: **aggiornare l'app**.
/// Capita davvero — si ripristina su un telefono vecchio con una versione
/// vecchia dal negozio — e non è un guasto.
class BackupTroppoNuovo implements Exception {
  const BackupTroppoNuovo({required this.delFile, required this.dellApp});

  /// Lo schema scritto dentro il file.
  final int delFile;

  /// Lo schema che questa versione dell'app sa gestire.
  final int dellApp;

  /// 💡 Il messaggio dice **cosa fare**, non solo cosa è successo.
  String get motivo =>
      'Questo backup è stato fatto con una versione più recente dell\'app. '
      'Aggiorna l\'app e riprova.';

  @override
  String toString() =>
      'BackupTroppoNuovo(file: $delFile, app: $dellApp) — $motivo';
}

/// Le letture istantanee: HRV, battito a riposo, battito medio.
@DataClassName('LetturaSalute')
class LettureSalute extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Da dove viene: `health_connect`, `healthkit`, `manuale`.
  TextColumn get fonte => text().withLength(min: 1, max: 32)();

  /// Il codice di `MetricaSalute`.
  TextColumn get metrica => text().withLength(min: 1, max: 24)();

  DateTimeColumn get misurataIl => dateTime()();

  /// Il giorno di appartenenza, a mezzanotte.
  ///
  /// ⚠️ Ridondante rispetto a `misurataIl`, e **serve**: la media di riferimento
  /// ragiona per giorni, e senza questa colonna ogni confronto diventerebbe un
  /// calcolo su un timestamp — cioè un indice che non si può usare.
  DateTimeColumn get giorno => dateTime()();

  RealColumn get valore => real()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {fonte, metrica, misurataIl},
  ];
}

/// I blocchi del sonno, uno per fase.
@DataClassName('CampioneSonno')
class CampioniSonno extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get fonte => text().withLength(min: 1, max: 32)();

  /// La notte di appartenenza — vedi `notteDi()`.
  DateTimeColumn get notte => dateTime()();

  DateTimeColumn get iniziatoIl => dateTime()();
  DateTimeColumn get finitoIl => dateTime()();

  /// Il codice di `FaseSonno`.
  IntColumn get fase => integer()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {fonte, iniziatoIl},
  ];
}

/// Peso e misure — S5.2.
///
/// 🚨 **Erano `body_metrics` sul server, e da S5 non ci stanno più**
/// (decisione D9-bis: *«tutti i dati sensibili devono sparire dal server»*).
///
/// ⚠️ **Sono i dati che vale davvero la pena non perdere.** Il peso di due anni
/// è la cosa che si guarda indietro; sonno e HRV valgono giorni e si ripigliano
/// da Health Connect. È per questo che il backup di S6.6 esiste soprattutto per
/// questa tabella.
@DataClassName('MisuraCorpo')
class MisureCorpo extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// 🚨 **Una misura al giorno per persona.** Vedi `registraMisura()`.
  DateTimeColumn get giorno => dateTime().unique()();

  RealColumn get pesoKg => real().nullable()();
  RealColumn get massaGrassaPct => real().nullable()();
  RealColumn get vitaCm => real().nullable()();
  RealColumn get toraceCm => real().nullable()();
  RealColumn get braccioCm => real().nullable()();
  RealColumn get cosciaCm => real().nullable()();

  TextColumn get note => text().nullable()();
}

/// Le foto dei progressi — S5.3.
///
/// 🚨 **Qui ci sta il PERCORSO, non l'immagine.** I file vivono in
/// `Documents/foto/`, e questa tabella è solo l'indice: metterci i byte
/// gonfierebbe il database e renderebbe lentissima ogni query che non c'entra.
///
/// ⚠️ **Sono l'unica cosa che il committente ha detto di poter perdere**
/// (*«tanto gli utenti ne avranno a bizzeffe nei loro cellulari»*), ed è per
/// questo che restano **fuori dal backup automatico**: Android Auto Backup ha un
/// tetto di ~25 MB per app, e con le foto dentro lo si sfonda al primo utente
/// facendo smettere di funzionare **anche il backup di tutto il resto**.
/// Entrano solo nel file esportato di S6.6, con una spunta.
@DataClassName('FotoProgresso')
class FotoProgressi extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Il percorso del file, relativo alla cartella dei documenti.
  ///
  /// 🚨 **Relativo, non assoluto.** Su iOS il contenitore dell'app cambia
  /// percorso a ogni aggiornamento: un percorso assoluto salvato oggi domani
  /// punta a niente, e la galleria si svuota da sola senza che nessuno abbia
  /// cancellato niente.
  TextColumn get percorso => text()();

  DateTimeColumn get scattataIl => dateTime()();

  /// La sessione di allenamento a cui è legata, se è una foto di fine
  /// allenamento (era `type = 'workout'` sul server).
  IntColumn get sessioneId => integer().nullable()();
}

/// I minuti di un campione.
extension MinutiDelCampione on CampioneSonno {
  int get minuti {
    final s = finitoIl.difference(iniziatoIl).inSeconds;

    return s <= 0 ? 0 : (s / 60).round();
  }
}

/// Le schede arrivate dal trainer via chat — S7.4.
///
/// 🚨 **Stanno qui e non sul server, ed è il punto dell'intera fase.** Una
/// scheda assegnata dice *«questa persona segue questo programma»*, e da un
/// programma post-infortunio si capisce cos'è successo a chi lo esegue. Il
/// modello resta sul server — è il patrimonio della palestra e non parla di
/// nessuno — ma **il legame fra la persona e il programma non ci arriva mai**.
///
/// 💡 La scheda si conserva **per intero**, come JSON, non come riferimento:
/// chi la riceve la tiene anche se domani cambia palestra, e un elenco di id
/// non gli servirebbe a niente.
@DataClassName('PianoRicevuto')
/// I piani alimentari arrivati dal trainer via chat — G8.4.
///
/// 🚨 **Gemella di `SchedeRicevute`, e per la stessa ragione**: vivono sul
/// telefono. Un piano dice cosa mangia una persona, e da un piano si capisce
/// molto di lei — il modello resta sul server, il legame fra la persona e il
/// piano non ci arriva mai (D4).
class PianiRicevuti extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get messaggioId => integer().unique()();

  IntColumn get mittenteId => integer()();

  /// 🚨 **L'identita' stabile del piano** — D15.
  ///
  /// E' cio' che permette di riconoscere che un piano arrivato e' la **versione
  /// nuova** di uno che c'e' gia', e di sostituirlo invece di affiancarlo.
  ///
  /// ⚠️ **Nullable**: le buste `v1` non ce l'hanno. Chi arriva senza cade sul
  /// comportamento vecchio — una riga per messaggio — che e' corretto, solo
  /// meno furbo.
  TextColumn get origineId => text().nullable()();

  TextColumn get nome => text()();

  TextColumn get piano => text()();

  /// 🚨 **La PRIMA volta che questo piano e' arrivato**, non l'ultima.
  ///
  /// Sostituendo una versione si conserva questa data: e' quella che l'allievo
  /// riconosce («quello di marzo»). Spostarla a ogni correzione del trainer
  /// gli farebbe sembrare nuovo un piano che segue da mesi.
  DateTimeColumn get ricevutaIl => dateTime()();

  /// Quando e' stato sostituito l'ultima volta. `null` = mai.
  DateTimeColumn get aggiornatoIl => dateTime().nullable()();

  /// Il PDF originale da cui e' stato importato — N20.4.
  ///
  /// 🚨 **Percorso relativo dentro `Documents/foto/piani`**, cioe' dentro
  /// il backup. L'originale deve restare consultabile anche quando la riga sul
  /// server e' scaduta: senza, fra un mese non c'e' piu' niente con cui
  /// confrontare i numeri che si stanno seguendo.
  ///
  /// ⚠️ `null` per i piani arrivati via chat, che un originale non ce l'hanno.
  TextColumn get pdfOriginale => text().nullable()();

  /// L'ha importato la persona da un PDF, non l'ha mandato un trainer.
  ///
  /// 💡 Serve a **dirlo in faccia** nell'elenco: un piano importato lo ha
  /// trascritto un modello e riletto una persona, e chi lo guarda fra sei mesi
  /// deve sapere da dove viene.
  BoolColumn get importato => boolean().withDefault(const Constant(false))();
}

@DataClassName('ContenutoRifiutato')
/// Cio' che l'allievo ha buttato, e che non deve tornare — G8.10.
///
/// ⚠️ **Senza questa tabella il salvataggio automatico e' una trappola**: chi
/// butta un piano se lo ritrova al messaggio successivo, lo butta di nuovo, e
/// cosi' per sempre. Buttare e' una decisione, e va ricordata.
class ContenutiRifiutati extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// L'`origine_id` del piano o della scheda rifiutata.
  TextColumn get origineId => text().unique()();

  DateTimeColumn get rifiutatoIl => dateTime()();
}

@DataClassName('SchedaRicevuta')
class SchedeRicevute extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// 🚨 **L'id del messaggio, unico.** È ciò che impedisce che toccare due
  /// volte «aggiungi» produca due copie della stessa scheda.
  ///
  /// ⚠️ Non è l'id della *scheda*: lo stesso modello può arrivare due volte —
  /// il trainer lo rimanda dopo averlo corretto — e sono **due schede diverse**
  /// nella vita di chi le riceve.
  IntColumn get messaggioId => integer().unique()();

  IntColumn get mittenteId => integer()();

  /// Il nome, estratto per poterlo mostrare senza aprire il JSON a ogni riga.
  TextColumn get nome => text()();

  /// La scheda intera, serializzata.
  TextColumn get scheda => text()();

  /// 🆕 G8 — l'identita' stabile (D15). Vedi `PianiRicevuti.origineId`.
  TextColumn get origineId => text().nullable()();

  DateTimeColumn get ricevutaIl => dateTime()();

  DateTimeColumn get aggiornatoIl => dateTime().nullable()();
}

/// Gli allenamenti che ha registrato l'orologio — FASE 1.8.
///
/// ── 🚨 Perché stanno sul telefono e non sul server ────────────────────────
///
/// Perché sono dati sanitari, e la regola del 19/08 non ha eccezioni: *«tutti i
/// dati che possono essere anche lontanamente sensibili devono restare solo
/// on-device, con il backup»*. Un elenco di quando e quanto ti alleni dice
/// molto, e non ci serve altrove.
///
/// 💡 Nel backup ci finisce **da sola**: `esportaPerBackup()` enumera
/// `allTables`.
///
/// ── ⚠️ Health Connect è il magazzino, non la fonte ────────────────────────
///
/// Ci scrivono l'app dell'orologio, Strava, Google Fit. Per questo `fonte` è la
/// cosa più importante dopo la data: `com.huami.watch.hmwatchmanager` è Zepp,
/// cioè un Amazfit. 🚨 Senza, due app che scrivono lo stesso allenamento
/// sarebbero indistinguibili — e la chiave unica non potrebbe funzionare.
@DataClassName('AllenamentoDaOrologio')
class AllenamentiDaOrologio extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Il pacchetto dell'app che l'ha scritto in Health Connect.
  TextColumn get fonte => text().withLength(min: 1, max: 64)();

  /// Il codice originale del tipo: `RUNNING`, `STRENGTH_TRAINING`, `BIKING`.
  ///
  /// 🚨 **Si salva il codice, non la traduzione.** Le etichette italiane vivono
  /// in `TipoAllenamento` e possono cambiare; il codice no. ⚠️ Salvando «Pesi»
  /// perderemmo la differenza fra `STRENGTH_TRAINING` e `WEIGHTLIFTING`, e
  /// nessuna correzione futura potrebbe recuperarla.
  TextColumn get tipo => text().withLength(min: 1, max: 48)();

  DateTimeColumn get iniziatoIl => dateTime()();
  DateTimeColumn get finitoIl => dateTime()();

  /// Le calorie **attive** bruciate durante la sessione.
  ///
  /// ══ 🚨 ATTIVE, non totali — corretto il 20/08 ═══════════════════════════
  ///
  /// Prima venivano da `WorkoutHealthValue.totalEnergyBurned`, cioè da
  /// `TotalCaloriesBurnedRecord`, che comprende il **metabolismo basale**.
  /// ⚠️ Il committente se n'è accorto in un minuto: l'app dell'orologio diceva
  /// **680 kcal** per quella seduta, la nostra ne mostrava **835**.
  ///
  /// 💡 Adesso si sommano i campioni di `ACTIVE_ENERGY_BURNED` che cadono nella
  /// finestra dell'allenamento — vedi `PonteSalute._attiveDentro`. Non è solo
  /// più corretto: è **la stessa fonte** delle calorie della giornata, quindi
  /// due schermate dell'app non possono più dire numeri diversi sulla stessa
  /// ora.
  ///
  /// 🚨 **`null` quando non si sa**, e non uno zero: nessun ripiego su
  /// `totalEnergyBurned`, che rimetterebbe dentro il basale di nascosto.
  ///
  /// ⚠️ **Non si sommano comunque al totale del giorno.** Quello si calcola già
  /// dagli stessi campioni: sommare anche queste li conterebbe due volte.
  IntColumn get kcal => integer().nullable()();

  /// Metri percorsi, quando ha senso: una corsa sì, i pesi quasi no.
  IntColumn get distanzaMetri => integer().nullable()();

  IntColumn get passi => integer().nullable()();

  /// La scheda che questa persona dice di aver fatto — richiesta del 19/08:
  /// *«devo poter scegliere di assegnarvi una mia scheda»*.
  ///
  /// 💡 È l'`id` locale di `SchedeRicevute`. `null` vuol dire «non l'ho
  /// assegnata», che è lo stato normale: la maggior parte delle corse non
  /// corrisponde a nessuna scheda.
  ///
  /// 🚨 **Una risincronizzazione non la cancella**: `scriviAllenamenti()` usa
  /// `insertOrIgnore`, quindi una riga già presente non viene riscritta. ⚠️ Con
  /// `insertOrReplace` l'orologio sovrascriverebbe una scelta della persona
  /// ogni volta che si rileggono gli ultimi sette giorni — cioè a ogni avvio.
  IntColumn get schedaAssegnata => integer().nullable()();

  /// Nascosto dallo storico perché è il doppione di una seduta del player.
  ///
  /// ⚠️ Chi si allena in palestra **con l'app aperta e l'orologio al polso**
  /// produce due registrazioni della stessa ora. Non si cancella quella
  /// dell'orologio — è un dato vero, e cancellarlo renderebbe la scelta
  /// irreversibile — si smette di mostrarla.
  BoolColumn get nascosto => boolean().withDefault(const Constant(false))();

  /// «Questo non si unisce a nessuno» — FASE 1-bis.
  ///
  /// ── 🚨 È la contropartita della regola larga ──────────────────────────────
  ///
  /// Dal 20/08 basta **un istante** di sovrapposizione perché due registrazioni
  /// siano lo stesso allenamento (decisione D-1bis/A). ⚠️ Una regola così larga
  /// prima o poi unisce due cose diverse — i pesi finiti alle 18:01 e la corsa
  /// cominciata alle 18:00 — e senza un modo di dire «no, sono due» quell'errore
  /// farebbe **sparire** un allenamento vero dallo storico.
  ///
  /// 💡 Il committente l'ha messa esattamente così: *«se i timeframes si
  /// sovrappongono allora è lo stesso allenamento. Poi ci mettiamo la
  /// possibilità di splittarli e via»*.
  ///
  /// ── ⚠️ Perché NON si riusa `nascosto` ─────────────────────────────────────
  ///
  /// Sono due gesti opposti. Chi nasconde vuole vedere **una riga in meno**; chi
  /// stacca vuole vederne **una in più**. Riusare la stessa colonna vorrebbe
  /// dire che l'unico modo di correggere un raggruppamento sbagliato è far
  /// sparire uno dei due allenamenti — cioè il difetto che si stava correggendo.
  BoolColumn get staccato => boolean().withDefault(const Constant(false))();

  /// 🚨 `fonte` + `iniziatoIl`: la stessa chiave del sonno, per la stessa
  /// ragione. Si rileggono sempre gli ultimi sette giorni, e senza questa
  /// coppia ogni avvio dell'app aggiungerebbe di nuovo tutto.
  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {fonte, iniziatoIl},
  ];
}

/// Una seduta di allenamento registrata **con l'app** — FASE 11.1, 21/08/2026.
///
/// ══ 🚨 PERCHÉ QUESTA TABELLA ESISTE ═══════════════════════════════════════
///
/// 📌 Il committente: *«Nessun allenamento deve risiedere sul server, devono
/// stare tutti nell'app»*. È la decisione già scritta il 16/08 in
/// `plan_tutto_sul_telefono.md` §2.1, rimasta a metà.
///
/// ⚠️ **Fino a oggi c'erano due case per la stessa cosa**: quello che arriva
/// dall'orologio in [AllenamentiDaOrologio], quello registrato col player in
/// `workout_sessions` **sul server**. 🚨 `storicoUnificatoProvider` esiste solo
/// per ricucire i due mondi — ed è il motivo per cui la scheda «Allenamento» si
/// è contraddetta da sola (difetto O.D.8).
///
/// ── ⚠️ `idServer` non è ridondante ───────────────────────────────────────
///
/// 🚨 Serve a **due** cose, e senza di esso la migrazione non è possibile:
///
/// 1. La migrazione (11.3) deve poter riscaricare senza duplicare: la chiave
///    unica è `idServer`, e una seconda passata non crea righe doppie.
/// 2. `SchedeRicevute` e le foto della seduta puntano all'id del server. ⛔
///    Buttarlo vorrebbe dire perdere il legame fra una seduta e la scheda che
///    è stata eseguita.
///
/// 💡 `null` per le sedute **nate sul telefono** dopo la migrazione: da lì in
/// poi il server non le vede mai, quindi un id di là non ce l'hanno.
@DataClassName('SedutaAllenamento')
class SeduteAllenamento extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// L'`id` che questa seduta aveva sul server, se ci è mai stata.
  IntColumn get idServer => integer().nullable().unique()();

  /// L'`id` **del server** della scheda eseguita, come lo mandava `plan_id`.
  ///
  /// ⚠️ Non l'id locale di `SchedeRicevute`: quello cambia da telefono a
  /// telefono, questo no. Le due cose si incrociano su `SchedeRicevute.origineId`.
  IntColumn get schedaServerId => integer().nullable()();

  /// 💡 Copiato al momento della seduta, non risolto ogni volta: la scheda può
  /// essere archiviata o rinominata, e lo storico deve continuare a dire quello
  /// che diceva allora.
  TextColumn get nomeScheda => text().nullable()();

  DateTimeColumn get iniziataIl => dateTime()();

  /// 🚨 `null` = **seduta ancora aperta**, ed è uno stato che deve sopravvivere
  /// alla chiusura dell'app: chi si allena mette giù il telefono.
  DateTimeColumn get finitaIl => dateTime().nullable()();

  /// Le calorie che **valgono** per questa seduta.
  ///
  /// ⚠️ Va sempre letta insieme a [kcalAMano]: è la coppia che tiene in piedi la
  /// regola «il manuale batte la stima». 🚨 Senza la seconda colonna, un
  /// ricalcolo automatico non sa se sta sovrascrivendo una stima o una
  /// correzione della persona — e lo scopre solo la persona, quando il suo
  /// numero sparisce.
  IntColumn get kcal => integer().nullable()();

  /// Se [kcal] l'ha scritta la persona invece della formula.
  BoolColumn get kcalAMano => boolean().withDefault(const Constant(false))();

  TextColumn get note => text().nullable()();

  // 💡 Niente `uniqueKeys`: `idServer` ha già il suo `.unique()` di colonna, e
  // dichiararlo due volte fa avvisare drift senza aggiungere niente.
}

/// Una serie dentro una seduta — FASE 11.1.
///
/// ⚠️ **`esercizioId` è quello del catalogo del server**, e il catalogo **resta
/// sul server**: `exercises` è roba condivisa, non è di nessuno
/// (`plan_tutto_sul_telefono.md` §2.2). 💡 Il nome si copia qui accanto perché
/// lo storico si deve poter leggere anche senza rete.
@DataClassName('SerieSeduta')
class SerieDelleSedute extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// L'`id` **locale** della seduta: qui il legame è interno al telefono.
  IntColumn get sedutaId => integer().references(
    SeduteAllenamento,
    #id,
    onDelete: KeyAction.cascade,
  )();

  IntColumn get esercizioId => integer()();
  TextColumn get nomeEsercizio => text()();

  /// Il MET dell'esercizio, **copiato al momento della serie** — FASE 11.2.
  ///
  /// ══ 🚨 SI COPIA, NON SI RISOLVE ═══════════════════════════════════════
  ///
  /// Il catalogo degli esercizi **resta sul server** (`plan_tutto_sul_telefono.md`
  /// §2.2): è roba condivisa, non è di nessuno. ⚠️ Ma il calcolo delle calorie
  /// gira sul telefono, e deve funzionare **senza rete** — un ricalcolo che
  /// aspetta il catalogo è un ricalcolo che non avviene in palestra.
  ///
  /// 💡 E c'è la ragione migliore: se domani il MET di un esercizio venisse
  /// corretto nel catalogo, le sedute già fatte **non devono cambiare numero**.
  /// Lo storico deve continuare a dire quello che diceva allora. È la stessa
  /// scelta di [nomeEsercizio].
  ///
  /// ⛔ `null` per l'esercizio che non ce l'ha (1 su 121) e per quelli scritti a
  /// mano dalle palestre: allora vince il ripiego di `CalorieAllenamento.met`.
  RealColumn get met => real().nullable()();

  IntColumn get numero => integer()();
  IntColumn get ripetizioni => integer().nullable()();

  /// 🚨 `real` e non intero: i manubri da 7.5 kg esistono, e arrotondarli
  /// falserebbe il volume settimanale di chi li usa.
  RealColumn get pesoKg => real().nullable()();

  IntColumn get durataSec => integer().nullable()();
  IntColumn get riposoSec => integer().nullable()();

  DateTimeColumn get fattaIl => dateTime().nullable()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {sedutaId, esercizioId, numero},
  ];
}

/// Le calorie bruciate **dichiarate a mano** per un giorno — FASE 11.1.
///
/// 🚨 **È una dichiarazione complessiva, non un contributo**: «oggi ho bruciato
/// 800». ⚠️ Sommarla alle sedute raddoppierebbe la giornata di chi corregge il
/// numero dopo essersi allenato — è la stessa regola che il server applicava in
/// `WorkoutCalorieService::dailyBurned()`, e va **trasportata**, non
/// reinventata.
@DataClassName('BruciatoDichiarato')
class BruciateDichiarate extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Il giorno locale, a mezzanotte.
  ///
  /// ⚠️ Un `DateTime` e non una stringa `yyyy-mm-dd`: il resto dell'archivio
  /// usa `DateTime` per i giorni, e mescolare due convenzioni nello stesso
  /// database è il modo per confrontare una data con un testo e non accorgersene.
  DateTimeColumn get giorno => dateTime().unique()();

  IntColumn get kcal => integer()();

  /// Se questa riga è **arrivata dal server** col trasloco — FASE 11.3.
  ///
  /// ══ 🚨 SERVE A CONTARE LA COSA GIUSTA ═══════════════════════════════════
  ///
  /// ⚠️ `conteggiDelTrasloco()` deve dire al server **quante delle sue righe**
  /// sono arrivate, non quante righe ci sono in tutto sul telefono. 🚨 Dalla
  /// FASE 11.4 in poi il player scrive in locale: una dichiarazione fatta
  /// **prima** di aver traslocato farebbe sballare il conteggio, il server
  /// risponderebbe `409 conteggi_diversi`, e quella persona non riuscirebbe
  /// **mai più** a confermare — bloccando anche la caduta delle tabelle (11.6).
  ///
  /// 💡 Le sedute questo problema non ce l'hanno: hanno già `idServer`.
  BoolColumn get daServer => boolean().withDefault(const Constant(false))();

  // 💡 `giorno` ha già il suo `.unique()`: niente `uniqueKeys`.
}
