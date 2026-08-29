import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/trainer/data/utente_seguito.dart';
import 'package:training_companion/src/features/trainer/invio_multiplo.dart';

/// 🎯 Mandare la stessa scheda a più allievi — 3b-U.1.
///
/// ══ 🚨 LA DOMANDA CHE QUESTI TEST DIFENDONO ══════════════════════════════
///
/// *«a chi è arrivata?»* — ed è una domanda che deve avere una risposta anche
/// quando qualcosa va storto, perché **con venti invii qualcosa va storto**:
/// rete che cade, chiave della persona non ancora pubblicata, filo mai aperto.
///
/// ⛔ Un invio multiplo che si ferma al primo errore lascia metà degli allievi
/// senza scheda **e nessuno che lo sappia**: il trainer vede un errore e non ha
/// modo di capire dove si era fermato. Rimanderebbe a tutti — e chi l'aveva già
/// ricevuta se la ritrova due volte in chat — oppure a nessuno.
UtenteSeguito _persona(int id, String nome) => UtenteSeguito(
  id: id,
  nome: nome,
  email: '$nome@esempio.test'.toLowerCase(),
  attivo: true,
);

void main() {
  /// Un contenitore in cui l'invio a una persona è finto: si annota chi è stato
  /// chiamato, e si può far fallire chi si vuole.
  ({ProviderContainer contenitore, List<int> chiamati}) banco({
    Set<int> falliscono = const {},
  }) {
    final chiamati = <int>[];

    final contenitore = ProviderContainer(
      overrides: [
        inviaSchedaAProvider.overrideWithValue((utenteId, scheda) async {
          chiamati.add(utenteId);

          if (falliscono.contains(utenteId)) {
            throw StateError('finto guasto per $utenteId');
          }
        }),
      ],
    );

    addTearDown(contenitore.dispose);

    return (contenitore: contenitore, chiamati: chiamati);
  }

  test('la scheda arriva a tutti i destinatari, uno per uno', () async {
    final b = banco();

    final esiti = await b.contenitore
        .read(invioMultiploProvider)
        .manda(
          scheda: {'name': 'Massa'},
          destinatari: [
            _persona(1, 'Anna'),
            _persona(2, 'Bruno'),
            _persona(3, 'Carla'),
          ],
        );

    expect(b.chiamati, [1, 2, 3]);
    expect(esiti.every((e) => e.riuscito), isTrue);
  });

  /// 🚨 **Il test di U.1.3.** È l'unico che distingue un invio multiplo utile
  /// da uno che sembra funzionare finché la rete regge.
  test('un fallimento su uno non ferma gli altri', () async {
    final b = banco(falliscono: {2});

    final esiti = await b.contenitore
        .read(invioMultiploProvider)
        .manda(
          scheda: {'name': 'Massa'},
          destinatari: [
            _persona(1, 'Anna'),
            _persona(2, 'Bruno'),
            _persona(3, 'Carla'),
          ],
        );

    // ⛔ Il difetto sarebbe qui: `[1, 2]`, cioè Carla mai tentata.
    expect(
      b.chiamati,
      [1, 2, 3],
      reason: 'Il ciclo si è fermato sul guasto invece di andare avanti.',
    );

    expect(esiti.where((e) => e.riuscito).map((e) => e.persona.id), [1, 3]);

    final fallito = esiti.singleWhere((e) => !e.riuscito);
    expect(fallito.persona.nome, 'Bruno');
    expect(fallito.errore, isNotNull);
  });

  /// 💡 Il resoconto serve a **ritentare solo i falliti**: se non si sapesse
  /// chi sono, l'unica strada sarebbe rimandarla a tutti.
  test('il secondo giro tocca solo chi era rimasto fuori', () async {
    final b = banco(falliscono: {2, 3});

    final tutti = [
      _persona(1, 'Anna'),
      _persona(2, 'Bruno'),
      _persona(3, 'Carla'),
    ];

    final primi = await b.contenitore
        .read(invioMultiploProvider)
        .manda(scheda: {'name': 'Massa'}, destinatari: tutti);

    final falliti = primi
        .where((e) => !e.riuscito)
        .map((e) => e.persona)
        .toList(growable: false);

    expect(falliti.map((p) => p.id), [2, 3]);

    b.chiamati.clear();

    await b.contenitore
        .read(invioMultiploProvider)
        .manda(scheda: {'name': 'Massa'}, destinatari: falliti);

    expect(
      b.chiamati,
      [2, 3],
      reason: 'Il ritentativo ha ridisturbato chi l\'aveva già ricevuta.',
    );
  });

  /// 🚨 **R4 — il promemoria privato del trainer non parte.**
  ///
  /// ⚠️ Qui vale doppio rispetto all'invio singolo: dimenticarlo manderebbe
  /// l'appunto con cui il trainer chiama una persona a **tutte** le altre.
  ///
  /// 💡 E si toglie **una volta sola, prima del ciclo**: farlo dentro sarebbe
  /// venti occasioni di sbagliarne una, e quella una non si vedrebbe.
  test('il rif_allievo non parte per nessuno', () async {
    final viste = <Map<String, dynamic>>[];

    final contenitore = ProviderContainer(
      overrides: [
        inviaSchedaAProvider.overrideWithValue((utenteId, scheda) async {
          viste.add(scheda);
        }),
      ],
    );
    addTearDown(contenitore.dispose);

    await contenitore
        .read(invioMultiploProvider)
        .manda(
          scheda: {
            'name': 'Massa',
            'rif_allievo': 'M.R. spalla dx',
            'days': [
              {'name': 'Giorno 1'},
            ],
          },
          destinatari: [_persona(1, 'Anna'), _persona(2, 'Bruno')],
        );

    expect(viste.length, 2);

    for (final scheda in viste) {
      expect(scheda.containsKey('rif_allievo'), isFalse);

      // 💡 E lo spoglio resta chirurgico: non è una whitelist, quindi i campi
      // che l'app non conosce ancora sopravvivono.
      expect(scheda['name'], 'Massa');
      expect((scheda['days'] as List).length, 1);
    }
  });

  /// ⚠️ L'originale del chiamante non si tocca: il compositore lo sta ancora
  /// mostrando, e vedersi sparire il proprio promemoria dallo schermo dopo un
  /// invio sembrerebbe una perdita di dati.
  test('la scheda originale del trainer resta intatta', () async {
    final b = banco();

    final originale = <String, dynamic>{
      'name': 'Massa',
      'rif_allievo': 'M.R. spalla dx',
    };

    await b.contenitore
        .read(invioMultiploProvider)
        .manda(scheda: originale, destinatari: [_persona(1, 'Anna')]);

    expect(originale['rif_allievo'], 'M.R. spalla dx');
  });

  test('senza destinatari non si manda niente e non si esplode', () async {
    final b = banco();

    final esiti = await b.contenitore
        .read(invioMultiploProvider)
        .manda(scheda: {'name': 'Massa'}, destinatari: const []);

    expect(esiti, isEmpty);
    expect(b.chiamati, isEmpty);
  });
}
