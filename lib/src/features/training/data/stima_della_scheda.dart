/// Quanto dura e quanto costa una scheda, prima di farla — 3b-D.16, 25/08/2026.
///
/// ══ 📌 LA RICHIESTA ═══════════════════════════════════════════════════════
///
/// *«Mettici le cards con l'uomo e il diagramma a stella, e una stima del tempo
/// di esecuzione e delle calorie bruciate»*.
///
/// ══ 🚨 E' UNA STIMA, E DEVE SEMBRARLO ═════════════════════════════════════
///
/// ⛔ Nessuno di questi numeri è misurato: il tempo di una serie dipende da come
/// la si esegue, e le calorie da chi la esegue. 💡 Quello che si può dire
/// onestamente è **l'ordine di grandezza**: se questa scheda è da mezz'ora o da
/// un'ora e mezza, e se costa 200 kcal o 600.
///
/// ⚠️ Per questo i numeri si mostrano **arrotondati** e con scritto «circa»: una
/// precisione al minuto direbbe una cosa che non si sa.
///
/// 🚨 **Le convenzioni sotto sono prudenti**, come i MET: sovrastimare le
/// calorie porta chi legge a mangiare di più credendosi in deficit, e
/// sottostimare il tempo porta a cominciare una scheda da un'ora quando ne resta
/// mezza.
library;

import '../training_controller.dart';
import 'calorie_allenamento.dart';
import 'catalogo_esercizi.dart';
import 'serie_prevista.dart';

/// Quanto dura una ripetizione, in secondi.
///
/// 💡 Tre secondi: una ripetizione controllata — un tempo giù, uno su, uno di
/// transizione. ⚠️ Chi le fa esplosive ne impiega meno, chi le fa lente di più:
/// è una media, e per questo il risultato si arrotonda ai cinque minuti.
const double secondiPerRipetizione = 3;

/// Il recupero quando la scheda non lo dice.
const int recuperoDiRipiego = 60;

/// Il tempo fra un esercizio e l'altro: prendere la postazione, sistemarla.
///
/// ⚠️ **Non è tempo perso**: in una scheda da dieci esercizi sono dieci minuti,
/// e ignorarli darebbe una durata che nessuno riesce a rispettare.
const int secondiPerCambioEsercizio = 60;

/// Cosa si può dire di una scheda prima di eseguirla.
class StimaDellaScheda {
  const StimaDellaScheda({
    required this.durata,
    required this.kcal,
    required this.serie,
    required this.esercizi,
  });

  final Duration durata;

  /// ⚠️ `null` quando la scheda non ha **niente** da cui stimare — nessuna
  /// serie, nessun esercizio. ⛔ Uno zero direbbe «non brucia niente», che è
  /// un'altra cosa.
  final int? kcal;

  final int serie;
  final int esercizi;

  /// I minuti arrotondati ai **cinque**.
  ///
  /// 🚨 «Circa 45 minuti» è una stima, «47 minuti» è una bugia con l'aria di
  /// una misura.
  int get minutiTondi {
    final minuti = durata.inMinutes;

    if (minuti <= 0) return 0;

    return ((minuti / 5).round() * 5).clamp(5, 100000);
  }
}

/// La stima di una scheda.
///
/// 💡 **Pura**: prende quello che le serve e non guarda nessun provider, così si
/// prova con un test invece che aprendo l'app.
StimaDellaScheda stimaDellaScheda({
  required WorkoutPlan scheda,
  required CatalogoEsercizi catalogo,
  required double kg,
}) {
  var secondi = 0.0;
  var serie = 0;
  var esercizi = 0;

  final met = <double?>[];

  for (final riga in scheda.exercises) {
    final righeDelleSerie = riga.serie;

    if (righeDelleSerie.isEmpty) continue;

    esercizi++;

    // ⚠️ Il cambio postazione si conta **fra** gli esercizi, non prima del
    // primo: chi comincia è già dov'è.
    if (esercizi > 1) secondi += secondiPerCambioEsercizio;

    for (var i = 0; i < righeDelleSerie.length; i++) {
      final s = righeDelleSerie[i];

      serie++;

      secondi += _lavoroDi(s);

      /*
       * ⛔ **Il recupero dopo l'ultima serie non si conta.** Finita l'ultima
       * ripetizione dell'ultimo esercizio l'allenamento e' finito: contarlo
       * aggiungerebbe un minuto e mezzo di niente a ogni scheda.
       */
      final ultimaDellUltimo =
          i == righeDelleSerie.length - 1 && riga == scheda.exercises.last;

      if (!ultimaDellUltimo) {
        secondi += (s.recuperoSec ?? recuperoDiRipiego).toDouble();
      }
    }

    met.add(catalogo.perId(riga.exerciseId)?.met ?? catalogo.perNome(riga.name)?.met);
  }

  final durata = Duration(seconds: secondi.round());

  return StimaDellaScheda(
    durata: durata,
    kcal: serie == 0
        ? null
        : CalorieAllenamento.formula(
            durata: durata,
            kg: kg,
            metMedio: CalorieAllenamento.metMedio(met),
          ),
    serie: serie,
    esercizi: esercizi,
  );
}

/// Quanto dura **una serie**.
///
/// 💡 L'isometria dice i secondi da sola; le ripetizioni si moltiplicano.
/// ⚠️ Una serie senza ripetizioni dichiarate — «a cedimento» — vale comunque
/// qualcosa: **trenta secondi**, che è una serie corta. ⛔ Contarla zero
/// direbbe che quella serie non esiste.
double _lavoroDi(SeriePrevista s) {
  final iso = s.isoSec;

  if (iso != null && iso > 0) return iso.toDouble();

  final ripetizioni = s.ripetizioni;

  if (ripetizioni == null || ripetizioni <= 0) return 30;

  return ripetizioni * secondiPerRipetizione;
}
