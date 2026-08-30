import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/onboarding/riferimento_dell_installazione.dart';

/// 🎯 Ritrovare l'invito **dopo** l'installazione — 3b-V.3.3.
///
/// ══ 🚨 PERCHE' IL PEZZO DA PROVARE E' IL PARSER ═══════════════════════════
///
/// Il canale nativo in un test non c'è, e il Play Store nemmeno. ⛔ Ma il punto
/// in cui questa funzione sbaglia **in silenzio** non è il canale: è la lettura
/// della stringa.
///
/// Il referrer è testo libero. La nostra parte ci mette `invito=<token>`, ma
/// nella stessa stringa il Play Store — o una campagna pubblicitaria — può
/// infilarci `utm_source`, `gclid` e altro, separati da `&`.
///
/// ⚠️ Leggere «tutta la stringa» come token funzionerebbe **in prova**, dove il
/// referrer lo scriviamo noi, e si romperebbe il giorno che qualcuno aggiunge
/// una campagna. 🚨 E non darebbe un errore: darebbe *«invito non più valido»* —
/// che sembra un invito scaduto invece di un difetto nostro.
void main() {
  group('il token si tira fuori dal referrer', () {
    test('da solo', () {
      expect(
        RiferimentoDellInstallazione.tokenDa(
          'invito=AbCdEfGhIjKlMnOpQrStUvWxYz012345',
        ),
        'AbCdEfGhIjKlMnOpQrStUvWxYz012345',
      );
    });

    /// 🚨 **Il caso vero.** Il Play Store non promette di mandare solo la nostra
    /// parte: la mescola con quello che c'è.
    test('in mezzo ad altre voci', () {
      expect(
        RiferimentoDellInstallazione.tokenDa(
          'utm_source=google&invito=AbCdEfGhIjKlMnOpQrStUvWxYz012345&gclid=xyz',
        ),
        'AbCdEfGhIjKlMnOpQrStUvWxYz012345',
      );
    });

    /// ⚠️ Il referrer arriva **codificato**: `invito%3Dtoken`.
    test('anche quando arriva codificato', () {
      expect(
        RiferimentoDellInstallazione.tokenDa(
          'invito%3DAbCdEfGhIjKlMnOpQrStUvWxYz012345',
        ),
        'AbCdEfGhIjKlMnOpQrStUvWxYz012345',
      );
    });

    test('e se non c\'è, non si inventa', () {
      expect(RiferimentoDellInstallazione.tokenDa(''), isNull);
      expect(RiferimentoDellInstallazione.tokenDa('utm_source=google'), isNull);
      expect(
        RiferimentoDellInstallazione.tokenDa('not_set'),
        isNull,
        reason: 'È la stringa che il Play Store manda quando non sa niente.',
      );
    });
  });

  /// 🚨 **La forma si controlla**, e non è pignoleria: questa stringa arriva da
  /// fuori, e finisce dentro un percorso e una richiesta al server.
  group('quello che non ha la forma di un token non passa', () {
    test('troppo corto o troppo lungo', () {
      expect(RiferimentoDellInstallazione.tokenDa('invito=abc'), isNull);
      expect(
        RiferimentoDellInstallazione.tokenDa('invito=${'a' * 64}'),
        isNull,
      );
    });

    /// ⛔ Il caso che conta: barre e punti dentro un valore che diventerà un
    /// percorso.
    test('con caratteri che non sono alfanumerici', () {
      expect(
        RiferimentoDellInstallazione.tokenDa(
          'invito=../../../etc/passwd12345678',
        ),
        isNull,
      );
      expect(
        RiferimentoDellInstallazione.tokenDa(
          'invito=AbCdEfGhIjKlMnOpQrStUvWxY-012345',
        ),
        isNull,
      );
    });

    /// ⚠️ `invitoqualcosa=…` non è `invito=…`: il confronto è sulla chiave
    /// intera, non su un «comincia per».
    test('una chiave che gli somiglia non basta', () {
      expect(
        RiferimentoDellInstallazione.tokenDa(
          'invitoDiQualcunAltro=AbCdEfGhIjKlMnOpQrStUvWxYz012345',
        ),
        isNull,
      );
    });
  });
}
