import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/privacy/i_miei_dati.dart';

/// 📦 «Scarica i miei dati» — artt. 15 e 20, 19/09/2026.
void main() {
  final quando = DateTime(2026, 9, 19, 21, 30);

  test('il file ha le due metà, server e telefono, e dice cosa sono', () {
    final file = componiIMieiDati(
      dalServer: {
        'account': {'email': 'mario@esempio.test'},
      },
      dalTelefono: {
        '_schema': 33,
        'pesate': [
          {'kg': 72.5},
        ],
      },
      quando: quando,
    );

    final server = file['server'] as Map<String, dynamic>;
    final telefono = file['telefono'] as Map<String, dynamic>;

    expect(
      (server['account'] as Map<String, dynamic>)['email'],
      'mario@esempio.test',
    );
    expect(telefono['pesate'], hasLength(1));
    expect(file['cosa_contiene'], containsPair('server', isA<String>()));
    expect(file['cosa_contiene'], containsPair('telefono', isA<String>()));
    expect(file['creato_il'], quando.toIso8601String());
  });

  test('passa da jsonEncode: è JSON vero, leggibile da un\'altra app', () {
    final file = componiIMieiDati(
      dalServer: const {},
      dalTelefono: const {'_schema': 33},
      quando: quando,
    );

    expect(() => jsonEncode(file), returnsNormally);
  });

  test('il nome porta la data: due esportazioni non si sovrascrivono', () {
    expect(
      nomeDelFileDeiMieiDati(quando),
      'i-miei-dati-training-companion-2026-09-19.json',
    );
  });
}
