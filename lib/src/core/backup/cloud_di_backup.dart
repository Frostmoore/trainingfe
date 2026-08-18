import 'dart:typed_data';

/// Dove finisce la copia di sicurezza — N3.3, 18/08/2026.
///
/// ── 🚨 Un'interfaccia, e non direttamente Drive ────────────────────────────
///
/// Perché iOS arriverà, e lì il posto è iCloud. ⚠️ Scrivendo Drive dentro la
/// schermata, il giorno di iOS bisognerebbe riaprire l'interruttore, il lavoro
/// programmato e il ripristino — cioè tre punti che non c'entrano niente con
/// **dove** sta il file.
///
/// 💡 Da qui in su nessuno sa che esiste Google: si sa solo che c'è un posto in
/// cui si mette un file e da cui lo si riprende.
abstract class CloudDiBackup {
  /// Come si chiama, per dirlo alla persona: «Google Drive», «iCloud».
  String get nome;

  /// Chiede l'accesso. Torna `false` se la persona ha detto di no.
  ///
  /// 🚨 **Dire di no non è un errore**, ed è la ragione per cui torna un
  /// `bool` invece di lanciare: rifiutare l'accesso al proprio spazio è una
  /// risposta legittima, e trattarla come un guasto farebbe comparire un
  /// messaggio rosso a chi ha solo cambiato idea.
  Future<bool> collega();

  /// Scollega, senza toccare quello che c'è già caricato.
  Future<void> scollega();

  /// Se c'è già un accesso valido, senza chiedere niente a nessuno.
  Future<bool> eCollegato();

  /// Carica il backup, **sovrascrivendo** quello di prima.
  ///
  /// ⚠️ L'implementazione deve tenere **due generazioni**: se un caricamento si
  /// interrompe a metà, quello precedente deve essere ancora buono. Un backup
  /// solo è un backup che si può perdere proprio mentre lo si sta rifacendo.
  Future<void> carica(Uint8List contenuto);

  /// Riprende l'ultimo backup, o `null` se non ce n'è nessuno.
  Future<Uint8List?> scarica();

  /// Quando è stato caricato l'ultimo, o `null`.
  ///
  /// 💡 È l'unica cosa che rende credibile un backup automatico: senza una
  /// data, «è acceso» è una promessa che nessuno può verificare.
  Future<DateTime?> quandoLUltimo();

  /// Cancella tutto quello che l'app ha messo nel cloud.
  ///
  /// 🚨 Si chiama quando si spegne l'interruttore, **dopo aver chiesto**.
  /// Lasciare lì i file di qualcuno che ha appena detto «non voglio più» è la
  /// cosa sbagliata; cancellarli senza chiedere è peggio.
  Future<void> cancellaTutto();

  // ────────────────────────── gli allegati ──────────────────────────
  //
  // ── 🚨 Perché le foto NON stanno dentro l'archivio ────────────────────────
  //
  // Sarebbe stato più semplice aggiungere un campo `foto` al file `v2` e
  // chiudere la questione. Due ragioni lo escludono, e sono entrambe pratiche:
  //
  // **1. L'archivio si rifà da zero a ogni backup.** Le foto dentro
  // vorrebbero dire ricaricarle **tutte, ogni giorno**: qualche centinaio di
  // megabyte del piano dati di qualcun altro e del suo spazio su Drive, per
  // file che non cambiano mai. Separate, si carica solo quello che manca.
  //
  // **2. Il file `v2` si costruisce in memoria.** ⚠️ Duecento megabyte di foto
  // diventano, fra base64, JSON e cifratura, più di un giga di picco: l'app
  // verrebbe uccisa dal sistema proprio mentre mette al sicuro le cose.
  //
  // 💡 Il prezzo è che il cloud vede **quante** foto ci sono e quanto pesano.
  // Non cosa contengono: ognuna è cifrata per conto suo.

  /// Carica un allegato con un nome suo, sovrascrivendolo se c'è già.
  Future<void> caricaAllegato(String nome, Uint8List contenuto);

  /// Riprende un allegato, o `null` se non c'è.
  Future<Uint8List?> scaricaAllegato(String nome);

  /// I nomi degli allegati già nel cloud.
  ///
  /// 💡 È quello che rende il caricamento **incrementale**: si carica la
  /// differenza fra quello che c'è sul telefono e quello che c'è già lì.
  Future<Set<String>> elencaAllegati();

  /// Cancella un allegato. Non è un errore se non c'era.
  Future<void> cancellaAllegato(String nome);
}

/// Il cloud non è raggiungibile, o ha detto di no.
///
/// 💡 Distinta da «la persona ha rifiutato»: quella non è un errore e torna
/// `false` da [CloudDiBackup.collega].
class CloudNonRaggiungibile implements Exception {
  const CloudNonRaggiungibile(this.motivo);

  final String motivo;

  @override
  String toString() => motivo;
}
