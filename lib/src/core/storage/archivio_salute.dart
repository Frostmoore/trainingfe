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
  ],
)
class ArchivioSalute extends _$ArchivioSalute {
  ArchivioSalute() : super(_apri());

  /// Per i test: un archivio in memoria, che non tocca il disco.
  ArchivioSalute.inMemoria() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 7;

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

    await batch((b) => b.insertAll(
          lettureSalute,
          buone.map(_companionLettura).toList(),
          mode: InsertMode.insertOrIgnore,
        ));

    return buone.length;
  }

  /// Scrive i campioni del sonno, senza duplicare su `(fonte, iniziatoIl)`.
  Future<int> scriviCampioniSonno(List<CampioneSonno> campioni) async {
    if (campioni.isEmpty) return 0;

    await batch((b) => b.insertAll(
          campioniSonno,
          campioni.map(_companionCampione).toList(),
          mode: InsertMode.insertOrIgnore,
        ));

    return campioni.length;
  }

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
  LettureSaluteCompanion _companionLettura(LetturaSalute l) => LettureSaluteCompanion.insert(
        fonte: l.fonte,
        metrica: l.metrica,
        misurataIl: l.misurataIl,
        giorno: l.giorno,
        valore: l.valore,
      );

  CampioniSonnoCompanion _companionCampione(CampioneSonno c) => CampioniSonnoCompanion.insert(
        fonte: c.fonte,
        notte: c.notte,
        iniziatoIl: c.iniziatoIl,
        finitoIl: c.finitoIl,
        fase: c.fase,
      );

  // ─────────────────────────── lettura ───────────────────────────

  /// Le letture di una metrica in una finestra di giorni, **dalla più recente**.
  Future<List<LetturaSalute>> lettureRecenti(
    MetricaSalute metrica, {
    required int giorni,
  }) {
    final da = DateTime.now().subtract(Duration(days: giorni));

    return (select(lettureSalute)
          ..where((t) => t.metrica.equals(metrica.codice) & t.misurataIl.isBiggerOrEqualValue(da))
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
    final da = _soloGiorno(DateTime.now().subtract(Duration(days: giorni)));

    final righe = await customSelect(
      'SELECT giorno, AVG(valore) AS media, MIN(valore) AS minimo, '
      'MAX(valore) AS massimo, COUNT(*) AS quante '
      'FROM letture_salute WHERE metrica = ?1 AND giorno >= ?2 '
      'GROUP BY giorno ORDER BY giorno ASC',
      variables: [Variable.withString(metrica.codice), Variable.withDateTime(da)],
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
          ..where((t) =>
              t.metrica.equals(metrica.codice) &
              t.giorno.isBiggerOrEqualValue(_soloGiorno(da)) &
              t.giorno.isSmallerOrEqualValue(_soloGiorno(a)))
          ..orderBy([(t) => OrderingTerm.asc(t.misurataIl)]))
        .get();
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
    final riga = await (select(campioniSonno)
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
    final q = select(misureCorpo)..orderBy([(t) => OrderingTerm.desc(t.giorno)]);

    if (ultimiGiorni != null) {
      final da = _soloGiorno(DateTime.now().subtract(Duration(days: ultimiGiorni)));
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

  Future<int> registraFoto(FotoProgressiCompanion foto) => into(fotoProgressi).insert(foto);

  /// La galleria, dalla più recente.
  Future<List<FotoProgresso>> galleria() {
    return (select(fotoProgressi)..orderBy([(t) => OrderingTerm.desc(t.scattataIl)])).get();
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
      final esistente = await (select(schedeRicevute)
            ..where((t) => t.origineId.equals(origineId)))
          .getSingleOrNull();

      if (esistente != null) {
        // ⚠️ Fuori ordine: una versione piu' vecchia che arriva dopo non
        // sovrascrive quella buona. Vedi `salvaPiano()`.
        if (esistente.messaggioId >= messaggioId) return false;

        await (update(schedeRicevute)..where((t) => t.id.equals(esistente.id))).write(
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
    return (select(schedeRicevute)
          ..orderBy([(t) => OrderingTerm.desc(t.ricevutaIl)]))
        .get();
  }

  /// C'è già? Serve alla chat per dire «aggiunta» invece di «aggiungi».
  Future<bool> schedaGiaSalvata(int messaggioId) async {
    final riga = await (select(schedeRicevute)
          ..where((t) => t.messaggioId.equals(messaggioId)))
        .getSingleOrNull();

    return riga != null;
  }

  /// Butta una scheda, e **ricorda che e' stata buttata** — G8.10.
  Future<void> dimenticaScheda(int id) async {
    final riga = await (select(schedeRicevute)..where((t) => t.id.equals(id)))
        .getSingleOrNull();

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
      final esistente = await (select(pianiRicevuti)
            ..where((t) => t.origineId.equals(origineId)))
          .getSingleOrNull();

      if (esistente != null) {
        if (esistente.messaggioId >= messaggioId) return false;

        await (update(pianiRicevuti)..where((t) => t.id.equals(esistente.id))).write(
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

  Future<List<PianoRicevuto>> piani() {
    return (select(pianiRicevuti)
          ..orderBy([(t) => OrderingTerm.desc(t.ricevutaIl)]))
        .get();
  }

  Future<bool> pianoGiaSalvato(int messaggioId) async {
    final riga = await (select(pianiRicevuti)
          ..where((t) => t.messaggioId.equals(messaggioId)))
        .getSingleOrNull();

    return riga != null;
  }

  /// Butta un piano, e **ricorda che e' stato buttato** — G8.10.
  ///
  /// 🚨 Senza la seconda meta', il salvataggio automatico glielo rimetterebbe
  /// davanti al messaggio successivo. Buttare e' una decisione.
  Future<void> dimenticaPiano(int id) async {
    final riga = await (select(pianiRicevuti)..where((t) => t.id.equals(id)))
        .getSingleOrNull();

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
    final riga = await (select(contenutiRifiutati)
          ..where((t) => t.origineId.equals(origineId)))
        .getSingleOrNull();

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
