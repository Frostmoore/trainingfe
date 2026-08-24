/// I gruppi muscolari, come li chiama il server — 3b-A.3.4, 23/08/2026.
///
/// ══ 🚨 GLI STESSI VALORI DELL'ENUM PHP, NON DEI SINONIMI ═══════════════════
///
/// ⛔ I `value` qui sotto sono **identici** a `App\Enums\MuscleGroup`: viaggiano
/// nel JSON in tutte e due le direzioni, e un `pettorali` scritto in italiano
/// verrebbe rifiutato con un 422 che nessuno capisce.
///
/// 💡 L'etichetta italiana sta **solo** qui, che è il posto giusto: il server
/// non deve sapere come si dice «hamstrings» a un iscritto.
library;

/// Quello che si sa dei muscoli di un esercizio.
///
/// 🚨 **Sta qui e non nel widget che lo chiede.** Lo usano il modello della
/// scheda, il compositore e il foglio di scelta: se vivesse nella cartella
/// `ui/`, il modello dei dati dovrebbe importare un widget per conoscere la
/// forma di un proprio campo.
typedef MuscoliScelti = ({
  GruppoMuscolare? primario,
  List<GruppoMuscolare> secondari,
});

/// Come i muscoli entrano in un JSON diretto al server — 3b-A.3.4/A.3.5.
///
/// ══ 🚨 TRE STATI, NON DUE, E SCRITTI IN UN POSTO SOLO ══════════════════════
///
/// - `null` → **nessuno l'ha deciso**: non si manda niente, e il server dira'
///   di no se sta creando (`muscoli_non_decisi`, 422).
/// - `secondari` vuoto → **«questo esercizio isola davvero»**: si manda `[]`,
///   perche' e' una risposta.
/// - `secondari` pieno → i muscoli che aiutano.
///
/// ⛔ Questa regola stava scritta in **tre posti** — il modello della scheda,
/// l'editor della scheda propria e il player — e tre copie della stessa regola
/// diventano tre regole diverse alla prima modifica. 🚨 Il modo di sbagliare
/// non e' teorico: basta che una delle tre mandi sempre `[]`, e la libreria si
/// riempie di esercizi che *dichiarano* di non avere secondari.
Map<String, dynamic> muscoliInJson(MuscoliScelti? muscoli) {
  if (muscoli == null) return const {};

  return {
    if (muscoli.primario != null) 'muscle_group': muscoli.primario!.valore,
    'secondary_muscles': muscoli.secondari
        .map((m) => m.valore)
        .toList(growable: false),
  };
}

enum GruppoMuscolare {
  petto('chest', 'Petto'),
  schiena('back', 'Schiena'),
  spalle('shoulders', 'Spalle'),
  bicipiti('biceps', 'Bicipiti'),
  tricipiti('triceps', 'Tricipiti'),
  avambracci('forearms', 'Avambracci', 'Avambr.'),
  addome('abs', 'Addome'),
  glutei('glutes', 'Glutei'),
  quadricipiti('quads', 'Quadricipiti', 'Quadric.'),
  femorali('hamstrings', 'Femorali'),
  polpacci('calves', 'Polpacci'),
  totale('full_body', 'Tutto il corpo', 'Tutto'),
  cardio('cardio', 'Cardio');

  const GruppoMuscolare(this.valore, this.etichetta, [String? breve])
    : _breve = breve;

  /// Il valore che viaggia nel JSON. 🚨 Deve restare uguale a quello del server.
  final String valore;

  /// Come si chiama in italiano, per chi lo legge.
  final String etichetta;

  final String? _breve;

  /// La forma corta, dove lo spazio è contato — 24/08/2026.
  ///
  /// ══ 🚨 SERVE AL GRAFICO A STELLA, E L'HA CHIESTO LO SCHERMO ═══════════
  ///
  /// ⛔ Undici parole intere attorno a un cerchio dentro una card da 250 px non
  /// ci stanno: **«Addome» e «Avambracci» si sovrapponevano**, e le due
  /// etichette in basso diventavano una macchia illeggibile. Visto sul telefono
  /// del committente il 24/08 — nessun test lo prendeva, perché non è uno sforo:
  /// è testo che si accavalla dentro un `Canvas`.
  ///
  /// 💡 **Solo tre voci ce l'hanno diversa**, e le altre ricadono sull'intera:
  /// abbreviare «Petto» non serve a nessuno, e un elenco parallelo di undici
  /// stringhe sarebbe una seconda verità da tenere allineata.
  String get etichettaBreve => _breve ?? etichetta;

  static GruppoMuscolare? da(Object? valore) {
    if (valore == null) return null;

    for (final g in GruppoMuscolare.values) {
      if (g.valore == valore) return g;
    }

    return null;
  }

  /// Se corrisponde a una **zona del corpo** che si può colorare.
  ///
  /// 🚨 `cardio` e `full_body` sono valori legittimi — dicono che natura ha
  /// l'esercizio — ma **non sono muscoli**. ⛔ Colorare una figura con «cardio»
  /// non vuol dire niente. 💡 Una corsa colora le gambe lo stesso, perché le ha
  /// fra i secondari: è la stessa regola di `MuscleGroup::eUnMuscolo()` sul
  /// server, e sta scritta in tutti e due i posti perché tutti e due decidono.
  bool get eUnMuscolo =>
      this != GruppoMuscolare.cardio && this != GruppoMuscolare.totale;
}
