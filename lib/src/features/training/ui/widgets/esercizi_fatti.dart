/// Gli esercizi di un allenamento, **una card per esercizio** — 3b-B.20.3.
///
/// ══ 📌 LA RICHIESTA ═══════════════════════════════════════════════════════
///
/// *«gli esercizi che ho fatto devono essere più dettagliati. va bene una card
/// per uno come hai fatto tu, ma con tutti i dettagli (rep, pesi, serie)»*.
///
/// ⛔ **Prima le serie stavano tutte su una riga**, separate da un puntino:
/// `8 × 40 kg · 8 × 40 kg · 7 × 40 kg · 6 × 40 kg`. Con quattro serie si legge
/// a fatica, con sette non si legge più — e il numero della serie, che è quello
/// che si cerca quando si vuole sapere dove si è calato, non c'era proprio.
///
/// 💡 Una riga per serie, numerata, e in fondo il volume dell'esercizio.
///
/// ══ 🚨 ED È UN FILE A PARTE PER UNA RAGIONE — B.20 ════════════════════════
///
/// 📌 *«nel caso di allenamenti con l'orologio, se ci ho allegato una scheda, la
/// pagina deve diventare IDENTICA a quella di un allenamento nato nell'app»*.
///
/// ⚠️ «Identica» non si ottiene scrivendo la stessa cosa due volte: si ottiene
/// scrivendola **una** e montandola in due posti. ⛔ Due copie della stessa card
/// divergono sempre, e la seconda a divergere è quella che nessuno guarda.
library;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/session_models.dart';

/// Un esercizio da mostrare, **qualunque sia la sua provenienza**.
///
/// 🚨 Le serie **registrate** e la **prescrizione di una scheda** sono due cose
/// diverse, e la card deve poterle mostrare entrambe senza fingere che siano la
/// stessa: chi si allena con l'orologio non ha ripetizioni registrate, e
/// inventargliele «per coerenza» sarebbe dato finto.
class EsercizioFatto {
  const EsercizioFatto({
    required this.nome,
    this.serie = const [],
    this.prescrizione,
    this.note,
  });

  /// Le serie di un esercizio, ricostruite da quelle registrate.
  factory EsercizioFatto.dalleSerie({
    required String nome,
    required List<LoggedSet> serie,
  }) => EsercizioFatto(nome: nome, serie: serie);

  final String nome;

  /// Le serie davvero registrate. Vuota per un allenamento del polso.
  final List<LoggedSet> serie;

  /// Cosa diceva la scheda — `'4 × 12'`. ⚠️ Si mostra **solo** quando di serie
  /// registrate non ce ne sono: quando ci sono, quello che conta è cos'hai
  /// fatto, non cosa c'era scritto.
  final String? prescrizione;

  final String? note;

  /// Il volume: ripetizioni × peso, sommato sulle serie.
  ///
  /// 💡 È il numero che dice se oggi è stato più duro dell'altra volta, molto
  /// più del tempo passato in palestra. ⚠️ `null` quando non c'è niente da
  /// sommare — a corpo libero, o su un allenamento del polso: `0 kg` sarebbe
  /// una risposta sbagliata a una domanda che non si può fare.
  double? get volume {
    var totale = 0.0;

    for (final s in serie) {
      totale += (s.reps ?? 0) * (s.weight ?? 0);
    }

    return totale == 0 ? null : totale;
  }

  /// Le ripetizioni totali, quando ci sono.
  int? get ripetizioni {
    var totale = 0;

    for (final s in serie) {
      totale += s.reps ?? 0;
    }

    return totale == 0 ? null : totale;
  }
}

/// Raggruppa le serie per esercizio, **nell'ordine in cui sono state fatte**.
///
/// ⚠️ `Map` di Dart conserva l'ordine di inserimento: è quello che rende
/// l'elenco il racconto della seduta invece che una lista alfabetica.
List<EsercizioFatto> raggruppaPerEsercizio(List<LoggedSet> serie) {
  final per = <String, List<LoggedSet>>{};

  for (final s in serie) {
    per.putIfAbsent(s.exerciseName, () => []).add(s);
  }

  return [
    for (final voce in per.entries)
      EsercizioFatto.dalleSerie(nome: voce.key, serie: voce.value),
  ];
}

/// La card di un esercizio.
class CardEsercizioFatto extends StatelessWidget {
  const CardEsercizioFatto({required this.esercizio, super.key});

  final EsercizioFatto esercizio;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final serie = esercizio.serie;

    return Card(
      margin: const EdgeInsets.only(bottom: Gap.sm),
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    esercizio.nome,
                    style: tema.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (serie.isNotEmpty)
                  Text(
                    serie.length == 1 ? '1 serie' : '${serie.length} serie',
                    style: tema.textTheme.labelMedium?.copyWith(
                      color: tema.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),

            if (esercizio.note != null && esercizio.note!.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: Gap.xs),
                child: Text(
                  esercizio.note!,
                  style: tema.textTheme.bodySmall?.copyWith(
                    color: tema.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),

            /*
             * ⛔ **Senza serie registrate non si finge.** Un allenamento letto
             * dall'orologio non ha ripetizioni: si mostra cosa diceva la scheda,
             * e si dice che è quello. 🚨 Riempire con dei numeri inventati
             * darebbe una pagina che *sembra* informata — la specie di dato che
             * è peggio di nessun dato.
             */
            if (serie.isEmpty) ...[
              const SizedBox(height: Gap.xs),
              Text(
                esercizio.prescrizione == null
                    ? 'Nessuna serie registrata.'
                    : '${esercizio.prescrizione} da scheda',
                style: tema.textTheme.bodyMedium?.copyWith(
                  color: tema.colorScheme.onSurfaceVariant,
                ),
              ),
            ] else ...[
              const SizedBox(height: Gap.sm),

              // 💡 Una riga per serie, e **numerata**: «alla quarta sono
              // calato» è la cosa che si vuole leggere, e da una riga sola
              // separata da puntini non si legge.
              for (final (indice, s) in serie.indexed)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 26,
                        child: Text(
                          '${indice + 1}',
                          style: tema.textTheme.labelMedium?.copyWith(
                            color: tema.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        s.reps == null ? '—' : '${s.reps} rip',
                        style: tema.textTheme.bodyMedium,
                      ),
                      if (s.weight != null) ...[
                        Text(
                          '  ×  ',
                          style: tema.textTheme.bodySmall?.copyWith(
                            color: tema.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          '${kg(s.weight!)} kg',
                          style: tema.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (s.reps != null && s.weight != null)
                        Text(
                          '${kg(s.reps! * s.weight!)} kg',
                          style: tema.textTheme.bodySmall?.copyWith(
                            color: tema.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),

              if (esercizio.volume != null) ...[
                const Divider(height: Gap.md),
                Row(
                  children: [
                    Text(
                      'Volume',
                      style: tema.textTheme.labelMedium?.copyWith(
                        color: tema.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    if (esercizio.ripetizioni != null)
                      Padding(
                        padding: const EdgeInsets.only(right: Gap.sm),
                        child: Text(
                          '${esercizio.ripetizioni} rip',
                          style: tema.textTheme.labelMedium?.copyWith(
                            color: tema.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    Text(
                      '${kg(esercizio.volume!)} kg',
                      style: tema.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  /// 💡 Senza decimali quando non servono: «40 kg», non «40.0 kg».
  static String kg(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
}
