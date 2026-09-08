/// Una dormita intera: dal momento in cui ti sei addormentato a quando ti sei
/// svegliato.
class SessioneSonno {
  const SessioneSonno({
    required this.inizio,
    required this.fine,
    required this.eNotte,
  });

  final DateTime inizio;
  final DateTime fine;

  /// `true` se è **la dormita principale**, `false` se è una pennichella.
  final bool eNotte;

  Duration get durata => fine.difference(inizio);

  /// A quale giornata di riposo appartiene.
  ///
  /// ── 🚨 Due regole diverse, perché sono due cose diverse ──────────────────
  ///
  /// | | |
  /// |---|---|
  /// | **La notte** | il giorno in cui **ti svegli** |
  /// | **La pennichella** | il giorno in cui **comincia** |
  ///
  /// ⚠️ È qui che stava il difetto riferito il 18/08/2026: una pennica delle
  /// 18:09 di ieri veniva accreditata a **oggi**, e la giornata risultava
  /// sfasata di mezza giornata — *«è assurdo che mi prenda la pennica di ieri
  /// come parte del sonno di oggi»*.
  ///
  /// 💡 Con questa regola non può più succedere: una pennichella **non si
  /// sposta mai** di giorno, qualunque ora sia.
  DateTime get giornata {
    final quando = eNotte ? fine : inizio;

    return DateTime(quando.year, quando.month, quando.day);
  }
}

/// Da segmenti di fase a dormite intere — 18/08/2026.
///
/// ── 🚨 Perché serviva, e perché la regola vecchia non poteva funzionare ────
///
/// Quello che arriva da Health Connect **non sono dormite: sono segmenti di
/// fase** — venti minuti di REM, quaranta di profondo, dieci di sveglio. Una
/// notte sola sono decine di righe.
///
/// La regola precedente decideva la giornata guardando **l'ora d'inizio del
/// singolo segmento**: dopo le 18 apparteneva al giorno dopo, prima al giorno
/// stesso. ⚠️ Con un segmento di venti minuti in mano non si può sapere se fa
/// parte di una notte o di un pisolino — e infatti una pennichella cominciata
/// alle **18:09** finiva accreditata all'indomani.
///
/// 💡 **La domanda giusta si può fare solo alla dormita intera.** Quindi prima
/// si ricompongono i segmenti in sessioni, poi si decide.
class SessioniDiSonno {
  /// Il buco oltre il quale due segmenti sono **due dormite diverse**.
  ///
  /// ⚠️ Novanta minuti sono larghi apposta: chi si sveglia alle tre e si
  /// rigira per un'ora sta ancora facendo la stessa notte, e alcuni orologi non
  /// registrano affatto quel pezzo. 💡 E sono comunque strettissimi rispetto
  /// alla distanza vera fra due dormite distinte, che sono ore.
  static const Duration pausaCheSepara = Duration(minutes: 90);

  /// Sopra questa durata è la dormita principale, **a qualunque ora**.
  ///
  /// 💡 Serve a chi lavora di notte: chi dorme dalle 9 alle 16 non sta facendo
  /// una pennichella di sette ore.
  static const Duration durataDaNotte = Duration(hours: 4);

  /// Sotto questa durata non è una notte, **nemmeno alle tre di mattina**.
  ///
  /// 💡 Un colpo di sonno di mezz'ora davanti alla televisione resta un colpo
  /// di sonno anche se capita a notte fonda.
  static const Duration durataMinimaNotte = Duration(hours: 2);

  /// Il cuore della notte: le ore in cui, se stai dormendo, stai **dormendo la
  /// notte**.
  static const int oraInizioCuoreNotte = 23;

  static const int oraFineCuoreNotte = 7;

  /// Quanto bisogna starci dentro perché conti.
  static const Duration dentroIlCuore = Duration(minutes: 60);

  /// Ricompone i segmenti in dormite.
  ///
  /// 🚨 I segmenti vanno passati **tutti insieme**, non uno per volta: è
  /// esattamente l'informazione che mancava alla regola vecchia.
  static List<SessioneSonno> da(
    Iterable<({DateTime inizio, DateTime fine})> segmenti,
  ) {
    final ordinati = segmenti.toList()
      ..sort((a, b) => a.inizio.compareTo(b.inizio));

    if (ordinati.isEmpty) return const [];

    final sessioni = <SessioneSonno>[];

    var inizio = ordinati.first.inizio;
    var fine = ordinati.first.fine;

    for (final s in ordinati.skip(1)) {
      // ⚠️ `isAfter` sulla fine corrente e non sull'inizio: i segmenti possono
      // sovrapporsi, e due sorgenti diverse possono descrivere lo stesso pezzo
      // di notte.
      if (s.inizio.difference(fine) > pausaCheSepara) {
        sessioni.add(_classifica(inizio, fine));
        inizio = s.inizio;
        fine = s.fine;

        continue;
      }

      if (s.fine.isAfter(fine)) fine = s.fine;
    }

    sessioni.add(_classifica(inizio, fine));

    return sessioni;
  }

  /// Notte o pennichella.
  ///
  /// ── La regola, in una riga ────────────────────────────────────────────────
  ///
  ///     è una notte se è **lunga**, oppure se è **abbastanza lunga e capita di
  ///     notte**
  ///
  /// 💡 È la traduzione precisa dell'istinto giusto — *«se è DI NOTTE è una
  /// notte di sonno, se è di giorno è una pennichella»* — con l'aggiunta che
  /// serve a non chiamare «notte» un pisolino delle due di mattina.
  static SessioneSonno _classifica(DateTime inizio, DateTime fine) {
    final durata = fine.difference(inizio);

    final eNotte =
        durata >= durataDaNotte ||
        (durata >= durataMinimaNotte &&
            _dentroIlCuoreDellaNotte(inizio, fine) >= dentroIlCuore);

    return SessioneSonno(inizio: inizio, fine: fine, eNotte: eNotte);
  }

  /// Quanto della dormita cade fra le 23:00 e le 07:00.
  ///
  /// ⚠️ Si scorre **notte per notte** invece di fare aritmetica sulle ore: una
  /// dormita può attraversare più mezzanotti, e il cambio dell'ora legale
  /// rende falsa qualunque scorciatoia basata sul sommare 24 ore.
  static Duration _dentroIlCuoreDellaNotte(DateTime inizio, DateTime fine) {
    var totale = Duration.zero;

    // Si parte dal giorno prima dell'inizio: la finestra delle 23:00 di ieri
    // arriva dentro oggi.
    var giorno = DateTime(inizio.year, inizio.month, inizio.day - 1);
    final ultimo = DateTime(fine.year, fine.month, fine.day + 1);

    while (giorno.isBefore(ultimo)) {
      final apre = DateTime(
        giorno.year,
        giorno.month,
        giorno.day,
        oraInizioCuoreNotte,
      );
      final chiude = DateTime(
        giorno.year,
        giorno.month,
        giorno.day + 1,
        oraFineCuoreNotte,
      );

      final da = inizio.isAfter(apre) ? inizio : apre;
      final a = fine.isBefore(chiude) ? fine : chiude;

      if (a.isAfter(da)) totale += a.difference(da);

      giorno = DateTime(giorno.year, giorno.month, giorno.day + 1);
    }

    return totale;
  }

  /// A quale giornata appartiene ciascun segmento.
  ///
  /// 💡 È la forma comoda per chi deve scrivere in banca dati: si passano i
  /// segmenti e si riceve, per ognuno, il giorno da mettere in colonna.
  ///
  /// ⚠️ La chiave è l'istante d'inizio del segmento, che è anche la metà del
  /// vincolo di unicità `(fonte, iniziatoIl)`.
  static Map<DateTime, DateTime> giornatePerSegmento(
    Iterable<({DateTime inizio, DateTime fine})> segmenti,
  ) {
    final sessioni = da(segmenti);
    final fuori = <DateTime, DateTime>{};

    for (final s in segmenti) {
      // La sessione che lo contiene: la prima che comincia non dopo di lui e
      // finisce non prima.
      final sua = sessioni.firstWhere(
        (x) => !x.inizio.isAfter(s.inizio) && !x.fine.isBefore(s.inizio),
        orElse: () => _classifica(s.inizio, s.fine),
      );

      fuori[s.inizio] = sua.giornata;
    }

    return fuori;
  }
}

/// A quale giornata di riposo appartiene un istante — **solo per un segmento
/// isolato**.
///
/// 🚨 **Da non usare per decidere il giorno di una dormita.** Serve solo dove
/// non c'è modo di avere il contesto degli altri segmenti; ovunque ci sia, si
/// usa [SessioniDiSonno].
///
/// ⚠️ È rimasta perché la migrazione vecchia la nomina, e perché toglierla del
/// tutto vorrebbe dire riscrivere una migrazione già eseguita sui telefoni.
@Deprecated('Usa SessioniDiSonno: un segmento da solo non sa se è una notte.')
DateTime notteDi(DateTime istante) =>
    DateTime(istante.year, istante.month, istante.day);
