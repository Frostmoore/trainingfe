/// La figura e la stella, sotto una scheda — 3b-D.6, 25/08/2026.
///
/// 📌 *«In fondo alla scheda, ci deve essere la card con l'uomo e i muscoli
/// allenati e il grafico a stella (le stesse dello storico e dell'esercizio
/// individuale)»* e poi, vedendola: *«La card sotto con l'uomo dovrebbe essere
/// un carosello come nelle altre schermate, sennò non si capisce un cazzo»*.
///
/// ══ 🚨 «LE STESSE» VOLEVA DIRE ANCHE LA FORMA, NON SOLO I WIDGET ══════════
///
/// ⛔ La prima stesura metteva figura e stella **affiancate** dentro una card
/// sola: gli stessi widget dello storico, ma stretti a metà larghezza ciascuno.
/// A 328 px la figura diventa un francobollo e la stella un ragnetto con le
/// etichette accavallate — **due grafici illeggibili invece di uno leggibile**.
///
/// 💡 Nello storico sono un **carosello**: una card per volta, a tutta
/// larghezza, con i puntini sotto. Ed è quello che «le stesse dello storico»
/// voleva dire fin dall'inizio — l'ho letto come «gli stessi widget» invece che
/// come «la stessa cosa».
///
/// ⚠️ **La differenza col carosello dello storico è cosa colora**: là
/// l'intensità viene da quello che hai *fatto*, qui da quello che hai
/// *scritto*. Stessa forma, tempo verbale diverso.
library;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/gruppo_muscolare.dart';
import '../../muscoli_allenati.dart';
import 'carosello_del_mese.dart';
import 'figura_del_corpo.dart';

class MuscoliInCard extends StatefulWidget {
  const MuscoliInCard({required this.intensita, super.key});

  final Map<GruppoMuscolare, double> intensita;

  @override
  State<MuscoliInCard> createState() => _MuscoliInCardState();
}

class _MuscoliInCardState extends State<MuscoliInCard> {
  final _pagine = PageController();
  int _pagina = 0;

  @override
  void dispose() {
    _pagine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final card = <Widget>[
      CardDelCarosello(
        titolo: 'Cosa allena questa scheda',
        sottotitolo: 'da quello che hai scritto',
        child: Column(
          children: [
            Expanded(
              // 📌 Nel quadrato bianco anche col tema scuro (3b-C.1): il PNG è
              // disegnato per un fondo chiaro, e su nero le linee spariscono.
              child: RiquadroBianco(
                sempreChiaro: true,
                child: FiguraDelCorpo(intensita: widget.intensita),
              ),
            ),
            const SizedBox(height: Gap.xs),
            const LegendaDeiMuscoli(),
          ],
        ),
      ),
      CardDelCarosello(
        titolo: 'I gruppi muscolari',
        sottotitolo: spiegazioneDeiMuscoli(widget.intensita),
        child: StellaInRiquadro(intensita: widget.intensita),
      ),
    ];

    return Column(
      children: [
        SizedBox(
          height: altezzaCarosello,

          // 🚨 `PageView` e non `ListView`: le card sono larghe tutta la pagina
          // e devono **scattare** una per una, o si resta a cavallo di due. È
          // la stessa scelta del carosello dello storico.
          child: PageView(
            controller: _pagine,
            onPageChanged: (i) => setState(() => _pagina = i),
            children: card,
          ),
        ),
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
