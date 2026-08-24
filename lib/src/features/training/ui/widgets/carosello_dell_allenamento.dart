/// Le tre card, ristrette a **un allenamento solo** — 3b-B.20.1, 25/08/2026.
///
/// ══ 📌 LA RICHIESTA ═══════════════════════════════════════════════════════
///
/// *«aggiungere sopra le tre cards a carosello come nella sezione storico, ma
/// limitate allo specifico allenamento»*.
///
/// ══ 🚨 «COME NELLA SEZIONE STORICO» VUOL DIRE *LE STESSE* ═════════════════
///
/// ⛔ La vestizione — la card, il riquadro bianco, la stella, i puntini — **non
/// è riscritta qui**: vive in `carosello_del_mese.dart`, dove era privata, e da
/// oggi è pubblica. Rifarla di qua avrebbe prodotto due caroselli che si
/// somigliano finché qualcuno non tocca uno dei due.
///
/// 💡 Quello che cambia non è il disegno: è **da dove vengono i dati**. Là un
/// mese, qui una `VoceStorico`.
///
/// ══ ⚠️ E LA TERZA CARD NON È LA STESSA, DI PROPOSITO ══════════════════════
///
/// 🚨 Su un allenamento solo, *«il numero di sessioni del mese»* dice sempre
/// **1**, e il grafico degli ultimi mesi non ha niente da confrontare. ⛔ Ridurre
/// a uno un contatore mensile non lo restringe: lo rende muto.
///
/// 💡 Al suo posto i numeri di **quella seduta**: durata, volume, distanza,
/// calorie, serie. E ognuno compare solo se c'è — un «0 km» su una seduta di
/// pesi è spazio riempito con niente, ed è la regola che
/// `allenamento_orologio_screen` seguiva già.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/catalogo_esercizi.dart';
import '../../data/storico_unificato.dart';
import '../../muscoli_allenati.dart';
import 'carosello_del_mese.dart';
import 'figura_del_corpo.dart';

class CaroselloDellAllenamento extends ConsumerStatefulWidget {
  const CaroselloDellAllenamento({required this.voce, super.key});

  final VoceStorico voce;

  @override
  ConsumerState<CaroselloDellAllenamento> createState() =>
      _CaroselloDellAllenamentoState();
}

class _CaroselloDellAllenamentoState
    extends ConsumerState<CaroselloDellAllenamento> {
  /// ⛔ Fuori da `build`, come nel carosello del mese: crearlo dentro lo
  /// rifarebbe a ogni ridisegno, e la pagina tornerebbe alla prima card ogni
  /// volta che cambia un numero.
  final _pagine = PageController();
  int _pagina = 0;

  @override
  void dispose() {
    _pagine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final voce = widget.voce;

    final catalogo =
        ref.watch(catalogoEserciziProvider).valueOrNull ??
        CatalogoEsercizi.vuoto;

    /*
     * ⚠️ **I muscoli passano anche dalla scheda associata** — B.9. Senza, la
     * pagina di un allenamento del polso sarebbe l'unico posto in cui la scheda
     * che gli hai attaccato non colora niente: la stessa domanda, due risposte
     * diverse a seconda di dove la guardi.
     */
    final intensita = intensitaDeiMuscoli(
      voci: [voce],
      catalogo: catalogo,
      pesiDelleSchede:
          ref.watch(muscoliDelleSchedeProvider).valueOrNull ?? const {},
    );

    final quando = DateFormat('d MMMM, HH:mm', 'it').format(voce.quando);

    /*
     * ⛔ **Senza muscoli non si mostrano due card mute.** Uno sport che la
     * tabella non conosce darebbe una figura tutta grigia e una stella
     * schiacciata al centro: due modi di dire «non hai allenato niente» a chi si
     * è appena allenato. 💡 I numeri invece ci sono sempre, e restano da soli.
     */
    final card = <Widget>[
      if (intensita.isNotEmpty) ...[
        CardDelCarosello(
          titolo: 'Cosa hai mosso',
          sottotitolo: quando,
          child: FiguraDelCorpo(intensita: intensita),
        ),
        CardDelCarosello(
          titolo: 'I gruppi muscolari',
          sottotitolo: quando,
          child: StellaInRiquadro(intensita: intensita),
        ),
      ],
      CardDelCarosello(
        titolo: 'L\'allenamento in numeri',
        sottotitolo: quando,
        child: _NumeriDellAllenamento(voce: voce),
      ),
    ];

    return Column(
      children: [
        SizedBox(
          height: altezzaCarosello,

          // 🚨 `PageView` e non `ListView`: le card sono larghe tutta la pagina
          // e devono **scattare** una per una, o si resta a cavallo di due.
          child: PageView(
            controller: _pagine,
            onPageChanged: (i) => setState(() => _pagina = i),
            children: card,
          ),
        ),
        if (card.length > 1)
          SizedBox(
            height: altezzaPuntiniDelCarosello,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < card.length; i++)
                  PuntinoDelCarosello(acceso: i == _pagina),
              ],
            ),
          ),
      ],
    );
  }
}

/// I numeri di **questo** allenamento.
class _NumeriDellAllenamento extends StatelessWidget {
  const _NumeriDellAllenamento({required this.voce});

  final VoceStorico voce;

  /// Il volume sollevato: ripetizioni × peso, su tutte le serie del gruppo.
  ///
  /// ⚠️ `null` quando non c'è niente da sommare — un allenamento del polso, o
  /// una seduta tutta a corpo libero. `0 kg` sarebbe una risposta sbagliata a
  /// una domanda che non si può fare.
  double? get _volume {
    var totale = 0.0;

    for (final s in voce.sedute) {
      for (final serie in s.sets) {
        totale += (serie.reps ?? 0) * (serie.weight ?? 0);
      }
    }

    return totale == 0 ? null : totale;
  }

  int get _serie {
    var totale = 0;

    for (final s in voce.sedute) {
      totale += s.sets.length;
    }

    return totale;
  }

  int get _passi {
    var totale = 0;

    for (final a in voce.dalPolso) {
      totale += a.passi ?? 0;
    }

    return totale;
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final metri = voce.distanzaMetri;
    final kcal = voce.kcal;
    final volume = _volume;

    final minuti = voce.durata.inMinutes;

    /*
     * ══ 🚨 «LE COSE CHE HANNO RILEVANZA» ═══════════════════════════════════
     *
     * ⛔ Ogni numero compare **solo se c'è**. Un «0 km» su una seduta di pesi o
     * un «— passi» su una nuotata non sono informazioni: sono spazio riempito,
     * e insegnano a non leggere il riquadro. È la regola che questa pagina
     * seguiva già prima che i numeri si spostassero qui dentro.
     *
     * 💡 Il ritmo si calcola solo quando ci sono dei metri: «5:30 /km» su un
     * allenamento di pesi sarebbe una divisione per zero travestita da dato.
     */
    final numeri = <(String, String)>[
      ('$minuti', 'minuti'),
      if (kcal != null && kcal > 0) ('$kcal', 'kcal'),
      if (volume != null) (_kg(volume), 'kg sollevati'),
      if (_serie > 0) ('$_serie', _serie == 1 ? 'serie' : 'serie fatte'),
      if (metri != null && metri > 0) (_distanza(metri), 'percorsi'),
      if (metri != null && metri >= 1000 && minuti > 0)
        (_ritmo(metri, minuti), 'al chilometro'),
      if (_passi > 0) ('$_passi', 'passi'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        /*
         * 🥇 **L'intenso si dice qui, non solo col bordo.** Nello storico l'oro
         * intorno alla card è un segnale che si coglie di sfuggita; chi apre
         * l'allenamento vuole leggerlo scritto.
         */
        if (voce.intenso)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.local_fire_department_rounded,
                  size: 18,
                  color: oroDellIntenso,
                ),
                const SizedBox(width: 4),
                Text(
                  'Allenamento intenso',
                  style: tema.textTheme.labelLarge?.copyWith(
                    color: oroDellIntenso,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

        Expanded(
          child: RiquadroBianco(
            child: Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                runAlignment: WrapAlignment.center,
                spacing: Gap.lg,
                runSpacing: Gap.md,
                children: [
                  for (final (valore, etichetta) in numeri)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          valore,
                          style: tema.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: tema.colorScheme.primary,
                          ),
                        ),
                        Text(etichetta, style: tema.textTheme.bodySmall),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  static String _kg(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  /// 💡 Sotto il chilometro si scrivono i metri, come ovunque nell'app.
  static String _distanza(int metri) => metri < 1000
      ? '$metri m'
      : '${(metri / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';

  /// Minuti e secondi per chilometro.
  static String _ritmo(int metri, int minuti) {
    final secondiPerKm = (minuti * 60) / (metri / 1000);
    final m = secondiPerKm ~/ 60;
    final sec = (secondiPerKm % 60).round();

    return '$m:${sec.toString().padLeft(2, '0')}';
  }
}
