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
}

/// 🔤 Dal nome Dart al nome del caso PHP: `incassoFallito` → `IncassoFallito`.
String _nomePhp(Notifica n) {
  final nome = n.name;

  return nome[0].toUpperCase() + nome.substring(1);
}
