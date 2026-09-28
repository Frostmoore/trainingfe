/// ✉️ **Gli inviti che ho ricevuto** — voce 62.6, 28/09/2026.
///
/// ══ 📌 PERCHE' ESISTE ═════════════════════════════════════════════════════
///
/// ⛔ Fino al 28/09 un invito si poteva accettare **solo dal link nella mail**.
/// 🚨 Chi la perdeva non aveva nessuna strada — e il DMARC del dominio è in
/// `p=none` da ieri, quindi quelle mail possono finire nello spam.
///
/// 💡 Da qui l'app se li va a prendere da sola, e la notifica `invito` porta
/// qui invece che alla casa.
///
/// ══ 🔑 PERCHE' IL CODICE ARRIVA DA QUI E NON DALLA NOTIFICA ═══════════════
///
/// 🚨 Il codice di un invito è una **credenziale monouso**. ⛔ Nel carico di una
/// notifica passerebbe da Google e resterebbe nella memoria delle notifiche del
/// telefono. ✅ Qui invece passa dall'**API autenticata**, e solo a chi ha
/// **l'indirizzo verificato**.
///
/// ⚖️ È la differenza fra «ti do la chiave per strada» e «ti dico dove trovarla,
/// e te la do quando mi dimostri chi sei».
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';



/// Un invito ricevuto, come lo manda il server.
class InvitoRicevuto {
  const InvitoRicevuto({
    required this.tipo,
    required this.codice,
    required this.da,
    this.scadeIl,
  });

  factory InvitoRicevuto.fromJson(Map<String, dynamic> json) {
    final quando = json['scade_il']?.toString();

    return InvitoRicevuto(
      tipo: json['tipo']?.toString() == 'trainer'
          ? TipoDiInvito.trainer
          : TipoDiInvito.palestra,
      codice: json['codice']?.toString() ?? '',
      da: json['da']?.toString() ?? '',
      scadeIl: quando == null ? null : DateTime.tryParse(quando),
    );
  }

  final TipoDiInvito tipo;

  /// 🔑 Il codice monouso. ⚠️ **Non si scrive nei registri e non si mostra**:
  /// serve solo a comporre l'indirizzo della schermata che lo accetta.
  final String codice;

  /// Chi invita: il nome della palestra o del trainer.
  ///
  /// ⛔ **Non la sua email**: quella è un dato di un'altra persona, e non serve
  /// a chi deve decidere se accettare.
  final String da;

  final DateTime? scadeIl;

  /// ⏳ Quanti giorni mancano, arrotondati per difetto. `null` se non si sa.
  int? get giorniRimasti {
    final quando = scadeIl;

    if (quando == null) return null;

    return quando.difference(DateTime.now()).inDays;
  }
}

enum TipoDiInvito { palestra, trainer }

/// 📋 Gli inviti ancora validi mandati al mio indirizzo — `GET /inviti-ricevuti`.
///
/// ══ 🚨 IL 403 NON E' UN ERRORE: E' UNA RISPOSTA ═══════════════════════════
///
/// ⛔ La rotta pretende l'email **verificata**, perché consegna credenziali. 💡 Un
/// 403 qui vuol dire «devi confermare l'indirizzo», e la schermata lo sa
/// mostrare col bottone — invece di dire «qualcosa è andato storto», che manda a
/// cercare un problema che non c'è.
final invitiRicevutiProvider =
    FutureProvider.autoDispose<EsitoDegliInviti>((ref) async {
      try {
        final dati = await ref
            .watch(apiClientProvider)
            .get<List<dynamic>>('/inviti-ricevuti');

        return EsitoDegliInviti(
          inviti: dati
              .whereType<Map<String, dynamic>>()
              .map(InvitoRicevuto.fromJson)
              .toList(),
        );
      } on DioException catch (e) {
        /*
         * 🔑 **403 = «conferma l'indirizzo»**, e basta saperlo per mostrare la
         * cosa giusta. ⚠️ Ogni altro errore resta un errore: ⛔ trattarli tutti
         * come «devi verificare» manderebbe a controllare la posta chi ha solo
         * il telefono senza rete.
         */
        if (e.response?.statusCode == 403) {
          return const EsitoDegliInviti(serveVerificare: true);
        }

        rethrow;
      }
    });

/// Cosa è successo chiedendo gli inviti.
class EsitoDegliInviti {
  const EsitoDegliInviti({
    this.inviti = const [],
    this.serveVerificare = false,
  });

  final List<InvitoRicevuto> inviti;

  /// 🚨 `true` quando il server ha risposto **403**: l'indirizzo non è confermato.
  final bool serveVerificare;
}

/// 📧 «Mandami la mail di conferma» — `POST /auth/email/conferma`.
///
/// ⚠️ Risponde **sempre**, anche quando non manda niente (già verificata): 💡 il
/// campo `mandata` dice cosa è successo, e la schermata lo racconta.
Future<bool> chiediLaMailDiConferma(WidgetRef ref) async {
  try {
    final dati = await ref
        .read(apiClientProvider)
        .post<Map<String, dynamic>>('/auth/email/conferma');

    return dati['mandata'] == true;
  } on Object {
    /*
     * ⛔ Silenzio voluto: la schermata mostra «non è partita, riprova». 🚨 Il
     * limite di tentativi risponde 429, e dirlo con parole tecniche non aiuta
     * chi sta solo aspettando una mail.
     */
    return false;
  }
}
