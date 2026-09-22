import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/media/tipo_foto.dart';
import 'package:training_companion/src/core/storage/archivio_salute.dart';
import 'package:training_companion/src/features/diary/data/alimento_catalogo.dart';

/// 📷 **La foto sugli alimenti propri** — A4 di `plan_blocco_A.md`, 22/09/2026.
///
/// 📌 Il committente, 22/09: *«foto su alimenti propri teniamola»*.
///
/// 🚨 Quello che questi test difendono: la foto si lega all'alimento **per
/// nome** (lo stesso criterio con cui l'app riconosce un alimento tuo), si
/// toglie senza toccare altri, ed entra nel backup — il file e la riga.
void main() {
  late ArchivioSalute archivio;

  setUp(() => archivio = ArchivioSalute.inMemoria());
  tearDown(() => archivio.close());

  test('si mette e si ritrova', () async {
    await archivio.mettiFotoAllAlimentoMio(
      'Torta della nonna',
      'foto/alimenti_miei/1.jpg',
    );

    expect(
      await archivio.fotoDellAlimentoMio('Torta della nonna'),
      'foto/alimenti_miei/1.jpg',
    );
  });

  /// ⚠️ «Torta della nonna» e «torta  della nonna» sono lo stesso alimento
  /// per `alimentiScrittiDaMe`, che raggruppa per `lower(descrizione)`: devono
  /// avere la stessa foto.
  test('maiuscole e spazi doppi non ne fanno un altro alimento', () async {
    await archivio.mettiFotoAllAlimentoMio(
      'Torta della nonna',
      'foto/alimenti_miei/1.jpg',
    );

    expect(
      await archivio.fotoDellAlimentoMio('  torta   DELLA nonna '),
      'foto/alimenti_miei/1.jpg',
    );
  });

  test('una foto nuova prende il posto della vecchia', () async {
    await archivio.mettiFotoAllAlimentoMio(
      'Frittata',
      'foto/alimenti_miei/1.jpg',
    );
    await archivio.mettiFotoAllAlimentoMio(
      'frittata',
      'foto/alimenti_miei/2.jpg',
    );

    expect(
      await archivio.fotoDellAlimentoMio('Frittata'),
      'foto/alimenti_miei/2.jpg',
    );
  });

  test('togliendola sparisce solo la sua', () async {
    await archivio.mettiFotoAllAlimentoMio(
      'Frittata',
      'foto/alimenti_miei/1.jpg',
    );
    await archivio.mettiFotoAllAlimentoMio('Torta', 'foto/alimenti_miei/2.jpg');

    await archivio.mettiFotoAllAlimentoMio('Frittata', null);

    expect(await archivio.fotoDellAlimentoMio('Frittata'), isNull);
    expect(
      await archivio.fotoDellAlimentoMio('Torta'),
      'foto/alimenti_miei/2.jpg',
    );
  });

  /// 💡 La ricerca le chiede tutte insieme, a ogni tasto: una lettura sola.
  test('più alimenti in una lettura, per chiave', () async {
    await archivio.mettiFotoAllAlimentoMio(
      'Frittata',
      'foto/alimenti_miei/1.jpg',
    );
    await archivio.mettiFotoAllAlimentoMio('Torta', 'foto/alimenti_miei/2.jpg');

    final foto = await archivio.fotoDegliAlimentiMieiPer([
      'frittata',
      'Torta',
      'Pane',
    ]);

    expect(foto, {
      'frittata': 'foto/alimenti_miei/1.jpg',
      'torta': 'foto/alimenti_miei/2.jpg',
    });
  });

  test('un nome vuoto non scrive niente', () async {
    await archivio.mettiFotoAllAlimentoMio('   ', 'foto/alimenti_miei/1.jpg');

    expect(await archivio.fotoDegliAlimentiMieiPer(['']), isEmpty);
  });

  group('il backup', () {
    /// 🚨 La riga è nell'archivio, quindi nel file di backup.
    test('la tabella c\'è nel file esportato', () async {
      await archivio.mettiFotoAllAlimentoMio(
        'Frittata',
        'foto/alimenti_miei/1.jpg',
      );

      final dati = await archivio.esportaPerBackup();

      expect(dati['foto_degli_alimenti_miei'], hasLength(1));
    });

    /// ⛔ E il file non è una cache: non è `alimenti`, che si riscarica.
    test('le foto sono permanenti e vanno nel backup', () {
      expect(TipoFoto.alimentiMiei.permanente, isTrue);
      expect(TipoFoto.alimentiMiei.nelBackup, isTrue);
      expect(TipoFoto.alimenti.nelBackup, isFalse);
    });
  });

  test('un alimento del telefono è «mio», uno del catalogo no', () {
    const mio = AlimentoCatalogo(id: 0, nome: 'Frittata');
    const delCatalogo = AlimentoCatalogo(id: 42, nome: 'Pane');

    expect(mio.eMio, isTrue);
    expect(delCatalogo.eMio, isFalse);
  });
}
