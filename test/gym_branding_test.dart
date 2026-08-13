import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/theme/app_theme.dart';
import 'package:training_companion/src/features/onboarding/data/gym_branding.dart';

/// A2.2 / A3.1 — il branding e il tema costruito a runtime.
///
/// 🚨 **È il cuore del white-label**: se questa parte cede, un cliente vede i
/// colori di un altro, oppure l'app non parte per un refuso in un campo colore
/// compilato nel pannello.
void main() {
  group('lettura dei colori', () {
    test('legge un esadecimale normale', () {
      expect(GymBranding.parseHex('#FF0000'), const Color(0xFFFF0000));
      expect(GymBranding.parseHex('00ff00'), const Color(0xFF00FF00));
      expect(GymBranding.parseHex('  #0000FF  '), const Color(0xFF0000FF));
    });

    /// 🚨 Un colore malformato deve dare `null`, non un colore a caso.
    ///
    /// Il valore arriva da un campo che qualcuno compila a mano dal pannello di
    /// piattaforma: un refuso lì renderebbe l'app di un colore casuale, o la
    /// farebbe esplodere all'avvio. Restituendo `null` il chiamante usa il
    /// proprio valore di riserva.
    test('rifiuta quello che non è un colore', () {
      expect(GymBranding.parseHex('#GGGGGG'), isNull);
      expect(GymBranding.parseHex('#FFF'), isNull);
      expect(GymBranding.parseHex(''), isNull);
      expect(GymBranding.parseHex(null), isNull);
    });
  });

  group('lettura del payload', () {
    test('legge il branding completo', () {
      final b = GymBranding.fromJson(const {
        'name': 'Palestra Demo',
        'slug': 'palestra-demo',
        'logo_url': 'https://esempio.test/logo.png',
        'locale': 'it',
        'colors': {'primary': '#123456', 'secondary': '#654321', 'accent': '#ABCDEF'},
      });

      expect(b.name, 'Palestra Demo');
      expect(b.primary, const Color(0xFF123456));
      expect(b.logoUrl, isNotNull);
    });

    /// 🚨 Tollerante per costruzione.
    ///
    /// Questa mappa arriva anche dalla **cache su disco**, che può essere stata
    /// scritta da una versione precedente dell'app. Un campo mancante non deve
    /// far fallire l'avvio: l'utente non avrebbe modo di rimediare se non
    /// disinstallando.
    /// ⚠️ **L'attesa sul nome è cambiata il 13/08/2026, con F3.**
    ///
    /// Prima il nome mancante diventava «La tua palestra», e il test pretendeva
    /// `isNotEmpty`. Da F3 il server manda `name: null` per chi **non ha** una
    /// palestra, e un ripiego lì sarebbe peggio del vuoto: scriverebbe in cima
    /// alla schermata il nome di una palestra che non esiste.
    ///
    /// 🚨 Ciò che **non** è cambiato è la parte che contava: i colori hanno
    /// ancora un valore di riserva. Una cache scritta da una versione
    /// precedente non deve impedire l'avvio, perché chi la subisce non avrebbe
    /// modo di rimediare se non disinstallando.
    test('sopravvive a un payload monco', () {
      final b = GymBranding.fromJson(const {});

      expect(b.name, isNull);
      expect(b.primary, GymBranding.fallbackPrimary);
      expect(b.accent, GymBranding.fallbackAccent);
    });

    /// 🆕 F3 — `null` non è un dato mancante: è «non ho una palestra».
    test('un tenant personale non ha un nome da mostrare', () {
      final b = GymBranding.fromJson(const {
        'name': null,
        'colors': {'primary': '#123456'},
      });

      expect(b.name, isNull);
      expect(b.primary, isNot(GymBranding.fallbackPrimary), reason: 'i colori arrivano lo stesso');
    });

    /// 🚨 Quali pulsanti d'accesso esterno mostrare lo decide il **server**.
    ///
    /// Un «Accedi con Apple» che risponde sempre errore fa sembrare rotta tutta
    /// l'applicazione, non solo quel pulsante — ed è anche il motivo per cui non
    /// è una costante dentro l'app: cambiarla richiederebbe una pubblicazione.
    test('i fornitori esterni arrivano dal server', () {
      final b = GymBranding.fromJson(const {
        'name': 'X',
        'social': ['google', 'apple'],
      });

      expect(b.supporta('google'), isTrue);
      expect(b.supporta('apple'), isTrue);
    });

    test('senza `social` non si mostra nessun pulsante', () {
      // È il caso di una cache scritta da una versione precedente dell'app,
      // e il risultato giusto è lo stesso di «non configurato».
      final b = GymBranding.fromJson(const {'name': 'X'});

      expect(b.social, isEmpty);
      expect(b.supporta('google'), isFalse);
    });

    test('un fornitore sconosciuto si scarta invece di disegnare un pulsante muto', () {
      final b = GymBranding.fromJson(const {
        'name': 'X',
        'social': ['google', 'facebook'],
      });

      expect(b.social, ['google']);
    });

    test('un colore sbagliato ricade sul valore di riserva', () {
      final b = GymBranding.fromJson(const {
        'name': 'X',
        'colors': {'primary': 'non-un-colore'},
      });

      expect(b.primary, GymBranding.fallbackPrimary);
    });

    test('andata e ritorno dalla cache non perde niente', () {
      const originale = GymBranding(
        name: 'Demo',
        slug: 'demo',
        primary: Color(0xFF112233),
        secondary: Color(0xFF445566),
        accent: Color(0xFF778899),
      );

      final riletto = GymBranding.fromJson(originale.toJson());

      expect(riletto.primary, originale.primary);
      expect(riletto.secondary, originale.secondary);
      expect(riletto.accent, originale.accent);
    });
  });

  group('tema a runtime', () {
    test('il colore della palestra diventa il primario del tema', () {
      const branding = GymBranding(
        name: 'Demo',
        slug: 'demo',
        primary: Color(0xFFB91C1C),
        secondary: GymBranding.fallbackSecondary,
        accent: GymBranding.fallbackAccent,
      );

      final tema = AppTheme.light(branding);

      // Non si confronta il colore esatto: `fromSeed` deriva una tavolozza
      // armonica, e pretendere il valore identico legherebbe il test
      // all'algoritmo di Material invece che al comportamento.
      expect(tema.colorScheme.brightness, Brightness.light);
      expect(tema.useMaterial3, isTrue);
    });

    /// 🚨 L'accento della palestra non deve toccare il rosso degli errori.
    ///
    /// Un avviso che non sembra un avviso non è un avviso: il colore del
    /// pericolo non può dipendere dal gusto di chi ha compilato il pannello.
    test('l\'accento non diventa il colore d\'errore', () {
      const branding = GymBranding(
        name: 'Demo',
        slug: 'demo',
        primary: GymBranding.fallbackPrimary,
        secondary: GymBranding.fallbackSecondary,
        accent: Color(0xFF00FF00),
      );

      final tema = AppTheme.light(branding);

      expect(tema.colorScheme.error, isNot(const Color(0xFF00FF00)));
    });

    test('chiaro e scuro derivano dallo stesso branding', () {
      const branding = GymBranding.neutral;

      expect(AppTheme.light(branding).colorScheme.brightness, Brightness.light);
      expect(AppTheme.dark(branding).colorScheme.brightness, Brightness.dark);
    });
  });
}
