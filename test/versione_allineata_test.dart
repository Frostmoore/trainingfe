import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 🏷️ **Il numero di versione dice quale versione è** — 23/09/2026.
///
/// ⛔ `pubspec.yaml` è rimasto a `18.8.0+180800` **da fine agosto al 23
/// settembre**, mentre il codice arrivava alla `v18.30.0`. Il telefono del
/// committente dichiarava `versionName=18.8.0`, e sembrava una build vecchia:
/// non lo era. 🚨 Alla domanda *«che versione hai?»* non c'era risposta — né
/// per l'assistenza, né per un rapporto di crash, né per sapere se una
/// correzione era arrivata sul telefono di qualcuno.
///
/// ══ 🚨 E IL `versionCode` NON E' DECORATIVO ═════════════════════════════════
///
/// Il numero dopo il `+` è quello che `IdentitaApp` manda al server come
/// `X-App-Build` a **ogni richiesta**, e su cui `VersioneMinima` decide se
/// quella copia può entrare.
///
/// ⛔ Con un `versionCode` fermo, alzare il minimo sul server **bloccherebbe
/// tutti insieme**, compresi quelli che hanno appena aggiornato: dal punto di
/// vista del server sono tutti la stessa vecchia copia. ⚠️ E gli store
/// rifiutano un caricamento che non lo alza, quindi senza questo guardiano il
/// difetto si presenterebbe **il giorno della pubblicazione**.
///
/// ── 💡 Perché il ramo ──────────────────────────────────────────────────────
///
/// I rami si chiamano come le versioni (`v18.31.0`): il numero giusto esiste
/// già, mancava solo che finisse nel `pubspec.yaml`. Confrontare le due cose è
/// l'unico modo di accorgersene **prima** che esca.
///
/// ⚠️ **Se non si capisce su che ramo si è, il test passa e lo dice.** Fuori da
/// un ramo-versione (HEAD staccato, `main`, una macchina senza `.git`) non c'è
/// niente con cui confrontare, e fallire lì vorrebbe dire una suite rossa per
/// un motivo che non riguarda il codice.
void main() {
  test('la versione nel pubspec è quella del ramo', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    final riga = RegExp(
      r'^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)\s*$',
      multiLine: true,
    ).firstMatch(pubspec);

    expect(
      riga,
      isNotNull,
      reason:
          'In pubspec.yaml non c\'è una riga «version: X.Y.Z+N». Senza, '
          'l\'app non sa dire chi è.',
    );

    final major = int.parse(riga!.group(1)!);
    final minor = int.parse(riga.group(2)!);
    final patch = int.parse(riga.group(3)!);
    final build = int.parse(riga.group(4)!);

    /*
     * 🚨 **Il `versionCode` si calcola, non si sceglie.**
     *
     * ⛔ Scriverlo a mano vuol dire, prima o poi, scriverlo più basso di
     * quello di prima: e un `versionCode` che scende è un caricamento
     * rifiutato dallo store, o — peggio — un'app che il server considera
     * vecchia senza che nessuno capisca perché.
     */
    expect(
      build,
      major * 10000 + minor * 100 + patch,
      reason:
          'Il versionCode ($build) non viene da $major.$minor.$patch: la '
          'formula è major * 10000 + minor * 100 + patch. È il numero che il '
          'server confronta per decidere chi può entrare (VersioneMinima).',
    );

    final ramo = _ramoCorrente();

    if (ramo == null) {
      printOnFailure('Nessun ramo-versione: confronto saltato.');

      return;
    }

    expect(
      '$major.$minor.$patch',
      ramo,
      reason:
          'Il ramo si chiama «v$ramo» ma pubspec.yaml dice '
          '«$major.$minor.$patch». 🚨 È il difetto del 23/09: il numero di '
          'versione che non dice quale versione sia. Allinea il pubspec (e il '
          'versionCode viene da solo).',
    );
  });
}

/// Il nome del ramo, **solo se è un ramo-versione**: `v18.31.0` → `18.31.0`.
///
/// 💡 Si legge `.git/HEAD` invece di lanciare `git`: non tutte le macchine
/// hanno `git` nel `PATH` dei test, e un test che dipende da un eseguibile
/// esterno fallisce per il motivo sbagliato.
String? _ramoCorrente() {
  try {
    for (final cartella in ['.git', '../.git']) {
      final head = File('$cartella/HEAD');

      if (!head.existsSync()) continue;

      final match = RegExp(
        r'ref:\s*refs/heads/v(\d+\.\d+\.\d+)',
      ).firstMatch(head.readAsStringSync());

      return match?.group(1);
    }
  } on Object {
    // ⚠️ Un guardiano che esplode è peggio di un guardiano che tace: qui si
    //    rinuncia al confronto, non si fa fallire la suite.
  }

  return null;
}
