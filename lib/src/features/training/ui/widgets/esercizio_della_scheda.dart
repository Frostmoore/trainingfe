/// Un esercizio come lo prescrive la scheda — 3b-D.18, 25/08/2026.
///
/// ══ 📌 LA RICHIESTA ═══════════════════════════════════════════════════════
///
/// *«nella pagina di mezzo, in ogni esercizio deve essere mostrata la foto (se
/// c'è) e tutti i dettagli di ogni serie, non solo rec. 60s o 11.0kg come
/// adesso»*.
///
/// ══ 🚨 IL DATO C'ERA GIA' E NON LO MOSTRAVA NESSUNO ═══════════════════════
///
/// ⛔ La riga diceva `rec. 60s · 11.0 kg`, cioè **il riassunto del formato
/// vecchio** — un recupero e un peso soli, uguali per tutte le serie. Le righe
/// vere (`PlanExercise.serie`) c'erano da 3b-D.1 e non le leggeva nessuno.
///
/// 🚨 **È il difetto peggiore di una funzione nuova**: il dato si scrive, si
/// salva, entra nel backup — e a schermo continua a comparire quello di prima.
/// Chi guarda conclude che la funzione non c'è.
///
/// ⚠️ E `11.0 kg` non era solo brutto: **uno zero dietro la virgola sembra una
/// precisione**, dice che qualcuno ha misurato il decimo di chilo.
library;

import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/media/archivio_foto.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/foto_locale.dart';
import '../../../../core/ui/miniatura.dart';
import '../../data/serie_prevista.dart';
import '../../training_controller.dart';

class EsercizioDellaScheda extends StatelessWidget {
  const EsercizioDellaScheda({required this.esercizio, super.key});

  static const _lato = 64.0;

  final PlanExercise esercizio;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: Gap.sm),
      child: Padding(
        padding: const EdgeInsets.all(Gap.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Foto(esercizio: esercizio),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    esercizio.name,
                    style: tema.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: Gap.xs),

                  /*
                   * ⚠️ **Una riga per serie**, con il suo numero davanti: e' il
                   * modo in cui una scheda si legge in palestra — «la terza a
                   * cinquanta» — e il motivo per cui le serie sono diventate
                   * righe.
                   */
                  for (var i = 0; i < esercizio.serie.length; i++)
                    _RigaLetta(
                      numero: i + 1,
                      serie: esercizio.serie[i],
                      carico: esercizio.carico,
                    ),

                  if (esercizio.notes case final note?
                      when note.trim().isNotEmpty) ...[
                    const SizedBox(height: Gap.xs),
                    Text(
                      note,
                      style: tema.textTheme.bodySmall?.copyWith(
                        color: tema.colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// La foto propria se c'è, altrimenti l'illustrazione del catalogo.
///
/// 💡 **Quella propria vince**: la foto della macchina di *quella* palestra,
/// con il sedile all'altezza giusta, dice più di un'illustrazione generica.
class _Foto extends StatelessWidget {
  const _Foto({required this.esercizio});

  final PlanExercise esercizio;

  @override
  Widget build(BuildContext context) {
    final relativo = esercizio.immagine;

    if (relativo == null || relativo.isEmpty) {
      return Miniatura(
        url: esercizio.imageUrl,
        etichetta: esercizio.name,
        lato: EsercizioDellaScheda._lato,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(Gap.sm),
      child: FutureBuilder<File>(
        future: const ArchivioFoto().fileDi(relativo),
        builder: (context, esito) {
          final file = esito.data;

          /*
           * ⚠️ Mentre il percorso si risolve si mostra **la miniatura del
           * catalogo**, non un giro: e' un'attesa di millisecondi, e un
           * indicatore che lampeggia a ogni ricostruzione sembra un difetto.
           */
          if (file == null) {
            return Miniatura(
              url: esercizio.imageUrl,
              etichetta: esercizio.name,
              lato: EsercizioDellaScheda._lato,
            );
          }

          return FotoLocale(
            file: file,
            width: EsercizioDellaScheda._lato,
            height: EsercizioDellaScheda._lato,
          );
        },
      ),
    );
  }
}

class _RigaLetta extends StatelessWidget {
  const _RigaLetta({
    required this.numero,
    required this.serie,
    required this.carico,
  });

  final int numero;
  final SeriePrevista serie;
  final CaricoDellEsercizio carico;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            child: Text(
              '$numero',
              style: tema.textTheme.labelSmall?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              _testo(),
              style: tema.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  /// ⚠️ **Solo quello che c'è.** Un «— kg» su un esercizio a corpo libero o un
  /// «0 rip» su una serie a cedimento sono spazio riempito con niente, e
  /// insegnano a non leggere la riga.
  String _testo() {
    final pezzi = <String>[];

    final secondi = serie.isoSec;
    final ripetizioni = serie.ripetizioni;

    if (carico == CaricoDellEsercizio.iso && secondi != null) {
      pezzi.add('$secondi s');
    } else if (ripetizioni != null) {
      pezzi.add('$ripetizioni rip');
    } else {
      // 💡 Una serie senza ripetizioni dichiarate **esiste**: e' quella che si
      // fa fino a non poterne piu'. Lasciare la riga vuota la farebbe sembrare
      // un errore di compilazione.
      pezzi.add('a cedimento');
    }

    final peso = serie.peso;

    if (carico == CaricoDellEsercizio.peso && peso != null) {
      pezzi.add('${numeroPulito(peso)} kg');
    }

    if (carico == CaricoDellEsercizio.niente) pezzi.add('corpo libero');

    final recupero = serie.recuperoSec;

    if (recupero != null) pezzi.add('rec. ${recupero}s');

    return pezzi.join(' · ');
  }
}
