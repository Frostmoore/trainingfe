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

enum GruppoMuscolare {
  petto('chest', 'Petto'),
  schiena('back', 'Schiena'),
  spalle('shoulders', 'Spalle'),
  bicipiti('biceps', 'Bicipiti'),
  tricipiti('triceps', 'Tricipiti'),
  avambracci('forearms', 'Avambracci'),
  addome('abs', 'Addome'),
  glutei('glutes', 'Glutei'),
  quadricipiti('quads', 'Quadricipiti'),
  femorali('hamstrings', 'Femorali'),
  polpacci('calves', 'Polpacci'),
  totale('full_body', 'Tutto il corpo'),
  cardio('cardio', 'Cardio');

  const GruppoMuscolare(this.valore, this.etichetta);

  /// Il valore che viaggia nel JSON. 🚨 Deve restare uguale a quello del server.
  final String valore;

  /// Come si chiama in italiano, per chi lo legge.
  final String etichetta;

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
