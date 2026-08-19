import 'package:shared_preferences/shared_preferences.dart';

import 'calcolatore_calorie.dart';

/// L'obiettivo che la persona ha deciso **al posto** della stima — N18.
///
/// ── 🚨 Perché deve poterlo cambiare ────────────────────────────────────────
///
/// La stima nasce da una formula generica applicata a quattro dati anagrafici.
/// Per moltissime persone è ragionevole; per qualcuna è lontana — chi ha una
/// composizione corporea insolita, chi si allena molto più di quanto abbia
/// dichiarato, e soprattutto **chi ha un fabbisogno calcolato da un
/// professionista abilitato** e vuole usare quello.
///
/// ⚠️ Impedirglielo vorrebbe dire dire alla persona che la nostra formula ne sa
/// più del suo nutrizionista. È il contrario esatto di quello che l'avvertenza
/// di N17 dichiara.
///
/// ── 💡 Sta sul telefono, come tutto il resto del corpo ────────────────────
///
/// Peso, misure e composizione non escono da qui (D9-bis): il fabbisogno è
/// figlio di quelli, e mandarlo al server per poterlo modificare sarebbe stato
/// un passo indietro sulla decisione che regge tutta la Parte S.
class TargetScelto {
  const TargetScelto({
    required this.kcal,
    required this.proteineG,
    required this.carboidratiG,
    required this.grassiG,
  });

  final int kcal;
  final int proteineG;
  final int carboidratiG;
  final int grassiG;

  Macro get macro => Macro(
    proteineG: proteineG,
    carboidratiG: carboidratiG,
    grassiG: grassiG,
  );

  static const _chiave = 'target_scelto_a_mano';

  /// Quello scelto, o `null` se vale la stima.
  static Future<TargetScelto?> leggi() async {
    final prefs = await SharedPreferences.getInstance();
    final riga = prefs.getStringList(_chiave);

    /*
     * ⚠️ **Una riga malformata vale come "non c'è".**
     *
     * 💡 Sono preferenze locali, e una versione futura potrebbe scriverne una
     * forma diversa: tornare alla stima è sempre un comportamento corretto,
     * mentre lanciare qui bloccherebbe la schermata principale su un dato
     * accessorio.
     */
    if (riga == null || riga.length != 4) return null;

    final numeri = riga.map(int.tryParse).toList();

    if (numeri.any((n) => n == null || n < 0)) return null;

    return TargetScelto(
      kcal: numeri[0]!,
      proteineG: numeri[1]!,
      carboidratiG: numeri[2]!,
      grassiG: numeri[3]!,
    );
  }

  Future<void> salva() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setStringList(_chiave, [
      '$kcal',
      '$proteineG',
      '$carboidratiG',
      '$grassiG',
    ]);
  }

  /// 🚨 «Torna alla stima» in un gesto solo.
  ///
  /// ⚠️ Senza, chi ha provato a cambiare un numero resterebbe legato alla
  /// propria scelta per sempre, o dovrebbe ricopiare a mano i valori calcolati
  /// — che è il modo per sbagliarli.
  static Future<void> dimentica() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_chiave);
  }
}
