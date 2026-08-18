import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/chat/data/permesso_negato.dart';

/// Come l'app legge il «no» del cancello della chat — M3.4, 18/08/2026.
///
/// 🚨 **Da questa lettura dipende cosa vede la persona**: la spiegazione giusta,
/// oppure «Messaggio non inviato. Riprova.» — che a chi ha finito i tre messaggi
/// di presentazione fa riprovare, fallire di nuovo, e concludere che l'app è
/// rotta.
void main() {
  DioException risposta(int codice, Object? corpo) => DioException(
    requestOptions: RequestOptions(path: '/conversations/1/messages'),
    response: Response<Object?>(
      requestOptions: RequestOptions(path: '/conversations/1/messages'),
      statusCode: codice,
      data: corpo,
    ),
  );

  test('legge la spiegazione e la proposta di abbonamento', () {
    final rifiuto = PermessoNegato.da(
      risposta(403, {
        'message': 'Hai usato i tre messaggi di presentazione.',
        'code': 'tre_messaggi_esauriti',
        'permesso': {
          'consentito': false,
          'codice': 'tre_messaggi_esauriti',
          'spiegazione': 'Hai usato i tre messaggi di presentazione.',
          'restanti': 0,
          'proponi_abbonamento': true,
        },
      }),
    );

    expect(rifiuto, isNotNull);
    expect(rifiuto!.proponiAbbonamento, isTrue);
    expect(rifiuto.codice, 'tre_messaggi_esauriti');
    expect(rifiuto.spiegazione, contains('tre messaggi'));
  });

  test('un diniego di altra natura NON propone l\'abbonamento', () {
    /*
     * 🚨 Fuori dal caso dei tre messaggi non c'è niente da vendere: proporre
     * l'abbonamento a chi non può scrivere a un trainer dipendente sarebbe
     * vendergli una cosa che non risolve il suo problema.
     */
    final rifiuto = PermessoNegato.da(
      risposta(403, {
        'permesso': {
          'consentito': false,
          'codice': 'conversation_closed',
          'spiegazione': 'Questa conversazione è stata chiusa.',
          'proponi_abbonamento': false,
        },
      }),
    );

    expect(rifiuto, isNotNull);
    expect(rifiuto!.proponiAbbonamento, isFalse);
  });

  test('un errore di rete NON è un diniego del cancello', () {
    /*
     * ⚠️ Qui «riprova» è davvero la cosa giusta da dire, e mostrare una
     * spiegazione del cancello sarebbe inventarsi un motivo.
     */
    final rete = DioException(
      requestOptions: RequestOptions(path: '/x'),
      type: DioExceptionType.connectionTimeout,
    );

    expect(PermessoNegato.da(rete), isNull);
  });

  test('un 500 NON è un diniego del cancello', () {
    expect(PermessoNegato.da(risposta(500, {'message': 'Errore'})), isNull);
  });

  test('un 403 SENZA il blocco permesso non si interpreta', () {
    /*
     * 🚨 Un `403` senza quel blocco è un rifiuto di un'altra natura — una
     * policy, un token scaduto — e trattarlo come un diniego del cancello
     * mostrerebbe una spiegazione su un problema diverso.
     */
    expect(
      PermessoNegato.da(risposta(403, {'message': 'Non autorizzato.'})),
      isNull,
    );
  });

  test('un corpo che non è una mappa non fa esplodere niente', () {
    // 💡 Capita davvero: un proxy che risponde HTML, una pagina d'errore.
    expect(PermessoNegato.da(risposta(403, '<html>vietato</html>')), isNull);
    expect(PermessoNegato.da(risposta(403, null)), isNull);
  });

  test('una spiegazione vuota si tratta come assente', () {
    // ⚠️ Un foglio con dentro il vuoto è peggio di un messaggio generico.
    expect(
      PermessoNegato.da(
        risposta(403, {
          'permesso': {'spiegazione': '', 'proponi_abbonamento': true},
        }),
      ),
      isNull,
    );
  });
}
