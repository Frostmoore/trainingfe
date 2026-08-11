import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../features/health/dati_salute.dart';

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
@DriftDatabase(tables: [LettureSalute, CampioniSonno, MisureCorpo, FotoProgressi])
class ArchivioSalute extends _$ArchivioSalute {
  ArchivioSalute() : super(_apri());

  /// Per i test: un archivio in memoria, che non tocca il disco.
  ArchivioSalute.inMemoria() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, da, a) async {
          // v1 → v2 (S5.2): peso e misure escono dal server e arrivano qui.
          if (da < 2) await m.createTable(misureCorpo);

          // v2 → v3 (S5.3): e le foto dei progressi con loro.
          if (da < 3) await m.createTable(fotoProgressi);
        },
      );

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
    });
  }

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
