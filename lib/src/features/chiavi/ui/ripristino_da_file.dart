import 'dart:io';

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

/// Quello che serve per aprire un file: dove sta, il codice, la password nuova.
class DatiDelFile {
  const DatiDelFile({
    required this.percorso,
    required this.codice,
    required this.nuovaPassword,
  });

  final String percorso;
  final String codice;
  final String nuovaPassword;
}

/// Apre il file e rimette dentro tutto. Torna `null` se è andata bene,
/// altrimenti **il motivo da mostrare**.
///
/// 🚨 Non lancia: chi chiama è una schermata, e una schermata deve poter dire
/// cos'è successo senza sapere quali eccezioni esistono qua sotto.
Future<String?> eseguiIlRipristinoDaFile(WidgetRef ref, DatiDelFile scelta) async {
  try {
    final sodium = await ref.read(sodiumProvider.future);
    final servizio = await ref.read(servizioChiaviProvider.future);

    final contenuto = await FileDiBackup(sodium).importaQualsiasi(
      file: await File(scelta.percorso).readAsBytes(),
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
  } on FileSystemException {
    return 'Non riesco a leggere quel file.';
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

/// Chiede il file, il codice e la password nuova.
///
/// ⚠️ Il percorso si scrive **a mano**, ed è un difetto aperto (voce 51 del
/// `DA-FARE`): `file_picker` è già fra le dipendenze e restituirebbe i byte,
/// togliendo di mezzo sia il percorso sia i permessi sull'archivio condiviso.
/// Finché non si fa, da `Download` non si riesce a leggere niente.
class ChiediFileECodice extends StatefulWidget {
  const ChiediFileECodice({super.key});

  @override
  State<ChiediFileECodice> createState() => _ChiediFileECodiceState();
}

class _ChiediFileECodiceState extends State<ChiediFileECodice> {
  final _percorso = TextEditingController();
  final _codice = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _percorso.dispose();
    _codice.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _valido =>
      _percorso.text.trim().isNotEmpty &&
      FileDiBackup.normalizza(_codice.text).length == 24 &&
      _password.text.length >= 8;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ripristino da file'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _percorso,
              decoration: const InputDecoration(
                labelText: 'Percorso del file',
                hintText: '/storage/…/training-companion.backup',
              ),
              onChanged: (_) => setState(() {}),
            ),
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
                    percorso: _percorso.text.trim(),
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
