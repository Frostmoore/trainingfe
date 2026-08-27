/// Il listino, **chiesto al server** — 3b-H, 26/08/2026.
///
/// ══ ⛔ PRIMA I PREZZI ERANO SCRITTI DENTRO LA SCHERMATA ════════════════════
///
/// `schermata_acquisti.dart` diceva *«400 richieste al mese»* a mano, il
/// listino del server ne diceva **300** e il piano vero ne concedeva **450**.
/// 🚨 Tre numeri per la stessa cosa, e quello che il cliente leggeva era
/// l'unico che non si poteva correggere senza pubblicare sugli store.
///
/// 💡 Adesso l'app chiede: cambiare un prezzo è una riga di configurazione.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/providers.dart';

/// Un taglio di gettoni.
class PacchettoGettoni {
  const PacchettoGettoni({
    required this.gettoni,
    required this.prezzoCent,
    required this.nota,
  });

  factory PacchettoGettoni.fromJson(Map<String, dynamic> j) => PacchettoGettoni(
    gettoni: (j['gettoni'] as num?)?.toInt() ?? 0,
    prezzoCent: (j['prezzo_cent'] as num?)?.toInt() ?? 0,
    nota: j['nota']?.toString() ?? '',
  );

  final int gettoni;
  final int prezzoCent;
  final String nota;

  /// Quanto costa **un** gettone, in centesimi.
  ///
  /// 💡 È il numero che fa scegliere, e nessuno ha voglia di calcolarselo:
  /// «2.000 per 29,90» non dice niente, «1,5 centesimi l'uno» dice tutto.
  double get centPerGettone => gettoni == 0 ? 0 : prezzoCent / gettoni;
}

/// L'abbonamento in corso: quando scade, e cosa succede dopo.
///
/// ══ 🚨 LE DUE COSE INSIEME, O LA FRASE MENTE ══════════════════════════════
///
/// «Fino al 27 settembre» detto a chi si rinnova **suona come una scadenza** e
/// fa disdire per sbaglio. «Si rinnova il 27» detto a chi ha già disdetto è
/// peggio: gli dice che il gesto non è servito.
class AbbonamentoInCorso {
  const AbbonamentoInCorso({
    required this.finoAl,
    required this.rinnova,
    required this.gestibile,
  });

  static AbbonamentoInCorso? daJson(Object? j) {
    if (j is! Map) return null;

    final m = j.cast<String, dynamic>();

    return AbbonamentoInCorso(
      finoAl: DateTime.tryParse(m['fino_al']?.toString() ?? ''),
      rinnova: m['rinnova'] as bool? ?? false,
      gestibile: m['gestibile'] as bool? ?? false,
    );
  }

  /// ⚠️ `null` per gli abbonamenti che non scadono — quelli delle palestre.
  final DateTime? finoAl;

  final bool rinnova;

  /// Se c'è un cliente Stripe dietro, cioè se il portale ha senso.
  ///
  /// ⛔ Alle palestre il pulsante non deve comparire: aprirebbe una pagina
  /// vuota, e una pagina vuota si legge come un guasto.
  final bool gestibile;
}

/// Cosa si può comprare, e cosa si ha già.
class Listino {
  const Listino({
    required this.abbonato,
    required this.livello,
    required this.prezzoAbbonamentoCent,
    required this.chiamateMensili,
    required this.pacchetti,
    required this.gettoniDisponibili,
    this.inCorso,
  });

  factory Listino.fromJson(Map<String, dynamic> j) {
    final abbonamento =
        (j['abbonamento'] as Map?)?.cast<String, dynamic>() ?? const {};

    return Listino(
      abbonato: j['abbonato'] as bool? ?? false,
      livello: j['livello']?.toString() ?? 'free',
      prezzoAbbonamentoCent: (abbonamento['prezzo_cent'] as num?)?.toInt() ?? 0,
      chiamateMensili: (abbonamento['chiamate_mensili'] as num?)?.toInt() ?? 0,
      pacchetti: ((j['pacchetti'] as List?) ?? const [])
          .map((e) => PacchettoGettoni.fromJson((e as Map).cast()))
          .toList(),
      gettoniDisponibili: (j['gettoni_disponibili'] as num?)?.toInt() ?? 0,
      inCorso: AbbonamentoInCorso.daJson(j['abbonamento_attivo']),
    );
  }

  /// 🚨 **Decide cosa la schermata vende per primo.** Offrire l'abbonamento a
  /// chi ce l'ha già è il modo più rapido per fargli credere che non sia attivo.
  final bool abbonato;

  final String livello;
  final int prezzoAbbonamentoCent;
  final int chiamateMensili;
  final List<PacchettoGettoni> pacchetti;
  final int gettoniDisponibili;

  /// `null` se non c'è nessun abbonamento in corso.
  final AbbonamentoInCorso? inCorso;

  /// Il taglio con il prezzo per gettone più basso.
  ///
  /// ⚠️ Si **calcola**, non si marca a mano: il giorno che si aggiunge un taglio
  /// più grande, una scritta «il più conveniente» messa a mano resta sul
  /// vecchio.
  PacchettoGettoni? get ilPiuConveniente {
    if (pacchetti.isEmpty) return null;

    return pacchetti.reduce(
      (a, b) => a.centPerGettone <= b.centPerGettone ? a : b,
    );
  }
}

final listinoProvider = FutureProvider.autoDispose<Listino>((ref) async {
  final dati = await ref
      .watch(apiClientProvider)
      .get<Map<String, dynamic>>('/billing/listino');

  return Listino.fromJson(dati);
});

/// Cosa è andato storto aprendo il pagamento — o `null` se è andato bene.
///
/// 🚨 **Una stringa e non un `bool`**: chi chiama deve poter dire *cosa* non ha
/// funzionato. «Non è andata» su un pagamento fa chiudere l'app e non riprovare.
typedef EsitoPagamento = String?;

/// Apre il pagamento su Stripe, nel browser.
///
/// ══ ⚠️ PERCHE' IL BROWSER E NON UNA WEBVIEW ═══════════════════════════════
///
/// Perché è quello che chiede Stripe, ed è anche quello che chiede il buon
/// senso: in una webview dell'app **la barra dell'indirizzo non si vede**, e
/// chi sta per digitare il numero della carta non ha modo di verificare dove lo
/// sta scrivendo. 🚨 Un modulo di pagamento senza barra dell'indirizzo è
/// indistinguibile da una truffa, e insegnare alle persone che va bene così è
/// un danno che sopravvive a questa app.
Future<EsitoPagamento> apriIlPagamento(
  WidgetRef ref, {
  required String tipo,
  int? gettoni,
}) async {
  try {
    final risposta = await ref
        .read(apiClientProvider)
        .post<Map<String, dynamic>>(
          '/billing/checkout',
          body: {'tipo': tipo, 'gettoni': ?gettoni},
        );

    final url = Uri.tryParse(risposta['url']?.toString() ?? '');

    if (url == null) return 'Il pagamento non si è aperto. Riprova fra poco.';

    final partito = await launchUrl(url, mode: LaunchMode.externalApplication);

    return partito ? null : 'Non sono riuscito ad aprire il browser.';
  } on Object catch (errore) {
    /*
     * ⛔ **L'errore vero non si mostra e non si ingoia: si dice a modo.** Quello
     * di rete può contenere l'indirizzo del server e la traccia della richiesta,
     * che a chi guarda non servono; ma un `catch` muto qui lascerebbe una
     * persona con il dito su un pulsante che non fa niente.
     */
    return errore.toString().contains('409')
        ? 'Hai già un abbonamento attivo.'
        : 'Il pagamento non si è aperto. Riprova fra poco.';
  }
}

/// Apre il **portale di Stripe**: disdetta, carta, ricevute — 3b-H.9.
///
/// ⛔ **Non è il posto dove si disdice: è il posto dove si va a disdire.** Tutto
/// quello che succede là dentro torna indietro dai webhook, non da qui — ed è
/// il motivo per cui al ritorno il listino si ributta via e si richiede.
Future<EsitoPagamento> apriIlPortale(WidgetRef ref) async {
  try {
    final risposta = await ref
        .read(apiClientProvider)
        .post<Map<String, dynamic>>('/billing/portale');

    final url = Uri.tryParse(risposta['url']?.toString() ?? '');

    if (url == null) return 'Non sono riuscito ad aprire la gestione.';

    final partito = await launchUrl(url, mode: LaunchMode.externalApplication);

    return partito ? null : 'Non sono riuscito ad aprire il browser.';
  } on Object {
    return 'Non sono riuscito ad aprire la gestione. Riprova fra poco.';
  }
}

/// I centesimi in euro, come si scrivono in Italia.
///
/// 🚨 **Sta con i prezzi e non con i widget**: è il modo in cui un numero di
/// questo file diventa leggibile, e chi ne aggiunge un altro deve trovarla qui
/// invece di riscriversela nella sua schermata.
String euro(int cent) => NumberFormat.currency(
  locale: 'it',
  symbol: '€',
  decimalDigits: 2,
).format(cent / 100).trim();
