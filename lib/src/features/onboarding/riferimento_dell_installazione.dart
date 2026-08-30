import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Da dove viene questa installazione — 3b-V.3.3.
///
/// ══ 🎯 IL PROBLEMA CHE RISOLVE ════════════════════════════════════════════
///
/// Chi tocca un link d'invito **senza avere l'app** finisce sullo store. Dopo
/// l'installazione l'app non saprebbe da quale invito veniva: quel link l'ha
/// aperto il browser, non noi.
///
/// 💡 Il Play Store porta con sé la stringa che era attaccata all'URL dello
/// store — il `referrer` — e lì dentro ci mettiamo il token.
///
/// ══ ⛔ OGGI NON FA NIENTE, ED È VOLUTO ════════════════════════════════════
///
/// Funziona **solo per le installazioni dal Play Store**. Un APK caricato a
/// mano — come sta l'app adesso, in prova — non ha nessun referrer.
///
/// 🚨 È la strada giusta per quando l'app sarà pubblicata. Intanto il ripiego
/// resta: chi installa e riapre il link ci arriva lo stesso, perché gli App
/// Links lo portano dentro l'app.
class RiferimentoDellInstallazione {
  const RiferimentoDellInstallazione();

  /// 🚨 Deve combaciare con `RiferimentoDellInstallazione.CANALE` lato Kotlin.
  static const _canale = MethodChannel(
    'mytrainingcompanion/riferimento_installazione',
  );

  /// 💡 Il segno che l'abbiamo già guardato. Vedi [tokenDellInvito].
  static const _giaLetto = 'invito.referrer.letto';

  /// Il token dell'invito da cui viene questa installazione, **una volta sola**.
  ///
  /// ── 🚨 «Una volta sola» è la regola, non un'ottimizzazione ──────────────
  ///
  /// ⛔ Il referrer **non scade e non si cancella**: il Play Store lo
  /// restituisce identico a ogni chiamata, per sempre. Senza il segno,
  /// l'app riaprirebbe la pagina di quell'invito **a ogni avvio** — anche mesi
  /// dopo, anche a chi in quella palestra è già entrato, anche a chi aveva
  /// detto di no.
  ///
  /// ⚠️ E sarebbe un difetto che in prova non si vede: al primo avvio è
  /// esattamente il comportamento giusto.
  ///
  /// 💡 Il segno si scrive **prima** di tornare il token, non dopo averlo usato:
  /// se l'app si chiude mentre la pagina si apre, la persona ha comunque il
  /// link — che è la strada normale. Rischiare di riproporlo per sempre è
  /// peggio che rischiare di non proporlo una volta.
  Future<String?> tokenDellInvito() async {
    final memoria = await SharedPreferences.getInstance();

    if (memoria.getBool(_giaLetto) ?? false) return null;

    await memoria.setBool(_giaLetto, true);

    final grezzo = await _leggiIlReferrer();

    if (grezzo == null || grezzo.isEmpty) return null;

    return tokenDa(grezzo);
  }

  /// Tira fuori il token dalla stringa del Play Store.
  ///
  /// ── ⚠️ Il formato è quello di una query, e non è garantito da nessuno ───
  ///
  /// Il referrer è una stringa libera: la nostra ci mette `invito=<token>`, ma
  /// nella stessa stringa il Play Store (o una campagna) può infilarci
  /// `utm_source`, `gclid` e altro, separati da `&`.
  ///
  /// 🚨 **Quindi non si può leggere «tutta la stringa» come token.** Un
  /// referrer con dentro anche una sola voce in più darebbe un token sbagliato
  /// — e un token sbagliato non dà nessun errore: dà «invito non più valido»,
  /// che sembra un invito scaduto invece di un difetto nostro.
  ///
  /// 💡 `static` e pubblica perché è la parte che va provata da sola: il canale
  /// nativo in un test non c'è, questa sì.
  static String? tokenDa(String referrer) {
    for (final pezzo in Uri.decodeComponent(referrer).split('&')) {
      final taglio = pezzo.indexOf('=');

      if (taglio <= 0) continue;

      if (pezzo.substring(0, taglio).trim() == 'invito') {
        final token = pezzo.substring(taglio + 1).trim();

        /*
         * ⚠️ **Si controlla la forma**: i token sono 32 caratteri
         * alfanumerici. Una stringa qualunque arrivata da fuori non deve
         * diventare una richiesta al server — e soprattutto non deve
         * diventare un percorso.
         */
        return RegExp(r'^[A-Za-z0-9]{32}$').hasMatch(token) ? token : null;
      }
    }

    return null;
  }

  Future<String?> _leggiIlReferrer() async {
    try {
      return await _canale.invokeMethod<String>('leggi');
    } on Object {
      /*
       * ⛔ **Nessun errore da mostrare, mai.** Su iOS il canale non esiste, su
       * un telefono senza Play Services la libreria non parte, su un APK
       * caricato a mano non c'è niente da leggere. Sono tutti «nessun invito».
       *
       * 🚨 Un errore all'avvio per una funzione che la persona non sa nemmeno
       * di avere è il modo peggiore di aprire l'app.
       */
      return null;
    }
  }
}

final riferimentoDellInstallazioneProvider = Provider(
  (ref) => const RiferimentoDellInstallazione(),
);
