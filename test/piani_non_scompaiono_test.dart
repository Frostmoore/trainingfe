import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/storage/archivio_salute.dart';

/// La consegna via chat e l'archivio che non perde niente — G8 (D15, R8).
///
/// 🚨 **Cosa difende questa classe.** Il committente ha chiesto che schede e
/// piani **non scompaiano**, «alla fine li ha pagati». Le tre cose che, fatte
/// male, li farebbero sparire senza dare errore:
///
/// 1. una versione **più vecchia** che arriva dopo e sovrascrive quella buona;
/// 2. un piano buttato che **torna** al messaggio successivo;
/// 3. la data di ricezione che si sposta a ogni correzione del trainer, e fa
///    sembrare nuovo un piano seguito da mesi.
void main() {
  late ArchivioSalute archivio;

  setUp(() => archivio = ArchivioSalute.inMemoria());
  tearDown(() => archivio.close());

  group('l\'identità stabile', () {
    test('una versione nuova sostituisce, non affianca', () async {
      await archivio.salvaPiano(
        messaggioId: 1,
        mittenteId: 9,
        nome: 'Definizione',
        piano: '{"name":"Definizione"}',
        origineId: 'ABC',
      );

      await archivio.salvaPiano(
        messaggioId: 5,
        mittenteId: 9,
        nome: 'Definizione (corretta)',
        piano: '{"name":"Definizione v2"}',
        origineId: 'ABC',
      );

      final piani = await archivio.piani();

      // 🚨 Uno, non due. Senza `origine_id` sarebbero due piani nell'elenco
      // dell'allievo, e nessuno saprebbe quale seguire.
      expect(piani.length, 1);
      expect(piani.first.nome, 'Definizione (corretta)');
    });

    test('una versione più vecchia che arriva dopo NON sovrascrive', () async {
      await archivio.salvaPiano(
        messaggioId: 10,
        mittenteId: 9,
        nome: 'Buona',
        piano: '{}',
        origineId: 'ABC',
      );

      final scritto = await archivio.salvaPiano(
        messaggioId: 3,
        mittenteId: 9,
        nome: 'Vecchia',
        piano: '{}',
        origineId: 'ABC',
      );

      /*
       * ⚠️ **I messaggi arrivano fuori ordine**, e non è un caso raro: l'app
       * riprende una conversazione vecchia, due dispositivi si sincronizzano,
       * la rete restituisce una pagina in ritardo.
       *
       * 🚨 Se «l'ultimo che arriva vince», l'allievo si ritrova la versione
       * sbagliata del proprio piano — e non ha modo di accorgersene.
       */
      expect(scritto, isFalse);
      expect((await archivio.piani()).first.nome, 'Buona');
    });

    test('la data della prima ricezione non si sposta', () async {
      await archivio.salvaPiano(
        messaggioId: 1,
        mittenteId: 9,
        nome: 'Piano',
        piano: '{}',
        origineId: 'ABC',
      );

      final prima = (await archivio.piani()).first.ricevutaIl;

      await Future<void>.delayed(const Duration(milliseconds: 5));

      await archivio.salvaPiano(
        messaggioId: 2,
        mittenteId: 9,
        nome: 'Piano corretto',
        piano: '{}',
        origineId: 'ABC',
      );

      final dopo = (await archivio.piani()).first;

      /*
       * 💡 È la data che l'allievo riconosce («quello di marzo»). Spostarla a
       * ogni correzione del trainer gli farebbe sembrare **nuovo** un piano che
       * segue da mesi — e con lui tutto il ragionamento su cosa stava facendo.
       */
      expect(dopo.ricevutaIl, prima);
      expect(dopo.aggiornatoIl, isNotNull);
    });

    test('senza origine_id si cade sul comportamento vecchio', () async {
      await archivio.salvaPiano(
        messaggioId: 1,
        mittenteId: 9,
        nome: 'v1',
        piano: '{}',
      );

      await archivio.salvaPiano(
        messaggioId: 2,
        mittenteId: 9,
        nome: 'v1 di nuovo',
        piano: '{}',
      );

      /*
       * ⚠️ **Due righe, ed è corretto.** Le buste scritte prima di G8 non hanno
       * l'identità: senza, l'unica chiave è il messaggio. È il comportamento di
       * prima — meno furbo, non sbagliato — e va conservato perché quelle buste
       * esistono già nelle conversazioni.
       */
      expect((await archivio.piani()).length, 2);
    });

    test('lo stesso messaggio due volte non fa due copie', () async {
      for (var i = 0; i < 2; i++) {
        await archivio.salvaPiano(
          messaggioId: 7,
          mittenteId: 9,
          nome: 'Piano',
          piano: '{}',
          origineId: 'ABC',
        );
      }

      expect((await archivio.piani()).length, 1);
    });
  });

  group('quello che è stato buttato non torna', () {
    test('un piano rifiutato non si risalva', () async {
      await archivio.salvaPiano(
        messaggioId: 1,
        mittenteId: 9,
        nome: 'Piano',
        piano: '{}',
        origineId: 'ABC',
      );

      await archivio.dimenticaPiano((await archivio.piani()).first.id);

      final scritto = await archivio.salvaPiano(
        messaggioId: 2,
        mittenteId: 9,
        nome: 'Piano',
        piano: '{}',
        origineId: 'ABC',
      );

      /*
       * 🚨 **Senza questo, il salvataggio automatico è una trappola**: chi butta
       * un piano se lo ritrova al messaggio successivo, lo butta di nuovo, e
       * così per sempre. Buttare è una decisione, e va ricordata.
       */
      expect(scritto, isFalse);
      expect(await archivio.piani(), isEmpty);
      expect(await archivio.eRifiutato('ABC'), isTrue);
    });

    test('vale anche per le schede', () async {
      await archivio.salvaSchedaDallaChat(
        messaggioId: 1,
        nome: 'Full body',
        scheda: '{}',
        origineId: 'XYZ',
      );

      await archivio.cancellaScheda((await archivio.tutteLeSchede()).first.id);

      await archivio.salvaSchedaDallaChat(
        messaggioId: 2,
        nome: 'Full body',
        scheda: '{}',
        origineId: 'XYZ',
      );

      expect(await archivio.tutteLeSchede(), isEmpty);
    });
  });

  group('R8 — niente li cancella per un fatto del server', () {
    test('svuotare l\'archivio è l\'UNICA cosa che li porta via', () async {
      await archivio.salvaPiano(
        messaggioId: 1,
        mittenteId: 9,
        nome: 'Piano',
        piano: '{}',
        origineId: 'ABC',
      );
      await archivio.salvaSchedaDallaChat(
        messaggioId: 2,
        nome: 'Scheda',
        scheda: '{}',
        origineId: 'XYZ',
      );

      expect((await archivio.piani()).length, 1);
      expect((await archivio.tutteLeSchede()).length, 1);

      /*
       * 🚨 **`svuota()` si chiama in due soli casi** (§27.1 dell'atlante app):
       * la cancellazione dell'account, e l'ingresso di una **persona diversa**
       * sul telefono. Non al logout, non alla disattivazione da parte del
       * trainer, non alla scadenza di un abbonamento, non entrando in una
       * palestra.
       *
       * ⚠️ Il 13/08/2026 una pulizia scritta con una buona motivazione ha fatto
       * perdere mesi di dati a chi stava solo uscendo e rientrando. Questo test
       * fissa il perimetro.
       */
      await archivio.svuota();

      expect(await archivio.piani(), isEmpty);
      expect(await archivio.tutteLeSchede(), isEmpty);
    });

    test('svuotando si azzerano anche i rifiutati', () async {
      await archivio.salvaPiano(
        messaggioId: 1,
        mittenteId: 9,
        nome: 'Piano',
        piano: '{}',
        origineId: 'ABC',
      );
      await archivio.dimenticaPiano((await archivio.piani()).first.id);

      expect(await archivio.eRifiutato('ABC'), isTrue);

      await archivio.svuota();

      /*
       * 💡 I rifiutati sono una decisione di **questa** persona. Chi arriva dopo
       * su questo telefono non deve ereditare i piani che qualcun altro aveva
       * buttato: se ne riceve uno, deve vederlo.
       */
      expect(await archivio.eRifiutato('ABC'), isFalse);
    });
  });
}
