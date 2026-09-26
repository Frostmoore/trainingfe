import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import 'social_sign_in.dart';

/// 🔑 **Con cosa si può entrare** — voce 25, 26/09/2026.
///
/// ══ ⛔ IL DIFETTO CHE QUESTO FILE CHIUDE ═══════════════════════════════════
///
/// 🚨 L'elenco dei fornitori viaggiava **solo** dentro `GymBranding.social`, e
/// il branding arriva con l'accesso o con l'invito — cioè **dopo**. ⛔ Chi
/// apriva l'app per la prima volta aveva `GymBranding.neutral`, il cui elenco
/// è vuoto per costruzione, e i pulsanti «Continua con Google» non comparivano
/// **mai**.
///
/// ⚠️ **Non è sempre stato così.** C'era una rotta pubblica
/// (`GET branding/lookup?code=`) che l'app chiamava prima della schermata
/// d'accesso; è stata tolta con **F11 il 24/09/2026** insieme al codice
/// palestra. 🚨 E nessuno se n'è accorto per due giorni, perché l'accesso
/// social era comunque spento: il sintomo del difetto era **identico** al
/// comportamento atteso.
///
/// 💡 Ora la domanda ha una rotta sua, pubblica: `GET /auth/fornitori`.
///
/// ══ ⚠️ SI FALLISCE CHIUSI, NON APERTI ══════════════════════════════════════
///
/// ⛔ Se la richiesta non riesce — rete assente, server giù — **non si disegna
/// niente**. 🚨 Disegnare i pulsanti «per ottimismo» vorrebbe dire offrire una
/// strada che poi fallisce, e un pulsante che fallisce fa sembrare rotta tutta
/// l'applicazione, non solo quel pulsante.
///
/// 💡 E chi è offline non può comunque accedere con Google: non gli si toglie
/// niente.
final fornitoriSocialProvider = FutureProvider<List<String>>((ref) async {
  final api = ref.watch(apiClientProvider);

  try {
    /*
     * 🚨 **Una lista, non una mappa — e ci sono cascato.**
     *
     * ⛔ `ApiClient.get` **srotola già** l'involucro `data` (c'è un test che
     * si chiama *«srotola `data` senza che il chiamante debba saperlo»*).
     * Quindi qui arriva `["google","apple"]`, non `{"data": [...]}`.
     *
     * ⚠️ Chiedendo una `Map<String, dynamic>` il cast falliva, l'errore
     * finiva nel `catch` qui sotto, e l'app si comportava **esattamente come
     * se il server non avesse risposto**: nessun pulsante, nessun messaggio.
     * 💡 Il server invece rispondeva 200 — si è scoperto solo guardando il
     * suo log di accesso.
     */
    final risposta = await api.get<List<dynamic>>('/auth/fornitori');

    return leggiIFornitori(risposta);
  } on Object catch (errore) {
    /*
     * ⚠️ Nessun rilancio: l'assenza di pulsanti è una risposta valida, e un
     * errore a schermo per una funzione facoltativa sarebbe peggio.
     *
     * 🚨 **Ma in sviluppo si dice.** ⛔ Senza questa riga, un difetto di
     * programmazione — un tipo sbagliato, un percorso storto — è
     * indistinguibile da «il server non risponde». È successo il 26/09, ed è
     * costato la diagnosi più lunga della giornata.
     */
    if (kDebugMode) debugPrint('Fornitori social non letti: $errore');

    return const [];
  }
});

/// 🧪 **La lettura della risposta, da sola.**
///
/// 💡 Separata dal provider apposta: è l'unica parte che si può provare senza
/// un server, ed è quella dove si sbaglia.
///
/// 🚨 **Si tengono solo i fornitori che l'app conosce.** ⛔ Il server potrebbe
/// un giorno dichiararne uno nuovo: una versione vecchia dell'app non saprebbe
/// disegnarne il pulsante né gestirne l'accesso, e mostrarlo sarebbe peggio
/// che ignorarlo.
List<String> leggiIFornitori(Object? data) {
  if (data is! List) return const [];

  return data
      .map((e) => e?.toString() ?? '')
      .where(SocialProviderId.esiste)
      .toList(growable: false);
}
