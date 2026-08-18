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
