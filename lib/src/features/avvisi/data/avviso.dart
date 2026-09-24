/// 📣 **Un avviso mandato dalla piattaforma** — blocco B4, 24/09/2026.
///
/// 📌 Il committente, il 23/09: *«io (god) devo poter mandare notifiche a chi
/// voglio io … facendo apparire una modale in-app con un tasto per approvare
/// (testo che deciderò di volta in volta) e uno per rifiutare»*.
class Avviso {
  const Avviso({
    required this.id,
    required this.titolo,
    required this.testo,
    required this.tastoApprova,
    required this.tastoRifiuta,
    this.azione = 'dismiss',
    this.url,
  });

  factory Avviso.fromJson(Map<String, dynamic> json) => Avviso(
    id: (json['id'] as num).toInt(),
    titolo: json['titolo']?.toString() ?? '',
    testo: json['testo']?.toString() ?? '',
    tastoApprova: json['tasto_approva']?.toString() ?? 'Va bene',
    tastoRifiuta: json['tasto_rifiuta']?.toString() ?? 'No, grazie',
    azione: json['azione']?.toString() ?? 'dismiss',
    url: json['url']?.toString(),
  );

  final int id;
  final String titolo;
  final String testo;

  /// 🏷️ Le etichette le scrive la piattaforma **ogni volta**: qui non si
  /// inventa niente, si mostra quello che è arrivato.
  final String tastoApprova;
  final String tastoRifiuta;

  /// `dismiss` · `link` · `promo`.
  ///
  /// ⚠️ **L'app ne usa una sola**: `link`, per aprire il browser. 🚨 `promo` la
  /// esegue **il server** dentro la risposta alla decisione — farla eseguire al
  /// telefono vorrebbe dire lasciare che sia il telefono a dire «assegnami
  /// questa promozione».
  final String azione;

  final String? url;

  bool get apreUnLink => azione == 'link' && (url?.isNotEmpty ?? false);
}
