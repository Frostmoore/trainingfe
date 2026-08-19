/// A cosa serve una foto, e quindi che fine fa — N9.2.
///
/// ── 🚨 Il destino sta sul TIPO, non su una lista da un'altra parte ─────────
///
/// [nelBackup], [permanente] e [scadenza] vivono qui perché aggiungendo un tipo
/// nuovo si è **costretti** a rispondere alle tre domande: dove vive, se va
/// salvato, e quando muore.
///
/// ⚠️ L'alternativa — una lista di cartelle dentro `RaccoltaFoto`, o un elenco
/// di scadenze dentro la spazzata — è quella che ci si dimentica di aggiornare.
/// Il risultato sarebbero foto di un tipo nuovo che non entrano nel backup
/// **in silenzio**, o che non muoiono mai: lo stesso guasto da cui è nata tutta
/// la Parte N, perché un backup che qualcuno crede completo è peggio di nessun
/// backup.
enum TipoFoto {
  /// Le foto dei progressi: la storia di qualcuno, e vive **solo** sul telefono.
  progressi(cartella: 'progressi', permanente: true, nelBackup: true),

  /// Le foto scambiate in chat, non effimere.
  ///
  /// 💡 Nel backup perché il server le tiene solo 24 ore (§4.8 del piano):
  /// passate quelle, l'unica copia è quella sul telefono.
  chat(
    cartella: 'chat',
    permanente: true,
    nelBackup: true,
    // 🚨 N21: in chat passano anche i PDF, e devono entrare nel backup.
    accettaDocumenti: true,
  ),

  /// La foto del piatto mandata al modello.
  ///
  /// 🚨 **Vive dallo scatto alla conferma, e poi muore.** Serve a una cosa
  /// sola: farsi dire cosa c'è nel piatto. ⚠️ Senza un tipo suo sarebbe finita
  /// insieme alle altre — salvata per sempre e caricata su Drive, crescendo di
  /// qualche foto al giorno per anni.
  ///
  /// La [scadenza] copre il caso in cui l'app muoia fra lo scatto e la
  /// conferma: senza, quegli orfani resterebbero lì per sempre.
  ai(
    cartella: 'ai',
    permanente: false,
    nelBackup: false,
    scadenza: Duration(hours: 24),
  ),

  /// L'immagine di un alimento personale.
  ///
  /// 💡 Nessuna [scadenza]: è una cache vera, e il sistema la svuota da sé
  /// quando serve spazio. Quello che serve si riscarica aprendo il prodotto.
  alimenti(cartella: 'alimenti', permanente: false, nelBackup: false),

  /// Le foto usa e getta.
  ///
  /// 🚨 **Mai nel backup, ed è la parte che si dimentica.** Una foto effimera
  /// finita nel backup sopravviverebbe **per sempre su Drive** — l'esatto
  /// contrario di quello che voleva chi l'ha mandata, e nessuno se ne
  /// accorgerebbe.
  ///
  /// La [scadenza] è l'orologio di **chi ha mandato**: 24 ore dall'invio, poi
  /// resta la traccia. Chi riceve la perde prima, alla chiusura.
  effimere(
    cartella: 'effimere',
    permanente: false,
    nelBackup: false,
    scadenza: Duration(hours: 24),
  );

  const TipoFoto({
    required this.cartella,
    required this.permanente,
    required this.nelBackup,
    this.scadenza,
    this.accettaDocumenti = false,
  });

  /// Il nome della sottocartella, sotto `foto/`.
  final String cartella;

  /// 🚨 `true` → `Documents/foto/<cartella>` · `false` → `Cache/foto/<cartella>`.
  ///
  /// 💡 **La cache non è una comodità, è il meccanismo.** Quello che non deve
  /// finire in nessun backup ci finisce **per costruzione**: la cartella di
  /// cache è già esclusa da ogni backup di sistema, e il sistema la svuota
  /// quando serve spazio. Tenendo tutto in `Documents` avremmo dovuto
  /// ricordarci di escludere le stesse cartelle in tre punti diversi, e
  /// sbagliarne uno un anno dopo.
  final bool permanente;

  /// Se entra nel backup nel cloud.
  ///
  /// ⚠️ Non è la negazione di [permanente] per caso: sono due domande diverse,
  /// e un tipo futuro potrebbe voler stare in `Documents` **senza** essere
  /// salvato. Tenerle separate costa un campo ed evita di doverle scucire dopo.
  final bool nelBackup;

  /// 🚨 Se in questa cartella possono stare anche **documenti**, non solo
  /// immagini — N21.
  ///
  /// ── ⚠️ Il guasto che questo campo ha chiuso ─────────────────────────────
  ///
  /// I PDF della chat finivano in `foto/chat/`, ma l'elenco delle estensioni
  /// ammesse era **uno solo per tutti** e conteneva solo immagini. Risultato:
  /// **il backup li saltava in silenzio**, e non li avrebbe nemmeno saputi
  /// riprendere. Nessun errore, da nessuna parte.
  ///
  /// 💡 Sta sul tipo come `nelBackup` e `scadenza`, e per la stessa ragione:
  /// aggiungendo un tipo si è costretti a rispondere «cosa ci può stare
  /// dentro?». Un elenco globale è quello che ci si dimentica di allargare.
  ///
  /// ⚠️ E resta `false` per i progressi: un PDF fra le foto di progresso non
  /// vuol dire niente, e accettarlo vorrebbe dire farlo comparire in galleria.
  final bool accettaDocumenti;

  /// Le estensioni che questo tipo accetta.
  ///
  /// 🚨 **Elenco di ammessi, non di esclusi.** Un elenco di esclusi lascia
  /// passare il formato a cui nessuno aveva pensato — e nel caso dei video quel
  /// formato pesa cento volte una foto, sul piano dati di qualcun altro.
  Set<String> get estensioni => accettaDocumenti
      ? {..._immagini, ..._documenti}
      : _immagini;

  static const _immagini = <String>{'.jpg', '.jpeg', '.png', '.webp', '.heic'};

  /// 💡 Solo PDF: è l'unico formato che il canale sa mandare, e allargarlo
  /// «per comodità» vorrebbe dire accettare file che nessuno sa aprire.
  static const _documenti = <String>{'.pdf'};

  /// Dopo quanto una foto di questo tipo va buttata, se c'è ancora.
  ///
  /// `null` = non scade da sola.
  final Duration? scadenza;

  /// I tipi che il backup deve guardare.
  static Iterable<TipoFoto> get daSalvare => values.where((t) => t.nelBackup);

  /// I tipi che la spazzata deve ripulire.
  static Iterable<TipoFoto> get cheScadono =>
      values.where((t) => t.scadenza != null);

  /// Il tipo che vive in questa cartella, o `null` se il nome non è di nessuno.
  ///
  /// 💡 Serve a rifare il percorso assoluto da quello relativo salvato a
  /// database: dal nome della cartella si risale al tipo, e dal tipo alla
  /// radice giusta (documenti o cache).
  static TipoFoto? dallaCartella(String nome) {
    for (final t in values) {
      if (t.cartella == nome) return t;
    }

    return null;
  }
}
