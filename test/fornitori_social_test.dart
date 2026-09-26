import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/auth/data/fornitori_social.dart';
import 'package:training_companion/src/features/auth/data/social_sign_in.dart';

/// 🔑 **«Con cosa posso entrare?»** — voce 25, 26/09/2026.
///
/// ══ ⛔ IL DIFETTO CHE QUESTI TEST CHIUDONO ═════════════════════════════════
///
/// 🚨 L'elenco dei fornitori viaggiava **solo** dentro `GymBranding.social`, e
/// il branding arriva con l'accesso — cioè **dopo**. ⛔ Chi apriva l'app per la
/// prima volta aveva `neutral`, con l'elenco vuoto, e i pulsanti «Continua con
/// Google» non comparivano **mai**: proprio a chi servivano.
///
/// ⚠️ La rotta pubblica che serviva a questo è stata tolta con F11 il
/// 24/09/2026. 🚨 Nessuno se n'è accorto per due giorni perché l'accesso social
/// era comunque spento: il sintomo era identico al comportamento atteso.
void main() {
  group('la lettura della risposta del server', () {
    test('tiene i fornitori conosciuti', () {
      expect(leggiIFornitori(['google', 'apple']), [
        SocialProviderId.google,
        SocialProviderId.apple,
      ]);
    });

    /// 🚨 **Il caso che conta.** ⛔ Il server potrebbe un giorno dichiarare un
    /// fornitore nuovo: una versione vecchia dell'app non saprebbe né
    /// disegnarne il pulsante né gestirne l'accesso.
    ///
    /// 💡 Mostrarlo sarebbe peggio che ignorarlo: un pulsante che non porta da
    /// nessuna parte fa sembrare rotta tutta l'applicazione.
    test('⛔ butta via quelli che non conosce', () {
      expect(leggiIFornitori(['google', 'facebook', 'linkedin']), [
        SocialProviderId.google,
      ]);
    });

    /// ⚠️ La risposta arriva dalla rete: può essere qualunque cosa. ⛔ Un
    /// `as List` ottimista qui farebbe morire la schermata d'accesso — cioè la
    /// prima cosa che si vede.
    test('⚠️ una risposta malformata non fa saltare niente', () {
      for (final storta in <Object?>[null, 'google', 42, {}, ['', null]]) {
        expect(
          leggiIFornitori(storta),
          isEmpty,
          reason: 'su ${storta.runtimeType} deve restituire una lista vuota',
        );
      }
    });

    test('una lista vuota resta vuota', () {
      expect(leggiIFornitori(const []), isEmpty);
    });
  });

}
