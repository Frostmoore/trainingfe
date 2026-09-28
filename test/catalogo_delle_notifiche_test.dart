import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/notifications/catalogo.dart';

/// 🔔 **I due cataloghi delle notifiche dicono la stessa cosa** — voce 62, 27/09/2026.
///
/// ══ 📌 COSA RENDE VERA LA FRASE «UN SOLO PUNTO» ═══════════════════════════
///
/// 📌 Il committente: *«il sistema delle notifiche fallo autoconsistente. Voglio
/// un solo punto dove posso aggiungere notifiche»*.
///
/// 🔑 Il punto è **l'enum PHP del backend**. ⛔ Ma l'app ha bisogno di conoscere
/// gli stessi nomi — per sapere dove portare quando tocchi una push, e per
/// programmare le locali — quindi una seconda copia è inevitabile.
///
/// 🚨 **Una copia inevitabile è una copia che diverge**, a meno che qualcuno non
/// stia a guardare. 💡 Questo test è quello che sta a guardare: legge l'enum PHP
/// e pretende che i due elenchi coincidano, **valore per valore e canale per
/// canale**.
///
/// ⚠️ Quindi aggiungendo una notifica nel backend, questo test diventa rosso e
/// dice **cosa manca** qui. ⛔ Non è un fastidio: è la differenza fra «due liste
/// che dovrebbero essere uguali» e «due liste che non possono divergere senza che
/// nessuno se ne accorga».
void main() {
  /// 🔎 L'enum PHP sta nel repo accanto. ⚠️ Se non c'è — perché qualcuno ha
  /// clonato solo l'app — il test **si salta con un motivo**, invece di fallire
  /// accusando il codice di un difetto che non ha.
  File? enumDelBackend() {
    for (final p in [
      '../trainingbe/app/Enums/Notifica.php',
      'trainingbe/app/Enums/Notifica.php',
    ]) {
      final f = File(p);

      if (f.existsSync()) return f;
    }

    return null;
  }

  test('i due cataloghi hanno gli stessi valori e gli stessi canali', () {
    final file = enumDelBackend();

    if (file == null) {
      markTestSkipped(
        "Il repo trainingbe non e' accanto a questo: il confronto fra i due "
        "cataloghi non si puo' fare. Non e' un difetto dell'app.",
      );

      return;
    }

    final php = file.readAsStringSync();

    /*
     * 🔎 Si leggono i `case NOME = 'valore';` dell'enum.
     *
     * ⚠️ Una lettura a espressione regolare e non un parser: ⛔ scrivere un
     * parser PHP per tre righe sarebbe un secondo problema. 💡 E se un giorno la
     * forma dell'enum cambiasse, il test diventerebbe rosso invece di mentire —
     * perché troverebbe zero casi, e c'è un controllo apposta.
     */
    final casi = RegExp(r"case\s+\w+\s*=\s*'([a-z_]+)'\s*;")
        .allMatches(php)
        .map((m) => m.group(1)!)
        .toList();

    expect(
      casi.length,
      greaterThan(5),
      reason:
          "🚨 Nell'enum PHP non si trovano i casi: la sua forma e' cambiata e "
          "questo test non sta piu' confrontando niente.",
    );

    final diQua = Notifica.values.map((n) => n.valore).toSet();
    final diLa = casi.toSet();

    expect(
      diLa.difference(diQua),
      isEmpty,
      reason:
          "🚨 Il backend dichiara notifiche che l'app non conosce. 💡 Vanno "
          "aggiunte in lib/src/core/notifications/catalogo.dart, con il loro canale.",
    );

    expect(
      diQua.difference(diLa),
      isEmpty,
      reason:
          "🚨 L'app conosce notifiche che il backend non dichiara. ⛔ Il catalogo "
          "e' quello del server: se una notifica serve, va dichiarata la'.",
    );
  });

  test('e i canali combaciano, non solo i nomi', () {
    final file = enumDelBackend();

    if (file == null) {
      markTestSkipped("Il repo trainingbe non e' accanto a questo.");

      return;
    }

    final php = file.readAsStringSync();

    /*
     * 🔑 **Il canale si legge dal `match` di `canale()`**, che nell'enum PHP
     * elenca prima tutti i casi push e poi tutti i locali.
     *
     * ⚠️ Qui si guarda **da che parte del `=> CanaleDellaNotifica::Push`** cade
     * ogni nome. ⛔ Fragile? Un po'. 💡 Ma l'alternativa — fidarsi — e' peggio:
     * un canale sbagliato vuol dire un promemoria di allenamento che passa da
     * Google, che e' la cosa precisa che questa voce esiste per impedire.
     */
    final dentroIlMatch = RegExp(
      r'public function canale\(\).*?\}',
      dotAll: true,
    ).firstMatch(php)?.group(0);

    expect(
      dentroIlMatch,
      isNotNull,
      reason: "🚨 Non trovo canale() nell'enum PHP.",
    );

    final tagliato = dentroIlMatch!.split('CanaleDellaNotifica::Push');

    expect(
      tagliato.length,
      2,
      reason: "🚨 La forma di canale() e' cambiata: il confronto non e' affidabile.",
    );

    final partePush = tagliato.first;

    for (final n in Notifica.values) {
      /*
       * ⚠️ Si cerca il NOME del caso PHP, non il valore: dentro il `match` i casi
       * si scrivono `self::Messaggio`, non con la stringa.
       */
      final nomePhp = _nomePhp(n);

      final eNelRamoPush = partePush.contains('self::$nomePhp');

      final atteso = n.canale == CanaleDellaNotifica.push;

      expect(
        eNelRamoPush,
        atteso,
        reason:
            "🚨 ${n.valore}: qui e' ${n.canale.name}, nel backend no. "
            "⛔ Un canale sbagliato vuol dire un dato che passa da Google quando "
            "non doveva, o una notifica che non parte mai.",
      );
    }
  });

  /// 🆕 🧭 **E le destinazioni combaciano** — 27/09/2026.
  ///
  /// 📌 Il committente: *«ci deve essere un altro parametro nelle notifiche: dove
  /// rimanda»*.
  ///
  /// ══ 🚨 PERCHE' QUESTO CONFRONTO SERVE DAVVERO ═════════════════════════
  ///
  /// 🔑 La destinazione e' dichiarata **due volte**: nell'enum PHP, che la manda
  /// nel campo `dove`, e qui, che e' quella su cui l'app decide davvero
  /// (`destinazioneDellaNotifica` preferisce la propria).
  ///
  /// ⛔ Quindi se le due copie divergessero **non si vedrebbe niente**: la push
  /// arriverebbe con scritto un posto e l'app ne aprirebbe un altro, e il carico
  /// resterebbe la' a dire il falso a chi legge un registro. 💡 Questo test e'
  /// l'unica cosa che lo impedisce.
  test('e le destinazioni dichiarate sono le stesse', () {
    final file = enumDelBackend();

    if (file == null) {
      markTestSkipped("Il repo trainingbe non e' accanto a questo.");

      return;
    }

    final php = file.readAsStringSync();

    final dentroIlMatch = RegExp(
      r'public function destinazione\(\).*?\n    \}',
      dotAll: true,
    ).firstMatch(php)?.group(0);

    expect(
      dentroIlMatch,
      isNotNull,
      reason:
          "🚨 Non trovo destinazione() nell'enum PHP: o non c'e', o ha cambiato "
          "forma e questo test non sta piu' confrontando niente.",
    );

    /*
     * 🔎 Si raccolgono le coppie `self::Caso[, self::Altro] => 'nome',` del
     * `match`, tenendo conto che piu' casi possono condividere la stessa
     * destinazione — le tre del denaro lo fanno.
     *
     * ⚠️ Una lettura a espressione regolare, come per il canale: ⛔ un parser PHP
     * per un `match` sarebbe un secondo problema. 💡 E se la forma cambiasse il
     * test diventerebbe rosso, non silenzioso: sotto c'e' il controllo che i
     * nomi trovati siano tanti quanti i casi dell'enum.
     */
    final dalPhp = <String, String?>{};

    for (final m in RegExp(
      r"((?:self::\w+,\s*)*self::\w+)\s*=>\s*(null|'[a-z-]+')",
      dotAll: true,
    ).allMatches(dentroIlMatch!)) {
      final dove = m.group(2)!;

      for (final caso in RegExp(r'self::(\w+)').allMatches(m.group(1)!)) {
        dalPhp[caso.group(1)!] = dove == 'null'
            ? null
            : dove.substring(1, dove.length - 1);
      }
    }

    expect(
      dalPhp.length,
      Notifica.values.length,
      reason:
          "🚨 Nel match di destinazione() ho letto ${dalPhp.length} casi, ma le "
          "notifiche sono ${Notifica.values.length}. ⛔ O manca un caso di la', o "
          "la forma del match e' cambiata e la lettura non e' affidabile.",
    );

    for (final n in Notifica.values) {
      final nomePhp = _nomePhp(n);

      expect(
        dalPhp.containsKey(nomePhp),
        isTrue,
        reason: "🚨 destinazione() nel backend non decide niente per $nomePhp.",
      );

      expect(
        dalPhp[nomePhp],
        n.destinazione,
        reason:
            "🚨 ${n.valore}: qui porta a «${n.destinazione}», nel backend a "
            "«${dalPhp[nomePhp]}». ⛔ La push arriverebbe dicendo un posto e "
            "l'app ne aprirebbe un altro, senza che niente segnali l'errore.",
      );
    }
  });

  /// 🆕 📱 **Le locali dichiarate fatte sono fatte DAVVERO** — 27/09/2026.
  ///
  /// ══ 🚨 LA META' CHE IL BACKEND NON PUO' CONTROLLARE ═══════════════════
  ///
  /// `App\Enums\Notifica::daFare()` elenca le notifiche dichiarate e non ancora
  /// implementate, e di la' un test verifica che quelle **push** fuori
  /// dall'elenco abbiano un punto che le manda.
  ///
  /// ⛔ Ma per le **locali** quel test non puo' dire niente: le programma l'app,
  /// quindi in `app/` del backend non c'e' niente da trovare. 🚨 Verificato il
  /// 27/09 togliendo una locale da `daFare()`: il test PHP resta verde.
  ///
  /// ⚠️ La locale con cui l'avevo provato era `SchedaFinita`, che dal 28/09 **non
  /// esiste piu'**: e' stata togliata dal catalogo, non implementata — il
  /// committente, *«Le schede non finiscono»*. 💡 La verifica resta valida: vale
  /// per qualunque locale, non per quella.
  ///
  /// 💡 Quindi la guardia sulle locali sta **qui**, che e' l'unico posto dove una
  /// locale puo' essere implementata. ⚖️ Senza, il catalogo potrebbe dichiarare
  /// fatto un promemoria che nessuno programma — la cosa che si crede e non si
  /// controlla.
  ///
  /// ══ 🔎 COME CERCA ═════════════════════════════════════════════════════
  ///
  /// Legge `daFare()` dall'enum PHP, poi cerca il **valore** della notifica —
  /// `fine_recupero`, `promemoria_diario` — dentro `lib/`, escludendo il catalogo
  /// stesso che li nomina tutti per definizione.
  ///
  /// ⚠️ Cerca il valore e non il nome Dart: 💡 il valore e' la stringa che
  /// l'implementazione deve usare per dire **quale** notifica sta programmando, e
  /// un'implementazione che non la usa non e' collegata al catalogo.
  test('e le locali dichiarate fatte sono implementate nell app', () {
    final file = enumDelBackend();

    if (file == null) {
      markTestSkipped("Il repo trainingbe non e' accanto a questo.");

      return;
    }

    final php = file.readAsStringSync();

    final dentroDaFare = RegExp(
      r'public function daFare\(\).*?\], true\);',
      dotAll: true,
    ).firstMatch(php)?.group(0);

    expect(
      dentroDaFare,
      isNotNull,
      reason: "🚨 Non trovo daFare() nell'enum PHP: forma cambiata.",
    );

    /* 📚 Tutto il codice dell'app, meno il catalogo. */
    final codice = StringBuffer();
    var guardati = 0;

    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;

      if (f.path.replaceAll(r'\', '/').endsWith('core/notifications/catalogo.dart')) {
        continue;
      }

      guardati++;
      codice.write(f.readAsStringSync());
    }

    expect(
      guardati,
      greaterThan(50),
      reason: '⛔ Troppi pochi file guardati: il test non protegge niente.',
    );

    final tutto = codice.toString();

    for (final n in Notifica.values) {
      if (n.canale != CanaleDellaNotifica.locale) continue;

      final daFare = dentroDaFare!.contains('self::${_nomePhp(n)}');
      final implementata = tutto.contains("'${n.valore}'") ||
          tutto.contains('"${n.valore}"') ||
          tutto.contains('Notifica.${n.name}');

      if (daFare) {
        /*
         * ⚠️ Qui NON si pretende che manchi: una notifica puo' essere a metà —
         * il tipo già usato, il promemoria non ancora programmato — e fallire
         * per questo vorrebbe dire vietare i lavori in corso.
         */
        continue;
      }

      expect(
        implementata,
        isTrue,
        reason:
            "🚨 ${n.valore} non e' fra i «da fare» del backend, ma nel codice "
            "dell'app non si trova: nessuno la programma. ⛔ Il catalogo "
            'dichiara fatta una notifica che non suona mai.',
      );
    }
  });
}

/// 🔤 Dal nome Dart al nome del caso PHP: `incassoFallito` → `IncassoFallito`.
String _nomePhp(Notifica n) {
  final nome = n.name;

  return nome[0].toUpperCase() + nome.substring(1);
}
