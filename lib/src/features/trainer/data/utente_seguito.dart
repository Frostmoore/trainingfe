/// Una persona seguita da questo trainer — F5.1/F6 della Parte B.
class UtenteSeguito {
  const UtenteSeguito({
    required this.id,
    required this.nome,
    required this.email,
    required this.attivo,
    this.avatarUrl,
    this.suo = true,
  });

  factory UtenteSeguito.fromJson(Map<String, dynamic> json) => UtenteSeguito(
    id: (json['id'] as num).toInt(),
    nome: json['name']?.toString() ?? '',
    email: json['email']?.toString() ?? '',
    // ⚠️ Di serie `true`: un campo mancante non deve far sembrare disattivate
    // tutte le persone di un trainer che apre l'app dopo un aggiornamento del
    // server. La direzione dell'assenza è «tutto normale».
    attivo: json['attivo'] as bool? ?? true,
    avatarUrl: json['avatar_url']?.toString(),
    suo: json['suo'] as bool? ?? true,
  );

  final int id;
  final String nome;
  final String email;

  /// 🚨 `false` non vuol dire «cancellato»: vuol dire **canale chiuso** (D5).
  /// Il legame resta, la storia si conserva, e si può riattivare.
  final bool attivo;

  final String? avatarUrl;

  /// 🆕 **Il rapporto con questa persona è suo?** — 16/09/2026.
  ///
  /// 🚨 `false` per gli **iscritti della palestra**: sono in elenco perché il
  /// trainer li vede tutti, ma il legame è della palestra, non suo.
  ///
  /// ⛔ Serve a non offrire un gesto che il server rifiuta: il pulsante «chiudi
  /// la conversazione» chiama `toggleMember()`, che cerca il rapporto in
  /// `trainer_member` e per loro risponde **404**. ⚠️ Il rifiuto è giusto —
  /// quel rapporto lo decide la palestra — ciò che era sbagliato è mostrare il
  /// pulsante.
  ///
  /// 💡 **Di serie `true`**, come `attivo`: una risposta vecchia senza il
  /// campo si comporta come prima.
  final bool suo;
}

/// Quanti posti restano, e su che piano — il `meta` di `GET /trainer/members`.
///
/// 💡 Arriva **insieme** all'elenco e non da un endpoint suo: l'app deve poter
/// spegnere il pulsante «invita» *prima* che qualcuno lo prema. Scoprire il
/// limite dopo aver compilato un modulo fa sembrare rotto un vincolo
/// commerciale.
class PostiDelTrainer {
  const PostiDelTrainer({
    this.rimasti,
    this.limite,
    this.piano = 'free',
    this.allieviPropri = true,
  });

  factory PostiDelTrainer.fromJson(Map<String, dynamic> json) =>
      PostiDelTrainer(
        rimasti: (json['posti_rimasti'] as num?)?.toInt(),
        limite: (json['limite'] as num?)?.toInt(),
        piano: json['piano']?.toString() ?? 'free',
        allieviPropri: json['allievi_propri'] as bool? ?? true,
      );

  /// `null` = senza limite.
  final int? rimasti;
  final int? limite;
  final String piano;

  /// 🆕 **Questa persona può avere allievi suoi?** — 15/09/2026.
  ///
  /// 📌 Il committente: *«un trainer di una palestra non serve che veda il
  /// banner utenti illimitati, e un trainer indipendente (anche se lavora in
  /// una palestra) deve vederlo con il numero di allievi possibili per il suo
  /// piano»*.
  ///
  /// ⛔ **Senza questo campo i due casi erano indistinguibili.** Per un
  /// trainer di sola palestra il limite arriva `null`, e `null` qui vuol dire
  /// «senza limite»: la schermata gli scriveva **«Utenti illimitati»** quando
  /// la verità è che di posti suoi non ne ha nessuno — gli iscritti li paga la
  /// palestra, e li vede tutti comunque.
  ///
  /// ⚠️ **Di serie `true`**, e nella direzione giusta: una risposta vecchia,
  /// senza il campo, si comporta come prima invece di nascondere i posti a un
  /// trainer indipendente che li ha.
  final bool allieviPropri;

  bool get illimitato => limite == null;

  bool get puoInvitare => allieviPropri && (illimitato || (rimasti ?? 0) > 0);
}

/// L'elenco e i posti, insieme.
class MieiUtenti {
  const MieiUtenti({required this.utenti, required this.posti});

  final List<UtenteSeguito> utenti;
  final PostiDelTrainer posti;
}
