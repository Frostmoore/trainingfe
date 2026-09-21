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
    this.attivabile = false,
    this.inSospeso = false,
    this.siUsaPagando = false,
  });

  factory Offerta.fromJson(Map<String, dynamic> json) => Offerta(
    codice: json['codice']?.toString() ?? '',
    nome: json['nome']?.toString() ?? '',
    cosa: json['cosa']?.toString() ?? '',
    descrizione: json['descrizione']?.toString(),
    scadeIl: DateTime.tryParse(json['scade_il']?.toString() ?? '')?.toLocal(),
    attivabile: json['attivabile'] == true,
    inSospeso: json['in_sospeso'] == true,
    siUsaPagando: json['si_usa_pagando'] == true,
  );

  final String codice;
  final String nome;

  /// Cosa dà, già scritto dal server.
  final String cosa;
  final String? descrizione;
  final DateTime? scadeIl;

  /// È un'offerta **col link** che si può attivare adesso («Attiva»).
  ///
  /// ⛔ Niente codici sconto (24/09/2026): le offerte si attivano da sole o dal
  /// link. Le automatiche non hanno il tasto: arrivano da sole.
  final bool attivabile;

  /// È già attivata: lo sconto vale al prossimo pagamento, da solo.
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

/// L'offerta di un **link** aperto nell'app — `GET /promozioni/{codice}`.
///
/// ⛔ Non è un codice scritto a mano (24/09/2026): il codice arriva **dentro il
/// link** (`…/promo/{codice}`) o da una notifica. Restituisce l'offerta, oppure
/// il messaggio del server («Questo link non porta a nessuna offerta.», «Hai già
/// ricevuto questa offerta.»…).
Future<({Offerta? offerta, String? errore})> offertaDelLink(
  WidgetRef ref,
  String codice,
) async {
  try {
    final dati = await ref
        .read(apiClientProvider)
        .get<Map<String, dynamic>>(
          '/promozioni/${Uri.encodeComponent(codice.trim())}',
        );

    return (offerta: Offerta.fromJson(dati), errore: null);
  } on Object catch (e) {
    return (offerta: null, errore: ApiClient.unwrapError(e).message);
  }
}

/// «Attiva»: prende l'offerta di un link — `POST /promozioni/{codice}/attiva`.
///
/// I regali arrivano subito; lo sconto resta pronto e il prossimo pagamento lo
/// usa da solo (`scontoPronto`). Restituisce anche il messaggio del server.
Future<({int gettoni, bool scontoPronto, String? errore})> attiva(
  WidgetRef ref,
  String codice,
) async {
  try {
    final dati = await ref
        .read(apiClientProvider)
        .post<Map<String, dynamic>>(
          '/promozioni/${Uri.encodeComponent(codice.trim())}/attiva',
        );

    return (
      gettoni: (dati['gettoni'] as num?)?.toInt() ?? 0,
      scontoPronto: dati['sconto_pronto'] == true,
      errore: null,
    );
  } on Object catch (e) {
    return (
      gettoni: 0,
      scontoPronto: false,
      errore: ApiClient.unwrapError(e).message,
    );
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

/// 🔗 Il link di un'offerta aperto **prima dell'accesso**: la schermata delle
/// offerte lo ritrova dopo, invece di perderlo al login.
const chiaveOffertaInAttesa = 'promozioni.offerta_in_attesa';
