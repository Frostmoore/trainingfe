import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:training_companion/src/features/auth/data/accesso_social_vero.dart';
import 'package:training_companion/src/features/auth/data/social_sign_in.dart';

/// 🔑 **L'accesso con Google e Apple** — voce 25, 26/09/2026.
///
/// ══ ⚠️ COSA SI PUO' PROVARE DA QUI, E COSA NO ══════════════════════════════
///
/// ⛔ **Non** si può provare l'accesso vero: apre una finestra di sistema, parla
/// con Google o con Apple e vuole un dispositivo con un account dentro.
///
/// 💡 Si prova quello che **è stato estratto apposta** per poterlo provare: la
/// regola su quali fornitori valgono su quale piattaforma, e la traduzione
/// degli errori di Google. Sono le due parti dove si sbaglia in silenzio.
void main() {
  group('quali fornitori valgono su questa piattaforma', () {
    /// 🎯 **La decisione del committente, 26/09**: *«Apple solo su iOS»*.
    ///
    /// ⛔ Il difetto che questo test chiude: il server dichiara i fornitori
    /// **una volta per tutti**, senza sapere da che dispositivo arriva la
    /// richiesta. Con Apple acceso lato server, il pulsante sarebbe comparso
    /// **anche su Android** — dove l'accesso nativo con Apple non esiste.
    test('⛔ Apple NON si usa fuori dai sistemi Apple', () {
      expect(
        fornitoreUsabileQui(SocialProviderId.apple, sistemaApple: false),
        isFalse,
        reason: 'su Android comparirebbe un pulsante che non può funzionare',
      );
    });

    test('✅ Apple si usa sui sistemi Apple', () {
      expect(
        fornitoreUsabileQui(SocialProviderId.apple, sistemaApple: true),
        isTrue,
      );
    });

    /// 💡 Google vale ovunque: è la ragione per cui la regola non è
    /// semplicemente «solo la piattaforma di casa».
    test('✅ Google si usa su tutte e due', () {
      for (final apple in [true, false]) {
        expect(
          fornitoreUsabileQui(SocialProviderId.google, sistemaApple: apple),
          isTrue,
        );
      }
    });

    /// 🚨 Un fornitore che non conosciamo **non** passa. ⛔ Il `social` del
    /// branding arriva dal server: se un giorno ne dichiarasse uno nuovo, l'app
    /// deve ignorarlo invece di disegnare un pulsante che non sa premere.
    test('⛔ un fornitore sconosciuto non passa', () {
      expect(fornitoreUsabileQui('facebook', sistemaApple: true), isFalse);
      expect(fornitoreUsabileQui('', sistemaApple: true), isFalse);
    });

    /// ⚠️ `supportaApple` legge la piattaforma vera: qui si controlla solo che
    /// sia **coerente con dove girano i test**, non che valga un valore fisso.
    test('supportaApple dice la verità sulla macchina dove gira', () {
      expect(
        AccessoSocialVero.supportaApple,
        Platform.isIOS || Platform.isMacOS,
      );
    });
  });

  group('gli errori di Google diventano frasi', () {
    /// 🎯 **Il caso che vale il test.** ⛔ `ApiException: 10`
    /// (`DEVELOPER_ERROR`) è l'errore più frequente di questa funzione e non
    /// dice niente: manda a cercare il difetto nel codice, dove non c'è.
    /// 🚨 La causa vera è quasi sempre l'impronta SHA-1 non registrata.
    test('🎯 la configurazione mancante nomina l\'impronta SHA-1', () {
      final frase = AccessoSocialVero.spiegaIlRifiutoDiGoogle(
        GoogleSignInExceptionCode.clientConfigurationError,
      );

      expect(frase, contains('SHA-1'));
      expect(
        frase.toLowerCase(),
        contains('firma'),
        reason: 'chi legge deve capire che si parla della chiave di firma',
      );
    });

    /// ⚠️ Ogni codice deve produrre **qualcosa di leggibile**: un ramo
    /// dimenticato mostrerebbe una stringa vuota a chi non è riuscito a entrare.
    test('⚠️ nessun codice resta senza spiegazione', () {
      for (final codice in GoogleSignInExceptionCode.values) {
        final frase = AccessoSocialVero.spiegaIlRifiutoDiGoogle(codice);

        expect(
          frase.trim(),
          isNotEmpty,
          reason: 'il codice ${codice.name} non ha una spiegazione',
        );
        expect(
          frase.length,
          greaterThan(10),
          reason: '${codice.name}: «$frase» non spiega niente',
        );
      }
    });
  });
}
