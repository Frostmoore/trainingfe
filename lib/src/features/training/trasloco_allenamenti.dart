import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/providers.dart';
import '../../core/storage/archivio_salute.dart';
import '../../core/storage/local_cache.dart';
import '../health/health_controller.dart';

/// Il trasloco degli allenamenti dal server al telefono — FASE 11.3,
/// 21/08/2026.
///
/// ══ 🚨 GIRA UNA VOLTA SOLA, E NON DEVE FALLIRE A METÀ ═════════════════════
///
/// 📌 Il committente: *«Nessun allenamento deve risiedere sul server, devono
/// stare tutti nell'app»*.
///
/// ⚠️ **I dati sul server sono l'unica copia esistente** di mesi di
/// allenamenti. 🚨 Quindi la sequenza non è «scarico e cancello», è:
///
/// | Passo | Cosa | Se va male |
/// |---|---|---|
/// | 1 | scarica il pacchetto | si riprova al prossimo avvio |
/// | 2 | scrive **in transazione** | l'archivio resta com'era |
/// | 3 | **riconta** quello che ha scritto | non dichiara niente |
/// | 4 | dichiara al server | il server verifica e può rifiutare |
///
/// ⛔ **Il passo 3 non è pedanteria.** Fra «ho scritto» e «ho scritto tutto» c'è
/// la differenza fra un trasloco riuscito e una perdita di dati che nessuno
/// vede: le righe sparirebbero dal server e nessuno saprebbe che non sono
/// arrivate.
///
/// ── 💡 Perché i dati sono ancora in due posti ────────────────────────────
///
/// Dopo questo trasloco le sedute stanno **sia** sul telefono **sia** sul
/// server: il server cancella solo in 11.6, quando tutti hanno confermato.
/// ⚠️ Finché dura, il player continua a scrivere di là (11.4 non è fatta) — e
/// va bene: chi ha già migrato riscaricherà le sedute nuove alla prossima
/// passata, perché `idServer` impedisce i doppioni.
class TraslocoAllenamenti {
  const TraslocoAllenamenti(this._api, this._archivio, this._cache);

  final ApiClient _api;
  final ArchivioSalute _archivio;
  final LocalCache _cache;

  /// 💡 Sul telefono, non sul server: evita **una chiamata a ogni avvio** a chi
  /// ha già traslocato. ⚠️ Non è la verità — quella è `workouts_migrated_at` di
  /// là — è solo un modo per non chiederla.
  static const chiaveFatto = 'trasloco.allenamenti.fatto';

  /// Fa il trasloco se serve. Non lancia mai.
  ///
  /// 🚨 **Non lancia** perché gira all'avvio: un trasloco che fa fallire
  /// l'apertura dell'app sarebbe peggio del problema che risolve, e non ci
  /// sarebbe nessun modo di rimediare se non disinstallando.
  Future<bool> seServe() async {
    if (_cache.getString(chiaveFatto) == '1') return false;

    try {
      final fatto = await _esegui();

      if (fatto) await _cache.setString(chiaveFatto, '1');

      return fatto;
    } on Object catch (e) {
      /*
       * ⚠️ Il `debugPrint` non è decorazione: una ricaduta silenziosa qui
       * vorrebbe dire un trasloco che non avviene mai e nessuno che se ne
       * accorge, finché non si va a cercare perché lo storico è vuoto.
       */
      debugPrint('trasloco allenamenti: non riuscito, si riprova — $e');

      return false;
    }
  }

  Future<bool> _esegui() async {
    final stato = await _api.get<Map<String, dynamic>>(
      '/migrazione/allenamenti/stato',
    );

    if (stato['migrated'] == true) return true;

    final pacchetto = await _api.get<Map<String, dynamic>>(
      '/migrazione/allenamenti',
    );

    final sessioni = ((pacchetto['sessions'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();
    final bruciate = ((pacchetto['daily_burns'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();

    /*
     * 🚨 **Tutto dentro una transazione.** A metà strada l'archivio avrebbe
     * sedute senza le loro serie: nessun errore, uno storico con volumi
     * sbagliati, e nessun modo di distinguerlo da chi si è allenato senza
     * segnare i pesi.
     */
    await _archivio.transaction(() async {
      for (final s in sessioni) {
        await _scriviSeduta(s);
      }

      for (final b in bruciate) {
        final giorno = DateTime.tryParse(b['date']?.toString() ?? '');
        final kcal = (b['kcal'] as num?)?.toInt();

        if (giorno == null || kcal == null) continue;

        await _archivio.dichiaraBruciate(giorno, kcal);
      }
    });

    /*
     * ⛔ **I conteggi si rileggono DALL'ARCHIVIO**, non dal pacchetto.
     *
     * ⚠️ Contare quello che si è ricevuto proverebbe che il server ha mandato
     * qualcosa, non che il telefono l'abbia scritto. 🚨 È la differenza fra un
     * controllo e un rito.
     */
    final scritte = await _archivio.conteggiDelTrasloco();

    await _api.post<Map<String, dynamic>>(
      '/migrazione/allenamenti/fatta',
      body: {'counts': scritte},
    );

    return true;
  }

  Future<void> _scriviSeduta(Map<String, dynamic> s) async {
    final idServer = (s['id'] as num?)?.toInt();
    final inizio = DateTime.tryParse(s['started_at']?.toString() ?? '');

    // ⛔ Senza questi due non si può né scrivere né riconoscere: si salta, e il
    // conteggio non tornerà — che è il comportamento voluto.
    if (idServer == null || inizio == null) return;

    final sedutaId = await _archivio.importaSeduta(
      idServer: idServer,
      schedaServerId: (s['plan_id'] as num?)?.toInt(),
      nomeScheda: s['plan_name']?.toString(),
      iniziataIl: inizio,
      finitaIl: DateTime.tryParse(s['ended_at']?.toString() ?? ''),
      kcal: (s['kcal'] as num?)?.toInt(),
      kcalAMano: s['kcal_manual'] == true,
    );

    for (final r
        in ((s['sets'] as List?) ?? const []).cast<Map<String, dynamic>>()) {
      final esercizioId = (r['exercise_id'] as num?)?.toInt();
      final numero = (r['set_number'] as num?)?.toInt();

      if (esercizioId == null || numero == null) continue;

      await _archivio.registraSerie(
        SerieDelleSeduteCompanion.insert(
          sedutaId: sedutaId,
          esercizioId: esercizioId,
          nomeEsercizio: r['exercise_name']?.toString() ?? 'Esercizio',
          met: Value((r['met'] as num?)?.toDouble()),
          numero: numero,
          ripetizioni: Value((r['reps'] as num?)?.toInt()),
          pesoKg: Value((r['weight'] as num?)?.toDouble()),
          durataSec: Value((r['duration_sec'] as num?)?.toInt()),
          riposoSec: Value((r['rest_sec'] as num?)?.toInt()),
          fattaIl: Value(DateTime.tryParse(r['done_at']?.toString() ?? '')),
        ),
      );
    }
  }
}

final traslocoAllenamentiProvider = Provider<TraslocoAllenamenti>(
  (ref) => TraslocoAllenamenti(
    ref.watch(apiClientProvider),
    ref.watch(archivioSaluteProvider),
    ref.watch(localCacheProvider),
  ),
);
