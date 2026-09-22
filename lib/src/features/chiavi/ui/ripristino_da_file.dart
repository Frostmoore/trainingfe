import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backup/preferenze_nel_backup.dart';
import '../../../core/crypto/file_di_backup.dart';
import '../../../core/crypto/providers_crypto.dart';
import '../../../core/theme/app_theme.dart';
import '../../health/health_controller.dart';
import '../../privacy/consensi_controller.dart';

/// Il ripristino da un file di backup — **da due porte diverse**.
///
/// ══ 🚨 Perché sta in un file suo e non dentro una schermata ═══════════════
///
/// 📌 Il committente, 23/09/2026: *«non capisco perché per ripristinare il
/// backup devo andare sui messaggi e non su "backup e dati", non ha nessun
/// senso»*. Aveva ragione: il ripristino nasceva come *«riapri i messaggi»* e
/// viveva solo dentro `SchermataRipristino`, cioè dietro alla chat. ⚠️ Ma chi
/// ha perso i dati va a cercarlo dove li ha salvati — in **Backup e dati**.
///
/// ⛔ La tentazione era copiare le venti righe nella seconda schermata. Sarebbe
/// stato il modo sicuro di avere, fra sei mesi, **due ripristini diversi**: uno
/// che riporta le preferenze e uno no, uno che aggiorna le schermate e uno che
/// lascia l'app a mostrare i dati vecchi. È già successo in questo impianto —
/// vedi la nota N2.2 sull'archivio che non veniva riscritto.
///
/// 💡 Quindi: la logica sta **qui**, una volta sola, e le due schermate la
/// chiamano. Chi ne aggiungerà una terza non deve sapere niente.

/// Il file scelto: come si chiama e cosa c'è dentro.
typedef FileScelto = ({String nome, Uint8List byte});

/// Come si sceglie un file. 💡 Iniettabile: vedi `ChiediFileECodice.scegli`.
typedef SceltaDelFile = Future<FileScelto?> Function();

/// Quello che serve per aprire un file: i **byte**, il codice, la password nuova.
///
/// ══ 🚨 I byte e non il percorso — 23/09/2026 ══════════════════════════════
///
/// ⛔ Fino alla `v18.18.0` qui c'era un `String percorso`, scritto a mano in un
/// campo di testo, e l'app faceva `File(percorso).readAsBytes()`. ⚠️ Ma l'app
/// non dichiara **nessun** permesso sull'archivio condiviso: un file in
/// `Download` rispondeva **sempre** *«Non riesco a leggere quel file»*. L'unica
/// cartella che funzionava era `/storage/emulated/0/Android/media/<pacchetto>/`,
/// che nessun utente conosce e nessuno può raggiungere dal telefono.
///
/// 🚨 Il 22/09/2026 il backup del committente è stato recuperato solo spingendo
/// il file lì con `adb push` e scrivendo il percorso con `adb shell input text`.
/// **Senza un PC collegato non ci sarebbe arrivato** — e questa è la strada che
/// si percorre quando si è già perso tutto, cioè quando fallire costa di più.
///
/// 💡 Il selettore di sistema restituisce i byte e **non passa dal filesystem**:
/// niente percorsi da scrivere, niente permessi da chiedere, e funziona da
/// Download, da Drive, da Telegram e da qualunque altra app.
class DatiDelFile {
  const DatiDelFile({
    required this.byte,
    required this.codice,
    required this.nuovaPassword,
    this.nome = '',
  });

  final Uint8List byte;
  final String codice;
  final String nuovaPassword;

  /// Solo per mostrarlo a schermo: il ripristino non lo guarda.
  final String nome;
}

/// Apre il file e rimette dentro tutto. Torna `null` se è andata bene,
/// altrimenti **il motivo da mostrare**.
///
/// 🚨 Non lancia: chi chiama è una schermata, e una schermata deve poter dire
/// cos'è successo senza sapere quali eccezioni esistono qua sotto.
Future<String?> eseguiIlRipristinoDaFile(
  WidgetRef ref,
  DatiDelFile scelta,
) async {
  try {
    final sodium = await ref.read(sodiumProvider.future);
    final servizio = await ref.read(servizioChiaviProvider.future);

    final contenuto = await FileDiBackup(sodium).importaQualsiasi(
      file: scelta.byte,
      codice: scelta.codice,
    );

    await servizio.ripristinaDaChiave(
      chiaveMaestra: contenuto.chiaveMaestra,
      nuovaPassword: scelta.nuovaPassword,
    );

    /*
     * 🚨 **L'archivio si riscrive DOPO la chiave** — N2.2.
     *
     * Fino alla `v6.24.0` `contenuto.archivio` non lo leggeva nessuno: si
     * ripristinava la chat e si perdevano peso, misure e sonno, senza che
     * niente lo dicesse.
     *
     * ⚠️ L'ordine conta: se l'archivio fallisse dopo che la chiave e' gia' a
     * posto, la persona ha comunque riavuto i messaggi — che sono la cosa
     * irrecuperabile. Al contrario avrebbe l'archivio e nessun modo di leggere
     * la chat.
     *
     * 💡 Un archivio vuoto (il caso dei file `v1`) non fa niente:
     * `ripristinaDaBackup` salta le tabelle che il file non contiene.
     */
    if (contenuto.archivio.isNotEmpty) {
      await ref
          .read(archivioSaluteProvider)
          .ripristinaDaBackup(contenuto.archivio);

      await PreferenzeNelBackup.ripristina(
        contenuto.archivio[PreferenzeNelBackup.chiave],
      );
    }

    rileggiTuttoDopoIlRipristino(ref);

    return null;
  } on CodiceDiRipristinoSbagliato catch (e) {
    return e.motivo;
  } on Object catch (e) {
    return e.toString();
  }
}

/// Dopo un ripristino **si rilegge tutto quello che il ripristino ha toccato**.
///
/// ══ 🚨 Perché non basta `statoChiaviProvider` ═════════════════════════════
///
/// ⛔ Fino al 22/09/2026 c'era quella riga sola, e un ripristino riuscito si
/// lasciava dietro due bugie: la schermata della privacy continuava a dire
/// *«Sessione scaduta»* — l'errore era stato preso **da sloggati**, prima
/// dell'accesso, e `FutureProvider` tiene in cache anche gli errori — e peso,
/// misure e allenamenti appena riscritti non comparivano finché non si
/// cambiava schermata.
///
/// ⚠️ **Non è un fastidio estetico.** Chi ha appena recuperato i suoi dati sta
/// guardando proprio quella schermata per capire se il recupero è riuscito: un
/// errore lì gli dice di no. E chi crede fallito il ripristino rifà tutto da
/// capo, o preme «Ricomincia» — che genera una chiave nuova e **brucia i
/// messaggi vecchi per sempre**.
///
/// 💡 `revisioneAllenamentiProvider` è il segnale già in uso per «l'archivio è
/// cambiato»: lo guardano sette provider fra salute e allenamenti, quindi
/// incrementarlo qui vale anche per quelli che verranno scritti domani, senza
/// un elenco da tenere aggiornato.
void rileggiTuttoDopoIlRipristino(WidgetRef ref) {
  ref.invalidate(statoChiaviProvider);
  ref.invalidate(consensiProvider);
  ref.read(revisioneAllenamentiProvider.notifier).state++;
}

/// Il selettore di sistema, quello vero.
///
/// 📌 `FilePicker.platform` e non i metodi statici: siamo fermi alla 10.x, come
/// in `documento_scelto.dart` e `conversations_screen.dart`.
///
/// ⚠️ `FileType.any` e non `custom` con `['json']`: il file di backup lo si può
/// aver salvato con qualunque nome, e un filtro che nasconde il file giusto è
/// peggio di nessun filtro — la persona conclude che il backup non c'è più.
Future<FileScelto?> scegliUnFileDiBackup() async {
  final scelta = await FilePicker.platform.pickFiles(withData: true);
  final file = scelta?.files.firstOrNull;
  final byte = file?.bytes;

  if (byte == null) return null;

  return (nome: file!.name, byte: byte);
}

/// Chiede il file, il codice e la password nuova.
class ChiediFileECodice extends StatefulWidget {
  const ChiediFileECodice({super.key, this.scegli});

  /// 💡 Iniettabile **solo per i test**: in app resta il selettore di sistema.
  /// ⛔ L'alternativa era falsificare `FilePicker.platform`, che obbliga a
  /// riscrivere tutti e dodici i parametri di `pickFiles` in una finta — e a
  /// rincorrerli ogni volta che il pacchetto ne aggiunge uno.
  final SceltaDelFile? scegli;

  @override
  State<ChiediFileECodice> createState() => _ChiediFileECodiceState();
}

class _ChiediFileECodiceState extends State<ChiediFileECodice> {
  final _codice = TextEditingController();
  final _password = TextEditingController();

  FileScelto? _file;
  bool _sceltaInCorso = false;

  @override
  void dispose() {
    _codice.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _valido =>
      _file != null &&
      FileDiBackup.normalizza(_codice.text).length == 24 &&
      _password.text.length >= 8;

  Future<void> _scegli() async {
    setState(() => _sceltaInCorso = true);

    try {
      final scelto = await (widget.scegli ?? scegliUnFileDiBackup)();

      if (mounted && scelto != null) setState(() => _file = scelto);
    } finally {
      if (mounted) setState(() => _sceltaInCorso = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return AlertDialog(
      title: const Text('Ripristino da file'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton.icon(
              onPressed: _sceltaInCorso ? null : _scegli,
              icon: _sceltaInCorso
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.folder_open_rounded),
              label: Text(_file == null ? 'Scegli il file' : 'Cambia file'),
            ),
            if (_file != null) ...[
              const SizedBox(height: Gap.sm),
              Text(
                _file!.nome,
                style: tema.textTheme.bodySmall,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: Gap.md),
            TextField(
              controller: _codice,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Codice di ripristino',
                hintText: 'ABCD-EFGH-JKLM-NPQR-STUV-WXYZ',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: Gap.md),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Nuova password di recupero',
                helperText: 'Almeno 8 caratteri',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: _valido
              ? () => Navigator.of(context).pop(
                  DatiDelFile(
                    byte: _file!.byte,
                    nome: _file!.nome,
                    codice: _codice.text,
                    nuovaPassword: _password.text,
                  ),
                )
              : null,
          child: const Text('Ripristina'),
        ),
      ],
    );
  }
}
