import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';

/// 🎁 **Un'offerta, come la racconta il server** — 24/09/2026, P8 di
/// `plan_promozioni.md`.
///
/// ⚠️ **Il conto non lo fa l'app.** `cosa` è già scritto dal server («20% su
/// tutti i pacchetti», «+100 gettoni»): lo sconto vero lo decide il server al
/// pagamento, e un numero calcolato qui sarebbe un secondo conto che un giorno
/// dice una cifra diversa.
class Offerta {
  const Offerta({
    required this.codice,
    required this.nome,
    required this.cosa,
    this.descrizione,
    this.scadeIl,
    this.riscattabile = false,
    this.inSospeso = false,
    this.siUsaPagando = false,
  });

  factory Offerta.fromJson(Map<String, dynamic> json) => Offerta(
    codice: json['codice']?.toString() ?? '',
    nome: json['nome']?.toString() ?? '',
    cosa: json['cosa']?.toString() ?? '',
    descrizione: json['descrizione']?.toString(),
    scadeIl: DateTime.tryParse(json['scade_il']?.toString() ?? '')?.toLocal(),
    riscattabile: json['riscattabile'] == true,
    inSospeso: json['in_sospeso'] == true,
    siUsaPagando: json['si_usa_pagando'] == true,
  );

  final String codice;
  final String nome;

  /// Cosa dà, già scritto dal server.
  final String cosa;
  final String? descrizione;
  final DateTime? scadeIl;

  /// Ha dei regali che si possono prendere adesso («Riscatta»).
  final bool riscattabile;

  /// È già tua: uno sconto che vale al prossimo pagamento, senza codice.
  final bool inSospeso;

  /// Ha uno sconto o un bonus che vale pagando.
  final bool siUsaPagando;
}

/// Le offerte di questa persona: `GET /promozioni`.
///
/// 💡 Si ributta via dopo un riscatto o un pagamento: quello che si vede viene
/// dal server, non da cosa abbiamo appena toccato.
final offertePerTeProvider = FutureProvider.autoDispose<List<Offerta>>((
  ref,
) async {
  final dati = await ref
      .watch(apiClientProvider)
      .get<List<dynamic>>('/promozioni');

  return dati.whereType<Map<String, dynamic>>().map(Offerta.fromJson).toList();
});

/// «Hai un codice?»: vale per me? — `POST /promozioni/verifica`.
///
/// Restituisce l'offerta, oppure il messaggio del server («Questo codice non
/// esiste.», «Hai già ricevuto questa offerta.»…): ⛔ mai un «non valido»
/// generico, che fa arrivare tutte le telefonate uguali.
Future<({Offerta? offerta, String? errore})> verificaIlCodice(
  WidgetRef ref,
  String codice,
) async {
  try {
    final dati = await ref
        .read(apiClientProvider)
        .post<Map<String, dynamic>>(
          '/promozioni/verifica',
          body: {'codice': codice.trim()},
        );

    return (offerta: Offerta.fromJson(dati), errore: null);
  } on Object catch (e) {
    return (offerta: null, errore: ApiClient.unwrapError(e).message);
  }
}

/// «Riscatta»: prende i regali di un'offerta — `POST /promozioni/{codice}/riscatta`.
///
/// Restituisce i gettoni ricevuti, oppure il messaggio del server.
Future<({int gettoni, String? errore})> riscatta(
  WidgetRef ref,
  String codice,
) async {
  try {
    final dati = await ref
        .read(apiClientProvider)
        .post<Map<String, dynamic>>(
          '/promozioni/${Uri.encodeComponent(codice.trim())}/riscatta',
        );

    return (gettoni: (dati['gettoni'] as num?)?.toInt() ?? 0, errore: null);
  } on Object catch (e) {
    return (gettoni: 0, errore: ApiClient.unwrapError(e).message);
  }
}

/// 🤝 Il mio codice «porta un amico».
class IlMioCodiceAmico {
  const IlMioCodiceAmico({
    required this.codice,
    required this.link,
    required this.amici,
  });

  final String codice;
  final String link;

  /// Quanti amici si sono iscritti col mio codice.
  final int amici;
}

/// `GET /account/amico`.
final ilMioCodiceAmicoProvider = FutureProvider.autoDispose<IlMioCodiceAmico>((
  ref,
) async {
  final dati = await ref
      .watch(apiClientProvider)
      .get<Map<String, dynamic>>('/account/amico');

  return IlMioCodiceAmico(
    codice: dati['codice']?.toString() ?? '',
    link: dati['link']?.toString() ?? '',
    amici: (dati['amici'] as num?)?.toInt() ?? 0,
  );
});

/// «Mi ha portato lui» — `POST /account/amico`.
///
/// ⚠️ Il server lo accetta **una volta sola e nei primi 7 giorni** dopo
/// l'iscrizione: per questo l'app lo manda **subito dopo** la registrazione.
/// Restituisce `null` se è andato, altrimenti il messaggio del server.
///
/// ⚠️ Prende il **client** e non un `WidgetRef`: la registrazione lo chiama
/// quando il router potrebbe aver già chiuso la sua schermata, e un `ref` di un
/// widget chiuso non si può più usare.
Future<String?> collegaLAmico(ApiClient api, String codice) async {
  try {
    await api.post<Map<String, dynamic>>(
      '/account/amico',
      body: {'codice': codice.trim().toUpperCase()},
    );

    return null;
  } on Object catch (e) {
    return ApiClient.unwrapError(e).message;
  }
}

/// 🔗 Il codice amico arrivato da un link, **in attesa** dell'iscrizione.
///
/// 💡 Nella cache locale e non in un provider: deve sopravvivere al passaggio
/// dal link alla registrazione, anche se l'app viene chiusa in mezzo.
const chiaveCodiceAmicoInAttesa = 'promozioni.codice_amico_in_attesa';
