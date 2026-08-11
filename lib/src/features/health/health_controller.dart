import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/storage/archivio_salute.dart';
import 'ponte_salute.dart';

/// L'archivio locale, uno solo per tutta l'app.
///
/// ⚠️ **Non `autoDispose`**: un database che si chiude e riapre a ogni
/// schermata paga l'apertura del file ogni volta, e su un telefono lento si
/// vede. Vive quanto l'app.
final archivioSaluteProvider = Provider<ArchivioSalute>((ref) {
  final archivio = ArchivioSalute();

  ref.onDispose(archivio.close);

  return archivio;
});

final ponteSaluteProvider = Provider<PonteSalute>(
  (ref) => PonteSalute(ref.watch(archivioSaluteProvider)),
);

/// Lo stato del collegamento con Health Connect.
class StatoSalute {
  const StatoSalute({
    this.collegato = false,
    this.inCorso = false,
    this.errore,
    this.ultimaSincronizzazione,
  });

  final bool collegato;
  final bool inCorso;
  final String? errore;
  final String? ultimaSincronizzazione;

  StatoSalute copyWith({
    bool? collegato,
    bool? inCorso,
    String? errore,
    String? ultimaSincronizzazione,
    bool azzeraErrore = false,
  }) => StatoSalute(
    collegato: collegato ?? this.collegato,
    inCorso: inCorso ?? this.inCorso,
    errore: azzeraErrore ? null : (errore ?? this.errore),
    ultimaSincronizzazione: ultimaSincronizzazione ?? this.ultimaSincronizzazione,
  );
}

/// Chi governa il collegamento e la sincronizzazione — S3.4.
class HealthController extends StateNotifier<StatoSalute> {
  HealthController(this._ponte, this._archivio) : super(const StatoSalute());

  final PonteSalute _ponte;
  final ArchivioSalute _archivio;

  /// Chiede il permesso e, se c'è, sincronizza subito.
  ///
  /// ⚠️ **Il permesso e la prima lettura vanno insieme.** Chiedere il permesso
  /// e poi lasciare la schermata vuota fino al giorno dopo fa sembrare che non
  /// sia successo niente, e la persona lo revoca.
  Future<void> collega() async {
    state = state.copyWith(inCorso: true, azzeraErrore: true);

    final concesso = await _ponte.chiediPermessi();

    if (!concesso) {
      state = state.copyWith(
        inCorso: false,
        collegato: false,
        errore: 'Non è stato possibile collegare Health Connect. '
            'Se hai già rifiutato in passato, il permesso va riattivato dalle '
            'impostazioni di sistema.',
      );

      return;
    }

    /*
     * 🚨 30 giorni, non 7.
     *
     * Health Connect di serie lascia rileggere circa un mese indietro, e oltre
     * serve un permesso a parte che Google concede con parsimonia. Alla PRIMA
     * sincronizzazione si prende tutto quello che si puo': da li' in poi la
     * memoria lunga e' l'archivio locale, che accumula.
     *
     * ⚠️ La media di riferimento a sette giorni esiste comunque solo dopo
     * sette giorni di dati. Non e' un difetto, ma va detto — o sembrera' che
     * la funzione non parta.
     */
    final quanti = await _ponte.sincronizza(giorniIndietro: 30);

    state = state.copyWith(
      inCorso: false,
      collegato: true,
      ultimaSincronizzazione: DateFormat('d MMM, HH:mm', 'it').format(DateTime.now()),
      errore: quanti == 0
          ? 'Collegato, ma non è arrivato ancora nessun dato. '
              'Succede se il tuo orologio non ha ancora sincronizzato con il telefono.'
          : null,
      azzeraErrore: quanti > 0,
    );
  }

  /// Cancella tutto quello che c'è sul telefono.
  ///
  /// 🚨 Con i dati in locale il server non può cancellarli per conto di
  /// nessuno: **questo è l'unico modo che una persona ha di liberarsene** senza
  /// disinstallare l'app.
  Future<void> cancellaTutto() async {
    state = state.copyWith(inCorso: true, azzeraErrore: true);

    await _archivio.svuota();

    state = state.copyWith(inCorso: false, ultimaSincronizzazione: null);
  }
}

final healthControllerProvider =
    StateNotifierProvider<HealthController, StatoSalute>(
  (ref) => HealthController(
    ref.watch(ponteSaluteProvider),
    ref.watch(archivioSaluteProvider),
  ),
);
