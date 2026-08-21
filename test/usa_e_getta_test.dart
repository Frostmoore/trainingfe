import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/media/tipo_foto.dart';
import 'package:training_companion/src/features/chat/chat_controller.dart';

/// I messaggi «una volta sola», lato app — N16.
///
/// ── 🚨 Cosa difendono questi test ──────────────────────────────────────────
///
/// Che una cosa mandata «una volta sola» **non sopravviva**. È un difetto che
/// non si vede da nessuna parte: nella chat la foto è sparita regolarmente, e
/// intanto la sua copia sta su Drive per sempre. Chi l'ha mandata non lo
/// scoprirebbe mai.
void main() {
  group('la traccia di ciò che non c\'è più', () {
    test('dice se era una foto o un messaggio', () {
      final foto = ChatMessage.effimeraSpenta(
        id: 1,
        senderId: 2,
        eraFoto: true,
      );
      final testo = ChatMessage.effimeraSpenta(
        id: 2,
        senderId: 2,
        eraFoto: false,
      );

      expect(foto.body, 'Foto effimera');
      expect(testo.body, 'Messaggio effimero');
    });

    /*
     * 🚨 **Non è un messaggio illeggibile.** Se `leggibile` fosse `false`,
     * l'interfaccia direbbe «questo messaggio non è più leggibile su questo
     * dispositivo» — che manderebbe qualcuno a cercare un guasto inesistente.
     * Il messaggio non è rotto: è stato usato.
     */
    test('non si confonde con una busta che non si apre', () {
      final spenta = ChatMessage.effimeraSpenta(
        id: 1,
        senderId: 2,
        eraFoto: true,
      );

      expect(spenta.leggibile, isTrue);
      expect(spenta.spenta, isTrue);
      expect(spenta.usaEGetta, isTrue);
      expect(spenta.contenuto, isNull);
    });
  });

  group('dove vivono le foto effimere', () {
    /// 🚨 **La regola che rende vera tutta la funzione.**
    test('stanno nella cache, quindi fuori dal backup per costruzione', () {
      expect(TipoFoto.effimere.nelBackup, isFalse);

      /*
       * ⚠️ `permanente: false` vuol dire `Cache/`, e Android esclude **sempre**
       * `getCacheDir()` dal backup — un'esclusione che non è sovrascrivibile.
       * È il motivo per cui una foto usa e getta non può finire su Drive
       * nemmeno per sbaglio: non dipende da una riga di configurazione che
       * qualcuno può cambiare.
       */
      expect(TipoFoto.effimere.permanente, isFalse);
    });

    test('scadono in 24 ore, come sul server', () {
      expect(TipoFoto.effimere.scadenza, const Duration(hours: 24));

      // 💡 Lo stesso patto degli allegati: due scadenze diverse avrebbero
      // prodotto il caso peggiore — la traccia che resta e il file che non c'è
      // più, o viceversa.
      expect(TipoFoto.cheScadono, contains(TipoFoto.effimere));
    });

    /// ⚠️ Le foto normali della chat **restano**: sono un'altra cosa.
    test('le foto normali della chat non scadono e stanno nel backup', () {
      expect(TipoFoto.chat.nelBackup, isTrue);
      expect(TipoFoto.chat.permanente, isTrue);
      expect(TipoFoto.chat.scadenza, isNull);
    });
  });
}
