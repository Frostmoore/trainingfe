import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

/// Lo stato dei consensi — S9.1.
///
/// 🚨 **Sono date, non booleani, e arrivano così anche all'app.** L'art. 7(1)
/// chiede di poter dimostrare che il consenso è stato dato; qui servono anche a
/// dire *«concesso il 12 agosto»* invece di una spunta muta — chi riapre questa
/// schermata sta cercando di ricordarsi cosa ha deciso e quando.
class Consensi {
  const Consensi({this.salute, this.ai});

  factory Consensi.fromJson(Map<String, dynamic> j) => Consensi(
    salute: DateTime.tryParse(j['health']?.toString() ?? ''),
    ai: DateTime.tryParse(j['ai']?.toString() ?? ''),
  );

  /// Quando è stato concesso, oppure `null` se non lo è.
  final DateTime? salute;
  final DateTime? ai;

  bool get saluteDato => salute != null;

  bool get aiDato => ai != null;
}

final consensiProvider = FutureProvider<Consensi>((ref) async {
  final data = await ref
      .watch(apiClientProvider)
      .get<Map<String, dynamic>>('/account/consents');

  return Consensi.fromJson(data);
});

/// Concede o revoca.
///
/// 🚨 **Revocare costa esattamente quanto concedere** (art. 7(3)): la stessa
/// chiamata, lo stesso campo, `false` invece di `true`. Un consenso che si dà
/// con un tocco e si toglie scrivendo un'email non è liberamente revocabile —
/// e quindi, a rigore, non è mai stato valido.
final cambiaConsensoProvider =
    Provider<Future<void> Function(String, bool)>((ref) {
      return (String quale, bool dato) async {
        await ref
            .read(apiClientProvider)
            .patch<Map<String, dynamic>>(
              '/account/consents',
              body: {quale: dato},
            );

        ref.invalidate(consensiProvider);
      };
    });
