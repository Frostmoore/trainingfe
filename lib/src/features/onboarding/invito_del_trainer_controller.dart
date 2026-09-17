import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

/// 🆕 L'invito di un **trainer**, dietro un link — F6.2, 17/09/2026.
///
/// ══ ⛔ PERCHE' NASCE OGGI, E NON CON F6.2 ═════════════════════════════════
///
/// 🚨 **Questo giro viveva sul server senza un cliente.** La pagina web diceva
/// *«apri l'app e tocca "Ho un invito"»*, e **quel pulsante non esisteva**:
/// `POST /inviti/{token}/riscatta` e `POST /auth/register-with-invite` erano
/// scritti, provati, documentati — e non li chiamava nessuno.
///
/// ⚠️ Trovato il 17/09 cercando dove mettere la modale della sovrapposizione
/// (AH.1-ter.4): non c'era **nessuna** schermata dove metterla.
///
/// ══ 🚨 E NON E' LO STESSO DI `invito_controller.dart` ═════════════════════
///
/// Quello è l'invito di una **palestra**: sposta una persona dentro
/// un'organizzazione. ⛔ Questo crea un legame fra **due persone**. Sembrano la
/// stessa cosa e non lo sono, ed è la stessa ragione per cui i due percorsi si
/// chiamano `/invito-palestra` e `/invito`.
class InvitoDelTrainer {
  const InvitoDelTrainer({required this.trainer, required this.scadeIl});

  factory InvitoDelTrainer.fromJson(Map<String, dynamic> json) =>
      InvitoDelTrainer(
        trainer: json['trainer']?.toString(),
        scadeIl: json['scade_il']?.toString(),
      );

  /// Chi ha mandato l'invito. `null` se il server non lo dice.
  final String? trainer;

  final String? scadeIl;
}

/// L'anteprima, **pubblica**: chi tocca il link spesso non ha ancora l'app.
final invitoDelTrainerProvider = FutureProvider.autoDispose
    .family<InvitoDelTrainer, String>((ref, token) async {
      final dati = await ref
          .watch(apiClientProvider)
          .get<Map<String, dynamic>>('/inviti/$token');

      return InvitoDelTrainer.fromJson(dati);
    });

/// Le due risposte a un invito di un trainer.
class RispostaAlTrainer {
  const RispostaAlTrainer(this._ref);

  final Ref _ref;

  /// Accetta l'invito.
  ///
  /// 🚨 **`affianco` non si manda di serie**, ed è il verso giusto: il server
  /// risponde 409 e si dice di sì **dopo** aver chiesto alla persona, non
  /// prima. ⛔ Mandarlo sempre vorrebbe dire creare la sovrapposizione senza che
  /// nessuno l'abbia scelta — cioè il difetto che il 409 esiste per impedire.
  ///
  /// 🚨 Lancia [TiSegueGiaQualcunoException] quando il server si ferma
  /// perché questa persona ha già un trainer: non è un errore, è una domanda.
  Future<String?> accetta(String token, {bool affianco = false}) async {
    final dati = await _ref
        .read(apiClientProvider)
        .post<Map<String, dynamic>>(
          '/inviti/$token/riscatta',
          body: affianco ? {'affianco': true} : null,
        );

    return (dati['trainer'] as Map?)?['name']?.toString();
  }
}

final rispostaAlTrainerProvider = Provider(RispostaAlTrainer.new);
