/// «Questa scheda ha quattro giorni, e diventerà quattro schede» — K2-bis.
///
/// ══ 📌 LA DECISIONE, ALLA LETTERA ═════════════════════════════════════════
///
/// Il committente, il 03/09/2026: *«l'utente non abbonato non può avere schede
/// multiday, quindi alla fine del controllo, il sistema deve generare x schede
/// per quanti giorni ci sono in quella originale»*. E sul conflitto con il
/// limite delle tre schede: *«si avverte prima e via»*.
///
/// ══ 🚨 PERCHE' PRIMA E NON DOPO ═══════════════════════════════════════════
///
/// La divisione avviene al salvataggio, cioè **dopo** che qualcuno ha
/// confrontato quaranta righe con l'originale. ⛔ Annunciarla lì sarebbe il
/// momento peggiore possibile: i gettoni sono spesi, il lavoro è fatto, e la
/// sorpresa arriva quando non si può più decidere niente.
///
/// ⚠️ **E si dice anche del limite**, quando serve: chi non è abbonato ha tre
/// schede, e una scheda da quattro giorni ne genera quattro. 🚨 Si salvano
/// tutte lo stesso — rifiutare dopo aver incassato cinquanta gettoni sarebbe
/// l'unico modo di sprecarli davvero — ma quelle oltre la terza risultano
/// bloccate, e chi importa deve saperlo **adesso**.
library;

import 'package:flutter/material.dart';

class AvvisoDeiGiorni {
  const AvvisoDeiGiorni._();

  /// 🚨 Il limite di chi non è abbonato (3b-D). ⚠️ Scritto qui e non dedotto:
  /// serve solo a decidere se dire una frase in più, e una lettura sbagliata
  /// darebbe un avviso che parla di un limite che non esiste.
  static const limite = 3;

  /// Torna `true` se si va avanti.
  ///
  /// ⚠️ `?? false`: chi chiude con il gesto di sistema non ha detto di sì, e
  /// proseguire in quel caso vorrebbe dire far comparire quattro schede a
  /// qualcuno che stava tornando indietro.
  static Future<bool> mostra(
    BuildContext context, {
    required int giorni,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Questa scheda ha $giorni giorni'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Le schede a più giorni sono per gli abbonati. Quando avrai '
                'finito di controllarla, la salverò come $giorni schede '
                'separate, una per giorno: sono le stesse cose, solo divise.',
              ),
              if (giorni > limite) ...[
                const SizedBox(height: 12),
                Text(
                  'Senza abbonamento puoi tenerne $limite: le altre '
                  '${giorni - limite} le trovi nell\'elenco, ma restano '
                  'bloccate finché non ne cancelli qualcuna o ti abboni.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Lascio stare'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Va bene, controllo'),
            ),
          ],
        ),
      ) ??
      false;
}
