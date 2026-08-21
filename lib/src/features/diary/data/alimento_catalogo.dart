/// Un alimento del catalogo condiviso — 17/08/2026.
///
/// ── 💡 Perché i valori sono **per 100 g** e non per porzione ───────────────
///
/// Perché il catalogo è condiviso: se ognuno ci mettesse i valori della propria
/// porzione, lo stesso nome avrebbe verità diverse a seconda di chi l'ha
/// scritto per primo. ⚠️ La moltiplicazione per la quantità la fa l'app, qui,
/// nel momento in cui si registra il pasto.
class AlimentoCatalogo {
  const AlimentoCatalogo({
    required this.id,
    required this.nome,
    this.marca,
    this.kcal100,
    this.proteine100,
    this.carboidrati100,
    this.grassi100,
    this.basis = 'g',
    this.codiceABarre,
    this.immagineUrl,
    this.note,
  });

  factory AlimentoCatalogo.fromJson(Map<String, dynamic> j) => AlimentoCatalogo(
    id: (j['id'] as num).toInt(),
    nome: j['nome'] as String? ?? '',
    marca: j['marca'] as String?,
    kcal100: (j['kcal_100'] as num?)?.toDouble(),
    proteine100: (j['protein_100'] as num?)?.toDouble(),
    carboidrati100: (j['carbs_100'] as num?)?.toDouble(),
    grassi100: (j['fat_100'] as num?)?.toDouble(),
    basis: j['basis'] as String? ?? 'g',
    codiceABarre: j['codice_a_barre'] as String?,
    immagineUrl: j['immagine_url'] as String?,
    note: j['note'] as String?,
  );

  final int id;
  final String nome;
  final String? marca;
  final double? kcal100, proteine100, carboidrati100, grassi100;

  /// `g` per i solidi, `ml` per i liquidi: 100 ml di olio non sono 100 g.
  final String basis;

  final String? codiceABarre;
  final String? immagineUrl;

  /// 🚨 **La provenienza del dato, ed è l'attribuzione.**
  ///
  /// CREA chiede «una chiara indicazione della fonte originale», Open Food
  /// Facts chiede l'attribuzione ODbL. ⚠️ Non è una nota interna da tenere in
  /// banca dati: la licenza chiede che la veda **chi usa il dato**, cioè la
  /// persona davanti allo schermo.
  final String? note;

  /// Come si presenta in un elenco: «Petto di pollo · Aia».
  String get titolo =>
      marca == null || marca!.isEmpty ? nome : '$nome · $marca';

  /// I valori per una quantità in grammi (o millilitri).
  ///
  /// 💡 Restituisce `null` dove il catalogo non sa: meglio un campo vuoto che
  /// uno zero, perché uno zero nel diario è un'affermazione — «questo alimento
  /// non ha proteine» — e non un «non lo so».
  ({double? kcal, double? proteine, double? carboidrati, double? grassi}) per(
    double quantita,
  ) {
    double? scala(double? per100) =>
        per100 == null ? null : per100 * quantita / 100;

    return (
      kcal: scala(kcal100),
      proteine: scala(proteine100),
      carboidrati: scala(carboidrati100),
      grassi: scala(grassi100),
    );
  }
}
