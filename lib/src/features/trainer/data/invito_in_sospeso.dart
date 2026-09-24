/// 📨 **Un invito ancora in piedi** — blocco B1, 24/09/2026.
///
/// ══ 🚨 PERCHE' QUESTA CLASSE NON ESISTEVA ════════════════════════════════════
///
/// ⛔ Perché **un invito creato dall'app spariva**: il link finiva negli appunti
/// e da quel momento non stava più da nessuna parte. Non c'era niente da
/// modellare, perché non c'era niente da rivedere.
///
/// ⚠️ E il costo non era estetico: un invito valido **tiene un posto del piano**
/// finché non scade. Chi copiava qualcos'altro prima di incollarlo si ritrovava
/// un posto occupato per sette giorni, senza un modo di liberarlo.
class InvitoInSospeso {
  const InvitoInSospeso({
    required this.id,
    required this.url,
    required this.scadeIl,
    this.email,
    this.emailInviataIl,
    this.creatoIl,
  });

  factory InvitoInSospeso.fromJson(Map<String, dynamic> json) =>
      InvitoInSospeso(
        id: (json['id'] as num).toInt(),
        url: json['url']?.toString() ?? '',
        email: json['email']?.toString(),
        emailInviataIl: DateTime.tryParse(
          json['email_inviata_il']?.toString() ?? '',
        )?.toLocal(),
        creatoIl: DateTime.tryParse(
          json['creato_il']?.toString() ?? '',
        )?.toLocal(),
        scadeIl:
            DateTime.tryParse(json['scade_il']?.toString() ?? '')?.toLocal() ??
            DateTime.now(),
      );

  final int id;
  final String url;

  /// A chi si voleva mandarlo. `null` = invito da copiare a mano.
  final String? email;

  /// 🚨 **Quando è partita la mail — non «se c'era un indirizzo».**
  ///
  /// ⚠️ Sono due cose diverse: l'invio può fallire (trasporto giù, indirizzo
  /// rifiutato) e in quel caso l'invito **resta valido di proposito**, perché il
  /// link esiste e chi invita ce l'ha. 💡 Con questa data la schermata può dire
  /// *«mandata»* solo quando è vero, invece di dirlo sempre o mai.
  final DateTime? emailInviataIl;

  final DateTime? creatoIl;
  final DateTime scadeIl;

  bool get mandatoPerEmail => emailInviataIl != null;

  /// Quanti giorni mancano, arrotondati per eccesso.
  ///
  /// 💡 «Scade fra 1 giorno» è più utile di «scade il 01/10»: chi guarda un
  /// invito in sospeso sta decidendo se rimandarlo **adesso**.
  int get giorniRimasti {
    final mancano = scadeIl.difference(DateTime.now());

    return mancano.isNegative ? 0 : mancano.inHours ~/ 24 + 1;
  }
}

/// I posti del piano, come li racconta l'elenco degli inviti.
///
/// 💡 Arrivano **nella stessa risposta** dell'elenco: chi guarda gli inviti per
/// revocarne uno sta guardando il contatore, e farlo chiedere a parte vorrebbe
/// dire mostrargli per un istante il numero di prima.
class PostiDegliInviti {
  const PostiDegliInviti({this.occupati = 0, this.totali, this.rimasti});

  factory PostiDegliInviti.fromJson(Map<String, dynamic> json) =>
      PostiDegliInviti(
        occupati: (json['occupati'] as num?)?.toInt() ?? 0,
        totali: (json['totali'] as num?)?.toInt(),
        rimasti: (json['rimasti'] as num?)?.toInt(),
      );

  final int occupati;

  /// `null` = il piano non mette limiti.
  final int? totali;
  final int? rimasti;
}

/// L'elenco e i posti, insieme.
class InvitiEPosti {
  const InvitiEPosti({required this.inviti, required this.posti});

  final List<InvitoInSospeso> inviti;
  final PostiDegliInviti posti;
}

/// Cosa è successo creando un invito.
///
/// 🚨 **Non è più solo il link.** Serve sapere anche *se la mail è partita*: chi
/// scrive un indirizzo e preme «manda» deve poter leggere una conferma vera, e
/// quando l'invio fallisce deve poterlo sapere subito — il link ce l'ha, e può
/// mandarlo a mano.
class InvitoCreato {
  const InvitoCreato({
    required this.id,
    required this.url,
    required this.emailInviata,
    this.email,
  });

  factory InvitoCreato.fromJson(Map<String, dynamic> json) => InvitoCreato(
    id: (json['id'] as num?)?.toInt() ?? 0,
    url: json['url']?.toString() ?? '',
    email: json['email']?.toString(),
    emailInviata: json['email_inviata'] as bool? ?? false,
  );

  final int id;
  final String url;
  final String? email;
  final bool emailInviata;
}
