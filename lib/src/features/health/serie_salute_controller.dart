import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../privacy/consensi_controller.dart';
import 'dati_salute.dart';
import 'health_controller.dart';

/// La serie giornaliera di una metrica, per il grafico.
///
/// 🚨 **Passa dallo stesso cancello del resto**: senza il consenso sanitario
/// non si legge niente e il grafico resta vuoto. Sarebbe assurdo che revocando
/// il consenso sparisse la scheda Recupero e restasse un grafico con dentro gli
/// stessi dati.
///
/// ⚠️ Dipende da `healthControllerProvider` per ricalcolarsi quando il ponte
/// scrive: senza, collegare Health Connect non aggiornerebbe il grafico fino al
/// riavvio dell'app.
final serieSaluteProvider = FutureProvider.autoDispose
    .family<List<MediaGiornaliera>, MetricaSalute>((ref, metrica) async {
      // 🚨 Tutte le `ref.watch` prima del primo `await`: dopo una pausa
      // asincrona non registrano più la dipendenza. Vedi `recuperoProvider`.
      final consenso = ref.watch(consensoSaluteProvider.future);
      final archivio = ref.watch(archivioSaluteProvider);

      ref.watch(healthControllerProvider);

      if (!await consenso) return const [];

      return archivio.mediePerGiorno(metrica);
    });
