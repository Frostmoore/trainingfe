/// 🆔 **Il nome utente come nome pubblico** — blocco B3, 24/09/2026.
///
/// 📌 Il committente, il 23/09: *«bisognerà inventarsi un sistema di username
/// per poter scrivere a chiunque, così una palestra o un trainer possono
/// invitare direttamente un allievo o un trainer da app a app»*.
///
/// ══ ⛔ TROVARSI E' UNA SCELTA, E NASCE SPENTA ═══════════════════════════════
///
/// Decisione 53.1: *«spento e se lo vuoi lo accendi»*. 🚨 Chi si allena in
/// palestra non si è iscritto per farsi cercare: trovabile di serie sarebbe una
/// rubrica di persone con nome, foto e città che non hanno chiesto niente.
class NomePubblico {
  const NomePubblico({
    this.username,
    this.trovabile = false,
    this.puoCambiare = true,
    this.potraCambiareDal,
  });

  factory NomePubblico.fromJson(Map<String, dynamic> json) => NomePubblico(
    username: json['username']?.toString(),
    trovabile: json['trovabile'] as bool? ?? false,
    puoCambiare: json['puo_cambiare'] as bool? ?? true,
    potraCambiareDal: DateTime.tryParse(
      json['potra_cambiare_dal']?.toString() ?? '',
    )?.toLocal(),
  );

  /// `null` = non l'ha ancora scelto. ⚠️ È **facoltativo** (decisione 53.5a).
  final String? username;

  final bool trovabile;

  /// 📅 Si cambia **una volta ogni 30 giorni** (53.5b): cambiarlo di continuo è
  /// il modo di sfuggire a chi ti ha bloccato.
  final bool puoCambiare;
  final DateTime? potraCambiareDal;

  bool get ceL => username != null && username!.isNotEmpty;
}

/// Una persona trovata cercando.
///
/// ⚠️ **Niente email, niente telefono, niente palestra**: una ricerca deve
/// bastare a *riconoscere* una persona, non a saperne di più di quanto se ne
/// sapesse prima.
class PersonaTrovata {
  const PersonaTrovata({
    required this.id,
    required this.username,
    required this.nome,
    this.avatar,
  });

  factory PersonaTrovata.fromJson(Map<String, dynamic> json) => PersonaTrovata(
    id: (json['id'] as num).toInt(),
    username: json['username']?.toString() ?? '',
    nome: json['nome']?.toString() ?? '',
    avatar: json['avatar']?.toString(),
  );

  final int id;
  final String username;
  final String nome;
  final String? avatar;
}
