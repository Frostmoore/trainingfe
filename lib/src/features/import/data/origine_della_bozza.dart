/// Da dove viene una bozza, e dove va a finire — Parte K, K3.
///
/// ══ 🚨 PERCHE' ESISTE ═════════════════════════════════════════════════════
///
/// 📌 Il committente, il 03/09/2026: *«Mi serve che l'app mostri il builder di
/// schede già compilato o un diario alimentare già compilato con un tasto in
/// basso a sx per vedere il documento originale così l'utente può correggere
/// tutto a mano prima di salvarlo»*.
///
/// ⛔ **Non basta passare la bozza al builder.** I due compositori sono nati per
/// il **trainer** e salvano sul server (`POST /workout-plans`,
/// `/nutrition-plans`). 🚨 Una scheda importata da un iscritto deve finire
/// nell'archivio locale: salvarla di là vorrebbe dire un piano alimentare con un
/// nome sopra sui nostri sistemi, cioè l'opposto esatto di D9-bis.
///
/// 💡 Quindi ai builder non basta imparare *cosa mostrare*: devono imparare
/// **dove salvare**. È questa classe a dirglielo.
///
/// ══ ⚠️ E' L'UNICO INTERRUTTORE DELLA MODALITA' REVISIONE ═════════════════
///
/// `origine != null` accende tutto: la barra del documento, il conteggio delle
/// righe, i dubbi in cima, il pulsante che dice *«Ho controllato tutto»*.
///
/// ⛔ Un secondo campo `bool revisione` sarebbe una **seconda verità sullo
/// stesso fatto**: si possono disallineare, e il giorno che si disallineano il
/// builder mostra la barra del documento senza avere il documento.
library;

import 'package:flutter/foundation.dart';

/// Che cosa si è caricato.
///
/// 💡 Cambia **il testo dell'avvertenza**, non il comportamento: la revisione è
/// obbligatoria comunque, e lo era già per i PDF.
enum TipoDiDocumento {
  pdf,

  /// 📌 *«Per risultati ottimali, si consiglia di usare un documento in PDF.
  /// L'analisi delle immagini è generalmente meno accurata di quella dei PDF.
  /// Potrai comunque correggere a mano ogni riga.»*
  immagini;

  static TipoDiDocumento da(String? valore) =>
      valore == 'immagini' ? TipoDiDocumento.immagini : TipoDiDocumento.pdf;
}

@immutable
class OrigineDellaBozza {
  const OrigineDellaBozza({
    required this.importazioneId,
    required this.documenti,
    required this.tipo,
    required this.righeDaControllare,
    this.dubbi = const [],
  });

  /// L'importazione sul server: si chiude dopo il salvataggio.
  ///
  /// 💡 Chiuderla serve tanto a confermare quanto a scartare — il risultato di
  /// là è lo stesso, perché la bozza confermata **non resta sul server**.
  final int importazioneId;

  /// I percorsi **locali** dei documenti originali, nell'ordine di lettura.
  ///
  /// ══ 🚨 NON SI SCARICANO DA NESSUNA PARTE ═════════════════════════════════
  ///
  /// Sono le copie che **il telefono ha fatto quando l'utente ha scelto i
  /// file** (K1-bis). ⛔ Sul server, di quei documenti, non resta niente appena
  /// il job ha finito: la rotta che li riconsegnava non esiste più.
  ///
  /// ⚠️ E vivono in `Documents`, non nella cache: l'originale deve poter essere
  /// riaperto anche fra sei mesi, accanto al piano che si sta seguendo.
  final List<String> documenti;

  final TipoDiDocumento tipo;

  /// Quante righe ci sono da confrontare, detto **prima**.
  ///
  /// 💡 «34 righe da controllare» è un'informazione che cambia come qualcuno
  /// affronta la revisione: chi crede che sia questione di due secondi la fa
  /// male.
  final int righeDaControllare;

  /// I dubbi che il modello ha dichiarato.
  ///
  /// 🚨 Vanno **in cima e non sepolti**: sono la parte più utile della risposta,
  /// perché portano chi controlla dritto sulle righe che contano.
  final List<String> dubbi;

  bool get daFotografia => tipo == TipoDiDocumento.immagini;

  /// L'avvertenza da mostrare in revisione.
  ///
  /// ⚠️ **Solo per le fotografie.** Su un PDF sarebbe rumore: la revisione è
  /// obbligatoria comunque, e un avviso che compare sempre si smette di leggere.
  String? get avvertenza => daFotografia
      ? 'Questa bozza viene da una fotografia, e l\'analisi delle immagini è '
            'generalmente meno accurata di quella dei PDF. Controlla ogni riga '
            'con l\'originale.'
      : null;
}
