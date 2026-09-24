/// 🆕 🏷️ **Con che cappello si entra** — blocco B2, 24/09/2026.
///
/// ⚠️ Le due voci sono quelle che il server accetta, e **nessun'altra**: un
/// invito a comandare regalerebbe a chi lo riceve l'abbonamento della palestra.
enum RuoloInvitato {
  iscritto('iscritto', 'Iscritto'),
  trainer('trainer', 'Trainer');

  const RuoloInvitato(this.valore, this.etichetta);

  /// Come lo scrive il server. ⚠️ `iscritto`, non `member`: il resto dell'API
  /// parla inglese, ma questo valore finisce **a schermo** accanto a «trainer».
  final String valore;

  final String etichetta;

  static RuoloInvitato? daStringa(String? valore) => switch (valore) {
    'trainer' => RuoloInvitato.trainer,
    'iscritto' => RuoloInvitato.iscritto,
    _ => null,
  };
}

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
    this.ruolo,
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
        ruolo: RuoloInvitato.daStringa(json['ruolo']?.toString()),
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

  /// 🆕 🏷️ Con che cappello entra chi lo riscatta — B2, 24/09/2026.
  ///
  /// ⚠️ `null` per gli inviti di un trainer, che hanno una specie sola.
  ///
  /// 🚨 **Non è decorazione**: nello stesso elenco di una palestra ci sono
  /// inviti che consumano posti **diversi**. ⛔ Senza, chi revoca per liberare
  /// un posto iscritto può revocarne uno trainer e vedere muoversi il contatore
  /// sbagliato.
  final RuoloInvitato? ruolo;

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
  const InvitiEPosti({
    required this.inviti,
    required this.posti,
    this.postiTrainer,
  });

  final List<InvitoInSospeso> inviti;

  /// I posti per le persone che si allenano. Per un trainer sono **i suoi
  /// allievi**, per una palestra **i suoi iscritti**.
  final PostiDegliInviti posti;

  /// 🆕 🏋️ I posti trainer — **solo una palestra ne ha**, B2, 24/09/2026.
  ///
  /// 🚨 È un limite **a parte** (`plans.max_trainers`), e `null` quando chi
  /// guarda è un trainer. ⛔ Sommarlo all'altro direbbe «restano 4» a una
  /// palestra che ha finito i posti trainer e ne ha quattro per gli iscritti:
  /// un numero vero che risponde alla domanda sbagliata.
  final PostiDegliInviti? postiTrainer;
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
    this.ruolo,
  });

  factory InvitoCreato.fromJson(Map<String, dynamic> json) => InvitoCreato(
    id: (json['id'] as num?)?.toInt() ?? 0,
    url: json['url']?.toString() ?? '',
    email: json['email']?.toString(),
    emailInviata: json['email_inviata'] as bool? ?? false,
    ruolo: RuoloInvitato.daStringa(json['ruolo']?.toString()),
  );

  final int id;
  final String url;
  final String? email;
  final bool emailInviata;

  /// 🆕 Con che cappello entrerà chi lo riscatta. `null` per un trainer.
  final RuoloInvitato? ruolo;
}

/// 🆕 🚪 **Chi sta invitando** — blocco B2, 24/09/2026.
///
/// ══ 🔑 PERCHE' UN ENUM E NON DUE SCHERMATE ═════════════════════════
///
/// ⛔ La pagina degli inviti di una palestra fa **le stesse quattro cose** di
/// quella di un trainer: crea, copia, rimanda, revoca. Riscriverla vorrebbe dire
/// due schermate da tenere allineate per sempre — ed è la lezione tornata tre
/// volte in due giorni: *una regola che serve in due posti non va scritta in
/// nessuno dei due*.
///
/// 💡 Quindi cambia **solo l'indirizzo delle rotte**, e sta qui.
enum ChiInvita {
  trainer('/trainer/invites', 'Inviti in sospeso'),
  palestra('/gym/invites', 'Inviti della palestra');

  const ChiInvita(this.rotta, this.titolo);

  final String rotta;
  final String titolo;

  /// ⚠️ Solo una palestra sceglie **che specie** di persona invitare, e solo
  /// lei ha due contatori: è l'unica differenza vera fra i due casi.
  bool get sceglieIlRuolo => this == ChiInvita.palestra;
}
