/// Le schede fra server e telefono — 3b-B.16, 24/08/2026.
///
/// ══ 📌 LA RICHIESTA ═══════════════════════════════════════════════════════
///
/// *«L'allenamento e le schede devono essere solide come il marmo, se inizio un
/// allenamento, modifico un esercizio, ne aggiungo o rimuovo uno, tutto deve
/// stare sul telefono. A questo punto facciamo che le schede sul server si
/// sincronizzano sul telefono quando apro l'app e per le modifiche vince sempre
/// la più recente, che aggiorna rispettivamente la scheda sul telefono o
/// sull'app (perché potrei non avere rete quando mi alleno)»*.
///
/// ══ 🚨 LA DECISIONE CHE REGGE TUTTO: NON SI CONFRONTANO DUE OROLOGI ═══════
///
/// ⛔ «Vince la più recente» detto alla lettera vorrebbe dire mettere a
/// confronto l'orologio del telefono con quello del server. ⚠️ Sono due
/// orologi diversi: uno sfasamento di due minuti — normalissimo — farebbe
/// vincere **sistematicamente** il lato avanti, e cancellerebbe modifiche vere
/// senza dirlo. Cioè il difetto del 24/08 con un altro nome.
///
/// 💡 Nel caso normale il confronto **non serve affatto**, e la regola diventa
/// esatta invece che probabile:
///
/// | Copia sul telefono | Chi vince |
/// |---|---|
/// | **pulita** (niente da spingere) | il server, sempre |
/// | **sporca** e il server non è cambiato | il telefono, sempre |
/// | **sporca** e anche il server è cambiato | ⚠️ conflitto vero: la più recente |
///
/// 🚨 Il terzo caso è raro — bisogna aver toccato la scheda **sul telefono e
/// dal pannello** fra due aperture dell'app — ed è l'unico in cui i due orologi
/// si incontrano. ⚠️ Lì la copia che perde **si tiene da parte**: buttarla
/// sarebbe di nuovo una modifica vera che sparisce senza che nessuno lo dica.
///
/// ── ⛔ Le schede del trainer non si spingono mai ──────────────────────────
///
/// `editable = false` → vince il server, sempre. 💡 Non è una scorciatoia: il
/// server le rifiuterebbe comunque con un 403, e fingere di poterle modificare
/// in locale creerebbe una copia divergente che non tornerebbe più indietro.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart' show ApiClient;
import '../../core/providers.dart';
import '../../core/storage/archivio_salute.dart';
import '../health/health_controller.dart';

/// Cosa ha fatto una sincronizzazione.
///
/// 💡 Non è decorazione: senza numeri, «ha funzionato» e «non ha trovato niente
/// da fare» si somigliano troppo, e sono due cose diverse quando qualcosa non
/// torna.
@immutable
class EsitoSincronizzazione {
  const EsitoSincronizzazione({
    this.tirate = 0,
    this.spinte = 0,
    this.conflitti = 0,
    this.tolte = 0,
    this.senzaRete = false,
  });

  /// Quante sono arrivate dal server.
  final int tirate;

  /// Quante sono state spinte al server.
  final int spinte;

  /// Quanti conflitti veri, cioè cambiate da tutte e due le parti.
  final int conflitti;

  /// Quante tolte dal telefono perché sul server non ci sono più.
  final int tolte;

  /// ⚠️ **Senza rete non è un errore.** È il caso per cui B.16 esiste: ci si
  /// allena lo stesso, con quello che c'è sul telefono.
  final bool senzaRete;

  bool get haFattoQualcosa =>
      tirate > 0 || spinte > 0 || conflitti > 0 || tolte > 0;

  @override
  String toString() =>
      'tirate=$tirate spinte=$spinte conflitti=$conflitti tolte=$tolte'
      '${senzaRete ? ' (senza rete)' : ''}';
}

class SincronizzaLeSchede {
  const SincronizzaLeSchede({required this.api, required this.archivio});

  final ApiClient api;
  final ArchivioSalute archivio;

  /// Tira, spinge, e risolve i conflitti veri.
  Future<EsitoSincronizzazione> gira() async {
    final List<dynamic> elenco;

    try {
      elenco = await api.get<List<dynamic>>('/workout-plans');
    } on Object catch (e) {
      /*
       * ⛔ **Senza rete non si tocca niente e non si urla.** 📌 *«potrei non
       * avere rete quando mi alleno»*: quello che c'è sul telefono resta buono,
       * e la sincronizzazione riproverà alla prossima apertura.
       */
      debugPrint('schede: il server non risponde — $e');

      return const EsitoSincronizzazione(senzaRete: true);
    }

    var tirate = 0;
    var spinte = 0;
    var conflitti = 0;

    final visti = <int>{};

    for (final riga in elenco) {
      final dati = (riga as Map).cast<String, dynamic>();
      final id = (dati['id'] as num).toInt();
      final quandoServer = _data(dati['updated_at']);
      final modificabile = dati['editable'] == true;

      visti.add(id);

      final locale = await archivio.schedaSulTelefono(id);

      // ── 1. Non ce l'abbiamo: si prende ────────────────────────────────
      if (locale == null) {
        if (await _tira(id, quandoServer, modificabile)) tirate++;

        continue;
      }

      final sporca = locale.modificataQuiIl != null;

      /*
       * ══ 🚨 SI CONFRONTANO GLI ISTANTI, NON I `DateTime` ════════════════
       *
       * ⛔ Difetto vero, preso da un test: `DateTime ==` in Dart e' `true` solo
       * se i due valori sono lo stesso istante **e** hanno lo stesso flag
       * `isUtc`. Drift rilegge le date in **ora locale**, il server le manda in
       * UTC: `!=` era **sempre** vero.
       *
       * ⚠️ La conseguenza sarebbe stata silenziosa e continua: ogni apertura
       * dell'app avrebbe riscaricato **tutte** le schede credendole cambiate —
       * e su una copia sporca avrebbe dichiarato un conflitto che non esiste,
       * mettendo da parte la copia locale a ogni avvio.
       */
      final cambiataSulServer = !_stessoIstante(
        locale.aggiornataIlServer,
        quandoServer,
      );

      // ── 2. Pulita: vince il server, sempre ────────────────────────────
      if (!sporca) {
        if (cambiataSulServer && await _tira(id, quandoServer, modificabile)) {
          tirate++;
        }

        continue;
      }

      /*
       * ── 3. Sporca ma non modificabile ─────────────────────────────────
       *
       * ⛔ Non dovrebbe capitare — l'app non lascia modificare le schede del
       * trainer — ma se capita **vince il server**: spingerla prenderebbe un
       * 403, e tenerla sporca per sempre vorrebbe dire non sincronizzarla mai
       * più. ⚠️ La copia locale si tiene da parte invece di sparire.
       */
      if (!modificabile) {
        await _tira(id, quandoServer, modificabile, scartata: locale.scheda);
        conflitti++;

        continue;
      }

      // ── 4. Sporca e il server è fermo: vince il telefono ──────────────
      if (!cambiataSulServer) {
        if (await _spingi(locale)) spinte++;

        continue;
      }

      /*
       * ── 5. Conflitto vero: cambiata da tutte e due le parti ───────────
       *
       * ⚠️ **Qui e solo qui i due orologi si incontrano.** Vince la più
       * recente, come chiesto — e la perdente si tiene da parte.
       */
      conflitti++;

      final vinceIlTelefono =
          quandoServer == null || locale.modificataQuiIl!.isAfter(quandoServer);

      if (vinceIlTelefono) {
        /*
         * ⛔ Si spinge **senza** dichiarare la base: la base non corrisponde
         * più, ed è proprio questo il caso in cui abbiamo deciso di vincere.
         * Dichiararla prenderebbe il 409 che noi stessi abbiamo messo.
         */
        if (await _spingi(locale, dichiaraLaBase: false)) spinte++;

        continue;
      }

      await _tira(id, quandoServer, modificabile, scartata: locale.scheda);
      tirate++;
    }

    /*
     * ⛔ Le sparite si tolgono **solo se pulite**: una scheda con modifiche non
     * spinte che sparisce dal server è un caso da guardare, non da eseguire.
     */
    final tolte = await archivio.togliSchedeSparite(visti);

    final esito = EsitoSincronizzazione(
      tirate: tirate,
      spinte: spinte,
      conflitti: conflitti,
      tolte: tolte,
    );

    debugPrint('schede: $esito');

    return esito;
  }

  /// Scarica il dettaglio e lo scrive sul telefono.
  Future<bool> _tira(
    int id,
    DateTime? quandoServer,
    bool modificabile, {
    String? scartata,
  }) async {
    try {
      final dettaglio = await api.get<Map<String, dynamic>>(
        '/workout-plans/$id',
      );

      await archivio.scriviSchedaDalServer(
        idServer: id,
        nome: dettaglio['name']?.toString() ?? 'Scheda',
        scheda: jsonEncode(dettaglio),
        aggiornataIlServer: _data(dettaglio['updated_at']) ?? quandoServer,
        modificabile: modificabile,
        scartata: scartata,
      );

      return true;
    } on Object catch (e) {
      // ⚠️ Una scheda che non si scarica non ferma le altre.
      debugPrint('schede: la $id non si scarica — $e');

      return false;
    }
  }

  /// Manda al server la copia del telefono.
  Future<bool> _spingi(
    SchedaDelServer locale, {
    bool dichiaraLaBase = true,
  }) async {
    try {
      final scheda = (jsonDecode(locale.scheda) as Map).cast<String, dynamic>();

      final risposta = await api.put<Map<String, dynamic>>(
        '/workout-plans/${locale.idServer}',
        body: {
          'name': locale.nome,
          'notes': scheda['notes'],
          'exercises': _esercizi(scheda),
          if (dichiaraLaBase && locale.aggiornataIlServer != null)
            'base_updated_at': locale.aggiornataIlServer!.toIso8601String(),
        },
      );

      await archivio.segnaSchedaSpinta(
        idServer: locale.idServer,
        aggiornataIlServer: _data(risposta['updated_at']),
        scheda: jsonEncode(risposta),
      );

      return true;
    } on Object catch (e) {
      /*
       * ⛔ **Se la spinta fallisce, la copia locale resta sporca.** È quello che
       * la fa riprovare alla prossima apertura invece di perdersi: un fallimento
       * che azzera il segno è un fallimento che cancella il lavoro.
       */
      debugPrint('schede: la ${locale.idServer} non si spinge — $e');

      return false;
    }
  }

  /// Gli esercizi nella forma che il server accetta.
  ///
  /// ⚠️ **Si manda il nome**, come fa già il resto dell'app: la riconciliazione
  /// è compito di `ExerciseMatcher`, e un id obbligatorio costringerebbe il
  /// telefono a creare l'esercizio prima, in due richieste che possono fallire
  /// a metà — cioè proprio quando si è senza campo.
  static List<Map<String, dynamic>> _esercizi(Map<String, dynamic> scheda) => [
    for (final e in (scheda['exercises'] as List? ?? const []))
      if (((e as Map)['exercise'] as Map?)?['name'] != null ||
          e['name'] != null)
        {
          'name':
              (e['exercise'] as Map?)?['name']?.toString() ??
              e['name'].toString(),
          'sets': e['sets'],
          'reps': e['reps'],
          'rest_sec': e['rest_sec'],
          'target_weight': e['target_weight'],
          'notes': e['notes'],
        },
  ];

  /// Se due istanti sono lo stesso momento, comunque siano scritti.
  ///
  /// ⚠️ Anche la **precisione** conta: Drift salva le date al secondo, il server
  /// le manda coi millisecondi. Confrontare senza troncare farebbe risultare
  /// diversa una scheda che nessuno ha toccato.
  static bool _stessoIstante(DateTime? a, DateTime? b) {
    if (a == null || b == null) return a == null && b == null;

    return a.toUtc().millisecondsSinceEpoch ~/ 1000 ==
        b.toUtc().millisecondsSinceEpoch ~/ 1000;
  }

  static DateTime? _data(Object? valore) {
    if (valore == null) return null;

    return DateTime.tryParse(valore.toString())?.toUtc();
  }
}

final sincronizzaLeSchedeProvider = Provider<SincronizzaLeSchede>(
  (ref) => SincronizzaLeSchede(
    api: ref.watch(apiClientProvider),
    archivio: ref.watch(archivioSaluteProvider),
  ),
);
