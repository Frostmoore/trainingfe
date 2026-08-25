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
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/media/archivio_foto.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/foto_locale.dart';
import '../../../../core/ui/miniatura.dart';
import '../../data/catalogo_esercizi.dart';
import '../../data/serie_prevista.dart';
import '../../training_controller.dart';

class EsercizioDellaScheda extends ConsumerWidget {
  const EsercizioDellaScheda({required this.esercizio, super.key});

  static const _lato = 64.0;

  final PlanExercise esercizio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);

    /*
     * ══ 💡 L'ILLUSTRAZIONE SI CHIEDE AL CATALOGO — 3b-E.12 ═══════════════════
     *
     * ⛔ Si leggeva da `esercizio.imageUrl`, cioe' da `exercise.image_url`: un
     * campo che manda **il server** e che `esercizioInJson` non riscrive. 🚨 Alla
     * prima scheda salvata dall'app — e da 3b-E succede a ogni allenamento —
     * l'illustrazione spariva, senza nessun errore.
     *
     * 💡 L'id dell'esercizio ce l'abbiamo: si ricava. ⚠️ Copiarsi l'URL dentro la
     * scheda sarebbe una seconda copia che invecchia, e che resterebbe attaccata
     * a un esercizio anche dopo averlo rinominato.
     */
    final dalCatalogo = ref
        .watch(catalogoEserciziProvider)
        .valueOrNull
        ?.perId(esercizio.exerciseId);

    return Card(
      margin: const EdgeInsets.only(bottom: Gap.sm),
      child: Padding(
        padding: const EdgeInsets.all(Gap.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FotoDellEsercizio(
              immagine: esercizio.immagine,
              url: esercizio.imageUrl ?? dalCatalogo?.immagine,
              etichetta: esercizio.name,
            ),
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
///
/// ⚠️ **Pubblica e senza `PlanExercise` da 3b-E.10**: la usano la pagina della
/// scheda e la card dell'allenamento a riposo. 🚨 Legandola a un modello, la
/// seconda schermata avrebbe dovuto costruirsene uno finto — o farsi la sua
/// copia della regola «la propria vince».
class FotoDellEsercizio extends StatelessWidget {
  const FotoDellEsercizio({
    required this.immagine,
    required this.url,
    required this.etichetta,
    this.lato = EsercizioDellaScheda._lato,
    super.key,
  });

  /// Il percorso **relativo** della foto propria (`foto/esercizi/…`).
  final String? immagine;

  /// L'illustrazione del catalogo, quando c'è.
  final String? url;

  final String etichetta;
  final double lato;

  @override
  Widget build(BuildContext context) {
    final relativo = immagine;

    if (relativo == null || relativo.isEmpty) {
      return Miniatura(url: url, etichetta: etichetta, lato: lato);
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
            return Miniatura(url: url, etichetta: etichetta, lato: lato);
          }

          return FotoLocale(file: file, width: lato, height: lato);
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
              descrizioneDellaSerie(serie, carico),
              style: tema.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
