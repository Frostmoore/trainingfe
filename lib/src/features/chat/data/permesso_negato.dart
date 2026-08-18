import 'package:dio/dio.dart';

/// Il «no» del cancello della chat, letto dalla risposta del server — M3.4.
///
/// ── 🚨 Perché non basta il messaggio d'errore generico ─────────────────────
///
/// «Messaggio non inviato. Riprova.» è la cosa **sbagliata** da dire a chi ha
/// finito i tre messaggi di presentazione: riproverà, fallirà di nuovo, e
/// concluderà che l'app è rotta. ⚠️ I «no» del cancello non sono tutti uguali,
/// e il server manda il motivo proprio perché qui si possa dire la cosa giusta.
class PermessoNegato {
  const PermessoNegato({
    required this.spiegazione,
    required this.proponiAbbonamento,
    this.codice,
  });

  /// Legge un `403` del cancello. Torna `null` se l'errore è **altro** — rete,
  /// server giù, `500` — perché in quel caso «riprova» è davvero la cosa giusta.
  static PermessoNegato? da(Object errore) {
    if (errore is! DioException) return null;

    final risposta = errore.response;

    /*
     * ⚠️ Solo `403`, e solo se porta il blocco `permesso`.
     *
     * 🚨 Un `403` senza quel blocco è un rifiuto di un'altra natura — una
     * policy, un token scaduto — e trattarlo come un diniego del cancello
     * mostrerebbe una spiegazione inventata su un problema diverso.
     */
    if (risposta?.statusCode != 403) return null;

    final corpo = risposta?.data;
    if (corpo is! Map) return null;

    final permesso = corpo['permesso'];
    if (permesso is! Map) return null;

    final spiegazione = permesso['spiegazione'] ?? corpo['message'];
    if (spiegazione is! String || spiegazione.isEmpty) return null;

    return PermessoNegato(
      spiegazione: spiegazione,

      /*
       * 🚨 Vero **solo** quando i tre messaggi sono finiti. Fuori da quel caso
       * non c'è niente da vendere: proporre l'abbonamento a chi non può
       * scrivere a un trainer dipendente sarebbe vendergli una cosa che non
       * risolve il suo problema.
       */
      proponiAbbonamento: permesso['proponi_abbonamento'] as bool? ?? false,
      codice: permesso['codice'] as String?,
    );
  }

  final String spiegazione;
  final bool proponiAbbonamento;
  final String? codice;
}
