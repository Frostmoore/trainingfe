import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

/// Un comune, come lo restituisce il server — M1.2.
class Comune {
  const Comune({
    required this.id,
    required this.nome,
    required this.esteso,
    this.provincia,
    this.attivo = true,
  });

  factory Comune.fromJson(Map<String, dynamic> j) => Comune(
    id: (j['id'] as num).toInt(),
    nome: j['nome'] as String? ?? '',
    esteso: j['esteso'] as String? ?? (j['nome'] as String? ?? ''),
    provincia: j['provincia'] as String?,

    /*
     * 💡 Se il comune scelto è stato accorpato, il server lo dice: l'app deve
     * poterlo scrivere — «il tuo comune è stato accorpato, scegline un altro» —
     * invece di mostrarlo come se fosse normale e lasciare la persona fuori da
     * ogni ricerca senza spiegazione.
     */
    attivo: j['attivo'] as bool? ?? true,
  );

  final int id;
  final String nome;

  /// «Bologna (BO)». 💡 La provincia c'è **sempre**, anche per i capoluoghi:
  /// esistono otto comuni che si chiamano `Castro`, e senza la sigla un elenco
  /// di risultati sarebbe una fila di righe identiche fra cui non si può
  /// scegliere.
  final String esteso;

  final String? provincia;
  final bool attivo;
}

/// La ricerca dei comuni per il campo città.
///
/// 💡 `autoDispose`: ogni ricerca è diversa, e tenerle tutte vorrebbe dire
/// conservare l'elenco di quello che una persona ha digitato.
final ricercaComuniProvider = FutureProvider.autoDispose
    .family<List<Comune>, String>((ref, testo) async {
      final q = testo.trim();

      // 💡 Lo stesso minimo che applica il server: ripeterlo qui evita una
      // richiesta che si sa già che tornerà vuota.
      if (q.length < 2) return const [];

      final elenco = await ref
          .watch(apiClientProvider)
          .get<List<dynamic>>('/comuni', query: {'q': q});

      return elenco
          .whereType<Map<String, dynamic>>()
          .map(Comune.fromJson)
          .toList(growable: false);
    });

/// La città scelta adesso, o `null`.
///
/// 🚨 **Non è obbligatoria e non lo diventerà**: chi non vuole dire dove sta usa
/// l'applicazione intera e perde solo l'ordinamento per vicinanza nel catalogo
/// — che è un servizio che gli si offre, non un pedaggio per entrare.
final cittaProvider = FutureProvider<Comune?>((ref) async {
  final dati = await ref
      .watch(apiClientProvider)
      .get<Map<String, dynamic>?>('/account/citta');

  return dati == null ? null : Comune.fromJson(dati);
});

/// Scrive (o azzera) la città.
///
/// ⚠️ `null` **azzera**, e deve poterlo fare: un campo che si può solo riempire
/// e mai svuotare è un campo obbligatorio scritto male.
final salvaCittaProvider = Provider(
  (ref) => (int? comuneId) async {
    await ref
        .read(apiClientProvider)
        .put<dynamic>('/account/citta', body: {'comune_id': comuneId});

    ref.invalidate(cittaProvider);
  },
);
