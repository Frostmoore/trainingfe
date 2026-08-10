import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/ui/foto_protetta.dart';
import 'package:training_companion/src/features/progress/progress_controller.dart';

/// Le immagini che vogliono il token.
///
/// 🚨 **Il test del difetto della foto invisibile.**
///
/// `/photos/{id}/file` risponde 401 senza intestazione, e il token si legge dal
/// Keychain — cioè in modo **asincrono**. Chi scriveva
/// `httpHeaders: ...valueOrNull ?? const {}` faceva partire la prima richiesta
/// **senza token**, prendeva 401, e `CachedNetworkImage` si teneva l'errore:
/// quando il token arrivava un istante dopo, non riprovava più. Riquadro rotto
/// permanente, con il file perfettamente presente sul server.
///
/// La regola che questi test bloccano: **nessuna richiesta finché il token non
/// c'è**.
void main() {
  Widget conProvider(Override override) => ProviderScope(
    overrides: [override],
    child: const MaterialApp(
      home: Scaffold(
        body: FotoProtetta(url: 'https://esempio.test/foto/1', width: 100, height: 100),
      ),
    ),
  );

  testWidgets('finché il token non è pronto non parte nessuna richiesta', (tester) async {
    // Un futuro che non si completa: è lo stato in cui si trova l'app nei
    // millisecondi in cui legge il Keychain.
    final maiPronto = Completer<Map<String, String>>();

    await tester.pumpWidget(
      conProvider(
        progressAuthHeaderProvider.overrideWith((ref) => maiPronto.future),
      ),
    );
    await tester.pump();

    expect(
      find.byType(CachedNetworkImage),
      findsNothing,
      reason: 'Senza token la richiesta prenderebbe 401, e quel 401 resterebbe '
          'in cache anche dopo l\'arrivo del token.',
    );

    // Il segnaposto c'è: il buco non si lascia mai.
    expect(find.byType(Container), findsWidgets);
  });

  testWidgets('con il token pronto l\'immagine si costruisce', (tester) async {
    await tester.pumpWidget(
      conProvider(
        progressAuthHeaderProvider.overrideWith(
          (ref) async => {'Authorization': 'Bearer token-finto'},
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CachedNetworkImage), findsOneWidget);

    final immagine = tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));

    expect(immagine.httpHeaders?['Authorization'], 'Bearer token-finto');
  });

  /// ⚠️ Un utente senza token (mai successo in pratica, ma il provider può
  /// restituire una mappa vuota) non deve far partire una richiesta destinata
  /// a un 401 memorizzato.
  testWidgets('una mappa vuota è comunque un token: si prova', (tester) async {
    await tester.pumpWidget(
      conProvider(progressAuthHeaderProvider.overrideWith((ref) async => const {})),
    );
    await tester.pump();

    // Qui la scelta è deliberata: `{}` significa «letto, e non c'è nessun
    // token» — cioè sessione assente. Provare e fallire è corretto; è il
    // `null` (ancora in lettura) che non deve produrre richieste.
    expect(find.byType(CachedNetworkImage), findsOneWidget);
  });
}
