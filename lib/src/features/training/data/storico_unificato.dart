import '../../../core/storage/archivio_salute.dart';
import 'session_models.dart';

/// Una riga dello storico, da qualunque parte venga — FASE 1.10.
///
/// ── 🚨 Perché un tipo solo per due origini diverse ────────────────────────
///
/// Perché chi guarda lo storico si chiede *«quando mi sono allenato»*, non
/// *«quali allenamenti ha registrato il player e quali l'orologio»*. Due elenchi
/// separati costringerebbero a fare a mente la fusione che dovremmo fare noi —
/// e a farla ogni volta.
///
/// ⚠️ È la stessa ragione per cui la corsa e la seduta di pesi stanno nella
/// stessa lista: il committente l'ha detto così — *«a sto punto facciamola
/// bene […] tanto vale metterci tutti gli allenamenti»*.
sealed class VoceStorico {
  const VoceStorico();

  /// Quando è cominciato. È la chiave con cui si ordina tutto.
  DateTime get quando;
}

/// Una seduta registrata **nell'app**, eventualmente arricchita da quello che
/// l'orologio ha visto nello stesso momento.
class VoceSeduta extends VoceStorico {
  const VoceSeduta({required this.sessione, this.orologio});

  final WorkoutSession sessione;

  /// L'allenamento dell'orologio che copre la stessa ora, se c'è.
  ///
  /// 💡 Non è un doppione da nascondere: è la **stessa cosa vista da due
  /// strumenti**. Il player sa quali esercizi hai fatto, l'orologio sa quanto ti
  /// è costato. Tenerli insieme dà una riga che nessuno dei due saprebbe
  /// scrivere da solo.
  final AllenamentoDaOrologio? orologio;

  @override
  DateTime get quando => sessione.startedAt;
}

/// Un allenamento che esiste **solo** perché l'orologio l'ha registrato.
///
/// 💡 È il caso che questa fase esiste per coprire: *«molta gente probabilmente
/// o non userà l'app quando si allena o non userà l'orologio»*. Una corsa fatta
/// senza toccare il telefono è comunque un allenamento, e prima di oggi non
/// compariva da nessuna parte.
class VoceOrologio extends VoceStorico {
  const VoceOrologio({required this.allenamento, this.scheda});

  final AllenamentoDaOrologio allenamento;

  /// La scheda che questa persona ha detto di aver fatto, se l'ha assegnata.
  final SchedaRicevuta? scheda;

  @override
  DateTime get quando => allenamento.iniziatoIl;
}

/// Come si mettono insieme le due origini.
///
/// ── 🚨 Il problema che risolve: lo stesso allenamento contato due volte ───
///
/// Chi si allena in palestra **con l'app aperta e l'orologio al polso** produce
/// due registrazioni della stessa ora. Senza una regola, lo storico direbbe
/// «due sedute» dove ce n'è stata una, e la settimana ne conterebbe il doppio.
abstract final class StoricoUnificato {
  /// Quanto devono sovrapporsi due registrazioni per essere la stessa cosa.
  ///
  /// ── ⚠️ Perché una percentuale e non un tempo fisso ────────────────────────
  ///
  /// Perché la durata cambia di un ordine di grandezza: dieci minuti di
  /// sovrapposizione sono tantissimo per una corsa di venti e pochissimo per una
  /// seduta di due ore. Una soglia fissa sbaglierebbe da una parte o dall'altra.
  ///
  /// 💡 **Metà della più corta**: se l'orologio ha visto almeno metà di quello
  /// che ha visto il player (o viceversa), stanno parlando dello stesso
  /// allenamento. Sotto quella soglia sono due cose che si sono solo sfiorate —
  /// tipico di chi finisce i pesi e parte subito con la corsa.
  static const quantoSiDevonoSovrapporre = 0.5;

  /// Fonde le sedute dell'app e gli allenamenti dell'orologio in un elenco solo,
  /// dal più recente.
  ///
  /// ── 🚨 Le regole, in ordine ───────────────────────────────────────────────
  ///
  /// 1. Ogni seduta dell'app diventa una riga. **Sempre**: è quella che contiene
  ///    gli esercizi, ed è quella che la persona ha creato di sua mano.
  /// 2. Un allenamento dell'orologio che si sovrappone a una seduta le si
  ///    **attacca** invece di fare riga a sé.
  /// 3. Quello che avanza diventa una riga sua.
  /// 4. Quelli marcati `nascosto` non compaiono.
  ///
  /// ⚠️ **Un allenamento dell'orologio si attacca a una sola seduta**, la prima
  /// che incontra in ordine di tempo. Senza questo vincolo una seduta lunga e
  /// una corta sovrapposte se lo prenderebbero entrambe, e la stessa ora
  /// comparirebbe due volte — cioè esattamente il difetto che stiamo chiudendo.
  static List<VoceStorico> fondi({
    required List<WorkoutSession> sessioni,
    required List<AllenamentoDaOrologio> dallOrologio,
    Map<int, SchedaRicevuta> schede = const {},
  }) {
    final daPiazzare = dallOrologio.where((a) => !a.nascosto).toList()
      ..sort((a, b) => a.iniziatoIl.compareTo(b.iniziatoIl));

    final usati = <int>{};
    final voci = <VoceStorico>[];

    for (final sessione in sessioni) {
      AllenamentoDaOrologio? gemello;

      for (final candidato in daPiazzare) {
        if (usati.contains(candidato.id)) continue;
        if (!_sonoLoStesso(sessione, candidato)) continue;

        gemello = candidato;
        usati.add(candidato.id);
        break;
      }

      voci.add(VoceSeduta(sessione: sessione, orologio: gemello));
    }

    for (final avanzato in daPiazzare) {
      if (usati.contains(avanzato.id)) continue;

      voci.add(VoceOrologio(
        allenamento: avanzato,
        scheda: avanzato.schedaAssegnata == null
            ? null
            : schede[avanzato.schedaAssegnata],
      ));
    }

    voci.sort((a, b) => b.quando.compareTo(a.quando));

    return voci;
  }

  /// Se una seduta dell'app e un allenamento dell'orologio sono la stessa cosa.
  ///
  /// ⚠️ **Una seduta ancora aperta non si accoppia mai.** `isOpen` vuol dire che
  /// non è finita: la sua durata è «finora», e cresce a ogni secondo. Accoppiarla
  /// vorrebbe dire prendere una decisione che il minuto dopo può essere diversa.
  static bool _sonoLoStesso(WorkoutSession sessione, AllenamentoDaOrologio orologio) {
    if (sessione.isOpen) return false;

    final inizioA = sessione.startedAt;
    final fineA = sessione.endedAt ??
        (sessione.durationMinutes == null
            ? null
            : inizioA.add(Duration(minutes: sessione.durationMinutes!)));

    /*
     * ⚠️ Una seduta senza fine **e** senza durata non ha un intervallo, e
     * inventarglielo sarebbe peggio che lasciarla sola: si finirebbe ad
     * attaccarle l'allenamento sbagliato.
     */
    if (fineA == null || !fineA.isAfter(inizioA)) return false;

    final inizioB = orologio.iniziatoIl;
    final fineB = orologio.finitoIl;

    final inizioComune = inizioA.isAfter(inizioB) ? inizioA : inizioB;
    final fineComune = fineA.isBefore(fineB) ? fineA : fineB;

    if (!fineComune.isAfter(inizioComune)) return false;

    final comune = fineComune.difference(inizioComune).inSeconds;
    final piuCorta = [
      fineA.difference(inizioA).inSeconds,
      fineB.difference(inizioB).inSeconds,
    ].reduce((a, b) => a < b ? a : b);

    if (piuCorta <= 0) return false;

    return comune / piuCorta >= quantoSiDevonoSovrapporre;
  }
}
