import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/backup/backup_che_gira_da_solo.dart';
import '../../../core/backup/backup_controller.dart';
import '../../../core/backup/cloud_di_backup.dart';
import '../../../core/backup/raccolta_foto.dart';
import '../../../core/crypto/file_di_backup.dart';
import '../../../core/crypto/providers_crypto.dart';
import '../../../core/ui/intestazione_app.dart';
import '../../health/health_controller.dart';

/// L'esportazione del file di backup — M7.3, 18/08/2026.
///
/// ── 🚨 A quale guasto risponde ─────────────────────────────────────────────
///
/// Fino a oggi l'app sapeva **importare** un file di backup e non crearne
/// nessuno: si poteva ripristinare da un file che non si poteva fare. ⚠️ Era il
/// buco più silenzioso di tutto l'impianto delle chiavi, perché si scopre solo
/// nel momento in cui serve — cioè quando è troppo tardi.
///
/// ── ⚠️ Cosa c'è dentro, e cosa no ──────────────────────────────────────────
///
/// Dentro c'è **la chiave maestra**, che è la cosa irrecuperabile: senza,
/// nessuno — nemmeno noi — può più leggere i messaggi ricevuti. 📌 L'archivio
/// locale (peso, sonno, allenamenti) **non** ci è ancora dentro: lo copre il
/// backup di sistema, ed è debito dichiarato nel piano.
///
/// 🚨 **Il file vale quanto l'account.** Chi ce l'ha, insieme al codice, entra.
/// Va detto nella schermata, non nascosto in una nota.
class SchermataBackup extends ConsumerStatefulWidget {
  const SchermataBackup({super.key});

  @override
  ConsumerState<SchermataBackup> createState() => _SchermataBackupState();
}

class _SchermataBackupState extends ConsumerState<SchermataBackup> {
  bool _inCorso = false;
  String? _codice;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Scaffold(
      /*
       * 📌 «Backup e dati» — 3b-P.6.1, 22/08/2026, su richiesta del
       * committente.
       *
       * 💡 ⛔ **La parola nel titolo del file condiviso resta «copia di
       * sicurezza»** e non e' una svista: quello e' il nome che legge chi
       * riceve il file, magari fra un anno, magari da un'altra app. «Backup»
       * dice cos'e' a chi usa questa schermata; «copia di sicurezza» dice
       * cos'e' a chiunque altro.
       */
      appBar: const IntestazioneApp(titolo: 'Backup e dati'),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          /*
           * ☁️ L'automatico sta **in cima** — N3.5.
           *
           * 💡 È quello che risolve il problema per davvero: un file creato a
           * mano una volta e dimenticato in una cartella protegge molto meno
           * di una copia che si rifà da sola. Il manuale resta sotto, per chi
           * lo vuole e per il caso «ho scordato la password».
           */
          const _InterruttoreCloud(),
          const SizedBox(height: 12),
          const _RipristinoDalCloud(),
          const SizedBox(height: 24),

          Text('Il file da tenere da parte', style: tema.textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text(
            'Serve nel caso peggiore: hai perso il telefono E hai dimenticato '
            'la password di recupero. Il backup automatico non copre quel caso, '
            'perché si apre proprio con quella password.',
          ),
          const SizedBox(height: 20),

          Text('A cosa serve', style: tema.textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text(
            'I tuoi messaggi sono cifrati con una chiave che sta solo sul tuo '
            'telefono. Se perdi il telefono e hai dimenticato la password di '
            'recupero, questo file è l\'unico modo per rientrare.',
          ),
          const SizedBox(height: 20),

          Text('Cosa c\'è dentro', style: tema.textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text('· La chiave per leggere i tuoi messaggi.'),
          const SizedBox(height: 4),
          const Text(
            '· Peso, misure, sonno e recupero: tutto quello che vive solo sul '
            'tuo telefono.',
          ),
          const SizedBox(height: 4),
          /*
           * 🚨 **Si dice anche cosa NON c'è.**
           *
           * ⚠️ Un backup che qualcuno crede completo è peggio di nessun backup:
           * si perde il telefono tranquilli, e si scopre dopo.
           *
           * 📌 Questa riga diceva «le foto le copia il backup del telefono»
           * fino alla `v7.3.0`, ed era **falsa da N0**: le foto sono state
           * tolte dal backup di sistema proprio perché sfondavano il tetto dei
           * 25 MB e facevano fallire in silenzio il salvataggio di tutto il
           * resto. Oggi la loro casa è la spunta qui sopra.
           */
          const Text(
            '· Non ci sono le foto dei progressi: quelle vanno nel backup '
            'automatico, con la spunta qui sopra.',
          ),
          const SizedBox(height: 20),

          Card(
            color: tema.colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: tema.colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Questo file vale quanto il tuo account. Chi lo ha, '
                      'insieme al codice, può leggere i tuoi messaggi.',
                      style: TextStyle(
                        color: tema.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          if (_codice != null) ...[
            /*
             * 🚨 **Il codice si mostra UNA VOLTA SOLA**, e non si può
             * ritrovare: non lo conserviamo da nessuna parte.
             *
             * ⚠️ È il motivo per cui non è una password scelta dalla persona:
             * una password si **ricorda** — e si dimentica, ed è il guasto da
             * cui stiamo scappando. Un codice si **conserva** insieme al file.
             */
            Text(
              'Il tuo codice di ripristino',
              style: tema.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SelectableText(
              _codice!,
              style: tema.textTheme.headlineSmall?.copyWith(
                fontFamily: 'monospace',
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Conservalo insieme al file: senza, il file non si apre. '
              'Non possiamo recuperarlo — non lo conosciamo.',
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _codice!));
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Codice copiato')));
              },
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copia il codice'),
            ),
            const SizedBox(height: 24),
          ],

          FilledButton.icon(
            onPressed: _inCorso ? null : _esporta,
            icon: _inCorso
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share_rounded),
            label: Text(
              _codice == null ? 'Crea il file' : 'Crea un file nuovo',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _esporta() async {
    setState(() => _inCorso = true);
    final messaggeria = ScaffoldMessenger.of(context);

    try {
      final sodium = await ref.read(sodiumProvider.future);
      final maestra = await ref.read(portachiaviProvider).chiaveMaestra();

      if (maestra == null) {
        messaggeria.showSnackBar(
          const SnackBar(
            content: Text(
              'Non c\'è ancora nessuna chiave: apri prima la chat.',
            ),
          ),
        );

        return;
      }

      final backup = FileDiBackup(sodium);
      final codice = backup.generaCodice();

      /*
       * 🚨 **L'archivio ci va dentro davvero** — N2.1.
       *
       * ⚠️ Fino alla `v6.24.0` qui c'era `archivio: const {}`: il file
       * conteneva solo la chiave, e la schermata sembrava funzionare
       * benissimo. Un backup si prova riaprendo quello che c'era, non
       * guardando se il pulsante risponde.
       */
      final byte = await backup.esportaV2(
        chiaveMaestra: maestra,
        archivio: await ref.read(archivioSaluteProvider).esportaPerBackup(),
        codice: codice,
      );

      /*
       * 💡 Si scrive in una cartella temporanea e si passa al foglio di
       * condivisione. ⚠️ Non si salva da nessuna parte da soli: dove tenere un
       * file che vale quanto l'account lo deve decidere la persona, non noi.
       */
      final cartella = await getTemporaryDirectory();
      final file = File('${cartella.path}/training-companion-backup.json');
      await file.writeAsBytes(byte);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'Copia di sicurezza Training Companion',
        ),
      );

      if (mounted) setState(() => _codice = codice);
    } on Object catch (_) {
      messaggeria.showSnackBar(
        const SnackBar(content: Text('Non riesco a creare il file.')),
      );
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }
}

/// L'interruttore del backup automatico sul cloud — N3.5 e N3.6.
///
/// 🚨 **Spento di serie.** Mandare i propri dati — anche cifrati — nel proprio
/// spazio su Google è una decisione che deve prendere la persona, non un
/// effetto collaterale di aver installato l'app.
class _InterruttoreCloud extends ConsumerStatefulWidget {
  const _InterruttoreCloud();

  @override
  ConsumerState<_InterruttoreCloud> createState() => _InterruttoreCloudState();
}

class _InterruttoreCloudState extends ConsumerState<_InterruttoreCloud> {
  bool _inCorso = false;

  @override
  Widget build(BuildContext context) {
    final stato = ref.watch(backupAutomaticoProvider);

    return stato.when(
      loading: () => const ListTile(
        leading: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        title: Text('Backup automatico'),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (s) {
        /*
         * 💡 Senza cloud configurato l'interruttore **non c'è**, invece di
         * esserci e dare errore: un comando che fallisce sempre fa sembrare
         * rotta tutta l'applicazione.
         */
        if (!s.disponibile) return const SizedBox.shrink();

        return Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.cloud_upload_outlined),
                title: Text('Backup automatico su ${s.nomeDelCloud}'),
                subtitle: Text(
                  _sottotitolo(s),
                  /*
                   * 🚨 **Rosso, e non un'icona in più.** Un guasto scritto con
                   * lo stesso colore di «tutto bene» si legge come «tutto bene»:
                   * chi apre questa schermata la scorre, non la studia.
                   */
                  style: s.inErrore
                      ? TextStyle(color: Theme.of(context).colorScheme.error)
                      : null,
                ),
                value: s.acceso,
                onChanged: _inCorso ? null : (_) => _cambia(s),
              ),
              if (s.acceso) ...[
                const Divider(height: 1),
                _spuntaDelleFoto(s),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.refresh_rounded),
                  title: const Text('Aggiorna adesso'),
                  enabled: !_inCorso,
                  onTap: _inCorso ? null : _adesso,
                ),
              ],
              if (_inCorso)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: LinearProgressIndicator(),
                ),
            ],
          ),
        );
      },
    );
  }

  /// ⚠️ Oltre questo peso si chiede conferma — N5.2.
  ///
  /// 💡 Duecento megabyte non è una soglia tecnica: è il punto oltre il quale
  /// la cosa si **sente**, sulla quota di Drive e sul piano dati. Sotto, non
  /// vale la pena disturbare nessuno; sopra, va detto prima e non dopo.
  static const _sogliaConferma = 200 * 1000 * 1000;

  /// La spunta «salva anche le foto», con quanto pesano — N5.1.
  Widget _spuntaDelleFoto(StatoBackup s) {
    final peso = ref.watch(pesoDelleFotoProvider);

    return SwitchListTile(
      secondary: const Icon(Icons.photo_library_outlined),
      title: const Text('Salva anche le foto'),
      subtitle: Text(
        peso.when(
          // 🚨 Il peso si dice **sempre**, anche a spunta spenta: è il numero su
          // cui si decide, e nasconderlo fino a dopo aver acceso vorrebbe dire
          // farlo scoprire quando è già partito il caricamento.
          data: (byte) => byte == 0
              ? 'Non hai ancora nessuna foto.'
              : 'Le tue foto pesano ${RaccoltaFoto.pesoLeggibile(byte)}.',
          loading: () => 'Sto contando quanto pesano…',
          error: (_, _) => 'Non riesco a contare quanto pesano.',
        ),
      ),
      value: s.fotoIncluse,
      // ⚠️ Disattivata finché non so il peso: accendere senza poterlo dire
      // sarebbe esattamente la decisione al buio che questa riga evita.
      onChanged: _inCorso || peso.isLoading
          ? null
          : (vuole) => _cambiaLeFoto(vuole: vuole, byte: peso.valueOrNull ?? 0),
    );
  }

  Future<void> _cambiaLeFoto({required bool vuole, required int byte}) async {
    /*
     * 🚨 **La conferma serve solo per accendere, non per spegnere** — N5.2.
     *
     * ⚠️ Chiedere «sei sicuro?» a chi sta togliendo qualcosa è il modo per
     * rendere fastidioso l'unico gesto che non fa danni. Il peso lo si difende
     * quando lo si sta per occupare.
     */
    if (vuole && byte > _sogliaConferma) {
      final conferma = await showDialog<bool>(
        context: context,
        builder: (dialogo) => AlertDialog(
          title: const Text('Sono parecchie'),
          content: Text(
            'Le tue foto pesano ${RaccoltaFoto.pesoLeggibile(byte)}, e '
            'finiranno nel tuo spazio su Google Drive.\n\n'
            'La prima volta serve una connessione buona: meglio sotto wi-fi.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogo).pop(),
              child: const Text('Lascia stare'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogo).pop(true),
              child: const Text('Va bene, salvale'),
            ),
          ],
        ),
      );

      if (conferma != true || !mounted) return;
    }

    setState(() => _inCorso = true);

    try {
      await ref
          .read(backupAutomaticoProvider.notifier)
          .cambiaLeFoto(incluse: vuole);
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  /// 🚨 Con «acceso» si dice **quando è stato l'ultimo**.
  ///
  /// ⚠️ Senza una data, «è acceso» è una promessa che nessuno può verificare —
  /// ed è esattamente il tipo di promessa che si scopre falsa quando serve.
  String _sottotitolo(StatoBackup s) {
    if (!s.acceso) {
      return 'Spento. Acceso, i tuoi dati si salvano da soli nel tuo spazio.';
    }

    /*
     * ══ 🚨 L'ERRORE VIENE PRIMA DI TUTTO IL RESTO — 20/08/2026 ═════════════
     *
     * ⚠️ Fino a FASE 2.1 questo stato non serviva: il backup partiva solo
     * premendo un pulsante, e chi lo premeva vedeva l'errore. Da quando gira
     * **da solo**, un fallimento succede alle tre di notte e non lo vede
     * nessuno.
     *
     * 🚨 E la riga di prima era **vera e fuorviante insieme**: «Ultimo backup:
     * 3 giorni fa» è vero — l'ultimo *riuscito* è di tre giorni fa — ma non dice
     * che da allora ci ha provato tre volte senza farcela.
     *
     * 💡 `inErrore` è vero solo se il fallimento è **più recente** dell'ultimo
     * successo: un errore di due settimane fa, seguito da cinque backup
     * riusciti, non è una cosa da mostrare.
     */
    if (s.inErrore) {
      final tentativo = _daQuando(s.fallitoIl!);

      return s.ultimo == null
          ? 'Non è mai riuscito · ultimo tentativo $tentativo'
          : 'Non riesce da $tentativo · l\'ultimo riuscito è ${_daQuando(s.ultimo!)}';
    }

    final quando = s.ultimo;

    if (quando == null)
      return 'Acceso · non so ancora quando è stato l\'ultimo';

    return 'Ultimo backup: ${_daQuando(quando)}';
  }

  /// 💡 «oggi alle 03:14», «ieri alle 22:40», «3 giorni fa» in un posto solo: la
  /// stessa frase serve all'ultimo riuscito **e** all'ultimo tentativo, e due
  /// copie divergono.
  ///
  /// ══ 🕒 PERCHE' ANCHE L'ORA — 3b-P.6.2, 22/08/2026 ═══════════════════════
  ///
  /// 📌 Il committente: *«deve dire anche l'ora dell'ultimo backup oltre al
  /// giorno»*.
  ///
  /// ⚠️ **«Oggi» su un backup notturno non risponde alla domanda che si sta
  /// facendo.** Chi guarda questa riga sta per fare qualcosa di rischioso —
  /// cambiare telefono, ripristinare, disinstallare — e vuole sapere **se
  /// quello che ha fatto stamattina c'e' dentro**. «Oggi» puo' voler dire le
  /// tre di notte, cioe' prima di tutto il resto.
  ///
  /// ⛔ **L'ora solo per oggi e ieri**: su «3 giorni fa» non aggiunge niente
  /// che serva, e allunga una riga che sta gia' stretta.
  static String _daQuando(DateTime quando) {
    final giorni = DateTime.now().difference(quando).inDays;
    final ora =
        '${quando.hour.toString().padLeft(2, '0')}:'
        '${quando.minute.toString().padLeft(2, '0')}';

    return switch (giorni) {
      0 => 'oggi alle $ora',
      1 => 'ieri alle $ora',
      _ => '$giorni giorni fa',
    };
  }

  Future<void> _cambia(StatoBackup s) async {
    if (s.acceso) {
      await _spegni();

      return;
    }

    setState(() => _inCorso = true);
    final messaggeria = ScaffoldMessenger.of(context);

    try {
      final acceso = await ref
          .read(backupAutomaticoProvider.notifier)
          .accendi();

      if (!acceso) {
        // 💡 Ha detto di no: non è un errore, e non merita un messaggio rosso.
        messaggeria.showSnackBar(
          const SnackBar(content: Text('Backup automatico non attivato.')),
        );
      }
    } on Object catch (errore) {
      messaggeria.showSnackBar(SnackBar(content: Text(errore.toString())));
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  /// 🚨 Spegnendo si **chiede** se cancellare quello che c'è nel cloud.
  ///
  /// ⚠️ Lasciarlo lì in silenzio dopo un «non voglio più» è la cosa sbagliata;
  /// cancellarlo senza chiedere è peggio — quella copia potrebbe essere l'unica
  /// rimasta.
  Future<void> _spegni() async {
    final scelta = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: const Text('Spegnere il backup automatico?'),
        content: const Text(
          'Da adesso i tuoi dati non si salveranno più da soli.\n\n'
          'Vuoi anche cancellare la copia già caricata?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogo).pop(),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogo).pop(false),
            child: const Text('Spegni e basta'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogo).pop(true),
            child: const Text('Spegni e cancella'),
          ),
        ],
      ),
    );

    // ⚠️ `null` = ha annullato. Diverso da `false` = «spegni ma non cancellare».
    if (scelta == null || !mounted) return;

    setState(() => _inCorso = true);

    try {
      await ref
          .read(backupAutomaticoProvider.notifier)
          .spegni(cancellaDalCloud: scelta);
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  Future<void> _adesso() async {
    setState(() => _inCorso = true);
    final messaggeria = ScaffoldMessenger.of(context);

    try {
      await ref.read(backupAutomaticoProvider.notifier).adesso();
      messaggeria.showSnackBar(
        const SnackBar(content: Text('Backup aggiornato.')),
      );
    } on Object catch (errore, stack) {
      /*
       * ══ 🚨 IL MESSAGGIO È PER UNA PERSONA, NON PER NOI — 20/08/2026 ═══════
       *
       * ⚠️ Qui c'era `Text(errore.toString())`, e sul telefono del committente
       * ha sputato **l'eccezione con lo stack** dentro il toast. *«Non va bene
       * che mostri proprio i dettagli tecnici dell'errore»*.
       *
       * 🚨 Non è solo brutto: un messaggio che nessuno capisce **non dice cosa
       * fare**, e chi lo legge conclude che l'app è rotta invece che «manca la
       * rete». La differenza fra le due è tutta: la prima si subisce, la
       * seconda si risolve in due secondi.
       *
       * 💡 Lo stack serve **a noi** e va nel log, dove lo cerchiamo noi.
       */
      debugPrintStack(label: 'Backup a mano: $errore', stackTrace: stack);

      /*
       * 🚨 **E si segna che è fallito** — FASE 2.2.
       *
       * ⚠️ Prima lo scriveva solo il backup **automatico**, e infatti provando
       * a mano il committente ha visto «Ultimo backup: oggi» subito dopo un
       * fallimento: vero, e fuorviante. 💡 Un tentativo è un tentativo, che a
       * farlo sia un cron o un dito.
       */
      unawaited(BackupCheGiraDaSolo.segnaFallito());

      ref.invalidate(backupAutomaticoProvider);

      messaggeria.showSnackBar(SnackBar(content: Text(_perUnaPersona(errore))));
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  /// L'errore, detto a chi lo legge.
  ///
  /// 💡 Tre casi e non venti: quello che conta non è **quale** guasto è, è
  /// **cosa può fare adesso chi sta guardando**. ⚠️ Un elenco di venti messaggi
  /// diversi sarebbe venti modi di dire le stesse tre cose.
  static String _perUnaPersona(Object errore) {
    if (errore is CloudNonRaggiungibile) return errore.motivo;

    final t = errore.toString().toLowerCase();

    if (t.contains('socket') ||
        t.contains('network') ||
        t.contains('connection') ||
        t.contains('host')) {
      return 'Non riesco a raggiungere il tuo spazio: controlla la connessione '
          'e riprova.';
    }

    // ⚠️ Il caso generico dice comunque **cosa succede adesso**: che i dati
    // sono ancora sul telefono. Senza, «non è riuscito» suona come «hai perso
    // qualcosa».
    return 'Il backup non è riuscito. I tuoi dati sono ancora sul telefono: '
        'riprova più tardi.';
  }
}

/// «Riprendi quello che c'è nel cloud» — N4.2.
///
/// 🚨 **È la maniglia della cassaforte.** Fino alla `v7.2.0` l'app sapeva
/// caricare su Drive e non sapeva riprendere: ci metteva dentro le cose e non
/// c'era nessun modo di tirarle fuori.
///
/// ⚠️ Sta in una scheda a parte e non accanto all'interruttore: accendere il
/// backup e ripristinarlo sono due gesti opposti, e chi cerca il secondo di
/// solito ha appena cambiato telefono ed è già in difficoltà.
class _RipristinoDalCloud extends ConsumerStatefulWidget {
  const _RipristinoDalCloud();

  @override
  ConsumerState<_RipristinoDalCloud> createState() =>
      _RipristinoDalCloudState();
}

class _RipristinoDalCloudState extends ConsumerState<_RipristinoDalCloud> {
  bool _inCorso = false;

  @override
  Widget build(BuildContext context) {
    final stato = ref.watch(backupAutomaticoProvider).valueOrNull;

    if (stato == null || !stato.disponibile) return const SizedBox.shrink();

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: _inCorso
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.cloud_download_outlined),
        title: Text('Riprendi da ${stato.nomeDelCloud}'),
        subtitle: const Text(
          'Hai cambiato telefono? Rimetti a posto peso, misure e sonno.',
        ),
        onTap: _inCorso ? null : _ripristina,
      ),
    );
  }

  Future<void> _ripristina() async {
    final messaggeria = ScaffoldMessenger.of(context);

    setState(() => _inCorso = true);

    try {
      /*
       * 💡 Prima si **guarda se c'è qualcosa**, e solo dopo si chiede conferma.
       *
       * ⚠️ Chiedere «vuoi sovrascrivere?» e poi scoprire che non c'era niente
       * da ripristinare è il modo per far spaventare qualcuno a vuoto.
       */
      final quando = await ref
          .read(backupAutomaticoProvider.notifier)
          .cercaNelCloud();

      if (!mounted) return;

      if (quando == null) {
        messaggeria.showSnackBar(
          const SnackBar(
            content: Text(
              'Non c\'è nessuna copia di sicurezza in questo account.',
            ),
          ),
        );

        return;
      }

      /*
       * 🚨 **Si chiede prima di sovrascrivere.**
       *
       * ⚠️ Su un telefono appena installato non c'è niente da perdere, ma su
       * uno in uso si butterebbe via quello che c'è — ed è esattamente ciò che
       * farebbe qualcuno premendo per curiosità.
       */
      final conferma = await showDialog<bool>(
        context: context,
        builder: (dialogo) => AlertDialog(
          /*
           * ══ 🚨 DICE TUTTO QUELLO CHE SOSTITUISCE — 3b-P.6.3 ═════════════
           *
           * 📌 Il committente: *«deve apparire una modale che mi dice che i
           * dati su questo telefono verranno SOSTITUITI con quelli dell'ultimo
           * backup»*.
           *
           * ⚠️ **La modale c'era gia', e diceva una cosa incompleta**: «peso,
           * misure e sonno». 🚨 Da allora nel backup sono entrati **gli
           * allenamenti** (FASE 11), **le preferenze** (O.D.12) e le foto.
           *
           * ⛔ Elencare tre voci su sei e' peggio di non elencarne nessuna:
           * chi legge conclude che le altre si salvano, e conferma. Una
           * conferma che sottostima quello che cancella **non e' un consenso
           * informato**, e questa e' l'unica azione dell'app da cui non si
           * torna indietro.
           */
          title: const Text('Sostituire i dati di questo telefono?'),
          content: Text(
            'Trovata una copia del ${_giorno(quando)}.\n\n'
            // ⛔ Niente asterischi: questo e' un `Text`, non markdown — li
            // stamperebbe. Il peso della parola lo porta il titolo.
            'Tutto quello che hai su questo telefono viene sostituito con '
            'quello che c\'e\' nella copia: peso e misure, diario e pasti, '
            'allenamenti e serie, sonno, foto e preferenze.'
            '\n\n'
            'Quello che hai fatto dopo il ${_giorno(quando)} andra\' perso, e '
            'non si puo\' annullare.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogo).pop(),
              child: const Text('Annulla'),
            ),
            /*
             * ⚠️ **Il verbo del pulsante e' quello dell'azione**, non
             * «Riprendi»: chi legge di fretta legge **solo** il pulsante, e
             * «riprendi» suona come «continua», cioe' innocuo.
             */
            FilledButton(
              onPressed: () => Navigator.of(dialogo).pop(true),
              child: const Text('Sostituisci'),
            ),
          ],
        ),
      );

      if (conferma != true || !mounted) return;

      final quante = await ref
          .read(backupAutomaticoProvider.notifier)
          .ripristinaDalCloud();

      messaggeria.showSnackBar(
        SnackBar(
          content: Text(
            quante == 0
                // 💡 Zero righe non è un errore: è una copia fatta quando non
                // c'era ancora niente da salvare. Dirlo evita di far cercare un
                // guasto che non c'è.
                ? 'La copia non conteneva ancora nessun dato.'
                : 'Rimesse a posto $quante voci.',
          ),
        ),
      );
    } on Object catch (errore) {
      messaggeria.showSnackBar(SnackBar(content: Text(errore.toString())));
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  String _giorno(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';
}
