import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/providers.dart';
import '../../core/storage/archivio_salute.dart';
import '../../core/storage/local_cache.dart';
import '../health/health_controller.dart';
import 'data/profilo_sul_telefono.dart';

/// 📦 **Il profilo viene a casa** — 19/09/2026.
///
/// ══ 📌 PERCHÉ ════════════════════════════════════════════════════════════
///
/// 📌 Il committente: *«assicurati che non ci scriva niente di personale
/// (esattamente come peso altezza e data di nascita)»*. ⛔ Fino al 19/09
/// sesso, data di nascita, altezza, livello di attività, obiettivo, peso
/// obiettivo e orari dei pasti stavano sul server.
///
/// ══ 🚨 PRIMA SUL TELEFONO, POI VIA DAL SERVER — MAI IL CONTRARIO ══════════
///
/// È la stessa regola del trasloco del diario: *«la differenza fra "i dati
/// sono stati spostati" e "i dati sono stati persi"»*.
///
/// 1. `GET /profile` — quello che il server sa;
/// 2. si scrive sul telefono **senza** coprire quello che c'è già;
/// 3. si **rilegge**: se un campo non è arrivato, ci si ferma e non si
///    cancella niente;
/// 4. solo allora `DELETE /profile`;
/// 5. e si ricorda, **per quella persona**, che è fatto.
///
/// ⚠️ Una cosa qualunque va storta → si riprova al prossimo accesso. Non
/// solleva mai: torna un esito.
enum EsitoTraslocoProfilo { fatto, giaFatto, nienteDaPortare, nonTorna, rete }

class TraslocoDelProfilo {
  const TraslocoDelProfilo(this._api, this._archivio, this._cache);

  final ApiClient _api;
  final ArchivioSalute _archivio;
  final LocalCache _cache;

  /// ⚠️ **Per persona**: sullo stesso telefono possono entrare due account.
  static String chiave(int utenteId) => 'trasloco_profilo_$utenteId';

  /// I campi che vengono a casa.
  static const campi = [
    'sex',
    'birthdate',
    'height_cm',
    'activity_level',
    'goal',
    'target_weight_kg',
  ];

  Future<EsitoTraslocoProfilo> porta(int utenteId) async {
    if (_cache.getString(chiave(utenteId)) == 'fatto') {
      return EsitoTraslocoProfilo.giaFatto;
    }

    try {
      final dati = await _api.get<Map<String, dynamic>>('/profile');

      final daPortare = <String, dynamic>{
        for (final c in campi)
          if (dati[c] != null) c: dati[c],
      };

      /*
       * ⚠️ **Gli orari solo se diversi da quelli di serie.** Il server
       * risponde sempre con tutti e sei, riempiendo i vuoti: copiarli tutti
       * vorrebbe dire scrivere come «scelti» orari che nessuno ha scelto.
       */
      final orari = (dati['meal_hours'] as Map?)?.cast<String, dynamic>() ?? {};
      final scelti = {
        for (final o in orari.entries)
          if (orariDiSerie[o.key] != null &&
              orariDiSerie[o.key] != '${o.value}')
            o.key: '${o.value}',
      };

      if (scelti.isNotEmpty) daPortare['meal_hours'] = scelti;

      if (daPortare.isNotEmpty) {
        await _archivio.scriviNelProfilo(
          utenteId,
          daPortare,
          soloSeMancano: true,
        );

        // 🚨 Si rilegge: se un campo non c'è, dal server non si cancella niente.
        final scritto = await _archivio.leggiProfilo(utenteId);

        for (final c in daPortare.keys) {
          if (scritto[c] == null) {
            debugPrint('trasloco del profilo: «$c» non è arrivato');

            return EsitoTraslocoProfilo.nonTorna;
          }
        }
      }

      await _api.delete('/profile');
      await _cache.setString(chiave(utenteId), 'fatto');

      return daPortare.isEmpty
          ? EsitoTraslocoProfilo.nienteDaPortare
          : EsitoTraslocoProfilo.fatto;
    } on Object catch (e) {
      debugPrint('trasloco del profilo: si riprova — $e');

      return EsitoTraslocoProfilo.rete;
    }
  }
}

final traslocoDelProfiloProvider = Provider<TraslocoDelProfilo>(
  (ref) => TraslocoDelProfilo(
    ref.watch(apiClientProvider),
    ref.watch(archivioSaluteProvider),
    ref.watch(localCacheProvider),
  ),
);
