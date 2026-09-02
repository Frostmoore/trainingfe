import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../features/health/dati_salute.dart';
import '../../features/health/sessioni_di_sonno.dart';
import '../../features/training/data/progressione.dart';
import '../../features/training/data/storia_della_scheda.dart';

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
    PianiRicevuti,
    ContenutiRifiutati,
    AllenamentiDaOrologio,
    SeduteAllenamento,
    SerieDelleSedute,
    SettimanaProgrammata,
    AnalisiDelleSchede,
    VersioniDelleSchede,
    BruciateDichiarate,
    SchedeSulTelefono,
    VociDiario,
    PreferitiCibo,
  ],
)
class ArchivioSalute extends _$ArchivioSalute {
  ArchivioSalute() : super(_apri());

  /// Per i test: un archivio in memoria, che non tocca il disco.
  ArchivioSalute.inMemoria() : super(NativeDatabase.memory());

  /// Per i test: un archivio **su un database che c'è già**.
  ///
  /// 🚨 Serve a provare le **migrazioni**, e non c'è altro modo di provarle:
  /// `inMemoria()` parte sempre da vuoto, cioè dall'unico caso in cui
  /// `onUpgrade` non gira mai. ⚠️ È lo scenario di chi aggiorna l'app con i
  /// dati dentro — cioè di tutti tranne noi.
  ArchivioSalute.su(super.e);

  /// 🏷️ Scritta da una persona, dentro l'app. ⛔ **Non si sovrascrive mai.**
  static const origineManuale = 'manuale';

  /// 🏷️ Arrivata da Health Connect / Apple Health.
  ///
  /// ⚠️ **Non dice quale app**: `sourceId` arriva vuoto (misurato il 30/08), e
  /// una frase che promette di sapere quale bilancia è una frase che mente.
  static const origineSalute = 'salute';

  @override
  int get schemaVersion => 27;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, da, a) async {
      // v1 → v2 (S5.2): peso e misure escono dal server e arrivano qui.
      if (da < 2) await m.createTable(misureCorpo);

      // v2 → v3 (S5.3): e le foto dei progressi con loro.
      if (da < 3) await m.createTable(fotoProgressi);

      /*
       * v3 → v4 (S7.4): le schede ricevute dal trainer via chat.
       *
       * ⛔ **La tabella non esiste più**: la v15 l'ha fusa dentro
       * `schedeSulTelefono`. Ma questo passo deve restare **eseguibile**, e con
       * l'SQL scritto a mano invece di `m.createTable`: chi aggiorna da una
       * versione anteriore alla 15 passa di qui, e il passo che fonde legge da
       * questa tabella. 🚨 Cancellare i passi vecchi perché «tanto la tabella
       * non c'è più» vuol dire che chi non ha ancora aggiornato non arriva
       * **mai** alla v15 — l'aggiornamento gli esplode a metà strada.
       */
      if (da < 4) {
        await customStatement(
          'CREATE TABLE IF NOT EXISTS schede_ricevute ('
          'id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
          'messaggio_id INTEGER NOT NULL UNIQUE, '
          'mittente_id INTEGER NOT NULL, '
          'nome TEXT NOT NULL, '
          'scheda TEXT NOT NULL, '
          'ricevuta_il INTEGER NOT NULL)',
        );
      }

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
        // ⚠️ A mano, per la stessa ragione del passo `da < 4` qui sopra.
        await customStatement(
          'ALTER TABLE schede_ricevute ADD COLUMN origine_id TEXT',
        );
        await customStatement(
          'ALTER TABLE schede_ricevute ADD COLUMN aggiornato_il INTEGER',
        );
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

      /*
       * v12 → v13 (3b-B.16): le schede del server vivono sul telefono.
       *
       * 📌 *«tutto deve stare sul telefono … perché potrei non avere rete
       * quando mi alleno»*.
       *
       * ⚠️ **La tabella nasce vuota, e va bene**: la prima sincronizzazione la
       * riempie. ⛔ Provare a precaricarla qui vorrebbe dire fare una chiamata
       * di rete dentro una migrazione — cioè bloccare l'avvio dell'app su una
       * cosa che può non rispondere.
       *
       * 💡 Nel backup ci finisce **da sola**: `esportaPerBackup()` enumera
       * `allTables`, non un elenco scritto a mano.
       */
      if (da < 13) await m.createTable(schedeSulTelefono);

      /*
       * v13 -> v14 (3b-B.17, poche ore dopo): niente piu' sincronizzazione.
       *
       * 📌 *«Basta, niente server, sticazzi crea solo problemi»*.
       *
       * ⛔ La tabella aveva quattro colonne che servivano a far convivere due
       * copie della stessa scheda — il timbro del server, quando era stata
       * toccata qui, la copia che aveva perso un conflitto e quando. Di copie
       * ce n'e' **una**: quelle colonne non hanno piu' niente da dire.
       *
       * ⚠️ Si ricrea invece di alterare: la v13 e' vissuta **poche ore** e su un
       * telefono solo, e quello che c'era dentro lo rimette l'importazione.
       */
      if (da < 14) {
        await m.deleteTable('schede_sul_telefono');
        await m.createTable(schedeSulTelefono);
      }

      /*
       * ══ 🗃️ v14 → v15 (3b-B.17.6, 25/08/2026): UN ARCHIVIO SOLO ═══════════
       *
       * 📌 *«Che vuol dire stanno in una seconda tabella locale? Uniamole»*.
       *
       * ⛔ **Non è un riordino estetico.** Le schede della chat stavano in
       * `SchedeRicevute` e quelle scese dal server in `SchedeSulTelefono`, ma
       * l'elenco delle schede ne leggeva **una sola**: una scheda ricevuta dal
       * trainer via chat non compariva fra le proprie, e non si poteva né
       * allenarcisi né assegnarla a un allenamento del polso. Due posti per la
       * stessa cosa è esattamente come è cominciato il disastro del 24/08.
       *
       * ⚠️ **Si migra invece di droppare**, e la differenza conta: le schede
       * scese dal server non tornerebbero da sole. L'importazione di
       * `PortaGiuLeSchede` gira **una volta per telefono** e il suo segno sta in
       * `LocalCache`, che una migrazione del database non vede — buttare qui le
       * righe vorrebbe dire perdere Giorno 1, 2 e 3 per sempre.
       *
       * 💡 `alterTable` ricrea la tabella dalla definizione Dart e ricopia i
       * dati: è così che `id` diventa `autoIncrement` senza perdere gli id già
       * assegnati, a cui punta `AllenamentiDaOrologio.schedaAssegnata`.
       */
      if (da < 15) {
        await m.alterTable(
          TableMigration(
            schedeSulTelefono,
            newColumns: [schedeSulTelefono.origine],
            columnTransformer: {
              // 💡 Il segno dell'id diceva già da dove veniva: qui diventa una
              // colonna, che lo dice ad alta voce.
              schedeSulTelefono.origine: const CustomExpression<String>(
                "CASE WHEN mia THEN 'mia' ELSE 'server' END",
              ),
              schedeSulTelefono.idOrigine: const CustomExpression<int>(
                'CASE WHEN id > 0 THEN id ELSE NULL END',
              ),
              schedeSulTelefono.origineIdStabile:
                  const CustomExpression<String>('NULL'),

              /*
               * ══ 🚨 OGNI COLONNA NUOVA VA DICHIARATA ANCHE QUI ═════════════
               *
               * ⛔ **Questo passo non è finito il giorno in cui è stato
               * scritto.** `alterTable` ricostruisce la tabella dalla
               * definizione Dart di **oggi** e ci copia dentro i dati della
               * vecchia: una colonna aggiunta dopo esiste nella definizione ma
               * **non** nella tabella da cui si copia, e la copia fallisce con
               * *«no such column»*.
               *
               * 🚨 Chi aggiunge una colonna a `SchedeSulTelefono` deve
               * aggiungerne una riga qui, o l'aggiornamento si ferma a metà —
               * **sul telefono di chi viene da una v14**, mai sul nostro che
               * installa da zero. È successo con `creataIl` il 25/08, e l'ha
               * trovato il test della migrazione.
               *
               * 💡 `NULL` e non `aggiornata_il`: una scheda che c'era prima una
               * data di nascita non ce l'ha, e inventargliela vorrebbe dire
               * dare a tutte le vecchie la stessa età.
               */
              schedeSulTelefono.creataIl: const CustomExpression<DateTime>(
                'NULL',
              ),
            },
          ),
        );

        /*
         * ⚠️ **`ricevuta_il` se non è mai stata corretta**: `aggiornato_il` è
         * nullable, e una scheda mai ricorretta dal trainer ce l'ha a `NULL`.
         * Senza il `COALESCE` finirebbe in cima all'elenco (o in fondo) a
         * seconda di come SQLite ordina i nulli — cioè a caso.
         */
        await customStatement(
          'INSERT INTO schede_sul_telefono '
          '(nome, scheda, aggiornata_il, mia, origine, id_origine, origine_id_stabile) '
          "SELECT nome, scheda, COALESCE(aggiornato_il, ricevuta_il), 0, 'chat', "
          'messaggio_id, origine_id FROM schede_ricevute',
        );

        await m.deleteTable('schede_ricevute');
      }

      /*
       * ⚠️ v15 → v16 (3b-B.20.5): il tipo dichiarato a mano.
       *
       * 📌 *«voglio poterci assegnare anche un tipo di allenamento diverso dalla
       * scheda»*.
       *
       * 💡 Una colonna **accanto** a `tipo`, non al suo posto: quello lo scrive
       * l'orologio, questo lo scrive una persona, e schiacciarli su una casella
       * sola vorrebbe dire che a ogni risincronizzazione si contendono il
       * campo. 🚨 Nasce vuota, ed è giusto: nessuno ha ancora dichiarato niente.
       */
      if (da < 16) {
        await m.addColumn(
          allenamentiDaOrologio,
          allenamentiDaOrologio.tipoScelto,
        );
      }

      /*
       * 📸 v16 → v17 (3b-B.20.8): la foto di un allenamento del polso.
       *
       * 📌 *«Anche nella schermata di allenamento con orologio devo poter
       * aggiungere una foto»*.
       *
       * 🚨 Una colonna **nuova**, non `sessioneId` con un id negativo: gli id
       * firmati sono la convenzione che B.17.6 ha appena tolto dalle schede.
       */
      if (da < 17) {
        await m.addColumn(fotoProgressi, fotoProgressi.allenamentoOrologioId);
      }

      /*
       * 🔥 v17 → v18 (3b-C.4): le calorie di un allenamento del polso si
       * possono correggere, come quelle di una seduta dell'app.
       */
      if (da < 18) {
        await m.addColumn(
          allenamentiDaOrologio,
          allenamentiDaOrologio.kcalCorrette,
        );
      }

      /*
       * 📅 v18 → v19 (3b-C.6): quando è nata una scheda.
       *
       * ⚠️ **Resta vuota per quelle che c'erano già**, e va bene: chi legge cade
       * su `aggiornataIl`. 🚨 Riempirla con `now()` darebbe a tutte le schede
       * vecchie la stessa età, e l'ordine «le ultime tre» diventerebbe casuale
       * proprio per chi ne ha di più.
       */
      if (da < 19) {
        /*
         * ══ 🚨 «SE NON C'È GIÀ», E NON È PRUDENZA GENERICA ══════════════════
         *
         * ⛔ **`addColumn` qui esplodeva davvero**, e non solo nel test. Il
         * passo v14 → v15 usa `m.alterTable`, che **ricostruisce la tabella
         * dalla definizione Dart di OGGI** — cioè con dentro `creataIl`. Chi
         * aggiorna da una v14 arriva quindi alla v19 con la colonna già
         * presente, e `ALTER TABLE ADD COLUMN` su una colonna che esiste è un
         * errore SQL: l'aggiornamento si ferma a metà.
         *
         * 🚨 **È la trappola di ogni `alterTable`**: da quel passo in poi, ogni
         * colonna nuova su quella tabella nasce «già fatta» per chi viene da
         * prima e «da fare» per chi viene da dopo. Chi aggiunge una colonna a
         * `SchedeSulTelefono` deve passare di qui.
         *
         * 💡 L'ha trovata il test della migrazione, che parte da un database
         * v14 vero. Senza, sarebbe esplosa sul telefono di chi aggiorna — mai
         * sul nostro, che installa da zero.
         */
        final colonne = await customSelect(
          'PRAGMA table_info(schede_sul_telefono)',
        ).get();

        final ceGia = colonne.any((r) => r.read<String>('name') == 'creata_il');

        if (!ceGia) {
          await m.addColumn(schedeSulTelefono, schedeSulTelefono.creataIl);
        }
      }

      /*
       * 🏃 v19 → v20 (3b-G.7): la spunta «conta come extra», sulle sedute del
       * polso e su quelle dell'app.
       *
       * ⚠️ Due `addColumn` e non un `alterTable`: aggiungere una colonna con un
       * valore di serie non ha bisogno di ricostruire la tabella — e
       * ricostruirla e' il passo che nel v14 → v15 ha lasciato la trappola
       * descritta qui sopra.
       *
       * 💡 Nessuna delle due tabelle e' mai passata da un `alterTable`, quindi
       * qui il controllo «se non c'e' gia'» non serve.
       */
      if (da < 20) {
        await m.addColumn(
          allenamentiDaOrologio,
          allenamentiDaOrologio.contaComeExtra,
        );
        await m.addColumn(seduteAllenamento, seduteAllenamento.contaComeExtra);
      }

      /*
       * 📅 v20 → v21 (3b-I.B): la settimana programmata.
       *
       * 💡 Tabella nuova, quindi `createTable` e basta: non c'e' niente da
       * convertire, e chi aggiorna si trova sette caselle vuote — che e'
       * esattamente lo stato «non ho ancora programmato niente».
       */
      if (da < 21) {
        await m.createTable(settimanaProgrammata);
      }

      /*
       * v21 → v22 (3b-I.A): l'analisi della progressione, scritta dall'AI.
       *
       * 🚨 **Una tabella e non `SharedPreferences`.** Le preferenze sono un
       * file **in chiaro** — sta scritto in `LocalCache` — e qui dentro
       * finiscono frasi che parlano di quanto solleva una persona. ⛔ Non è
       * roba da lasciare leggibile a chiunque prenda in mano il telefono.
       *
       * 💡 E così entra nel backup da sola: `esportaPerBackup()` enumera
       * `allTables`, e questo è il motivo per cui l'elenco non si scrive a mano.
       */
      if (da < 22) {
        await m.createTable(analisiDelleSchede);
      }

      /*
       * ══ 📐 v22 → v23 (3b-I.E): le versioni della scheda ═══════════════════
       *
       * 📌 *«ci deve essere qualcosa che tiene traccia del modo in cui cambia la
       * scheda nel corso del tempo»*.
       *
       * ── ⛔ E `analisiDelleSchede` si rifà, invece di essere aggiornata ─────
       *
       * 🚨 **La colonna si chiamava `scheda_server_id` e teneva un id LOCALE.**
       * `schedeUniteProvider` costruisce ogni scheda con `'id': r.id`, cioè con
       * l'id di `SchedeSulTelefono`: quel nome era sbagliato dal giorno in cui
       * l'ho scritto, e con una tabella nuova che si aggancia allo stesso id
       * sarebbe diventato **due posti che si chiamano diversamente per la stessa
       * cosa**.
       *
       * 💡 Si può buttare **perché è una cache**: l'analisi si rigenera. ⚠️ Costa
       * un gettone a chi ce l'aveva, ed è l'unica ragione per cui vale la pena
       * dirlo qui invece di farlo in silenzio.
       */
      if (da < 23) {
        await m.createTable(versioniDelleSchede);

        await customStatement('DROP TABLE IF EXISTS analisi_delle_schede');
        await m.createTable(analisiDelleSchede);
      }

      /*
       * ══ v23 → v24 (3b-I.F): il riassunto di tutta la scheda ═══════════════
       *
       * 💡 **Una colonna e non una tabella**: è una frase sola, che nasce e
       * muore con l'analisi di cui fa parte. ⚠️ Nullable, perché le analisi già
       * scritte non ce l'hanno — e una stringa vuota direbbe «il modello non ha
       * trovato niente», che è un'altra cosa.
       *
       * ── 🚨 `da >= 23`, E NON È UNA CONDIZIONE DI TROPPO ──────────────────
       *
       * ⛔ **`m.createTable` crea sempre la forma di OGGI**, non quella che la
       * tabella aveva a quella versione. Chi arriva dalla v14 passa dal `da <
       * 23`, che ricrea `analisiDelleSchede` — e se la ritrova **già con questa
       * colonna**. Un `addColumn` subito dopo esplode con `duplicate column
       * name: riassunto`, e l'aggiornamento si spezza a metà.
       *
       * ⚠️ **Chi invece è già alla v23** — chi ha installato l'app fra le due
       * versioni — la colonna non ce l'ha, e per lui l'`addColumn` serve
       * davvero. 💡 Sono due strade diverse verso la stessa forma, ed è il caso
       * normale ogni volta che un passo *ricrea* una tabella che un passo
       * successivo *modifica*.
       *
       * 🚨 L'ha trovato `migrazione_schede_unite_test.dart`, che parte dalla
       * v14: senza quel test il difetto si sarebbe visto solo sul telefono di
       * chi aggiorna da lontano — cioè mai sui nostri.
       */
      if (da < 24 && da >= 23) {
        await m.addColumn(analisiDelleSchede, analisiDelleSchede.riassunto);
      }

      /*
       * ══ ⚖️ v24 → v25 (3b-W): la bilancia scrive nelle misure ═════════════
       *
       * Due colonne su `misureCorpo`: la **massa magra**, quando una bilancia
       * la manda, e la **provenienza**, che serve a non sovrascrivere quello
       * che una persona ha scritto a mano. Il perché per esteso sta sulle due
       * colonne.
       *
       * ── 🚨 `da >= 2`, E NON È UNA CONDIZIONE DI TROPPO ──────────────────
       *
       * ⛔ È la stessa trappola del passo v23 → v24, e per la stessa ragione:
       * il passo `da < 2` fa `m.createTable(misureCorpo)`, e `createTable`
       * crea sempre la forma **di oggi** — cioè già con queste due colonne.
       * Chi arriva dalla v1 se le ritroverebbe, e un `addColumn` subito dopo
       * esploderebbe con `duplicate column name`.
       *
       * ⚠️ Chi invece è già alla v2 o oltre non ce le ha, e per lui
       * l'`addColumn` serve davvero. 💡 Due strade verso la stessa forma.
       */
      if (da < 25 && da >= 2) {
        await m.addColumn(misureCorpo, misureCorpo.massaMagraKg);
        await m.addColumn(misureCorpo, misureCorpo.origine);
      }

      /*
       * v25 → v26 (Parte I, I1): **il diario alimentare arriva sul telefono**.
       *
       * ⚠️ **Le tabelle si creano vuote, e per ora nessuno ci scrive.** Il
       * traslocо dei dati è I3, e collegarlo all'app è il passo dopo: creare lo
       * schema e cambiare i lettori nello stesso giro vorrebbe dire un'app che
       * legge di qua e scrive di là, cioè pasti che spariscono.
       *
       * 💡 Finiscono nel backup **da sole**: `esportaPerBackup()` enumera
       * `allTables`, e questo è il motivo per cui l'elenco non si scrive a mano
       * (R4).
       */
      if (da < 26) {
        await m.createTable(vociDiario);
        await m.createTable(preferitiCibo);
      }

      /*
       * v26 → v27 (I2.5): i preferiti si ricordano **quante volte** sono stati
       * usati.
       *
       * ⛔ Erano rimasti fuori dalla v26, e sarebbe stato un difetto silenzioso:
       * l'elenco dei preferiti c'è tutto, ma nell'ordine sbagliato — e nessuno
       * guarda un elenco per accorgersi che manca un criterio.
       *
       * ⚠️ Solo per chi è **già** alla v26: chi arriva da prima le trova nella
       * `createTable` qui sopra, e un `addColumn` gli darebbe «duplicate column
       * name». È la stessa forma del passo `da < 25 && da >= 2`.
       */
      if (da < 27 && da >= 26) {
        await m.addColumn(preferitiCibo, preferitiCibo.volteUsato);
        await m.addColumn(preferitiCibo, preferitiCibo.usatoIl);
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

  /// La settimana programmata, sette caselle da lunedì — 3b-I.B.
  ///
  /// ⚠️ **Sempre sette**, anche se nel database ce ne sono meno: chi la disegna
  /// non deve avere un caso «la riga di giovedì non esiste» diverso da «giovedì
  /// è riposo». 💡 Sono la stessa cosa per chi guarda, e devono esserlo anche
  /// per chi scrive il widget.
  Future<List<int?>> settimanaDelPiano() async {
    final righe = await select(settimanaProgrammata).get();
    final fuori = List<int?>.filled(7, null);

    for (final r in righe) {
      if (r.giorno >= 1 && r.giorno <= 7) fuori[r.giorno - 1] = r.schedaLocale;
    }

    return fuori;
  }

  /// Riscrive la settimana intera.
  ///
  /// 🚨 **Tutta insieme, in una transazione.** Salvarla giorno per giorno
  /// vorrebbe dire che un'interruzione a metà lascia mezza settimana vecchia e
  /// mezza nuova — e nessuno se ne accorgerebbe, perché entrambe sono
  /// settimane plausibili.
  Future<void> scriviLaSettimana(List<int?> giorni) => transaction(() async {
    await delete(settimanaProgrammata).go();

    for (var i = 0; i < giorni.length && i < 7; i++) {
      await into(settimanaProgrammata).insert(
        SettimanaProgrammataCompanion.insert(
          giorno: Value(i + 1),
          schedaLocale: Value(giorni[i]),
        ),
      );
    }
  });

  /// La storia di ogni esercizio di una scheda — 3b-I.A, 27/08/2026.
  ///
  /// ══ 🚨 UNA SERIE PER SEDUTA, NON TUTTE ════════════════════════════════
  ///
  /// Di ogni seduta si tiene la **serie migliore** — il carico più alto, e a
  /// pari carico le ripetizioni più alte. ⛔ Mandare tutte le serie di otto
  /// sedute per quaranta esercizi vorrebbe dire una richiesta da migliaia di
  /// numeri per farne uscire quaranta righe: si pagherebbe il contesto, non la
  /// risposta.
  ///
  /// 💡 Ed è anche **la cosa giusta da guardare**: «sono migliorato» si legge
  /// sulla serie di punta, non sulla media di un riscaldamento e di un
  /// cedimento.
  ///
  /// ⚠️ **Solo le sedute finite.** Una seduta ancora aperta (`finitaIl == null`)
  /// ha le serie a metà: entrerebbe come un calo che non è successo.
  ///
  /// ══ ⚠️ IL FILTRO È SULL'ID **LOCALE**, E IL NOME DELLA COLONNA MENTE ═══
  ///
  /// 🚨 `sedute_allenamento.scheda_server_id` si chiama così dai tempi in cui le
  /// schede stavano sul server, ma quello che ci finisce dentro è
  /// `SessionActions.start(planId: …)` — cioè `WorkoutPlan.id`, che
  /// `schedeUniteProvider` riempie con **l'id locale**.
  ///
  /// ⛔ Non è stata rinominata perché la usa il player e la scrive ogni seduta:
  /// una rinomina lì è una migrazione con dentro tutto lo storico degli
  /// allenamenti, per un guadagno di sola leggibilità. 💡 Questo commento è il
  /// compromesso — e l'altra tabella nata dopo ([AnalisiDelleSchede]) il nome
  /// giusto ce l'ha.
  ///
  /// Sposta le serie già registrate dall'esercizio vecchio al nuovo — 3b-O.
  ///
  /// ══ 🚨 È QUI CHE «SENZA PERDERE NULLA» DIVENTA VERO ═══════════════════
  ///
  /// 📌 *«vorrei che gli esercizi che ho io nelle schede siano quelli che
  /// abbiamo nel database. Senza farmi perdere nulla, naturalmente»*.
  ///
  /// ⛔ Il server può far puntare le schede a un altro esercizio, ma **lo
  /// storico degli allenamenti sta qui**, e usa l'id vecchio. Senza questa
  /// riscrittura le serie resterebbero sul telefono e non le troverebbe più
  /// nessuno: non cancellate — **orfane**, che è peggio, perché la
  /// progressione ripartirebbe da zero senza dire perché.
  ///
  /// ── 💡 Perché è ripetibile ────────────────────────────────────────────
  ///
  /// Gira a ogni lettura del catalogo, e la seconda volta non trova più
  /// niente da spostare. ⚠️ Un'esecuzione «una sola volta» avrebbe avuto
  /// bisogno di ricordarsi di averla fatta — cioè di un flag che, se si
  /// perde, perde con sé lo storico.
  ///
  /// ── ⚠️ Perché ogni rinvio ha il suo `try` ─────────────────────────────
  ///
  /// `SerieDelleSedute` è unica su `{seduta, esercizio, numero}`. 🚨 Se due
  /// esercizi vecchi finissero sullo **stesso** nuovo, e fossero stati fatti
  /// nella stessa seduta con lo stesso numero di serie, la riscrittura
  /// sbatterebbe contro il vincolo. ⛔ Con una transazione sola, quel caso
  /// farebbe fallire **tutti** gli spostamenti, compresi quelli giusti.
  ///
  /// @return quante righe sono state spostate
  Future<int> applicaLeRiconciliazioni(
    Map<int, int> rinvii, {
    Map<int, String> nomi = const {},
  }) async {
    if (rinvii.isEmpty) return 0;

    var spostate = 0;

    spostate += await _riscriviLeSchede(rinvii, nomi);

    for (final rinvio in rinvii.entries) {
      // ⛔ Un rinvio su sé stesso girerebbe a vuoto a ogni avvio.
      if (rinvio.key == rinvio.value) continue;

      try {
        spostate +=
            await (update(serieDelleSedute)
                  ..where((t) => t.esercizioId.equals(rinvio.key)))
                .write(
                  SerieDelleSeduteCompanion(esercizioId: Value(rinvio.value)),
                );
      } on Object catch (e) {
        debugPrint(
          'riconciliazione ${rinvio.key}→${rinvio.value} non riuscita: $e',
        );
      }
    }

    if (spostate > 0) {
      debugPrint('riconciliazioni: toccate $spostate righe');
    }

    return spostate;
  }

  /// Riscrive gli id dentro le **schede salvate sul telefono** — 3b-Q.
  ///
  /// ══ 🚨 SENZA QUESTO, LA FUSIONE NON SI VEDE PROPRIO ═══════════════════
  ///
  /// ⛔ Le schede sono scese dal server **una volta sola** (3b-B.17): da
  /// allora *«di schede il server non ne sa più niente»*, e la copia che conta
  /// è questa. 🚨 Ripuntare `plan_exercises` sul server non cambia **niente**
  /// di quello che si vede: quella tabella nessuno la rilegge più.
  ///
  /// ⚠️ È il difetto che si è visto solo **guardando il telefono** dopo la
  /// fusione: sul server tutto a posto, sullo schermo i nomi vecchi.
  ///
  /// ── ⚠️ Perché riscrive anche il nome ──────────────────────────────────
  ///
  /// 📌 *«vorrei che gli esercizi che ho io nelle schede siano quelli che
  /// abbiamo nel database»*. Il nome scritto nella scheda **vince** su quello
  /// del catalogo (3b-D.17): lasciandolo, si vedrebbe l'etichetta vecchia
  /// sopra il disegno nuovo. 💡 Il nome si cambia **solo** se il catalogo ne
  /// conosce uno per la destinazione: senza, si tiene quello che c'è.
  ///
  /// ── 💡 Perché la passeggiata è ricorsiva ──────────────────────────────
  ///
  /// L'id sta in `exercise_id`, ma nelle schede vecchie può stare in
  /// `exercise.id`, e gli esercizi si annidano dentro `days` e dentro
  /// `alternatives`. ⛔ Una passeggiata scritta sulla forma di oggi
  /// mancherebbe le alternative senza dirlo.
  Future<int> _riscriviLeSchede(
    Map<int, int> rinvii,
    Map<int, String> nomi,
  ) async {
    var toccate = 0;

    for (final riga in await select(schedeSulTelefono).get()) {
      Object? decodificata;

      try {
        decodificata = jsonDecode(riga.scheda);
      } on Object catch (e) {
        debugPrint('scheda ${riga.id} illeggibile, la lascio com\'è — $e');

        continue;
      }

      var cambiata = false;

      /*
       * ══ 🚨 SI RISCRIVE `exercise_id`, MAI UN `id` NUDO ═══════════════════
       *
       * ⛔ **Prima la regola era «`id` se l'oggetto ha anche `name`», ed era
       * sbagliata.** Nel JSON di una scheda hanno tutti e due: la scheda, il
       * giorno, e ogni riga di esercizio — dove però `id` è **la riga**, non
       * l'esercizio.
       *
       * 🚨 Bastava che l'id di una riga coincidesse con l'id vecchio di un
       * esercizio fuso e quella riga si prendeva id **e nome** di un altro
       * esercizio. Il 28/08 non è successo solo perché gli id non si
       * sovrapponevano (righe 46-113, esercizi fusi 122-147): **per fortuna,
       * non per costruzione**.
       *
       * 💡 Adesso `id` si tocca **solo** dentro l'oggetto `exercise`, che è
       * l'unico posto in cui vuol dire davvero «l'esercizio».
       */
      void passeggia(Object? nodo, {bool dentroExercise = false}) {
        if (nodo is List) {
          for (final figlio in nodo) {
            passeggia(figlio);
          }

          return;
        }

        if (nodo is! Map) return;

        void rinomina(int nuovo) {
          if (nomi[nuovo] case final nome? when nodo.containsKey('name')) {
            nodo['name'] = nome;
          }
        }

        if (nodo['exercise_id'] case final int vecchio
            when rinvii.containsKey(vecchio)) {
          nodo['exercise_id'] = rinvii[vecchio];
          cambiata = true;
          rinomina(rinvii[vecchio]!);
        }

        if (dentroExercise) {
          if (nodo['id'] case final int vecchio
              when rinvii.containsKey(vecchio)) {
            nodo['id'] = rinvii[vecchio];
            cambiata = true;
            rinomina(rinvii[vecchio]!);
          }
        }

        for (final voce in nodo.entries) {
          passeggia(voce.value, dentroExercise: voce.key == 'exercise');
        }
      }

      passeggia(decodificata);

      if (!cambiata) continue;

      await (update(schedeSulTelefono)..where((t) => t.id.equals(riga.id)))
          .write(
            SchedeSulTelefonoCompanion(scheda: Value(jsonEncode(decodificata))),
          );

      toccate++;
    }

    if (toccate > 0) {
      debugPrint('riconciliazioni: riscritte $toccate schede');
    }

    return toccate;
  }

  /// Torna, per ogni `esercizioId`, i punti **dal più vecchio al più recente**.
  Future<Map<int, List<PuntoDiProgressione>>> storiaDegliEsercizi(
    int schedaLocale, {
    int quanteSedute = 8,
  }) async {
    final righe = await customSelect(
      'SELECT s.esercizio_id AS eid, a.finita_il AS quando, '
      '       s.peso_kg AS peso, s.ripetizioni AS reps '
      '  FROM serie_delle_sedute s '
      '  JOIN sedute_allenamento a ON a.id = s.seduta_id '
      ' WHERE a.scheda_server_id = ?1 AND a.finita_il IS NOT NULL '
      ' ORDER BY a.finita_il ASC',
      variables: [Variable<int>(schedaLocale)],
      readsFrom: {serieDelleSedute, seduteAllenamento},
    ).get();

    /*
     * ⚠️ **Il raggruppamento si fa qui e non in SQL.** Un `GROUP BY` con un
     * `MAX(peso)` non porta con sé le ripetizioni di *quella* riga: SQLite
     * risponderebbe con le ripetizioni di una riga qualsiasi del gruppo, senza
     * dire niente. È il difetto che legge bene e produce un numero sbagliato.
     */
    final perEsercizio = <int, Map<int, PuntoDiProgressione>>{};

    for (final r in righe) {
      final eid = r.read<int>('eid');
      final quando = r.read<DateTime>('quando');
      final peso = r.readNullable<double>('peso');
      final reps = r.readNullable<int>('reps');

      // 💡 Una serie senza carico **e** senza ripetizioni non dice niente: è il
      // caso dell'esercizio a tempo, che qui non ha nessuna progressione da
      // raccontare.
      if (peso == null && reps == null) continue;

      final sedute = perEsercizio.putIfAbsent(eid, () => {});

      // La chiave è il giorno: due sedute nello stesso giorno restano due punti
      // solo se sono davvero due allenamenti diversi.
      final chiave = quando.millisecondsSinceEpoch;
      final prima = sedute[chiave];

      final punto = PuntoDiProgressione(
        data: quando,
        carico: peso,
        ripetizioni: reps,
      );

      if (prima == null || punto.batte(prima)) sedute[chiave] = punto;
    }

    return {
      for (final voce in perEsercizio.entries)
        voce.key: (voce.value.values.toList()
              ..sort((a, b) => a.data.compareTo(b.data)))
            // ⚠️ `takeLast`: si tengono le **ultime** sedute, non le prime.
            // Con `take()` l'analisi parlerebbe di com'era sei mesi fa.
            .reversed
            .take(quanteSedute)
            .toList()
            .reversed
            .toList(),
    };
  }

  /// L'analisi già scritta per una scheda, se c'è.
  Future<AnalisiScheda?> analisiDellaScheda(int schedaLocale) =>
      (select(analisiDelleSchede)
            ..where((t) => t.schedaLocale.equals(schedaLocale)))
          .getSingleOrNull();

  /// Scrive (o riscrive) l'analisi di una scheda.
  ///
  /// 💡 `insertOnConflictUpdate` e non `insert`: di una scheda ne esiste **una**,
  /// e una seconda riga vorrebbe dire che l'app ne mostrerebbe una a caso.
  Future<void> scriviLAnalisi(AnalisiDelleSchedeCompanion riga) =>
      into(analisiDelleSchede).insertOnConflictUpdate(riga);

  /// Le versioni di una scheda, **dalla più vecchia** — 3b-I.E, 27/08/2026.
  Future<List<VersioneDellaScheda>> versioniDellaScheda(
    int schedaLocale, {
    int quante = 12,
  }) async {
    /*
     * ══ 🚨 `id` COME SECONDO CRITERIO, E NON È PIGNOLERIA ═════════════════
     *
     * ⛔ **Due versioni possono avere lo stesso istante.** Con il solo `quando`
     * l'ordine fra loro lo decide SQLite come gli pare, e la storia di una
     * scheda si legge **al contrario** — cioè «da 12 a 8» invece di «da 8 a
     * 12».
     *
     * ⚠️ Non è un caso di laboratorio: `aggiungiScheda` scrive la versione zero
     * e una modifica subito dopo cade nello stesso millisecondo. 💡 L'ha trovato
     * il test, non lo schermo — ed è esattamente il tipo di difetto che a
     * schermo si sarebbe visto come una frase dell'AI che dice il contrario del
     * vero.
     */
    final righe =
        await (select(versioniDelleSchede)
              ..where((t) => t.schedaLocale.equals(schedaLocale))
              ..orderBy([
                (t) => OrderingTerm.desc(t.quando),
                (t) => OrderingTerm.desc(t.id),
              ])
              ..limit(quante))
            .get();

    // ⚠️ Si legge dalla più recente per prendere **le ultime** `quante`, e poi si
    // gira: chi confronta le versioni ha bisogno dell'ordine del tempo.
    return [
      for (final r in righe.reversed)
        VersioneDellaScheda(quando: r.quando, contenuto: r.contenuto),
    ];
  }

  /// Butta la storia di una scheda.
  ///
  /// 💡 Serve a **una cosa sola**: costruire nei test lo stato di una scheda
  /// nata prima della v23 — la riga c'è, la sua storia no. ⚠️ Non lo chiama
  /// nessuno in produzione, e non deve: la storia di una scheda si perde solo
  /// insieme alla scheda.
  Future<void> dimenticaLeVersioni(int schedaLocale) =>
      (delete(versioniDelleSchede)
            ..where((t) => t.schedaLocale.equals(schedaLocale)))
          .go();

  /// Registra com'è fatta una scheda **adesso**, se è cambiata.
  ///
  /// ══ 🚨 LE TRE REGOLE, E NESSUNA È UN'OTTIMIZZAZIONE ═══════════════════
  ///
  /// **1. Niente riga se l'impronta è la stessa.** `aggiornaScheda` si chiama a
  /// **ogni** modifica — è scritto nel suo docblock — e salvare due volte lo
  /// stesso contenuto (rinominare, correggere una nota) riempirebbe la tabella
  /// di versioni identiche. ⛔ E più avanti l'analisi direbbe «la scheda è
  /// cambiata» davanti a una virgola spostata.
  ///
  /// **2. Dentro [finestraDiModifica] si SOSTITUISCE.** 🚨 Chi compone una
  /// scheda salva venti volte in cinque minuti: senza questa regola una serata
  /// di lavoro diventerebbe venti versioni, e il «com'era prima» vero — quello
  /// di ieri — finirebbe sepolto in fondo. 💡 Così una sessione di modifica è
  /// **una** versione: quella finale.
  ///
  /// **3. La prima non si tocca mai.** È l'originale, ed è l'unico confronto che
  /// vale ancora fra sei mesi.
  ///
  /// ⚠️ **[quando] è quello di chi salva**, non `DateTime.now()`: se
  /// `aggiornaScheda` riceve una data — il ripristino di un backup, un test che
  /// viaggia nel tempo — la versione deve portare **quella**, o la storia
  /// risulterebbe tutta scritta nell'istante del ripristino.
  Future<void> segnaLaVersione(
    int schedaLocale,
    String scheda, {
    DateTime? quando,
  }) async {
    final impronta = improntaDellaScheda(scheda);

    final ultima =
        await (select(versioniDelleSchede)
              ..where((t) => t.schedaLocale.equals(schedaLocale))
              ..orderBy([
                (t) => OrderingTerm.desc(t.quando),
                (t) => OrderingTerm.desc(t.id),
              ])
              ..limit(1))
            .getSingleOrNull();

    if (ultima != null && ultima.impronta == impronta) return;

    final adesso = quando ?? DateTime.now();

    final quante = await (selectOnly(versioniDelleSchede)
          ..addColumns([versioniDelleSchede.id.count()])
          ..where(versioniDelleSchede.schedaLocale.equals(schedaLocale)))
        .getSingle()
        .then((r) => r.read(versioniDelleSchede.id.count()) ?? 0);

    final dentroLaFinestra =
        ultima != null &&
        quante > 1 &&
        adesso.difference(ultima.quando) < finestraDiModifica;

    if (dentroLaFinestra) {
      await (update(versioniDelleSchede)
            ..where((t) => t.id.equals(ultima.id))).write(
        VersioniDelleSchedeCompanion(
          quando: Value(adesso),
          impronta: Value(impronta),
          contenuto: Value(scheda),
        ),
      );

      return;
    }

    await into(versioniDelleSchede).insert(
      VersioniDelleSchedeCompanion.insert(
        schedaLocale: schedaLocale,
        quando: adesso,
        impronta: impronta,
        contenuto: scheda,
      ),
    );

    await _potaLeVersioni(schedaLocale);
  }

  /// ⚠️ **Tiene la prima e le ultime [quanteVersioni]**, e butta quelle in
  /// mezzo. 💡 La prima è l'originale: senza, fra un anno non ci sarebbe più
  /// niente con cui confrontare. ⛔ Quelle in mezzo invece invecchiano davvero:
  /// «com'era a marzo» non serve a nessuno se c'è aprile.
  Future<void> _potaLeVersioni(int schedaLocale) async {
    final tutte =
        await (select(versioniDelleSchede)
              ..where((t) => t.schedaLocale.equals(schedaLocale))
              ..orderBy([
                (t) => OrderingTerm.asc(t.quando),
                (t) => OrderingTerm.asc(t.id),
              ]))
            .get();

    if (tutte.length <= quanteVersioni + 1) return;

    /*
     * ══ 🚨 «LA PRIMA» È LA PRIMA **SCRITTA**, NON LA PIÙ VECCHIA DI DATA ══
     *
     * ⛔ Prima teneva `tutte.first`, cioè la più vecchia in ordine di `quando`.
     * ⚠️ Ma `quando` lo passa chi salva — il ripristino di un backup, una scheda
     * arrivata via chat con la data del messaggio — e può benissimo essere
     * **anteriore** alla versione zero. In quel caso l'originale veniva buttato
     * e al suo posto restava una versione qualsiasi che aveva solo la data più
     * bassa.
     *
     * 💡 L'`id` è l'unica cosa che dice davvero **cosa è arrivato per primo**,
     * perché lo assegna il database in ordine di scrittura.
     */
    var originale = tutte.first.id;

    for (final r in tutte) {
      if (r.id < originale) originale = r.id;
    }

    final daTenere = {
      originale,
      for (final r in tutte.skip(tutte.length - quanteVersioni)) r.id,
    };

    await (delete(versioniDelleSchede)..where(
          (t) =>
              t.schedaLocale.equals(schedaLocale) & t.id.isNotIn(daTenere),
        ))
        .go();
  }

  /// Le sedute dell'orologio **di un giorno**, per contarne le calorie —
  /// 3b-G.3, 26/08/2026.
  ///
  /// 🚨 Restituisce le **righe**, non un totale: la regola per non contare due
  /// volte lo stesso allenamento vive in `kcalDelleSedute` — che è una funzione
  /// pura e quindi si può provare — e non dentro una query.
  ///
  /// ⚠️ **Il giorno è quello in cui l'allenamento è COMINCIATO.** Una seduta a
  /// cavallo della mezzanotte conta tutta nel giorno in cui sei partito: è la
  /// stessa convenzione dello storico, e spezzarla vorrebbe dire due mezze
  /// sedute che non corrispondono a niente.
  ///
  /// 💡 `nascosto` **non** si filtra qui, come in `allenamentiDellOrologio`:
  /// filtrare alla fonte renderebbe la scelta irreversibile. Lo toglie
  /// `kcalDelleSedute`.
  Future<List<AllenamentoDaOrologio>> seduteDellOrologioDi(DateTime giorno) {
    final da = _soloGiorno(giorno);
    final a = da.add(const Duration(days: 1));

    return (select(allenamentiDaOrologio)..where(
          (t) =>
              t.iniziatoIl.isBiggerOrEqualValue(da) &
              t.iniziatoIl.isSmallerThanValue(a),
        ))
        .get();
  }

  /// Le calorie delle sedute marcate **«fuori dal solito»** di un giorno —
  /// 3b-G.7, 26/08/2026.
  ///
  /// 🚨 Serve **solo** al modello «stima», dove gli allenamenti normali sono già
  /// dentro il fattore e non si sommano. ⛔ Nel modello «misurata» questo numero
  /// non va usato: lì le sedute entrano già tutte, e sommarlo le conterebbe due
  /// volte — è il provider a saperlo, non questa query.
  ///
  /// ⚠️ Le due famiglie si sommano perché sono cose diverse: quelle del polso e
  /// quelle registrate col player. 💡 Il doppione fra le due lo toglie già
  /// `nascosto`, che è nato per quello.
  Future<int> kcalExtraDi(DateTime giorno) async {
    final da = _soloGiorno(giorno);
    final a = da.add(const Duration(days: 1));

    final dalPolso =
        await (select(allenamentiDaOrologio)..where(
              (t) =>
                  t.contaComeExtra.equals(true) &
                  t.nascosto.equals(false) &
                  t.iniziatoIl.isBiggerOrEqualValue(da) &
                  t.iniziatoIl.isSmallerThanValue(a),
            ))
            .get();

    final dallApp =
        await (select(seduteAllenamento)..where(
              (t) =>
                  t.contaComeExtra.equals(true) &
                  t.iniziataIl.isBiggerOrEqualValue(da) &
                  t.iniziataIl.isSmallerThanValue(a),
            ))
            .get();

    var totale = 0;

    for (final s in dalPolso) {
      totale += s.kcalCorrette ?? s.kcal ?? 0;
    }

    for (final s in dallApp) {
      totale += s.kcal ?? 0;
    }

    return totale;
  }

  /// Marca (o smarca) una seduta del polso come «fuori dal solito» — 3b-G.7.
  Future<void> segnaExtraDalPolso(int id, {required bool extra}) =>
      (update(allenamentiDaOrologio)..where((t) => t.id.equals(id))).write(
        AllenamentiDaOrologioCompanion(contaComeExtra: Value(extra)),
      );

  /// Marca (o smarca) una seduta dell'app come «fuori dal solito» — 3b-G.7.
  Future<void> segnaExtraDallApp(int id, {required bool extra}) =>
      (update(seduteAllenamento)..where((t) => t.id.equals(id))).write(
        SeduteAllenamentoCompanion(contaComeExtra: Value(extra)),
      );

  /// Assegna (o toglie) la scheda che questa persona dice di aver fatto.
  Future<void> assegnaSchedaAllenamento(int id, int? schedaId) =>
      (update(allenamentiDaOrologio)..where((t) => t.id.equals(id))).write(
        AllenamentiDaOrologioCompanion(schedaAssegnata: Value(schedaId)),
      );

  /// Corregge a mano le calorie di un allenamento del polso — 3b-C.4.
  ///
  /// 💡 `null` toglie la correzione e rimette in gioco quelle dell'orologio: una
  /// scelta che non si può disfare è una trappola.
  Future<void> correggiKcalAllenamento(int id, int? kcal) =>
      (update(allenamentiDaOrologio)..where((t) => t.id.equals(id))).write(
        AllenamentiDaOrologioCompanion(kcalCorrette: Value(kcal)),
      );

  /// Dichiara che tipo di allenamento era — 3b-B.20.5.
  ///
  /// 💡 `null` toglie la dichiarazione e rimette in gioco quello dell'orologio:
  /// una scelta che non si può disfare è una trappola, ed è la stessa regola di
  /// `assegnaSchedaAllenamento`.
  Future<void> dichiaraTipoAllenamento(int id, String? codice) =>
      (update(allenamentiDaOrologio)..where((t) => t.id.equals(id))).write(
        AllenamentiDaOrologioCompanion(tipoScelto: Value(codice)),
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
  /// ══ ⚠️ DAL 26/08 NON ALIMENTA PIU' L'OBIETTIVO — 3b-G.3 ════════════════
  ///
  /// Questo è il **flusso giornaliero** delle calorie attive: tutto il movimento
  /// del giorno, allenamenti compresi. ⛔ Nel modello «misurata» il movimento di
  /// tutti i giorni sta **già dentro il fattore di attività quotidiana**, quindi
  /// sommarlo lo conterebbe due volte.
  ///
  /// 💡 Le bruciate che entrano nell'obiettivo vengono da `kcalDelleSedute`.
  /// ⚠️ Questo resta perché è un dato vero e serve ai controlli netto/lordo di
  /// 3b-G.4: `totale del giorno − attive del giorno ≈ metabolismo basale`.
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

  /// L'istante in cui finisce il campione di sonno più recente — 3b-AB.
  ///
  /// ══ 🚨 PERCHÉ `finitoIl` E NON LA NOTTE ═══════════════════════════════
  ///
  /// Perché serve a rispondere a *«è successo qualcosa da quando abbiamo
  /// scritto l'ultimo consiglio?»*, e [ultimaNotteConDati] risponde con una
  /// **data a mezzanotte**.
  ///
  /// ⛔ Con quella, la notte del 30 varrebbe *30/08 00:00*: confrontata con un
  /// consiglio generato il 30 alle 09:15 risulterebbe **più vecchia**, e il
  /// sonno non farebbe mai scattere niente. 🚨 Un difetto che non dà errori:
  /// semplicemente il consiglio non parla mai di come hai dormito.
  ///
  /// 💡 `finitoIl` è invece **il momento in cui ti sei svegliato**: le 07:30 di
  /// stamattina battono le 22:00 di ieri sera, che è esattamente la risposta
  /// giusta.
  Future<DateTime?> ultimoRisveglio() async {
    final riga =
        await (select(campioniSonno)
              ..orderBy([(t) => OrderingTerm.desc(t.finitoIl)])
              ..limit(1))
            .getSingleOrNull();

    return riga?.finitoIl;
  }

  // ─────────────────────── diario alimentare (I1) ───────────────────────

  /// Le voci di un giorno, in ordine di pasto e poi di scrittura.
  ///
  /// ══ 🚨 IL GIORNO SI CONFRONTA SUL GIORNO, NON SULL'ISTANTE ═══════════
  ///
  /// `mangiatoIl` porta la **mezzanotte** del giorno scelto (è ciò che l'app
  /// manda al server da sempre), quindi un confronto `>= giorno && < domani`
  /// funziona. ⚠️ Ma non si dà per scontato: la finestra è esplicita, così il
  /// giorno che qualcuno scriverà l'ora vera questa lettura continuerà a
  /// rispondere giusto.
  Future<List<VoceDiario>> vociDelGiorno(DateTime giorno) {
    final da = _soloGiorno(giorno);
    final a = da.add(const Duration(days: 1));

    return (select(vociDiario)
          ..where((t) => t.mangiatoIl.isBiggerOrEqualValue(da))
          ..where((t) => t.mangiatoIl.isSmallerThanValue(a))
          ..orderBy([
            (t) => OrderingTerm.asc(t.mangiatoIl),
            (t) => OrderingTerm.asc(t.scrittaIl),
          ]))
        .get();
  }

  /// Le voci di un intervallo, per la settimana e per i grafici.
  ///
  /// 💡 Una lettura sola invece di una al giorno: sette query per disegnare una
  /// settimana sono sette viaggi nel database per una risposta che sta in uno.
  Future<List<VoceDiario>> vociFra(DateTime da, DateTime a) {
    final inizio = _soloGiorno(da);
    final fine = _soloGiorno(a).add(const Duration(days: 1));

    return (select(vociDiario)
          ..where((t) => t.mangiatoIl.isBiggerOrEqualValue(inizio))
          ..where((t) => t.mangiatoIl.isSmallerThanValue(fine))
          ..orderBy([(t) => OrderingTerm.asc(t.mangiatoIl)]))
        .get();
  }

  /// Quante voci ci sono in tutto. 🚨 Serve a I3: il server confronta questo
  /// numero con il suo **prima** di cancellare qualcosa.
  Future<int> quanteVociDelDiario() async {
    final riga = await (selectOnly(vociDiario)
          ..addColumns([vociDiario.id.count()]))
        .getSingle();

    return riga.read(vociDiario.id.count()) ?? 0;
  }

  /// Quando è stata scritta l'ultima voce, di qualunque giorno — I5.2.
  ///
  /// ══ 🚨 `scrittaIl`, NON `mangiatoIl` ═════════════════════════════════════
  ///
  /// ⛔ `mangiatoIl` è la **mezzanotte del giorno scelto**: chi programma la
  /// cena di domani alle 10 del mattino scriverebbe una «notizia» di domani, e
  /// chi completa ieri sera una di ieri. 💡 La domanda è *«quando è successo
  /// l'ultimo gesto»*, e la risposta è l'ora in cui la riga è nata.
  ///
  /// 🚨 Serve al secondo cancello del consiglio (3b-AB): senza, registrare un
  /// pasto non fa scattare niente — e non lo dice a nessuno, perché il consiglio
  /// resta quello di prima.
  Future<DateTime?> ultimaScritturaDelDiario() async {
    final riga = await (selectOnly(vociDiario)
          ..addColumns([vociDiario.scrittaIl.max()]))
        .getSingleOrNull();

    return riga?.read(vociDiario.scrittaIl.max());
  }

  /// Scrive una voce e torna il suo id locale.
  Future<int> scriviVoceDiario(VociDiarioCompanion voce) =>
      into(vociDiario).insert(voce);

  /// Un gruppo di scritture che vale **tutto o niente** — I2.5.
  ///
  /// 🚨 Serve a chi scrive **un pasto**: un preferito da cinque voci, o una
  /// stima confermata. ⛔ Un'interruzione a metà lascerebbe in diario mezza
  /// cena, che nei totali è un numero sbagliato **senza nessun segno che lo
  /// sia** — è la stessa ragione per cui `AiController::scriviVoci()` scriveva
  /// in transazione sul server.
  ///
  /// 💡 Esiste come metodo invece di esporre `transaction` perché chi la usa
  /// sta nel livello dei dati del diario, non dentro l'archivio.
  Future<T> tuttoOniente<T>(Future<T> Function() azione) => transaction(azione);

  /// Scrive un pacchetto di voci in un colpo solo — I3.
  ///
  /// ══ 🚨 `insertOrIgnore` SU `idSulServer`, E NON È UN DETTAGLIO ═══════
  ///
  /// La migrazione può girare **due volte**: l'app si chiude a metà, il telefono
  /// perde la rete, la persona reinstalla. ⛔ Senza questa guardia il secondo
  /// giro raddoppierebbe il diario — e nessuno se ne accorgerebbe finché non
  /// guarda le calorie di un giorno vecchio.
  ///
  /// ⚠️ Le voci **nate qui** hanno `idSulServer` a `null` e non sono toccate da
  /// questa strada: si scrivono con [scriviVoceDiario].
  Future<void> importaVociDelDiario(List<VociDiarioCompanion> voci) async {
    if (voci.isEmpty) return;

    await batch((b) => b.insertAll(vociDiario, voci, mode: InsertMode.insertOrIgnore));
  }

  Future<void> cancellaVoceDiario(int id) =>
      (delete(vociDiario)..where((t) => t.id.equals(id))).go();

  /// Una voce sola, per id locale — I2.5.
  ///
  /// 🚨 **Serve al ricalcolo della modifica**, che ha bisogno di sapere
  /// *com'era* la voce prima: il fattore grammi-per-unità si ricava da lì, e
  /// senza la riga di partenza si finirebbe per usare la tabella generica —
  /// cioè 30 g per due cucchiai di un olio che il modello aveva pesato 28.
  Future<VoceDiario?> voceDelDiario(int id) =>
      (select(vociDiario)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// ⚠️ **Scrive solo i campi presenti nel companion.** I `Value.absent()` non
  /// toccano niente: è ciò che permette di correggere la quantità senza
  /// azzerare i macro che nessuno ha nominato.
  Future<void> aggiornaVoceDiario(int id, VociDiarioCompanion voce) =>
      (update(vociDiario)..where((t) => t.id.equals(id))).write(voce);

  // ── i preferiti ────────────────────────────────────────────────────────

  /// I preferiti, **i più usati per primi** — I2.5.
  ///
  /// 🚨 È l'ordine di `FoodFavorite::scopeMostUsed()` sul server, e non è un
  /// dettaglio estetico: 📌 *«chi ha venticinque preferiti vuole i tre che usa
  /// ogni giorno in cima, non quelli che cominciano per A»*.
  ///
  /// ⚠️ **`salvatoIl` come terzo criterio**, e non come primo: chi non ha mai
  /// usato niente ha tutti gli zeri, e senza un terzo criterio l'ordine fra
  /// quelli sarebbe quello che decide SQLite — cioè diverso a ogni lettura.
  Future<List<PreferitoCibo>> preferitiDelDiario() =>
      (select(preferitiCibo)
            ..orderBy([
              (t) => OrderingTerm.desc(t.volteUsato),
              (t) => OrderingTerm.desc(t.usatoIl),
              (t) => OrderingTerm.desc(t.salvatoIl),
            ]))
          .get();

  Future<PreferitoCibo?> preferitoDelDiario(int id) =>
      (select(preferitiCibo)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Segna che un preferito è stato usato — I2.5.
  ///
  /// 🚨 **Incrementa in SQL, non legge-e-riscrive.** Due usi ravvicinati —
  /// aggiungere la colazione e poi lo spuntino dallo stesso elenco — leggerebbero
  /// lo stesso numero e ne scriverebbero uno solo: il contatore perderebbe colpi
  /// proprio a chi lo usa di più, cioè esattamente chi l'ordinamento deve servire.
  Future<void> segnaPreferitoUsato(int id, DateTime quando) =>
      (update(preferitiCibo)..where((t) => t.id.equals(id))).write(
        PreferitiCiboCompanion.custom(
          volteUsato: preferitiCibo.volteUsato + const Constant(1),
          usatoIl: Variable(quando),
        ),
      );

  Future<int> scriviPreferito(PreferitiCiboCompanion preferito) =>
      into(preferitiCibo).insert(preferito);

  /// ⚠️ **I preferiti si AGGIORNANO, le voci del diario no**, ed è una
  /// differenza voluta.
  ///
  /// 🚨 Una voce del diario può essere stata corretta a mano sul telefono dopo
  /// il trasloco: riscriverla con quella del server cancellerebbe la
  /// correzione. ⛔ Un preferito invece è ancora del server fino a I4, e il suo
  /// contatore d'uso lì è più aggiornato che qui.
  ///
  /// 💡 È anche ciò che permette di **rifare** il trasloco quando il pacchetto
  /// guadagna un campo — come è successo con `volteUsato`.
  Future<void> importaPreferiti(List<PreferitiCiboCompanion> preferiti) async {
    if (preferiti.isEmpty) return;

    /*
     * 💡 **Si buttano e si riscrivono**, invece di una clausola di conflitto:
     * dice da solo cosa succede, e non c'è niente da tenere allineato.
     *
     * ⛔ **Solo quelle del server**: le righe nate qui hanno `idSulServer` a
     * `null` e restano dove sono. 🚨 Senza quel `where`, rifare il trasloco
     * cancellerebbe i preferiti creati sul telefono — e nessuno lo scoprirebbe
     * finché non ne cerca uno.
     *
     * ⚠️ In una transazione: a metà strada i preferiti del server **non ci sono
     * più e non sono ancora tornati**, e un'interruzione lì li perderebbe tutti.
     */
    await transaction(() async {
      await (delete(preferitiCibo)..where((t) => t.idSulServer.isNotNull())).go();

      await batch((b) => b.insertAll(preferitiCibo, preferiti));
    });
  }

  Future<void> cancellaPreferito(int id) =>
      (delete(preferitiCibo)..where((t) => t.id.equals(id))).go();

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
      massaMagraKg: Value(misura.massaMagraKg),
      /*
       * 🚨 **Chi passa di qui è una persona che scrive**, quindi `manuale` —
       * anche se il chiamante non l'ha detto.
       *
       * ⛔ Lasciare `null` vorrebbe dire che la prima importazione da Health
       * Connect sovrascrive quello che quella persona ha appena scritto:
       * `null` è «non lo so», e «non lo so» non si difende.
       *
       * ⚠️ L'importazione **non passa di qui**: ha il suo metodo,
       * [registraDaSalute], che rispetta questa colonna.
       */
      origine: Value(misura.origine ?? origineManuale),
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

  /// L'ultima **massa grassa** nota, se c'è — 3b-W.
  ///
  /// ══ 🚨 SEPARATA DAL PESO, E NON È PIGNOLERIA ══════════════════════════════
  ///
  /// 📌 *«bisogna prendere solo i dati che vengono davvero passati e stimare
  /// quelli che non vengono passati»*.
  ///
  /// ⚠️ Peso e massa grassa **arrivano da giorni diversi**: chi si pesa ogni
  /// giorno e misura il grasso una volta a settimana ha il peso di stamattina e
  /// il grasso di martedì. ⛔ Chiedere «l'ultima misura» e leggerne due campi
  /// butterebbe via il valore più fresco dei due.
  Future<MisuraCorpo?> ultimaMassaGrassa() {
    return (select(misureCorpo)
          ..where((t) => t.massaGrassaPct.isNotNull())
          ..orderBy([(t) => OrderingTerm.desc(t.giorno)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// L'ultima **massa magra** nota, se c'è — 3b-W.
  ///
  /// 💡 Vale più della percentuale: Katch-McArdle parte da qui, e averla
  /// misurata invece che derivata toglie di mezzo l'errore della bioimpedenza.
  Future<MisuraCorpo?> ultimaMassaMagra() {
    return (select(misureCorpo)
          ..where((t) => t.massaMagraKg.isNotNull())
          ..orderBy([(t) => OrderingTerm.desc(t.giorno)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Le ultime percentuali di grasso note, **dalla più vecchia alla più
  /// recente** — per livellarle.
  ///
  /// ⚠️ L'ordine è quello che vuole [IndiciDiForma.ewma]: cronologico. 🚨 Darlo
  /// al contrario non solleva niente e restituisce una media pesata **sul
  /// passato invece che sul presente**, cioè un numero che si muove al
  /// contrario.
  Future<List<double>> massaGrassaRecente({int quante = 7}) async {
    final righe =
        await (select(misureCorpo)
              ..where((t) => t.massaGrassaPct.isNotNull())
              ..orderBy([(t) => OrderingTerm.desc(t.giorno)])
              ..limit(quante))
            .get();

    return righe.reversed
        .map((r) => r.massaGrassaPct!)
        .toList(growable: false);
  }

  /// Scrive una misura **arrivata da Health Connect** — 3b-W.2.
  ///
  /// ══ ⛔ IL MANUALE VINCE SEMPRE ════════════════════════════════════════════
  ///
  /// Una riga con `origine == 'manuale'` **non si tocca**, nemmeno se la
  /// bilancia ne ha una dello stesso giorno.
  ///
  /// 💡 Chi ha scritto un numero a mano ha fatto una scelta; un'importazione non
  /// ne fa nessuna. ⚠️ E il caso concreto è quello di chi si pesa con una
  /// bilancia che sballa e corregge: senza questa regola si ritroverebbe la
  /// correzione cancellata al primo aggiornamento, **in silenzio**.
  ///
  /// ══ 🚨 E SI SCRIVE CAMPO PER CAMPO ═══════════════════════════════════════
  ///
  /// ⛔ **Non** si sovrascrive la riga intera. Una giornata può avere il peso
  /// dalla bilancia e la circonferenza della vita scritta a mano: rimpiazzare
  /// tutto perché è arrivato un peso butterebbe via il resto.
  ///
  /// 💡 Un valore `null` in arrivo vuol dire «di questo non so niente», **non**
  /// «cancellalo».
  ///
  /// @return `true` se ha scritto, `false` se ha lasciato stare
  Future<bool> registraDaSalute({
    required DateTime giorno,
    double? pesoKg,
    double? massaGrassaPct,
    double? massaMagraKg,
  }) async {
    if (pesoKg == null && massaGrassaPct == null && massaMagraKg == null) {
      return false;
    }

    final quando = _soloGiorno(giorno);

    final esistente =
        await (select(misureCorpo)..where((t) => t.giorno.equals(quando)))
            .getSingleOrNull();

    if (esistente?.origine == origineManuale) return false;

    if (esistente == null) {
      await into(misureCorpo).insert(
        MisureCorpoCompanion.insert(
          giorno: quando,
          pesoKg: Value(pesoKg),
          massaGrassaPct: Value(massaGrassaPct),
          massaMagraKg: Value(massaMagraKg),
          origine: const Value(origineSalute),
        ),
      );

      return true;
    }

    /*
     * ⚠️ `Value.absent()` e non `Value(null)`: il primo dice «non toccare
     * questa colonna», il secondo dice «mettila a null». 🚨 Confonderli
     * cancellerebbe il peso di ieri ogni volta che arriva una massa grassa
     * senza peso — e il grafico si bucherebbe da solo.
     */
    await (update(misureCorpo)..where((t) => t.giorno.equals(quando))).write(
      MisureCorpoCompanion(
        pesoKg: pesoKg == null ? const Value.absent() : Value(pesoKg),
        massaGrassaPct: massaGrassaPct == null
            ? const Value.absent()
            : Value(massaGrassaPct),
        massaMagraKg: massaMagraKg == null
            ? const Value.absent()
            : Value(massaMagraKg),
        origine: const Value(origineSalute),
      ),
    );

    return true;
  }

  /// Il giorno più recente che porta **già** un dato importato — 3b-W.1.3.
  ///
  /// 💡 Serve a non richiedere ogni volta due anni di storico: la prima
  /// importazione prende tutto, le successive partono da qui. ⚠️ `null` vuol
  /// dire «non ho mai importato niente», ed è il caso della prima volta.
  Future<DateTime?> ultimoGiornoImportato() async {
    final riga =
        await (select(misureCorpo)
              ..where((t) => t.origine.equals(origineSalute))
              ..orderBy([(t) => OrderingTerm.desc(t.giorno)])
              ..limit(1))
            .getSingleOrNull();

    return riga?.giorno;
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

  /// Le foto di un allenamento visto solo dall'orologio — 3b-B.20.8.
  Future<List<FotoProgresso>> fotoDellAllenamentoDaOrologio(int id) {
    return (select(fotoProgressi)
          ..where((t) => t.allenamentoOrologioId.equals(id))
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
      b.deleteAll(schedeSulTelefono);
      b.deleteAll(pianiRicevuti);

      /*
       * ══ 🚨 ANCHE GLI ALLENAMENTI — corretto il 25/08/2026 ═══════════════
       *
       * ⛔ Queste quattro righe **mancavano**, e non è un dettaglio: `svuota()`
       * gira quando entra un'altra persona su questo telefono e quando si
       * cancella l'account. Chi arrivava dopo si trovava lo storico completo di
       * chi c'era prima — quando si allenava, per quanto, con che carichi.
       *
       * ⚠️ La causa è quella già vista due volte ieri: **un elenco scritto a
       * mano che deve contenere tutto**. Le tabelle di FASE 11 sono arrivate
       * dopo, e nessuno è tornato ad aggiungerle qui. Chi ne crea una nuova
       * deve passare **anche** di qui — a differenza del backup, che le enumera
       * da solo.
       */
      b.deleteAll(seduteAllenamento);
      b.deleteAll(serieDelleSedute);
      b.deleteAll(bruciateDichiarate);
      b.deleteAll(allenamentiDaOrologio);
      /*
       * ⚠️ **Anche i rifiutati.** Sono una decisione di **questa** persona: chi
       * arriva dopo su questo telefono non deve ereditare i piani che qualcun
       * altro aveva buttato — se ne riceve uno, deve vederlo.
       */
      b.deleteAll(contenutiRifiutati);
    });
  }

  // ─────────────────── le schede, sul telefono (B.17) ───────────────────

  /// Tutte le schede che il telefono ha, dalla più recente.
  Future<List<SchedaSulTelefono>> tutteLeSchede() => (select(
    schedeSulTelefono,
  )..orderBy([(t) => OrderingTerm.desc(t.aggiornataIl)])).get();

  /// Una scheda, o `null` se non c'è.
  Future<SchedaSulTelefono?> laScheda(int id) => (select(
    schedeSulTelefono,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Una scheda scesa dal server, cercata **col suo id di là** — o `null`.
  ///
  /// ⚠️ Non è `laScheda()`: quello vuole l'id di **qui**. Serve
  /// all'importazione, che ha in mano l'id del server e deve sapere se quella
  /// scheda è già arrivata.
  Future<SchedaSulTelefono?> laSchedaDalServer(int idServer) =>
      (select(schedeSulTelefono)..where(
            (t) => t.origine.equals('server') & t.idOrigine.equals(idServer),
          ))
          .getSingleOrNull();

  /// Aggiunge una scheda, e ne restituisce l'id **su questo telefono**.
  ///
  /// 💡 L'id lo dà il database (`autoIncrement`) e non chi chiama: era l'ultimo
  /// pezzo che costringeva a sapere «da dove viene» per calcolare un numero.
  Future<int> aggiungiScheda({
    required String nome,
    required String scheda,
    required bool mia,
    required String origine,
    int? idOrigine,
    String? origineIdStabile,
    DateTime? quando,
  }) async {
    final id = await into(schedeSulTelefono).insert(
      SchedeSulTelefonoCompanion.insert(
        nome: nome,
        scheda: scheda,
        aggiornataIl: quando ?? DateTime.now(),
        // 💡 Nasce adesso, e da qui in poi non si tocca più: `aggiornaScheda`
        // non la sfiora.
        creataIl: Value(quando ?? DateTime.now()),
        mia: Value(mia),
        origine: origine,
        idOrigine: Value(idOrigine),
        origineIdStabile: Value(origineIdStabile),
      ),
    );

    /*
     * 📐 **La versione zero — 3b-I.E.** 🚨 Va scritta alla nascita e non alla
     * prima modifica: registrandola solo quando si cambia qualcosa, il
     * «com'era prima» del primo cambio sarebbe **già perduto** — cioè
     * mancherebbe proprio il confronto che serve la prima volta.
     */
    await segnaLaVersione(id, scheda, quando: quando);

    return id;
  }

  /// Riscrive una scheda che c'è già.
  ///
  /// 🚨 **Si chiama a ogni modifica, non a fine allenamento.** Il salvataggio in
  /// blocco alla fine è ciò che il 24/08 ha reso possibile perdere due esercizi
  /// con un clic: una modifica scritta subito non ha un momento in cui può
  /// sparire.
  ///
  /// ⚠️ `origine` e `idOrigine` **non si toccano**: modificare una scheda non
  /// cambia da dove è arrivata.
  Future<void> aggiornaScheda({
    required int id,
    required String nome,
    required String scheda,
    DateTime? quando,
  }) async {
    /*
     * 📐 **Prima si mette al sicuro com'era — 3b-I.E.**
     *
     * 🚨 Se non c'è ancora nessuna versione, quella che sta per essere
     * sovrascritta è **l'unica copia del "prima"**: le schede che esistevano
     * prima della v23 non hanno una versione zero, e senza questa riga la loro
     * storia comincerebbe dal secondo cambio.
     *
     * ⚠️ Con la data di `aggiornataIl` e non con quella di adesso: quella
     * versione risale a quando è stata scritta, e datarla oggi farebbe sembrare
     * due modifiche nello stesso istante.
     */
    final prima = await (select(
      schedeSulTelefono,
    )..where((t) => t.id.equals(id))).getSingleOrNull();

    if (prima != null) {
      final quante = await (select(
        versioniDelleSchede,
      )..where((t) => t.schedaLocale.equals(id))).get();

      if (quante.isEmpty) {
        await into(versioniDelleSchede).insert(
          VersioniDelleSchedeCompanion.insert(
            schedaLocale: id,
            quando: prima.aggiornataIl,
            impronta: improntaDellaScheda(prima.scheda),
            contenuto: prima.scheda,
          ),
        );
      }
    }

    await (update(schedeSulTelefono)..where((t) => t.id.equals(id))).write(
      SchedeSulTelefonoCompanion(
        nome: Value(nome),
        scheda: Value(scheda),
        aggiornataIl: Value(quando ?? DateTime.now()),
      ),
    );

    await segnaLaVersione(id, scheda, quando: quando);
  }

  /// Salva una scheda arrivata via chat.
  ///
  /// ══ 🚨 LE TRE PROTEZIONI, E PERCHÉ CI SONO TUTTE E TRE ═══════════════════
  ///
  /// | Cosa | Senza |
  /// |---|---|
  /// | ⛔ salta quelle **rifiutate** | una scheda buttata ricompare da sola al messaggio dopo, e si ributta. Per sempre |
  /// | ⚠️ salta quelle **fuori ordine** | la versione vecchia che arriva per seconda sovrascrive quella corretta |
  /// | 💡 `insertOrIgnore` | toccare due volte «aggiungi» fa due copie della stessa scheda |
  ///
  /// ⚠️ **`messaggioId` e non l'id della scheda**: lo stesso modello può
  /// arrivare due volte — il trainer lo rimanda dopo averlo corretto — e sono
  /// **due schede diverse** nella vita di chi le riceve. La vecchia va tenuta
  /// finché non la si butta, o sparirebbe lo storico di cosa si stava facendo il
  /// mese scorso.
  ///
  /// 📌 `false` vuol dire «non l'ho salvata», ed è **una risposta normale**: la
  /// chat non deve dire niente a nessuno.
  Future<bool> salvaSchedaDallaChat({
    required int messaggioId,
    required String nome,
    required String scheda,
    String? origineId,
  }) async {
    if (origineId != null && await eRifiutato(origineId)) return false;

    if (origineId != null) {
      final esistente =
          await (select(schedeSulTelefono)..where(
                (t) =>
                    t.origine.equals('chat') &
                    t.origineIdStabile.equals(origineId),
              ))
              .getSingleOrNull();

      if (esistente != null) {
        /*
         * ⚠️ **Fuori ordine**: una versione più vecchia che arriva dopo non
         * sovrascrive quella buona. Vedi `salvaPiano()`. 🚨 Il confronto è fra
         * id di messaggio e non fra date: le date le mette chi manda, e due
         * telefoni con l'orologio storto basterebbero a invertire l'ordine.
         */
        if ((esistente.idOrigine ?? 0) >= messaggioId) return false;

        await (update(
          schedeSulTelefono,
        )..where((t) => t.id.equals(esistente.id))).write(
          SchedeSulTelefonoCompanion(
            idOrigine: Value(messaggioId),
            nome: Value(nome),
            scheda: Value(scheda),
            aggiornataIl: Value(DateTime.now()),
          ),
        );

        return true;
      }
    }

    await into(schedeSulTelefono).insert(
      SchedeSulTelefonoCompanion.insert(
        nome: nome,
        scheda: scheda,
        aggiornataIl: DateTime.now(),
        origine: 'chat',
        idOrigine: Value(messaggioId),
        origineIdStabile: Value(origineId),
      ),
      mode: InsertMode.insertOrIgnore,
    );

    return true;
  }

  /// C'è già? Serve alla chat per dire «aggiunta» invece di «aggiungi».
  ///
  /// 💡 Senza, l'unico modo di sapere se si è già premuto il pulsante è provare
  /// — e riprovare su un messaggio vecchio è la cosa più naturale del mondo.
  Future<bool> schedaGiaSalvata(int messaggioId) async {
    final riga =
        await (select(schedeSulTelefono)..where(
              (t) => t.origine.equals('chat') & t.idOrigine.equals(messaggioId),
            ))
            .getSingleOrNull();

    return riga != null;
  }

  /// Butta una scheda, e **ricorda che è stata buttata** — G8.10.
  ///
  /// 📌 *«se serve una nuova scheda il trainer la rimanda e l'utente cancella la
  /// vecchia e usa la nuova»*: cancellare è un'azione normale, non un incidente.
  ///
  /// 🚨 **Il ricordo non è un dettaglio.** Senza, il salvataggio automatico
  /// della chat la rimetterebbe in archivio al messaggio successivo, e chi
  /// l'aveva buttata la ributterebbe. Per sempre.
  Future<int> cancellaScheda(int id) async {
    final riga = await laScheda(id);

    if (riga?.origineIdStabile != null) {
      await into(contenutiRifiutati).insert(
        ContenutiRifiutatiCompanion.insert(
          origineId: riga!.origineIdStabile!,
          rifiutatoIl: DateTime.now(),
        ),
        mode: InsertMode.insertOrIgnore,
      );
    }

    return (delete(schedeSulTelefono)..where((t) => t.id.equals(id))).go();
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

/// Il diario alimentare, **sul telefono** — Parte I, I1.
///
/// ══ 📌 PERCHÉ SI SPOSTA ═══════════════════════════════════════════════════
///
/// 📌 Regola R3 del progetto: *«tutto ciò che è anche lontanamente sensibile
/// resta sul telefono»*. 🚨 Cosa mangia una persona è **dato dell'art. 9**, ed
/// era l'ultima tabella grossa di dati personali rimasta sul server: peso,
/// sonno, allenamenti e schede se ne sono andati fra S5, D9 e la FASE 11.
///
/// ══ ⛔ COSA NON C'È, E NON È UNA DIMENTICANZA ════════════════════════════
///
/// **Niente `tenant_id`, niente `user_id`.** Questo database è il telefono di
/// **una** persona: una colonna che dice di chi è la riga sarebbe una colonna
/// con sempre lo stesso valore, e il giorno che qualcuno la leggesse per
/// filtrare avrebbe scritto un filtro che non filtra.
///
/// 💡 È la stessa scelta di `MisureCorpo` e `SeduteAllenamento`.
///
/// ══ 🚨 `idSulServer`: SERVE ALLA MIGRAZIONE, E SOLO A QUELLA ═════════════
///
/// Una riga che arriva dal server porta il suo id di là, così I3 può rileggere
/// il pacchetto **due volte senza duplicare** — e il server può confrontare i
/// conteggi prima di cancellare qualcosa.
///
/// ⛔ `null` per tutto ciò che nasce qui, che dopo il trasloco sarà la
/// maggioranza. ⚠️ **Non è una chiave**: due telefoni della stessa persona
/// possono avere id locali diversi per la stessa voce, e va bene — la copia
/// autorevole è una sola, e viaggia nel backup.
@DataClassName('VoceDiario')
class VociDiario extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// L'id che questa riga aveva su `food_entries`. Vedi la nota in testa.
  IntColumn get idSulServer => integer().nullable()();

  /// Quando è stata mangiata.
  ///
  /// ⚠️ **Oggi l'app manda la mezzanotte del giorno scelto**, non l'ora vera:
  /// `eaten_at` sul server vale `selectedDate`. 🚨 Qui si conserva così com'è
  /// per non inventare un'ora che non è mai stata misurata — e per sapere
  /// *quando* una voce è stata scritta c'è [scrittaIl], che è un dato vero.
  DateTimeColumn get mangiatoIl => dateTime()();

  /// `breakfast`, `morning_snack`, `lunch`, `afternoon_snack`, `dinner`,
  /// `evening_snack`. 💡 La **chiave**, non l'etichetta: le etichette cambiano.
  TextColumn get pasto => text().withLength(min: 1, max: 24)();

  TextColumn get descrizione => text().withLength(min: 1, max: 255)();

  RealColumn get grammi => real().nullable()();
  RealColumn get quantita => real().nullable()();
  TextColumn get unita => text().withLength(min: 1, max: 16).nullable()();

  RealColumn get kcal => real().nullable()();
  RealColumn get proteine => real().nullable()();
  RealColumn get carboidrati => real().nullable()();
  RealColumn get grassi => real().nullable()();

  /// I valori per 100 g/ml, che servono a ricalcolare quando si corregge la
  /// quantità. ⛔ Senza, cambiare «100 g» in «150 g» richiederebbe di
  /// richiedere la stima da capo — cioè di pagare un gettone per una moltiplicazione.
  RealColumn get kcal100 => real().nullable()();
  RealColumn get proteine100 => real().nullable()();
  RealColumn get carboidrati100 => real().nullable()();
  RealColumn get grassi100 => real().nullable()();

  /// `manual`, `ai_text`, `ai_photo`, `plan`, `favorite`, `catalog`…
  ///
  /// 💡 È quello che permette di dire «questo numero l'ha stimato l'AI» accanto
  /// alla voce, ed è anche l'unico modo di sapere **quanto** ci si può fidare.
  TextColumn get fonte => text().withLength(min: 1, max: 16).withDefault(
    const Constant('manual'),
  )();

  /// La risposta grezza del modello, quando la voce viene da una stima.
  ///
  /// ⚠️ Serve a spiegare un numero che qualcuno contesta — *«non è stato
  /// specificato se sono panate»* — ed è il campo che il 12/08 ha spiegato una
  /// stima sbagliata mentre `confidence` diceva 0.85.
  TextColumn get aiGrezzo => text().nullable()();

  /// Da quale piano alimentare viene, se viene da un piano.
  IntColumn get pianoId => integer().nullable()();

  /// L'alimento del catalogo condiviso, se è stato riconosciuto.
  ///
  /// 🚨 **Il catalogo resta sul server** ed è giusto così: non è di nessuno.
  /// Qui c'è solo il riferimento.
  IntColumn get alimentoId => integer().nullable()();

  /// Quando la riga è stata **scritta**, che è un'altra cosa da [mangiatoIl].
  ///
  /// 💡 È il campo che distingue una cena **programmata** alle 10 del mattino da
  /// una cena mangiata alle 21 — la stessa distinzione che il consiglio del
  /// giorno usa da 3b-AC, dove si chiama `scritto_alle` e viene da `created_at`.
  DateTimeColumn get scrittaIl =>
      dateTime().withDefault(currentDateAndTime)();

  /// ⚠️ **L'indice unico è ciò che rende vero `insertOrIgnore`** — I1.
  ///
  /// ⛔ `insertOrIgnore` ignora su **violazione di vincolo**: senza questo, una
  /// migrazione ripetuta scriverebbe tutto due volte, e il difetto si vedrebbe
  /// solo guardando le calorie di un giorno vecchio.
  ///
  /// 💡 I `null` non danno fastidio: in SQLite due `NULL` non sono uguali,
  /// quindi le voci **nate qui** — `idSulServer` nullo — convivono quante si
  /// vuole. È esattamente la proprietà che serve.
  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {idSulServer},
  ];
}

/// I preferiti del diario — Parte I, I1.
///
/// 💡 Un piatto che si ripete: si salva una volta e si riusa. ⛔ Sul server
/// stavano in `food_favorites`, e viaggiano con il diario perché sono fatti
/// della stessa sostanza — quello che quella persona mangia di solito.
@DataClassName('PreferitoCibo')
class PreferitiCibo extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get idSulServer => integer().nullable()();

  TextColumn get descrizione => text().withLength(min: 1, max: 255)();

  /// Se è un **pasto intero** invece di un singolo alimento.
  BoolColumn get ePasto => boolean().withDefault(const Constant(false))();

  /// Le voci che lo compongono, quando è un pasto. JSON.
  TextColumn get voci => text().nullable()();

  RealColumn get grammi => real().nullable()();
  RealColumn get quantita => real().nullable()();
  TextColumn get unita => text().withLength(min: 1, max: 16).nullable()();

  RealColumn get kcal => real().nullable()();
  RealColumn get proteine => real().nullable()();
  RealColumn get carboidrati => real().nullable()();
  RealColumn get grassi => real().nullable()();

  RealColumn get kcal100 => real().nullable()();
  RealColumn get proteine100 => real().nullable()();
  RealColumn get carboidrati100 => real().nullable()();
  RealColumn get grassi100 => real().nullable()();

  DateTimeColumn get salvatoIl => dateTime().withDefault(currentDateAndTime)();

  /// Quante volte è stato usato.
  ///
  /// 🚨 **Un contatore salvato, non un aggregato**: sul server era
  /// `food_favorites.times_used`, incrementato a ogni uso. ⛔ Ricavarlo contando
  /// le voci del diario con la stessa descrizione darebbe un numero diverso —
  /// chi ha scritto «Pollo» a mano dieci volte non ha usato dieci volte il
  /// preferito «Pollo».
  ///
  /// 💡 È metà dell'ordinamento: 📌 *«chi ha venticinque preferiti vuole i tre
  /// che usa ogni giorno in cima, non quelli che cominciano per A»*.
  IntColumn get volteUsato => integer().withDefault(const Constant(0))();

  /// L'ultima volta che è stato usato. L'altra metà dell'ordinamento.
  DateTimeColumn get usatoIl => dateTime().nullable()();

  /// ⚠️ **L'indice unico è ciò che rende vero `insertOrIgnore`** — I1.
  ///
  /// ⛔ `insertOrIgnore` ignora su **violazione di vincolo**: senza questo, una
  /// migrazione ripetuta scriverebbe tutto due volte, e il difetto si vedrebbe
  /// solo guardando le calorie di un giorno vecchio.
  ///
  /// 💡 I `null` non danno fastidio: in SQLite due `NULL` non sono uguali,
  /// quindi le voci **nate qui** — `idSulServer` nullo — convivono quante si
  /// vuole. È esattamente la proprietà che serve.
  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {idSulServer},
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

  /// 🆕 La **massa magra**, quando la bilancia la manda — 3b-W.
  ///
  /// 💡 Vale più della percentuale di grasso: Katch-McArdle parte da qui, e
  /// averla **misurata** invece che derivata toglie di mezzo l'errore della
  /// bioimpedenza. ⚠️ La bilancia del committente non la manda; un orologio
  /// Amazfit sì.
  RealColumn get massaMagraKg => real().nullable()();

  /// 🆕 Da dove viene questa misura — 3b-W.2.
  ///
  /// ══ 🚨 SERVE A NON SOVRASCRIVERE QUELLO CHE UNO HA SCRITTO A MANO ═══════
  ///
  /// ⛔ Senza, un'importazione da Health Connect cancella **in silenzio** la
  /// correzione di chi si è pesato con una bilancia scassata e ha rimesso il
  /// numero giusto. ⚠️ E il caso non è teorico: la riga esiste, ha un valore
  /// plausibile, e nessuno si accorge di niente.
  ///
  /// ══ ⛔ E DICE SOLO «DA HEALTH CONNECT», NON QUALE APP ═══════════════════
  ///
  /// 🚨 Misurato il 30/08: `HealthDataPoint.sourceId` arriva **vuoto** su
  /// Android. Non sappiamo se un peso l'ha scritto la bilancia, l'orologio o
  /// una persona dentro Health Connect. 💡 Quindi l'interfaccia può dire *«da
  /// Health Connect»* e **non** *«dalla tua bilancia»*: promettere di sapere
  /// quale bilancia sarebbe mentire.
  ///
  /// ⚠️ **`null` è un valore vero**, e vuol dire «non lo so»: sono le righe
  /// scritte prima di 3b-W. ⛔ Riempirle con `'manuale'` alla migrazione le
  /// proteggerebbe per sempre da un aggiornamento — e non è vero che sono state
  /// scritte a mano: molte arrivano da un backup.
  TextColumn get origine => text().nullable()();

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

  /// La foto di un allenamento visto **solo dall'orologio** — 3b-B.20.8.
  ///
  /// 📌 *«Anche nella schermata di allenamento con orologio devo poter
  /// aggiungere una foto»*.
  ///
  /// 🚨 **Una colonna nuova e non `sessioneId` con un id negativo.** Gli id
  /// firmati sono la convenzione che B.17.6 ha appena tolto dalle schede, e
  /// rimetterla qui vorrebbe dire ripagare lo stesso prezzo: una riga in cui il
  /// **segno** di un numero cambia a quale tabella punta è una riga che prima o
  /// poi qualcuno legge sbagliata, senza nessun errore.
  ///
  /// ⚠️ Le due colonne non sono mai piene insieme: una foto appartiene a una
  /// seduta **o** a un allenamento del polso. Ed entrambe possono essere vuote —
  /// è la foto di progressi che non sta su nessun allenamento.
  IntColumn get allenamentoOrologioId => integer().nullable()();
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
/// 🚨 **Gemella delle schede, e per la stessa ragione**: vivono sul
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

@DataClassName('SchedaSulTelefono')
/// Le schede, **sul telefono e basta** — 3b-B.17, 24/08/2026.
///
/// ══ 📌 LA DECISIONE ═══════════════════════════════════════════════════════
///
/// *«la scheda risiede sul telefono (e finisce nel backup). Basta, niente
/// server, sticazzi crea solo problemi. Tanto se serve una nuova scheda il
/// trainer la rimanda e l'utente cancella la vecchia e usa la nuova»*.
///
/// ⛔ **Qui c'erano quattro colonne in più** — il timbro del server, quando era
/// stata toccata qui, la copia che aveva perso un conflitto e quando. Servivano
/// a far convivere due copie della stessa scheda. 💡 Di copie ce n'è **una**:
/// quelle colonne non hanno più niente da dire, e sono sparite.
///
/// ══ 🗃️ E SONO UNA TABELLA SOLA — 3b-B.17.6, 25/08/2026 ═══════════════════
///
/// 📌 *«Che vuol dire stanno in una seconda tabella locale? Uniamole»*.
///
/// ⛔ Le schede arrivate in chat vivevano in `SchedeRicevute`, e l'elenco delle
/// schede leggeva **solo questa**: una scheda mandata dal trainer non compariva
/// fra le proprie e non ci si poteva allenare. 💡 Adesso la provenienza è una
/// **colonna** (`origine`), non una tabella: chi legge le schede legge un posto
/// solo, e non può dimenticarsi il secondo.
///
/// ⚠️ Nel backup ci finisce **da sola**: `esportaPerBackup()` enumera
/// `allTables`, non un elenco scritto a mano.
class SchedeSulTelefono extends Table {
  /// L'id della scheda **su questo telefono**.
  ///
  /// ⛔ Qui c'era il trucco degli id firmati — positivi per quelle del server,
  /// negativi per quelle scritte qui — che serviva a tenere separati due spazi
  /// di id. 💡 Con una tabella sola non c'è niente da tenere separato, e un id
  /// firmato è una convenzione che prima o poi qualcuno viola: da dove viene
  /// una scheda lo dice `origine`, che è un dato, non un segno.
  ///
  /// ⚠️ **Gli id già assegnati non cambiano**: la migrazione ricopia le righe
  /// così come sono, perché `AllenamentiDaOrologio.schedaAssegnata` punta qui —
  /// rinumerarli vorrebbe dire spostare in silenzio gli allenamenti già fatti
  /// su schede diverse da quelle vere.
  IntColumn get id => integer().autoIncrement()();

  /// Il nome, per non dover aprire il JSON a ogni riga di un elenco.
  TextColumn get nome => text()();

  /// La scheda intera, serializzata.
  TextColumn get scheda => text()();

  /// Quando è stata toccata l'ultima volta, **su questo telefono**.
  DateTimeColumn get aggiornataIl => dateTime()();

  /// Quando è **arrivata**, o è stata scritta — 3b-C.6.
  ///
  /// 📌 Serve al limite di chi non è abbonato: *«le ultime 3 per data di
  /// creazione»*.
  ///
  /// 🚨 **Non è `aggiornataIl`, e la differenza è tutta qui.** Quella cambia a
  /// ogni modifica: rinominare una scheda di marzo la porterebbe in cima e
  /// scavalcherebbe una arrivata ieri, cioè **sbloccherebbe la vecchia
  /// bloccando la nuova**. Un limite che si aggira rinominando non è un limite.
  ///
  /// ⚠️ **Nullable**, perché le righe che c'erano prima una data di nascita non
  /// ce l'hanno: chi legge cade su `aggiornataIl`, che per quelle è la stima
  /// migliore disponibile. ⛔ Riempirla con `DateTime.now()` in migrazione
  /// avrebbe dato a tutte le schede vecchie la stessa età — quella del giorno
  /// dell'aggiornamento — e l'ordine sarebbe stato casuale.
  DateTimeColumn get creataIl => dateTime().nullable()();

  /// Se la si può modificare.
  ///
  /// ⚠️ `false` per quelle del trainer: si eseguono, non si cambiano. ⛔ E se
  /// serve una versione nuova **la rimanda lui** — è la decisione del 24/08, ed
  /// è il motivo per cui non c'è nessuna sincronizzazione da nessuna parte.
  BoolColumn get mia => boolean().withDefault(const Constant(false))();

  /// Da dove viene: `'chat'`, `'server'` o `'mia'`.
  ///
  /// 🚨 **Serve a non confondere due id che si somigliano.** Il numero in
  /// `idOrigine` è un id di messaggio per le schede della chat e un id di
  /// scheda per quelle scese dal server: sono due numerazioni diverse, e senza
  /// questa colonna il messaggio 8 e la scheda 8 sarebbero la stessa riga.
  TextColumn get origine => text()();

  /// Il numero che identifica la scheda **là da dove viene**.
  ///
  /// 💡 `messaggioId` per la chat, l'id del server per le altre. ⚠️ `null` per
  /// quelle scritte qui, che non vengono da nessuna parte — e i `NULL` in
  /// SQLite non collidono fra loro, quindi la chiave unica qui sotto non
  /// impedisce di scriversene quante se ne vuole.
  IntColumn get idOrigine => integer().nullable()();

  /// 🚨 **L'identità stabile della scheda** — D15.
  ///
  /// È ciò che permette di riconoscere che una scheda arrivata è la **versione
  /// nuova** di una che c'è già, e di sostituirla invece di affiancarla. È
  /// anche ciò che si ricorda quando la si butta, perché non torni da sola al
  /// messaggio successivo.
  ///
  /// ⚠️ **Nullable**: le buste `v1` non ce l'hanno, e chi arriva senza cade sul
  /// comportamento vecchio — una riga per messaggio — che è corretto, solo meno
  /// furbo.
  TextColumn get origineIdStabile => text().nullable()();

  /// ⚠️ **Toccare due volte «aggiungi» non deve fare due copie.** È l'unico che
  /// regge `insertOrIgnore` in `salvaSchedaDallaChat()`: prima stava sulla sola
  /// colonna `messaggioId`, e adesso che nella stessa tabella convivono id di
  /// messaggi e id di schede deve comprendere anche la provenienza.
  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {origine, idOrigine},
  ];
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
  /// 💡 È l'`id` locale in `SchedeSulTelefono` — quello di **qui**, non quello
  /// del server. `null` vuol dire «non l'ho assegnata», che è lo stato normale:
  /// la maggior parte delle corse non corrisponde a nessuna scheda.
  ///
  /// ⚠️ **È il motivo per cui la migrazione v14 → v15 non rinumera gli id.**
  /// Rinumerarli avrebbe spostato in silenzio gli allenamenti già fatti su
  /// schede diverse da quelle vere.
  ///
  /// 🚨 **Una risincronizzazione non la cancella**: `scriviAllenamenti()` usa
  /// `insertOrIgnore`, quindi una riga già presente non viene riscritta. ⚠️ Con
  /// `insertOrReplace` l'orologio sovrascriverebbe una scelta della persona
  /// ogni volta che si rileggono gli ultimi sette giorni — cioè a ogni avvio.
  IntColumn get schedaAssegnata => integer().nullable()();

  /// Il tipo che **hai dichiarato tu**, quando quello dell'orologio non va —
  /// 3b-B.20.5, 25/08/2026.
  ///
  /// 📌 *«voglio poterci assegnare anche un tipo di allenamento diverso dalla
  /// scheda. Tipo corsa, bicicletta, nuoto, ste cose qui, in modo che possa
  /// stimare i muscoli coinvolti e le calorie»*.
  ///
  /// 🚨 **È una colonna diversa da `tipo`, e la differenza è tutto.** `tipo` lo
  /// scrive l'orologio; questa la scrive una persona. ⛔ Sovrascrivere `tipo`
  /// avrebbe cancellato quello che il sensore ha visto per mettercelo dentro un
  /// parere — e alla prima risincronizzazione i due si sarebbero contesi la
  /// stessa casella.
  ///
  /// 💡 È la **gemella di `schedaAssegnata`**, e per la stessa ragione:
  /// `scriviAllenamenti()` usa `insertOrIgnore`, quindi una riga già presente
  /// non viene riscritta e la scelta sopravvive a ogni lettura degli ultimi
  /// sette giorni. ⚠️ Con `insertOrReplace` l'orologio la cancellerebbe a ogni
  /// avvio.
  ///
  /// ⚠️ Vale un codice di `TipoScelto`, non un testo libero: `null` vuol dire
  /// «non l'ho dichiarato», e allora vale quello dell'orologio.
  TextColumn get tipoScelto => text().nullable()();

  /// Le calorie **corrette a mano** per questo allenamento — 3b-C.4.
  ///
  /// 📌 *«deve essere IDENTICA»*: sulla pagina di una seduta dell'app le calorie
  /// si possono correggere da sempre, e senza questa colonna la pagina di un
  /// allenamento del polso avrebbe avuto lo stesso riquadro con dentro un numero
  /// che non si tocca. ⛔ Una card identica che non fa la stessa cosa è peggio di
  /// una card diversa: promette e non mantiene.
  ///
  /// 🚨 **Accanto a `kcal`, non al suo posto**: quello lo ha misurato
  /// l'orologio. È la stessa forma di `tipoScelto` accanto a `tipo`, e per la
  /// stessa ragione — `insertOrIgnore` fa sì che la correzione sopravviva a ogni
  /// risincronizzazione.
  IntColumn get kcalCorrette => integer().nullable()();

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

  /// «Questo è stato fuori dal solito» — 3b-G.7, 26/08/2026.
  ///
  /// ══ 📌 A COSA SERVE, E SOLO IN UN MODELLO ══════════════════════════════
  ///
  /// Chi ha scelto il modello **«stima»** ha un fattore di attività che gli
  /// allenamenti li contiene già, quindi registrarli non alza l'obiettivo — ed è
  /// giusto, o li conterebbe due volte. ⚠️ Ma la frase con cui il committente ha
  /// descritto quel modello era *«registrerò solo gli allenamenti
  /// eccezionali»*: la mezza maratona di domenica **non** sta dentro «3-4
  /// allenamenti a settimana».
  ///
  /// 💡 Questa spunta è quel «eccezionale»: nel modello a stima **solo** le
  /// sedute marcate entrano nell'obiettivo.
  ///
  /// ⛔ **Spenta di serie, e non è pigrizia**: accesa di serie rimetterebbe
  /// dentro tutti gli allenamenti, cioè il doppio conteggio da cui veniamo.
  ///
  /// ⚠️ **Nel modello «misurata» non fa niente**, perché lì entra già tutto.
  BoolColumn get contaComeExtra =>
      boolean().withDefault(const Constant(false))();

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
/// 2. Le schede ricevute e le foto della seduta puntano all'id del server. ⛔
///    Buttarlo vorrebbe dire perdere il legame fra una seduta e la scheda che
///    è stata eseguita.
///
/// 💡 `null` per le sedute **nate sul telefono** dopo la migrazione: da lì in
/// poi il server non le vede mai, quindi un id di là non ce l'hanno.
@DataClassName('SedutaAllenamento')
class SeduteAllenamento extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// «Questa è stata fuori dal solito» — 3b-G.7.
  ///
  /// 🚨 Stessa cosa di `AllenamentiDaOrologio.contaComeExtra`, e c'è su tutte e
  /// due perché nel modello a stima esistono tutte e due: marcarne solo una
  /// famiglia vorrebbe dire che la mezza maratona conta se l'hai fatta con
  /// l'orologio e non se l'hai registrata con l'app.
  BoolColumn get contaComeExtra =>
      boolean().withDefault(const Constant(false))();

  /// L'`id` che questa seduta aveva sul server, se ci è mai stata.
  IntColumn get idServer => integer().nullable().unique()();

  /// L'`id` **del server** della scheda eseguita, come lo mandava `plan_id`.
  ///
  /// ⚠️ Non l'id locale in `SchedeSulTelefono`: quello cambia da telefono a
  /// telefono, questo no. Le due cose si incrociano su
  /// `SchedeSulTelefono.idOrigine`, con `origine = 'server'`.
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

/// La settimana programmata — 3b-I.B, 27/08/2026.
///
/// ══ 📌 COS'E' ═════════════════════════════════════════════════════════════
///
/// Sette righe, una per giorno: quale scheda tocca, o `null` per il riposo.
///
/// ⛔ **Non è «una lista di appuntamenti con le date»**, ed è una scelta: la
/// settimana **si ripete**, e con le date bisognerebbe rigenerarla ogni
/// domenica — cioè avere qualcosa che gira di notte per tenere in piedi una
/// funzione che non ne ha bisogno.
///
/// ⚠️ **`schedaLocale` non ha un vincolo di chiave esterna**, e non è una
/// dimenticanza: se la scheda viene cancellata il giorno deve **restare**,
/// vuoto, e dirlo. 🚨 Con una cascata sparirebbe la riga e il giorno tornerebbe
/// «riposo» — cioè l'app direbbe che quel giorno non ti alleni, invece di dire
/// che la scheda che avevi messo non c'è più.
///
/// 💡 Finisce nel backup da sola: `esportaPerBackup()` enumera `allTables`.
@DataClassName('GiornoProgrammato')
class SettimanaProgrammata extends Table {
  /// 1 = lunedì … 7 = domenica.
  ///
  /// 💡 **La convenzione di `DateTime.weekday`**, non una nostra: così
  /// `adesso.weekday` è già la chiave, senza nessuna conversione da ricordare.
  IntColumn get giorno => integer()();

  /// L'id in `SchedeSulTelefono`, o `null` per il riposo.
  IntColumn get schedaLocale => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {giorno};
}


/// L'analisi della progressione di una scheda — 3b-I.A, 27/08/2026.
///
/// ══ 🚨 UNA RIGA PER SCHEDA, E IL JSON DENTRO ══════════════════════════════
///
/// ⛔ **Non una tabella con una riga per esercizio**, ed è deliberato:
/// l'analisi è **una risposta sola** (una chiamata per scheda), si scrive
/// insieme e si butta insieme. Spezzarla vorrebbe dire poterne avere metà
/// vecchia e metà nuova — cioè una scheda che racconta due storie diverse a
/// seconda dell'esercizio che guardi.
///
/// 💡 E il JSON qui dentro non è pigrizia: nessuna query dovrà mai cercare «gli
/// esercizi in salita». Si legge tutto o niente, che è la definizione di quando
/// una colonna di testo va bene.
///
/// ══ ⚠️ [impronta] È QUELLO CHE RENDE L'ANALISI RIGENERABILE ══════════════
///
/// È l'impronta dello storico su cui l'analisi è stata scritta. 🚨 Serve a
/// rispondere alla sola domanda che conta — *«è ancora attuale?»* — senza
/// chiedere niente a nessuno: se da allora sono state fatte altre sedute
/// l'impronta cambia, e l'app può dirlo. Con la sola data non si distinguerebbe
/// «vecchia di un mese ma ancora vera» da «di ieri e già superata».
///
/// 💡 Finisce nel backup da sola: `esportaPerBackup()` enumera `allTables`.
@DataClassName('AnalisiScheda')
class AnalisiDelleSchede extends Table {
  /// L'id della scheda **su questo telefono** — `SchedeSulTelefono.id`.
  ///
  /// ══ ⚠️ SI CHIAMAVA `schedaServerId`, ED ERA SBAGLIATO ═══════════════════
  ///
  /// 🚨 `schedeUniteProvider` costruisce ogni `WorkoutPlan` con `'id': r.id`,
  /// cioè con l'id **locale**: quello che arriva qui non è mai stato l'id del
  /// server. ⛔ Il codice funzionava — tutti e due i lati usavano lo stesso
  /// numero — ma il nome raccontava un'altra cosa, ed è il tipo di bugia che si
  /// paga quando qualcuno ci costruisce sopra.
  ///
  /// 💡 Rinominata alla v23, quando è arrivata [VersioniDelleSchede] che si
  /// aggancia **allo stesso id**: due tabelle vicine non potevano chiamarlo in
  /// due modi diversi.
  IntColumn get schedaLocale => integer()();

  /// Le righe, come sono arrivate dal server: `[{id, andamento, riga}, …]`.
  TextColumn get righe => text()();

  /// L'impronta dello storico al momento dell'analisi. Vedi la nota in testa.
  TextColumn get impronta => text()();

  /// La frase su **tutta** la scheda — 3b-I.F.
  ///
  /// ⚠️ **Nullable**, e non «vuota di serie»: le analisi scritte prima che
  /// questo campo esistesse non ne hanno una, e riempirle con una stringa vuota
  /// direbbe «il modello non ha trovato niente da dire» — che è un'altra cosa.
  TextColumn get riassunto => text().nullable()();

  DateTimeColumn get fattaIl => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {schedaLocale};
}


/// Quanto dura una «sessione di modifica»: dentro, la versione si sostituisce.
///
/// 💡 Venti minuti perché chi compone una scheda salva molte volte di fila —
/// `aggiornaScheda` si chiama **a ogni modifica** — e una serata di lavoro deve
/// restare **una** versione. ⚠️ Più lunga seppellirebbe il «com'era stamattina»
/// di chi corregge la scheda fra due allenamenti dello stesso giorno.
const finestraDiModifica = Duration(minutes: 20);

/// Quante versioni si tengono, oltre alla prima.
const quanteVersioni = 20;

/// Com'era fatta una scheda, prima — 3b-I.E, 27/08/2026.
///
/// ══ 📌 PERCHÉ ESISTE ══════════════════════════════════════════════════════
///
/// 📌 *«devi fare in modo che siamo sicuri che le modifiche il programma le
/// veda: cioè deve vedere com'era prima e com'era dopo … ci deve essere
/// qualcosa che tiene traccia del modo in cui cambia la scheda nel corso del
/// tempo»*.
///
/// 🚨 **`SerieDelleSedute` dice cosa hai fatto, questa dice cosa ti eri
/// prescritto.** ⛔ Senza, un calo di ripetizioni e una serie aggiunta alla
/// scheda sono indistinguibili — e l'analisi racconterebbe un peggioramento
/// dove c'è un cambio di programma.
///
/// ══ 💡 IL CONTENUTO INTERO, NON IL DIFF ═══════════════════════════════════
///
/// ⛔ Salvare le differenze invece degli scatti sarebbe più compatto e
/// **irrecuperabile**: un difetto nel calcolo del diff, un giorno, renderebbe
/// illeggibile tutta la catena all'indietro. 🚨 Con gli scatti il diff si
/// ricalcola quando serve, e si corregge quando sbaglia.
///
/// 💡 Costa poco: una scheda è qualche kB di JSON, e ne teniamo al massimo
/// [quanteVersioni] più l'originale. 📌 *«tanto è tutto in locale, non ci costa
/// niente»*.
///
/// 💡 Finisce nel backup da sola: `esportaPerBackup()` enumera `allTables`.
@DataClassName('VersioneSchedaSalvata')
class VersioniDelleSchede extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// L'id in `SchedeSulTelefono`.
  ///
  /// ⚠️ **Nessuna chiave esterna**, come per `SettimanaProgrammata`: se la
  /// scheda viene cancellata queste righe restano orfane e vengono ignorate.
  /// ⛔ Una cascata cancellerebbe la storia di una scheda cancellata per
  /// sbaglio, che è l'unico momento in cui quella storia servirebbe davvero.
  IntColumn get schedaLocale => integer()();

  DateTimeColumn get quando => dateTime()();

  /// L'impronta di [improntaDellaScheda]: serve a non riscrivere due volte lo
  /// stesso contenuto.
  TextColumn get impronta => text()();

  /// Il JSON della scheda, com'era.
  TextColumn get contenuto => text()();
}
