// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'archivio_salute.dart';

// ignore_for_file: type=lint
class $LettureSaluteTable extends LettureSalute
    with TableInfo<$LettureSaluteTable, LetturaSalute> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LettureSaluteTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _fonteMeta = const VerificationMeta('fonte');
  @override
  late final GeneratedColumn<String> fonte = GeneratedColumn<String>(
    'fonte',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 32,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _metricaMeta = const VerificationMeta(
    'metrica',
  );
  @override
  late final GeneratedColumn<String> metrica = GeneratedColumn<String>(
    'metrica',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 24,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _misurataIlMeta = const VerificationMeta(
    'misurataIl',
  );
  @override
  late final GeneratedColumn<DateTime> misurataIl = GeneratedColumn<DateTime>(
    'misurata_il',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _giornoMeta = const VerificationMeta('giorno');
  @override
  late final GeneratedColumn<DateTime> giorno = GeneratedColumn<DateTime>(
    'giorno',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valoreMeta = const VerificationMeta('valore');
  @override
  late final GeneratedColumn<double> valore = GeneratedColumn<double>(
    'valore',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    fonte,
    metrica,
    misurataIl,
    giorno,
    valore,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'letture_salute';
  @override
  VerificationContext validateIntegrity(
    Insertable<LetturaSalute> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('fonte')) {
      context.handle(
        _fonteMeta,
        fonte.isAcceptableOrUnknown(data['fonte']!, _fonteMeta),
      );
    } else if (isInserting) {
      context.missing(_fonteMeta);
    }
    if (data.containsKey('metrica')) {
      context.handle(
        _metricaMeta,
        metrica.isAcceptableOrUnknown(data['metrica']!, _metricaMeta),
      );
    } else if (isInserting) {
      context.missing(_metricaMeta);
    }
    if (data.containsKey('misurata_il')) {
      context.handle(
        _misurataIlMeta,
        misurataIl.isAcceptableOrUnknown(data['misurata_il']!, _misurataIlMeta),
      );
    } else if (isInserting) {
      context.missing(_misurataIlMeta);
    }
    if (data.containsKey('giorno')) {
      context.handle(
        _giornoMeta,
        giorno.isAcceptableOrUnknown(data['giorno']!, _giornoMeta),
      );
    } else if (isInserting) {
      context.missing(_giornoMeta);
    }
    if (data.containsKey('valore')) {
      context.handle(
        _valoreMeta,
        valore.isAcceptableOrUnknown(data['valore']!, _valoreMeta),
      );
    } else if (isInserting) {
      context.missing(_valoreMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {fonte, metrica, misurataIl},
  ];
  @override
  LetturaSalute map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LetturaSalute(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      fonte: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fonte'],
      )!,
      metrica: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metrica'],
      )!,
      misurataIl: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}misurata_il'],
      )!,
      giorno: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}giorno'],
      )!,
      valore: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}valore'],
      )!,
    );
  }

  @override
  $LettureSaluteTable createAlias(String alias) {
    return $LettureSaluteTable(attachedDatabase, alias);
  }
}

class LetturaSalute extends DataClass implements Insertable<LetturaSalute> {
  final int id;

  /// Da dove viene: `health_connect`, `healthkit`, `manuale`.
  final String fonte;

  /// Il codice di `MetricaSalute`.
  final String metrica;
  final DateTime misurataIl;

  /// Il giorno di appartenenza, a mezzanotte.
  ///
  /// ⚠️ Ridondante rispetto a `misurataIl`, e **serve**: la media di riferimento
  /// ragiona per giorni, e senza questa colonna ogni confronto diventerebbe un
  /// calcolo su un timestamp — cioè un indice che non si può usare.
  final DateTime giorno;
  final double valore;
  const LetturaSalute({
    required this.id,
    required this.fonte,
    required this.metrica,
    required this.misurataIl,
    required this.giorno,
    required this.valore,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['fonte'] = Variable<String>(fonte);
    map['metrica'] = Variable<String>(metrica);
    map['misurata_il'] = Variable<DateTime>(misurataIl);
    map['giorno'] = Variable<DateTime>(giorno);
    map['valore'] = Variable<double>(valore);
    return map;
  }

  LettureSaluteCompanion toCompanion(bool nullToAbsent) {
    return LettureSaluteCompanion(
      id: Value(id),
      fonte: Value(fonte),
      metrica: Value(metrica),
      misurataIl: Value(misurataIl),
      giorno: Value(giorno),
      valore: Value(valore),
    );
  }

  factory LetturaSalute.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LetturaSalute(
      id: serializer.fromJson<int>(json['id']),
      fonte: serializer.fromJson<String>(json['fonte']),
      metrica: serializer.fromJson<String>(json['metrica']),
      misurataIl: serializer.fromJson<DateTime>(json['misurataIl']),
      giorno: serializer.fromJson<DateTime>(json['giorno']),
      valore: serializer.fromJson<double>(json['valore']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'fonte': serializer.toJson<String>(fonte),
      'metrica': serializer.toJson<String>(metrica),
      'misurataIl': serializer.toJson<DateTime>(misurataIl),
      'giorno': serializer.toJson<DateTime>(giorno),
      'valore': serializer.toJson<double>(valore),
    };
  }

  LetturaSalute copyWith({
    int? id,
    String? fonte,
    String? metrica,
    DateTime? misurataIl,
    DateTime? giorno,
    double? valore,
  }) => LetturaSalute(
    id: id ?? this.id,
    fonte: fonte ?? this.fonte,
    metrica: metrica ?? this.metrica,
    misurataIl: misurataIl ?? this.misurataIl,
    giorno: giorno ?? this.giorno,
    valore: valore ?? this.valore,
  );
  LetturaSalute copyWithCompanion(LettureSaluteCompanion data) {
    return LetturaSalute(
      id: data.id.present ? data.id.value : this.id,
      fonte: data.fonte.present ? data.fonte.value : this.fonte,
      metrica: data.metrica.present ? data.metrica.value : this.metrica,
      misurataIl: data.misurataIl.present
          ? data.misurataIl.value
          : this.misurataIl,
      giorno: data.giorno.present ? data.giorno.value : this.giorno,
      valore: data.valore.present ? data.valore.value : this.valore,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LetturaSalute(')
          ..write('id: $id, ')
          ..write('fonte: $fonte, ')
          ..write('metrica: $metrica, ')
          ..write('misurataIl: $misurataIl, ')
          ..write('giorno: $giorno, ')
          ..write('valore: $valore')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, fonte, metrica, misurataIl, giorno, valore);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LetturaSalute &&
          other.id == this.id &&
          other.fonte == this.fonte &&
          other.metrica == this.metrica &&
          other.misurataIl == this.misurataIl &&
          other.giorno == this.giorno &&
          other.valore == this.valore);
}

class LettureSaluteCompanion extends UpdateCompanion<LetturaSalute> {
  final Value<int> id;
  final Value<String> fonte;
  final Value<String> metrica;
  final Value<DateTime> misurataIl;
  final Value<DateTime> giorno;
  final Value<double> valore;
  const LettureSaluteCompanion({
    this.id = const Value.absent(),
    this.fonte = const Value.absent(),
    this.metrica = const Value.absent(),
    this.misurataIl = const Value.absent(),
    this.giorno = const Value.absent(),
    this.valore = const Value.absent(),
  });
  LettureSaluteCompanion.insert({
    this.id = const Value.absent(),
    required String fonte,
    required String metrica,
    required DateTime misurataIl,
    required DateTime giorno,
    required double valore,
  }) : fonte = Value(fonte),
       metrica = Value(metrica),
       misurataIl = Value(misurataIl),
       giorno = Value(giorno),
       valore = Value(valore);
  static Insertable<LetturaSalute> custom({
    Expression<int>? id,
    Expression<String>? fonte,
    Expression<String>? metrica,
    Expression<DateTime>? misurataIl,
    Expression<DateTime>? giorno,
    Expression<double>? valore,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (fonte != null) 'fonte': fonte,
      if (metrica != null) 'metrica': metrica,
      if (misurataIl != null) 'misurata_il': misurataIl,
      if (giorno != null) 'giorno': giorno,
      if (valore != null) 'valore': valore,
    });
  }

  LettureSaluteCompanion copyWith({
    Value<int>? id,
    Value<String>? fonte,
    Value<String>? metrica,
    Value<DateTime>? misurataIl,
    Value<DateTime>? giorno,
    Value<double>? valore,
  }) {
    return LettureSaluteCompanion(
      id: id ?? this.id,
      fonte: fonte ?? this.fonte,
      metrica: metrica ?? this.metrica,
      misurataIl: misurataIl ?? this.misurataIl,
      giorno: giorno ?? this.giorno,
      valore: valore ?? this.valore,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (fonte.present) {
      map['fonte'] = Variable<String>(fonte.value);
    }
    if (metrica.present) {
      map['metrica'] = Variable<String>(metrica.value);
    }
    if (misurataIl.present) {
      map['misurata_il'] = Variable<DateTime>(misurataIl.value);
    }
    if (giorno.present) {
      map['giorno'] = Variable<DateTime>(giorno.value);
    }
    if (valore.present) {
      map['valore'] = Variable<double>(valore.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LettureSaluteCompanion(')
          ..write('id: $id, ')
          ..write('fonte: $fonte, ')
          ..write('metrica: $metrica, ')
          ..write('misurataIl: $misurataIl, ')
          ..write('giorno: $giorno, ')
          ..write('valore: $valore')
          ..write(')'))
        .toString();
  }
}

class $CampioniSonnoTable extends CampioniSonno
    with TableInfo<$CampioniSonnoTable, CampioneSonno> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CampioniSonnoTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _fonteMeta = const VerificationMeta('fonte');
  @override
  late final GeneratedColumn<String> fonte = GeneratedColumn<String>(
    'fonte',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 32,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notteMeta = const VerificationMeta('notte');
  @override
  late final GeneratedColumn<DateTime> notte = GeneratedColumn<DateTime>(
    'notte',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _iniziatoIlMeta = const VerificationMeta(
    'iniziatoIl',
  );
  @override
  late final GeneratedColumn<DateTime> iniziatoIl = GeneratedColumn<DateTime>(
    'iniziato_il',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _finitoIlMeta = const VerificationMeta(
    'finitoIl',
  );
  @override
  late final GeneratedColumn<DateTime> finitoIl = GeneratedColumn<DateTime>(
    'finito_il',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _faseMeta = const VerificationMeta('fase');
  @override
  late final GeneratedColumn<int> fase = GeneratedColumn<int>(
    'fase',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    fonte,
    notte,
    iniziatoIl,
    finitoIl,
    fase,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'campioni_sonno';
  @override
  VerificationContext validateIntegrity(
    Insertable<CampioneSonno> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('fonte')) {
      context.handle(
        _fonteMeta,
        fonte.isAcceptableOrUnknown(data['fonte']!, _fonteMeta),
      );
    } else if (isInserting) {
      context.missing(_fonteMeta);
    }
    if (data.containsKey('notte')) {
      context.handle(
        _notteMeta,
        notte.isAcceptableOrUnknown(data['notte']!, _notteMeta),
      );
    } else if (isInserting) {
      context.missing(_notteMeta);
    }
    if (data.containsKey('iniziato_il')) {
      context.handle(
        _iniziatoIlMeta,
        iniziatoIl.isAcceptableOrUnknown(data['iniziato_il']!, _iniziatoIlMeta),
      );
    } else if (isInserting) {
      context.missing(_iniziatoIlMeta);
    }
    if (data.containsKey('finito_il')) {
      context.handle(
        _finitoIlMeta,
        finitoIl.isAcceptableOrUnknown(data['finito_il']!, _finitoIlMeta),
      );
    } else if (isInserting) {
      context.missing(_finitoIlMeta);
    }
    if (data.containsKey('fase')) {
      context.handle(
        _faseMeta,
        fase.isAcceptableOrUnknown(data['fase']!, _faseMeta),
      );
    } else if (isInserting) {
      context.missing(_faseMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {fonte, iniziatoIl},
  ];
  @override
  CampioneSonno map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CampioneSonno(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      fonte: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fonte'],
      )!,
      notte: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}notte'],
      )!,
      iniziatoIl: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}iniziato_il'],
      )!,
      finitoIl: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}finito_il'],
      )!,
      fase: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fase'],
      )!,
    );
  }

  @override
  $CampioniSonnoTable createAlias(String alias) {
    return $CampioniSonnoTable(attachedDatabase, alias);
  }
}

class CampioneSonno extends DataClass implements Insertable<CampioneSonno> {
  final int id;
  final String fonte;

  /// La notte di appartenenza — vedi `notteDi()`.
  final DateTime notte;
  final DateTime iniziatoIl;
  final DateTime finitoIl;

  /// Il codice di `FaseSonno`.
  final int fase;
  const CampioneSonno({
    required this.id,
    required this.fonte,
    required this.notte,
    required this.iniziatoIl,
    required this.finitoIl,
    required this.fase,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['fonte'] = Variable<String>(fonte);
    map['notte'] = Variable<DateTime>(notte);
    map['iniziato_il'] = Variable<DateTime>(iniziatoIl);
    map['finito_il'] = Variable<DateTime>(finitoIl);
    map['fase'] = Variable<int>(fase);
    return map;
  }

  CampioniSonnoCompanion toCompanion(bool nullToAbsent) {
    return CampioniSonnoCompanion(
      id: Value(id),
      fonte: Value(fonte),
      notte: Value(notte),
      iniziatoIl: Value(iniziatoIl),
      finitoIl: Value(finitoIl),
      fase: Value(fase),
    );
  }

  factory CampioneSonno.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CampioneSonno(
      id: serializer.fromJson<int>(json['id']),
      fonte: serializer.fromJson<String>(json['fonte']),
      notte: serializer.fromJson<DateTime>(json['notte']),
      iniziatoIl: serializer.fromJson<DateTime>(json['iniziatoIl']),
      finitoIl: serializer.fromJson<DateTime>(json['finitoIl']),
      fase: serializer.fromJson<int>(json['fase']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'fonte': serializer.toJson<String>(fonte),
      'notte': serializer.toJson<DateTime>(notte),
      'iniziatoIl': serializer.toJson<DateTime>(iniziatoIl),
      'finitoIl': serializer.toJson<DateTime>(finitoIl),
      'fase': serializer.toJson<int>(fase),
    };
  }

  CampioneSonno copyWith({
    int? id,
    String? fonte,
    DateTime? notte,
    DateTime? iniziatoIl,
    DateTime? finitoIl,
    int? fase,
  }) => CampioneSonno(
    id: id ?? this.id,
    fonte: fonte ?? this.fonte,
    notte: notte ?? this.notte,
    iniziatoIl: iniziatoIl ?? this.iniziatoIl,
    finitoIl: finitoIl ?? this.finitoIl,
    fase: fase ?? this.fase,
  );
  CampioneSonno copyWithCompanion(CampioniSonnoCompanion data) {
    return CampioneSonno(
      id: data.id.present ? data.id.value : this.id,
      fonte: data.fonte.present ? data.fonte.value : this.fonte,
      notte: data.notte.present ? data.notte.value : this.notte,
      iniziatoIl: data.iniziatoIl.present
          ? data.iniziatoIl.value
          : this.iniziatoIl,
      finitoIl: data.finitoIl.present ? data.finitoIl.value : this.finitoIl,
      fase: data.fase.present ? data.fase.value : this.fase,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CampioneSonno(')
          ..write('id: $id, ')
          ..write('fonte: $fonte, ')
          ..write('notte: $notte, ')
          ..write('iniziatoIl: $iniziatoIl, ')
          ..write('finitoIl: $finitoIl, ')
          ..write('fase: $fase')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, fonte, notte, iniziatoIl, finitoIl, fase);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CampioneSonno &&
          other.id == this.id &&
          other.fonte == this.fonte &&
          other.notte == this.notte &&
          other.iniziatoIl == this.iniziatoIl &&
          other.finitoIl == this.finitoIl &&
          other.fase == this.fase);
}

class CampioniSonnoCompanion extends UpdateCompanion<CampioneSonno> {
  final Value<int> id;
  final Value<String> fonte;
  final Value<DateTime> notte;
  final Value<DateTime> iniziatoIl;
  final Value<DateTime> finitoIl;
  final Value<int> fase;
  const CampioniSonnoCompanion({
    this.id = const Value.absent(),
    this.fonte = const Value.absent(),
    this.notte = const Value.absent(),
    this.iniziatoIl = const Value.absent(),
    this.finitoIl = const Value.absent(),
    this.fase = const Value.absent(),
  });
  CampioniSonnoCompanion.insert({
    this.id = const Value.absent(),
    required String fonte,
    required DateTime notte,
    required DateTime iniziatoIl,
    required DateTime finitoIl,
    required int fase,
  }) : fonte = Value(fonte),
       notte = Value(notte),
       iniziatoIl = Value(iniziatoIl),
       finitoIl = Value(finitoIl),
       fase = Value(fase);
  static Insertable<CampioneSonno> custom({
    Expression<int>? id,
    Expression<String>? fonte,
    Expression<DateTime>? notte,
    Expression<DateTime>? iniziatoIl,
    Expression<DateTime>? finitoIl,
    Expression<int>? fase,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (fonte != null) 'fonte': fonte,
      if (notte != null) 'notte': notte,
      if (iniziatoIl != null) 'iniziato_il': iniziatoIl,
      if (finitoIl != null) 'finito_il': finitoIl,
      if (fase != null) 'fase': fase,
    });
  }

  CampioniSonnoCompanion copyWith({
    Value<int>? id,
    Value<String>? fonte,
    Value<DateTime>? notte,
    Value<DateTime>? iniziatoIl,
    Value<DateTime>? finitoIl,
    Value<int>? fase,
  }) {
    return CampioniSonnoCompanion(
      id: id ?? this.id,
      fonte: fonte ?? this.fonte,
      notte: notte ?? this.notte,
      iniziatoIl: iniziatoIl ?? this.iniziatoIl,
      finitoIl: finitoIl ?? this.finitoIl,
      fase: fase ?? this.fase,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (fonte.present) {
      map['fonte'] = Variable<String>(fonte.value);
    }
    if (notte.present) {
      map['notte'] = Variable<DateTime>(notte.value);
    }
    if (iniziatoIl.present) {
      map['iniziato_il'] = Variable<DateTime>(iniziatoIl.value);
    }
    if (finitoIl.present) {
      map['finito_il'] = Variable<DateTime>(finitoIl.value);
    }
    if (fase.present) {
      map['fase'] = Variable<int>(fase.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CampioniSonnoCompanion(')
          ..write('id: $id, ')
          ..write('fonte: $fonte, ')
          ..write('notte: $notte, ')
          ..write('iniziatoIl: $iniziatoIl, ')
          ..write('finitoIl: $finitoIl, ')
          ..write('fase: $fase')
          ..write(')'))
        .toString();
  }
}

class $MisureCorpoTable extends MisureCorpo
    with TableInfo<$MisureCorpoTable, MisuraCorpo> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MisureCorpoTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _giornoMeta = const VerificationMeta('giorno');
  @override
  late final GeneratedColumn<DateTime> giorno = GeneratedColumn<DateTime>(
    'giorno',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _pesoKgMeta = const VerificationMeta('pesoKg');
  @override
  late final GeneratedColumn<double> pesoKg = GeneratedColumn<double>(
    'peso_kg',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _massaGrassaPctMeta = const VerificationMeta(
    'massaGrassaPct',
  );
  @override
  late final GeneratedColumn<double> massaGrassaPct = GeneratedColumn<double>(
    'massa_grassa_pct',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _massaMagraKgMeta = const VerificationMeta(
    'massaMagraKg',
  );
  @override
  late final GeneratedColumn<double> massaMagraKg = GeneratedColumn<double>(
    'massa_magra_kg',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _origineMeta = const VerificationMeta(
    'origine',
  );
  @override
  late final GeneratedColumn<String> origine = GeneratedColumn<String>(
    'origine',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _vitaCmMeta = const VerificationMeta('vitaCm');
  @override
  late final GeneratedColumn<double> vitaCm = GeneratedColumn<double>(
    'vita_cm',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _toraceCmMeta = const VerificationMeta(
    'toraceCm',
  );
  @override
  late final GeneratedColumn<double> toraceCm = GeneratedColumn<double>(
    'torace_cm',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _braccioCmMeta = const VerificationMeta(
    'braccioCm',
  );
  @override
  late final GeneratedColumn<double> braccioCm = GeneratedColumn<double>(
    'braccio_cm',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cosciaCmMeta = const VerificationMeta(
    'cosciaCm',
  );
  @override
  late final GeneratedColumn<double> cosciaCm = GeneratedColumn<double>(
    'coscia_cm',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    giorno,
    pesoKg,
    massaGrassaPct,
    massaMagraKg,
    origine,
    vitaCm,
    toraceCm,
    braccioCm,
    cosciaCm,
    note,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'misure_corpo';
  @override
  VerificationContext validateIntegrity(
    Insertable<MisuraCorpo> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('giorno')) {
      context.handle(
        _giornoMeta,
        giorno.isAcceptableOrUnknown(data['giorno']!, _giornoMeta),
      );
    } else if (isInserting) {
      context.missing(_giornoMeta);
    }
    if (data.containsKey('peso_kg')) {
      context.handle(
        _pesoKgMeta,
        pesoKg.isAcceptableOrUnknown(data['peso_kg']!, _pesoKgMeta),
      );
    }
    if (data.containsKey('massa_grassa_pct')) {
      context.handle(
        _massaGrassaPctMeta,
        massaGrassaPct.isAcceptableOrUnknown(
          data['massa_grassa_pct']!,
          _massaGrassaPctMeta,
        ),
      );
    }
    if (data.containsKey('massa_magra_kg')) {
      context.handle(
        _massaMagraKgMeta,
        massaMagraKg.isAcceptableOrUnknown(
          data['massa_magra_kg']!,
          _massaMagraKgMeta,
        ),
      );
    }
    if (data.containsKey('origine')) {
      context.handle(
        _origineMeta,
        origine.isAcceptableOrUnknown(data['origine']!, _origineMeta),
      );
    }
    if (data.containsKey('vita_cm')) {
      context.handle(
        _vitaCmMeta,
        vitaCm.isAcceptableOrUnknown(data['vita_cm']!, _vitaCmMeta),
      );
    }
    if (data.containsKey('torace_cm')) {
      context.handle(
        _toraceCmMeta,
        toraceCm.isAcceptableOrUnknown(data['torace_cm']!, _toraceCmMeta),
      );
    }
    if (data.containsKey('braccio_cm')) {
      context.handle(
        _braccioCmMeta,
        braccioCm.isAcceptableOrUnknown(data['braccio_cm']!, _braccioCmMeta),
      );
    }
    if (data.containsKey('coscia_cm')) {
      context.handle(
        _cosciaCmMeta,
        cosciaCm.isAcceptableOrUnknown(data['coscia_cm']!, _cosciaCmMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MisuraCorpo map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MisuraCorpo(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      giorno: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}giorno'],
      )!,
      pesoKg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}peso_kg'],
      ),
      massaGrassaPct: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}massa_grassa_pct'],
      ),
      massaMagraKg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}massa_magra_kg'],
      ),
      origine: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origine'],
      ),
      vitaCm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}vita_cm'],
      ),
      toraceCm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}torace_cm'],
      ),
      braccioCm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}braccio_cm'],
      ),
      cosciaCm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}coscia_cm'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
    );
  }

  @override
  $MisureCorpoTable createAlias(String alias) {
    return $MisureCorpoTable(attachedDatabase, alias);
  }
}

class MisuraCorpo extends DataClass implements Insertable<MisuraCorpo> {
  final int id;

  /// 🚨 **Una misura al giorno per persona.** Vedi `registraMisura()`.
  final DateTime giorno;
  final double? pesoKg;
  final double? massaGrassaPct;

  /// 🆕 La **massa magra**, quando la bilancia la manda — 3b-W.
  ///
  /// 💡 Vale più della percentuale di grasso: Katch-McArdle parte da qui, e
  /// averla **misurata** invece che derivata toglie di mezzo l'errore della
  /// bioimpedenza. ⚠️ La bilancia del committente non la manda; un orologio
  /// Amazfit sì.
  final double? massaMagraKg;

  /// 🆕 Da dove viene questa misura — 3b-W.2.
  ///
  /// ══ 🚨 SERVE A NON SOVRASCRIVERE QUELLO CHE UNO HA SCRITTO A MANO ═══════
  ///
  /// ⛔ Senza, un'importazione da Health Connect cancella **in silenzio** la
  /// correzione di chi si è pesato con una bilancia scassata e ha rimesso il
  /// numero giusto. ⚠️ E il caso non è teorico: la riga esiste, ha un valore
  /// plausibile, e nessuno si accorge di niente.
  ///
  /// ══ ⛔ E DICE SOLO «DA HEALTH CONNECT», NON QUALE APP ═══════════════════
  ///
  /// 🚨 Misurato il 30/08: `HealthDataPoint.sourceId` arriva **vuoto** su
  /// Android. Non sappiamo se un peso l'ha scritto la bilancia, l'orologio o
  /// una persona dentro Health Connect. 💡 Quindi l'interfaccia può dire *«da
  /// Health Connect»* e **non** *«dalla tua bilancia»*: promettere di sapere
  /// quale bilancia sarebbe mentire.
  ///
  /// ⚠️ **`null` è un valore vero**, e vuol dire «non lo so»: sono le righe
  /// scritte prima di 3b-W. ⛔ Riempirle con `'manuale'` alla migrazione le
  /// proteggerebbe per sempre da un aggiornamento — e non è vero che sono state
  /// scritte a mano: molte arrivano da un backup.
  final String? origine;
  final double? vitaCm;
  final double? toraceCm;
  final double? braccioCm;
  final double? cosciaCm;
  final String? note;
  const MisuraCorpo({
    required this.id,
    required this.giorno,
    this.pesoKg,
    this.massaGrassaPct,
    this.massaMagraKg,
    this.origine,
    this.vitaCm,
    this.toraceCm,
    this.braccioCm,
    this.cosciaCm,
    this.note,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['giorno'] = Variable<DateTime>(giorno);
    if (!nullToAbsent || pesoKg != null) {
      map['peso_kg'] = Variable<double>(pesoKg);
    }
    if (!nullToAbsent || massaGrassaPct != null) {
      map['massa_grassa_pct'] = Variable<double>(massaGrassaPct);
    }
    if (!nullToAbsent || massaMagraKg != null) {
      map['massa_magra_kg'] = Variable<double>(massaMagraKg);
    }
    if (!nullToAbsent || origine != null) {
      map['origine'] = Variable<String>(origine);
    }
    if (!nullToAbsent || vitaCm != null) {
      map['vita_cm'] = Variable<double>(vitaCm);
    }
    if (!nullToAbsent || toraceCm != null) {
      map['torace_cm'] = Variable<double>(toraceCm);
    }
    if (!nullToAbsent || braccioCm != null) {
      map['braccio_cm'] = Variable<double>(braccioCm);
    }
    if (!nullToAbsent || cosciaCm != null) {
      map['coscia_cm'] = Variable<double>(cosciaCm);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    return map;
  }

  MisureCorpoCompanion toCompanion(bool nullToAbsent) {
    return MisureCorpoCompanion(
      id: Value(id),
      giorno: Value(giorno),
      pesoKg: pesoKg == null && nullToAbsent
          ? const Value.absent()
          : Value(pesoKg),
      massaGrassaPct: massaGrassaPct == null && nullToAbsent
          ? const Value.absent()
          : Value(massaGrassaPct),
      massaMagraKg: massaMagraKg == null && nullToAbsent
          ? const Value.absent()
          : Value(massaMagraKg),
      origine: origine == null && nullToAbsent
          ? const Value.absent()
          : Value(origine),
      vitaCm: vitaCm == null && nullToAbsent
          ? const Value.absent()
          : Value(vitaCm),
      toraceCm: toraceCm == null && nullToAbsent
          ? const Value.absent()
          : Value(toraceCm),
      braccioCm: braccioCm == null && nullToAbsent
          ? const Value.absent()
          : Value(braccioCm),
      cosciaCm: cosciaCm == null && nullToAbsent
          ? const Value.absent()
          : Value(cosciaCm),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
    );
  }

  factory MisuraCorpo.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MisuraCorpo(
      id: serializer.fromJson<int>(json['id']),
      giorno: serializer.fromJson<DateTime>(json['giorno']),
      pesoKg: serializer.fromJson<double?>(json['pesoKg']),
      massaGrassaPct: serializer.fromJson<double?>(json['massaGrassaPct']),
      massaMagraKg: serializer.fromJson<double?>(json['massaMagraKg']),
      origine: serializer.fromJson<String?>(json['origine']),
      vitaCm: serializer.fromJson<double?>(json['vitaCm']),
      toraceCm: serializer.fromJson<double?>(json['toraceCm']),
      braccioCm: serializer.fromJson<double?>(json['braccioCm']),
      cosciaCm: serializer.fromJson<double?>(json['cosciaCm']),
      note: serializer.fromJson<String?>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'giorno': serializer.toJson<DateTime>(giorno),
      'pesoKg': serializer.toJson<double?>(pesoKg),
      'massaGrassaPct': serializer.toJson<double?>(massaGrassaPct),
      'massaMagraKg': serializer.toJson<double?>(massaMagraKg),
      'origine': serializer.toJson<String?>(origine),
      'vitaCm': serializer.toJson<double?>(vitaCm),
      'toraceCm': serializer.toJson<double?>(toraceCm),
      'braccioCm': serializer.toJson<double?>(braccioCm),
      'cosciaCm': serializer.toJson<double?>(cosciaCm),
      'note': serializer.toJson<String?>(note),
    };
  }

  MisuraCorpo copyWith({
    int? id,
    DateTime? giorno,
    Value<double?> pesoKg = const Value.absent(),
    Value<double?> massaGrassaPct = const Value.absent(),
    Value<double?> massaMagraKg = const Value.absent(),
    Value<String?> origine = const Value.absent(),
    Value<double?> vitaCm = const Value.absent(),
    Value<double?> toraceCm = const Value.absent(),
    Value<double?> braccioCm = const Value.absent(),
    Value<double?> cosciaCm = const Value.absent(),
    Value<String?> note = const Value.absent(),
  }) => MisuraCorpo(
    id: id ?? this.id,
    giorno: giorno ?? this.giorno,
    pesoKg: pesoKg.present ? pesoKg.value : this.pesoKg,
    massaGrassaPct: massaGrassaPct.present
        ? massaGrassaPct.value
        : this.massaGrassaPct,
    massaMagraKg: massaMagraKg.present ? massaMagraKg.value : this.massaMagraKg,
    origine: origine.present ? origine.value : this.origine,
    vitaCm: vitaCm.present ? vitaCm.value : this.vitaCm,
    toraceCm: toraceCm.present ? toraceCm.value : this.toraceCm,
    braccioCm: braccioCm.present ? braccioCm.value : this.braccioCm,
    cosciaCm: cosciaCm.present ? cosciaCm.value : this.cosciaCm,
    note: note.present ? note.value : this.note,
  );
  MisuraCorpo copyWithCompanion(MisureCorpoCompanion data) {
    return MisuraCorpo(
      id: data.id.present ? data.id.value : this.id,
      giorno: data.giorno.present ? data.giorno.value : this.giorno,
      pesoKg: data.pesoKg.present ? data.pesoKg.value : this.pesoKg,
      massaGrassaPct: data.massaGrassaPct.present
          ? data.massaGrassaPct.value
          : this.massaGrassaPct,
      massaMagraKg: data.massaMagraKg.present
          ? data.massaMagraKg.value
          : this.massaMagraKg,
      origine: data.origine.present ? data.origine.value : this.origine,
      vitaCm: data.vitaCm.present ? data.vitaCm.value : this.vitaCm,
      toraceCm: data.toraceCm.present ? data.toraceCm.value : this.toraceCm,
      braccioCm: data.braccioCm.present ? data.braccioCm.value : this.braccioCm,
      cosciaCm: data.cosciaCm.present ? data.cosciaCm.value : this.cosciaCm,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MisuraCorpo(')
          ..write('id: $id, ')
          ..write('giorno: $giorno, ')
          ..write('pesoKg: $pesoKg, ')
          ..write('massaGrassaPct: $massaGrassaPct, ')
          ..write('massaMagraKg: $massaMagraKg, ')
          ..write('origine: $origine, ')
          ..write('vitaCm: $vitaCm, ')
          ..write('toraceCm: $toraceCm, ')
          ..write('braccioCm: $braccioCm, ')
          ..write('cosciaCm: $cosciaCm, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    giorno,
    pesoKg,
    massaGrassaPct,
    massaMagraKg,
    origine,
    vitaCm,
    toraceCm,
    braccioCm,
    cosciaCm,
    note,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MisuraCorpo &&
          other.id == this.id &&
          other.giorno == this.giorno &&
          other.pesoKg == this.pesoKg &&
          other.massaGrassaPct == this.massaGrassaPct &&
          other.massaMagraKg == this.massaMagraKg &&
          other.origine == this.origine &&
          other.vitaCm == this.vitaCm &&
          other.toraceCm == this.toraceCm &&
          other.braccioCm == this.braccioCm &&
          other.cosciaCm == this.cosciaCm &&
          other.note == this.note);
}

class MisureCorpoCompanion extends UpdateCompanion<MisuraCorpo> {
  final Value<int> id;
  final Value<DateTime> giorno;
  final Value<double?> pesoKg;
  final Value<double?> massaGrassaPct;
  final Value<double?> massaMagraKg;
  final Value<String?> origine;
  final Value<double?> vitaCm;
  final Value<double?> toraceCm;
  final Value<double?> braccioCm;
  final Value<double?> cosciaCm;
  final Value<String?> note;
  const MisureCorpoCompanion({
    this.id = const Value.absent(),
    this.giorno = const Value.absent(),
    this.pesoKg = const Value.absent(),
    this.massaGrassaPct = const Value.absent(),
    this.massaMagraKg = const Value.absent(),
    this.origine = const Value.absent(),
    this.vitaCm = const Value.absent(),
    this.toraceCm = const Value.absent(),
    this.braccioCm = const Value.absent(),
    this.cosciaCm = const Value.absent(),
    this.note = const Value.absent(),
  });
  MisureCorpoCompanion.insert({
    this.id = const Value.absent(),
    required DateTime giorno,
    this.pesoKg = const Value.absent(),
    this.massaGrassaPct = const Value.absent(),
    this.massaMagraKg = const Value.absent(),
    this.origine = const Value.absent(),
    this.vitaCm = const Value.absent(),
    this.toraceCm = const Value.absent(),
    this.braccioCm = const Value.absent(),
    this.cosciaCm = const Value.absent(),
    this.note = const Value.absent(),
  }) : giorno = Value(giorno);
  static Insertable<MisuraCorpo> custom({
    Expression<int>? id,
    Expression<DateTime>? giorno,
    Expression<double>? pesoKg,
    Expression<double>? massaGrassaPct,
    Expression<double>? massaMagraKg,
    Expression<String>? origine,
    Expression<double>? vitaCm,
    Expression<double>? toraceCm,
    Expression<double>? braccioCm,
    Expression<double>? cosciaCm,
    Expression<String>? note,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (giorno != null) 'giorno': giorno,
      if (pesoKg != null) 'peso_kg': pesoKg,
      if (massaGrassaPct != null) 'massa_grassa_pct': massaGrassaPct,
      if (massaMagraKg != null) 'massa_magra_kg': massaMagraKg,
      if (origine != null) 'origine': origine,
      if (vitaCm != null) 'vita_cm': vitaCm,
      if (toraceCm != null) 'torace_cm': toraceCm,
      if (braccioCm != null) 'braccio_cm': braccioCm,
      if (cosciaCm != null) 'coscia_cm': cosciaCm,
      if (note != null) 'note': note,
    });
  }

  MisureCorpoCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? giorno,
    Value<double?>? pesoKg,
    Value<double?>? massaGrassaPct,
    Value<double?>? massaMagraKg,
    Value<String?>? origine,
    Value<double?>? vitaCm,
    Value<double?>? toraceCm,
    Value<double?>? braccioCm,
    Value<double?>? cosciaCm,
    Value<String?>? note,
  }) {
    return MisureCorpoCompanion(
      id: id ?? this.id,
      giorno: giorno ?? this.giorno,
      pesoKg: pesoKg ?? this.pesoKg,
      massaGrassaPct: massaGrassaPct ?? this.massaGrassaPct,
      massaMagraKg: massaMagraKg ?? this.massaMagraKg,
      origine: origine ?? this.origine,
      vitaCm: vitaCm ?? this.vitaCm,
      toraceCm: toraceCm ?? this.toraceCm,
      braccioCm: braccioCm ?? this.braccioCm,
      cosciaCm: cosciaCm ?? this.cosciaCm,
      note: note ?? this.note,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (giorno.present) {
      map['giorno'] = Variable<DateTime>(giorno.value);
    }
    if (pesoKg.present) {
      map['peso_kg'] = Variable<double>(pesoKg.value);
    }
    if (massaGrassaPct.present) {
      map['massa_grassa_pct'] = Variable<double>(massaGrassaPct.value);
    }
    if (massaMagraKg.present) {
      map['massa_magra_kg'] = Variable<double>(massaMagraKg.value);
    }
    if (origine.present) {
      map['origine'] = Variable<String>(origine.value);
    }
    if (vitaCm.present) {
      map['vita_cm'] = Variable<double>(vitaCm.value);
    }
    if (toraceCm.present) {
      map['torace_cm'] = Variable<double>(toraceCm.value);
    }
    if (braccioCm.present) {
      map['braccio_cm'] = Variable<double>(braccioCm.value);
    }
    if (cosciaCm.present) {
      map['coscia_cm'] = Variable<double>(cosciaCm.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MisureCorpoCompanion(')
          ..write('id: $id, ')
          ..write('giorno: $giorno, ')
          ..write('pesoKg: $pesoKg, ')
          ..write('massaGrassaPct: $massaGrassaPct, ')
          ..write('massaMagraKg: $massaMagraKg, ')
          ..write('origine: $origine, ')
          ..write('vitaCm: $vitaCm, ')
          ..write('toraceCm: $toraceCm, ')
          ..write('braccioCm: $braccioCm, ')
          ..write('cosciaCm: $cosciaCm, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }
}

class $FotoProgressiTable extends FotoProgressi
    with TableInfo<$FotoProgressiTable, FotoProgresso> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FotoProgressiTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _percorsoMeta = const VerificationMeta(
    'percorso',
  );
  @override
  late final GeneratedColumn<String> percorso = GeneratedColumn<String>(
    'percorso',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scattataIlMeta = const VerificationMeta(
    'scattataIl',
  );
  @override
  late final GeneratedColumn<DateTime> scattataIl = GeneratedColumn<DateTime>(
    'scattata_il',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessioneIdMeta = const VerificationMeta(
    'sessioneId',
  );
  @override
  late final GeneratedColumn<int> sessioneId = GeneratedColumn<int>(
    'sessione_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _allenamentoOrologioIdMeta =
      const VerificationMeta('allenamentoOrologioId');
  @override
  late final GeneratedColumn<int> allenamentoOrologioId = GeneratedColumn<int>(
    'allenamento_orologio_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    percorso,
    scattataIl,
    sessioneId,
    allenamentoOrologioId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'foto_progressi';
  @override
  VerificationContext validateIntegrity(
    Insertable<FotoProgresso> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('percorso')) {
      context.handle(
        _percorsoMeta,
        percorso.isAcceptableOrUnknown(data['percorso']!, _percorsoMeta),
      );
    } else if (isInserting) {
      context.missing(_percorsoMeta);
    }
    if (data.containsKey('scattata_il')) {
      context.handle(
        _scattataIlMeta,
        scattataIl.isAcceptableOrUnknown(data['scattata_il']!, _scattataIlMeta),
      );
    } else if (isInserting) {
      context.missing(_scattataIlMeta);
    }
    if (data.containsKey('sessione_id')) {
      context.handle(
        _sessioneIdMeta,
        sessioneId.isAcceptableOrUnknown(data['sessione_id']!, _sessioneIdMeta),
      );
    }
    if (data.containsKey('allenamento_orologio_id')) {
      context.handle(
        _allenamentoOrologioIdMeta,
        allenamentoOrologioId.isAcceptableOrUnknown(
          data['allenamento_orologio_id']!,
          _allenamentoOrologioIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FotoProgresso map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FotoProgresso(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      percorso: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}percorso'],
      )!,
      scattataIl: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}scattata_il'],
      )!,
      sessioneId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sessione_id'],
      ),
      allenamentoOrologioId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}allenamento_orologio_id'],
      ),
    );
  }

  @override
  $FotoProgressiTable createAlias(String alias) {
    return $FotoProgressiTable(attachedDatabase, alias);
  }
}

class FotoProgresso extends DataClass implements Insertable<FotoProgresso> {
  final int id;

  /// Il percorso del file, relativo alla cartella dei documenti.
  ///
  /// 🚨 **Relativo, non assoluto.** Su iOS il contenitore dell'app cambia
  /// percorso a ogni aggiornamento: un percorso assoluto salvato oggi domani
  /// punta a niente, e la galleria si svuota da sola senza che nessuno abbia
  /// cancellato niente.
  final String percorso;
  final DateTime scattataIl;

  /// La sessione di allenamento a cui è legata, se è una foto di fine
  /// allenamento (era `type = 'workout'` sul server).
  final int? sessioneId;

  /// La foto di un allenamento visto **solo dall'orologio** — 3b-B.20.8.
  ///
  /// 📌 *«Anche nella schermata di allenamento con orologio devo poter
  /// aggiungere una foto»*.
  ///
  /// 🚨 **Una colonna nuova e non `sessioneId` con un id negativo.** Gli id
  /// firmati sono la convenzione che B.17.6 ha appena tolto dalle schede, e
  /// rimetterla qui vorrebbe dire ripagare lo stesso prezzo: una riga in cui il
  /// **segno** di un numero cambia a quale tabella punta è una riga che prima o
  /// poi qualcuno legge sbagliata, senza nessun errore.
  ///
  /// ⚠️ Le due colonne non sono mai piene insieme: una foto appartiene a una
  /// seduta **o** a un allenamento del polso. Ed entrambe possono essere vuote —
  /// è la foto di progressi che non sta su nessun allenamento.
  final int? allenamentoOrologioId;
  const FotoProgresso({
    required this.id,
    required this.percorso,
    required this.scattataIl,
    this.sessioneId,
    this.allenamentoOrologioId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['percorso'] = Variable<String>(percorso);
    map['scattata_il'] = Variable<DateTime>(scattataIl);
    if (!nullToAbsent || sessioneId != null) {
      map['sessione_id'] = Variable<int>(sessioneId);
    }
    if (!nullToAbsent || allenamentoOrologioId != null) {
      map['allenamento_orologio_id'] = Variable<int>(allenamentoOrologioId);
    }
    return map;
  }

  FotoProgressiCompanion toCompanion(bool nullToAbsent) {
    return FotoProgressiCompanion(
      id: Value(id),
      percorso: Value(percorso),
      scattataIl: Value(scattataIl),
      sessioneId: sessioneId == null && nullToAbsent
          ? const Value.absent()
          : Value(sessioneId),
      allenamentoOrologioId: allenamentoOrologioId == null && nullToAbsent
          ? const Value.absent()
          : Value(allenamentoOrologioId),
    );
  }

  factory FotoProgresso.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FotoProgresso(
      id: serializer.fromJson<int>(json['id']),
      percorso: serializer.fromJson<String>(json['percorso']),
      scattataIl: serializer.fromJson<DateTime>(json['scattataIl']),
      sessioneId: serializer.fromJson<int?>(json['sessioneId']),
      allenamentoOrologioId: serializer.fromJson<int?>(
        json['allenamentoOrologioId'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'percorso': serializer.toJson<String>(percorso),
      'scattataIl': serializer.toJson<DateTime>(scattataIl),
      'sessioneId': serializer.toJson<int?>(sessioneId),
      'allenamentoOrologioId': serializer.toJson<int?>(allenamentoOrologioId),
    };
  }

  FotoProgresso copyWith({
    int? id,
    String? percorso,
    DateTime? scattataIl,
    Value<int?> sessioneId = const Value.absent(),
    Value<int?> allenamentoOrologioId = const Value.absent(),
  }) => FotoProgresso(
    id: id ?? this.id,
    percorso: percorso ?? this.percorso,
    scattataIl: scattataIl ?? this.scattataIl,
    sessioneId: sessioneId.present ? sessioneId.value : this.sessioneId,
    allenamentoOrologioId: allenamentoOrologioId.present
        ? allenamentoOrologioId.value
        : this.allenamentoOrologioId,
  );
  FotoProgresso copyWithCompanion(FotoProgressiCompanion data) {
    return FotoProgresso(
      id: data.id.present ? data.id.value : this.id,
      percorso: data.percorso.present ? data.percorso.value : this.percorso,
      scattataIl: data.scattataIl.present
          ? data.scattataIl.value
          : this.scattataIl,
      sessioneId: data.sessioneId.present
          ? data.sessioneId.value
          : this.sessioneId,
      allenamentoOrologioId: data.allenamentoOrologioId.present
          ? data.allenamentoOrologioId.value
          : this.allenamentoOrologioId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FotoProgresso(')
          ..write('id: $id, ')
          ..write('percorso: $percorso, ')
          ..write('scattataIl: $scattataIl, ')
          ..write('sessioneId: $sessioneId, ')
          ..write('allenamentoOrologioId: $allenamentoOrologioId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, percorso, scattataIl, sessioneId, allenamentoOrologioId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FotoProgresso &&
          other.id == this.id &&
          other.percorso == this.percorso &&
          other.scattataIl == this.scattataIl &&
          other.sessioneId == this.sessioneId &&
          other.allenamentoOrologioId == this.allenamentoOrologioId);
}

class FotoProgressiCompanion extends UpdateCompanion<FotoProgresso> {
  final Value<int> id;
  final Value<String> percorso;
  final Value<DateTime> scattataIl;
  final Value<int?> sessioneId;
  final Value<int?> allenamentoOrologioId;
  const FotoProgressiCompanion({
    this.id = const Value.absent(),
    this.percorso = const Value.absent(),
    this.scattataIl = const Value.absent(),
    this.sessioneId = const Value.absent(),
    this.allenamentoOrologioId = const Value.absent(),
  });
  FotoProgressiCompanion.insert({
    this.id = const Value.absent(),
    required String percorso,
    required DateTime scattataIl,
    this.sessioneId = const Value.absent(),
    this.allenamentoOrologioId = const Value.absent(),
  }) : percorso = Value(percorso),
       scattataIl = Value(scattataIl);
  static Insertable<FotoProgresso> custom({
    Expression<int>? id,
    Expression<String>? percorso,
    Expression<DateTime>? scattataIl,
    Expression<int>? sessioneId,
    Expression<int>? allenamentoOrologioId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (percorso != null) 'percorso': percorso,
      if (scattataIl != null) 'scattata_il': scattataIl,
      if (sessioneId != null) 'sessione_id': sessioneId,
      if (allenamentoOrologioId != null)
        'allenamento_orologio_id': allenamentoOrologioId,
    });
  }

  FotoProgressiCompanion copyWith({
    Value<int>? id,
    Value<String>? percorso,
    Value<DateTime>? scattataIl,
    Value<int?>? sessioneId,
    Value<int?>? allenamentoOrologioId,
  }) {
    return FotoProgressiCompanion(
      id: id ?? this.id,
      percorso: percorso ?? this.percorso,
      scattataIl: scattataIl ?? this.scattataIl,
      sessioneId: sessioneId ?? this.sessioneId,
      allenamentoOrologioId:
          allenamentoOrologioId ?? this.allenamentoOrologioId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (percorso.present) {
      map['percorso'] = Variable<String>(percorso.value);
    }
    if (scattataIl.present) {
      map['scattata_il'] = Variable<DateTime>(scattataIl.value);
    }
    if (sessioneId.present) {
      map['sessione_id'] = Variable<int>(sessioneId.value);
    }
    if (allenamentoOrologioId.present) {
      map['allenamento_orologio_id'] = Variable<int>(
        allenamentoOrologioId.value,
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FotoProgressiCompanion(')
          ..write('id: $id, ')
          ..write('percorso: $percorso, ')
          ..write('scattataIl: $scattataIl, ')
          ..write('sessioneId: $sessioneId, ')
          ..write('allenamentoOrologioId: $allenamentoOrologioId')
          ..write(')'))
        .toString();
  }
}

class $PianiRicevutiTable extends PianiRicevuti
    with TableInfo<$PianiRicevutiTable, PianoRicevuto> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PianiRicevutiTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _messaggioIdMeta = const VerificationMeta(
    'messaggioId',
  );
  @override
  late final GeneratedColumn<int> messaggioId = GeneratedColumn<int>(
    'messaggio_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _mittenteIdMeta = const VerificationMeta(
    'mittenteId',
  );
  @override
  late final GeneratedColumn<int> mittenteId = GeneratedColumn<int>(
    'mittente_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _origineIdMeta = const VerificationMeta(
    'origineId',
  );
  @override
  late final GeneratedColumn<String> origineId = GeneratedColumn<String>(
    'origine_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nomeMeta = const VerificationMeta('nome');
  @override
  late final GeneratedColumn<String> nome = GeneratedColumn<String>(
    'nome',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pianoMeta = const VerificationMeta('piano');
  @override
  late final GeneratedColumn<String> piano = GeneratedColumn<String>(
    'piano',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ricevutaIlMeta = const VerificationMeta(
    'ricevutaIl',
  );
  @override
  late final GeneratedColumn<DateTime> ricevutaIl = GeneratedColumn<DateTime>(
    'ricevuta_il',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _aggiornatoIlMeta = const VerificationMeta(
    'aggiornatoIl',
  );
  @override
  late final GeneratedColumn<DateTime> aggiornatoIl = GeneratedColumn<DateTime>(
    'aggiornato_il',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pdfOriginaleMeta = const VerificationMeta(
    'pdfOriginale',
  );
  @override
  late final GeneratedColumn<String> pdfOriginale = GeneratedColumn<String>(
    'pdf_originale',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _importatoMeta = const VerificationMeta(
    'importato',
  );
  @override
  late final GeneratedColumn<bool> importato = GeneratedColumn<bool>(
    'importato',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("importato" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    messaggioId,
    mittenteId,
    origineId,
    nome,
    piano,
    ricevutaIl,
    aggiornatoIl,
    pdfOriginale,
    importato,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'piani_ricevuti';
  @override
  VerificationContext validateIntegrity(
    Insertable<PianoRicevuto> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('messaggio_id')) {
      context.handle(
        _messaggioIdMeta,
        messaggioId.isAcceptableOrUnknown(
          data['messaggio_id']!,
          _messaggioIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_messaggioIdMeta);
    }
    if (data.containsKey('mittente_id')) {
      context.handle(
        _mittenteIdMeta,
        mittenteId.isAcceptableOrUnknown(data['mittente_id']!, _mittenteIdMeta),
      );
    } else if (isInserting) {
      context.missing(_mittenteIdMeta);
    }
    if (data.containsKey('origine_id')) {
      context.handle(
        _origineIdMeta,
        origineId.isAcceptableOrUnknown(data['origine_id']!, _origineIdMeta),
      );
    }
    if (data.containsKey('nome')) {
      context.handle(
        _nomeMeta,
        nome.isAcceptableOrUnknown(data['nome']!, _nomeMeta),
      );
    } else if (isInserting) {
      context.missing(_nomeMeta);
    }
    if (data.containsKey('piano')) {
      context.handle(
        _pianoMeta,
        piano.isAcceptableOrUnknown(data['piano']!, _pianoMeta),
      );
    } else if (isInserting) {
      context.missing(_pianoMeta);
    }
    if (data.containsKey('ricevuta_il')) {
      context.handle(
        _ricevutaIlMeta,
        ricevutaIl.isAcceptableOrUnknown(data['ricevuta_il']!, _ricevutaIlMeta),
      );
    } else if (isInserting) {
      context.missing(_ricevutaIlMeta);
    }
    if (data.containsKey('aggiornato_il')) {
      context.handle(
        _aggiornatoIlMeta,
        aggiornatoIl.isAcceptableOrUnknown(
          data['aggiornato_il']!,
          _aggiornatoIlMeta,
        ),
      );
    }
    if (data.containsKey('pdf_originale')) {
      context.handle(
        _pdfOriginaleMeta,
        pdfOriginale.isAcceptableOrUnknown(
          data['pdf_originale']!,
          _pdfOriginaleMeta,
        ),
      );
    }
    if (data.containsKey('importato')) {
      context.handle(
        _importatoMeta,
        importato.isAcceptableOrUnknown(data['importato']!, _importatoMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PianoRicevuto map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PianoRicevuto(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      messaggioId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}messaggio_id'],
      )!,
      mittenteId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}mittente_id'],
      )!,
      origineId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origine_id'],
      ),
      nome: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nome'],
      )!,
      piano: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}piano'],
      )!,
      ricevutaIl: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ricevuta_il'],
      )!,
      aggiornatoIl: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}aggiornato_il'],
      ),
      pdfOriginale: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pdf_originale'],
      ),
      importato: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}importato'],
      )!,
    );
  }

  @override
  $PianiRicevutiTable createAlias(String alias) {
    return $PianiRicevutiTable(attachedDatabase, alias);
  }
}

class PianoRicevuto extends DataClass implements Insertable<PianoRicevuto> {
  final int id;
  final int messaggioId;
  final int mittenteId;

  /// 🚨 **L'identita' stabile del piano** — D15.
  ///
  /// E' cio' che permette di riconoscere che un piano arrivato e' la **versione
  /// nuova** di uno che c'e' gia', e di sostituirlo invece di affiancarlo.
  ///
  /// ⚠️ **Nullable**: le buste `v1` non ce l'hanno. Chi arriva senza cade sul
  /// comportamento vecchio — una riga per messaggio — che e' corretto, solo
  /// meno furbo.
  final String? origineId;
  final String nome;
  final String piano;

  /// 🚨 **La PRIMA volta che questo piano e' arrivato**, non l'ultima.
  ///
  /// Sostituendo una versione si conserva questa data: e' quella che l'allievo
  /// riconosce («quello di marzo»). Spostarla a ogni correzione del trainer
  /// gli farebbe sembrare nuovo un piano che segue da mesi.
  final DateTime ricevutaIl;

  /// Quando e' stato sostituito l'ultima volta. `null` = mai.
  final DateTime? aggiornatoIl;

  /// Il PDF originale da cui e' stato importato — N20.4.
  ///
  /// 🚨 **Percorso relativo dentro `Documents/foto/piani`**, cioe' dentro
  /// il backup. L'originale deve restare consultabile anche quando la riga sul
  /// server e' scaduta: senza, fra un mese non c'e' piu' niente con cui
  /// confrontare i numeri che si stanno seguendo.
  ///
  /// ⚠️ `null` per i piani arrivati via chat, che un originale non ce l'hanno.
  final String? pdfOriginale;

  /// L'ha importato la persona da un PDF, non l'ha mandato un trainer.
  ///
  /// 💡 Serve a **dirlo in faccia** nell'elenco: un piano importato lo ha
  /// trascritto un modello e riletto una persona, e chi lo guarda fra sei mesi
  /// deve sapere da dove viene.
  final bool importato;
  const PianoRicevuto({
    required this.id,
    required this.messaggioId,
    required this.mittenteId,
    this.origineId,
    required this.nome,
    required this.piano,
    required this.ricevutaIl,
    this.aggiornatoIl,
    this.pdfOriginale,
    required this.importato,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['messaggio_id'] = Variable<int>(messaggioId);
    map['mittente_id'] = Variable<int>(mittenteId);
    if (!nullToAbsent || origineId != null) {
      map['origine_id'] = Variable<String>(origineId);
    }
    map['nome'] = Variable<String>(nome);
    map['piano'] = Variable<String>(piano);
    map['ricevuta_il'] = Variable<DateTime>(ricevutaIl);
    if (!nullToAbsent || aggiornatoIl != null) {
      map['aggiornato_il'] = Variable<DateTime>(aggiornatoIl);
    }
    if (!nullToAbsent || pdfOriginale != null) {
      map['pdf_originale'] = Variable<String>(pdfOriginale);
    }
    map['importato'] = Variable<bool>(importato);
    return map;
  }

  PianiRicevutiCompanion toCompanion(bool nullToAbsent) {
    return PianiRicevutiCompanion(
      id: Value(id),
      messaggioId: Value(messaggioId),
      mittenteId: Value(mittenteId),
      origineId: origineId == null && nullToAbsent
          ? const Value.absent()
          : Value(origineId),
      nome: Value(nome),
      piano: Value(piano),
      ricevutaIl: Value(ricevutaIl),
      aggiornatoIl: aggiornatoIl == null && nullToAbsent
          ? const Value.absent()
          : Value(aggiornatoIl),
      pdfOriginale: pdfOriginale == null && nullToAbsent
          ? const Value.absent()
          : Value(pdfOriginale),
      importato: Value(importato),
    );
  }

  factory PianoRicevuto.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PianoRicevuto(
      id: serializer.fromJson<int>(json['id']),
      messaggioId: serializer.fromJson<int>(json['messaggioId']),
      mittenteId: serializer.fromJson<int>(json['mittenteId']),
      origineId: serializer.fromJson<String?>(json['origineId']),
      nome: serializer.fromJson<String>(json['nome']),
      piano: serializer.fromJson<String>(json['piano']),
      ricevutaIl: serializer.fromJson<DateTime>(json['ricevutaIl']),
      aggiornatoIl: serializer.fromJson<DateTime?>(json['aggiornatoIl']),
      pdfOriginale: serializer.fromJson<String?>(json['pdfOriginale']),
      importato: serializer.fromJson<bool>(json['importato']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'messaggioId': serializer.toJson<int>(messaggioId),
      'mittenteId': serializer.toJson<int>(mittenteId),
      'origineId': serializer.toJson<String?>(origineId),
      'nome': serializer.toJson<String>(nome),
      'piano': serializer.toJson<String>(piano),
      'ricevutaIl': serializer.toJson<DateTime>(ricevutaIl),
      'aggiornatoIl': serializer.toJson<DateTime?>(aggiornatoIl),
      'pdfOriginale': serializer.toJson<String?>(pdfOriginale),
      'importato': serializer.toJson<bool>(importato),
    };
  }

  PianoRicevuto copyWith({
    int? id,
    int? messaggioId,
    int? mittenteId,
    Value<String?> origineId = const Value.absent(),
    String? nome,
    String? piano,
    DateTime? ricevutaIl,
    Value<DateTime?> aggiornatoIl = const Value.absent(),
    Value<String?> pdfOriginale = const Value.absent(),
    bool? importato,
  }) => PianoRicevuto(
    id: id ?? this.id,
    messaggioId: messaggioId ?? this.messaggioId,
    mittenteId: mittenteId ?? this.mittenteId,
    origineId: origineId.present ? origineId.value : this.origineId,
    nome: nome ?? this.nome,
    piano: piano ?? this.piano,
    ricevutaIl: ricevutaIl ?? this.ricevutaIl,
    aggiornatoIl: aggiornatoIl.present ? aggiornatoIl.value : this.aggiornatoIl,
    pdfOriginale: pdfOriginale.present ? pdfOriginale.value : this.pdfOriginale,
    importato: importato ?? this.importato,
  );
  PianoRicevuto copyWithCompanion(PianiRicevutiCompanion data) {
    return PianoRicevuto(
      id: data.id.present ? data.id.value : this.id,
      messaggioId: data.messaggioId.present
          ? data.messaggioId.value
          : this.messaggioId,
      mittenteId: data.mittenteId.present
          ? data.mittenteId.value
          : this.mittenteId,
      origineId: data.origineId.present ? data.origineId.value : this.origineId,
      nome: data.nome.present ? data.nome.value : this.nome,
      piano: data.piano.present ? data.piano.value : this.piano,
      ricevutaIl: data.ricevutaIl.present
          ? data.ricevutaIl.value
          : this.ricevutaIl,
      aggiornatoIl: data.aggiornatoIl.present
          ? data.aggiornatoIl.value
          : this.aggiornatoIl,
      pdfOriginale: data.pdfOriginale.present
          ? data.pdfOriginale.value
          : this.pdfOriginale,
      importato: data.importato.present ? data.importato.value : this.importato,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PianoRicevuto(')
          ..write('id: $id, ')
          ..write('messaggioId: $messaggioId, ')
          ..write('mittenteId: $mittenteId, ')
          ..write('origineId: $origineId, ')
          ..write('nome: $nome, ')
          ..write('piano: $piano, ')
          ..write('ricevutaIl: $ricevutaIl, ')
          ..write('aggiornatoIl: $aggiornatoIl, ')
          ..write('pdfOriginale: $pdfOriginale, ')
          ..write('importato: $importato')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    messaggioId,
    mittenteId,
    origineId,
    nome,
    piano,
    ricevutaIl,
    aggiornatoIl,
    pdfOriginale,
    importato,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PianoRicevuto &&
          other.id == this.id &&
          other.messaggioId == this.messaggioId &&
          other.mittenteId == this.mittenteId &&
          other.origineId == this.origineId &&
          other.nome == this.nome &&
          other.piano == this.piano &&
          other.ricevutaIl == this.ricevutaIl &&
          other.aggiornatoIl == this.aggiornatoIl &&
          other.pdfOriginale == this.pdfOriginale &&
          other.importato == this.importato);
}

class PianiRicevutiCompanion extends UpdateCompanion<PianoRicevuto> {
  final Value<int> id;
  final Value<int> messaggioId;
  final Value<int> mittenteId;
  final Value<String?> origineId;
  final Value<String> nome;
  final Value<String> piano;
  final Value<DateTime> ricevutaIl;
  final Value<DateTime?> aggiornatoIl;
  final Value<String?> pdfOriginale;
  final Value<bool> importato;
  const PianiRicevutiCompanion({
    this.id = const Value.absent(),
    this.messaggioId = const Value.absent(),
    this.mittenteId = const Value.absent(),
    this.origineId = const Value.absent(),
    this.nome = const Value.absent(),
    this.piano = const Value.absent(),
    this.ricevutaIl = const Value.absent(),
    this.aggiornatoIl = const Value.absent(),
    this.pdfOriginale = const Value.absent(),
    this.importato = const Value.absent(),
  });
  PianiRicevutiCompanion.insert({
    this.id = const Value.absent(),
    required int messaggioId,
    required int mittenteId,
    this.origineId = const Value.absent(),
    required String nome,
    required String piano,
    required DateTime ricevutaIl,
    this.aggiornatoIl = const Value.absent(),
    this.pdfOriginale = const Value.absent(),
    this.importato = const Value.absent(),
  }) : messaggioId = Value(messaggioId),
       mittenteId = Value(mittenteId),
       nome = Value(nome),
       piano = Value(piano),
       ricevutaIl = Value(ricevutaIl);
  static Insertable<PianoRicevuto> custom({
    Expression<int>? id,
    Expression<int>? messaggioId,
    Expression<int>? mittenteId,
    Expression<String>? origineId,
    Expression<String>? nome,
    Expression<String>? piano,
    Expression<DateTime>? ricevutaIl,
    Expression<DateTime>? aggiornatoIl,
    Expression<String>? pdfOriginale,
    Expression<bool>? importato,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (messaggioId != null) 'messaggio_id': messaggioId,
      if (mittenteId != null) 'mittente_id': mittenteId,
      if (origineId != null) 'origine_id': origineId,
      if (nome != null) 'nome': nome,
      if (piano != null) 'piano': piano,
      if (ricevutaIl != null) 'ricevuta_il': ricevutaIl,
      if (aggiornatoIl != null) 'aggiornato_il': aggiornatoIl,
      if (pdfOriginale != null) 'pdf_originale': pdfOriginale,
      if (importato != null) 'importato': importato,
    });
  }

  PianiRicevutiCompanion copyWith({
    Value<int>? id,
    Value<int>? messaggioId,
    Value<int>? mittenteId,
    Value<String?>? origineId,
    Value<String>? nome,
    Value<String>? piano,
    Value<DateTime>? ricevutaIl,
    Value<DateTime?>? aggiornatoIl,
    Value<String?>? pdfOriginale,
    Value<bool>? importato,
  }) {
    return PianiRicevutiCompanion(
      id: id ?? this.id,
      messaggioId: messaggioId ?? this.messaggioId,
      mittenteId: mittenteId ?? this.mittenteId,
      origineId: origineId ?? this.origineId,
      nome: nome ?? this.nome,
      piano: piano ?? this.piano,
      ricevutaIl: ricevutaIl ?? this.ricevutaIl,
      aggiornatoIl: aggiornatoIl ?? this.aggiornatoIl,
      pdfOriginale: pdfOriginale ?? this.pdfOriginale,
      importato: importato ?? this.importato,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (messaggioId.present) {
      map['messaggio_id'] = Variable<int>(messaggioId.value);
    }
    if (mittenteId.present) {
      map['mittente_id'] = Variable<int>(mittenteId.value);
    }
    if (origineId.present) {
      map['origine_id'] = Variable<String>(origineId.value);
    }
    if (nome.present) {
      map['nome'] = Variable<String>(nome.value);
    }
    if (piano.present) {
      map['piano'] = Variable<String>(piano.value);
    }
    if (ricevutaIl.present) {
      map['ricevuta_il'] = Variable<DateTime>(ricevutaIl.value);
    }
    if (aggiornatoIl.present) {
      map['aggiornato_il'] = Variable<DateTime>(aggiornatoIl.value);
    }
    if (pdfOriginale.present) {
      map['pdf_originale'] = Variable<String>(pdfOriginale.value);
    }
    if (importato.present) {
      map['importato'] = Variable<bool>(importato.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PianiRicevutiCompanion(')
          ..write('id: $id, ')
          ..write('messaggioId: $messaggioId, ')
          ..write('mittenteId: $mittenteId, ')
          ..write('origineId: $origineId, ')
          ..write('nome: $nome, ')
          ..write('piano: $piano, ')
          ..write('ricevutaIl: $ricevutaIl, ')
          ..write('aggiornatoIl: $aggiornatoIl, ')
          ..write('pdfOriginale: $pdfOriginale, ')
          ..write('importato: $importato')
          ..write(')'))
        .toString();
  }
}

class $ContenutiRifiutatiTable extends ContenutiRifiutati
    with TableInfo<$ContenutiRifiutatiTable, ContenutoRifiutato> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ContenutiRifiutatiTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _origineIdMeta = const VerificationMeta(
    'origineId',
  );
  @override
  late final GeneratedColumn<String> origineId = GeneratedColumn<String>(
    'origine_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _rifiutatoIlMeta = const VerificationMeta(
    'rifiutatoIl',
  );
  @override
  late final GeneratedColumn<DateTime> rifiutatoIl = GeneratedColumn<DateTime>(
    'rifiutato_il',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, origineId, rifiutatoIl];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'contenuti_rifiutati';
  @override
  VerificationContext validateIntegrity(
    Insertable<ContenutoRifiutato> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('origine_id')) {
      context.handle(
        _origineIdMeta,
        origineId.isAcceptableOrUnknown(data['origine_id']!, _origineIdMeta),
      );
    } else if (isInserting) {
      context.missing(_origineIdMeta);
    }
    if (data.containsKey('rifiutato_il')) {
      context.handle(
        _rifiutatoIlMeta,
        rifiutatoIl.isAcceptableOrUnknown(
          data['rifiutato_il']!,
          _rifiutatoIlMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_rifiutatoIlMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ContenutoRifiutato map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ContenutoRifiutato(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      origineId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origine_id'],
      )!,
      rifiutatoIl: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}rifiutato_il'],
      )!,
    );
  }

  @override
  $ContenutiRifiutatiTable createAlias(String alias) {
    return $ContenutiRifiutatiTable(attachedDatabase, alias);
  }
}

class ContenutoRifiutato extends DataClass
    implements Insertable<ContenutoRifiutato> {
  final int id;

  /// L'`origine_id` del piano o della scheda rifiutata.
  final String origineId;
  final DateTime rifiutatoIl;
  const ContenutoRifiutato({
    required this.id,
    required this.origineId,
    required this.rifiutatoIl,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['origine_id'] = Variable<String>(origineId);
    map['rifiutato_il'] = Variable<DateTime>(rifiutatoIl);
    return map;
  }

  ContenutiRifiutatiCompanion toCompanion(bool nullToAbsent) {
    return ContenutiRifiutatiCompanion(
      id: Value(id),
      origineId: Value(origineId),
      rifiutatoIl: Value(rifiutatoIl),
    );
  }

  factory ContenutoRifiutato.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ContenutoRifiutato(
      id: serializer.fromJson<int>(json['id']),
      origineId: serializer.fromJson<String>(json['origineId']),
      rifiutatoIl: serializer.fromJson<DateTime>(json['rifiutatoIl']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'origineId': serializer.toJson<String>(origineId),
      'rifiutatoIl': serializer.toJson<DateTime>(rifiutatoIl),
    };
  }

  ContenutoRifiutato copyWith({
    int? id,
    String? origineId,
    DateTime? rifiutatoIl,
  }) => ContenutoRifiutato(
    id: id ?? this.id,
    origineId: origineId ?? this.origineId,
    rifiutatoIl: rifiutatoIl ?? this.rifiutatoIl,
  );
  ContenutoRifiutato copyWithCompanion(ContenutiRifiutatiCompanion data) {
    return ContenutoRifiutato(
      id: data.id.present ? data.id.value : this.id,
      origineId: data.origineId.present ? data.origineId.value : this.origineId,
      rifiutatoIl: data.rifiutatoIl.present
          ? data.rifiutatoIl.value
          : this.rifiutatoIl,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ContenutoRifiutato(')
          ..write('id: $id, ')
          ..write('origineId: $origineId, ')
          ..write('rifiutatoIl: $rifiutatoIl')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, origineId, rifiutatoIl);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContenutoRifiutato &&
          other.id == this.id &&
          other.origineId == this.origineId &&
          other.rifiutatoIl == this.rifiutatoIl);
}

class ContenutiRifiutatiCompanion extends UpdateCompanion<ContenutoRifiutato> {
  final Value<int> id;
  final Value<String> origineId;
  final Value<DateTime> rifiutatoIl;
  const ContenutiRifiutatiCompanion({
    this.id = const Value.absent(),
    this.origineId = const Value.absent(),
    this.rifiutatoIl = const Value.absent(),
  });
  ContenutiRifiutatiCompanion.insert({
    this.id = const Value.absent(),
    required String origineId,
    required DateTime rifiutatoIl,
  }) : origineId = Value(origineId),
       rifiutatoIl = Value(rifiutatoIl);
  static Insertable<ContenutoRifiutato> custom({
    Expression<int>? id,
    Expression<String>? origineId,
    Expression<DateTime>? rifiutatoIl,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (origineId != null) 'origine_id': origineId,
      if (rifiutatoIl != null) 'rifiutato_il': rifiutatoIl,
    });
  }

  ContenutiRifiutatiCompanion copyWith({
    Value<int>? id,
    Value<String>? origineId,
    Value<DateTime>? rifiutatoIl,
  }) {
    return ContenutiRifiutatiCompanion(
      id: id ?? this.id,
      origineId: origineId ?? this.origineId,
      rifiutatoIl: rifiutatoIl ?? this.rifiutatoIl,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (origineId.present) {
      map['origine_id'] = Variable<String>(origineId.value);
    }
    if (rifiutatoIl.present) {
      map['rifiutato_il'] = Variable<DateTime>(rifiutatoIl.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ContenutiRifiutatiCompanion(')
          ..write('id: $id, ')
          ..write('origineId: $origineId, ')
          ..write('rifiutatoIl: $rifiutatoIl')
          ..write(')'))
        .toString();
  }
}

class $AllenamentiDaOrologioTable extends AllenamentiDaOrologio
    with TableInfo<$AllenamentiDaOrologioTable, AllenamentoDaOrologio> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AllenamentiDaOrologioTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _fonteMeta = const VerificationMeta('fonte');
  @override
  late final GeneratedColumn<String> fonte = GeneratedColumn<String>(
    'fonte',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 64,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tipoMeta = const VerificationMeta('tipo');
  @override
  late final GeneratedColumn<String> tipo = GeneratedColumn<String>(
    'tipo',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 48,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _iniziatoIlMeta = const VerificationMeta(
    'iniziatoIl',
  );
  @override
  late final GeneratedColumn<DateTime> iniziatoIl = GeneratedColumn<DateTime>(
    'iniziato_il',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _finitoIlMeta = const VerificationMeta(
    'finitoIl',
  );
  @override
  late final GeneratedColumn<DateTime> finitoIl = GeneratedColumn<DateTime>(
    'finito_il',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kcalMeta = const VerificationMeta('kcal');
  @override
  late final GeneratedColumn<int> kcal = GeneratedColumn<int>(
    'kcal',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _distanzaMetriMeta = const VerificationMeta(
    'distanzaMetri',
  );
  @override
  late final GeneratedColumn<int> distanzaMetri = GeneratedColumn<int>(
    'distanza_metri',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _passiMeta = const VerificationMeta('passi');
  @override
  late final GeneratedColumn<int> passi = GeneratedColumn<int>(
    'passi',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _schedaAssegnataMeta = const VerificationMeta(
    'schedaAssegnata',
  );
  @override
  late final GeneratedColumn<int> schedaAssegnata = GeneratedColumn<int>(
    'scheda_assegnata',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tipoSceltoMeta = const VerificationMeta(
    'tipoScelto',
  );
  @override
  late final GeneratedColumn<String> tipoScelto = GeneratedColumn<String>(
    'tipo_scelto',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _kcalCorretteMeta = const VerificationMeta(
    'kcalCorrette',
  );
  @override
  late final GeneratedColumn<int> kcalCorrette = GeneratedColumn<int>(
    'kcal_corrette',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nascostoMeta = const VerificationMeta(
    'nascosto',
  );
  @override
  late final GeneratedColumn<bool> nascosto = GeneratedColumn<bool>(
    'nascosto',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("nascosto" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _staccatoMeta = const VerificationMeta(
    'staccato',
  );
  @override
  late final GeneratedColumn<bool> staccato = GeneratedColumn<bool>(
    'staccato',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("staccato" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _contaComeExtraMeta = const VerificationMeta(
    'contaComeExtra',
  );
  @override
  late final GeneratedColumn<bool> contaComeExtra = GeneratedColumn<bool>(
    'conta_come_extra',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("conta_come_extra" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    fonte,
    tipo,
    iniziatoIl,
    finitoIl,
    kcal,
    distanzaMetri,
    passi,
    schedaAssegnata,
    tipoScelto,
    kcalCorrette,
    nascosto,
    staccato,
    contaComeExtra,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'allenamenti_da_orologio';
  @override
  VerificationContext validateIntegrity(
    Insertable<AllenamentoDaOrologio> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('fonte')) {
      context.handle(
        _fonteMeta,
        fonte.isAcceptableOrUnknown(data['fonte']!, _fonteMeta),
      );
    } else if (isInserting) {
      context.missing(_fonteMeta);
    }
    if (data.containsKey('tipo')) {
      context.handle(
        _tipoMeta,
        tipo.isAcceptableOrUnknown(data['tipo']!, _tipoMeta),
      );
    } else if (isInserting) {
      context.missing(_tipoMeta);
    }
    if (data.containsKey('iniziato_il')) {
      context.handle(
        _iniziatoIlMeta,
        iniziatoIl.isAcceptableOrUnknown(data['iniziato_il']!, _iniziatoIlMeta),
      );
    } else if (isInserting) {
      context.missing(_iniziatoIlMeta);
    }
    if (data.containsKey('finito_il')) {
      context.handle(
        _finitoIlMeta,
        finitoIl.isAcceptableOrUnknown(data['finito_il']!, _finitoIlMeta),
      );
    } else if (isInserting) {
      context.missing(_finitoIlMeta);
    }
    if (data.containsKey('kcal')) {
      context.handle(
        _kcalMeta,
        kcal.isAcceptableOrUnknown(data['kcal']!, _kcalMeta),
      );
    }
    if (data.containsKey('distanza_metri')) {
      context.handle(
        _distanzaMetriMeta,
        distanzaMetri.isAcceptableOrUnknown(
          data['distanza_metri']!,
          _distanzaMetriMeta,
        ),
      );
    }
    if (data.containsKey('passi')) {
      context.handle(
        _passiMeta,
        passi.isAcceptableOrUnknown(data['passi']!, _passiMeta),
      );
    }
    if (data.containsKey('scheda_assegnata')) {
      context.handle(
        _schedaAssegnataMeta,
        schedaAssegnata.isAcceptableOrUnknown(
          data['scheda_assegnata']!,
          _schedaAssegnataMeta,
        ),
      );
    }
    if (data.containsKey('tipo_scelto')) {
      context.handle(
        _tipoSceltoMeta,
        tipoScelto.isAcceptableOrUnknown(data['tipo_scelto']!, _tipoSceltoMeta),
      );
    }
    if (data.containsKey('kcal_corrette')) {
      context.handle(
        _kcalCorretteMeta,
        kcalCorrette.isAcceptableOrUnknown(
          data['kcal_corrette']!,
          _kcalCorretteMeta,
        ),
      );
    }
    if (data.containsKey('nascosto')) {
      context.handle(
        _nascostoMeta,
        nascosto.isAcceptableOrUnknown(data['nascosto']!, _nascostoMeta),
      );
    }
    if (data.containsKey('staccato')) {
      context.handle(
        _staccatoMeta,
        staccato.isAcceptableOrUnknown(data['staccato']!, _staccatoMeta),
      );
    }
    if (data.containsKey('conta_come_extra')) {
      context.handle(
        _contaComeExtraMeta,
        contaComeExtra.isAcceptableOrUnknown(
          data['conta_come_extra']!,
          _contaComeExtraMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {fonte, iniziatoIl},
  ];
  @override
  AllenamentoDaOrologio map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AllenamentoDaOrologio(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      fonte: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fonte'],
      )!,
      tipo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tipo'],
      )!,
      iniziatoIl: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}iniziato_il'],
      )!,
      finitoIl: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}finito_il'],
      )!,
      kcal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}kcal'],
      ),
      distanzaMetri: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}distanza_metri'],
      ),
      passi: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}passi'],
      ),
      schedaAssegnata: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}scheda_assegnata'],
      ),
      tipoScelto: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tipo_scelto'],
      ),
      kcalCorrette: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}kcal_corrette'],
      ),
      nascosto: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}nascosto'],
      )!,
      staccato: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}staccato'],
      )!,
      contaComeExtra: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}conta_come_extra'],
      )!,
    );
  }

  @override
  $AllenamentiDaOrologioTable createAlias(String alias) {
    return $AllenamentiDaOrologioTable(attachedDatabase, alias);
  }
}

class AllenamentoDaOrologio extends DataClass
    implements Insertable<AllenamentoDaOrologio> {
  final int id;

  /// Il pacchetto dell'app che l'ha scritto in Health Connect.
  final String fonte;

  /// Il codice originale del tipo: `RUNNING`, `STRENGTH_TRAINING`, `BIKING`.
  ///
  /// 🚨 **Si salva il codice, non la traduzione.** Le etichette italiane vivono
  /// in `TipoAllenamento` e possono cambiare; il codice no. ⚠️ Salvando «Pesi»
  /// perderemmo la differenza fra `STRENGTH_TRAINING` e `WEIGHTLIFTING`, e
  /// nessuna correzione futura potrebbe recuperarla.
  final String tipo;
  final DateTime iniziatoIl;
  final DateTime finitoIl;

  /// Le calorie **attive** bruciate durante la sessione.
  ///
  /// ══ 🚨 ATTIVE, non totali — corretto il 20/08 ═══════════════════════════
  ///
  /// Prima venivano da `WorkoutHealthValue.totalEnergyBurned`, cioè da
  /// `TotalCaloriesBurnedRecord`, che comprende il **metabolismo basale**.
  /// ⚠️ Il committente se n'è accorto in un minuto: l'app dell'orologio diceva
  /// **680 kcal** per quella seduta, la nostra ne mostrava **835**.
  ///
  /// 💡 Adesso si sommano i campioni di `ACTIVE_ENERGY_BURNED` che cadono nella
  /// finestra dell'allenamento — vedi `PonteSalute._attiveDentro`. Non è solo
  /// più corretto: è **la stessa fonte** delle calorie della giornata, quindi
  /// due schermate dell'app non possono più dire numeri diversi sulla stessa
  /// ora.
  ///
  /// 🚨 **`null` quando non si sa**, e non uno zero: nessun ripiego su
  /// `totalEnergyBurned`, che rimetterebbe dentro il basale di nascosto.
  ///
  /// ⚠️ **Non si sommano comunque al totale del giorno.** Quello si calcola già
  /// dagli stessi campioni: sommare anche queste li conterebbe due volte.
  final int? kcal;

  /// Metri percorsi, quando ha senso: una corsa sì, i pesi quasi no.
  final int? distanzaMetri;
  final int? passi;

  /// La scheda che questa persona dice di aver fatto — richiesta del 19/08:
  /// *«devo poter scegliere di assegnarvi una mia scheda»*.
  ///
  /// 💡 È l'`id` locale in `SchedeSulTelefono` — quello di **qui**, non quello
  /// del server. `null` vuol dire «non l'ho assegnata», che è lo stato normale:
  /// la maggior parte delle corse non corrisponde a nessuna scheda.
  ///
  /// ⚠️ **È il motivo per cui la migrazione v14 → v15 non rinumera gli id.**
  /// Rinumerarli avrebbe spostato in silenzio gli allenamenti già fatti su
  /// schede diverse da quelle vere.
  ///
  /// 🚨 **Una risincronizzazione non la cancella**: `scriviAllenamenti()` usa
  /// `insertOrIgnore`, quindi una riga già presente non viene riscritta. ⚠️ Con
  /// `insertOrReplace` l'orologio sovrascriverebbe una scelta della persona
  /// ogni volta che si rileggono gli ultimi sette giorni — cioè a ogni avvio.
  final int? schedaAssegnata;

  /// Il tipo che **hai dichiarato tu**, quando quello dell'orologio non va —
  /// 3b-B.20.5, 25/08/2026.
  ///
  /// 📌 *«voglio poterci assegnare anche un tipo di allenamento diverso dalla
  /// scheda. Tipo corsa, bicicletta, nuoto, ste cose qui, in modo che possa
  /// stimare i muscoli coinvolti e le calorie»*.
  ///
  /// 🚨 **È una colonna diversa da `tipo`, e la differenza è tutto.** `tipo` lo
  /// scrive l'orologio; questa la scrive una persona. ⛔ Sovrascrivere `tipo`
  /// avrebbe cancellato quello che il sensore ha visto per mettercelo dentro un
  /// parere — e alla prima risincronizzazione i due si sarebbero contesi la
  /// stessa casella.
  ///
  /// 💡 È la **gemella di `schedaAssegnata`**, e per la stessa ragione:
  /// `scriviAllenamenti()` usa `insertOrIgnore`, quindi una riga già presente
  /// non viene riscritta e la scelta sopravvive a ogni lettura degli ultimi
  /// sette giorni. ⚠️ Con `insertOrReplace` l'orologio la cancellerebbe a ogni
  /// avvio.
  ///
  /// ⚠️ Vale un codice di `TipoScelto`, non un testo libero: `null` vuol dire
  /// «non l'ho dichiarato», e allora vale quello dell'orologio.
  final String? tipoScelto;

  /// Le calorie **corrette a mano** per questo allenamento — 3b-C.4.
  ///
  /// 📌 *«deve essere IDENTICA»*: sulla pagina di una seduta dell'app le calorie
  /// si possono correggere da sempre, e senza questa colonna la pagina di un
  /// allenamento del polso avrebbe avuto lo stesso riquadro con dentro un numero
  /// che non si tocca. ⛔ Una card identica che non fa la stessa cosa è peggio di
  /// una card diversa: promette e non mantiene.
  ///
  /// 🚨 **Accanto a `kcal`, non al suo posto**: quello lo ha misurato
  /// l'orologio. È la stessa forma di `tipoScelto` accanto a `tipo`, e per la
  /// stessa ragione — `insertOrIgnore` fa sì che la correzione sopravviva a ogni
  /// risincronizzazione.
  final int? kcalCorrette;

  /// Nascosto dallo storico perché è il doppione di una seduta del player.
  ///
  /// ⚠️ Chi si allena in palestra **con l'app aperta e l'orologio al polso**
  /// produce due registrazioni della stessa ora. Non si cancella quella
  /// dell'orologio — è un dato vero, e cancellarlo renderebbe la scelta
  /// irreversibile — si smette di mostrarla.
  final bool nascosto;

  /// «Questo non si unisce a nessuno» — FASE 1-bis.
  ///
  /// ── 🚨 È la contropartita della regola larga ──────────────────────────────
  ///
  /// Dal 20/08 basta **un istante** di sovrapposizione perché due registrazioni
  /// siano lo stesso allenamento (decisione D-1bis/A). ⚠️ Una regola così larga
  /// prima o poi unisce due cose diverse — i pesi finiti alle 18:01 e la corsa
  /// cominciata alle 18:00 — e senza un modo di dire «no, sono due» quell'errore
  /// farebbe **sparire** un allenamento vero dallo storico.
  ///
  /// 💡 Il committente l'ha messa esattamente così: *«se i timeframes si
  /// sovrappongono allora è lo stesso allenamento. Poi ci mettiamo la
  /// possibilità di splittarli e via»*.
  ///
  /// ── ⚠️ Perché NON si riusa `nascosto` ─────────────────────────────────────
  ///
  /// Sono due gesti opposti. Chi nasconde vuole vedere **una riga in meno**; chi
  /// stacca vuole vederne **una in più**. Riusare la stessa colonna vorrebbe
  /// dire che l'unico modo di correggere un raggruppamento sbagliato è far
  /// sparire uno dei due allenamenti — cioè il difetto che si stava correggendo.
  final bool staccato;

  /// «Questo è stato fuori dal solito» — 3b-G.7, 26/08/2026.
  ///
  /// ══ 📌 A COSA SERVE, E SOLO IN UN MODELLO ══════════════════════════════
  ///
  /// Chi ha scelto il modello **«stima»** ha un fattore di attività che gli
  /// allenamenti li contiene già, quindi registrarli non alza l'obiettivo — ed è
  /// giusto, o li conterebbe due volte. ⚠️ Ma la frase con cui il committente ha
  /// descritto quel modello era *«registrerò solo gli allenamenti
  /// eccezionali»*: la mezza maratona di domenica **non** sta dentro «3-4
  /// allenamenti a settimana».
  ///
  /// 💡 Questa spunta è quel «eccezionale»: nel modello a stima **solo** le
  /// sedute marcate entrano nell'obiettivo.
  ///
  /// ⛔ **Spenta di serie, e non è pigrizia**: accesa di serie rimetterebbe
  /// dentro tutti gli allenamenti, cioè il doppio conteggio da cui veniamo.
  ///
  /// ⚠️ **Nel modello «misurata» non fa niente**, perché lì entra già tutto.
  final bool contaComeExtra;
  const AllenamentoDaOrologio({
    required this.id,
    required this.fonte,
    required this.tipo,
    required this.iniziatoIl,
    required this.finitoIl,
    this.kcal,
    this.distanzaMetri,
    this.passi,
    this.schedaAssegnata,
    this.tipoScelto,
    this.kcalCorrette,
    required this.nascosto,
    required this.staccato,
    required this.contaComeExtra,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['fonte'] = Variable<String>(fonte);
    map['tipo'] = Variable<String>(tipo);
    map['iniziato_il'] = Variable<DateTime>(iniziatoIl);
    map['finito_il'] = Variable<DateTime>(finitoIl);
    if (!nullToAbsent || kcal != null) {
      map['kcal'] = Variable<int>(kcal);
    }
    if (!nullToAbsent || distanzaMetri != null) {
      map['distanza_metri'] = Variable<int>(distanzaMetri);
    }
    if (!nullToAbsent || passi != null) {
      map['passi'] = Variable<int>(passi);
    }
    if (!nullToAbsent || schedaAssegnata != null) {
      map['scheda_assegnata'] = Variable<int>(schedaAssegnata);
    }
    if (!nullToAbsent || tipoScelto != null) {
      map['tipo_scelto'] = Variable<String>(tipoScelto);
    }
    if (!nullToAbsent || kcalCorrette != null) {
      map['kcal_corrette'] = Variable<int>(kcalCorrette);
    }
    map['nascosto'] = Variable<bool>(nascosto);
    map['staccato'] = Variable<bool>(staccato);
    map['conta_come_extra'] = Variable<bool>(contaComeExtra);
    return map;
  }

  AllenamentiDaOrologioCompanion toCompanion(bool nullToAbsent) {
    return AllenamentiDaOrologioCompanion(
      id: Value(id),
      fonte: Value(fonte),
      tipo: Value(tipo),
      iniziatoIl: Value(iniziatoIl),
      finitoIl: Value(finitoIl),
      kcal: kcal == null && nullToAbsent ? const Value.absent() : Value(kcal),
      distanzaMetri: distanzaMetri == null && nullToAbsent
          ? const Value.absent()
          : Value(distanzaMetri),
      passi: passi == null && nullToAbsent
          ? const Value.absent()
          : Value(passi),
      schedaAssegnata: schedaAssegnata == null && nullToAbsent
          ? const Value.absent()
          : Value(schedaAssegnata),
      tipoScelto: tipoScelto == null && nullToAbsent
          ? const Value.absent()
          : Value(tipoScelto),
      kcalCorrette: kcalCorrette == null && nullToAbsent
          ? const Value.absent()
          : Value(kcalCorrette),
      nascosto: Value(nascosto),
      staccato: Value(staccato),
      contaComeExtra: Value(contaComeExtra),
    );
  }

  factory AllenamentoDaOrologio.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AllenamentoDaOrologio(
      id: serializer.fromJson<int>(json['id']),
      fonte: serializer.fromJson<String>(json['fonte']),
      tipo: serializer.fromJson<String>(json['tipo']),
      iniziatoIl: serializer.fromJson<DateTime>(json['iniziatoIl']),
      finitoIl: serializer.fromJson<DateTime>(json['finitoIl']),
      kcal: serializer.fromJson<int?>(json['kcal']),
      distanzaMetri: serializer.fromJson<int?>(json['distanzaMetri']),
      passi: serializer.fromJson<int?>(json['passi']),
      schedaAssegnata: serializer.fromJson<int?>(json['schedaAssegnata']),
      tipoScelto: serializer.fromJson<String?>(json['tipoScelto']),
      kcalCorrette: serializer.fromJson<int?>(json['kcalCorrette']),
      nascosto: serializer.fromJson<bool>(json['nascosto']),
      staccato: serializer.fromJson<bool>(json['staccato']),
      contaComeExtra: serializer.fromJson<bool>(json['contaComeExtra']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'fonte': serializer.toJson<String>(fonte),
      'tipo': serializer.toJson<String>(tipo),
      'iniziatoIl': serializer.toJson<DateTime>(iniziatoIl),
      'finitoIl': serializer.toJson<DateTime>(finitoIl),
      'kcal': serializer.toJson<int?>(kcal),
      'distanzaMetri': serializer.toJson<int?>(distanzaMetri),
      'passi': serializer.toJson<int?>(passi),
      'schedaAssegnata': serializer.toJson<int?>(schedaAssegnata),
      'tipoScelto': serializer.toJson<String?>(tipoScelto),
      'kcalCorrette': serializer.toJson<int?>(kcalCorrette),
      'nascosto': serializer.toJson<bool>(nascosto),
      'staccato': serializer.toJson<bool>(staccato),
      'contaComeExtra': serializer.toJson<bool>(contaComeExtra),
    };
  }

  AllenamentoDaOrologio copyWith({
    int? id,
    String? fonte,
    String? tipo,
    DateTime? iniziatoIl,
    DateTime? finitoIl,
    Value<int?> kcal = const Value.absent(),
    Value<int?> distanzaMetri = const Value.absent(),
    Value<int?> passi = const Value.absent(),
    Value<int?> schedaAssegnata = const Value.absent(),
    Value<String?> tipoScelto = const Value.absent(),
    Value<int?> kcalCorrette = const Value.absent(),
    bool? nascosto,
    bool? staccato,
    bool? contaComeExtra,
  }) => AllenamentoDaOrologio(
    id: id ?? this.id,
    fonte: fonte ?? this.fonte,
    tipo: tipo ?? this.tipo,
    iniziatoIl: iniziatoIl ?? this.iniziatoIl,
    finitoIl: finitoIl ?? this.finitoIl,
    kcal: kcal.present ? kcal.value : this.kcal,
    distanzaMetri: distanzaMetri.present
        ? distanzaMetri.value
        : this.distanzaMetri,
    passi: passi.present ? passi.value : this.passi,
    schedaAssegnata: schedaAssegnata.present
        ? schedaAssegnata.value
        : this.schedaAssegnata,
    tipoScelto: tipoScelto.present ? tipoScelto.value : this.tipoScelto,
    kcalCorrette: kcalCorrette.present ? kcalCorrette.value : this.kcalCorrette,
    nascosto: nascosto ?? this.nascosto,
    staccato: staccato ?? this.staccato,
    contaComeExtra: contaComeExtra ?? this.contaComeExtra,
  );
  AllenamentoDaOrologio copyWithCompanion(AllenamentiDaOrologioCompanion data) {
    return AllenamentoDaOrologio(
      id: data.id.present ? data.id.value : this.id,
      fonte: data.fonte.present ? data.fonte.value : this.fonte,
      tipo: data.tipo.present ? data.tipo.value : this.tipo,
      iniziatoIl: data.iniziatoIl.present
          ? data.iniziatoIl.value
          : this.iniziatoIl,
      finitoIl: data.finitoIl.present ? data.finitoIl.value : this.finitoIl,
      kcal: data.kcal.present ? data.kcal.value : this.kcal,
      distanzaMetri: data.distanzaMetri.present
          ? data.distanzaMetri.value
          : this.distanzaMetri,
      passi: data.passi.present ? data.passi.value : this.passi,
      schedaAssegnata: data.schedaAssegnata.present
          ? data.schedaAssegnata.value
          : this.schedaAssegnata,
      tipoScelto: data.tipoScelto.present
          ? data.tipoScelto.value
          : this.tipoScelto,
      kcalCorrette: data.kcalCorrette.present
          ? data.kcalCorrette.value
          : this.kcalCorrette,
      nascosto: data.nascosto.present ? data.nascosto.value : this.nascosto,
      staccato: data.staccato.present ? data.staccato.value : this.staccato,
      contaComeExtra: data.contaComeExtra.present
          ? data.contaComeExtra.value
          : this.contaComeExtra,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AllenamentoDaOrologio(')
          ..write('id: $id, ')
          ..write('fonte: $fonte, ')
          ..write('tipo: $tipo, ')
          ..write('iniziatoIl: $iniziatoIl, ')
          ..write('finitoIl: $finitoIl, ')
          ..write('kcal: $kcal, ')
          ..write('distanzaMetri: $distanzaMetri, ')
          ..write('passi: $passi, ')
          ..write('schedaAssegnata: $schedaAssegnata, ')
          ..write('tipoScelto: $tipoScelto, ')
          ..write('kcalCorrette: $kcalCorrette, ')
          ..write('nascosto: $nascosto, ')
          ..write('staccato: $staccato, ')
          ..write('contaComeExtra: $contaComeExtra')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    fonte,
    tipo,
    iniziatoIl,
    finitoIl,
    kcal,
    distanzaMetri,
    passi,
    schedaAssegnata,
    tipoScelto,
    kcalCorrette,
    nascosto,
    staccato,
    contaComeExtra,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AllenamentoDaOrologio &&
          other.id == this.id &&
          other.fonte == this.fonte &&
          other.tipo == this.tipo &&
          other.iniziatoIl == this.iniziatoIl &&
          other.finitoIl == this.finitoIl &&
          other.kcal == this.kcal &&
          other.distanzaMetri == this.distanzaMetri &&
          other.passi == this.passi &&
          other.schedaAssegnata == this.schedaAssegnata &&
          other.tipoScelto == this.tipoScelto &&
          other.kcalCorrette == this.kcalCorrette &&
          other.nascosto == this.nascosto &&
          other.staccato == this.staccato &&
          other.contaComeExtra == this.contaComeExtra);
}

class AllenamentiDaOrologioCompanion
    extends UpdateCompanion<AllenamentoDaOrologio> {
  final Value<int> id;
  final Value<String> fonte;
  final Value<String> tipo;
  final Value<DateTime> iniziatoIl;
  final Value<DateTime> finitoIl;
  final Value<int?> kcal;
  final Value<int?> distanzaMetri;
  final Value<int?> passi;
  final Value<int?> schedaAssegnata;
  final Value<String?> tipoScelto;
  final Value<int?> kcalCorrette;
  final Value<bool> nascosto;
  final Value<bool> staccato;
  final Value<bool> contaComeExtra;
  const AllenamentiDaOrologioCompanion({
    this.id = const Value.absent(),
    this.fonte = const Value.absent(),
    this.tipo = const Value.absent(),
    this.iniziatoIl = const Value.absent(),
    this.finitoIl = const Value.absent(),
    this.kcal = const Value.absent(),
    this.distanzaMetri = const Value.absent(),
    this.passi = const Value.absent(),
    this.schedaAssegnata = const Value.absent(),
    this.tipoScelto = const Value.absent(),
    this.kcalCorrette = const Value.absent(),
    this.nascosto = const Value.absent(),
    this.staccato = const Value.absent(),
    this.contaComeExtra = const Value.absent(),
  });
  AllenamentiDaOrologioCompanion.insert({
    this.id = const Value.absent(),
    required String fonte,
    required String tipo,
    required DateTime iniziatoIl,
    required DateTime finitoIl,
    this.kcal = const Value.absent(),
    this.distanzaMetri = const Value.absent(),
    this.passi = const Value.absent(),
    this.schedaAssegnata = const Value.absent(),
    this.tipoScelto = const Value.absent(),
    this.kcalCorrette = const Value.absent(),
    this.nascosto = const Value.absent(),
    this.staccato = const Value.absent(),
    this.contaComeExtra = const Value.absent(),
  }) : fonte = Value(fonte),
       tipo = Value(tipo),
       iniziatoIl = Value(iniziatoIl),
       finitoIl = Value(finitoIl);
  static Insertable<AllenamentoDaOrologio> custom({
    Expression<int>? id,
    Expression<String>? fonte,
    Expression<String>? tipo,
    Expression<DateTime>? iniziatoIl,
    Expression<DateTime>? finitoIl,
    Expression<int>? kcal,
    Expression<int>? distanzaMetri,
    Expression<int>? passi,
    Expression<int>? schedaAssegnata,
    Expression<String>? tipoScelto,
    Expression<int>? kcalCorrette,
    Expression<bool>? nascosto,
    Expression<bool>? staccato,
    Expression<bool>? contaComeExtra,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (fonte != null) 'fonte': fonte,
      if (tipo != null) 'tipo': tipo,
      if (iniziatoIl != null) 'iniziato_il': iniziatoIl,
      if (finitoIl != null) 'finito_il': finitoIl,
      if (kcal != null) 'kcal': kcal,
      if (distanzaMetri != null) 'distanza_metri': distanzaMetri,
      if (passi != null) 'passi': passi,
      if (schedaAssegnata != null) 'scheda_assegnata': schedaAssegnata,
      if (tipoScelto != null) 'tipo_scelto': tipoScelto,
      if (kcalCorrette != null) 'kcal_corrette': kcalCorrette,
      if (nascosto != null) 'nascosto': nascosto,
      if (staccato != null) 'staccato': staccato,
      if (contaComeExtra != null) 'conta_come_extra': contaComeExtra,
    });
  }

  AllenamentiDaOrologioCompanion copyWith({
    Value<int>? id,
    Value<String>? fonte,
    Value<String>? tipo,
    Value<DateTime>? iniziatoIl,
    Value<DateTime>? finitoIl,
    Value<int?>? kcal,
    Value<int?>? distanzaMetri,
    Value<int?>? passi,
    Value<int?>? schedaAssegnata,
    Value<String?>? tipoScelto,
    Value<int?>? kcalCorrette,
    Value<bool>? nascosto,
    Value<bool>? staccato,
    Value<bool>? contaComeExtra,
  }) {
    return AllenamentiDaOrologioCompanion(
      id: id ?? this.id,
      fonte: fonte ?? this.fonte,
      tipo: tipo ?? this.tipo,
      iniziatoIl: iniziatoIl ?? this.iniziatoIl,
      finitoIl: finitoIl ?? this.finitoIl,
      kcal: kcal ?? this.kcal,
      distanzaMetri: distanzaMetri ?? this.distanzaMetri,
      passi: passi ?? this.passi,
      schedaAssegnata: schedaAssegnata ?? this.schedaAssegnata,
      tipoScelto: tipoScelto ?? this.tipoScelto,
      kcalCorrette: kcalCorrette ?? this.kcalCorrette,
      nascosto: nascosto ?? this.nascosto,
      staccato: staccato ?? this.staccato,
      contaComeExtra: contaComeExtra ?? this.contaComeExtra,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (fonte.present) {
      map['fonte'] = Variable<String>(fonte.value);
    }
    if (tipo.present) {
      map['tipo'] = Variable<String>(tipo.value);
    }
    if (iniziatoIl.present) {
      map['iniziato_il'] = Variable<DateTime>(iniziatoIl.value);
    }
    if (finitoIl.present) {
      map['finito_il'] = Variable<DateTime>(finitoIl.value);
    }
    if (kcal.present) {
      map['kcal'] = Variable<int>(kcal.value);
    }
    if (distanzaMetri.present) {
      map['distanza_metri'] = Variable<int>(distanzaMetri.value);
    }
    if (passi.present) {
      map['passi'] = Variable<int>(passi.value);
    }
    if (schedaAssegnata.present) {
      map['scheda_assegnata'] = Variable<int>(schedaAssegnata.value);
    }
    if (tipoScelto.present) {
      map['tipo_scelto'] = Variable<String>(tipoScelto.value);
    }
    if (kcalCorrette.present) {
      map['kcal_corrette'] = Variable<int>(kcalCorrette.value);
    }
    if (nascosto.present) {
      map['nascosto'] = Variable<bool>(nascosto.value);
    }
    if (staccato.present) {
      map['staccato'] = Variable<bool>(staccato.value);
    }
    if (contaComeExtra.present) {
      map['conta_come_extra'] = Variable<bool>(contaComeExtra.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AllenamentiDaOrologioCompanion(')
          ..write('id: $id, ')
          ..write('fonte: $fonte, ')
          ..write('tipo: $tipo, ')
          ..write('iniziatoIl: $iniziatoIl, ')
          ..write('finitoIl: $finitoIl, ')
          ..write('kcal: $kcal, ')
          ..write('distanzaMetri: $distanzaMetri, ')
          ..write('passi: $passi, ')
          ..write('schedaAssegnata: $schedaAssegnata, ')
          ..write('tipoScelto: $tipoScelto, ')
          ..write('kcalCorrette: $kcalCorrette, ')
          ..write('nascosto: $nascosto, ')
          ..write('staccato: $staccato, ')
          ..write('contaComeExtra: $contaComeExtra')
          ..write(')'))
        .toString();
  }
}

class $SeduteAllenamentoTable extends SeduteAllenamento
    with TableInfo<$SeduteAllenamentoTable, SedutaAllenamento> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SeduteAllenamentoTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _contaComeExtraMeta = const VerificationMeta(
    'contaComeExtra',
  );
  @override
  late final GeneratedColumn<bool> contaComeExtra = GeneratedColumn<bool>(
    'conta_come_extra',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("conta_come_extra" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _idServerMeta = const VerificationMeta(
    'idServer',
  );
  @override
  late final GeneratedColumn<int> idServer = GeneratedColumn<int>(
    'id_server',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _schedaServerIdMeta = const VerificationMeta(
    'schedaServerId',
  );
  @override
  late final GeneratedColumn<int> schedaServerId = GeneratedColumn<int>(
    'scheda_server_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nomeSchedaMeta = const VerificationMeta(
    'nomeScheda',
  );
  @override
  late final GeneratedColumn<String> nomeScheda = GeneratedColumn<String>(
    'nome_scheda',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _iniziataIlMeta = const VerificationMeta(
    'iniziataIl',
  );
  @override
  late final GeneratedColumn<DateTime> iniziataIl = GeneratedColumn<DateTime>(
    'iniziata_il',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _finitaIlMeta = const VerificationMeta(
    'finitaIl',
  );
  @override
  late final GeneratedColumn<DateTime> finitaIl = GeneratedColumn<DateTime>(
    'finita_il',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _kcalMeta = const VerificationMeta('kcal');
  @override
  late final GeneratedColumn<int> kcal = GeneratedColumn<int>(
    'kcal',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _kcalAManoMeta = const VerificationMeta(
    'kcalAMano',
  );
  @override
  late final GeneratedColumn<bool> kcalAMano = GeneratedColumn<bool>(
    'kcal_a_mano',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("kcal_a_mano" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    contaComeExtra,
    idServer,
    schedaServerId,
    nomeScheda,
    iniziataIl,
    finitaIl,
    kcal,
    kcalAMano,
    note,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sedute_allenamento';
  @override
  VerificationContext validateIntegrity(
    Insertable<SedutaAllenamento> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('conta_come_extra')) {
      context.handle(
        _contaComeExtraMeta,
        contaComeExtra.isAcceptableOrUnknown(
          data['conta_come_extra']!,
          _contaComeExtraMeta,
        ),
      );
    }
    if (data.containsKey('id_server')) {
      context.handle(
        _idServerMeta,
        idServer.isAcceptableOrUnknown(data['id_server']!, _idServerMeta),
      );
    }
    if (data.containsKey('scheda_server_id')) {
      context.handle(
        _schedaServerIdMeta,
        schedaServerId.isAcceptableOrUnknown(
          data['scheda_server_id']!,
          _schedaServerIdMeta,
        ),
      );
    }
    if (data.containsKey('nome_scheda')) {
      context.handle(
        _nomeSchedaMeta,
        nomeScheda.isAcceptableOrUnknown(data['nome_scheda']!, _nomeSchedaMeta),
      );
    }
    if (data.containsKey('iniziata_il')) {
      context.handle(
        _iniziataIlMeta,
        iniziataIl.isAcceptableOrUnknown(data['iniziata_il']!, _iniziataIlMeta),
      );
    } else if (isInserting) {
      context.missing(_iniziataIlMeta);
    }
    if (data.containsKey('finita_il')) {
      context.handle(
        _finitaIlMeta,
        finitaIl.isAcceptableOrUnknown(data['finita_il']!, _finitaIlMeta),
      );
    }
    if (data.containsKey('kcal')) {
      context.handle(
        _kcalMeta,
        kcal.isAcceptableOrUnknown(data['kcal']!, _kcalMeta),
      );
    }
    if (data.containsKey('kcal_a_mano')) {
      context.handle(
        _kcalAManoMeta,
        kcalAMano.isAcceptableOrUnknown(data['kcal_a_mano']!, _kcalAManoMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SedutaAllenamento map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SedutaAllenamento(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      contaComeExtra: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}conta_come_extra'],
      )!,
      idServer: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id_server'],
      ),
      schedaServerId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}scheda_server_id'],
      ),
      nomeScheda: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nome_scheda'],
      ),
      iniziataIl: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}iniziata_il'],
      )!,
      finitaIl: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}finita_il'],
      ),
      kcal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}kcal'],
      ),
      kcalAMano: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}kcal_a_mano'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
    );
  }

  @override
  $SeduteAllenamentoTable createAlias(String alias) {
    return $SeduteAllenamentoTable(attachedDatabase, alias);
  }
}

class SedutaAllenamento extends DataClass
    implements Insertable<SedutaAllenamento> {
  final int id;

  /// «Questa è stata fuori dal solito» — 3b-G.7.
  ///
  /// 🚨 Stessa cosa di `AllenamentiDaOrologio.contaComeExtra`, e c'è su tutte e
  /// due perché nel modello a stima esistono tutte e due: marcarne solo una
  /// famiglia vorrebbe dire che la mezza maratona conta se l'hai fatta con
  /// l'orologio e non se l'hai registrata con l'app.
  final bool contaComeExtra;

  /// L'`id` che questa seduta aveva sul server, se ci è mai stata.
  final int? idServer;

  /// L'`id` **del server** della scheda eseguita, come lo mandava `plan_id`.
  ///
  /// ⚠️ Non l'id locale in `SchedeSulTelefono`: quello cambia da telefono a
  /// telefono, questo no. Le due cose si incrociano su
  /// `SchedeSulTelefono.idOrigine`, con `origine = 'server'`.
  final int? schedaServerId;

  /// 💡 Copiato al momento della seduta, non risolto ogni volta: la scheda può
  /// essere archiviata o rinominata, e lo storico deve continuare a dire quello
  /// che diceva allora.
  final String? nomeScheda;
  final DateTime iniziataIl;

  /// 🚨 `null` = **seduta ancora aperta**, ed è uno stato che deve sopravvivere
  /// alla chiusura dell'app: chi si allena mette giù il telefono.
  final DateTime? finitaIl;

  /// Le calorie che **valgono** per questa seduta.
  ///
  /// ⚠️ Va sempre letta insieme a [kcalAMano]: è la coppia che tiene in piedi la
  /// regola «il manuale batte la stima». 🚨 Senza la seconda colonna, un
  /// ricalcolo automatico non sa se sta sovrascrivendo una stima o una
  /// correzione della persona — e lo scopre solo la persona, quando il suo
  /// numero sparisce.
  final int? kcal;

  /// Se [kcal] l'ha scritta la persona invece della formula.
  final bool kcalAMano;
  final String? note;
  const SedutaAllenamento({
    required this.id,
    required this.contaComeExtra,
    this.idServer,
    this.schedaServerId,
    this.nomeScheda,
    required this.iniziataIl,
    this.finitaIl,
    this.kcal,
    required this.kcalAMano,
    this.note,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['conta_come_extra'] = Variable<bool>(contaComeExtra);
    if (!nullToAbsent || idServer != null) {
      map['id_server'] = Variable<int>(idServer);
    }
    if (!nullToAbsent || schedaServerId != null) {
      map['scheda_server_id'] = Variable<int>(schedaServerId);
    }
    if (!nullToAbsent || nomeScheda != null) {
      map['nome_scheda'] = Variable<String>(nomeScheda);
    }
    map['iniziata_il'] = Variable<DateTime>(iniziataIl);
    if (!nullToAbsent || finitaIl != null) {
      map['finita_il'] = Variable<DateTime>(finitaIl);
    }
    if (!nullToAbsent || kcal != null) {
      map['kcal'] = Variable<int>(kcal);
    }
    map['kcal_a_mano'] = Variable<bool>(kcalAMano);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    return map;
  }

  SeduteAllenamentoCompanion toCompanion(bool nullToAbsent) {
    return SeduteAllenamentoCompanion(
      id: Value(id),
      contaComeExtra: Value(contaComeExtra),
      idServer: idServer == null && nullToAbsent
          ? const Value.absent()
          : Value(idServer),
      schedaServerId: schedaServerId == null && nullToAbsent
          ? const Value.absent()
          : Value(schedaServerId),
      nomeScheda: nomeScheda == null && nullToAbsent
          ? const Value.absent()
          : Value(nomeScheda),
      iniziataIl: Value(iniziataIl),
      finitaIl: finitaIl == null && nullToAbsent
          ? const Value.absent()
          : Value(finitaIl),
      kcal: kcal == null && nullToAbsent ? const Value.absent() : Value(kcal),
      kcalAMano: Value(kcalAMano),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
    );
  }

  factory SedutaAllenamento.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SedutaAllenamento(
      id: serializer.fromJson<int>(json['id']),
      contaComeExtra: serializer.fromJson<bool>(json['contaComeExtra']),
      idServer: serializer.fromJson<int?>(json['idServer']),
      schedaServerId: serializer.fromJson<int?>(json['schedaServerId']),
      nomeScheda: serializer.fromJson<String?>(json['nomeScheda']),
      iniziataIl: serializer.fromJson<DateTime>(json['iniziataIl']),
      finitaIl: serializer.fromJson<DateTime?>(json['finitaIl']),
      kcal: serializer.fromJson<int?>(json['kcal']),
      kcalAMano: serializer.fromJson<bool>(json['kcalAMano']),
      note: serializer.fromJson<String?>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'contaComeExtra': serializer.toJson<bool>(contaComeExtra),
      'idServer': serializer.toJson<int?>(idServer),
      'schedaServerId': serializer.toJson<int?>(schedaServerId),
      'nomeScheda': serializer.toJson<String?>(nomeScheda),
      'iniziataIl': serializer.toJson<DateTime>(iniziataIl),
      'finitaIl': serializer.toJson<DateTime?>(finitaIl),
      'kcal': serializer.toJson<int?>(kcal),
      'kcalAMano': serializer.toJson<bool>(kcalAMano),
      'note': serializer.toJson<String?>(note),
    };
  }

  SedutaAllenamento copyWith({
    int? id,
    bool? contaComeExtra,
    Value<int?> idServer = const Value.absent(),
    Value<int?> schedaServerId = const Value.absent(),
    Value<String?> nomeScheda = const Value.absent(),
    DateTime? iniziataIl,
    Value<DateTime?> finitaIl = const Value.absent(),
    Value<int?> kcal = const Value.absent(),
    bool? kcalAMano,
    Value<String?> note = const Value.absent(),
  }) => SedutaAllenamento(
    id: id ?? this.id,
    contaComeExtra: contaComeExtra ?? this.contaComeExtra,
    idServer: idServer.present ? idServer.value : this.idServer,
    schedaServerId: schedaServerId.present
        ? schedaServerId.value
        : this.schedaServerId,
    nomeScheda: nomeScheda.present ? nomeScheda.value : this.nomeScheda,
    iniziataIl: iniziataIl ?? this.iniziataIl,
    finitaIl: finitaIl.present ? finitaIl.value : this.finitaIl,
    kcal: kcal.present ? kcal.value : this.kcal,
    kcalAMano: kcalAMano ?? this.kcalAMano,
    note: note.present ? note.value : this.note,
  );
  SedutaAllenamento copyWithCompanion(SeduteAllenamentoCompanion data) {
    return SedutaAllenamento(
      id: data.id.present ? data.id.value : this.id,
      contaComeExtra: data.contaComeExtra.present
          ? data.contaComeExtra.value
          : this.contaComeExtra,
      idServer: data.idServer.present ? data.idServer.value : this.idServer,
      schedaServerId: data.schedaServerId.present
          ? data.schedaServerId.value
          : this.schedaServerId,
      nomeScheda: data.nomeScheda.present
          ? data.nomeScheda.value
          : this.nomeScheda,
      iniziataIl: data.iniziataIl.present
          ? data.iniziataIl.value
          : this.iniziataIl,
      finitaIl: data.finitaIl.present ? data.finitaIl.value : this.finitaIl,
      kcal: data.kcal.present ? data.kcal.value : this.kcal,
      kcalAMano: data.kcalAMano.present ? data.kcalAMano.value : this.kcalAMano,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SedutaAllenamento(')
          ..write('id: $id, ')
          ..write('contaComeExtra: $contaComeExtra, ')
          ..write('idServer: $idServer, ')
          ..write('schedaServerId: $schedaServerId, ')
          ..write('nomeScheda: $nomeScheda, ')
          ..write('iniziataIl: $iniziataIl, ')
          ..write('finitaIl: $finitaIl, ')
          ..write('kcal: $kcal, ')
          ..write('kcalAMano: $kcalAMano, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    contaComeExtra,
    idServer,
    schedaServerId,
    nomeScheda,
    iniziataIl,
    finitaIl,
    kcal,
    kcalAMano,
    note,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SedutaAllenamento &&
          other.id == this.id &&
          other.contaComeExtra == this.contaComeExtra &&
          other.idServer == this.idServer &&
          other.schedaServerId == this.schedaServerId &&
          other.nomeScheda == this.nomeScheda &&
          other.iniziataIl == this.iniziataIl &&
          other.finitaIl == this.finitaIl &&
          other.kcal == this.kcal &&
          other.kcalAMano == this.kcalAMano &&
          other.note == this.note);
}

class SeduteAllenamentoCompanion extends UpdateCompanion<SedutaAllenamento> {
  final Value<int> id;
  final Value<bool> contaComeExtra;
  final Value<int?> idServer;
  final Value<int?> schedaServerId;
  final Value<String?> nomeScheda;
  final Value<DateTime> iniziataIl;
  final Value<DateTime?> finitaIl;
  final Value<int?> kcal;
  final Value<bool> kcalAMano;
  final Value<String?> note;
  const SeduteAllenamentoCompanion({
    this.id = const Value.absent(),
    this.contaComeExtra = const Value.absent(),
    this.idServer = const Value.absent(),
    this.schedaServerId = const Value.absent(),
    this.nomeScheda = const Value.absent(),
    this.iniziataIl = const Value.absent(),
    this.finitaIl = const Value.absent(),
    this.kcal = const Value.absent(),
    this.kcalAMano = const Value.absent(),
    this.note = const Value.absent(),
  });
  SeduteAllenamentoCompanion.insert({
    this.id = const Value.absent(),
    this.contaComeExtra = const Value.absent(),
    this.idServer = const Value.absent(),
    this.schedaServerId = const Value.absent(),
    this.nomeScheda = const Value.absent(),
    required DateTime iniziataIl,
    this.finitaIl = const Value.absent(),
    this.kcal = const Value.absent(),
    this.kcalAMano = const Value.absent(),
    this.note = const Value.absent(),
  }) : iniziataIl = Value(iniziataIl);
  static Insertable<SedutaAllenamento> custom({
    Expression<int>? id,
    Expression<bool>? contaComeExtra,
    Expression<int>? idServer,
    Expression<int>? schedaServerId,
    Expression<String>? nomeScheda,
    Expression<DateTime>? iniziataIl,
    Expression<DateTime>? finitaIl,
    Expression<int>? kcal,
    Expression<bool>? kcalAMano,
    Expression<String>? note,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (contaComeExtra != null) 'conta_come_extra': contaComeExtra,
      if (idServer != null) 'id_server': idServer,
      if (schedaServerId != null) 'scheda_server_id': schedaServerId,
      if (nomeScheda != null) 'nome_scheda': nomeScheda,
      if (iniziataIl != null) 'iniziata_il': iniziataIl,
      if (finitaIl != null) 'finita_il': finitaIl,
      if (kcal != null) 'kcal': kcal,
      if (kcalAMano != null) 'kcal_a_mano': kcalAMano,
      if (note != null) 'note': note,
    });
  }

  SeduteAllenamentoCompanion copyWith({
    Value<int>? id,
    Value<bool>? contaComeExtra,
    Value<int?>? idServer,
    Value<int?>? schedaServerId,
    Value<String?>? nomeScheda,
    Value<DateTime>? iniziataIl,
    Value<DateTime?>? finitaIl,
    Value<int?>? kcal,
    Value<bool>? kcalAMano,
    Value<String?>? note,
  }) {
    return SeduteAllenamentoCompanion(
      id: id ?? this.id,
      contaComeExtra: contaComeExtra ?? this.contaComeExtra,
      idServer: idServer ?? this.idServer,
      schedaServerId: schedaServerId ?? this.schedaServerId,
      nomeScheda: nomeScheda ?? this.nomeScheda,
      iniziataIl: iniziataIl ?? this.iniziataIl,
      finitaIl: finitaIl ?? this.finitaIl,
      kcal: kcal ?? this.kcal,
      kcalAMano: kcalAMano ?? this.kcalAMano,
      note: note ?? this.note,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (contaComeExtra.present) {
      map['conta_come_extra'] = Variable<bool>(contaComeExtra.value);
    }
    if (idServer.present) {
      map['id_server'] = Variable<int>(idServer.value);
    }
    if (schedaServerId.present) {
      map['scheda_server_id'] = Variable<int>(schedaServerId.value);
    }
    if (nomeScheda.present) {
      map['nome_scheda'] = Variable<String>(nomeScheda.value);
    }
    if (iniziataIl.present) {
      map['iniziata_il'] = Variable<DateTime>(iniziataIl.value);
    }
    if (finitaIl.present) {
      map['finita_il'] = Variable<DateTime>(finitaIl.value);
    }
    if (kcal.present) {
      map['kcal'] = Variable<int>(kcal.value);
    }
    if (kcalAMano.present) {
      map['kcal_a_mano'] = Variable<bool>(kcalAMano.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SeduteAllenamentoCompanion(')
          ..write('id: $id, ')
          ..write('contaComeExtra: $contaComeExtra, ')
          ..write('idServer: $idServer, ')
          ..write('schedaServerId: $schedaServerId, ')
          ..write('nomeScheda: $nomeScheda, ')
          ..write('iniziataIl: $iniziataIl, ')
          ..write('finitaIl: $finitaIl, ')
          ..write('kcal: $kcal, ')
          ..write('kcalAMano: $kcalAMano, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }
}

class $SerieDelleSeduteTable extends SerieDelleSedute
    with TableInfo<$SerieDelleSeduteTable, SerieSeduta> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SerieDelleSeduteTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _sedutaIdMeta = const VerificationMeta(
    'sedutaId',
  );
  @override
  late final GeneratedColumn<int> sedutaId = GeneratedColumn<int>(
    'seduta_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sedute_allenamento (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _esercizioIdMeta = const VerificationMeta(
    'esercizioId',
  );
  @override
  late final GeneratedColumn<int> esercizioId = GeneratedColumn<int>(
    'esercizio_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nomeEsercizioMeta = const VerificationMeta(
    'nomeEsercizio',
  );
  @override
  late final GeneratedColumn<String> nomeEsercizio = GeneratedColumn<String>(
    'nome_esercizio',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _metMeta = const VerificationMeta('met');
  @override
  late final GeneratedColumn<double> met = GeneratedColumn<double>(
    'met',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _numeroMeta = const VerificationMeta('numero');
  @override
  late final GeneratedColumn<int> numero = GeneratedColumn<int>(
    'numero',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ripetizioniMeta = const VerificationMeta(
    'ripetizioni',
  );
  @override
  late final GeneratedColumn<int> ripetizioni = GeneratedColumn<int>(
    'ripetizioni',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pesoKgMeta = const VerificationMeta('pesoKg');
  @override
  late final GeneratedColumn<double> pesoKg = GeneratedColumn<double>(
    'peso_kg',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durataSecMeta = const VerificationMeta(
    'durataSec',
  );
  @override
  late final GeneratedColumn<int> durataSec = GeneratedColumn<int>(
    'durata_sec',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _riposoSecMeta = const VerificationMeta(
    'riposoSec',
  );
  @override
  late final GeneratedColumn<int> riposoSec = GeneratedColumn<int>(
    'riposo_sec',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fattaIlMeta = const VerificationMeta(
    'fattaIl',
  );
  @override
  late final GeneratedColumn<DateTime> fattaIl = GeneratedColumn<DateTime>(
    'fatta_il',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sedutaId,
    esercizioId,
    nomeEsercizio,
    met,
    numero,
    ripetizioni,
    pesoKg,
    durataSec,
    riposoSec,
    fattaIl,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'serie_delle_sedute';
  @override
  VerificationContext validateIntegrity(
    Insertable<SerieSeduta> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('seduta_id')) {
      context.handle(
        _sedutaIdMeta,
        sedutaId.isAcceptableOrUnknown(data['seduta_id']!, _sedutaIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sedutaIdMeta);
    }
    if (data.containsKey('esercizio_id')) {
      context.handle(
        _esercizioIdMeta,
        esercizioId.isAcceptableOrUnknown(
          data['esercizio_id']!,
          _esercizioIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_esercizioIdMeta);
    }
    if (data.containsKey('nome_esercizio')) {
      context.handle(
        _nomeEsercizioMeta,
        nomeEsercizio.isAcceptableOrUnknown(
          data['nome_esercizio']!,
          _nomeEsercizioMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_nomeEsercizioMeta);
    }
    if (data.containsKey('met')) {
      context.handle(
        _metMeta,
        met.isAcceptableOrUnknown(data['met']!, _metMeta),
      );
    }
    if (data.containsKey('numero')) {
      context.handle(
        _numeroMeta,
        numero.isAcceptableOrUnknown(data['numero']!, _numeroMeta),
      );
    } else if (isInserting) {
      context.missing(_numeroMeta);
    }
    if (data.containsKey('ripetizioni')) {
      context.handle(
        _ripetizioniMeta,
        ripetizioni.isAcceptableOrUnknown(
          data['ripetizioni']!,
          _ripetizioniMeta,
        ),
      );
    }
    if (data.containsKey('peso_kg')) {
      context.handle(
        _pesoKgMeta,
        pesoKg.isAcceptableOrUnknown(data['peso_kg']!, _pesoKgMeta),
      );
    }
    if (data.containsKey('durata_sec')) {
      context.handle(
        _durataSecMeta,
        durataSec.isAcceptableOrUnknown(data['durata_sec']!, _durataSecMeta),
      );
    }
    if (data.containsKey('riposo_sec')) {
      context.handle(
        _riposoSecMeta,
        riposoSec.isAcceptableOrUnknown(data['riposo_sec']!, _riposoSecMeta),
      );
    }
    if (data.containsKey('fatta_il')) {
      context.handle(
        _fattaIlMeta,
        fattaIl.isAcceptableOrUnknown(data['fatta_il']!, _fattaIlMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {sedutaId, esercizioId, numero},
  ];
  @override
  SerieSeduta map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SerieSeduta(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sedutaId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seduta_id'],
      )!,
      esercizioId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}esercizio_id'],
      )!,
      nomeEsercizio: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nome_esercizio'],
      )!,
      met: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}met'],
      ),
      numero: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}numero'],
      )!,
      ripetizioni: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ripetizioni'],
      ),
      pesoKg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}peso_kg'],
      ),
      durataSec: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}durata_sec'],
      ),
      riposoSec: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}riposo_sec'],
      ),
      fattaIl: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fatta_il'],
      ),
    );
  }

  @override
  $SerieDelleSeduteTable createAlias(String alias) {
    return $SerieDelleSeduteTable(attachedDatabase, alias);
  }
}

class SerieSeduta extends DataClass implements Insertable<SerieSeduta> {
  final int id;

  /// L'`id` **locale** della seduta: qui il legame è interno al telefono.
  final int sedutaId;
  final int esercizioId;
  final String nomeEsercizio;

  /// Il MET dell'esercizio, **copiato al momento della serie** — FASE 11.2.
  ///
  /// ══ 🚨 SI COPIA, NON SI RISOLVE ═══════════════════════════════════════
  ///
  /// Il catalogo degli esercizi **resta sul server** (`plan_tutto_sul_telefono.md`
  /// §2.2): è roba condivisa, non è di nessuno. ⚠️ Ma il calcolo delle calorie
  /// gira sul telefono, e deve funzionare **senza rete** — un ricalcolo che
  /// aspetta il catalogo è un ricalcolo che non avviene in palestra.
  ///
  /// 💡 E c'è la ragione migliore: se domani il MET di un esercizio venisse
  /// corretto nel catalogo, le sedute già fatte **non devono cambiare numero**.
  /// Lo storico deve continuare a dire quello che diceva allora. È la stessa
  /// scelta di [nomeEsercizio].
  ///
  /// ⛔ `null` per l'esercizio che non ce l'ha (1 su 121) e per quelli scritti a
  /// mano dalle palestre: allora vince il ripiego di `CalorieAllenamento.met`.
  final double? met;
  final int numero;
  final int? ripetizioni;

  /// 🚨 `real` e non intero: i manubri da 7.5 kg esistono, e arrotondarli
  /// falserebbe il volume settimanale di chi li usa.
  final double? pesoKg;
  final int? durataSec;
  final int? riposoSec;
  final DateTime? fattaIl;
  const SerieSeduta({
    required this.id,
    required this.sedutaId,
    required this.esercizioId,
    required this.nomeEsercizio,
    this.met,
    required this.numero,
    this.ripetizioni,
    this.pesoKg,
    this.durataSec,
    this.riposoSec,
    this.fattaIl,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['seduta_id'] = Variable<int>(sedutaId);
    map['esercizio_id'] = Variable<int>(esercizioId);
    map['nome_esercizio'] = Variable<String>(nomeEsercizio);
    if (!nullToAbsent || met != null) {
      map['met'] = Variable<double>(met);
    }
    map['numero'] = Variable<int>(numero);
    if (!nullToAbsent || ripetizioni != null) {
      map['ripetizioni'] = Variable<int>(ripetizioni);
    }
    if (!nullToAbsent || pesoKg != null) {
      map['peso_kg'] = Variable<double>(pesoKg);
    }
    if (!nullToAbsent || durataSec != null) {
      map['durata_sec'] = Variable<int>(durataSec);
    }
    if (!nullToAbsent || riposoSec != null) {
      map['riposo_sec'] = Variable<int>(riposoSec);
    }
    if (!nullToAbsent || fattaIl != null) {
      map['fatta_il'] = Variable<DateTime>(fattaIl);
    }
    return map;
  }

  SerieDelleSeduteCompanion toCompanion(bool nullToAbsent) {
    return SerieDelleSeduteCompanion(
      id: Value(id),
      sedutaId: Value(sedutaId),
      esercizioId: Value(esercizioId),
      nomeEsercizio: Value(nomeEsercizio),
      met: met == null && nullToAbsent ? const Value.absent() : Value(met),
      numero: Value(numero),
      ripetizioni: ripetizioni == null && nullToAbsent
          ? const Value.absent()
          : Value(ripetizioni),
      pesoKg: pesoKg == null && nullToAbsent
          ? const Value.absent()
          : Value(pesoKg),
      durataSec: durataSec == null && nullToAbsent
          ? const Value.absent()
          : Value(durataSec),
      riposoSec: riposoSec == null && nullToAbsent
          ? const Value.absent()
          : Value(riposoSec),
      fattaIl: fattaIl == null && nullToAbsent
          ? const Value.absent()
          : Value(fattaIl),
    );
  }

  factory SerieSeduta.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SerieSeduta(
      id: serializer.fromJson<int>(json['id']),
      sedutaId: serializer.fromJson<int>(json['sedutaId']),
      esercizioId: serializer.fromJson<int>(json['esercizioId']),
      nomeEsercizio: serializer.fromJson<String>(json['nomeEsercizio']),
      met: serializer.fromJson<double?>(json['met']),
      numero: serializer.fromJson<int>(json['numero']),
      ripetizioni: serializer.fromJson<int?>(json['ripetizioni']),
      pesoKg: serializer.fromJson<double?>(json['pesoKg']),
      durataSec: serializer.fromJson<int?>(json['durataSec']),
      riposoSec: serializer.fromJson<int?>(json['riposoSec']),
      fattaIl: serializer.fromJson<DateTime?>(json['fattaIl']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sedutaId': serializer.toJson<int>(sedutaId),
      'esercizioId': serializer.toJson<int>(esercizioId),
      'nomeEsercizio': serializer.toJson<String>(nomeEsercizio),
      'met': serializer.toJson<double?>(met),
      'numero': serializer.toJson<int>(numero),
      'ripetizioni': serializer.toJson<int?>(ripetizioni),
      'pesoKg': serializer.toJson<double?>(pesoKg),
      'durataSec': serializer.toJson<int?>(durataSec),
      'riposoSec': serializer.toJson<int?>(riposoSec),
      'fattaIl': serializer.toJson<DateTime?>(fattaIl),
    };
  }

  SerieSeduta copyWith({
    int? id,
    int? sedutaId,
    int? esercizioId,
    String? nomeEsercizio,
    Value<double?> met = const Value.absent(),
    int? numero,
    Value<int?> ripetizioni = const Value.absent(),
    Value<double?> pesoKg = const Value.absent(),
    Value<int?> durataSec = const Value.absent(),
    Value<int?> riposoSec = const Value.absent(),
    Value<DateTime?> fattaIl = const Value.absent(),
  }) => SerieSeduta(
    id: id ?? this.id,
    sedutaId: sedutaId ?? this.sedutaId,
    esercizioId: esercizioId ?? this.esercizioId,
    nomeEsercizio: nomeEsercizio ?? this.nomeEsercizio,
    met: met.present ? met.value : this.met,
    numero: numero ?? this.numero,
    ripetizioni: ripetizioni.present ? ripetizioni.value : this.ripetizioni,
    pesoKg: pesoKg.present ? pesoKg.value : this.pesoKg,
    durataSec: durataSec.present ? durataSec.value : this.durataSec,
    riposoSec: riposoSec.present ? riposoSec.value : this.riposoSec,
    fattaIl: fattaIl.present ? fattaIl.value : this.fattaIl,
  );
  SerieSeduta copyWithCompanion(SerieDelleSeduteCompanion data) {
    return SerieSeduta(
      id: data.id.present ? data.id.value : this.id,
      sedutaId: data.sedutaId.present ? data.sedutaId.value : this.sedutaId,
      esercizioId: data.esercizioId.present
          ? data.esercizioId.value
          : this.esercizioId,
      nomeEsercizio: data.nomeEsercizio.present
          ? data.nomeEsercizio.value
          : this.nomeEsercizio,
      met: data.met.present ? data.met.value : this.met,
      numero: data.numero.present ? data.numero.value : this.numero,
      ripetizioni: data.ripetizioni.present
          ? data.ripetizioni.value
          : this.ripetizioni,
      pesoKg: data.pesoKg.present ? data.pesoKg.value : this.pesoKg,
      durataSec: data.durataSec.present ? data.durataSec.value : this.durataSec,
      riposoSec: data.riposoSec.present ? data.riposoSec.value : this.riposoSec,
      fattaIl: data.fattaIl.present ? data.fattaIl.value : this.fattaIl,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SerieSeduta(')
          ..write('id: $id, ')
          ..write('sedutaId: $sedutaId, ')
          ..write('esercizioId: $esercizioId, ')
          ..write('nomeEsercizio: $nomeEsercizio, ')
          ..write('met: $met, ')
          ..write('numero: $numero, ')
          ..write('ripetizioni: $ripetizioni, ')
          ..write('pesoKg: $pesoKg, ')
          ..write('durataSec: $durataSec, ')
          ..write('riposoSec: $riposoSec, ')
          ..write('fattaIl: $fattaIl')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sedutaId,
    esercizioId,
    nomeEsercizio,
    met,
    numero,
    ripetizioni,
    pesoKg,
    durataSec,
    riposoSec,
    fattaIl,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SerieSeduta &&
          other.id == this.id &&
          other.sedutaId == this.sedutaId &&
          other.esercizioId == this.esercizioId &&
          other.nomeEsercizio == this.nomeEsercizio &&
          other.met == this.met &&
          other.numero == this.numero &&
          other.ripetizioni == this.ripetizioni &&
          other.pesoKg == this.pesoKg &&
          other.durataSec == this.durataSec &&
          other.riposoSec == this.riposoSec &&
          other.fattaIl == this.fattaIl);
}

class SerieDelleSeduteCompanion extends UpdateCompanion<SerieSeduta> {
  final Value<int> id;
  final Value<int> sedutaId;
  final Value<int> esercizioId;
  final Value<String> nomeEsercizio;
  final Value<double?> met;
  final Value<int> numero;
  final Value<int?> ripetizioni;
  final Value<double?> pesoKg;
  final Value<int?> durataSec;
  final Value<int?> riposoSec;
  final Value<DateTime?> fattaIl;
  const SerieDelleSeduteCompanion({
    this.id = const Value.absent(),
    this.sedutaId = const Value.absent(),
    this.esercizioId = const Value.absent(),
    this.nomeEsercizio = const Value.absent(),
    this.met = const Value.absent(),
    this.numero = const Value.absent(),
    this.ripetizioni = const Value.absent(),
    this.pesoKg = const Value.absent(),
    this.durataSec = const Value.absent(),
    this.riposoSec = const Value.absent(),
    this.fattaIl = const Value.absent(),
  });
  SerieDelleSeduteCompanion.insert({
    this.id = const Value.absent(),
    required int sedutaId,
    required int esercizioId,
    required String nomeEsercizio,
    this.met = const Value.absent(),
    required int numero,
    this.ripetizioni = const Value.absent(),
    this.pesoKg = const Value.absent(),
    this.durataSec = const Value.absent(),
    this.riposoSec = const Value.absent(),
    this.fattaIl = const Value.absent(),
  }) : sedutaId = Value(sedutaId),
       esercizioId = Value(esercizioId),
       nomeEsercizio = Value(nomeEsercizio),
       numero = Value(numero);
  static Insertable<SerieSeduta> custom({
    Expression<int>? id,
    Expression<int>? sedutaId,
    Expression<int>? esercizioId,
    Expression<String>? nomeEsercizio,
    Expression<double>? met,
    Expression<int>? numero,
    Expression<int>? ripetizioni,
    Expression<double>? pesoKg,
    Expression<int>? durataSec,
    Expression<int>? riposoSec,
    Expression<DateTime>? fattaIl,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sedutaId != null) 'seduta_id': sedutaId,
      if (esercizioId != null) 'esercizio_id': esercizioId,
      if (nomeEsercizio != null) 'nome_esercizio': nomeEsercizio,
      if (met != null) 'met': met,
      if (numero != null) 'numero': numero,
      if (ripetizioni != null) 'ripetizioni': ripetizioni,
      if (pesoKg != null) 'peso_kg': pesoKg,
      if (durataSec != null) 'durata_sec': durataSec,
      if (riposoSec != null) 'riposo_sec': riposoSec,
      if (fattaIl != null) 'fatta_il': fattaIl,
    });
  }

  SerieDelleSeduteCompanion copyWith({
    Value<int>? id,
    Value<int>? sedutaId,
    Value<int>? esercizioId,
    Value<String>? nomeEsercizio,
    Value<double?>? met,
    Value<int>? numero,
    Value<int?>? ripetizioni,
    Value<double?>? pesoKg,
    Value<int?>? durataSec,
    Value<int?>? riposoSec,
    Value<DateTime?>? fattaIl,
  }) {
    return SerieDelleSeduteCompanion(
      id: id ?? this.id,
      sedutaId: sedutaId ?? this.sedutaId,
      esercizioId: esercizioId ?? this.esercizioId,
      nomeEsercizio: nomeEsercizio ?? this.nomeEsercizio,
      met: met ?? this.met,
      numero: numero ?? this.numero,
      ripetizioni: ripetizioni ?? this.ripetizioni,
      pesoKg: pesoKg ?? this.pesoKg,
      durataSec: durataSec ?? this.durataSec,
      riposoSec: riposoSec ?? this.riposoSec,
      fattaIl: fattaIl ?? this.fattaIl,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sedutaId.present) {
      map['seduta_id'] = Variable<int>(sedutaId.value);
    }
    if (esercizioId.present) {
      map['esercizio_id'] = Variable<int>(esercizioId.value);
    }
    if (nomeEsercizio.present) {
      map['nome_esercizio'] = Variable<String>(nomeEsercizio.value);
    }
    if (met.present) {
      map['met'] = Variable<double>(met.value);
    }
    if (numero.present) {
      map['numero'] = Variable<int>(numero.value);
    }
    if (ripetizioni.present) {
      map['ripetizioni'] = Variable<int>(ripetizioni.value);
    }
    if (pesoKg.present) {
      map['peso_kg'] = Variable<double>(pesoKg.value);
    }
    if (durataSec.present) {
      map['durata_sec'] = Variable<int>(durataSec.value);
    }
    if (riposoSec.present) {
      map['riposo_sec'] = Variable<int>(riposoSec.value);
    }
    if (fattaIl.present) {
      map['fatta_il'] = Variable<DateTime>(fattaIl.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SerieDelleSeduteCompanion(')
          ..write('id: $id, ')
          ..write('sedutaId: $sedutaId, ')
          ..write('esercizioId: $esercizioId, ')
          ..write('nomeEsercizio: $nomeEsercizio, ')
          ..write('met: $met, ')
          ..write('numero: $numero, ')
          ..write('ripetizioni: $ripetizioni, ')
          ..write('pesoKg: $pesoKg, ')
          ..write('durataSec: $durataSec, ')
          ..write('riposoSec: $riposoSec, ')
          ..write('fattaIl: $fattaIl')
          ..write(')'))
        .toString();
  }
}

class $SettimanaProgrammataTable extends SettimanaProgrammata
    with TableInfo<$SettimanaProgrammataTable, GiornoProgrammato> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettimanaProgrammataTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _giornoMeta = const VerificationMeta('giorno');
  @override
  late final GeneratedColumn<int> giorno = GeneratedColumn<int>(
    'giorno',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _schedaLocaleMeta = const VerificationMeta(
    'schedaLocale',
  );
  @override
  late final GeneratedColumn<int> schedaLocale = GeneratedColumn<int>(
    'scheda_locale',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [giorno, schedaLocale];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settimana_programmata';
  @override
  VerificationContext validateIntegrity(
    Insertable<GiornoProgrammato> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('giorno')) {
      context.handle(
        _giornoMeta,
        giorno.isAcceptableOrUnknown(data['giorno']!, _giornoMeta),
      );
    }
    if (data.containsKey('scheda_locale')) {
      context.handle(
        _schedaLocaleMeta,
        schedaLocale.isAcceptableOrUnknown(
          data['scheda_locale']!,
          _schedaLocaleMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {giorno};
  @override
  GiornoProgrammato map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GiornoProgrammato(
      giorno: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}giorno'],
      )!,
      schedaLocale: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}scheda_locale'],
      ),
    );
  }

  @override
  $SettimanaProgrammataTable createAlias(String alias) {
    return $SettimanaProgrammataTable(attachedDatabase, alias);
  }
}

class GiornoProgrammato extends DataClass
    implements Insertable<GiornoProgrammato> {
  /// 1 = lunedì … 7 = domenica.
  ///
  /// 💡 **La convenzione di `DateTime.weekday`**, non una nostra: così
  /// `adesso.weekday` è già la chiave, senza nessuna conversione da ricordare.
  final int giorno;

  /// L'id in `SchedeSulTelefono`, o `null` per il riposo.
  final int? schedaLocale;
  const GiornoProgrammato({required this.giorno, this.schedaLocale});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['giorno'] = Variable<int>(giorno);
    if (!nullToAbsent || schedaLocale != null) {
      map['scheda_locale'] = Variable<int>(schedaLocale);
    }
    return map;
  }

  SettimanaProgrammataCompanion toCompanion(bool nullToAbsent) {
    return SettimanaProgrammataCompanion(
      giorno: Value(giorno),
      schedaLocale: schedaLocale == null && nullToAbsent
          ? const Value.absent()
          : Value(schedaLocale),
    );
  }

  factory GiornoProgrammato.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GiornoProgrammato(
      giorno: serializer.fromJson<int>(json['giorno']),
      schedaLocale: serializer.fromJson<int?>(json['schedaLocale']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'giorno': serializer.toJson<int>(giorno),
      'schedaLocale': serializer.toJson<int?>(schedaLocale),
    };
  }

  GiornoProgrammato copyWith({
    int? giorno,
    Value<int?> schedaLocale = const Value.absent(),
  }) => GiornoProgrammato(
    giorno: giorno ?? this.giorno,
    schedaLocale: schedaLocale.present ? schedaLocale.value : this.schedaLocale,
  );
  GiornoProgrammato copyWithCompanion(SettimanaProgrammataCompanion data) {
    return GiornoProgrammato(
      giorno: data.giorno.present ? data.giorno.value : this.giorno,
      schedaLocale: data.schedaLocale.present
          ? data.schedaLocale.value
          : this.schedaLocale,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GiornoProgrammato(')
          ..write('giorno: $giorno, ')
          ..write('schedaLocale: $schedaLocale')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(giorno, schedaLocale);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GiornoProgrammato &&
          other.giorno == this.giorno &&
          other.schedaLocale == this.schedaLocale);
}

class SettimanaProgrammataCompanion extends UpdateCompanion<GiornoProgrammato> {
  final Value<int> giorno;
  final Value<int?> schedaLocale;
  const SettimanaProgrammataCompanion({
    this.giorno = const Value.absent(),
    this.schedaLocale = const Value.absent(),
  });
  SettimanaProgrammataCompanion.insert({
    this.giorno = const Value.absent(),
    this.schedaLocale = const Value.absent(),
  });
  static Insertable<GiornoProgrammato> custom({
    Expression<int>? giorno,
    Expression<int>? schedaLocale,
  }) {
    return RawValuesInsertable({
      if (giorno != null) 'giorno': giorno,
      if (schedaLocale != null) 'scheda_locale': schedaLocale,
    });
  }

  SettimanaProgrammataCompanion copyWith({
    Value<int>? giorno,
    Value<int?>? schedaLocale,
  }) {
    return SettimanaProgrammataCompanion(
      giorno: giorno ?? this.giorno,
      schedaLocale: schedaLocale ?? this.schedaLocale,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (giorno.present) {
      map['giorno'] = Variable<int>(giorno.value);
    }
    if (schedaLocale.present) {
      map['scheda_locale'] = Variable<int>(schedaLocale.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettimanaProgrammataCompanion(')
          ..write('giorno: $giorno, ')
          ..write('schedaLocale: $schedaLocale')
          ..write(')'))
        .toString();
  }
}

class $AnalisiDelleSchedeTable extends AnalisiDelleSchede
    with TableInfo<$AnalisiDelleSchedeTable, AnalisiScheda> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AnalisiDelleSchedeTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _schedaLocaleMeta = const VerificationMeta(
    'schedaLocale',
  );
  @override
  late final GeneratedColumn<int> schedaLocale = GeneratedColumn<int>(
    'scheda_locale',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _righeMeta = const VerificationMeta('righe');
  @override
  late final GeneratedColumn<String> righe = GeneratedColumn<String>(
    'righe',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _improntaMeta = const VerificationMeta(
    'impronta',
  );
  @override
  late final GeneratedColumn<String> impronta = GeneratedColumn<String>(
    'impronta',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _riassuntoMeta = const VerificationMeta(
    'riassunto',
  );
  @override
  late final GeneratedColumn<String> riassunto = GeneratedColumn<String>(
    'riassunto',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fattaIlMeta = const VerificationMeta(
    'fattaIl',
  );
  @override
  late final GeneratedColumn<DateTime> fattaIl = GeneratedColumn<DateTime>(
    'fatta_il',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    schedaLocale,
    righe,
    impronta,
    riassunto,
    fattaIl,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'analisi_delle_schede';
  @override
  VerificationContext validateIntegrity(
    Insertable<AnalisiScheda> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('scheda_locale')) {
      context.handle(
        _schedaLocaleMeta,
        schedaLocale.isAcceptableOrUnknown(
          data['scheda_locale']!,
          _schedaLocaleMeta,
        ),
      );
    }
    if (data.containsKey('righe')) {
      context.handle(
        _righeMeta,
        righe.isAcceptableOrUnknown(data['righe']!, _righeMeta),
      );
    } else if (isInserting) {
      context.missing(_righeMeta);
    }
    if (data.containsKey('impronta')) {
      context.handle(
        _improntaMeta,
        impronta.isAcceptableOrUnknown(data['impronta']!, _improntaMeta),
      );
    } else if (isInserting) {
      context.missing(_improntaMeta);
    }
    if (data.containsKey('riassunto')) {
      context.handle(
        _riassuntoMeta,
        riassunto.isAcceptableOrUnknown(data['riassunto']!, _riassuntoMeta),
      );
    }
    if (data.containsKey('fatta_il')) {
      context.handle(
        _fattaIlMeta,
        fattaIl.isAcceptableOrUnknown(data['fatta_il']!, _fattaIlMeta),
      );
    } else if (isInserting) {
      context.missing(_fattaIlMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {schedaLocale};
  @override
  AnalisiScheda map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AnalisiScheda(
      schedaLocale: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}scheda_locale'],
      )!,
      righe: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}righe'],
      )!,
      impronta: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}impronta'],
      )!,
      riassunto: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}riassunto'],
      ),
      fattaIl: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fatta_il'],
      )!,
    );
  }

  @override
  $AnalisiDelleSchedeTable createAlias(String alias) {
    return $AnalisiDelleSchedeTable(attachedDatabase, alias);
  }
}

class AnalisiScheda extends DataClass implements Insertable<AnalisiScheda> {
  /// L'id della scheda **su questo telefono** — `SchedeSulTelefono.id`.
  ///
  /// ══ ⚠️ SI CHIAMAVA `schedaServerId`, ED ERA SBAGLIATO ═══════════════════
  ///
  /// 🚨 `schedeUniteProvider` costruisce ogni `WorkoutPlan` con `'id': r.id`,
  /// cioè con l'id **locale**: quello che arriva qui non è mai stato l'id del
  /// server. ⛔ Il codice funzionava — tutti e due i lati usavano lo stesso
  /// numero — ma il nome raccontava un'altra cosa, ed è il tipo di bugia che si
  /// paga quando qualcuno ci costruisce sopra.
  ///
  /// 💡 Rinominata alla v23, quando è arrivata [VersioniDelleSchede] che si
  /// aggancia **allo stesso id**: due tabelle vicine non potevano chiamarlo in
  /// due modi diversi.
  final int schedaLocale;

  /// Le righe, come sono arrivate dal server: `[{id, andamento, riga}, …]`.
  final String righe;

  /// L'impronta dello storico al momento dell'analisi. Vedi la nota in testa.
  final String impronta;

  /// La frase su **tutta** la scheda — 3b-I.F.
  ///
  /// ⚠️ **Nullable**, e non «vuota di serie»: le analisi scritte prima che
  /// questo campo esistesse non ne hanno una, e riempirle con una stringa vuota
  /// direbbe «il modello non ha trovato niente da dire» — che è un'altra cosa.
  final String? riassunto;
  final DateTime fattaIl;
  const AnalisiScheda({
    required this.schedaLocale,
    required this.righe,
    required this.impronta,
    this.riassunto,
    required this.fattaIl,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['scheda_locale'] = Variable<int>(schedaLocale);
    map['righe'] = Variable<String>(righe);
    map['impronta'] = Variable<String>(impronta);
    if (!nullToAbsent || riassunto != null) {
      map['riassunto'] = Variable<String>(riassunto);
    }
    map['fatta_il'] = Variable<DateTime>(fattaIl);
    return map;
  }

  AnalisiDelleSchedeCompanion toCompanion(bool nullToAbsent) {
    return AnalisiDelleSchedeCompanion(
      schedaLocale: Value(schedaLocale),
      righe: Value(righe),
      impronta: Value(impronta),
      riassunto: riassunto == null && nullToAbsent
          ? const Value.absent()
          : Value(riassunto),
      fattaIl: Value(fattaIl),
    );
  }

  factory AnalisiScheda.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AnalisiScheda(
      schedaLocale: serializer.fromJson<int>(json['schedaLocale']),
      righe: serializer.fromJson<String>(json['righe']),
      impronta: serializer.fromJson<String>(json['impronta']),
      riassunto: serializer.fromJson<String?>(json['riassunto']),
      fattaIl: serializer.fromJson<DateTime>(json['fattaIl']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'schedaLocale': serializer.toJson<int>(schedaLocale),
      'righe': serializer.toJson<String>(righe),
      'impronta': serializer.toJson<String>(impronta),
      'riassunto': serializer.toJson<String?>(riassunto),
      'fattaIl': serializer.toJson<DateTime>(fattaIl),
    };
  }

  AnalisiScheda copyWith({
    int? schedaLocale,
    String? righe,
    String? impronta,
    Value<String?> riassunto = const Value.absent(),
    DateTime? fattaIl,
  }) => AnalisiScheda(
    schedaLocale: schedaLocale ?? this.schedaLocale,
    righe: righe ?? this.righe,
    impronta: impronta ?? this.impronta,
    riassunto: riassunto.present ? riassunto.value : this.riassunto,
    fattaIl: fattaIl ?? this.fattaIl,
  );
  AnalisiScheda copyWithCompanion(AnalisiDelleSchedeCompanion data) {
    return AnalisiScheda(
      schedaLocale: data.schedaLocale.present
          ? data.schedaLocale.value
          : this.schedaLocale,
      righe: data.righe.present ? data.righe.value : this.righe,
      impronta: data.impronta.present ? data.impronta.value : this.impronta,
      riassunto: data.riassunto.present ? data.riassunto.value : this.riassunto,
      fattaIl: data.fattaIl.present ? data.fattaIl.value : this.fattaIl,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AnalisiScheda(')
          ..write('schedaLocale: $schedaLocale, ')
          ..write('righe: $righe, ')
          ..write('impronta: $impronta, ')
          ..write('riassunto: $riassunto, ')
          ..write('fattaIl: $fattaIl')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(schedaLocale, righe, impronta, riassunto, fattaIl);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AnalisiScheda &&
          other.schedaLocale == this.schedaLocale &&
          other.righe == this.righe &&
          other.impronta == this.impronta &&
          other.riassunto == this.riassunto &&
          other.fattaIl == this.fattaIl);
}

class AnalisiDelleSchedeCompanion extends UpdateCompanion<AnalisiScheda> {
  final Value<int> schedaLocale;
  final Value<String> righe;
  final Value<String> impronta;
  final Value<String?> riassunto;
  final Value<DateTime> fattaIl;
  const AnalisiDelleSchedeCompanion({
    this.schedaLocale = const Value.absent(),
    this.righe = const Value.absent(),
    this.impronta = const Value.absent(),
    this.riassunto = const Value.absent(),
    this.fattaIl = const Value.absent(),
  });
  AnalisiDelleSchedeCompanion.insert({
    this.schedaLocale = const Value.absent(),
    required String righe,
    required String impronta,
    this.riassunto = const Value.absent(),
    required DateTime fattaIl,
  }) : righe = Value(righe),
       impronta = Value(impronta),
       fattaIl = Value(fattaIl);
  static Insertable<AnalisiScheda> custom({
    Expression<int>? schedaLocale,
    Expression<String>? righe,
    Expression<String>? impronta,
    Expression<String>? riassunto,
    Expression<DateTime>? fattaIl,
  }) {
    return RawValuesInsertable({
      if (schedaLocale != null) 'scheda_locale': schedaLocale,
      if (righe != null) 'righe': righe,
      if (impronta != null) 'impronta': impronta,
      if (riassunto != null) 'riassunto': riassunto,
      if (fattaIl != null) 'fatta_il': fattaIl,
    });
  }

  AnalisiDelleSchedeCompanion copyWith({
    Value<int>? schedaLocale,
    Value<String>? righe,
    Value<String>? impronta,
    Value<String?>? riassunto,
    Value<DateTime>? fattaIl,
  }) {
    return AnalisiDelleSchedeCompanion(
      schedaLocale: schedaLocale ?? this.schedaLocale,
      righe: righe ?? this.righe,
      impronta: impronta ?? this.impronta,
      riassunto: riassunto ?? this.riassunto,
      fattaIl: fattaIl ?? this.fattaIl,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (schedaLocale.present) {
      map['scheda_locale'] = Variable<int>(schedaLocale.value);
    }
    if (righe.present) {
      map['righe'] = Variable<String>(righe.value);
    }
    if (impronta.present) {
      map['impronta'] = Variable<String>(impronta.value);
    }
    if (riassunto.present) {
      map['riassunto'] = Variable<String>(riassunto.value);
    }
    if (fattaIl.present) {
      map['fatta_il'] = Variable<DateTime>(fattaIl.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AnalisiDelleSchedeCompanion(')
          ..write('schedaLocale: $schedaLocale, ')
          ..write('righe: $righe, ')
          ..write('impronta: $impronta, ')
          ..write('riassunto: $riassunto, ')
          ..write('fattaIl: $fattaIl')
          ..write(')'))
        .toString();
  }
}

class $VersioniDelleSchedeTable extends VersioniDelleSchede
    with TableInfo<$VersioniDelleSchedeTable, VersioneSchedaSalvata> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VersioniDelleSchedeTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _schedaLocaleMeta = const VerificationMeta(
    'schedaLocale',
  );
  @override
  late final GeneratedColumn<int> schedaLocale = GeneratedColumn<int>(
    'scheda_locale',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quandoMeta = const VerificationMeta('quando');
  @override
  late final GeneratedColumn<DateTime> quando = GeneratedColumn<DateTime>(
    'quando',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _improntaMeta = const VerificationMeta(
    'impronta',
  );
  @override
  late final GeneratedColumn<String> impronta = GeneratedColumn<String>(
    'impronta',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contenutoMeta = const VerificationMeta(
    'contenuto',
  );
  @override
  late final GeneratedColumn<String> contenuto = GeneratedColumn<String>(
    'contenuto',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    schedaLocale,
    quando,
    impronta,
    contenuto,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'versioni_delle_schede';
  @override
  VerificationContext validateIntegrity(
    Insertable<VersioneSchedaSalvata> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('scheda_locale')) {
      context.handle(
        _schedaLocaleMeta,
        schedaLocale.isAcceptableOrUnknown(
          data['scheda_locale']!,
          _schedaLocaleMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_schedaLocaleMeta);
    }
    if (data.containsKey('quando')) {
      context.handle(
        _quandoMeta,
        quando.isAcceptableOrUnknown(data['quando']!, _quandoMeta),
      );
    } else if (isInserting) {
      context.missing(_quandoMeta);
    }
    if (data.containsKey('impronta')) {
      context.handle(
        _improntaMeta,
        impronta.isAcceptableOrUnknown(data['impronta']!, _improntaMeta),
      );
    } else if (isInserting) {
      context.missing(_improntaMeta);
    }
    if (data.containsKey('contenuto')) {
      context.handle(
        _contenutoMeta,
        contenuto.isAcceptableOrUnknown(data['contenuto']!, _contenutoMeta),
      );
    } else if (isInserting) {
      context.missing(_contenutoMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VersioneSchedaSalvata map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VersioneSchedaSalvata(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      schedaLocale: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}scheda_locale'],
      )!,
      quando: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}quando'],
      )!,
      impronta: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}impronta'],
      )!,
      contenuto: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}contenuto'],
      )!,
    );
  }

  @override
  $VersioniDelleSchedeTable createAlias(String alias) {
    return $VersioniDelleSchedeTable(attachedDatabase, alias);
  }
}

class VersioneSchedaSalvata extends DataClass
    implements Insertable<VersioneSchedaSalvata> {
  final int id;

  /// L'id in `SchedeSulTelefono`.
  ///
  /// ⚠️ **Nessuna chiave esterna**, come per `SettimanaProgrammata`: se la
  /// scheda viene cancellata queste righe restano orfane e vengono ignorate.
  /// ⛔ Una cascata cancellerebbe la storia di una scheda cancellata per
  /// sbaglio, che è l'unico momento in cui quella storia servirebbe davvero.
  final int schedaLocale;
  final DateTime quando;

  /// L'impronta di [improntaDellaScheda]: serve a non riscrivere due volte lo
  /// stesso contenuto.
  final String impronta;

  /// Il JSON della scheda, com'era.
  final String contenuto;
  const VersioneSchedaSalvata({
    required this.id,
    required this.schedaLocale,
    required this.quando,
    required this.impronta,
    required this.contenuto,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['scheda_locale'] = Variable<int>(schedaLocale);
    map['quando'] = Variable<DateTime>(quando);
    map['impronta'] = Variable<String>(impronta);
    map['contenuto'] = Variable<String>(contenuto);
    return map;
  }

  VersioniDelleSchedeCompanion toCompanion(bool nullToAbsent) {
    return VersioniDelleSchedeCompanion(
      id: Value(id),
      schedaLocale: Value(schedaLocale),
      quando: Value(quando),
      impronta: Value(impronta),
      contenuto: Value(contenuto),
    );
  }

  factory VersioneSchedaSalvata.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VersioneSchedaSalvata(
      id: serializer.fromJson<int>(json['id']),
      schedaLocale: serializer.fromJson<int>(json['schedaLocale']),
      quando: serializer.fromJson<DateTime>(json['quando']),
      impronta: serializer.fromJson<String>(json['impronta']),
      contenuto: serializer.fromJson<String>(json['contenuto']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'schedaLocale': serializer.toJson<int>(schedaLocale),
      'quando': serializer.toJson<DateTime>(quando),
      'impronta': serializer.toJson<String>(impronta),
      'contenuto': serializer.toJson<String>(contenuto),
    };
  }

  VersioneSchedaSalvata copyWith({
    int? id,
    int? schedaLocale,
    DateTime? quando,
    String? impronta,
    String? contenuto,
  }) => VersioneSchedaSalvata(
    id: id ?? this.id,
    schedaLocale: schedaLocale ?? this.schedaLocale,
    quando: quando ?? this.quando,
    impronta: impronta ?? this.impronta,
    contenuto: contenuto ?? this.contenuto,
  );
  VersioneSchedaSalvata copyWithCompanion(VersioniDelleSchedeCompanion data) {
    return VersioneSchedaSalvata(
      id: data.id.present ? data.id.value : this.id,
      schedaLocale: data.schedaLocale.present
          ? data.schedaLocale.value
          : this.schedaLocale,
      quando: data.quando.present ? data.quando.value : this.quando,
      impronta: data.impronta.present ? data.impronta.value : this.impronta,
      contenuto: data.contenuto.present ? data.contenuto.value : this.contenuto,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VersioneSchedaSalvata(')
          ..write('id: $id, ')
          ..write('schedaLocale: $schedaLocale, ')
          ..write('quando: $quando, ')
          ..write('impronta: $impronta, ')
          ..write('contenuto: $contenuto')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, schedaLocale, quando, impronta, contenuto);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VersioneSchedaSalvata &&
          other.id == this.id &&
          other.schedaLocale == this.schedaLocale &&
          other.quando == this.quando &&
          other.impronta == this.impronta &&
          other.contenuto == this.contenuto);
}

class VersioniDelleSchedeCompanion
    extends UpdateCompanion<VersioneSchedaSalvata> {
  final Value<int> id;
  final Value<int> schedaLocale;
  final Value<DateTime> quando;
  final Value<String> impronta;
  final Value<String> contenuto;
  const VersioniDelleSchedeCompanion({
    this.id = const Value.absent(),
    this.schedaLocale = const Value.absent(),
    this.quando = const Value.absent(),
    this.impronta = const Value.absent(),
    this.contenuto = const Value.absent(),
  });
  VersioniDelleSchedeCompanion.insert({
    this.id = const Value.absent(),
    required int schedaLocale,
    required DateTime quando,
    required String impronta,
    required String contenuto,
  }) : schedaLocale = Value(schedaLocale),
       quando = Value(quando),
       impronta = Value(impronta),
       contenuto = Value(contenuto);
  static Insertable<VersioneSchedaSalvata> custom({
    Expression<int>? id,
    Expression<int>? schedaLocale,
    Expression<DateTime>? quando,
    Expression<String>? impronta,
    Expression<String>? contenuto,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (schedaLocale != null) 'scheda_locale': schedaLocale,
      if (quando != null) 'quando': quando,
      if (impronta != null) 'impronta': impronta,
      if (contenuto != null) 'contenuto': contenuto,
    });
  }

  VersioniDelleSchedeCompanion copyWith({
    Value<int>? id,
    Value<int>? schedaLocale,
    Value<DateTime>? quando,
    Value<String>? impronta,
    Value<String>? contenuto,
  }) {
    return VersioniDelleSchedeCompanion(
      id: id ?? this.id,
      schedaLocale: schedaLocale ?? this.schedaLocale,
      quando: quando ?? this.quando,
      impronta: impronta ?? this.impronta,
      contenuto: contenuto ?? this.contenuto,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (schedaLocale.present) {
      map['scheda_locale'] = Variable<int>(schedaLocale.value);
    }
    if (quando.present) {
      map['quando'] = Variable<DateTime>(quando.value);
    }
    if (impronta.present) {
      map['impronta'] = Variable<String>(impronta.value);
    }
    if (contenuto.present) {
      map['contenuto'] = Variable<String>(contenuto.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VersioniDelleSchedeCompanion(')
          ..write('id: $id, ')
          ..write('schedaLocale: $schedaLocale, ')
          ..write('quando: $quando, ')
          ..write('impronta: $impronta, ')
          ..write('contenuto: $contenuto')
          ..write(')'))
        .toString();
  }
}

class $BruciateDichiarateTable extends BruciateDichiarate
    with TableInfo<$BruciateDichiarateTable, BruciatoDichiarato> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BruciateDichiarateTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _giornoMeta = const VerificationMeta('giorno');
  @override
  late final GeneratedColumn<DateTime> giorno = GeneratedColumn<DateTime>(
    'giorno',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _kcalMeta = const VerificationMeta('kcal');
  @override
  late final GeneratedColumn<int> kcal = GeneratedColumn<int>(
    'kcal',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _daServerMeta = const VerificationMeta(
    'daServer',
  );
  @override
  late final GeneratedColumn<bool> daServer = GeneratedColumn<bool>(
    'da_server',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("da_server" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [id, giorno, kcal, daServer];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bruciate_dichiarate';
  @override
  VerificationContext validateIntegrity(
    Insertable<BruciatoDichiarato> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('giorno')) {
      context.handle(
        _giornoMeta,
        giorno.isAcceptableOrUnknown(data['giorno']!, _giornoMeta),
      );
    } else if (isInserting) {
      context.missing(_giornoMeta);
    }
    if (data.containsKey('kcal')) {
      context.handle(
        _kcalMeta,
        kcal.isAcceptableOrUnknown(data['kcal']!, _kcalMeta),
      );
    } else if (isInserting) {
      context.missing(_kcalMeta);
    }
    if (data.containsKey('da_server')) {
      context.handle(
        _daServerMeta,
        daServer.isAcceptableOrUnknown(data['da_server']!, _daServerMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BruciatoDichiarato map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BruciatoDichiarato(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      giorno: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}giorno'],
      )!,
      kcal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}kcal'],
      )!,
      daServer: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}da_server'],
      )!,
    );
  }

  @override
  $BruciateDichiarateTable createAlias(String alias) {
    return $BruciateDichiarateTable(attachedDatabase, alias);
  }
}

class BruciatoDichiarato extends DataClass
    implements Insertable<BruciatoDichiarato> {
  final int id;

  /// Il giorno locale, a mezzanotte.
  ///
  /// ⚠️ Un `DateTime` e non una stringa `yyyy-mm-dd`: il resto dell'archivio
  /// usa `DateTime` per i giorni, e mescolare due convenzioni nello stesso
  /// database è il modo per confrontare una data con un testo e non accorgersene.
  final DateTime giorno;
  final int kcal;

  /// Se questa riga è **arrivata dal server** col trasloco — FASE 11.3.
  ///
  /// ══ 🚨 SERVE A CONTARE LA COSA GIUSTA ═══════════════════════════════════
  ///
  /// ⚠️ `conteggiDelTrasloco()` deve dire al server **quante delle sue righe**
  /// sono arrivate, non quante righe ci sono in tutto sul telefono. 🚨 Dalla
  /// FASE 11.4 in poi il player scrive in locale: una dichiarazione fatta
  /// **prima** di aver traslocato farebbe sballare il conteggio, il server
  /// risponderebbe `409 conteggi_diversi`, e quella persona non riuscirebbe
  /// **mai più** a confermare — bloccando anche la caduta delle tabelle (11.6).
  ///
  /// 💡 Le sedute questo problema non ce l'hanno: hanno già `idServer`.
  final bool daServer;
  const BruciatoDichiarato({
    required this.id,
    required this.giorno,
    required this.kcal,
    required this.daServer,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['giorno'] = Variable<DateTime>(giorno);
    map['kcal'] = Variable<int>(kcal);
    map['da_server'] = Variable<bool>(daServer);
    return map;
  }

  BruciateDichiarateCompanion toCompanion(bool nullToAbsent) {
    return BruciateDichiarateCompanion(
      id: Value(id),
      giorno: Value(giorno),
      kcal: Value(kcal),
      daServer: Value(daServer),
    );
  }

  factory BruciatoDichiarato.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BruciatoDichiarato(
      id: serializer.fromJson<int>(json['id']),
      giorno: serializer.fromJson<DateTime>(json['giorno']),
      kcal: serializer.fromJson<int>(json['kcal']),
      daServer: serializer.fromJson<bool>(json['daServer']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'giorno': serializer.toJson<DateTime>(giorno),
      'kcal': serializer.toJson<int>(kcal),
      'daServer': serializer.toJson<bool>(daServer),
    };
  }

  BruciatoDichiarato copyWith({
    int? id,
    DateTime? giorno,
    int? kcal,
    bool? daServer,
  }) => BruciatoDichiarato(
    id: id ?? this.id,
    giorno: giorno ?? this.giorno,
    kcal: kcal ?? this.kcal,
    daServer: daServer ?? this.daServer,
  );
  BruciatoDichiarato copyWithCompanion(BruciateDichiarateCompanion data) {
    return BruciatoDichiarato(
      id: data.id.present ? data.id.value : this.id,
      giorno: data.giorno.present ? data.giorno.value : this.giorno,
      kcal: data.kcal.present ? data.kcal.value : this.kcal,
      daServer: data.daServer.present ? data.daServer.value : this.daServer,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BruciatoDichiarato(')
          ..write('id: $id, ')
          ..write('giorno: $giorno, ')
          ..write('kcal: $kcal, ')
          ..write('daServer: $daServer')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, giorno, kcal, daServer);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BruciatoDichiarato &&
          other.id == this.id &&
          other.giorno == this.giorno &&
          other.kcal == this.kcal &&
          other.daServer == this.daServer);
}

class BruciateDichiarateCompanion extends UpdateCompanion<BruciatoDichiarato> {
  final Value<int> id;
  final Value<DateTime> giorno;
  final Value<int> kcal;
  final Value<bool> daServer;
  const BruciateDichiarateCompanion({
    this.id = const Value.absent(),
    this.giorno = const Value.absent(),
    this.kcal = const Value.absent(),
    this.daServer = const Value.absent(),
  });
  BruciateDichiarateCompanion.insert({
    this.id = const Value.absent(),
    required DateTime giorno,
    required int kcal,
    this.daServer = const Value.absent(),
  }) : giorno = Value(giorno),
       kcal = Value(kcal);
  static Insertable<BruciatoDichiarato> custom({
    Expression<int>? id,
    Expression<DateTime>? giorno,
    Expression<int>? kcal,
    Expression<bool>? daServer,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (giorno != null) 'giorno': giorno,
      if (kcal != null) 'kcal': kcal,
      if (daServer != null) 'da_server': daServer,
    });
  }

  BruciateDichiarateCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? giorno,
    Value<int>? kcal,
    Value<bool>? daServer,
  }) {
    return BruciateDichiarateCompanion(
      id: id ?? this.id,
      giorno: giorno ?? this.giorno,
      kcal: kcal ?? this.kcal,
      daServer: daServer ?? this.daServer,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (giorno.present) {
      map['giorno'] = Variable<DateTime>(giorno.value);
    }
    if (kcal.present) {
      map['kcal'] = Variable<int>(kcal.value);
    }
    if (daServer.present) {
      map['da_server'] = Variable<bool>(daServer.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BruciateDichiarateCompanion(')
          ..write('id: $id, ')
          ..write('giorno: $giorno, ')
          ..write('kcal: $kcal, ')
          ..write('daServer: $daServer')
          ..write(')'))
        .toString();
  }
}

class $SchedeSulTelefonoTable extends SchedeSulTelefono
    with TableInfo<$SchedeSulTelefonoTable, SchedaSulTelefono> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SchedeSulTelefonoTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nomeMeta = const VerificationMeta('nome');
  @override
  late final GeneratedColumn<String> nome = GeneratedColumn<String>(
    'nome',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _schedaMeta = const VerificationMeta('scheda');
  @override
  late final GeneratedColumn<String> scheda = GeneratedColumn<String>(
    'scheda',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _aggiornataIlMeta = const VerificationMeta(
    'aggiornataIl',
  );
  @override
  late final GeneratedColumn<DateTime> aggiornataIl = GeneratedColumn<DateTime>(
    'aggiornata_il',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _creataIlMeta = const VerificationMeta(
    'creataIl',
  );
  @override
  late final GeneratedColumn<DateTime> creataIl = GeneratedColumn<DateTime>(
    'creata_il',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _miaMeta = const VerificationMeta('mia');
  @override
  late final GeneratedColumn<bool> mia = GeneratedColumn<bool>(
    'mia',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("mia" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _origineMeta = const VerificationMeta(
    'origine',
  );
  @override
  late final GeneratedColumn<String> origine = GeneratedColumn<String>(
    'origine',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idOrigineMeta = const VerificationMeta(
    'idOrigine',
  );
  @override
  late final GeneratedColumn<int> idOrigine = GeneratedColumn<int>(
    'id_origine',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _origineIdStabileMeta = const VerificationMeta(
    'origineIdStabile',
  );
  @override
  late final GeneratedColumn<String> origineIdStabile = GeneratedColumn<String>(
    'origine_id_stabile',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    nome,
    scheda,
    aggiornataIl,
    creataIl,
    mia,
    origine,
    idOrigine,
    origineIdStabile,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'schede_sul_telefono';
  @override
  VerificationContext validateIntegrity(
    Insertable<SchedaSulTelefono> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('nome')) {
      context.handle(
        _nomeMeta,
        nome.isAcceptableOrUnknown(data['nome']!, _nomeMeta),
      );
    } else if (isInserting) {
      context.missing(_nomeMeta);
    }
    if (data.containsKey('scheda')) {
      context.handle(
        _schedaMeta,
        scheda.isAcceptableOrUnknown(data['scheda']!, _schedaMeta),
      );
    } else if (isInserting) {
      context.missing(_schedaMeta);
    }
    if (data.containsKey('aggiornata_il')) {
      context.handle(
        _aggiornataIlMeta,
        aggiornataIl.isAcceptableOrUnknown(
          data['aggiornata_il']!,
          _aggiornataIlMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_aggiornataIlMeta);
    }
    if (data.containsKey('creata_il')) {
      context.handle(
        _creataIlMeta,
        creataIl.isAcceptableOrUnknown(data['creata_il']!, _creataIlMeta),
      );
    }
    if (data.containsKey('mia')) {
      context.handle(
        _miaMeta,
        mia.isAcceptableOrUnknown(data['mia']!, _miaMeta),
      );
    }
    if (data.containsKey('origine')) {
      context.handle(
        _origineMeta,
        origine.isAcceptableOrUnknown(data['origine']!, _origineMeta),
      );
    } else if (isInserting) {
      context.missing(_origineMeta);
    }
    if (data.containsKey('id_origine')) {
      context.handle(
        _idOrigineMeta,
        idOrigine.isAcceptableOrUnknown(data['id_origine']!, _idOrigineMeta),
      );
    }
    if (data.containsKey('origine_id_stabile')) {
      context.handle(
        _origineIdStabileMeta,
        origineIdStabile.isAcceptableOrUnknown(
          data['origine_id_stabile']!,
          _origineIdStabileMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {origine, idOrigine},
  ];
  @override
  SchedaSulTelefono map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SchedaSulTelefono(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      nome: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nome'],
      )!,
      scheda: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scheda'],
      )!,
      aggiornataIl: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}aggiornata_il'],
      )!,
      creataIl: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}creata_il'],
      ),
      mia: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}mia'],
      )!,
      origine: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origine'],
      )!,
      idOrigine: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id_origine'],
      ),
      origineIdStabile: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origine_id_stabile'],
      ),
    );
  }

  @override
  $SchedeSulTelefonoTable createAlias(String alias) {
    return $SchedeSulTelefonoTable(attachedDatabase, alias);
  }
}

class SchedaSulTelefono extends DataClass
    implements Insertable<SchedaSulTelefono> {
  /// L'id della scheda **su questo telefono**.
  ///
  /// ⛔ Qui c'era il trucco degli id firmati — positivi per quelle del server,
  /// negativi per quelle scritte qui — che serviva a tenere separati due spazi
  /// di id. 💡 Con una tabella sola non c'è niente da tenere separato, e un id
  /// firmato è una convenzione che prima o poi qualcuno viola: da dove viene
  /// una scheda lo dice `origine`, che è un dato, non un segno.
  ///
  /// ⚠️ **Gli id già assegnati non cambiano**: la migrazione ricopia le righe
  /// così come sono, perché `AllenamentiDaOrologio.schedaAssegnata` punta qui —
  /// rinumerarli vorrebbe dire spostare in silenzio gli allenamenti già fatti
  /// su schede diverse da quelle vere.
  final int id;

  /// Il nome, per non dover aprire il JSON a ogni riga di un elenco.
  final String nome;

  /// La scheda intera, serializzata.
  final String scheda;

  /// Quando è stata toccata l'ultima volta, **su questo telefono**.
  final DateTime aggiornataIl;

  /// Quando è **arrivata**, o è stata scritta — 3b-C.6.
  ///
  /// 📌 Serve al limite di chi non è abbonato: *«le ultime 3 per data di
  /// creazione»*.
  ///
  /// 🚨 **Non è `aggiornataIl`, e la differenza è tutta qui.** Quella cambia a
  /// ogni modifica: rinominare una scheda di marzo la porterebbe in cima e
  /// scavalcherebbe una arrivata ieri, cioè **sbloccherebbe la vecchia
  /// bloccando la nuova**. Un limite che si aggira rinominando non è un limite.
  ///
  /// ⚠️ **Nullable**, perché le righe che c'erano prima una data di nascita non
  /// ce l'hanno: chi legge cade su `aggiornataIl`, che per quelle è la stima
  /// migliore disponibile. ⛔ Riempirla con `DateTime.now()` in migrazione
  /// avrebbe dato a tutte le schede vecchie la stessa età — quella del giorno
  /// dell'aggiornamento — e l'ordine sarebbe stato casuale.
  final DateTime? creataIl;

  /// Se la si può modificare.
  ///
  /// ⚠️ `false` per quelle del trainer: si eseguono, non si cambiano. ⛔ E se
  /// serve una versione nuova **la rimanda lui** — è la decisione del 24/08, ed
  /// è il motivo per cui non c'è nessuna sincronizzazione da nessuna parte.
  final bool mia;

  /// Da dove viene: `'chat'`, `'server'` o `'mia'`.
  ///
  /// 🚨 **Serve a non confondere due id che si somigliano.** Il numero in
  /// `idOrigine` è un id di messaggio per le schede della chat e un id di
  /// scheda per quelle scese dal server: sono due numerazioni diverse, e senza
  /// questa colonna il messaggio 8 e la scheda 8 sarebbero la stessa riga.
  final String origine;

  /// Il numero che identifica la scheda **là da dove viene**.
  ///
  /// 💡 `messaggioId` per la chat, l'id del server per le altre. ⚠️ `null` per
  /// quelle scritte qui, che non vengono da nessuna parte — e i `NULL` in
  /// SQLite non collidono fra loro, quindi la chiave unica qui sotto non
  /// impedisce di scriversene quante se ne vuole.
  final int? idOrigine;

  /// 🚨 **L'identità stabile della scheda** — D15.
  ///
  /// È ciò che permette di riconoscere che una scheda arrivata è la **versione
  /// nuova** di una che c'è già, e di sostituirla invece di affiancarla. È
  /// anche ciò che si ricorda quando la si butta, perché non torni da sola al
  /// messaggio successivo.
  ///
  /// ⚠️ **Nullable**: le buste `v1` non ce l'hanno, e chi arriva senza cade sul
  /// comportamento vecchio — una riga per messaggio — che è corretto, solo meno
  /// furbo.
  final String? origineIdStabile;
  const SchedaSulTelefono({
    required this.id,
    required this.nome,
    required this.scheda,
    required this.aggiornataIl,
    this.creataIl,
    required this.mia,
    required this.origine,
    this.idOrigine,
    this.origineIdStabile,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['nome'] = Variable<String>(nome);
    map['scheda'] = Variable<String>(scheda);
    map['aggiornata_il'] = Variable<DateTime>(aggiornataIl);
    if (!nullToAbsent || creataIl != null) {
      map['creata_il'] = Variable<DateTime>(creataIl);
    }
    map['mia'] = Variable<bool>(mia);
    map['origine'] = Variable<String>(origine);
    if (!nullToAbsent || idOrigine != null) {
      map['id_origine'] = Variable<int>(idOrigine);
    }
    if (!nullToAbsent || origineIdStabile != null) {
      map['origine_id_stabile'] = Variable<String>(origineIdStabile);
    }
    return map;
  }

  SchedeSulTelefonoCompanion toCompanion(bool nullToAbsent) {
    return SchedeSulTelefonoCompanion(
      id: Value(id),
      nome: Value(nome),
      scheda: Value(scheda),
      aggiornataIl: Value(aggiornataIl),
      creataIl: creataIl == null && nullToAbsent
          ? const Value.absent()
          : Value(creataIl),
      mia: Value(mia),
      origine: Value(origine),
      idOrigine: idOrigine == null && nullToAbsent
          ? const Value.absent()
          : Value(idOrigine),
      origineIdStabile: origineIdStabile == null && nullToAbsent
          ? const Value.absent()
          : Value(origineIdStabile),
    );
  }

  factory SchedaSulTelefono.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SchedaSulTelefono(
      id: serializer.fromJson<int>(json['id']),
      nome: serializer.fromJson<String>(json['nome']),
      scheda: serializer.fromJson<String>(json['scheda']),
      aggiornataIl: serializer.fromJson<DateTime>(json['aggiornataIl']),
      creataIl: serializer.fromJson<DateTime?>(json['creataIl']),
      mia: serializer.fromJson<bool>(json['mia']),
      origine: serializer.fromJson<String>(json['origine']),
      idOrigine: serializer.fromJson<int?>(json['idOrigine']),
      origineIdStabile: serializer.fromJson<String?>(json['origineIdStabile']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'nome': serializer.toJson<String>(nome),
      'scheda': serializer.toJson<String>(scheda),
      'aggiornataIl': serializer.toJson<DateTime>(aggiornataIl),
      'creataIl': serializer.toJson<DateTime?>(creataIl),
      'mia': serializer.toJson<bool>(mia),
      'origine': serializer.toJson<String>(origine),
      'idOrigine': serializer.toJson<int?>(idOrigine),
      'origineIdStabile': serializer.toJson<String?>(origineIdStabile),
    };
  }

  SchedaSulTelefono copyWith({
    int? id,
    String? nome,
    String? scheda,
    DateTime? aggiornataIl,
    Value<DateTime?> creataIl = const Value.absent(),
    bool? mia,
    String? origine,
    Value<int?> idOrigine = const Value.absent(),
    Value<String?> origineIdStabile = const Value.absent(),
  }) => SchedaSulTelefono(
    id: id ?? this.id,
    nome: nome ?? this.nome,
    scheda: scheda ?? this.scheda,
    aggiornataIl: aggiornataIl ?? this.aggiornataIl,
    creataIl: creataIl.present ? creataIl.value : this.creataIl,
    mia: mia ?? this.mia,
    origine: origine ?? this.origine,
    idOrigine: idOrigine.present ? idOrigine.value : this.idOrigine,
    origineIdStabile: origineIdStabile.present
        ? origineIdStabile.value
        : this.origineIdStabile,
  );
  SchedaSulTelefono copyWithCompanion(SchedeSulTelefonoCompanion data) {
    return SchedaSulTelefono(
      id: data.id.present ? data.id.value : this.id,
      nome: data.nome.present ? data.nome.value : this.nome,
      scheda: data.scheda.present ? data.scheda.value : this.scheda,
      aggiornataIl: data.aggiornataIl.present
          ? data.aggiornataIl.value
          : this.aggiornataIl,
      creataIl: data.creataIl.present ? data.creataIl.value : this.creataIl,
      mia: data.mia.present ? data.mia.value : this.mia,
      origine: data.origine.present ? data.origine.value : this.origine,
      idOrigine: data.idOrigine.present ? data.idOrigine.value : this.idOrigine,
      origineIdStabile: data.origineIdStabile.present
          ? data.origineIdStabile.value
          : this.origineIdStabile,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SchedaSulTelefono(')
          ..write('id: $id, ')
          ..write('nome: $nome, ')
          ..write('scheda: $scheda, ')
          ..write('aggiornataIl: $aggiornataIl, ')
          ..write('creataIl: $creataIl, ')
          ..write('mia: $mia, ')
          ..write('origine: $origine, ')
          ..write('idOrigine: $idOrigine, ')
          ..write('origineIdStabile: $origineIdStabile')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    nome,
    scheda,
    aggiornataIl,
    creataIl,
    mia,
    origine,
    idOrigine,
    origineIdStabile,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SchedaSulTelefono &&
          other.id == this.id &&
          other.nome == this.nome &&
          other.scheda == this.scheda &&
          other.aggiornataIl == this.aggiornataIl &&
          other.creataIl == this.creataIl &&
          other.mia == this.mia &&
          other.origine == this.origine &&
          other.idOrigine == this.idOrigine &&
          other.origineIdStabile == this.origineIdStabile);
}

class SchedeSulTelefonoCompanion extends UpdateCompanion<SchedaSulTelefono> {
  final Value<int> id;
  final Value<String> nome;
  final Value<String> scheda;
  final Value<DateTime> aggiornataIl;
  final Value<DateTime?> creataIl;
  final Value<bool> mia;
  final Value<String> origine;
  final Value<int?> idOrigine;
  final Value<String?> origineIdStabile;
  const SchedeSulTelefonoCompanion({
    this.id = const Value.absent(),
    this.nome = const Value.absent(),
    this.scheda = const Value.absent(),
    this.aggiornataIl = const Value.absent(),
    this.creataIl = const Value.absent(),
    this.mia = const Value.absent(),
    this.origine = const Value.absent(),
    this.idOrigine = const Value.absent(),
    this.origineIdStabile = const Value.absent(),
  });
  SchedeSulTelefonoCompanion.insert({
    this.id = const Value.absent(),
    required String nome,
    required String scheda,
    required DateTime aggiornataIl,
    this.creataIl = const Value.absent(),
    this.mia = const Value.absent(),
    required String origine,
    this.idOrigine = const Value.absent(),
    this.origineIdStabile = const Value.absent(),
  }) : nome = Value(nome),
       scheda = Value(scheda),
       aggiornataIl = Value(aggiornataIl),
       origine = Value(origine);
  static Insertable<SchedaSulTelefono> custom({
    Expression<int>? id,
    Expression<String>? nome,
    Expression<String>? scheda,
    Expression<DateTime>? aggiornataIl,
    Expression<DateTime>? creataIl,
    Expression<bool>? mia,
    Expression<String>? origine,
    Expression<int>? idOrigine,
    Expression<String>? origineIdStabile,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (nome != null) 'nome': nome,
      if (scheda != null) 'scheda': scheda,
      if (aggiornataIl != null) 'aggiornata_il': aggiornataIl,
      if (creataIl != null) 'creata_il': creataIl,
      if (mia != null) 'mia': mia,
      if (origine != null) 'origine': origine,
      if (idOrigine != null) 'id_origine': idOrigine,
      if (origineIdStabile != null) 'origine_id_stabile': origineIdStabile,
    });
  }

  SchedeSulTelefonoCompanion copyWith({
    Value<int>? id,
    Value<String>? nome,
    Value<String>? scheda,
    Value<DateTime>? aggiornataIl,
    Value<DateTime?>? creataIl,
    Value<bool>? mia,
    Value<String>? origine,
    Value<int?>? idOrigine,
    Value<String?>? origineIdStabile,
  }) {
    return SchedeSulTelefonoCompanion(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      scheda: scheda ?? this.scheda,
      aggiornataIl: aggiornataIl ?? this.aggiornataIl,
      creataIl: creataIl ?? this.creataIl,
      mia: mia ?? this.mia,
      origine: origine ?? this.origine,
      idOrigine: idOrigine ?? this.idOrigine,
      origineIdStabile: origineIdStabile ?? this.origineIdStabile,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (nome.present) {
      map['nome'] = Variable<String>(nome.value);
    }
    if (scheda.present) {
      map['scheda'] = Variable<String>(scheda.value);
    }
    if (aggiornataIl.present) {
      map['aggiornata_il'] = Variable<DateTime>(aggiornataIl.value);
    }
    if (creataIl.present) {
      map['creata_il'] = Variable<DateTime>(creataIl.value);
    }
    if (mia.present) {
      map['mia'] = Variable<bool>(mia.value);
    }
    if (origine.present) {
      map['origine'] = Variable<String>(origine.value);
    }
    if (idOrigine.present) {
      map['id_origine'] = Variable<int>(idOrigine.value);
    }
    if (origineIdStabile.present) {
      map['origine_id_stabile'] = Variable<String>(origineIdStabile.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SchedeSulTelefonoCompanion(')
          ..write('id: $id, ')
          ..write('nome: $nome, ')
          ..write('scheda: $scheda, ')
          ..write('aggiornataIl: $aggiornataIl, ')
          ..write('creataIl: $creataIl, ')
          ..write('mia: $mia, ')
          ..write('origine: $origine, ')
          ..write('idOrigine: $idOrigine, ')
          ..write('origineIdStabile: $origineIdStabile')
          ..write(')'))
        .toString();
  }
}

class $VociDiarioTable extends VociDiario
    with TableInfo<$VociDiarioTable, VoceDiario> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VociDiarioTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _idSulServerMeta = const VerificationMeta(
    'idSulServer',
  );
  @override
  late final GeneratedColumn<int> idSulServer = GeneratedColumn<int>(
    'id_sul_server',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mangiatoIlMeta = const VerificationMeta(
    'mangiatoIl',
  );
  @override
  late final GeneratedColumn<DateTime> mangiatoIl = GeneratedColumn<DateTime>(
    'mangiato_il',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pastoMeta = const VerificationMeta('pasto');
  @override
  late final GeneratedColumn<String> pasto = GeneratedColumn<String>(
    'pasto',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 24,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descrizioneMeta = const VerificationMeta(
    'descrizione',
  );
  @override
  late final GeneratedColumn<String> descrizione = GeneratedColumn<String>(
    'descrizione',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 255,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _grammiMeta = const VerificationMeta('grammi');
  @override
  late final GeneratedColumn<double> grammi = GeneratedColumn<double>(
    'grammi',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _quantitaMeta = const VerificationMeta(
    'quantita',
  );
  @override
  late final GeneratedColumn<double> quantita = GeneratedColumn<double>(
    'quantita',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _unitaMeta = const VerificationMeta('unita');
  @override
  late final GeneratedColumn<String> unita = GeneratedColumn<String>(
    'unita',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 16,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _kcalMeta = const VerificationMeta('kcal');
  @override
  late final GeneratedColumn<double> kcal = GeneratedColumn<double>(
    'kcal',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _proteineMeta = const VerificationMeta(
    'proteine',
  );
  @override
  late final GeneratedColumn<double> proteine = GeneratedColumn<double>(
    'proteine',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _carboidratiMeta = const VerificationMeta(
    'carboidrati',
  );
  @override
  late final GeneratedColumn<double> carboidrati = GeneratedColumn<double>(
    'carboidrati',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _grassiMeta = const VerificationMeta('grassi');
  @override
  late final GeneratedColumn<double> grassi = GeneratedColumn<double>(
    'grassi',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _kcal100Meta = const VerificationMeta(
    'kcal100',
  );
  @override
  late final GeneratedColumn<double> kcal100 = GeneratedColumn<double>(
    'kcal100',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _proteine100Meta = const VerificationMeta(
    'proteine100',
  );
  @override
  late final GeneratedColumn<double> proteine100 = GeneratedColumn<double>(
    'proteine100',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _carboidrati100Meta = const VerificationMeta(
    'carboidrati100',
  );
  @override
  late final GeneratedColumn<double> carboidrati100 = GeneratedColumn<double>(
    'carboidrati100',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _grassi100Meta = const VerificationMeta(
    'grassi100',
  );
  @override
  late final GeneratedColumn<double> grassi100 = GeneratedColumn<double>(
    'grassi100',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fonteMeta = const VerificationMeta('fonte');
  @override
  late final GeneratedColumn<String> fonte = GeneratedColumn<String>(
    'fonte',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 16,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('manual'),
  );
  static const VerificationMeta _aiGrezzoMeta = const VerificationMeta(
    'aiGrezzo',
  );
  @override
  late final GeneratedColumn<String> aiGrezzo = GeneratedColumn<String>(
    'ai_grezzo',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pianoIdMeta = const VerificationMeta(
    'pianoId',
  );
  @override
  late final GeneratedColumn<int> pianoId = GeneratedColumn<int>(
    'piano_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _alimentoIdMeta = const VerificationMeta(
    'alimentoId',
  );
  @override
  late final GeneratedColumn<int> alimentoId = GeneratedColumn<int>(
    'alimento_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scrittaIlMeta = const VerificationMeta(
    'scrittaIl',
  );
  @override
  late final GeneratedColumn<DateTime> scrittaIl = GeneratedColumn<DateTime>(
    'scritta_il',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    idSulServer,
    mangiatoIl,
    pasto,
    descrizione,
    grammi,
    quantita,
    unita,
    kcal,
    proteine,
    carboidrati,
    grassi,
    kcal100,
    proteine100,
    carboidrati100,
    grassi100,
    fonte,
    aiGrezzo,
    pianoId,
    alimentoId,
    scrittaIl,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'voci_diario';
  @override
  VerificationContext validateIntegrity(
    Insertable<VoceDiario> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('id_sul_server')) {
      context.handle(
        _idSulServerMeta,
        idSulServer.isAcceptableOrUnknown(
          data['id_sul_server']!,
          _idSulServerMeta,
        ),
      );
    }
    if (data.containsKey('mangiato_il')) {
      context.handle(
        _mangiatoIlMeta,
        mangiatoIl.isAcceptableOrUnknown(data['mangiato_il']!, _mangiatoIlMeta),
      );
    } else if (isInserting) {
      context.missing(_mangiatoIlMeta);
    }
    if (data.containsKey('pasto')) {
      context.handle(
        _pastoMeta,
        pasto.isAcceptableOrUnknown(data['pasto']!, _pastoMeta),
      );
    } else if (isInserting) {
      context.missing(_pastoMeta);
    }
    if (data.containsKey('descrizione')) {
      context.handle(
        _descrizioneMeta,
        descrizione.isAcceptableOrUnknown(
          data['descrizione']!,
          _descrizioneMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_descrizioneMeta);
    }
    if (data.containsKey('grammi')) {
      context.handle(
        _grammiMeta,
        grammi.isAcceptableOrUnknown(data['grammi']!, _grammiMeta),
      );
    }
    if (data.containsKey('quantita')) {
      context.handle(
        _quantitaMeta,
        quantita.isAcceptableOrUnknown(data['quantita']!, _quantitaMeta),
      );
    }
    if (data.containsKey('unita')) {
      context.handle(
        _unitaMeta,
        unita.isAcceptableOrUnknown(data['unita']!, _unitaMeta),
      );
    }
    if (data.containsKey('kcal')) {
      context.handle(
        _kcalMeta,
        kcal.isAcceptableOrUnknown(data['kcal']!, _kcalMeta),
      );
    }
    if (data.containsKey('proteine')) {
      context.handle(
        _proteineMeta,
        proteine.isAcceptableOrUnknown(data['proteine']!, _proteineMeta),
      );
    }
    if (data.containsKey('carboidrati')) {
      context.handle(
        _carboidratiMeta,
        carboidrati.isAcceptableOrUnknown(
          data['carboidrati']!,
          _carboidratiMeta,
        ),
      );
    }
    if (data.containsKey('grassi')) {
      context.handle(
        _grassiMeta,
        grassi.isAcceptableOrUnknown(data['grassi']!, _grassiMeta),
      );
    }
    if (data.containsKey('kcal100')) {
      context.handle(
        _kcal100Meta,
        kcal100.isAcceptableOrUnknown(data['kcal100']!, _kcal100Meta),
      );
    }
    if (data.containsKey('proteine100')) {
      context.handle(
        _proteine100Meta,
        proteine100.isAcceptableOrUnknown(
          data['proteine100']!,
          _proteine100Meta,
        ),
      );
    }
    if (data.containsKey('carboidrati100')) {
      context.handle(
        _carboidrati100Meta,
        carboidrati100.isAcceptableOrUnknown(
          data['carboidrati100']!,
          _carboidrati100Meta,
        ),
      );
    }
    if (data.containsKey('grassi100')) {
      context.handle(
        _grassi100Meta,
        grassi100.isAcceptableOrUnknown(data['grassi100']!, _grassi100Meta),
      );
    }
    if (data.containsKey('fonte')) {
      context.handle(
        _fonteMeta,
        fonte.isAcceptableOrUnknown(data['fonte']!, _fonteMeta),
      );
    }
    if (data.containsKey('ai_grezzo')) {
      context.handle(
        _aiGrezzoMeta,
        aiGrezzo.isAcceptableOrUnknown(data['ai_grezzo']!, _aiGrezzoMeta),
      );
    }
    if (data.containsKey('piano_id')) {
      context.handle(
        _pianoIdMeta,
        pianoId.isAcceptableOrUnknown(data['piano_id']!, _pianoIdMeta),
      );
    }
    if (data.containsKey('alimento_id')) {
      context.handle(
        _alimentoIdMeta,
        alimentoId.isAcceptableOrUnknown(data['alimento_id']!, _alimentoIdMeta),
      );
    }
    if (data.containsKey('scritta_il')) {
      context.handle(
        _scrittaIlMeta,
        scrittaIl.isAcceptableOrUnknown(data['scritta_il']!, _scrittaIlMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {idSulServer},
  ];
  @override
  VoceDiario map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VoceDiario(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      idSulServer: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id_sul_server'],
      ),
      mangiatoIl: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}mangiato_il'],
      )!,
      pasto: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pasto'],
      )!,
      descrizione: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}descrizione'],
      )!,
      grammi: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}grammi'],
      ),
      quantita: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}quantita'],
      ),
      unita: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unita'],
      ),
      kcal: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}kcal'],
      ),
      proteine: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}proteine'],
      ),
      carboidrati: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}carboidrati'],
      ),
      grassi: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}grassi'],
      ),
      kcal100: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}kcal100'],
      ),
      proteine100: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}proteine100'],
      ),
      carboidrati100: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}carboidrati100'],
      ),
      grassi100: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}grassi100'],
      ),
      fonte: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fonte'],
      )!,
      aiGrezzo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ai_grezzo'],
      ),
      pianoId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}piano_id'],
      ),
      alimentoId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}alimento_id'],
      ),
      scrittaIl: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}scritta_il'],
      )!,
    );
  }

  @override
  $VociDiarioTable createAlias(String alias) {
    return $VociDiarioTable(attachedDatabase, alias);
  }
}

class VoceDiario extends DataClass implements Insertable<VoceDiario> {
  final int id;

  /// L'id che questa riga aveva su `food_entries`. Vedi la nota in testa.
  final int? idSulServer;

  /// Quando è stata mangiata.
  ///
  /// ⚠️ **Oggi l'app manda la mezzanotte del giorno scelto**, non l'ora vera:
  /// `eaten_at` sul server vale `selectedDate`. 🚨 Qui si conserva così com'è
  /// per non inventare un'ora che non è mai stata misurata — e per sapere
  /// *quando* una voce è stata scritta c'è [scrittaIl], che è un dato vero.
  final DateTime mangiatoIl;

  /// `breakfast`, `morning_snack`, `lunch`, `afternoon_snack`, `dinner`,
  /// `evening_snack`. 💡 La **chiave**, non l'etichetta: le etichette cambiano.
  final String pasto;
  final String descrizione;
  final double? grammi;
  final double? quantita;
  final String? unita;
  final double? kcal;
  final double? proteine;
  final double? carboidrati;
  final double? grassi;

  /// I valori per 100 g/ml, che servono a ricalcolare quando si corregge la
  /// quantità. ⛔ Senza, cambiare «100 g» in «150 g» richiederebbe di
  /// richiedere la stima da capo — cioè di pagare un gettone per una moltiplicazione.
  final double? kcal100;
  final double? proteine100;
  final double? carboidrati100;
  final double? grassi100;

  /// `manual`, `ai_text`, `ai_photo`, `plan`, `favorite`, `catalog`…
  ///
  /// 💡 È quello che permette di dire «questo numero l'ha stimato l'AI» accanto
  /// alla voce, ed è anche l'unico modo di sapere **quanto** ci si può fidare.
  final String fonte;

  /// La risposta grezza del modello, quando la voce viene da una stima.
  ///
  /// ⚠️ Serve a spiegare un numero che qualcuno contesta — *«non è stato
  /// specificato se sono panate»* — ed è il campo che il 12/08 ha spiegato una
  /// stima sbagliata mentre `confidence` diceva 0.85.
  final String? aiGrezzo;

  /// Da quale piano alimentare viene, se viene da un piano.
  final int? pianoId;

  /// L'alimento del catalogo condiviso, se è stato riconosciuto.
  ///
  /// 🚨 **Il catalogo resta sul server** ed è giusto così: non è di nessuno.
  /// Qui c'è solo il riferimento.
  final int? alimentoId;

  /// Quando la riga è stata **scritta**, che è un'altra cosa da [mangiatoIl].
  ///
  /// 💡 È il campo che distingue una cena **programmata** alle 10 del mattino da
  /// una cena mangiata alle 21 — la stessa distinzione che il consiglio del
  /// giorno usa da 3b-AC, dove si chiama `scritto_alle` e viene da `created_at`.
  final DateTime scrittaIl;
  const VoceDiario({
    required this.id,
    this.idSulServer,
    required this.mangiatoIl,
    required this.pasto,
    required this.descrizione,
    this.grammi,
    this.quantita,
    this.unita,
    this.kcal,
    this.proteine,
    this.carboidrati,
    this.grassi,
    this.kcal100,
    this.proteine100,
    this.carboidrati100,
    this.grassi100,
    required this.fonte,
    this.aiGrezzo,
    this.pianoId,
    this.alimentoId,
    required this.scrittaIl,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || idSulServer != null) {
      map['id_sul_server'] = Variable<int>(idSulServer);
    }
    map['mangiato_il'] = Variable<DateTime>(mangiatoIl);
    map['pasto'] = Variable<String>(pasto);
    map['descrizione'] = Variable<String>(descrizione);
    if (!nullToAbsent || grammi != null) {
      map['grammi'] = Variable<double>(grammi);
    }
    if (!nullToAbsent || quantita != null) {
      map['quantita'] = Variable<double>(quantita);
    }
    if (!nullToAbsent || unita != null) {
      map['unita'] = Variable<String>(unita);
    }
    if (!nullToAbsent || kcal != null) {
      map['kcal'] = Variable<double>(kcal);
    }
    if (!nullToAbsent || proteine != null) {
      map['proteine'] = Variable<double>(proteine);
    }
    if (!nullToAbsent || carboidrati != null) {
      map['carboidrati'] = Variable<double>(carboidrati);
    }
    if (!nullToAbsent || grassi != null) {
      map['grassi'] = Variable<double>(grassi);
    }
    if (!nullToAbsent || kcal100 != null) {
      map['kcal100'] = Variable<double>(kcal100);
    }
    if (!nullToAbsent || proteine100 != null) {
      map['proteine100'] = Variable<double>(proteine100);
    }
    if (!nullToAbsent || carboidrati100 != null) {
      map['carboidrati100'] = Variable<double>(carboidrati100);
    }
    if (!nullToAbsent || grassi100 != null) {
      map['grassi100'] = Variable<double>(grassi100);
    }
    map['fonte'] = Variable<String>(fonte);
    if (!nullToAbsent || aiGrezzo != null) {
      map['ai_grezzo'] = Variable<String>(aiGrezzo);
    }
    if (!nullToAbsent || pianoId != null) {
      map['piano_id'] = Variable<int>(pianoId);
    }
    if (!nullToAbsent || alimentoId != null) {
      map['alimento_id'] = Variable<int>(alimentoId);
    }
    map['scritta_il'] = Variable<DateTime>(scrittaIl);
    return map;
  }

  VociDiarioCompanion toCompanion(bool nullToAbsent) {
    return VociDiarioCompanion(
      id: Value(id),
      idSulServer: idSulServer == null && nullToAbsent
          ? const Value.absent()
          : Value(idSulServer),
      mangiatoIl: Value(mangiatoIl),
      pasto: Value(pasto),
      descrizione: Value(descrizione),
      grammi: grammi == null && nullToAbsent
          ? const Value.absent()
          : Value(grammi),
      quantita: quantita == null && nullToAbsent
          ? const Value.absent()
          : Value(quantita),
      unita: unita == null && nullToAbsent
          ? const Value.absent()
          : Value(unita),
      kcal: kcal == null && nullToAbsent ? const Value.absent() : Value(kcal),
      proteine: proteine == null && nullToAbsent
          ? const Value.absent()
          : Value(proteine),
      carboidrati: carboidrati == null && nullToAbsent
          ? const Value.absent()
          : Value(carboidrati),
      grassi: grassi == null && nullToAbsent
          ? const Value.absent()
          : Value(grassi),
      kcal100: kcal100 == null && nullToAbsent
          ? const Value.absent()
          : Value(kcal100),
      proteine100: proteine100 == null && nullToAbsent
          ? const Value.absent()
          : Value(proteine100),
      carboidrati100: carboidrati100 == null && nullToAbsent
          ? const Value.absent()
          : Value(carboidrati100),
      grassi100: grassi100 == null && nullToAbsent
          ? const Value.absent()
          : Value(grassi100),
      fonte: Value(fonte),
      aiGrezzo: aiGrezzo == null && nullToAbsent
          ? const Value.absent()
          : Value(aiGrezzo),
      pianoId: pianoId == null && nullToAbsent
          ? const Value.absent()
          : Value(pianoId),
      alimentoId: alimentoId == null && nullToAbsent
          ? const Value.absent()
          : Value(alimentoId),
      scrittaIl: Value(scrittaIl),
    );
  }

  factory VoceDiario.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VoceDiario(
      id: serializer.fromJson<int>(json['id']),
      idSulServer: serializer.fromJson<int?>(json['idSulServer']),
      mangiatoIl: serializer.fromJson<DateTime>(json['mangiatoIl']),
      pasto: serializer.fromJson<String>(json['pasto']),
      descrizione: serializer.fromJson<String>(json['descrizione']),
      grammi: serializer.fromJson<double?>(json['grammi']),
      quantita: serializer.fromJson<double?>(json['quantita']),
      unita: serializer.fromJson<String?>(json['unita']),
      kcal: serializer.fromJson<double?>(json['kcal']),
      proteine: serializer.fromJson<double?>(json['proteine']),
      carboidrati: serializer.fromJson<double?>(json['carboidrati']),
      grassi: serializer.fromJson<double?>(json['grassi']),
      kcal100: serializer.fromJson<double?>(json['kcal100']),
      proteine100: serializer.fromJson<double?>(json['proteine100']),
      carboidrati100: serializer.fromJson<double?>(json['carboidrati100']),
      grassi100: serializer.fromJson<double?>(json['grassi100']),
      fonte: serializer.fromJson<String>(json['fonte']),
      aiGrezzo: serializer.fromJson<String?>(json['aiGrezzo']),
      pianoId: serializer.fromJson<int?>(json['pianoId']),
      alimentoId: serializer.fromJson<int?>(json['alimentoId']),
      scrittaIl: serializer.fromJson<DateTime>(json['scrittaIl']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'idSulServer': serializer.toJson<int?>(idSulServer),
      'mangiatoIl': serializer.toJson<DateTime>(mangiatoIl),
      'pasto': serializer.toJson<String>(pasto),
      'descrizione': serializer.toJson<String>(descrizione),
      'grammi': serializer.toJson<double?>(grammi),
      'quantita': serializer.toJson<double?>(quantita),
      'unita': serializer.toJson<String?>(unita),
      'kcal': serializer.toJson<double?>(kcal),
      'proteine': serializer.toJson<double?>(proteine),
      'carboidrati': serializer.toJson<double?>(carboidrati),
      'grassi': serializer.toJson<double?>(grassi),
      'kcal100': serializer.toJson<double?>(kcal100),
      'proteine100': serializer.toJson<double?>(proteine100),
      'carboidrati100': serializer.toJson<double?>(carboidrati100),
      'grassi100': serializer.toJson<double?>(grassi100),
      'fonte': serializer.toJson<String>(fonte),
      'aiGrezzo': serializer.toJson<String?>(aiGrezzo),
      'pianoId': serializer.toJson<int?>(pianoId),
      'alimentoId': serializer.toJson<int?>(alimentoId),
      'scrittaIl': serializer.toJson<DateTime>(scrittaIl),
    };
  }

  VoceDiario copyWith({
    int? id,
    Value<int?> idSulServer = const Value.absent(),
    DateTime? mangiatoIl,
    String? pasto,
    String? descrizione,
    Value<double?> grammi = const Value.absent(),
    Value<double?> quantita = const Value.absent(),
    Value<String?> unita = const Value.absent(),
    Value<double?> kcal = const Value.absent(),
    Value<double?> proteine = const Value.absent(),
    Value<double?> carboidrati = const Value.absent(),
    Value<double?> grassi = const Value.absent(),
    Value<double?> kcal100 = const Value.absent(),
    Value<double?> proteine100 = const Value.absent(),
    Value<double?> carboidrati100 = const Value.absent(),
    Value<double?> grassi100 = const Value.absent(),
    String? fonte,
    Value<String?> aiGrezzo = const Value.absent(),
    Value<int?> pianoId = const Value.absent(),
    Value<int?> alimentoId = const Value.absent(),
    DateTime? scrittaIl,
  }) => VoceDiario(
    id: id ?? this.id,
    idSulServer: idSulServer.present ? idSulServer.value : this.idSulServer,
    mangiatoIl: mangiatoIl ?? this.mangiatoIl,
    pasto: pasto ?? this.pasto,
    descrizione: descrizione ?? this.descrizione,
    grammi: grammi.present ? grammi.value : this.grammi,
    quantita: quantita.present ? quantita.value : this.quantita,
    unita: unita.present ? unita.value : this.unita,
    kcal: kcal.present ? kcal.value : this.kcal,
    proteine: proteine.present ? proteine.value : this.proteine,
    carboidrati: carboidrati.present ? carboidrati.value : this.carboidrati,
    grassi: grassi.present ? grassi.value : this.grassi,
    kcal100: kcal100.present ? kcal100.value : this.kcal100,
    proteine100: proteine100.present ? proteine100.value : this.proteine100,
    carboidrati100: carboidrati100.present
        ? carboidrati100.value
        : this.carboidrati100,
    grassi100: grassi100.present ? grassi100.value : this.grassi100,
    fonte: fonte ?? this.fonte,
    aiGrezzo: aiGrezzo.present ? aiGrezzo.value : this.aiGrezzo,
    pianoId: pianoId.present ? pianoId.value : this.pianoId,
    alimentoId: alimentoId.present ? alimentoId.value : this.alimentoId,
    scrittaIl: scrittaIl ?? this.scrittaIl,
  );
  VoceDiario copyWithCompanion(VociDiarioCompanion data) {
    return VoceDiario(
      id: data.id.present ? data.id.value : this.id,
      idSulServer: data.idSulServer.present
          ? data.idSulServer.value
          : this.idSulServer,
      mangiatoIl: data.mangiatoIl.present
          ? data.mangiatoIl.value
          : this.mangiatoIl,
      pasto: data.pasto.present ? data.pasto.value : this.pasto,
      descrizione: data.descrizione.present
          ? data.descrizione.value
          : this.descrizione,
      grammi: data.grammi.present ? data.grammi.value : this.grammi,
      quantita: data.quantita.present ? data.quantita.value : this.quantita,
      unita: data.unita.present ? data.unita.value : this.unita,
      kcal: data.kcal.present ? data.kcal.value : this.kcal,
      proteine: data.proteine.present ? data.proteine.value : this.proteine,
      carboidrati: data.carboidrati.present
          ? data.carboidrati.value
          : this.carboidrati,
      grassi: data.grassi.present ? data.grassi.value : this.grassi,
      kcal100: data.kcal100.present ? data.kcal100.value : this.kcal100,
      proteine100: data.proteine100.present
          ? data.proteine100.value
          : this.proteine100,
      carboidrati100: data.carboidrati100.present
          ? data.carboidrati100.value
          : this.carboidrati100,
      grassi100: data.grassi100.present ? data.grassi100.value : this.grassi100,
      fonte: data.fonte.present ? data.fonte.value : this.fonte,
      aiGrezzo: data.aiGrezzo.present ? data.aiGrezzo.value : this.aiGrezzo,
      pianoId: data.pianoId.present ? data.pianoId.value : this.pianoId,
      alimentoId: data.alimentoId.present
          ? data.alimentoId.value
          : this.alimentoId,
      scrittaIl: data.scrittaIl.present ? data.scrittaIl.value : this.scrittaIl,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VoceDiario(')
          ..write('id: $id, ')
          ..write('idSulServer: $idSulServer, ')
          ..write('mangiatoIl: $mangiatoIl, ')
          ..write('pasto: $pasto, ')
          ..write('descrizione: $descrizione, ')
          ..write('grammi: $grammi, ')
          ..write('quantita: $quantita, ')
          ..write('unita: $unita, ')
          ..write('kcal: $kcal, ')
          ..write('proteine: $proteine, ')
          ..write('carboidrati: $carboidrati, ')
          ..write('grassi: $grassi, ')
          ..write('kcal100: $kcal100, ')
          ..write('proteine100: $proteine100, ')
          ..write('carboidrati100: $carboidrati100, ')
          ..write('grassi100: $grassi100, ')
          ..write('fonte: $fonte, ')
          ..write('aiGrezzo: $aiGrezzo, ')
          ..write('pianoId: $pianoId, ')
          ..write('alimentoId: $alimentoId, ')
          ..write('scrittaIl: $scrittaIl')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    idSulServer,
    mangiatoIl,
    pasto,
    descrizione,
    grammi,
    quantita,
    unita,
    kcal,
    proteine,
    carboidrati,
    grassi,
    kcal100,
    proteine100,
    carboidrati100,
    grassi100,
    fonte,
    aiGrezzo,
    pianoId,
    alimentoId,
    scrittaIl,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VoceDiario &&
          other.id == this.id &&
          other.idSulServer == this.idSulServer &&
          other.mangiatoIl == this.mangiatoIl &&
          other.pasto == this.pasto &&
          other.descrizione == this.descrizione &&
          other.grammi == this.grammi &&
          other.quantita == this.quantita &&
          other.unita == this.unita &&
          other.kcal == this.kcal &&
          other.proteine == this.proteine &&
          other.carboidrati == this.carboidrati &&
          other.grassi == this.grassi &&
          other.kcal100 == this.kcal100 &&
          other.proteine100 == this.proteine100 &&
          other.carboidrati100 == this.carboidrati100 &&
          other.grassi100 == this.grassi100 &&
          other.fonte == this.fonte &&
          other.aiGrezzo == this.aiGrezzo &&
          other.pianoId == this.pianoId &&
          other.alimentoId == this.alimentoId &&
          other.scrittaIl == this.scrittaIl);
}

class VociDiarioCompanion extends UpdateCompanion<VoceDiario> {
  final Value<int> id;
  final Value<int?> idSulServer;
  final Value<DateTime> mangiatoIl;
  final Value<String> pasto;
  final Value<String> descrizione;
  final Value<double?> grammi;
  final Value<double?> quantita;
  final Value<String?> unita;
  final Value<double?> kcal;
  final Value<double?> proteine;
  final Value<double?> carboidrati;
  final Value<double?> grassi;
  final Value<double?> kcal100;
  final Value<double?> proteine100;
  final Value<double?> carboidrati100;
  final Value<double?> grassi100;
  final Value<String> fonte;
  final Value<String?> aiGrezzo;
  final Value<int?> pianoId;
  final Value<int?> alimentoId;
  final Value<DateTime> scrittaIl;
  const VociDiarioCompanion({
    this.id = const Value.absent(),
    this.idSulServer = const Value.absent(),
    this.mangiatoIl = const Value.absent(),
    this.pasto = const Value.absent(),
    this.descrizione = const Value.absent(),
    this.grammi = const Value.absent(),
    this.quantita = const Value.absent(),
    this.unita = const Value.absent(),
    this.kcal = const Value.absent(),
    this.proteine = const Value.absent(),
    this.carboidrati = const Value.absent(),
    this.grassi = const Value.absent(),
    this.kcal100 = const Value.absent(),
    this.proteine100 = const Value.absent(),
    this.carboidrati100 = const Value.absent(),
    this.grassi100 = const Value.absent(),
    this.fonte = const Value.absent(),
    this.aiGrezzo = const Value.absent(),
    this.pianoId = const Value.absent(),
    this.alimentoId = const Value.absent(),
    this.scrittaIl = const Value.absent(),
  });
  VociDiarioCompanion.insert({
    this.id = const Value.absent(),
    this.idSulServer = const Value.absent(),
    required DateTime mangiatoIl,
    required String pasto,
    required String descrizione,
    this.grammi = const Value.absent(),
    this.quantita = const Value.absent(),
    this.unita = const Value.absent(),
    this.kcal = const Value.absent(),
    this.proteine = const Value.absent(),
    this.carboidrati = const Value.absent(),
    this.grassi = const Value.absent(),
    this.kcal100 = const Value.absent(),
    this.proteine100 = const Value.absent(),
    this.carboidrati100 = const Value.absent(),
    this.grassi100 = const Value.absent(),
    this.fonte = const Value.absent(),
    this.aiGrezzo = const Value.absent(),
    this.pianoId = const Value.absent(),
    this.alimentoId = const Value.absent(),
    this.scrittaIl = const Value.absent(),
  }) : mangiatoIl = Value(mangiatoIl),
       pasto = Value(pasto),
       descrizione = Value(descrizione);
  static Insertable<VoceDiario> custom({
    Expression<int>? id,
    Expression<int>? idSulServer,
    Expression<DateTime>? mangiatoIl,
    Expression<String>? pasto,
    Expression<String>? descrizione,
    Expression<double>? grammi,
    Expression<double>? quantita,
    Expression<String>? unita,
    Expression<double>? kcal,
    Expression<double>? proteine,
    Expression<double>? carboidrati,
    Expression<double>? grassi,
    Expression<double>? kcal100,
    Expression<double>? proteine100,
    Expression<double>? carboidrati100,
    Expression<double>? grassi100,
    Expression<String>? fonte,
    Expression<String>? aiGrezzo,
    Expression<int>? pianoId,
    Expression<int>? alimentoId,
    Expression<DateTime>? scrittaIl,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (idSulServer != null) 'id_sul_server': idSulServer,
      if (mangiatoIl != null) 'mangiato_il': mangiatoIl,
      if (pasto != null) 'pasto': pasto,
      if (descrizione != null) 'descrizione': descrizione,
      if (grammi != null) 'grammi': grammi,
      if (quantita != null) 'quantita': quantita,
      if (unita != null) 'unita': unita,
      if (kcal != null) 'kcal': kcal,
      if (proteine != null) 'proteine': proteine,
      if (carboidrati != null) 'carboidrati': carboidrati,
      if (grassi != null) 'grassi': grassi,
      if (kcal100 != null) 'kcal100': kcal100,
      if (proteine100 != null) 'proteine100': proteine100,
      if (carboidrati100 != null) 'carboidrati100': carboidrati100,
      if (grassi100 != null) 'grassi100': grassi100,
      if (fonte != null) 'fonte': fonte,
      if (aiGrezzo != null) 'ai_grezzo': aiGrezzo,
      if (pianoId != null) 'piano_id': pianoId,
      if (alimentoId != null) 'alimento_id': alimentoId,
      if (scrittaIl != null) 'scritta_il': scrittaIl,
    });
  }

  VociDiarioCompanion copyWith({
    Value<int>? id,
    Value<int?>? idSulServer,
    Value<DateTime>? mangiatoIl,
    Value<String>? pasto,
    Value<String>? descrizione,
    Value<double?>? grammi,
    Value<double?>? quantita,
    Value<String?>? unita,
    Value<double?>? kcal,
    Value<double?>? proteine,
    Value<double?>? carboidrati,
    Value<double?>? grassi,
    Value<double?>? kcal100,
    Value<double?>? proteine100,
    Value<double?>? carboidrati100,
    Value<double?>? grassi100,
    Value<String>? fonte,
    Value<String?>? aiGrezzo,
    Value<int?>? pianoId,
    Value<int?>? alimentoId,
    Value<DateTime>? scrittaIl,
  }) {
    return VociDiarioCompanion(
      id: id ?? this.id,
      idSulServer: idSulServer ?? this.idSulServer,
      mangiatoIl: mangiatoIl ?? this.mangiatoIl,
      pasto: pasto ?? this.pasto,
      descrizione: descrizione ?? this.descrizione,
      grammi: grammi ?? this.grammi,
      quantita: quantita ?? this.quantita,
      unita: unita ?? this.unita,
      kcal: kcal ?? this.kcal,
      proteine: proteine ?? this.proteine,
      carboidrati: carboidrati ?? this.carboidrati,
      grassi: grassi ?? this.grassi,
      kcal100: kcal100 ?? this.kcal100,
      proteine100: proteine100 ?? this.proteine100,
      carboidrati100: carboidrati100 ?? this.carboidrati100,
      grassi100: grassi100 ?? this.grassi100,
      fonte: fonte ?? this.fonte,
      aiGrezzo: aiGrezzo ?? this.aiGrezzo,
      pianoId: pianoId ?? this.pianoId,
      alimentoId: alimentoId ?? this.alimentoId,
      scrittaIl: scrittaIl ?? this.scrittaIl,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (idSulServer.present) {
      map['id_sul_server'] = Variable<int>(idSulServer.value);
    }
    if (mangiatoIl.present) {
      map['mangiato_il'] = Variable<DateTime>(mangiatoIl.value);
    }
    if (pasto.present) {
      map['pasto'] = Variable<String>(pasto.value);
    }
    if (descrizione.present) {
      map['descrizione'] = Variable<String>(descrizione.value);
    }
    if (grammi.present) {
      map['grammi'] = Variable<double>(grammi.value);
    }
    if (quantita.present) {
      map['quantita'] = Variable<double>(quantita.value);
    }
    if (unita.present) {
      map['unita'] = Variable<String>(unita.value);
    }
    if (kcal.present) {
      map['kcal'] = Variable<double>(kcal.value);
    }
    if (proteine.present) {
      map['proteine'] = Variable<double>(proteine.value);
    }
    if (carboidrati.present) {
      map['carboidrati'] = Variable<double>(carboidrati.value);
    }
    if (grassi.present) {
      map['grassi'] = Variable<double>(grassi.value);
    }
    if (kcal100.present) {
      map['kcal100'] = Variable<double>(kcal100.value);
    }
    if (proteine100.present) {
      map['proteine100'] = Variable<double>(proteine100.value);
    }
    if (carboidrati100.present) {
      map['carboidrati100'] = Variable<double>(carboidrati100.value);
    }
    if (grassi100.present) {
      map['grassi100'] = Variable<double>(grassi100.value);
    }
    if (fonte.present) {
      map['fonte'] = Variable<String>(fonte.value);
    }
    if (aiGrezzo.present) {
      map['ai_grezzo'] = Variable<String>(aiGrezzo.value);
    }
    if (pianoId.present) {
      map['piano_id'] = Variable<int>(pianoId.value);
    }
    if (alimentoId.present) {
      map['alimento_id'] = Variable<int>(alimentoId.value);
    }
    if (scrittaIl.present) {
      map['scritta_il'] = Variable<DateTime>(scrittaIl.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VociDiarioCompanion(')
          ..write('id: $id, ')
          ..write('idSulServer: $idSulServer, ')
          ..write('mangiatoIl: $mangiatoIl, ')
          ..write('pasto: $pasto, ')
          ..write('descrizione: $descrizione, ')
          ..write('grammi: $grammi, ')
          ..write('quantita: $quantita, ')
          ..write('unita: $unita, ')
          ..write('kcal: $kcal, ')
          ..write('proteine: $proteine, ')
          ..write('carboidrati: $carboidrati, ')
          ..write('grassi: $grassi, ')
          ..write('kcal100: $kcal100, ')
          ..write('proteine100: $proteine100, ')
          ..write('carboidrati100: $carboidrati100, ')
          ..write('grassi100: $grassi100, ')
          ..write('fonte: $fonte, ')
          ..write('aiGrezzo: $aiGrezzo, ')
          ..write('pianoId: $pianoId, ')
          ..write('alimentoId: $alimentoId, ')
          ..write('scrittaIl: $scrittaIl')
          ..write(')'))
        .toString();
  }
}

class $PreferitiCiboTable extends PreferitiCibo
    with TableInfo<$PreferitiCiboTable, PreferitoCibo> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PreferitiCiboTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _idSulServerMeta = const VerificationMeta(
    'idSulServer',
  );
  @override
  late final GeneratedColumn<int> idSulServer = GeneratedColumn<int>(
    'id_sul_server',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _descrizioneMeta = const VerificationMeta(
    'descrizione',
  );
  @override
  late final GeneratedColumn<String> descrizione = GeneratedColumn<String>(
    'descrizione',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 255,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ePastoMeta = const VerificationMeta('ePasto');
  @override
  late final GeneratedColumn<bool> ePasto = GeneratedColumn<bool>(
    'e_pasto',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("e_pasto" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _vociMeta = const VerificationMeta('voci');
  @override
  late final GeneratedColumn<String> voci = GeneratedColumn<String>(
    'voci',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _grammiMeta = const VerificationMeta('grammi');
  @override
  late final GeneratedColumn<double> grammi = GeneratedColumn<double>(
    'grammi',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _quantitaMeta = const VerificationMeta(
    'quantita',
  );
  @override
  late final GeneratedColumn<double> quantita = GeneratedColumn<double>(
    'quantita',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _unitaMeta = const VerificationMeta('unita');
  @override
  late final GeneratedColumn<String> unita = GeneratedColumn<String>(
    'unita',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 16,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _kcalMeta = const VerificationMeta('kcal');
  @override
  late final GeneratedColumn<double> kcal = GeneratedColumn<double>(
    'kcal',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _proteineMeta = const VerificationMeta(
    'proteine',
  );
  @override
  late final GeneratedColumn<double> proteine = GeneratedColumn<double>(
    'proteine',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _carboidratiMeta = const VerificationMeta(
    'carboidrati',
  );
  @override
  late final GeneratedColumn<double> carboidrati = GeneratedColumn<double>(
    'carboidrati',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _grassiMeta = const VerificationMeta('grassi');
  @override
  late final GeneratedColumn<double> grassi = GeneratedColumn<double>(
    'grassi',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _kcal100Meta = const VerificationMeta(
    'kcal100',
  );
  @override
  late final GeneratedColumn<double> kcal100 = GeneratedColumn<double>(
    'kcal100',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _proteine100Meta = const VerificationMeta(
    'proteine100',
  );
  @override
  late final GeneratedColumn<double> proteine100 = GeneratedColumn<double>(
    'proteine100',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _carboidrati100Meta = const VerificationMeta(
    'carboidrati100',
  );
  @override
  late final GeneratedColumn<double> carboidrati100 = GeneratedColumn<double>(
    'carboidrati100',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _grassi100Meta = const VerificationMeta(
    'grassi100',
  );
  @override
  late final GeneratedColumn<double> grassi100 = GeneratedColumn<double>(
    'grassi100',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _salvatoIlMeta = const VerificationMeta(
    'salvatoIl',
  );
  @override
  late final GeneratedColumn<DateTime> salvatoIl = GeneratedColumn<DateTime>(
    'salvato_il',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _volteUsatoMeta = const VerificationMeta(
    'volteUsato',
  );
  @override
  late final GeneratedColumn<int> volteUsato = GeneratedColumn<int>(
    'volte_usato',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _usatoIlMeta = const VerificationMeta(
    'usatoIl',
  );
  @override
  late final GeneratedColumn<DateTime> usatoIl = GeneratedColumn<DateTime>(
    'usato_il',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    idSulServer,
    descrizione,
    ePasto,
    voci,
    grammi,
    quantita,
    unita,
    kcal,
    proteine,
    carboidrati,
    grassi,
    kcal100,
    proteine100,
    carboidrati100,
    grassi100,
    salvatoIl,
    volteUsato,
    usatoIl,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'preferiti_cibo';
  @override
  VerificationContext validateIntegrity(
    Insertable<PreferitoCibo> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('id_sul_server')) {
      context.handle(
        _idSulServerMeta,
        idSulServer.isAcceptableOrUnknown(
          data['id_sul_server']!,
          _idSulServerMeta,
        ),
      );
    }
    if (data.containsKey('descrizione')) {
      context.handle(
        _descrizioneMeta,
        descrizione.isAcceptableOrUnknown(
          data['descrizione']!,
          _descrizioneMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_descrizioneMeta);
    }
    if (data.containsKey('e_pasto')) {
      context.handle(
        _ePastoMeta,
        ePasto.isAcceptableOrUnknown(data['e_pasto']!, _ePastoMeta),
      );
    }
    if (data.containsKey('voci')) {
      context.handle(
        _vociMeta,
        voci.isAcceptableOrUnknown(data['voci']!, _vociMeta),
      );
    }
    if (data.containsKey('grammi')) {
      context.handle(
        _grammiMeta,
        grammi.isAcceptableOrUnknown(data['grammi']!, _grammiMeta),
      );
    }
    if (data.containsKey('quantita')) {
      context.handle(
        _quantitaMeta,
        quantita.isAcceptableOrUnknown(data['quantita']!, _quantitaMeta),
      );
    }
    if (data.containsKey('unita')) {
      context.handle(
        _unitaMeta,
        unita.isAcceptableOrUnknown(data['unita']!, _unitaMeta),
      );
    }
    if (data.containsKey('kcal')) {
      context.handle(
        _kcalMeta,
        kcal.isAcceptableOrUnknown(data['kcal']!, _kcalMeta),
      );
    }
    if (data.containsKey('proteine')) {
      context.handle(
        _proteineMeta,
        proteine.isAcceptableOrUnknown(data['proteine']!, _proteineMeta),
      );
    }
    if (data.containsKey('carboidrati')) {
      context.handle(
        _carboidratiMeta,
        carboidrati.isAcceptableOrUnknown(
          data['carboidrati']!,
          _carboidratiMeta,
        ),
      );
    }
    if (data.containsKey('grassi')) {
      context.handle(
        _grassiMeta,
        grassi.isAcceptableOrUnknown(data['grassi']!, _grassiMeta),
      );
    }
    if (data.containsKey('kcal100')) {
      context.handle(
        _kcal100Meta,
        kcal100.isAcceptableOrUnknown(data['kcal100']!, _kcal100Meta),
      );
    }
    if (data.containsKey('proteine100')) {
      context.handle(
        _proteine100Meta,
        proteine100.isAcceptableOrUnknown(
          data['proteine100']!,
          _proteine100Meta,
        ),
      );
    }
    if (data.containsKey('carboidrati100')) {
      context.handle(
        _carboidrati100Meta,
        carboidrati100.isAcceptableOrUnknown(
          data['carboidrati100']!,
          _carboidrati100Meta,
        ),
      );
    }
    if (data.containsKey('grassi100')) {
      context.handle(
        _grassi100Meta,
        grassi100.isAcceptableOrUnknown(data['grassi100']!, _grassi100Meta),
      );
    }
    if (data.containsKey('salvato_il')) {
      context.handle(
        _salvatoIlMeta,
        salvatoIl.isAcceptableOrUnknown(data['salvato_il']!, _salvatoIlMeta),
      );
    }
    if (data.containsKey('volte_usato')) {
      context.handle(
        _volteUsatoMeta,
        volteUsato.isAcceptableOrUnknown(data['volte_usato']!, _volteUsatoMeta),
      );
    }
    if (data.containsKey('usato_il')) {
      context.handle(
        _usatoIlMeta,
        usatoIl.isAcceptableOrUnknown(data['usato_il']!, _usatoIlMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {idSulServer},
  ];
  @override
  PreferitoCibo map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PreferitoCibo(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      idSulServer: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id_sul_server'],
      ),
      descrizione: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}descrizione'],
      )!,
      ePasto: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}e_pasto'],
      )!,
      voci: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}voci'],
      ),
      grammi: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}grammi'],
      ),
      quantita: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}quantita'],
      ),
      unita: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unita'],
      ),
      kcal: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}kcal'],
      ),
      proteine: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}proteine'],
      ),
      carboidrati: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}carboidrati'],
      ),
      grassi: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}grassi'],
      ),
      kcal100: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}kcal100'],
      ),
      proteine100: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}proteine100'],
      ),
      carboidrati100: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}carboidrati100'],
      ),
      grassi100: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}grassi100'],
      ),
      salvatoIl: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}salvato_il'],
      )!,
      volteUsato: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}volte_usato'],
      )!,
      usatoIl: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}usato_il'],
      ),
    );
  }

  @override
  $PreferitiCiboTable createAlias(String alias) {
    return $PreferitiCiboTable(attachedDatabase, alias);
  }
}

class PreferitoCibo extends DataClass implements Insertable<PreferitoCibo> {
  final int id;
  final int? idSulServer;
  final String descrizione;

  /// Se è un **pasto intero** invece di un singolo alimento.
  final bool ePasto;

  /// Le voci che lo compongono, quando è un pasto. JSON.
  final String? voci;
  final double? grammi;
  final double? quantita;
  final String? unita;
  final double? kcal;
  final double? proteine;
  final double? carboidrati;
  final double? grassi;
  final double? kcal100;
  final double? proteine100;
  final double? carboidrati100;
  final double? grassi100;
  final DateTime salvatoIl;

  /// Quante volte è stato usato.
  ///
  /// 🚨 **Un contatore salvato, non un aggregato**: sul server era
  /// `food_favorites.times_used`, incrementato a ogni uso. ⛔ Ricavarlo contando
  /// le voci del diario con la stessa descrizione darebbe un numero diverso —
  /// chi ha scritto «Pollo» a mano dieci volte non ha usato dieci volte il
  /// preferito «Pollo».
  ///
  /// 💡 È metà dell'ordinamento: 📌 *«chi ha venticinque preferiti vuole i tre
  /// che usa ogni giorno in cima, non quelli che cominciano per A»*.
  final int volteUsato;

  /// L'ultima volta che è stato usato. L'altra metà dell'ordinamento.
  final DateTime? usatoIl;
  const PreferitoCibo({
    required this.id,
    this.idSulServer,
    required this.descrizione,
    required this.ePasto,
    this.voci,
    this.grammi,
    this.quantita,
    this.unita,
    this.kcal,
    this.proteine,
    this.carboidrati,
    this.grassi,
    this.kcal100,
    this.proteine100,
    this.carboidrati100,
    this.grassi100,
    required this.salvatoIl,
    required this.volteUsato,
    this.usatoIl,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || idSulServer != null) {
      map['id_sul_server'] = Variable<int>(idSulServer);
    }
    map['descrizione'] = Variable<String>(descrizione);
    map['e_pasto'] = Variable<bool>(ePasto);
    if (!nullToAbsent || voci != null) {
      map['voci'] = Variable<String>(voci);
    }
    if (!nullToAbsent || grammi != null) {
      map['grammi'] = Variable<double>(grammi);
    }
    if (!nullToAbsent || quantita != null) {
      map['quantita'] = Variable<double>(quantita);
    }
    if (!nullToAbsent || unita != null) {
      map['unita'] = Variable<String>(unita);
    }
    if (!nullToAbsent || kcal != null) {
      map['kcal'] = Variable<double>(kcal);
    }
    if (!nullToAbsent || proteine != null) {
      map['proteine'] = Variable<double>(proteine);
    }
    if (!nullToAbsent || carboidrati != null) {
      map['carboidrati'] = Variable<double>(carboidrati);
    }
    if (!nullToAbsent || grassi != null) {
      map['grassi'] = Variable<double>(grassi);
    }
    if (!nullToAbsent || kcal100 != null) {
      map['kcal100'] = Variable<double>(kcal100);
    }
    if (!nullToAbsent || proteine100 != null) {
      map['proteine100'] = Variable<double>(proteine100);
    }
    if (!nullToAbsent || carboidrati100 != null) {
      map['carboidrati100'] = Variable<double>(carboidrati100);
    }
    if (!nullToAbsent || grassi100 != null) {
      map['grassi100'] = Variable<double>(grassi100);
    }
    map['salvato_il'] = Variable<DateTime>(salvatoIl);
    map['volte_usato'] = Variable<int>(volteUsato);
    if (!nullToAbsent || usatoIl != null) {
      map['usato_il'] = Variable<DateTime>(usatoIl);
    }
    return map;
  }

  PreferitiCiboCompanion toCompanion(bool nullToAbsent) {
    return PreferitiCiboCompanion(
      id: Value(id),
      idSulServer: idSulServer == null && nullToAbsent
          ? const Value.absent()
          : Value(idSulServer),
      descrizione: Value(descrizione),
      ePasto: Value(ePasto),
      voci: voci == null && nullToAbsent ? const Value.absent() : Value(voci),
      grammi: grammi == null && nullToAbsent
          ? const Value.absent()
          : Value(grammi),
      quantita: quantita == null && nullToAbsent
          ? const Value.absent()
          : Value(quantita),
      unita: unita == null && nullToAbsent
          ? const Value.absent()
          : Value(unita),
      kcal: kcal == null && nullToAbsent ? const Value.absent() : Value(kcal),
      proteine: proteine == null && nullToAbsent
          ? const Value.absent()
          : Value(proteine),
      carboidrati: carboidrati == null && nullToAbsent
          ? const Value.absent()
          : Value(carboidrati),
      grassi: grassi == null && nullToAbsent
          ? const Value.absent()
          : Value(grassi),
      kcal100: kcal100 == null && nullToAbsent
          ? const Value.absent()
          : Value(kcal100),
      proteine100: proteine100 == null && nullToAbsent
          ? const Value.absent()
          : Value(proteine100),
      carboidrati100: carboidrati100 == null && nullToAbsent
          ? const Value.absent()
          : Value(carboidrati100),
      grassi100: grassi100 == null && nullToAbsent
          ? const Value.absent()
          : Value(grassi100),
      salvatoIl: Value(salvatoIl),
      volteUsato: Value(volteUsato),
      usatoIl: usatoIl == null && nullToAbsent
          ? const Value.absent()
          : Value(usatoIl),
    );
  }

  factory PreferitoCibo.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PreferitoCibo(
      id: serializer.fromJson<int>(json['id']),
      idSulServer: serializer.fromJson<int?>(json['idSulServer']),
      descrizione: serializer.fromJson<String>(json['descrizione']),
      ePasto: serializer.fromJson<bool>(json['ePasto']),
      voci: serializer.fromJson<String?>(json['voci']),
      grammi: serializer.fromJson<double?>(json['grammi']),
      quantita: serializer.fromJson<double?>(json['quantita']),
      unita: serializer.fromJson<String?>(json['unita']),
      kcal: serializer.fromJson<double?>(json['kcal']),
      proteine: serializer.fromJson<double?>(json['proteine']),
      carboidrati: serializer.fromJson<double?>(json['carboidrati']),
      grassi: serializer.fromJson<double?>(json['grassi']),
      kcal100: serializer.fromJson<double?>(json['kcal100']),
      proteine100: serializer.fromJson<double?>(json['proteine100']),
      carboidrati100: serializer.fromJson<double?>(json['carboidrati100']),
      grassi100: serializer.fromJson<double?>(json['grassi100']),
      salvatoIl: serializer.fromJson<DateTime>(json['salvatoIl']),
      volteUsato: serializer.fromJson<int>(json['volteUsato']),
      usatoIl: serializer.fromJson<DateTime?>(json['usatoIl']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'idSulServer': serializer.toJson<int?>(idSulServer),
      'descrizione': serializer.toJson<String>(descrizione),
      'ePasto': serializer.toJson<bool>(ePasto),
      'voci': serializer.toJson<String?>(voci),
      'grammi': serializer.toJson<double?>(grammi),
      'quantita': serializer.toJson<double?>(quantita),
      'unita': serializer.toJson<String?>(unita),
      'kcal': serializer.toJson<double?>(kcal),
      'proteine': serializer.toJson<double?>(proteine),
      'carboidrati': serializer.toJson<double?>(carboidrati),
      'grassi': serializer.toJson<double?>(grassi),
      'kcal100': serializer.toJson<double?>(kcal100),
      'proteine100': serializer.toJson<double?>(proteine100),
      'carboidrati100': serializer.toJson<double?>(carboidrati100),
      'grassi100': serializer.toJson<double?>(grassi100),
      'salvatoIl': serializer.toJson<DateTime>(salvatoIl),
      'volteUsato': serializer.toJson<int>(volteUsato),
      'usatoIl': serializer.toJson<DateTime?>(usatoIl),
    };
  }

  PreferitoCibo copyWith({
    int? id,
    Value<int?> idSulServer = const Value.absent(),
    String? descrizione,
    bool? ePasto,
    Value<String?> voci = const Value.absent(),
    Value<double?> grammi = const Value.absent(),
    Value<double?> quantita = const Value.absent(),
    Value<String?> unita = const Value.absent(),
    Value<double?> kcal = const Value.absent(),
    Value<double?> proteine = const Value.absent(),
    Value<double?> carboidrati = const Value.absent(),
    Value<double?> grassi = const Value.absent(),
    Value<double?> kcal100 = const Value.absent(),
    Value<double?> proteine100 = const Value.absent(),
    Value<double?> carboidrati100 = const Value.absent(),
    Value<double?> grassi100 = const Value.absent(),
    DateTime? salvatoIl,
    int? volteUsato,
    Value<DateTime?> usatoIl = const Value.absent(),
  }) => PreferitoCibo(
    id: id ?? this.id,
    idSulServer: idSulServer.present ? idSulServer.value : this.idSulServer,
    descrizione: descrizione ?? this.descrizione,
    ePasto: ePasto ?? this.ePasto,
    voci: voci.present ? voci.value : this.voci,
    grammi: grammi.present ? grammi.value : this.grammi,
    quantita: quantita.present ? quantita.value : this.quantita,
    unita: unita.present ? unita.value : this.unita,
    kcal: kcal.present ? kcal.value : this.kcal,
    proteine: proteine.present ? proteine.value : this.proteine,
    carboidrati: carboidrati.present ? carboidrati.value : this.carboidrati,
    grassi: grassi.present ? grassi.value : this.grassi,
    kcal100: kcal100.present ? kcal100.value : this.kcal100,
    proteine100: proteine100.present ? proteine100.value : this.proteine100,
    carboidrati100: carboidrati100.present
        ? carboidrati100.value
        : this.carboidrati100,
    grassi100: grassi100.present ? grassi100.value : this.grassi100,
    salvatoIl: salvatoIl ?? this.salvatoIl,
    volteUsato: volteUsato ?? this.volteUsato,
    usatoIl: usatoIl.present ? usatoIl.value : this.usatoIl,
  );
  PreferitoCibo copyWithCompanion(PreferitiCiboCompanion data) {
    return PreferitoCibo(
      id: data.id.present ? data.id.value : this.id,
      idSulServer: data.idSulServer.present
          ? data.idSulServer.value
          : this.idSulServer,
      descrizione: data.descrizione.present
          ? data.descrizione.value
          : this.descrizione,
      ePasto: data.ePasto.present ? data.ePasto.value : this.ePasto,
      voci: data.voci.present ? data.voci.value : this.voci,
      grammi: data.grammi.present ? data.grammi.value : this.grammi,
      quantita: data.quantita.present ? data.quantita.value : this.quantita,
      unita: data.unita.present ? data.unita.value : this.unita,
      kcal: data.kcal.present ? data.kcal.value : this.kcal,
      proteine: data.proteine.present ? data.proteine.value : this.proteine,
      carboidrati: data.carboidrati.present
          ? data.carboidrati.value
          : this.carboidrati,
      grassi: data.grassi.present ? data.grassi.value : this.grassi,
      kcal100: data.kcal100.present ? data.kcal100.value : this.kcal100,
      proteine100: data.proteine100.present
          ? data.proteine100.value
          : this.proteine100,
      carboidrati100: data.carboidrati100.present
          ? data.carboidrati100.value
          : this.carboidrati100,
      grassi100: data.grassi100.present ? data.grassi100.value : this.grassi100,
      salvatoIl: data.salvatoIl.present ? data.salvatoIl.value : this.salvatoIl,
      volteUsato: data.volteUsato.present
          ? data.volteUsato.value
          : this.volteUsato,
      usatoIl: data.usatoIl.present ? data.usatoIl.value : this.usatoIl,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PreferitoCibo(')
          ..write('id: $id, ')
          ..write('idSulServer: $idSulServer, ')
          ..write('descrizione: $descrizione, ')
          ..write('ePasto: $ePasto, ')
          ..write('voci: $voci, ')
          ..write('grammi: $grammi, ')
          ..write('quantita: $quantita, ')
          ..write('unita: $unita, ')
          ..write('kcal: $kcal, ')
          ..write('proteine: $proteine, ')
          ..write('carboidrati: $carboidrati, ')
          ..write('grassi: $grassi, ')
          ..write('kcal100: $kcal100, ')
          ..write('proteine100: $proteine100, ')
          ..write('carboidrati100: $carboidrati100, ')
          ..write('grassi100: $grassi100, ')
          ..write('salvatoIl: $salvatoIl, ')
          ..write('volteUsato: $volteUsato, ')
          ..write('usatoIl: $usatoIl')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    idSulServer,
    descrizione,
    ePasto,
    voci,
    grammi,
    quantita,
    unita,
    kcal,
    proteine,
    carboidrati,
    grassi,
    kcal100,
    proteine100,
    carboidrati100,
    grassi100,
    salvatoIl,
    volteUsato,
    usatoIl,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PreferitoCibo &&
          other.id == this.id &&
          other.idSulServer == this.idSulServer &&
          other.descrizione == this.descrizione &&
          other.ePasto == this.ePasto &&
          other.voci == this.voci &&
          other.grammi == this.grammi &&
          other.quantita == this.quantita &&
          other.unita == this.unita &&
          other.kcal == this.kcal &&
          other.proteine == this.proteine &&
          other.carboidrati == this.carboidrati &&
          other.grassi == this.grassi &&
          other.kcal100 == this.kcal100 &&
          other.proteine100 == this.proteine100 &&
          other.carboidrati100 == this.carboidrati100 &&
          other.grassi100 == this.grassi100 &&
          other.salvatoIl == this.salvatoIl &&
          other.volteUsato == this.volteUsato &&
          other.usatoIl == this.usatoIl);
}

class PreferitiCiboCompanion extends UpdateCompanion<PreferitoCibo> {
  final Value<int> id;
  final Value<int?> idSulServer;
  final Value<String> descrizione;
  final Value<bool> ePasto;
  final Value<String?> voci;
  final Value<double?> grammi;
  final Value<double?> quantita;
  final Value<String?> unita;
  final Value<double?> kcal;
  final Value<double?> proteine;
  final Value<double?> carboidrati;
  final Value<double?> grassi;
  final Value<double?> kcal100;
  final Value<double?> proteine100;
  final Value<double?> carboidrati100;
  final Value<double?> grassi100;
  final Value<DateTime> salvatoIl;
  final Value<int> volteUsato;
  final Value<DateTime?> usatoIl;
  const PreferitiCiboCompanion({
    this.id = const Value.absent(),
    this.idSulServer = const Value.absent(),
    this.descrizione = const Value.absent(),
    this.ePasto = const Value.absent(),
    this.voci = const Value.absent(),
    this.grammi = const Value.absent(),
    this.quantita = const Value.absent(),
    this.unita = const Value.absent(),
    this.kcal = const Value.absent(),
    this.proteine = const Value.absent(),
    this.carboidrati = const Value.absent(),
    this.grassi = const Value.absent(),
    this.kcal100 = const Value.absent(),
    this.proteine100 = const Value.absent(),
    this.carboidrati100 = const Value.absent(),
    this.grassi100 = const Value.absent(),
    this.salvatoIl = const Value.absent(),
    this.volteUsato = const Value.absent(),
    this.usatoIl = const Value.absent(),
  });
  PreferitiCiboCompanion.insert({
    this.id = const Value.absent(),
    this.idSulServer = const Value.absent(),
    required String descrizione,
    this.ePasto = const Value.absent(),
    this.voci = const Value.absent(),
    this.grammi = const Value.absent(),
    this.quantita = const Value.absent(),
    this.unita = const Value.absent(),
    this.kcal = const Value.absent(),
    this.proteine = const Value.absent(),
    this.carboidrati = const Value.absent(),
    this.grassi = const Value.absent(),
    this.kcal100 = const Value.absent(),
    this.proteine100 = const Value.absent(),
    this.carboidrati100 = const Value.absent(),
    this.grassi100 = const Value.absent(),
    this.salvatoIl = const Value.absent(),
    this.volteUsato = const Value.absent(),
    this.usatoIl = const Value.absent(),
  }) : descrizione = Value(descrizione);
  static Insertable<PreferitoCibo> custom({
    Expression<int>? id,
    Expression<int>? idSulServer,
    Expression<String>? descrizione,
    Expression<bool>? ePasto,
    Expression<String>? voci,
    Expression<double>? grammi,
    Expression<double>? quantita,
    Expression<String>? unita,
    Expression<double>? kcal,
    Expression<double>? proteine,
    Expression<double>? carboidrati,
    Expression<double>? grassi,
    Expression<double>? kcal100,
    Expression<double>? proteine100,
    Expression<double>? carboidrati100,
    Expression<double>? grassi100,
    Expression<DateTime>? salvatoIl,
    Expression<int>? volteUsato,
    Expression<DateTime>? usatoIl,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (idSulServer != null) 'id_sul_server': idSulServer,
      if (descrizione != null) 'descrizione': descrizione,
      if (ePasto != null) 'e_pasto': ePasto,
      if (voci != null) 'voci': voci,
      if (grammi != null) 'grammi': grammi,
      if (quantita != null) 'quantita': quantita,
      if (unita != null) 'unita': unita,
      if (kcal != null) 'kcal': kcal,
      if (proteine != null) 'proteine': proteine,
      if (carboidrati != null) 'carboidrati': carboidrati,
      if (grassi != null) 'grassi': grassi,
      if (kcal100 != null) 'kcal100': kcal100,
      if (proteine100 != null) 'proteine100': proteine100,
      if (carboidrati100 != null) 'carboidrati100': carboidrati100,
      if (grassi100 != null) 'grassi100': grassi100,
      if (salvatoIl != null) 'salvato_il': salvatoIl,
      if (volteUsato != null) 'volte_usato': volteUsato,
      if (usatoIl != null) 'usato_il': usatoIl,
    });
  }

  PreferitiCiboCompanion copyWith({
    Value<int>? id,
    Value<int?>? idSulServer,
    Value<String>? descrizione,
    Value<bool>? ePasto,
    Value<String?>? voci,
    Value<double?>? grammi,
    Value<double?>? quantita,
    Value<String?>? unita,
    Value<double?>? kcal,
    Value<double?>? proteine,
    Value<double?>? carboidrati,
    Value<double?>? grassi,
    Value<double?>? kcal100,
    Value<double?>? proteine100,
    Value<double?>? carboidrati100,
    Value<double?>? grassi100,
    Value<DateTime>? salvatoIl,
    Value<int>? volteUsato,
    Value<DateTime?>? usatoIl,
  }) {
    return PreferitiCiboCompanion(
      id: id ?? this.id,
      idSulServer: idSulServer ?? this.idSulServer,
      descrizione: descrizione ?? this.descrizione,
      ePasto: ePasto ?? this.ePasto,
      voci: voci ?? this.voci,
      grammi: grammi ?? this.grammi,
      quantita: quantita ?? this.quantita,
      unita: unita ?? this.unita,
      kcal: kcal ?? this.kcal,
      proteine: proteine ?? this.proteine,
      carboidrati: carboidrati ?? this.carboidrati,
      grassi: grassi ?? this.grassi,
      kcal100: kcal100 ?? this.kcal100,
      proteine100: proteine100 ?? this.proteine100,
      carboidrati100: carboidrati100 ?? this.carboidrati100,
      grassi100: grassi100 ?? this.grassi100,
      salvatoIl: salvatoIl ?? this.salvatoIl,
      volteUsato: volteUsato ?? this.volteUsato,
      usatoIl: usatoIl ?? this.usatoIl,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (idSulServer.present) {
      map['id_sul_server'] = Variable<int>(idSulServer.value);
    }
    if (descrizione.present) {
      map['descrizione'] = Variable<String>(descrizione.value);
    }
    if (ePasto.present) {
      map['e_pasto'] = Variable<bool>(ePasto.value);
    }
    if (voci.present) {
      map['voci'] = Variable<String>(voci.value);
    }
    if (grammi.present) {
      map['grammi'] = Variable<double>(grammi.value);
    }
    if (quantita.present) {
      map['quantita'] = Variable<double>(quantita.value);
    }
    if (unita.present) {
      map['unita'] = Variable<String>(unita.value);
    }
    if (kcal.present) {
      map['kcal'] = Variable<double>(kcal.value);
    }
    if (proteine.present) {
      map['proteine'] = Variable<double>(proteine.value);
    }
    if (carboidrati.present) {
      map['carboidrati'] = Variable<double>(carboidrati.value);
    }
    if (grassi.present) {
      map['grassi'] = Variable<double>(grassi.value);
    }
    if (kcal100.present) {
      map['kcal100'] = Variable<double>(kcal100.value);
    }
    if (proteine100.present) {
      map['proteine100'] = Variable<double>(proteine100.value);
    }
    if (carboidrati100.present) {
      map['carboidrati100'] = Variable<double>(carboidrati100.value);
    }
    if (grassi100.present) {
      map['grassi100'] = Variable<double>(grassi100.value);
    }
    if (salvatoIl.present) {
      map['salvato_il'] = Variable<DateTime>(salvatoIl.value);
    }
    if (volteUsato.present) {
      map['volte_usato'] = Variable<int>(volteUsato.value);
    }
    if (usatoIl.present) {
      map['usato_il'] = Variable<DateTime>(usatoIl.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PreferitiCiboCompanion(')
          ..write('id: $id, ')
          ..write('idSulServer: $idSulServer, ')
          ..write('descrizione: $descrizione, ')
          ..write('ePasto: $ePasto, ')
          ..write('voci: $voci, ')
          ..write('grammi: $grammi, ')
          ..write('quantita: $quantita, ')
          ..write('unita: $unita, ')
          ..write('kcal: $kcal, ')
          ..write('proteine: $proteine, ')
          ..write('carboidrati: $carboidrati, ')
          ..write('grassi: $grassi, ')
          ..write('kcal100: $kcal100, ')
          ..write('proteine100: $proteine100, ')
          ..write('carboidrati100: $carboidrati100, ')
          ..write('grassi100: $grassi100, ')
          ..write('salvatoIl: $salvatoIl, ')
          ..write('volteUsato: $volteUsato, ')
          ..write('usatoIl: $usatoIl')
          ..write(')'))
        .toString();
  }
}

class $ConsigliDelGiornoTable extends ConsigliDelGiorno
    with TableInfo<$ConsigliDelGiornoTable, ConsiglioDelGiorno> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConsigliDelGiornoTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _fasciaMeta = const VerificationMeta('fascia');
  @override
  late final GeneratedColumn<String> fascia = GeneratedColumn<String>(
    'fascia',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 24,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _testoMeta = const VerificationMeta('testo');
  @override
  late final GeneratedColumn<String> testo = GeneratedColumn<String>(
    'testo',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _generatoIlMeta = const VerificationMeta(
    'generatoIl',
  );
  @override
  late final GeneratedColumn<DateTime> generatoIl = GeneratedColumn<DateTime>(
    'generato_il',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, fascia, testo, generatoIl];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'consigli_del_giorno';
  @override
  VerificationContext validateIntegrity(
    Insertable<ConsiglioDelGiorno> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('fascia')) {
      context.handle(
        _fasciaMeta,
        fascia.isAcceptableOrUnknown(data['fascia']!, _fasciaMeta),
      );
    } else if (isInserting) {
      context.missing(_fasciaMeta);
    }
    if (data.containsKey('testo')) {
      context.handle(
        _testoMeta,
        testo.isAcceptableOrUnknown(data['testo']!, _testoMeta),
      );
    } else if (isInserting) {
      context.missing(_testoMeta);
    }
    if (data.containsKey('generato_il')) {
      context.handle(
        _generatoIlMeta,
        generatoIl.isAcceptableOrUnknown(data['generato_il']!, _generatoIlMeta),
      );
    } else if (isInserting) {
      context.missing(_generatoIlMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {fascia},
  ];
  @override
  ConsiglioDelGiorno map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConsiglioDelGiorno(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      fascia: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fascia'],
      )!,
      testo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}testo'],
      )!,
      generatoIl: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}generato_il'],
      )!,
    );
  }

  @override
  $ConsigliDelGiornoTable createAlias(String alias) {
    return $ConsigliDelGiornoTable(attachedDatabase, alias);
  }
}

class ConsiglioDelGiorno extends DataClass
    implements Insertable<ConsiglioDelGiorno> {
  final int id;

  /// `2026-09-03T14` — l'etichetta che il server manda nella risposta.
  ///
  /// 🚨 **È la chiave, e viene da `FasciaDelConsiglio::etichetta()`.** ⛔ Non si
  /// ricostruisce qui: la fascia delle 22 scavalca la mezzanotte, e chi provasse
  /// a dedurla dall'orologio sbaglierebbe per nove ore al giorno.
  final String fascia;
  final String testo;

  /// Quando l'ha generato il server (`generated_at`).
  ///
  /// 💡 È il campo con cui la schermata scrive «di ieri», e quello su cui si
  /// pota: vedi `scriviConsiglio`.
  final DateTime generatoIl;
  const ConsiglioDelGiorno({
    required this.id,
    required this.fascia,
    required this.testo,
    required this.generatoIl,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['fascia'] = Variable<String>(fascia);
    map['testo'] = Variable<String>(testo);
    map['generato_il'] = Variable<DateTime>(generatoIl);
    return map;
  }

  ConsigliDelGiornoCompanion toCompanion(bool nullToAbsent) {
    return ConsigliDelGiornoCompanion(
      id: Value(id),
      fascia: Value(fascia),
      testo: Value(testo),
      generatoIl: Value(generatoIl),
    );
  }

  factory ConsiglioDelGiorno.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConsiglioDelGiorno(
      id: serializer.fromJson<int>(json['id']),
      fascia: serializer.fromJson<String>(json['fascia']),
      testo: serializer.fromJson<String>(json['testo']),
      generatoIl: serializer.fromJson<DateTime>(json['generatoIl']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'fascia': serializer.toJson<String>(fascia),
      'testo': serializer.toJson<String>(testo),
      'generatoIl': serializer.toJson<DateTime>(generatoIl),
    };
  }

  ConsiglioDelGiorno copyWith({
    int? id,
    String? fascia,
    String? testo,
    DateTime? generatoIl,
  }) => ConsiglioDelGiorno(
    id: id ?? this.id,
    fascia: fascia ?? this.fascia,
    testo: testo ?? this.testo,
    generatoIl: generatoIl ?? this.generatoIl,
  );
  ConsiglioDelGiorno copyWithCompanion(ConsigliDelGiornoCompanion data) {
    return ConsiglioDelGiorno(
      id: data.id.present ? data.id.value : this.id,
      fascia: data.fascia.present ? data.fascia.value : this.fascia,
      testo: data.testo.present ? data.testo.value : this.testo,
      generatoIl: data.generatoIl.present
          ? data.generatoIl.value
          : this.generatoIl,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConsiglioDelGiorno(')
          ..write('id: $id, ')
          ..write('fascia: $fascia, ')
          ..write('testo: $testo, ')
          ..write('generatoIl: $generatoIl')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, fascia, testo, generatoIl);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConsiglioDelGiorno &&
          other.id == this.id &&
          other.fascia == this.fascia &&
          other.testo == this.testo &&
          other.generatoIl == this.generatoIl);
}

class ConsigliDelGiornoCompanion extends UpdateCompanion<ConsiglioDelGiorno> {
  final Value<int> id;
  final Value<String> fascia;
  final Value<String> testo;
  final Value<DateTime> generatoIl;
  const ConsigliDelGiornoCompanion({
    this.id = const Value.absent(),
    this.fascia = const Value.absent(),
    this.testo = const Value.absent(),
    this.generatoIl = const Value.absent(),
  });
  ConsigliDelGiornoCompanion.insert({
    this.id = const Value.absent(),
    required String fascia,
    required String testo,
    required DateTime generatoIl,
  }) : fascia = Value(fascia),
       testo = Value(testo),
       generatoIl = Value(generatoIl);
  static Insertable<ConsiglioDelGiorno> custom({
    Expression<int>? id,
    Expression<String>? fascia,
    Expression<String>? testo,
    Expression<DateTime>? generatoIl,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (fascia != null) 'fascia': fascia,
      if (testo != null) 'testo': testo,
      if (generatoIl != null) 'generato_il': generatoIl,
    });
  }

  ConsigliDelGiornoCompanion copyWith({
    Value<int>? id,
    Value<String>? fascia,
    Value<String>? testo,
    Value<DateTime>? generatoIl,
  }) {
    return ConsigliDelGiornoCompanion(
      id: id ?? this.id,
      fascia: fascia ?? this.fascia,
      testo: testo ?? this.testo,
      generatoIl: generatoIl ?? this.generatoIl,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (fascia.present) {
      map['fascia'] = Variable<String>(fascia.value);
    }
    if (testo.present) {
      map['testo'] = Variable<String>(testo.value);
    }
    if (generatoIl.present) {
      map['generato_il'] = Variable<DateTime>(generatoIl.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConsigliDelGiornoCompanion(')
          ..write('id: $id, ')
          ..write('fascia: $fascia, ')
          ..write('testo: $testo, ')
          ..write('generatoIl: $generatoIl')
          ..write(')'))
        .toString();
  }
}

class $DocumentiImportatiTable extends DocumentiImportati
    with TableInfo<$DocumentiImportatiTable, DocumentoImportato> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DocumentiImportatiTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _origineIdMeta = const VerificationMeta(
    'origineId',
  );
  @override
  late final GeneratedColumn<String> origineId = GeneratedColumn<String>(
    'origine_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _percorsiMeta = const VerificationMeta(
    'percorsi',
  );
  @override
  late final GeneratedColumn<String> percorsi = GeneratedColumn<String>(
    'percorsi',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tipoMeta = const VerificationMeta('tipo');
  @override
  late final GeneratedColumn<String> tipo = GeneratedColumn<String>(
    'tipo',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 16,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _importatoIlMeta = const VerificationMeta(
    'importatoIl',
  );
  @override
  late final GeneratedColumn<DateTime> importatoIl = GeneratedColumn<DateTime>(
    'importato_il',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    origineId,
    percorsi,
    tipo,
    importatoIl,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'documenti_importati';
  @override
  VerificationContext validateIntegrity(
    Insertable<DocumentoImportato> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('origine_id')) {
      context.handle(
        _origineIdMeta,
        origineId.isAcceptableOrUnknown(data['origine_id']!, _origineIdMeta),
      );
    } else if (isInserting) {
      context.missing(_origineIdMeta);
    }
    if (data.containsKey('percorsi')) {
      context.handle(
        _percorsiMeta,
        percorsi.isAcceptableOrUnknown(data['percorsi']!, _percorsiMeta),
      );
    } else if (isInserting) {
      context.missing(_percorsiMeta);
    }
    if (data.containsKey('tipo')) {
      context.handle(
        _tipoMeta,
        tipo.isAcceptableOrUnknown(data['tipo']!, _tipoMeta),
      );
    } else if (isInserting) {
      context.missing(_tipoMeta);
    }
    if (data.containsKey('importato_il')) {
      context.handle(
        _importatoIlMeta,
        importatoIl.isAcceptableOrUnknown(
          data['importato_il']!,
          _importatoIlMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_importatoIlMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DocumentoImportato map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DocumentoImportato(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      origineId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origine_id'],
      )!,
      percorsi: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}percorsi'],
      )!,
      tipo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tipo'],
      )!,
      importatoIl: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}importato_il'],
      )!,
    );
  }

  @override
  $DocumentiImportatiTable createAlias(String alias) {
    return $DocumentiImportatiTable(attachedDatabase, alias);
  }
}

class DocumentoImportato extends DataClass
    implements Insertable<DocumentoImportato> {
  final int id;

  /// `importazione:<id>` — la stessa chiave che le schede scrivono in
  /// `origineIdStabile` e i piani in `origineId`.
  ///
  /// 🚨 **Senza l'indice del giorno**: una scheda multiday divisa in quattro
  /// genera quattro schede, ma il documento da cui vengono e' **uno**.
  final String origineId;

  /// I percorsi **relativi** dentro `Documents/foto/piani`, come lista JSON.
  ///
  /// ⚠️ Relativi e non assoluti: la cartella dei documenti cambia a ogni
  /// reinstallazione su iOS, e un percorso assoluto salvato oggi punta al vuoto
  /// domani.
  final String percorsi;

  /// `pdf` o `immagini` — serve a scegliere l'icona e l'avvertenza.
  final String tipo;
  final DateTime importatoIl;
  const DocumentoImportato({
    required this.id,
    required this.origineId,
    required this.percorsi,
    required this.tipo,
    required this.importatoIl,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['origine_id'] = Variable<String>(origineId);
    map['percorsi'] = Variable<String>(percorsi);
    map['tipo'] = Variable<String>(tipo);
    map['importato_il'] = Variable<DateTime>(importatoIl);
    return map;
  }

  DocumentiImportatiCompanion toCompanion(bool nullToAbsent) {
    return DocumentiImportatiCompanion(
      id: Value(id),
      origineId: Value(origineId),
      percorsi: Value(percorsi),
      tipo: Value(tipo),
      importatoIl: Value(importatoIl),
    );
  }

  factory DocumentoImportato.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DocumentoImportato(
      id: serializer.fromJson<int>(json['id']),
      origineId: serializer.fromJson<String>(json['origineId']),
      percorsi: serializer.fromJson<String>(json['percorsi']),
      tipo: serializer.fromJson<String>(json['tipo']),
      importatoIl: serializer.fromJson<DateTime>(json['importatoIl']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'origineId': serializer.toJson<String>(origineId),
      'percorsi': serializer.toJson<String>(percorsi),
      'tipo': serializer.toJson<String>(tipo),
      'importatoIl': serializer.toJson<DateTime>(importatoIl),
    };
  }

  DocumentoImportato copyWith({
    int? id,
    String? origineId,
    String? percorsi,
    String? tipo,
    DateTime? importatoIl,
  }) => DocumentoImportato(
    id: id ?? this.id,
    origineId: origineId ?? this.origineId,
    percorsi: percorsi ?? this.percorsi,
    tipo: tipo ?? this.tipo,
    importatoIl: importatoIl ?? this.importatoIl,
  );
  DocumentoImportato copyWithCompanion(DocumentiImportatiCompanion data) {
    return DocumentoImportato(
      id: data.id.present ? data.id.value : this.id,
      origineId: data.origineId.present ? data.origineId.value : this.origineId,
      percorsi: data.percorsi.present ? data.percorsi.value : this.percorsi,
      tipo: data.tipo.present ? data.tipo.value : this.tipo,
      importatoIl: data.importatoIl.present
          ? data.importatoIl.value
          : this.importatoIl,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DocumentoImportato(')
          ..write('id: $id, ')
          ..write('origineId: $origineId, ')
          ..write('percorsi: $percorsi, ')
          ..write('tipo: $tipo, ')
          ..write('importatoIl: $importatoIl')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, origineId, percorsi, tipo, importatoIl);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DocumentoImportato &&
          other.id == this.id &&
          other.origineId == this.origineId &&
          other.percorsi == this.percorsi &&
          other.tipo == this.tipo &&
          other.importatoIl == this.importatoIl);
}

class DocumentiImportatiCompanion extends UpdateCompanion<DocumentoImportato> {
  final Value<int> id;
  final Value<String> origineId;
  final Value<String> percorsi;
  final Value<String> tipo;
  final Value<DateTime> importatoIl;
  const DocumentiImportatiCompanion({
    this.id = const Value.absent(),
    this.origineId = const Value.absent(),
    this.percorsi = const Value.absent(),
    this.tipo = const Value.absent(),
    this.importatoIl = const Value.absent(),
  });
  DocumentiImportatiCompanion.insert({
    this.id = const Value.absent(),
    required String origineId,
    required String percorsi,
    required String tipo,
    required DateTime importatoIl,
  }) : origineId = Value(origineId),
       percorsi = Value(percorsi),
       tipo = Value(tipo),
       importatoIl = Value(importatoIl);
  static Insertable<DocumentoImportato> custom({
    Expression<int>? id,
    Expression<String>? origineId,
    Expression<String>? percorsi,
    Expression<String>? tipo,
    Expression<DateTime>? importatoIl,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (origineId != null) 'origine_id': origineId,
      if (percorsi != null) 'percorsi': percorsi,
      if (tipo != null) 'tipo': tipo,
      if (importatoIl != null) 'importato_il': importatoIl,
    });
  }

  DocumentiImportatiCompanion copyWith({
    Value<int>? id,
    Value<String>? origineId,
    Value<String>? percorsi,
    Value<String>? tipo,
    Value<DateTime>? importatoIl,
  }) {
    return DocumentiImportatiCompanion(
      id: id ?? this.id,
      origineId: origineId ?? this.origineId,
      percorsi: percorsi ?? this.percorsi,
      tipo: tipo ?? this.tipo,
      importatoIl: importatoIl ?? this.importatoIl,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (origineId.present) {
      map['origine_id'] = Variable<String>(origineId.value);
    }
    if (percorsi.present) {
      map['percorsi'] = Variable<String>(percorsi.value);
    }
    if (tipo.present) {
      map['tipo'] = Variable<String>(tipo.value);
    }
    if (importatoIl.present) {
      map['importato_il'] = Variable<DateTime>(importatoIl.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DocumentiImportatiCompanion(')
          ..write('id: $id, ')
          ..write('origineId: $origineId, ')
          ..write('percorsi: $percorsi, ')
          ..write('tipo: $tipo, ')
          ..write('importatoIl: $importatoIl')
          ..write(')'))
        .toString();
  }
}

abstract class _$ArchivioSalute extends GeneratedDatabase {
  _$ArchivioSalute(QueryExecutor e) : super(e);
  $ArchivioSaluteManager get managers => $ArchivioSaluteManager(this);
  late final $LettureSaluteTable lettureSalute = $LettureSaluteTable(this);
  late final $CampioniSonnoTable campioniSonno = $CampioniSonnoTable(this);
  late final $MisureCorpoTable misureCorpo = $MisureCorpoTable(this);
  late final $FotoProgressiTable fotoProgressi = $FotoProgressiTable(this);
  late final $PianiRicevutiTable pianiRicevuti = $PianiRicevutiTable(this);
  late final $ContenutiRifiutatiTable contenutiRifiutati =
      $ContenutiRifiutatiTable(this);
  late final $AllenamentiDaOrologioTable allenamentiDaOrologio =
      $AllenamentiDaOrologioTable(this);
  late final $SeduteAllenamentoTable seduteAllenamento =
      $SeduteAllenamentoTable(this);
  late final $SerieDelleSeduteTable serieDelleSedute = $SerieDelleSeduteTable(
    this,
  );
  late final $SettimanaProgrammataTable settimanaProgrammata =
      $SettimanaProgrammataTable(this);
  late final $AnalisiDelleSchedeTable analisiDelleSchede =
      $AnalisiDelleSchedeTable(this);
  late final $VersioniDelleSchedeTable versioniDelleSchede =
      $VersioniDelleSchedeTable(this);
  late final $BruciateDichiarateTable bruciateDichiarate =
      $BruciateDichiarateTable(this);
  late final $SchedeSulTelefonoTable schedeSulTelefono =
      $SchedeSulTelefonoTable(this);
  late final $VociDiarioTable vociDiario = $VociDiarioTable(this);
  late final $PreferitiCiboTable preferitiCibo = $PreferitiCiboTable(this);
  late final $ConsigliDelGiornoTable consigliDelGiorno =
      $ConsigliDelGiornoTable(this);
  late final $DocumentiImportatiTable documentiImportati =
      $DocumentiImportatiTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    lettureSalute,
    campioniSonno,
    misureCorpo,
    fotoProgressi,
    pianiRicevuti,
    contenutiRifiutati,
    allenamentiDaOrologio,
    seduteAllenamento,
    serieDelleSedute,
    settimanaProgrammata,
    analisiDelleSchede,
    versioniDelleSchede,
    bruciateDichiarate,
    schedeSulTelefono,
    vociDiario,
    preferitiCibo,
    consigliDelGiorno,
    documentiImportati,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'sedute_allenamento',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('serie_delle_sedute', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$LettureSaluteTableCreateCompanionBuilder =
    LettureSaluteCompanion Function({
      Value<int> id,
      required String fonte,
      required String metrica,
      required DateTime misurataIl,
      required DateTime giorno,
      required double valore,
    });
typedef $$LettureSaluteTableUpdateCompanionBuilder =
    LettureSaluteCompanion Function({
      Value<int> id,
      Value<String> fonte,
      Value<String> metrica,
      Value<DateTime> misurataIl,
      Value<DateTime> giorno,
      Value<double> valore,
    });

class $$LettureSaluteTableFilterComposer
    extends Composer<_$ArchivioSalute, $LettureSaluteTable> {
  $$LettureSaluteTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fonte => $composableBuilder(
    column: $table.fonte,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metrica => $composableBuilder(
    column: $table.metrica,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get misurataIl => $composableBuilder(
    column: $table.misurataIl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get giorno => $composableBuilder(
    column: $table.giorno,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get valore => $composableBuilder(
    column: $table.valore,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LettureSaluteTableOrderingComposer
    extends Composer<_$ArchivioSalute, $LettureSaluteTable> {
  $$LettureSaluteTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fonte => $composableBuilder(
    column: $table.fonte,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metrica => $composableBuilder(
    column: $table.metrica,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get misurataIl => $composableBuilder(
    column: $table.misurataIl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get giorno => $composableBuilder(
    column: $table.giorno,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get valore => $composableBuilder(
    column: $table.valore,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LettureSaluteTableAnnotationComposer
    extends Composer<_$ArchivioSalute, $LettureSaluteTable> {
  $$LettureSaluteTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get fonte =>
      $composableBuilder(column: $table.fonte, builder: (column) => column);

  GeneratedColumn<String> get metrica =>
      $composableBuilder(column: $table.metrica, builder: (column) => column);

  GeneratedColumn<DateTime> get misurataIl => $composableBuilder(
    column: $table.misurataIl,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get giorno =>
      $composableBuilder(column: $table.giorno, builder: (column) => column);

  GeneratedColumn<double> get valore =>
      $composableBuilder(column: $table.valore, builder: (column) => column);
}

class $$LettureSaluteTableTableManager
    extends
        RootTableManager<
          _$ArchivioSalute,
          $LettureSaluteTable,
          LetturaSalute,
          $$LettureSaluteTableFilterComposer,
          $$LettureSaluteTableOrderingComposer,
          $$LettureSaluteTableAnnotationComposer,
          $$LettureSaluteTableCreateCompanionBuilder,
          $$LettureSaluteTableUpdateCompanionBuilder,
          (
            LetturaSalute,
            BaseReferences<
              _$ArchivioSalute,
              $LettureSaluteTable,
              LetturaSalute
            >,
          ),
          LetturaSalute,
          PrefetchHooks Function()
        > {
  $$LettureSaluteTableTableManager(
    _$ArchivioSalute db,
    $LettureSaluteTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LettureSaluteTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LettureSaluteTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LettureSaluteTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> fonte = const Value.absent(),
                Value<String> metrica = const Value.absent(),
                Value<DateTime> misurataIl = const Value.absent(),
                Value<DateTime> giorno = const Value.absent(),
                Value<double> valore = const Value.absent(),
              }) => LettureSaluteCompanion(
                id: id,
                fonte: fonte,
                metrica: metrica,
                misurataIl: misurataIl,
                giorno: giorno,
                valore: valore,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String fonte,
                required String metrica,
                required DateTime misurataIl,
                required DateTime giorno,
                required double valore,
              }) => LettureSaluteCompanion.insert(
                id: id,
                fonte: fonte,
                metrica: metrica,
                misurataIl: misurataIl,
                giorno: giorno,
                valore: valore,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LettureSaluteTableProcessedTableManager =
    ProcessedTableManager<
      _$ArchivioSalute,
      $LettureSaluteTable,
      LetturaSalute,
      $$LettureSaluteTableFilterComposer,
      $$LettureSaluteTableOrderingComposer,
      $$LettureSaluteTableAnnotationComposer,
      $$LettureSaluteTableCreateCompanionBuilder,
      $$LettureSaluteTableUpdateCompanionBuilder,
      (
        LetturaSalute,
        BaseReferences<_$ArchivioSalute, $LettureSaluteTable, LetturaSalute>,
      ),
      LetturaSalute,
      PrefetchHooks Function()
    >;
typedef $$CampioniSonnoTableCreateCompanionBuilder =
    CampioniSonnoCompanion Function({
      Value<int> id,
      required String fonte,
      required DateTime notte,
      required DateTime iniziatoIl,
      required DateTime finitoIl,
      required int fase,
    });
typedef $$CampioniSonnoTableUpdateCompanionBuilder =
    CampioniSonnoCompanion Function({
      Value<int> id,
      Value<String> fonte,
      Value<DateTime> notte,
      Value<DateTime> iniziatoIl,
      Value<DateTime> finitoIl,
      Value<int> fase,
    });

class $$CampioniSonnoTableFilterComposer
    extends Composer<_$ArchivioSalute, $CampioniSonnoTable> {
  $$CampioniSonnoTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fonte => $composableBuilder(
    column: $table.fonte,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get notte => $composableBuilder(
    column: $table.notte,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get iniziatoIl => $composableBuilder(
    column: $table.iniziatoIl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get finitoIl => $composableBuilder(
    column: $table.finitoIl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fase => $composableBuilder(
    column: $table.fase,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CampioniSonnoTableOrderingComposer
    extends Composer<_$ArchivioSalute, $CampioniSonnoTable> {
  $$CampioniSonnoTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fonte => $composableBuilder(
    column: $table.fonte,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get notte => $composableBuilder(
    column: $table.notte,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get iniziatoIl => $composableBuilder(
    column: $table.iniziatoIl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get finitoIl => $composableBuilder(
    column: $table.finitoIl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fase => $composableBuilder(
    column: $table.fase,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CampioniSonnoTableAnnotationComposer
    extends Composer<_$ArchivioSalute, $CampioniSonnoTable> {
  $$CampioniSonnoTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get fonte =>
      $composableBuilder(column: $table.fonte, builder: (column) => column);

  GeneratedColumn<DateTime> get notte =>
      $composableBuilder(column: $table.notte, builder: (column) => column);

  GeneratedColumn<DateTime> get iniziatoIl => $composableBuilder(
    column: $table.iniziatoIl,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get finitoIl =>
      $composableBuilder(column: $table.finitoIl, builder: (column) => column);

  GeneratedColumn<int> get fase =>
      $composableBuilder(column: $table.fase, builder: (column) => column);
}

class $$CampioniSonnoTableTableManager
    extends
        RootTableManager<
          _$ArchivioSalute,
          $CampioniSonnoTable,
          CampioneSonno,
          $$CampioniSonnoTableFilterComposer,
          $$CampioniSonnoTableOrderingComposer,
          $$CampioniSonnoTableAnnotationComposer,
          $$CampioniSonnoTableCreateCompanionBuilder,
          $$CampioniSonnoTableUpdateCompanionBuilder,
          (
            CampioneSonno,
            BaseReferences<
              _$ArchivioSalute,
              $CampioniSonnoTable,
              CampioneSonno
            >,
          ),
          CampioneSonno,
          PrefetchHooks Function()
        > {
  $$CampioniSonnoTableTableManager(
    _$ArchivioSalute db,
    $CampioniSonnoTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CampioniSonnoTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CampioniSonnoTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CampioniSonnoTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> fonte = const Value.absent(),
                Value<DateTime> notte = const Value.absent(),
                Value<DateTime> iniziatoIl = const Value.absent(),
                Value<DateTime> finitoIl = const Value.absent(),
                Value<int> fase = const Value.absent(),
              }) => CampioniSonnoCompanion(
                id: id,
                fonte: fonte,
                notte: notte,
                iniziatoIl: iniziatoIl,
                finitoIl: finitoIl,
                fase: fase,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String fonte,
                required DateTime notte,
                required DateTime iniziatoIl,
                required DateTime finitoIl,
                required int fase,
              }) => CampioniSonnoCompanion.insert(
                id: id,
                fonte: fonte,
                notte: notte,
                iniziatoIl: iniziatoIl,
                finitoIl: finitoIl,
                fase: fase,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CampioniSonnoTableProcessedTableManager =
    ProcessedTableManager<
      _$ArchivioSalute,
      $CampioniSonnoTable,
      CampioneSonno,
      $$CampioniSonnoTableFilterComposer,
      $$CampioniSonnoTableOrderingComposer,
      $$CampioniSonnoTableAnnotationComposer,
      $$CampioniSonnoTableCreateCompanionBuilder,
      $$CampioniSonnoTableUpdateCompanionBuilder,
      (
        CampioneSonno,
        BaseReferences<_$ArchivioSalute, $CampioniSonnoTable, CampioneSonno>,
      ),
      CampioneSonno,
      PrefetchHooks Function()
    >;
typedef $$MisureCorpoTableCreateCompanionBuilder =
    MisureCorpoCompanion Function({
      Value<int> id,
      required DateTime giorno,
      Value<double?> pesoKg,
      Value<double?> massaGrassaPct,
      Value<double?> massaMagraKg,
      Value<String?> origine,
      Value<double?> vitaCm,
      Value<double?> toraceCm,
      Value<double?> braccioCm,
      Value<double?> cosciaCm,
      Value<String?> note,
    });
typedef $$MisureCorpoTableUpdateCompanionBuilder =
    MisureCorpoCompanion Function({
      Value<int> id,
      Value<DateTime> giorno,
      Value<double?> pesoKg,
      Value<double?> massaGrassaPct,
      Value<double?> massaMagraKg,
      Value<String?> origine,
      Value<double?> vitaCm,
      Value<double?> toraceCm,
      Value<double?> braccioCm,
      Value<double?> cosciaCm,
      Value<String?> note,
    });

class $$MisureCorpoTableFilterComposer
    extends Composer<_$ArchivioSalute, $MisureCorpoTable> {
  $$MisureCorpoTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get giorno => $composableBuilder(
    column: $table.giorno,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get pesoKg => $composableBuilder(
    column: $table.pesoKg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get massaGrassaPct => $composableBuilder(
    column: $table.massaGrassaPct,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get massaMagraKg => $composableBuilder(
    column: $table.massaMagraKg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get origine => $composableBuilder(
    column: $table.origine,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get vitaCm => $composableBuilder(
    column: $table.vitaCm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get toraceCm => $composableBuilder(
    column: $table.toraceCm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get braccioCm => $composableBuilder(
    column: $table.braccioCm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get cosciaCm => $composableBuilder(
    column: $table.cosciaCm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MisureCorpoTableOrderingComposer
    extends Composer<_$ArchivioSalute, $MisureCorpoTable> {
  $$MisureCorpoTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get giorno => $composableBuilder(
    column: $table.giorno,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get pesoKg => $composableBuilder(
    column: $table.pesoKg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get massaGrassaPct => $composableBuilder(
    column: $table.massaGrassaPct,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get massaMagraKg => $composableBuilder(
    column: $table.massaMagraKg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get origine => $composableBuilder(
    column: $table.origine,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get vitaCm => $composableBuilder(
    column: $table.vitaCm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get toraceCm => $composableBuilder(
    column: $table.toraceCm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get braccioCm => $composableBuilder(
    column: $table.braccioCm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get cosciaCm => $composableBuilder(
    column: $table.cosciaCm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MisureCorpoTableAnnotationComposer
    extends Composer<_$ArchivioSalute, $MisureCorpoTable> {
  $$MisureCorpoTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get giorno =>
      $composableBuilder(column: $table.giorno, builder: (column) => column);

  GeneratedColumn<double> get pesoKg =>
      $composableBuilder(column: $table.pesoKg, builder: (column) => column);

  GeneratedColumn<double> get massaGrassaPct => $composableBuilder(
    column: $table.massaGrassaPct,
    builder: (column) => column,
  );

  GeneratedColumn<double> get massaMagraKg => $composableBuilder(
    column: $table.massaMagraKg,
    builder: (column) => column,
  );

  GeneratedColumn<String> get origine =>
      $composableBuilder(column: $table.origine, builder: (column) => column);

  GeneratedColumn<double> get vitaCm =>
      $composableBuilder(column: $table.vitaCm, builder: (column) => column);

  GeneratedColumn<double> get toraceCm =>
      $composableBuilder(column: $table.toraceCm, builder: (column) => column);

  GeneratedColumn<double> get braccioCm =>
      $composableBuilder(column: $table.braccioCm, builder: (column) => column);

  GeneratedColumn<double> get cosciaCm =>
      $composableBuilder(column: $table.cosciaCm, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);
}

class $$MisureCorpoTableTableManager
    extends
        RootTableManager<
          _$ArchivioSalute,
          $MisureCorpoTable,
          MisuraCorpo,
          $$MisureCorpoTableFilterComposer,
          $$MisureCorpoTableOrderingComposer,
          $$MisureCorpoTableAnnotationComposer,
          $$MisureCorpoTableCreateCompanionBuilder,
          $$MisureCorpoTableUpdateCompanionBuilder,
          (
            MisuraCorpo,
            BaseReferences<_$ArchivioSalute, $MisureCorpoTable, MisuraCorpo>,
          ),
          MisuraCorpo,
          PrefetchHooks Function()
        > {
  $$MisureCorpoTableTableManager(_$ArchivioSalute db, $MisureCorpoTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MisureCorpoTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MisureCorpoTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MisureCorpoTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> giorno = const Value.absent(),
                Value<double?> pesoKg = const Value.absent(),
                Value<double?> massaGrassaPct = const Value.absent(),
                Value<double?> massaMagraKg = const Value.absent(),
                Value<String?> origine = const Value.absent(),
                Value<double?> vitaCm = const Value.absent(),
                Value<double?> toraceCm = const Value.absent(),
                Value<double?> braccioCm = const Value.absent(),
                Value<double?> cosciaCm = const Value.absent(),
                Value<String?> note = const Value.absent(),
              }) => MisureCorpoCompanion(
                id: id,
                giorno: giorno,
                pesoKg: pesoKg,
                massaGrassaPct: massaGrassaPct,
                massaMagraKg: massaMagraKg,
                origine: origine,
                vitaCm: vitaCm,
                toraceCm: toraceCm,
                braccioCm: braccioCm,
                cosciaCm: cosciaCm,
                note: note,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime giorno,
                Value<double?> pesoKg = const Value.absent(),
                Value<double?> massaGrassaPct = const Value.absent(),
                Value<double?> massaMagraKg = const Value.absent(),
                Value<String?> origine = const Value.absent(),
                Value<double?> vitaCm = const Value.absent(),
                Value<double?> toraceCm = const Value.absent(),
                Value<double?> braccioCm = const Value.absent(),
                Value<double?> cosciaCm = const Value.absent(),
                Value<String?> note = const Value.absent(),
              }) => MisureCorpoCompanion.insert(
                id: id,
                giorno: giorno,
                pesoKg: pesoKg,
                massaGrassaPct: massaGrassaPct,
                massaMagraKg: massaMagraKg,
                origine: origine,
                vitaCm: vitaCm,
                toraceCm: toraceCm,
                braccioCm: braccioCm,
                cosciaCm: cosciaCm,
                note: note,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MisureCorpoTableProcessedTableManager =
    ProcessedTableManager<
      _$ArchivioSalute,
      $MisureCorpoTable,
      MisuraCorpo,
      $$MisureCorpoTableFilterComposer,
      $$MisureCorpoTableOrderingComposer,
      $$MisureCorpoTableAnnotationComposer,
      $$MisureCorpoTableCreateCompanionBuilder,
      $$MisureCorpoTableUpdateCompanionBuilder,
      (
        MisuraCorpo,
        BaseReferences<_$ArchivioSalute, $MisureCorpoTable, MisuraCorpo>,
      ),
      MisuraCorpo,
      PrefetchHooks Function()
    >;
typedef $$FotoProgressiTableCreateCompanionBuilder =
    FotoProgressiCompanion Function({
      Value<int> id,
      required String percorso,
      required DateTime scattataIl,
      Value<int?> sessioneId,
      Value<int?> allenamentoOrologioId,
    });
typedef $$FotoProgressiTableUpdateCompanionBuilder =
    FotoProgressiCompanion Function({
      Value<int> id,
      Value<String> percorso,
      Value<DateTime> scattataIl,
      Value<int?> sessioneId,
      Value<int?> allenamentoOrologioId,
    });

class $$FotoProgressiTableFilterComposer
    extends Composer<_$ArchivioSalute, $FotoProgressiTable> {
  $$FotoProgressiTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get percorso => $composableBuilder(
    column: $table.percorso,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get scattataIl => $composableBuilder(
    column: $table.scattataIl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sessioneId => $composableBuilder(
    column: $table.sessioneId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get allenamentoOrologioId => $composableBuilder(
    column: $table.allenamentoOrologioId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FotoProgressiTableOrderingComposer
    extends Composer<_$ArchivioSalute, $FotoProgressiTable> {
  $$FotoProgressiTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get percorso => $composableBuilder(
    column: $table.percorso,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get scattataIl => $composableBuilder(
    column: $table.scattataIl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sessioneId => $composableBuilder(
    column: $table.sessioneId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get allenamentoOrologioId => $composableBuilder(
    column: $table.allenamentoOrologioId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FotoProgressiTableAnnotationComposer
    extends Composer<_$ArchivioSalute, $FotoProgressiTable> {
  $$FotoProgressiTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get percorso =>
      $composableBuilder(column: $table.percorso, builder: (column) => column);

  GeneratedColumn<DateTime> get scattataIl => $composableBuilder(
    column: $table.scattataIl,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sessioneId => $composableBuilder(
    column: $table.sessioneId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get allenamentoOrologioId => $composableBuilder(
    column: $table.allenamentoOrologioId,
    builder: (column) => column,
  );
}

class $$FotoProgressiTableTableManager
    extends
        RootTableManager<
          _$ArchivioSalute,
          $FotoProgressiTable,
          FotoProgresso,
          $$FotoProgressiTableFilterComposer,
          $$FotoProgressiTableOrderingComposer,
          $$FotoProgressiTableAnnotationComposer,
          $$FotoProgressiTableCreateCompanionBuilder,
          $$FotoProgressiTableUpdateCompanionBuilder,
          (
            FotoProgresso,
            BaseReferences<
              _$ArchivioSalute,
              $FotoProgressiTable,
              FotoProgresso
            >,
          ),
          FotoProgresso,
          PrefetchHooks Function()
        > {
  $$FotoProgressiTableTableManager(
    _$ArchivioSalute db,
    $FotoProgressiTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FotoProgressiTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FotoProgressiTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FotoProgressiTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> percorso = const Value.absent(),
                Value<DateTime> scattataIl = const Value.absent(),
                Value<int?> sessioneId = const Value.absent(),
                Value<int?> allenamentoOrologioId = const Value.absent(),
              }) => FotoProgressiCompanion(
                id: id,
                percorso: percorso,
                scattataIl: scattataIl,
                sessioneId: sessioneId,
                allenamentoOrologioId: allenamentoOrologioId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String percorso,
                required DateTime scattataIl,
                Value<int?> sessioneId = const Value.absent(),
                Value<int?> allenamentoOrologioId = const Value.absent(),
              }) => FotoProgressiCompanion.insert(
                id: id,
                percorso: percorso,
                scattataIl: scattataIl,
                sessioneId: sessioneId,
                allenamentoOrologioId: allenamentoOrologioId,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FotoProgressiTableProcessedTableManager =
    ProcessedTableManager<
      _$ArchivioSalute,
      $FotoProgressiTable,
      FotoProgresso,
      $$FotoProgressiTableFilterComposer,
      $$FotoProgressiTableOrderingComposer,
      $$FotoProgressiTableAnnotationComposer,
      $$FotoProgressiTableCreateCompanionBuilder,
      $$FotoProgressiTableUpdateCompanionBuilder,
      (
        FotoProgresso,
        BaseReferences<_$ArchivioSalute, $FotoProgressiTable, FotoProgresso>,
      ),
      FotoProgresso,
      PrefetchHooks Function()
    >;
typedef $$PianiRicevutiTableCreateCompanionBuilder =
    PianiRicevutiCompanion Function({
      Value<int> id,
      required int messaggioId,
      required int mittenteId,
      Value<String?> origineId,
      required String nome,
      required String piano,
      required DateTime ricevutaIl,
      Value<DateTime?> aggiornatoIl,
      Value<String?> pdfOriginale,
      Value<bool> importato,
    });
typedef $$PianiRicevutiTableUpdateCompanionBuilder =
    PianiRicevutiCompanion Function({
      Value<int> id,
      Value<int> messaggioId,
      Value<int> mittenteId,
      Value<String?> origineId,
      Value<String> nome,
      Value<String> piano,
      Value<DateTime> ricevutaIl,
      Value<DateTime?> aggiornatoIl,
      Value<String?> pdfOriginale,
      Value<bool> importato,
    });

class $$PianiRicevutiTableFilterComposer
    extends Composer<_$ArchivioSalute, $PianiRicevutiTable> {
  $$PianiRicevutiTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get messaggioId => $composableBuilder(
    column: $table.messaggioId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get mittenteId => $composableBuilder(
    column: $table.mittenteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get origineId => $composableBuilder(
    column: $table.origineId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nome => $composableBuilder(
    column: $table.nome,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get piano => $composableBuilder(
    column: $table.piano,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get ricevutaIl => $composableBuilder(
    column: $table.ricevutaIl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get aggiornatoIl => $composableBuilder(
    column: $table.aggiornatoIl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pdfOriginale => $composableBuilder(
    column: $table.pdfOriginale,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get importato => $composableBuilder(
    column: $table.importato,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PianiRicevutiTableOrderingComposer
    extends Composer<_$ArchivioSalute, $PianiRicevutiTable> {
  $$PianiRicevutiTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get messaggioId => $composableBuilder(
    column: $table.messaggioId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get mittenteId => $composableBuilder(
    column: $table.mittenteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get origineId => $composableBuilder(
    column: $table.origineId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nome => $composableBuilder(
    column: $table.nome,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get piano => $composableBuilder(
    column: $table.piano,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get ricevutaIl => $composableBuilder(
    column: $table.ricevutaIl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get aggiornatoIl => $composableBuilder(
    column: $table.aggiornatoIl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pdfOriginale => $composableBuilder(
    column: $table.pdfOriginale,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get importato => $composableBuilder(
    column: $table.importato,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PianiRicevutiTableAnnotationComposer
    extends Composer<_$ArchivioSalute, $PianiRicevutiTable> {
  $$PianiRicevutiTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get messaggioId => $composableBuilder(
    column: $table.messaggioId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get mittenteId => $composableBuilder(
    column: $table.mittenteId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get origineId =>
      $composableBuilder(column: $table.origineId, builder: (column) => column);

  GeneratedColumn<String> get nome =>
      $composableBuilder(column: $table.nome, builder: (column) => column);

  GeneratedColumn<String> get piano =>
      $composableBuilder(column: $table.piano, builder: (column) => column);

  GeneratedColumn<DateTime> get ricevutaIl => $composableBuilder(
    column: $table.ricevutaIl,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get aggiornatoIl => $composableBuilder(
    column: $table.aggiornatoIl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pdfOriginale => $composableBuilder(
    column: $table.pdfOriginale,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get importato =>
      $composableBuilder(column: $table.importato, builder: (column) => column);
}

class $$PianiRicevutiTableTableManager
    extends
        RootTableManager<
          _$ArchivioSalute,
          $PianiRicevutiTable,
          PianoRicevuto,
          $$PianiRicevutiTableFilterComposer,
          $$PianiRicevutiTableOrderingComposer,
          $$PianiRicevutiTableAnnotationComposer,
          $$PianiRicevutiTableCreateCompanionBuilder,
          $$PianiRicevutiTableUpdateCompanionBuilder,
          (
            PianoRicevuto,
            BaseReferences<
              _$ArchivioSalute,
              $PianiRicevutiTable,
              PianoRicevuto
            >,
          ),
          PianoRicevuto,
          PrefetchHooks Function()
        > {
  $$PianiRicevutiTableTableManager(
    _$ArchivioSalute db,
    $PianiRicevutiTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PianiRicevutiTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PianiRicevutiTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PianiRicevutiTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> messaggioId = const Value.absent(),
                Value<int> mittenteId = const Value.absent(),
                Value<String?> origineId = const Value.absent(),
                Value<String> nome = const Value.absent(),
                Value<String> piano = const Value.absent(),
                Value<DateTime> ricevutaIl = const Value.absent(),
                Value<DateTime?> aggiornatoIl = const Value.absent(),
                Value<String?> pdfOriginale = const Value.absent(),
                Value<bool> importato = const Value.absent(),
              }) => PianiRicevutiCompanion(
                id: id,
                messaggioId: messaggioId,
                mittenteId: mittenteId,
                origineId: origineId,
                nome: nome,
                piano: piano,
                ricevutaIl: ricevutaIl,
                aggiornatoIl: aggiornatoIl,
                pdfOriginale: pdfOriginale,
                importato: importato,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int messaggioId,
                required int mittenteId,
                Value<String?> origineId = const Value.absent(),
                required String nome,
                required String piano,
                required DateTime ricevutaIl,
                Value<DateTime?> aggiornatoIl = const Value.absent(),
                Value<String?> pdfOriginale = const Value.absent(),
                Value<bool> importato = const Value.absent(),
              }) => PianiRicevutiCompanion.insert(
                id: id,
                messaggioId: messaggioId,
                mittenteId: mittenteId,
                origineId: origineId,
                nome: nome,
                piano: piano,
                ricevutaIl: ricevutaIl,
                aggiornatoIl: aggiornatoIl,
                pdfOriginale: pdfOriginale,
                importato: importato,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PianiRicevutiTableProcessedTableManager =
    ProcessedTableManager<
      _$ArchivioSalute,
      $PianiRicevutiTable,
      PianoRicevuto,
      $$PianiRicevutiTableFilterComposer,
      $$PianiRicevutiTableOrderingComposer,
      $$PianiRicevutiTableAnnotationComposer,
      $$PianiRicevutiTableCreateCompanionBuilder,
      $$PianiRicevutiTableUpdateCompanionBuilder,
      (
        PianoRicevuto,
        BaseReferences<_$ArchivioSalute, $PianiRicevutiTable, PianoRicevuto>,
      ),
      PianoRicevuto,
      PrefetchHooks Function()
    >;
typedef $$ContenutiRifiutatiTableCreateCompanionBuilder =
    ContenutiRifiutatiCompanion Function({
      Value<int> id,
      required String origineId,
      required DateTime rifiutatoIl,
    });
typedef $$ContenutiRifiutatiTableUpdateCompanionBuilder =
    ContenutiRifiutatiCompanion Function({
      Value<int> id,
      Value<String> origineId,
      Value<DateTime> rifiutatoIl,
    });

class $$ContenutiRifiutatiTableFilterComposer
    extends Composer<_$ArchivioSalute, $ContenutiRifiutatiTable> {
  $$ContenutiRifiutatiTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get origineId => $composableBuilder(
    column: $table.origineId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get rifiutatoIl => $composableBuilder(
    column: $table.rifiutatoIl,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ContenutiRifiutatiTableOrderingComposer
    extends Composer<_$ArchivioSalute, $ContenutiRifiutatiTable> {
  $$ContenutiRifiutatiTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get origineId => $composableBuilder(
    column: $table.origineId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get rifiutatoIl => $composableBuilder(
    column: $table.rifiutatoIl,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ContenutiRifiutatiTableAnnotationComposer
    extends Composer<_$ArchivioSalute, $ContenutiRifiutatiTable> {
  $$ContenutiRifiutatiTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get origineId =>
      $composableBuilder(column: $table.origineId, builder: (column) => column);

  GeneratedColumn<DateTime> get rifiutatoIl => $composableBuilder(
    column: $table.rifiutatoIl,
    builder: (column) => column,
  );
}

class $$ContenutiRifiutatiTableTableManager
    extends
        RootTableManager<
          _$ArchivioSalute,
          $ContenutiRifiutatiTable,
          ContenutoRifiutato,
          $$ContenutiRifiutatiTableFilterComposer,
          $$ContenutiRifiutatiTableOrderingComposer,
          $$ContenutiRifiutatiTableAnnotationComposer,
          $$ContenutiRifiutatiTableCreateCompanionBuilder,
          $$ContenutiRifiutatiTableUpdateCompanionBuilder,
          (
            ContenutoRifiutato,
            BaseReferences<
              _$ArchivioSalute,
              $ContenutiRifiutatiTable,
              ContenutoRifiutato
            >,
          ),
          ContenutoRifiutato,
          PrefetchHooks Function()
        > {
  $$ContenutiRifiutatiTableTableManager(
    _$ArchivioSalute db,
    $ContenutiRifiutatiTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ContenutiRifiutatiTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ContenutiRifiutatiTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ContenutiRifiutatiTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> origineId = const Value.absent(),
                Value<DateTime> rifiutatoIl = const Value.absent(),
              }) => ContenutiRifiutatiCompanion(
                id: id,
                origineId: origineId,
                rifiutatoIl: rifiutatoIl,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String origineId,
                required DateTime rifiutatoIl,
              }) => ContenutiRifiutatiCompanion.insert(
                id: id,
                origineId: origineId,
                rifiutatoIl: rifiutatoIl,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ContenutiRifiutatiTableProcessedTableManager =
    ProcessedTableManager<
      _$ArchivioSalute,
      $ContenutiRifiutatiTable,
      ContenutoRifiutato,
      $$ContenutiRifiutatiTableFilterComposer,
      $$ContenutiRifiutatiTableOrderingComposer,
      $$ContenutiRifiutatiTableAnnotationComposer,
      $$ContenutiRifiutatiTableCreateCompanionBuilder,
      $$ContenutiRifiutatiTableUpdateCompanionBuilder,
      (
        ContenutoRifiutato,
        BaseReferences<
          _$ArchivioSalute,
          $ContenutiRifiutatiTable,
          ContenutoRifiutato
        >,
      ),
      ContenutoRifiutato,
      PrefetchHooks Function()
    >;
typedef $$AllenamentiDaOrologioTableCreateCompanionBuilder =
    AllenamentiDaOrologioCompanion Function({
      Value<int> id,
      required String fonte,
      required String tipo,
      required DateTime iniziatoIl,
      required DateTime finitoIl,
      Value<int?> kcal,
      Value<int?> distanzaMetri,
      Value<int?> passi,
      Value<int?> schedaAssegnata,
      Value<String?> tipoScelto,
      Value<int?> kcalCorrette,
      Value<bool> nascosto,
      Value<bool> staccato,
      Value<bool> contaComeExtra,
    });
typedef $$AllenamentiDaOrologioTableUpdateCompanionBuilder =
    AllenamentiDaOrologioCompanion Function({
      Value<int> id,
      Value<String> fonte,
      Value<String> tipo,
      Value<DateTime> iniziatoIl,
      Value<DateTime> finitoIl,
      Value<int?> kcal,
      Value<int?> distanzaMetri,
      Value<int?> passi,
      Value<int?> schedaAssegnata,
      Value<String?> tipoScelto,
      Value<int?> kcalCorrette,
      Value<bool> nascosto,
      Value<bool> staccato,
      Value<bool> contaComeExtra,
    });

class $$AllenamentiDaOrologioTableFilterComposer
    extends Composer<_$ArchivioSalute, $AllenamentiDaOrologioTable> {
  $$AllenamentiDaOrologioTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fonte => $composableBuilder(
    column: $table.fonte,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tipo => $composableBuilder(
    column: $table.tipo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get iniziatoIl => $composableBuilder(
    column: $table.iniziatoIl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get finitoIl => $composableBuilder(
    column: $table.finitoIl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get kcal => $composableBuilder(
    column: $table.kcal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get distanzaMetri => $composableBuilder(
    column: $table.distanzaMetri,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get passi => $composableBuilder(
    column: $table.passi,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get schedaAssegnata => $composableBuilder(
    column: $table.schedaAssegnata,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tipoScelto => $composableBuilder(
    column: $table.tipoScelto,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get kcalCorrette => $composableBuilder(
    column: $table.kcalCorrette,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get nascosto => $composableBuilder(
    column: $table.nascosto,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get staccato => $composableBuilder(
    column: $table.staccato,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get contaComeExtra => $composableBuilder(
    column: $table.contaComeExtra,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AllenamentiDaOrologioTableOrderingComposer
    extends Composer<_$ArchivioSalute, $AllenamentiDaOrologioTable> {
  $$AllenamentiDaOrologioTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fonte => $composableBuilder(
    column: $table.fonte,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tipo => $composableBuilder(
    column: $table.tipo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get iniziatoIl => $composableBuilder(
    column: $table.iniziatoIl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get finitoIl => $composableBuilder(
    column: $table.finitoIl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get kcal => $composableBuilder(
    column: $table.kcal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get distanzaMetri => $composableBuilder(
    column: $table.distanzaMetri,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get passi => $composableBuilder(
    column: $table.passi,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get schedaAssegnata => $composableBuilder(
    column: $table.schedaAssegnata,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tipoScelto => $composableBuilder(
    column: $table.tipoScelto,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get kcalCorrette => $composableBuilder(
    column: $table.kcalCorrette,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get nascosto => $composableBuilder(
    column: $table.nascosto,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get staccato => $composableBuilder(
    column: $table.staccato,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get contaComeExtra => $composableBuilder(
    column: $table.contaComeExtra,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AllenamentiDaOrologioTableAnnotationComposer
    extends Composer<_$ArchivioSalute, $AllenamentiDaOrologioTable> {
  $$AllenamentiDaOrologioTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get fonte =>
      $composableBuilder(column: $table.fonte, builder: (column) => column);

  GeneratedColumn<String> get tipo =>
      $composableBuilder(column: $table.tipo, builder: (column) => column);

  GeneratedColumn<DateTime> get iniziatoIl => $composableBuilder(
    column: $table.iniziatoIl,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get finitoIl =>
      $composableBuilder(column: $table.finitoIl, builder: (column) => column);

  GeneratedColumn<int> get kcal =>
      $composableBuilder(column: $table.kcal, builder: (column) => column);

  GeneratedColumn<int> get distanzaMetri => $composableBuilder(
    column: $table.distanzaMetri,
    builder: (column) => column,
  );

  GeneratedColumn<int> get passi =>
      $composableBuilder(column: $table.passi, builder: (column) => column);

  GeneratedColumn<int> get schedaAssegnata => $composableBuilder(
    column: $table.schedaAssegnata,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tipoScelto => $composableBuilder(
    column: $table.tipoScelto,
    builder: (column) => column,
  );

  GeneratedColumn<int> get kcalCorrette => $composableBuilder(
    column: $table.kcalCorrette,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get nascosto =>
      $composableBuilder(column: $table.nascosto, builder: (column) => column);

  GeneratedColumn<bool> get staccato =>
      $composableBuilder(column: $table.staccato, builder: (column) => column);

  GeneratedColumn<bool> get contaComeExtra => $composableBuilder(
    column: $table.contaComeExtra,
    builder: (column) => column,
  );
}

class $$AllenamentiDaOrologioTableTableManager
    extends
        RootTableManager<
          _$ArchivioSalute,
          $AllenamentiDaOrologioTable,
          AllenamentoDaOrologio,
          $$AllenamentiDaOrologioTableFilterComposer,
          $$AllenamentiDaOrologioTableOrderingComposer,
          $$AllenamentiDaOrologioTableAnnotationComposer,
          $$AllenamentiDaOrologioTableCreateCompanionBuilder,
          $$AllenamentiDaOrologioTableUpdateCompanionBuilder,
          (
            AllenamentoDaOrologio,
            BaseReferences<
              _$ArchivioSalute,
              $AllenamentiDaOrologioTable,
              AllenamentoDaOrologio
            >,
          ),
          AllenamentoDaOrologio,
          PrefetchHooks Function()
        > {
  $$AllenamentiDaOrologioTableTableManager(
    _$ArchivioSalute db,
    $AllenamentiDaOrologioTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AllenamentiDaOrologioTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$AllenamentiDaOrologioTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$AllenamentiDaOrologioTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> fonte = const Value.absent(),
                Value<String> tipo = const Value.absent(),
                Value<DateTime> iniziatoIl = const Value.absent(),
                Value<DateTime> finitoIl = const Value.absent(),
                Value<int?> kcal = const Value.absent(),
                Value<int?> distanzaMetri = const Value.absent(),
                Value<int?> passi = const Value.absent(),
                Value<int?> schedaAssegnata = const Value.absent(),
                Value<String?> tipoScelto = const Value.absent(),
                Value<int?> kcalCorrette = const Value.absent(),
                Value<bool> nascosto = const Value.absent(),
                Value<bool> staccato = const Value.absent(),
                Value<bool> contaComeExtra = const Value.absent(),
              }) => AllenamentiDaOrologioCompanion(
                id: id,
                fonte: fonte,
                tipo: tipo,
                iniziatoIl: iniziatoIl,
                finitoIl: finitoIl,
                kcal: kcal,
                distanzaMetri: distanzaMetri,
                passi: passi,
                schedaAssegnata: schedaAssegnata,
                tipoScelto: tipoScelto,
                kcalCorrette: kcalCorrette,
                nascosto: nascosto,
                staccato: staccato,
                contaComeExtra: contaComeExtra,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String fonte,
                required String tipo,
                required DateTime iniziatoIl,
                required DateTime finitoIl,
                Value<int?> kcal = const Value.absent(),
                Value<int?> distanzaMetri = const Value.absent(),
                Value<int?> passi = const Value.absent(),
                Value<int?> schedaAssegnata = const Value.absent(),
                Value<String?> tipoScelto = const Value.absent(),
                Value<int?> kcalCorrette = const Value.absent(),
                Value<bool> nascosto = const Value.absent(),
                Value<bool> staccato = const Value.absent(),
                Value<bool> contaComeExtra = const Value.absent(),
              }) => AllenamentiDaOrologioCompanion.insert(
                id: id,
                fonte: fonte,
                tipo: tipo,
                iniziatoIl: iniziatoIl,
                finitoIl: finitoIl,
                kcal: kcal,
                distanzaMetri: distanzaMetri,
                passi: passi,
                schedaAssegnata: schedaAssegnata,
                tipoScelto: tipoScelto,
                kcalCorrette: kcalCorrette,
                nascosto: nascosto,
                staccato: staccato,
                contaComeExtra: contaComeExtra,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AllenamentiDaOrologioTableProcessedTableManager =
    ProcessedTableManager<
      _$ArchivioSalute,
      $AllenamentiDaOrologioTable,
      AllenamentoDaOrologio,
      $$AllenamentiDaOrologioTableFilterComposer,
      $$AllenamentiDaOrologioTableOrderingComposer,
      $$AllenamentiDaOrologioTableAnnotationComposer,
      $$AllenamentiDaOrologioTableCreateCompanionBuilder,
      $$AllenamentiDaOrologioTableUpdateCompanionBuilder,
      (
        AllenamentoDaOrologio,
        BaseReferences<
          _$ArchivioSalute,
          $AllenamentiDaOrologioTable,
          AllenamentoDaOrologio
        >,
      ),
      AllenamentoDaOrologio,
      PrefetchHooks Function()
    >;
typedef $$SeduteAllenamentoTableCreateCompanionBuilder =
    SeduteAllenamentoCompanion Function({
      Value<int> id,
      Value<bool> contaComeExtra,
      Value<int?> idServer,
      Value<int?> schedaServerId,
      Value<String?> nomeScheda,
      required DateTime iniziataIl,
      Value<DateTime?> finitaIl,
      Value<int?> kcal,
      Value<bool> kcalAMano,
      Value<String?> note,
    });
typedef $$SeduteAllenamentoTableUpdateCompanionBuilder =
    SeduteAllenamentoCompanion Function({
      Value<int> id,
      Value<bool> contaComeExtra,
      Value<int?> idServer,
      Value<int?> schedaServerId,
      Value<String?> nomeScheda,
      Value<DateTime> iniziataIl,
      Value<DateTime?> finitaIl,
      Value<int?> kcal,
      Value<bool> kcalAMano,
      Value<String?> note,
    });

final class $$SeduteAllenamentoTableReferences
    extends
        BaseReferences<
          _$ArchivioSalute,
          $SeduteAllenamentoTable,
          SedutaAllenamento
        > {
  $$SeduteAllenamentoTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$SerieDelleSeduteTable, List<SerieSeduta>>
  _serieDelleSeduteRefsTable(_$ArchivioSalute db) =>
      MultiTypedResultKey.fromTable(
        db.serieDelleSedute,
        aliasName: 'sedute_allenamento__id__serie_delle_sedute__seduta_id',
      );

  $$SerieDelleSeduteTableProcessedTableManager get serieDelleSeduteRefs {
    final manager = $$SerieDelleSeduteTableTableManager(
      $_db,
      $_db.serieDelleSedute,
    ).filter((f) => f.sedutaId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _serieDelleSeduteRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SeduteAllenamentoTableFilterComposer
    extends Composer<_$ArchivioSalute, $SeduteAllenamentoTable> {
  $$SeduteAllenamentoTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get contaComeExtra => $composableBuilder(
    column: $table.contaComeExtra,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get idServer => $composableBuilder(
    column: $table.idServer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get schedaServerId => $composableBuilder(
    column: $table.schedaServerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nomeScheda => $composableBuilder(
    column: $table.nomeScheda,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get iniziataIl => $composableBuilder(
    column: $table.iniziataIl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get finitaIl => $composableBuilder(
    column: $table.finitaIl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get kcal => $composableBuilder(
    column: $table.kcal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get kcalAMano => $composableBuilder(
    column: $table.kcalAMano,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> serieDelleSeduteRefs(
    Expression<bool> Function($$SerieDelleSeduteTableFilterComposer f) f,
  ) {
    final $$SerieDelleSeduteTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.serieDelleSedute,
      getReferencedColumn: (t) => t.sedutaId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SerieDelleSeduteTableFilterComposer(
            $db: $db,
            $table: $db.serieDelleSedute,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SeduteAllenamentoTableOrderingComposer
    extends Composer<_$ArchivioSalute, $SeduteAllenamentoTable> {
  $$SeduteAllenamentoTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get contaComeExtra => $composableBuilder(
    column: $table.contaComeExtra,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get idServer => $composableBuilder(
    column: $table.idServer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get schedaServerId => $composableBuilder(
    column: $table.schedaServerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nomeScheda => $composableBuilder(
    column: $table.nomeScheda,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get iniziataIl => $composableBuilder(
    column: $table.iniziataIl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get finitaIl => $composableBuilder(
    column: $table.finitaIl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get kcal => $composableBuilder(
    column: $table.kcal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get kcalAMano => $composableBuilder(
    column: $table.kcalAMano,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SeduteAllenamentoTableAnnotationComposer
    extends Composer<_$ArchivioSalute, $SeduteAllenamentoTable> {
  $$SeduteAllenamentoTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<bool> get contaComeExtra => $composableBuilder(
    column: $table.contaComeExtra,
    builder: (column) => column,
  );

  GeneratedColumn<int> get idServer =>
      $composableBuilder(column: $table.idServer, builder: (column) => column);

  GeneratedColumn<int> get schedaServerId => $composableBuilder(
    column: $table.schedaServerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get nomeScheda => $composableBuilder(
    column: $table.nomeScheda,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get iniziataIl => $composableBuilder(
    column: $table.iniziataIl,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get finitaIl =>
      $composableBuilder(column: $table.finitaIl, builder: (column) => column);

  GeneratedColumn<int> get kcal =>
      $composableBuilder(column: $table.kcal, builder: (column) => column);

  GeneratedColumn<bool> get kcalAMano =>
      $composableBuilder(column: $table.kcalAMano, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  Expression<T> serieDelleSeduteRefs<T extends Object>(
    Expression<T> Function($$SerieDelleSeduteTableAnnotationComposer a) f,
  ) {
    final $$SerieDelleSeduteTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.serieDelleSedute,
      getReferencedColumn: (t) => t.sedutaId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SerieDelleSeduteTableAnnotationComposer(
            $db: $db,
            $table: $db.serieDelleSedute,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SeduteAllenamentoTableTableManager
    extends
        RootTableManager<
          _$ArchivioSalute,
          $SeduteAllenamentoTable,
          SedutaAllenamento,
          $$SeduteAllenamentoTableFilterComposer,
          $$SeduteAllenamentoTableOrderingComposer,
          $$SeduteAllenamentoTableAnnotationComposer,
          $$SeduteAllenamentoTableCreateCompanionBuilder,
          $$SeduteAllenamentoTableUpdateCompanionBuilder,
          (SedutaAllenamento, $$SeduteAllenamentoTableReferences),
          SedutaAllenamento,
          PrefetchHooks Function({bool serieDelleSeduteRefs})
        > {
  $$SeduteAllenamentoTableTableManager(
    _$ArchivioSalute db,
    $SeduteAllenamentoTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SeduteAllenamentoTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SeduteAllenamentoTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SeduteAllenamentoTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<bool> contaComeExtra = const Value.absent(),
                Value<int?> idServer = const Value.absent(),
                Value<int?> schedaServerId = const Value.absent(),
                Value<String?> nomeScheda = const Value.absent(),
                Value<DateTime> iniziataIl = const Value.absent(),
                Value<DateTime?> finitaIl = const Value.absent(),
                Value<int?> kcal = const Value.absent(),
                Value<bool> kcalAMano = const Value.absent(),
                Value<String?> note = const Value.absent(),
              }) => SeduteAllenamentoCompanion(
                id: id,
                contaComeExtra: contaComeExtra,
                idServer: idServer,
                schedaServerId: schedaServerId,
                nomeScheda: nomeScheda,
                iniziataIl: iniziataIl,
                finitaIl: finitaIl,
                kcal: kcal,
                kcalAMano: kcalAMano,
                note: note,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<bool> contaComeExtra = const Value.absent(),
                Value<int?> idServer = const Value.absent(),
                Value<int?> schedaServerId = const Value.absent(),
                Value<String?> nomeScheda = const Value.absent(),
                required DateTime iniziataIl,
                Value<DateTime?> finitaIl = const Value.absent(),
                Value<int?> kcal = const Value.absent(),
                Value<bool> kcalAMano = const Value.absent(),
                Value<String?> note = const Value.absent(),
              }) => SeduteAllenamentoCompanion.insert(
                id: id,
                contaComeExtra: contaComeExtra,
                idServer: idServer,
                schedaServerId: schedaServerId,
                nomeScheda: nomeScheda,
                iniziataIl: iniziataIl,
                finitaIl: finitaIl,
                kcal: kcal,
                kcalAMano: kcalAMano,
                note: note,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SeduteAllenamentoTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({serieDelleSeduteRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (serieDelleSeduteRefs) db.serieDelleSedute,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (serieDelleSeduteRefs)
                    await $_getPrefetchedData<
                      SedutaAllenamento,
                      $SeduteAllenamentoTable,
                      SerieSeduta
                    >(
                      currentTable: table,
                      referencedTable: $$SeduteAllenamentoTableReferences
                          ._serieDelleSeduteRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$SeduteAllenamentoTableReferences(
                            db,
                            table,
                            p0,
                          ).serieDelleSeduteRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.sedutaId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$SeduteAllenamentoTableProcessedTableManager =
    ProcessedTableManager<
      _$ArchivioSalute,
      $SeduteAllenamentoTable,
      SedutaAllenamento,
      $$SeduteAllenamentoTableFilterComposer,
      $$SeduteAllenamentoTableOrderingComposer,
      $$SeduteAllenamentoTableAnnotationComposer,
      $$SeduteAllenamentoTableCreateCompanionBuilder,
      $$SeduteAllenamentoTableUpdateCompanionBuilder,
      (SedutaAllenamento, $$SeduteAllenamentoTableReferences),
      SedutaAllenamento,
      PrefetchHooks Function({bool serieDelleSeduteRefs})
    >;
typedef $$SerieDelleSeduteTableCreateCompanionBuilder =
    SerieDelleSeduteCompanion Function({
      Value<int> id,
      required int sedutaId,
      required int esercizioId,
      required String nomeEsercizio,
      Value<double?> met,
      required int numero,
      Value<int?> ripetizioni,
      Value<double?> pesoKg,
      Value<int?> durataSec,
      Value<int?> riposoSec,
      Value<DateTime?> fattaIl,
    });
typedef $$SerieDelleSeduteTableUpdateCompanionBuilder =
    SerieDelleSeduteCompanion Function({
      Value<int> id,
      Value<int> sedutaId,
      Value<int> esercizioId,
      Value<String> nomeEsercizio,
      Value<double?> met,
      Value<int> numero,
      Value<int?> ripetizioni,
      Value<double?> pesoKg,
      Value<int?> durataSec,
      Value<int?> riposoSec,
      Value<DateTime?> fattaIl,
    });

final class $$SerieDelleSeduteTableReferences
    extends
        BaseReferences<_$ArchivioSalute, $SerieDelleSeduteTable, SerieSeduta> {
  $$SerieDelleSeduteTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $SeduteAllenamentoTable _sedutaIdTable(_$ArchivioSalute db) => db
      .seduteAllenamento
      .createAlias('serie_delle_sedute__seduta_id__sedute_allenamento__id');

  $$SeduteAllenamentoTableProcessedTableManager get sedutaId {
    final $_column = $_itemColumn<int>('seduta_id')!;

    final manager = $$SeduteAllenamentoTableTableManager(
      $_db,
      $_db.seduteAllenamento,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sedutaIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SerieDelleSeduteTableFilterComposer
    extends Composer<_$ArchivioSalute, $SerieDelleSeduteTable> {
  $$SerieDelleSeduteTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get esercizioId => $composableBuilder(
    column: $table.esercizioId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nomeEsercizio => $composableBuilder(
    column: $table.nomeEsercizio,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get met => $composableBuilder(
    column: $table.met,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get numero => $composableBuilder(
    column: $table.numero,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ripetizioni => $composableBuilder(
    column: $table.ripetizioni,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get pesoKg => $composableBuilder(
    column: $table.pesoKg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durataSec => $composableBuilder(
    column: $table.durataSec,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get riposoSec => $composableBuilder(
    column: $table.riposoSec,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fattaIl => $composableBuilder(
    column: $table.fattaIl,
    builder: (column) => ColumnFilters(column),
  );

  $$SeduteAllenamentoTableFilterComposer get sedutaId {
    final $$SeduteAllenamentoTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sedutaId,
      referencedTable: $db.seduteAllenamento,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SeduteAllenamentoTableFilterComposer(
            $db: $db,
            $table: $db.seduteAllenamento,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SerieDelleSeduteTableOrderingComposer
    extends Composer<_$ArchivioSalute, $SerieDelleSeduteTable> {
  $$SerieDelleSeduteTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get esercizioId => $composableBuilder(
    column: $table.esercizioId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nomeEsercizio => $composableBuilder(
    column: $table.nomeEsercizio,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get met => $composableBuilder(
    column: $table.met,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get numero => $composableBuilder(
    column: $table.numero,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ripetizioni => $composableBuilder(
    column: $table.ripetizioni,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get pesoKg => $composableBuilder(
    column: $table.pesoKg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durataSec => $composableBuilder(
    column: $table.durataSec,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get riposoSec => $composableBuilder(
    column: $table.riposoSec,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fattaIl => $composableBuilder(
    column: $table.fattaIl,
    builder: (column) => ColumnOrderings(column),
  );

  $$SeduteAllenamentoTableOrderingComposer get sedutaId {
    final $$SeduteAllenamentoTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sedutaId,
      referencedTable: $db.seduteAllenamento,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SeduteAllenamentoTableOrderingComposer(
            $db: $db,
            $table: $db.seduteAllenamento,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SerieDelleSeduteTableAnnotationComposer
    extends Composer<_$ArchivioSalute, $SerieDelleSeduteTable> {
  $$SerieDelleSeduteTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get esercizioId => $composableBuilder(
    column: $table.esercizioId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get nomeEsercizio => $composableBuilder(
    column: $table.nomeEsercizio,
    builder: (column) => column,
  );

  GeneratedColumn<double> get met =>
      $composableBuilder(column: $table.met, builder: (column) => column);

  GeneratedColumn<int> get numero =>
      $composableBuilder(column: $table.numero, builder: (column) => column);

  GeneratedColumn<int> get ripetizioni => $composableBuilder(
    column: $table.ripetizioni,
    builder: (column) => column,
  );

  GeneratedColumn<double> get pesoKg =>
      $composableBuilder(column: $table.pesoKg, builder: (column) => column);

  GeneratedColumn<int> get durataSec =>
      $composableBuilder(column: $table.durataSec, builder: (column) => column);

  GeneratedColumn<int> get riposoSec =>
      $composableBuilder(column: $table.riposoSec, builder: (column) => column);

  GeneratedColumn<DateTime> get fattaIl =>
      $composableBuilder(column: $table.fattaIl, builder: (column) => column);

  $$SeduteAllenamentoTableAnnotationComposer get sedutaId {
    final $$SeduteAllenamentoTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.sedutaId,
          referencedTable: $db.seduteAllenamento,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$SeduteAllenamentoTableAnnotationComposer(
                $db: $db,
                $table: $db.seduteAllenamento,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$SerieDelleSeduteTableTableManager
    extends
        RootTableManager<
          _$ArchivioSalute,
          $SerieDelleSeduteTable,
          SerieSeduta,
          $$SerieDelleSeduteTableFilterComposer,
          $$SerieDelleSeduteTableOrderingComposer,
          $$SerieDelleSeduteTableAnnotationComposer,
          $$SerieDelleSeduteTableCreateCompanionBuilder,
          $$SerieDelleSeduteTableUpdateCompanionBuilder,
          (SerieSeduta, $$SerieDelleSeduteTableReferences),
          SerieSeduta,
          PrefetchHooks Function({bool sedutaId})
        > {
  $$SerieDelleSeduteTableTableManager(
    _$ArchivioSalute db,
    $SerieDelleSeduteTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SerieDelleSeduteTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SerieDelleSeduteTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SerieDelleSeduteTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> sedutaId = const Value.absent(),
                Value<int> esercizioId = const Value.absent(),
                Value<String> nomeEsercizio = const Value.absent(),
                Value<double?> met = const Value.absent(),
                Value<int> numero = const Value.absent(),
                Value<int?> ripetizioni = const Value.absent(),
                Value<double?> pesoKg = const Value.absent(),
                Value<int?> durataSec = const Value.absent(),
                Value<int?> riposoSec = const Value.absent(),
                Value<DateTime?> fattaIl = const Value.absent(),
              }) => SerieDelleSeduteCompanion(
                id: id,
                sedutaId: sedutaId,
                esercizioId: esercizioId,
                nomeEsercizio: nomeEsercizio,
                met: met,
                numero: numero,
                ripetizioni: ripetizioni,
                pesoKg: pesoKg,
                durataSec: durataSec,
                riposoSec: riposoSec,
                fattaIl: fattaIl,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int sedutaId,
                required int esercizioId,
                required String nomeEsercizio,
                Value<double?> met = const Value.absent(),
                required int numero,
                Value<int?> ripetizioni = const Value.absent(),
                Value<double?> pesoKg = const Value.absent(),
                Value<int?> durataSec = const Value.absent(),
                Value<int?> riposoSec = const Value.absent(),
                Value<DateTime?> fattaIl = const Value.absent(),
              }) => SerieDelleSeduteCompanion.insert(
                id: id,
                sedutaId: sedutaId,
                esercizioId: esercizioId,
                nomeEsercizio: nomeEsercizio,
                met: met,
                numero: numero,
                ripetizioni: ripetizioni,
                pesoKg: pesoKg,
                durataSec: durataSec,
                riposoSec: riposoSec,
                fattaIl: fattaIl,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SerieDelleSeduteTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sedutaId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sedutaId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.sedutaId,
                                referencedTable:
                                    $$SerieDelleSeduteTableReferences
                                        ._sedutaIdTable(db),
                                referencedColumn:
                                    $$SerieDelleSeduteTableReferences
                                        ._sedutaIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SerieDelleSeduteTableProcessedTableManager =
    ProcessedTableManager<
      _$ArchivioSalute,
      $SerieDelleSeduteTable,
      SerieSeduta,
      $$SerieDelleSeduteTableFilterComposer,
      $$SerieDelleSeduteTableOrderingComposer,
      $$SerieDelleSeduteTableAnnotationComposer,
      $$SerieDelleSeduteTableCreateCompanionBuilder,
      $$SerieDelleSeduteTableUpdateCompanionBuilder,
      (SerieSeduta, $$SerieDelleSeduteTableReferences),
      SerieSeduta,
      PrefetchHooks Function({bool sedutaId})
    >;
typedef $$SettimanaProgrammataTableCreateCompanionBuilder =
    SettimanaProgrammataCompanion Function({
      Value<int> giorno,
      Value<int?> schedaLocale,
    });
typedef $$SettimanaProgrammataTableUpdateCompanionBuilder =
    SettimanaProgrammataCompanion Function({
      Value<int> giorno,
      Value<int?> schedaLocale,
    });

class $$SettimanaProgrammataTableFilterComposer
    extends Composer<_$ArchivioSalute, $SettimanaProgrammataTable> {
  $$SettimanaProgrammataTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get giorno => $composableBuilder(
    column: $table.giorno,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get schedaLocale => $composableBuilder(
    column: $table.schedaLocale,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettimanaProgrammataTableOrderingComposer
    extends Composer<_$ArchivioSalute, $SettimanaProgrammataTable> {
  $$SettimanaProgrammataTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get giorno => $composableBuilder(
    column: $table.giorno,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get schedaLocale => $composableBuilder(
    column: $table.schedaLocale,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettimanaProgrammataTableAnnotationComposer
    extends Composer<_$ArchivioSalute, $SettimanaProgrammataTable> {
  $$SettimanaProgrammataTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get giorno =>
      $composableBuilder(column: $table.giorno, builder: (column) => column);

  GeneratedColumn<int> get schedaLocale => $composableBuilder(
    column: $table.schedaLocale,
    builder: (column) => column,
  );
}

class $$SettimanaProgrammataTableTableManager
    extends
        RootTableManager<
          _$ArchivioSalute,
          $SettimanaProgrammataTable,
          GiornoProgrammato,
          $$SettimanaProgrammataTableFilterComposer,
          $$SettimanaProgrammataTableOrderingComposer,
          $$SettimanaProgrammataTableAnnotationComposer,
          $$SettimanaProgrammataTableCreateCompanionBuilder,
          $$SettimanaProgrammataTableUpdateCompanionBuilder,
          (
            GiornoProgrammato,
            BaseReferences<
              _$ArchivioSalute,
              $SettimanaProgrammataTable,
              GiornoProgrammato
            >,
          ),
          GiornoProgrammato,
          PrefetchHooks Function()
        > {
  $$SettimanaProgrammataTableTableManager(
    _$ArchivioSalute db,
    $SettimanaProgrammataTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettimanaProgrammataTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettimanaProgrammataTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$SettimanaProgrammataTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> giorno = const Value.absent(),
                Value<int?> schedaLocale = const Value.absent(),
              }) => SettimanaProgrammataCompanion(
                giorno: giorno,
                schedaLocale: schedaLocale,
              ),
          createCompanionCallback:
              ({
                Value<int> giorno = const Value.absent(),
                Value<int?> schedaLocale = const Value.absent(),
              }) => SettimanaProgrammataCompanion.insert(
                giorno: giorno,
                schedaLocale: schedaLocale,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettimanaProgrammataTableProcessedTableManager =
    ProcessedTableManager<
      _$ArchivioSalute,
      $SettimanaProgrammataTable,
      GiornoProgrammato,
      $$SettimanaProgrammataTableFilterComposer,
      $$SettimanaProgrammataTableOrderingComposer,
      $$SettimanaProgrammataTableAnnotationComposer,
      $$SettimanaProgrammataTableCreateCompanionBuilder,
      $$SettimanaProgrammataTableUpdateCompanionBuilder,
      (
        GiornoProgrammato,
        BaseReferences<
          _$ArchivioSalute,
          $SettimanaProgrammataTable,
          GiornoProgrammato
        >,
      ),
      GiornoProgrammato,
      PrefetchHooks Function()
    >;
typedef $$AnalisiDelleSchedeTableCreateCompanionBuilder =
    AnalisiDelleSchedeCompanion Function({
      Value<int> schedaLocale,
      required String righe,
      required String impronta,
      Value<String?> riassunto,
      required DateTime fattaIl,
    });
typedef $$AnalisiDelleSchedeTableUpdateCompanionBuilder =
    AnalisiDelleSchedeCompanion Function({
      Value<int> schedaLocale,
      Value<String> righe,
      Value<String> impronta,
      Value<String?> riassunto,
      Value<DateTime> fattaIl,
    });

class $$AnalisiDelleSchedeTableFilterComposer
    extends Composer<_$ArchivioSalute, $AnalisiDelleSchedeTable> {
  $$AnalisiDelleSchedeTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get schedaLocale => $composableBuilder(
    column: $table.schedaLocale,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get righe => $composableBuilder(
    column: $table.righe,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get impronta => $composableBuilder(
    column: $table.impronta,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get riassunto => $composableBuilder(
    column: $table.riassunto,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fattaIl => $composableBuilder(
    column: $table.fattaIl,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AnalisiDelleSchedeTableOrderingComposer
    extends Composer<_$ArchivioSalute, $AnalisiDelleSchedeTable> {
  $$AnalisiDelleSchedeTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get schedaLocale => $composableBuilder(
    column: $table.schedaLocale,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get righe => $composableBuilder(
    column: $table.righe,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get impronta => $composableBuilder(
    column: $table.impronta,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get riassunto => $composableBuilder(
    column: $table.riassunto,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fattaIl => $composableBuilder(
    column: $table.fattaIl,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AnalisiDelleSchedeTableAnnotationComposer
    extends Composer<_$ArchivioSalute, $AnalisiDelleSchedeTable> {
  $$AnalisiDelleSchedeTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get schedaLocale => $composableBuilder(
    column: $table.schedaLocale,
    builder: (column) => column,
  );

  GeneratedColumn<String> get righe =>
      $composableBuilder(column: $table.righe, builder: (column) => column);

  GeneratedColumn<String> get impronta =>
      $composableBuilder(column: $table.impronta, builder: (column) => column);

  GeneratedColumn<String> get riassunto =>
      $composableBuilder(column: $table.riassunto, builder: (column) => column);

  GeneratedColumn<DateTime> get fattaIl =>
      $composableBuilder(column: $table.fattaIl, builder: (column) => column);
}

class $$AnalisiDelleSchedeTableTableManager
    extends
        RootTableManager<
          _$ArchivioSalute,
          $AnalisiDelleSchedeTable,
          AnalisiScheda,
          $$AnalisiDelleSchedeTableFilterComposer,
          $$AnalisiDelleSchedeTableOrderingComposer,
          $$AnalisiDelleSchedeTableAnnotationComposer,
          $$AnalisiDelleSchedeTableCreateCompanionBuilder,
          $$AnalisiDelleSchedeTableUpdateCompanionBuilder,
          (
            AnalisiScheda,
            BaseReferences<
              _$ArchivioSalute,
              $AnalisiDelleSchedeTable,
              AnalisiScheda
            >,
          ),
          AnalisiScheda,
          PrefetchHooks Function()
        > {
  $$AnalisiDelleSchedeTableTableManager(
    _$ArchivioSalute db,
    $AnalisiDelleSchedeTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AnalisiDelleSchedeTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AnalisiDelleSchedeTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AnalisiDelleSchedeTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> schedaLocale = const Value.absent(),
                Value<String> righe = const Value.absent(),
                Value<String> impronta = const Value.absent(),
                Value<String?> riassunto = const Value.absent(),
                Value<DateTime> fattaIl = const Value.absent(),
              }) => AnalisiDelleSchedeCompanion(
                schedaLocale: schedaLocale,
                righe: righe,
                impronta: impronta,
                riassunto: riassunto,
                fattaIl: fattaIl,
              ),
          createCompanionCallback:
              ({
                Value<int> schedaLocale = const Value.absent(),
                required String righe,
                required String impronta,
                Value<String?> riassunto = const Value.absent(),
                required DateTime fattaIl,
              }) => AnalisiDelleSchedeCompanion.insert(
                schedaLocale: schedaLocale,
                righe: righe,
                impronta: impronta,
                riassunto: riassunto,
                fattaIl: fattaIl,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AnalisiDelleSchedeTableProcessedTableManager =
    ProcessedTableManager<
      _$ArchivioSalute,
      $AnalisiDelleSchedeTable,
      AnalisiScheda,
      $$AnalisiDelleSchedeTableFilterComposer,
      $$AnalisiDelleSchedeTableOrderingComposer,
      $$AnalisiDelleSchedeTableAnnotationComposer,
      $$AnalisiDelleSchedeTableCreateCompanionBuilder,
      $$AnalisiDelleSchedeTableUpdateCompanionBuilder,
      (
        AnalisiScheda,
        BaseReferences<
          _$ArchivioSalute,
          $AnalisiDelleSchedeTable,
          AnalisiScheda
        >,
      ),
      AnalisiScheda,
      PrefetchHooks Function()
    >;
typedef $$VersioniDelleSchedeTableCreateCompanionBuilder =
    VersioniDelleSchedeCompanion Function({
      Value<int> id,
      required int schedaLocale,
      required DateTime quando,
      required String impronta,
      required String contenuto,
    });
typedef $$VersioniDelleSchedeTableUpdateCompanionBuilder =
    VersioniDelleSchedeCompanion Function({
      Value<int> id,
      Value<int> schedaLocale,
      Value<DateTime> quando,
      Value<String> impronta,
      Value<String> contenuto,
    });

class $$VersioniDelleSchedeTableFilterComposer
    extends Composer<_$ArchivioSalute, $VersioniDelleSchedeTable> {
  $$VersioniDelleSchedeTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get schedaLocale => $composableBuilder(
    column: $table.schedaLocale,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get quando => $composableBuilder(
    column: $table.quando,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get impronta => $composableBuilder(
    column: $table.impronta,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contenuto => $composableBuilder(
    column: $table.contenuto,
    builder: (column) => ColumnFilters(column),
  );
}

class $$VersioniDelleSchedeTableOrderingComposer
    extends Composer<_$ArchivioSalute, $VersioniDelleSchedeTable> {
  $$VersioniDelleSchedeTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get schedaLocale => $composableBuilder(
    column: $table.schedaLocale,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get quando => $composableBuilder(
    column: $table.quando,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get impronta => $composableBuilder(
    column: $table.impronta,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contenuto => $composableBuilder(
    column: $table.contenuto,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VersioniDelleSchedeTableAnnotationComposer
    extends Composer<_$ArchivioSalute, $VersioniDelleSchedeTable> {
  $$VersioniDelleSchedeTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get schedaLocale => $composableBuilder(
    column: $table.schedaLocale,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get quando =>
      $composableBuilder(column: $table.quando, builder: (column) => column);

  GeneratedColumn<String> get impronta =>
      $composableBuilder(column: $table.impronta, builder: (column) => column);

  GeneratedColumn<String> get contenuto =>
      $composableBuilder(column: $table.contenuto, builder: (column) => column);
}

class $$VersioniDelleSchedeTableTableManager
    extends
        RootTableManager<
          _$ArchivioSalute,
          $VersioniDelleSchedeTable,
          VersioneSchedaSalvata,
          $$VersioniDelleSchedeTableFilterComposer,
          $$VersioniDelleSchedeTableOrderingComposer,
          $$VersioniDelleSchedeTableAnnotationComposer,
          $$VersioniDelleSchedeTableCreateCompanionBuilder,
          $$VersioniDelleSchedeTableUpdateCompanionBuilder,
          (
            VersioneSchedaSalvata,
            BaseReferences<
              _$ArchivioSalute,
              $VersioniDelleSchedeTable,
              VersioneSchedaSalvata
            >,
          ),
          VersioneSchedaSalvata,
          PrefetchHooks Function()
        > {
  $$VersioniDelleSchedeTableTableManager(
    _$ArchivioSalute db,
    $VersioniDelleSchedeTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VersioniDelleSchedeTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VersioniDelleSchedeTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$VersioniDelleSchedeTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> schedaLocale = const Value.absent(),
                Value<DateTime> quando = const Value.absent(),
                Value<String> impronta = const Value.absent(),
                Value<String> contenuto = const Value.absent(),
              }) => VersioniDelleSchedeCompanion(
                id: id,
                schedaLocale: schedaLocale,
                quando: quando,
                impronta: impronta,
                contenuto: contenuto,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int schedaLocale,
                required DateTime quando,
                required String impronta,
                required String contenuto,
              }) => VersioniDelleSchedeCompanion.insert(
                id: id,
                schedaLocale: schedaLocale,
                quando: quando,
                impronta: impronta,
                contenuto: contenuto,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$VersioniDelleSchedeTableProcessedTableManager =
    ProcessedTableManager<
      _$ArchivioSalute,
      $VersioniDelleSchedeTable,
      VersioneSchedaSalvata,
      $$VersioniDelleSchedeTableFilterComposer,
      $$VersioniDelleSchedeTableOrderingComposer,
      $$VersioniDelleSchedeTableAnnotationComposer,
      $$VersioniDelleSchedeTableCreateCompanionBuilder,
      $$VersioniDelleSchedeTableUpdateCompanionBuilder,
      (
        VersioneSchedaSalvata,
        BaseReferences<
          _$ArchivioSalute,
          $VersioniDelleSchedeTable,
          VersioneSchedaSalvata
        >,
      ),
      VersioneSchedaSalvata,
      PrefetchHooks Function()
    >;
typedef $$BruciateDichiarateTableCreateCompanionBuilder =
    BruciateDichiarateCompanion Function({
      Value<int> id,
      required DateTime giorno,
      required int kcal,
      Value<bool> daServer,
    });
typedef $$BruciateDichiarateTableUpdateCompanionBuilder =
    BruciateDichiarateCompanion Function({
      Value<int> id,
      Value<DateTime> giorno,
      Value<int> kcal,
      Value<bool> daServer,
    });

class $$BruciateDichiarateTableFilterComposer
    extends Composer<_$ArchivioSalute, $BruciateDichiarateTable> {
  $$BruciateDichiarateTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get giorno => $composableBuilder(
    column: $table.giorno,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get kcal => $composableBuilder(
    column: $table.kcal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get daServer => $composableBuilder(
    column: $table.daServer,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BruciateDichiarateTableOrderingComposer
    extends Composer<_$ArchivioSalute, $BruciateDichiarateTable> {
  $$BruciateDichiarateTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get giorno => $composableBuilder(
    column: $table.giorno,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get kcal => $composableBuilder(
    column: $table.kcal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get daServer => $composableBuilder(
    column: $table.daServer,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BruciateDichiarateTableAnnotationComposer
    extends Composer<_$ArchivioSalute, $BruciateDichiarateTable> {
  $$BruciateDichiarateTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get giorno =>
      $composableBuilder(column: $table.giorno, builder: (column) => column);

  GeneratedColumn<int> get kcal =>
      $composableBuilder(column: $table.kcal, builder: (column) => column);

  GeneratedColumn<bool> get daServer =>
      $composableBuilder(column: $table.daServer, builder: (column) => column);
}

class $$BruciateDichiarateTableTableManager
    extends
        RootTableManager<
          _$ArchivioSalute,
          $BruciateDichiarateTable,
          BruciatoDichiarato,
          $$BruciateDichiarateTableFilterComposer,
          $$BruciateDichiarateTableOrderingComposer,
          $$BruciateDichiarateTableAnnotationComposer,
          $$BruciateDichiarateTableCreateCompanionBuilder,
          $$BruciateDichiarateTableUpdateCompanionBuilder,
          (
            BruciatoDichiarato,
            BaseReferences<
              _$ArchivioSalute,
              $BruciateDichiarateTable,
              BruciatoDichiarato
            >,
          ),
          BruciatoDichiarato,
          PrefetchHooks Function()
        > {
  $$BruciateDichiarateTableTableManager(
    _$ArchivioSalute db,
    $BruciateDichiarateTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BruciateDichiarateTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BruciateDichiarateTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BruciateDichiarateTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> giorno = const Value.absent(),
                Value<int> kcal = const Value.absent(),
                Value<bool> daServer = const Value.absent(),
              }) => BruciateDichiarateCompanion(
                id: id,
                giorno: giorno,
                kcal: kcal,
                daServer: daServer,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime giorno,
                required int kcal,
                Value<bool> daServer = const Value.absent(),
              }) => BruciateDichiarateCompanion.insert(
                id: id,
                giorno: giorno,
                kcal: kcal,
                daServer: daServer,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BruciateDichiarateTableProcessedTableManager =
    ProcessedTableManager<
      _$ArchivioSalute,
      $BruciateDichiarateTable,
      BruciatoDichiarato,
      $$BruciateDichiarateTableFilterComposer,
      $$BruciateDichiarateTableOrderingComposer,
      $$BruciateDichiarateTableAnnotationComposer,
      $$BruciateDichiarateTableCreateCompanionBuilder,
      $$BruciateDichiarateTableUpdateCompanionBuilder,
      (
        BruciatoDichiarato,
        BaseReferences<
          _$ArchivioSalute,
          $BruciateDichiarateTable,
          BruciatoDichiarato
        >,
      ),
      BruciatoDichiarato,
      PrefetchHooks Function()
    >;
typedef $$SchedeSulTelefonoTableCreateCompanionBuilder =
    SchedeSulTelefonoCompanion Function({
      Value<int> id,
      required String nome,
      required String scheda,
      required DateTime aggiornataIl,
      Value<DateTime?> creataIl,
      Value<bool> mia,
      required String origine,
      Value<int?> idOrigine,
      Value<String?> origineIdStabile,
    });
typedef $$SchedeSulTelefonoTableUpdateCompanionBuilder =
    SchedeSulTelefonoCompanion Function({
      Value<int> id,
      Value<String> nome,
      Value<String> scheda,
      Value<DateTime> aggiornataIl,
      Value<DateTime?> creataIl,
      Value<bool> mia,
      Value<String> origine,
      Value<int?> idOrigine,
      Value<String?> origineIdStabile,
    });

class $$SchedeSulTelefonoTableFilterComposer
    extends Composer<_$ArchivioSalute, $SchedeSulTelefonoTable> {
  $$SchedeSulTelefonoTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nome => $composableBuilder(
    column: $table.nome,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scheda => $composableBuilder(
    column: $table.scheda,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get aggiornataIl => $composableBuilder(
    column: $table.aggiornataIl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get creataIl => $composableBuilder(
    column: $table.creataIl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get mia => $composableBuilder(
    column: $table.mia,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get origine => $composableBuilder(
    column: $table.origine,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get idOrigine => $composableBuilder(
    column: $table.idOrigine,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get origineIdStabile => $composableBuilder(
    column: $table.origineIdStabile,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SchedeSulTelefonoTableOrderingComposer
    extends Composer<_$ArchivioSalute, $SchedeSulTelefonoTable> {
  $$SchedeSulTelefonoTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nome => $composableBuilder(
    column: $table.nome,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scheda => $composableBuilder(
    column: $table.scheda,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get aggiornataIl => $composableBuilder(
    column: $table.aggiornataIl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get creataIl => $composableBuilder(
    column: $table.creataIl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get mia => $composableBuilder(
    column: $table.mia,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get origine => $composableBuilder(
    column: $table.origine,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get idOrigine => $composableBuilder(
    column: $table.idOrigine,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get origineIdStabile => $composableBuilder(
    column: $table.origineIdStabile,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SchedeSulTelefonoTableAnnotationComposer
    extends Composer<_$ArchivioSalute, $SchedeSulTelefonoTable> {
  $$SchedeSulTelefonoTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get nome =>
      $composableBuilder(column: $table.nome, builder: (column) => column);

  GeneratedColumn<String> get scheda =>
      $composableBuilder(column: $table.scheda, builder: (column) => column);

  GeneratedColumn<DateTime> get aggiornataIl => $composableBuilder(
    column: $table.aggiornataIl,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get creataIl =>
      $composableBuilder(column: $table.creataIl, builder: (column) => column);

  GeneratedColumn<bool> get mia =>
      $composableBuilder(column: $table.mia, builder: (column) => column);

  GeneratedColumn<String> get origine =>
      $composableBuilder(column: $table.origine, builder: (column) => column);

  GeneratedColumn<int> get idOrigine =>
      $composableBuilder(column: $table.idOrigine, builder: (column) => column);

  GeneratedColumn<String> get origineIdStabile => $composableBuilder(
    column: $table.origineIdStabile,
    builder: (column) => column,
  );
}

class $$SchedeSulTelefonoTableTableManager
    extends
        RootTableManager<
          _$ArchivioSalute,
          $SchedeSulTelefonoTable,
          SchedaSulTelefono,
          $$SchedeSulTelefonoTableFilterComposer,
          $$SchedeSulTelefonoTableOrderingComposer,
          $$SchedeSulTelefonoTableAnnotationComposer,
          $$SchedeSulTelefonoTableCreateCompanionBuilder,
          $$SchedeSulTelefonoTableUpdateCompanionBuilder,
          (
            SchedaSulTelefono,
            BaseReferences<
              _$ArchivioSalute,
              $SchedeSulTelefonoTable,
              SchedaSulTelefono
            >,
          ),
          SchedaSulTelefono,
          PrefetchHooks Function()
        > {
  $$SchedeSulTelefonoTableTableManager(
    _$ArchivioSalute db,
    $SchedeSulTelefonoTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SchedeSulTelefonoTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SchedeSulTelefonoTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SchedeSulTelefonoTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> nome = const Value.absent(),
                Value<String> scheda = const Value.absent(),
                Value<DateTime> aggiornataIl = const Value.absent(),
                Value<DateTime?> creataIl = const Value.absent(),
                Value<bool> mia = const Value.absent(),
                Value<String> origine = const Value.absent(),
                Value<int?> idOrigine = const Value.absent(),
                Value<String?> origineIdStabile = const Value.absent(),
              }) => SchedeSulTelefonoCompanion(
                id: id,
                nome: nome,
                scheda: scheda,
                aggiornataIl: aggiornataIl,
                creataIl: creataIl,
                mia: mia,
                origine: origine,
                idOrigine: idOrigine,
                origineIdStabile: origineIdStabile,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String nome,
                required String scheda,
                required DateTime aggiornataIl,
                Value<DateTime?> creataIl = const Value.absent(),
                Value<bool> mia = const Value.absent(),
                required String origine,
                Value<int?> idOrigine = const Value.absent(),
                Value<String?> origineIdStabile = const Value.absent(),
              }) => SchedeSulTelefonoCompanion.insert(
                id: id,
                nome: nome,
                scheda: scheda,
                aggiornataIl: aggiornataIl,
                creataIl: creataIl,
                mia: mia,
                origine: origine,
                idOrigine: idOrigine,
                origineIdStabile: origineIdStabile,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SchedeSulTelefonoTableProcessedTableManager =
    ProcessedTableManager<
      _$ArchivioSalute,
      $SchedeSulTelefonoTable,
      SchedaSulTelefono,
      $$SchedeSulTelefonoTableFilterComposer,
      $$SchedeSulTelefonoTableOrderingComposer,
      $$SchedeSulTelefonoTableAnnotationComposer,
      $$SchedeSulTelefonoTableCreateCompanionBuilder,
      $$SchedeSulTelefonoTableUpdateCompanionBuilder,
      (
        SchedaSulTelefono,
        BaseReferences<
          _$ArchivioSalute,
          $SchedeSulTelefonoTable,
          SchedaSulTelefono
        >,
      ),
      SchedaSulTelefono,
      PrefetchHooks Function()
    >;
typedef $$VociDiarioTableCreateCompanionBuilder =
    VociDiarioCompanion Function({
      Value<int> id,
      Value<int?> idSulServer,
      required DateTime mangiatoIl,
      required String pasto,
      required String descrizione,
      Value<double?> grammi,
      Value<double?> quantita,
      Value<String?> unita,
      Value<double?> kcal,
      Value<double?> proteine,
      Value<double?> carboidrati,
      Value<double?> grassi,
      Value<double?> kcal100,
      Value<double?> proteine100,
      Value<double?> carboidrati100,
      Value<double?> grassi100,
      Value<String> fonte,
      Value<String?> aiGrezzo,
      Value<int?> pianoId,
      Value<int?> alimentoId,
      Value<DateTime> scrittaIl,
    });
typedef $$VociDiarioTableUpdateCompanionBuilder =
    VociDiarioCompanion Function({
      Value<int> id,
      Value<int?> idSulServer,
      Value<DateTime> mangiatoIl,
      Value<String> pasto,
      Value<String> descrizione,
      Value<double?> grammi,
      Value<double?> quantita,
      Value<String?> unita,
      Value<double?> kcal,
      Value<double?> proteine,
      Value<double?> carboidrati,
      Value<double?> grassi,
      Value<double?> kcal100,
      Value<double?> proteine100,
      Value<double?> carboidrati100,
      Value<double?> grassi100,
      Value<String> fonte,
      Value<String?> aiGrezzo,
      Value<int?> pianoId,
      Value<int?> alimentoId,
      Value<DateTime> scrittaIl,
    });

class $$VociDiarioTableFilterComposer
    extends Composer<_$ArchivioSalute, $VociDiarioTable> {
  $$VociDiarioTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get idSulServer => $composableBuilder(
    column: $table.idSulServer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get mangiatoIl => $composableBuilder(
    column: $table.mangiatoIl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pasto => $composableBuilder(
    column: $table.pasto,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get descrizione => $composableBuilder(
    column: $table.descrizione,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get grammi => $composableBuilder(
    column: $table.grammi,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get quantita => $composableBuilder(
    column: $table.quantita,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unita => $composableBuilder(
    column: $table.unita,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get kcal => $composableBuilder(
    column: $table.kcal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get proteine => $composableBuilder(
    column: $table.proteine,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get carboidrati => $composableBuilder(
    column: $table.carboidrati,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get grassi => $composableBuilder(
    column: $table.grassi,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get kcal100 => $composableBuilder(
    column: $table.kcal100,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get proteine100 => $composableBuilder(
    column: $table.proteine100,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get carboidrati100 => $composableBuilder(
    column: $table.carboidrati100,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get grassi100 => $composableBuilder(
    column: $table.grassi100,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fonte => $composableBuilder(
    column: $table.fonte,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get aiGrezzo => $composableBuilder(
    column: $table.aiGrezzo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pianoId => $composableBuilder(
    column: $table.pianoId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get alimentoId => $composableBuilder(
    column: $table.alimentoId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get scrittaIl => $composableBuilder(
    column: $table.scrittaIl,
    builder: (column) => ColumnFilters(column),
  );
}

class $$VociDiarioTableOrderingComposer
    extends Composer<_$ArchivioSalute, $VociDiarioTable> {
  $$VociDiarioTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get idSulServer => $composableBuilder(
    column: $table.idSulServer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get mangiatoIl => $composableBuilder(
    column: $table.mangiatoIl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pasto => $composableBuilder(
    column: $table.pasto,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get descrizione => $composableBuilder(
    column: $table.descrizione,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get grammi => $composableBuilder(
    column: $table.grammi,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get quantita => $composableBuilder(
    column: $table.quantita,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unita => $composableBuilder(
    column: $table.unita,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get kcal => $composableBuilder(
    column: $table.kcal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get proteine => $composableBuilder(
    column: $table.proteine,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get carboidrati => $composableBuilder(
    column: $table.carboidrati,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get grassi => $composableBuilder(
    column: $table.grassi,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get kcal100 => $composableBuilder(
    column: $table.kcal100,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get proteine100 => $composableBuilder(
    column: $table.proteine100,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get carboidrati100 => $composableBuilder(
    column: $table.carboidrati100,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get grassi100 => $composableBuilder(
    column: $table.grassi100,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fonte => $composableBuilder(
    column: $table.fonte,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get aiGrezzo => $composableBuilder(
    column: $table.aiGrezzo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pianoId => $composableBuilder(
    column: $table.pianoId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get alimentoId => $composableBuilder(
    column: $table.alimentoId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get scrittaIl => $composableBuilder(
    column: $table.scrittaIl,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VociDiarioTableAnnotationComposer
    extends Composer<_$ArchivioSalute, $VociDiarioTable> {
  $$VociDiarioTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get idSulServer => $composableBuilder(
    column: $table.idSulServer,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get mangiatoIl => $composableBuilder(
    column: $table.mangiatoIl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pasto =>
      $composableBuilder(column: $table.pasto, builder: (column) => column);

  GeneratedColumn<String> get descrizione => $composableBuilder(
    column: $table.descrizione,
    builder: (column) => column,
  );

  GeneratedColumn<double> get grammi =>
      $composableBuilder(column: $table.grammi, builder: (column) => column);

  GeneratedColumn<double> get quantita =>
      $composableBuilder(column: $table.quantita, builder: (column) => column);

  GeneratedColumn<String> get unita =>
      $composableBuilder(column: $table.unita, builder: (column) => column);

  GeneratedColumn<double> get kcal =>
      $composableBuilder(column: $table.kcal, builder: (column) => column);

  GeneratedColumn<double> get proteine =>
      $composableBuilder(column: $table.proteine, builder: (column) => column);

  GeneratedColumn<double> get carboidrati => $composableBuilder(
    column: $table.carboidrati,
    builder: (column) => column,
  );

  GeneratedColumn<double> get grassi =>
      $composableBuilder(column: $table.grassi, builder: (column) => column);

  GeneratedColumn<double> get kcal100 =>
      $composableBuilder(column: $table.kcal100, builder: (column) => column);

  GeneratedColumn<double> get proteine100 => $composableBuilder(
    column: $table.proteine100,
    builder: (column) => column,
  );

  GeneratedColumn<double> get carboidrati100 => $composableBuilder(
    column: $table.carboidrati100,
    builder: (column) => column,
  );

  GeneratedColumn<double> get grassi100 =>
      $composableBuilder(column: $table.grassi100, builder: (column) => column);

  GeneratedColumn<String> get fonte =>
      $composableBuilder(column: $table.fonte, builder: (column) => column);

  GeneratedColumn<String> get aiGrezzo =>
      $composableBuilder(column: $table.aiGrezzo, builder: (column) => column);

  GeneratedColumn<int> get pianoId =>
      $composableBuilder(column: $table.pianoId, builder: (column) => column);

  GeneratedColumn<int> get alimentoId => $composableBuilder(
    column: $table.alimentoId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get scrittaIl =>
      $composableBuilder(column: $table.scrittaIl, builder: (column) => column);
}

class $$VociDiarioTableTableManager
    extends
        RootTableManager<
          _$ArchivioSalute,
          $VociDiarioTable,
          VoceDiario,
          $$VociDiarioTableFilterComposer,
          $$VociDiarioTableOrderingComposer,
          $$VociDiarioTableAnnotationComposer,
          $$VociDiarioTableCreateCompanionBuilder,
          $$VociDiarioTableUpdateCompanionBuilder,
          (
            VoceDiario,
            BaseReferences<_$ArchivioSalute, $VociDiarioTable, VoceDiario>,
          ),
          VoceDiario,
          PrefetchHooks Function()
        > {
  $$VociDiarioTableTableManager(_$ArchivioSalute db, $VociDiarioTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VociDiarioTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VociDiarioTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VociDiarioTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> idSulServer = const Value.absent(),
                Value<DateTime> mangiatoIl = const Value.absent(),
                Value<String> pasto = const Value.absent(),
                Value<String> descrizione = const Value.absent(),
                Value<double?> grammi = const Value.absent(),
                Value<double?> quantita = const Value.absent(),
                Value<String?> unita = const Value.absent(),
                Value<double?> kcal = const Value.absent(),
                Value<double?> proteine = const Value.absent(),
                Value<double?> carboidrati = const Value.absent(),
                Value<double?> grassi = const Value.absent(),
                Value<double?> kcal100 = const Value.absent(),
                Value<double?> proteine100 = const Value.absent(),
                Value<double?> carboidrati100 = const Value.absent(),
                Value<double?> grassi100 = const Value.absent(),
                Value<String> fonte = const Value.absent(),
                Value<String?> aiGrezzo = const Value.absent(),
                Value<int?> pianoId = const Value.absent(),
                Value<int?> alimentoId = const Value.absent(),
                Value<DateTime> scrittaIl = const Value.absent(),
              }) => VociDiarioCompanion(
                id: id,
                idSulServer: idSulServer,
                mangiatoIl: mangiatoIl,
                pasto: pasto,
                descrizione: descrizione,
                grammi: grammi,
                quantita: quantita,
                unita: unita,
                kcal: kcal,
                proteine: proteine,
                carboidrati: carboidrati,
                grassi: grassi,
                kcal100: kcal100,
                proteine100: proteine100,
                carboidrati100: carboidrati100,
                grassi100: grassi100,
                fonte: fonte,
                aiGrezzo: aiGrezzo,
                pianoId: pianoId,
                alimentoId: alimentoId,
                scrittaIl: scrittaIl,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> idSulServer = const Value.absent(),
                required DateTime mangiatoIl,
                required String pasto,
                required String descrizione,
                Value<double?> grammi = const Value.absent(),
                Value<double?> quantita = const Value.absent(),
                Value<String?> unita = const Value.absent(),
                Value<double?> kcal = const Value.absent(),
                Value<double?> proteine = const Value.absent(),
                Value<double?> carboidrati = const Value.absent(),
                Value<double?> grassi = const Value.absent(),
                Value<double?> kcal100 = const Value.absent(),
                Value<double?> proteine100 = const Value.absent(),
                Value<double?> carboidrati100 = const Value.absent(),
                Value<double?> grassi100 = const Value.absent(),
                Value<String> fonte = const Value.absent(),
                Value<String?> aiGrezzo = const Value.absent(),
                Value<int?> pianoId = const Value.absent(),
                Value<int?> alimentoId = const Value.absent(),
                Value<DateTime> scrittaIl = const Value.absent(),
              }) => VociDiarioCompanion.insert(
                id: id,
                idSulServer: idSulServer,
                mangiatoIl: mangiatoIl,
                pasto: pasto,
                descrizione: descrizione,
                grammi: grammi,
                quantita: quantita,
                unita: unita,
                kcal: kcal,
                proteine: proteine,
                carboidrati: carboidrati,
                grassi: grassi,
                kcal100: kcal100,
                proteine100: proteine100,
                carboidrati100: carboidrati100,
                grassi100: grassi100,
                fonte: fonte,
                aiGrezzo: aiGrezzo,
                pianoId: pianoId,
                alimentoId: alimentoId,
                scrittaIl: scrittaIl,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$VociDiarioTableProcessedTableManager =
    ProcessedTableManager<
      _$ArchivioSalute,
      $VociDiarioTable,
      VoceDiario,
      $$VociDiarioTableFilterComposer,
      $$VociDiarioTableOrderingComposer,
      $$VociDiarioTableAnnotationComposer,
      $$VociDiarioTableCreateCompanionBuilder,
      $$VociDiarioTableUpdateCompanionBuilder,
      (
        VoceDiario,
        BaseReferences<_$ArchivioSalute, $VociDiarioTable, VoceDiario>,
      ),
      VoceDiario,
      PrefetchHooks Function()
    >;
typedef $$PreferitiCiboTableCreateCompanionBuilder =
    PreferitiCiboCompanion Function({
      Value<int> id,
      Value<int?> idSulServer,
      required String descrizione,
      Value<bool> ePasto,
      Value<String?> voci,
      Value<double?> grammi,
      Value<double?> quantita,
      Value<String?> unita,
      Value<double?> kcal,
      Value<double?> proteine,
      Value<double?> carboidrati,
      Value<double?> grassi,
      Value<double?> kcal100,
      Value<double?> proteine100,
      Value<double?> carboidrati100,
      Value<double?> grassi100,
      Value<DateTime> salvatoIl,
      Value<int> volteUsato,
      Value<DateTime?> usatoIl,
    });
typedef $$PreferitiCiboTableUpdateCompanionBuilder =
    PreferitiCiboCompanion Function({
      Value<int> id,
      Value<int?> idSulServer,
      Value<String> descrizione,
      Value<bool> ePasto,
      Value<String?> voci,
      Value<double?> grammi,
      Value<double?> quantita,
      Value<String?> unita,
      Value<double?> kcal,
      Value<double?> proteine,
      Value<double?> carboidrati,
      Value<double?> grassi,
      Value<double?> kcal100,
      Value<double?> proteine100,
      Value<double?> carboidrati100,
      Value<double?> grassi100,
      Value<DateTime> salvatoIl,
      Value<int> volteUsato,
      Value<DateTime?> usatoIl,
    });

class $$PreferitiCiboTableFilterComposer
    extends Composer<_$ArchivioSalute, $PreferitiCiboTable> {
  $$PreferitiCiboTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get idSulServer => $composableBuilder(
    column: $table.idSulServer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get descrizione => $composableBuilder(
    column: $table.descrizione,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get ePasto => $composableBuilder(
    column: $table.ePasto,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get voci => $composableBuilder(
    column: $table.voci,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get grammi => $composableBuilder(
    column: $table.grammi,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get quantita => $composableBuilder(
    column: $table.quantita,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unita => $composableBuilder(
    column: $table.unita,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get kcal => $composableBuilder(
    column: $table.kcal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get proteine => $composableBuilder(
    column: $table.proteine,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get carboidrati => $composableBuilder(
    column: $table.carboidrati,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get grassi => $composableBuilder(
    column: $table.grassi,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get kcal100 => $composableBuilder(
    column: $table.kcal100,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get proteine100 => $composableBuilder(
    column: $table.proteine100,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get carboidrati100 => $composableBuilder(
    column: $table.carboidrati100,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get grassi100 => $composableBuilder(
    column: $table.grassi100,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get salvatoIl => $composableBuilder(
    column: $table.salvatoIl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get volteUsato => $composableBuilder(
    column: $table.volteUsato,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get usatoIl => $composableBuilder(
    column: $table.usatoIl,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PreferitiCiboTableOrderingComposer
    extends Composer<_$ArchivioSalute, $PreferitiCiboTable> {
  $$PreferitiCiboTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get idSulServer => $composableBuilder(
    column: $table.idSulServer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get descrizione => $composableBuilder(
    column: $table.descrizione,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get ePasto => $composableBuilder(
    column: $table.ePasto,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get voci => $composableBuilder(
    column: $table.voci,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get grammi => $composableBuilder(
    column: $table.grammi,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get quantita => $composableBuilder(
    column: $table.quantita,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unita => $composableBuilder(
    column: $table.unita,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get kcal => $composableBuilder(
    column: $table.kcal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get proteine => $composableBuilder(
    column: $table.proteine,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get carboidrati => $composableBuilder(
    column: $table.carboidrati,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get grassi => $composableBuilder(
    column: $table.grassi,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get kcal100 => $composableBuilder(
    column: $table.kcal100,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get proteine100 => $composableBuilder(
    column: $table.proteine100,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get carboidrati100 => $composableBuilder(
    column: $table.carboidrati100,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get grassi100 => $composableBuilder(
    column: $table.grassi100,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get salvatoIl => $composableBuilder(
    column: $table.salvatoIl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get volteUsato => $composableBuilder(
    column: $table.volteUsato,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get usatoIl => $composableBuilder(
    column: $table.usatoIl,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PreferitiCiboTableAnnotationComposer
    extends Composer<_$ArchivioSalute, $PreferitiCiboTable> {
  $$PreferitiCiboTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get idSulServer => $composableBuilder(
    column: $table.idSulServer,
    builder: (column) => column,
  );

  GeneratedColumn<String> get descrizione => $composableBuilder(
    column: $table.descrizione,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get ePasto =>
      $composableBuilder(column: $table.ePasto, builder: (column) => column);

  GeneratedColumn<String> get voci =>
      $composableBuilder(column: $table.voci, builder: (column) => column);

  GeneratedColumn<double> get grammi =>
      $composableBuilder(column: $table.grammi, builder: (column) => column);

  GeneratedColumn<double> get quantita =>
      $composableBuilder(column: $table.quantita, builder: (column) => column);

  GeneratedColumn<String> get unita =>
      $composableBuilder(column: $table.unita, builder: (column) => column);

  GeneratedColumn<double> get kcal =>
      $composableBuilder(column: $table.kcal, builder: (column) => column);

  GeneratedColumn<double> get proteine =>
      $composableBuilder(column: $table.proteine, builder: (column) => column);

  GeneratedColumn<double> get carboidrati => $composableBuilder(
    column: $table.carboidrati,
    builder: (column) => column,
  );

  GeneratedColumn<double> get grassi =>
      $composableBuilder(column: $table.grassi, builder: (column) => column);

  GeneratedColumn<double> get kcal100 =>
      $composableBuilder(column: $table.kcal100, builder: (column) => column);

  GeneratedColumn<double> get proteine100 => $composableBuilder(
    column: $table.proteine100,
    builder: (column) => column,
  );

  GeneratedColumn<double> get carboidrati100 => $composableBuilder(
    column: $table.carboidrati100,
    builder: (column) => column,
  );

  GeneratedColumn<double> get grassi100 =>
      $composableBuilder(column: $table.grassi100, builder: (column) => column);

  GeneratedColumn<DateTime> get salvatoIl =>
      $composableBuilder(column: $table.salvatoIl, builder: (column) => column);

  GeneratedColumn<int> get volteUsato => $composableBuilder(
    column: $table.volteUsato,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get usatoIl =>
      $composableBuilder(column: $table.usatoIl, builder: (column) => column);
}

class $$PreferitiCiboTableTableManager
    extends
        RootTableManager<
          _$ArchivioSalute,
          $PreferitiCiboTable,
          PreferitoCibo,
          $$PreferitiCiboTableFilterComposer,
          $$PreferitiCiboTableOrderingComposer,
          $$PreferitiCiboTableAnnotationComposer,
          $$PreferitiCiboTableCreateCompanionBuilder,
          $$PreferitiCiboTableUpdateCompanionBuilder,
          (
            PreferitoCibo,
            BaseReferences<
              _$ArchivioSalute,
              $PreferitiCiboTable,
              PreferitoCibo
            >,
          ),
          PreferitoCibo,
          PrefetchHooks Function()
        > {
  $$PreferitiCiboTableTableManager(
    _$ArchivioSalute db,
    $PreferitiCiboTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PreferitiCiboTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PreferitiCiboTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PreferitiCiboTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> idSulServer = const Value.absent(),
                Value<String> descrizione = const Value.absent(),
                Value<bool> ePasto = const Value.absent(),
                Value<String?> voci = const Value.absent(),
                Value<double?> grammi = const Value.absent(),
                Value<double?> quantita = const Value.absent(),
                Value<String?> unita = const Value.absent(),
                Value<double?> kcal = const Value.absent(),
                Value<double?> proteine = const Value.absent(),
                Value<double?> carboidrati = const Value.absent(),
                Value<double?> grassi = const Value.absent(),
                Value<double?> kcal100 = const Value.absent(),
                Value<double?> proteine100 = const Value.absent(),
                Value<double?> carboidrati100 = const Value.absent(),
                Value<double?> grassi100 = const Value.absent(),
                Value<DateTime> salvatoIl = const Value.absent(),
                Value<int> volteUsato = const Value.absent(),
                Value<DateTime?> usatoIl = const Value.absent(),
              }) => PreferitiCiboCompanion(
                id: id,
                idSulServer: idSulServer,
                descrizione: descrizione,
                ePasto: ePasto,
                voci: voci,
                grammi: grammi,
                quantita: quantita,
                unita: unita,
                kcal: kcal,
                proteine: proteine,
                carboidrati: carboidrati,
                grassi: grassi,
                kcal100: kcal100,
                proteine100: proteine100,
                carboidrati100: carboidrati100,
                grassi100: grassi100,
                salvatoIl: salvatoIl,
                volteUsato: volteUsato,
                usatoIl: usatoIl,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> idSulServer = const Value.absent(),
                required String descrizione,
                Value<bool> ePasto = const Value.absent(),
                Value<String?> voci = const Value.absent(),
                Value<double?> grammi = const Value.absent(),
                Value<double?> quantita = const Value.absent(),
                Value<String?> unita = const Value.absent(),
                Value<double?> kcal = const Value.absent(),
                Value<double?> proteine = const Value.absent(),
                Value<double?> carboidrati = const Value.absent(),
                Value<double?> grassi = const Value.absent(),
                Value<double?> kcal100 = const Value.absent(),
                Value<double?> proteine100 = const Value.absent(),
                Value<double?> carboidrati100 = const Value.absent(),
                Value<double?> grassi100 = const Value.absent(),
                Value<DateTime> salvatoIl = const Value.absent(),
                Value<int> volteUsato = const Value.absent(),
                Value<DateTime?> usatoIl = const Value.absent(),
              }) => PreferitiCiboCompanion.insert(
                id: id,
                idSulServer: idSulServer,
                descrizione: descrizione,
                ePasto: ePasto,
                voci: voci,
                grammi: grammi,
                quantita: quantita,
                unita: unita,
                kcal: kcal,
                proteine: proteine,
                carboidrati: carboidrati,
                grassi: grassi,
                kcal100: kcal100,
                proteine100: proteine100,
                carboidrati100: carboidrati100,
                grassi100: grassi100,
                salvatoIl: salvatoIl,
                volteUsato: volteUsato,
                usatoIl: usatoIl,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PreferitiCiboTableProcessedTableManager =
    ProcessedTableManager<
      _$ArchivioSalute,
      $PreferitiCiboTable,
      PreferitoCibo,
      $$PreferitiCiboTableFilterComposer,
      $$PreferitiCiboTableOrderingComposer,
      $$PreferitiCiboTableAnnotationComposer,
      $$PreferitiCiboTableCreateCompanionBuilder,
      $$PreferitiCiboTableUpdateCompanionBuilder,
      (
        PreferitoCibo,
        BaseReferences<_$ArchivioSalute, $PreferitiCiboTable, PreferitoCibo>,
      ),
      PreferitoCibo,
      PrefetchHooks Function()
    >;
typedef $$ConsigliDelGiornoTableCreateCompanionBuilder =
    ConsigliDelGiornoCompanion Function({
      Value<int> id,
      required String fascia,
      required String testo,
      required DateTime generatoIl,
    });
typedef $$ConsigliDelGiornoTableUpdateCompanionBuilder =
    ConsigliDelGiornoCompanion Function({
      Value<int> id,
      Value<String> fascia,
      Value<String> testo,
      Value<DateTime> generatoIl,
    });

class $$ConsigliDelGiornoTableFilterComposer
    extends Composer<_$ArchivioSalute, $ConsigliDelGiornoTable> {
  $$ConsigliDelGiornoTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fascia => $composableBuilder(
    column: $table.fascia,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get testo => $composableBuilder(
    column: $table.testo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get generatoIl => $composableBuilder(
    column: $table.generatoIl,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ConsigliDelGiornoTableOrderingComposer
    extends Composer<_$ArchivioSalute, $ConsigliDelGiornoTable> {
  $$ConsigliDelGiornoTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fascia => $composableBuilder(
    column: $table.fascia,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get testo => $composableBuilder(
    column: $table.testo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get generatoIl => $composableBuilder(
    column: $table.generatoIl,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ConsigliDelGiornoTableAnnotationComposer
    extends Composer<_$ArchivioSalute, $ConsigliDelGiornoTable> {
  $$ConsigliDelGiornoTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get fascia =>
      $composableBuilder(column: $table.fascia, builder: (column) => column);

  GeneratedColumn<String> get testo =>
      $composableBuilder(column: $table.testo, builder: (column) => column);

  GeneratedColumn<DateTime> get generatoIl => $composableBuilder(
    column: $table.generatoIl,
    builder: (column) => column,
  );
}

class $$ConsigliDelGiornoTableTableManager
    extends
        RootTableManager<
          _$ArchivioSalute,
          $ConsigliDelGiornoTable,
          ConsiglioDelGiorno,
          $$ConsigliDelGiornoTableFilterComposer,
          $$ConsigliDelGiornoTableOrderingComposer,
          $$ConsigliDelGiornoTableAnnotationComposer,
          $$ConsigliDelGiornoTableCreateCompanionBuilder,
          $$ConsigliDelGiornoTableUpdateCompanionBuilder,
          (
            ConsiglioDelGiorno,
            BaseReferences<
              _$ArchivioSalute,
              $ConsigliDelGiornoTable,
              ConsiglioDelGiorno
            >,
          ),
          ConsiglioDelGiorno,
          PrefetchHooks Function()
        > {
  $$ConsigliDelGiornoTableTableManager(
    _$ArchivioSalute db,
    $ConsigliDelGiornoTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConsigliDelGiornoTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConsigliDelGiornoTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ConsigliDelGiornoTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> fascia = const Value.absent(),
                Value<String> testo = const Value.absent(),
                Value<DateTime> generatoIl = const Value.absent(),
              }) => ConsigliDelGiornoCompanion(
                id: id,
                fascia: fascia,
                testo: testo,
                generatoIl: generatoIl,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String fascia,
                required String testo,
                required DateTime generatoIl,
              }) => ConsigliDelGiornoCompanion.insert(
                id: id,
                fascia: fascia,
                testo: testo,
                generatoIl: generatoIl,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ConsigliDelGiornoTableProcessedTableManager =
    ProcessedTableManager<
      _$ArchivioSalute,
      $ConsigliDelGiornoTable,
      ConsiglioDelGiorno,
      $$ConsigliDelGiornoTableFilterComposer,
      $$ConsigliDelGiornoTableOrderingComposer,
      $$ConsigliDelGiornoTableAnnotationComposer,
      $$ConsigliDelGiornoTableCreateCompanionBuilder,
      $$ConsigliDelGiornoTableUpdateCompanionBuilder,
      (
        ConsiglioDelGiorno,
        BaseReferences<
          _$ArchivioSalute,
          $ConsigliDelGiornoTable,
          ConsiglioDelGiorno
        >,
      ),
      ConsiglioDelGiorno,
      PrefetchHooks Function()
    >;
typedef $$DocumentiImportatiTableCreateCompanionBuilder =
    DocumentiImportatiCompanion Function({
      Value<int> id,
      required String origineId,
      required String percorsi,
      required String tipo,
      required DateTime importatoIl,
    });
typedef $$DocumentiImportatiTableUpdateCompanionBuilder =
    DocumentiImportatiCompanion Function({
      Value<int> id,
      Value<String> origineId,
      Value<String> percorsi,
      Value<String> tipo,
      Value<DateTime> importatoIl,
    });

class $$DocumentiImportatiTableFilterComposer
    extends Composer<_$ArchivioSalute, $DocumentiImportatiTable> {
  $$DocumentiImportatiTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get origineId => $composableBuilder(
    column: $table.origineId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get percorsi => $composableBuilder(
    column: $table.percorsi,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tipo => $composableBuilder(
    column: $table.tipo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get importatoIl => $composableBuilder(
    column: $table.importatoIl,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DocumentiImportatiTableOrderingComposer
    extends Composer<_$ArchivioSalute, $DocumentiImportatiTable> {
  $$DocumentiImportatiTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get origineId => $composableBuilder(
    column: $table.origineId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get percorsi => $composableBuilder(
    column: $table.percorsi,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tipo => $composableBuilder(
    column: $table.tipo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get importatoIl => $composableBuilder(
    column: $table.importatoIl,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DocumentiImportatiTableAnnotationComposer
    extends Composer<_$ArchivioSalute, $DocumentiImportatiTable> {
  $$DocumentiImportatiTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get origineId =>
      $composableBuilder(column: $table.origineId, builder: (column) => column);

  GeneratedColumn<String> get percorsi =>
      $composableBuilder(column: $table.percorsi, builder: (column) => column);

  GeneratedColumn<String> get tipo =>
      $composableBuilder(column: $table.tipo, builder: (column) => column);

  GeneratedColumn<DateTime> get importatoIl => $composableBuilder(
    column: $table.importatoIl,
    builder: (column) => column,
  );
}

class $$DocumentiImportatiTableTableManager
    extends
        RootTableManager<
          _$ArchivioSalute,
          $DocumentiImportatiTable,
          DocumentoImportato,
          $$DocumentiImportatiTableFilterComposer,
          $$DocumentiImportatiTableOrderingComposer,
          $$DocumentiImportatiTableAnnotationComposer,
          $$DocumentiImportatiTableCreateCompanionBuilder,
          $$DocumentiImportatiTableUpdateCompanionBuilder,
          (
            DocumentoImportato,
            BaseReferences<
              _$ArchivioSalute,
              $DocumentiImportatiTable,
              DocumentoImportato
            >,
          ),
          DocumentoImportato,
          PrefetchHooks Function()
        > {
  $$DocumentiImportatiTableTableManager(
    _$ArchivioSalute db,
    $DocumentiImportatiTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DocumentiImportatiTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DocumentiImportatiTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DocumentiImportatiTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> origineId = const Value.absent(),
                Value<String> percorsi = const Value.absent(),
                Value<String> tipo = const Value.absent(),
                Value<DateTime> importatoIl = const Value.absent(),
              }) => DocumentiImportatiCompanion(
                id: id,
                origineId: origineId,
                percorsi: percorsi,
                tipo: tipo,
                importatoIl: importatoIl,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String origineId,
                required String percorsi,
                required String tipo,
                required DateTime importatoIl,
              }) => DocumentiImportatiCompanion.insert(
                id: id,
                origineId: origineId,
                percorsi: percorsi,
                tipo: tipo,
                importatoIl: importatoIl,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DocumentiImportatiTableProcessedTableManager =
    ProcessedTableManager<
      _$ArchivioSalute,
      $DocumentiImportatiTable,
      DocumentoImportato,
      $$DocumentiImportatiTableFilterComposer,
      $$DocumentiImportatiTableOrderingComposer,
      $$DocumentiImportatiTableAnnotationComposer,
      $$DocumentiImportatiTableCreateCompanionBuilder,
      $$DocumentiImportatiTableUpdateCompanionBuilder,
      (
        DocumentoImportato,
        BaseReferences<
          _$ArchivioSalute,
          $DocumentiImportatiTable,
          DocumentoImportato
        >,
      ),
      DocumentoImportato,
      PrefetchHooks Function()
    >;

class $ArchivioSaluteManager {
  final _$ArchivioSalute _db;
  $ArchivioSaluteManager(this._db);
  $$LettureSaluteTableTableManager get lettureSalute =>
      $$LettureSaluteTableTableManager(_db, _db.lettureSalute);
  $$CampioniSonnoTableTableManager get campioniSonno =>
      $$CampioniSonnoTableTableManager(_db, _db.campioniSonno);
  $$MisureCorpoTableTableManager get misureCorpo =>
      $$MisureCorpoTableTableManager(_db, _db.misureCorpo);
  $$FotoProgressiTableTableManager get fotoProgressi =>
      $$FotoProgressiTableTableManager(_db, _db.fotoProgressi);
  $$PianiRicevutiTableTableManager get pianiRicevuti =>
      $$PianiRicevutiTableTableManager(_db, _db.pianiRicevuti);
  $$ContenutiRifiutatiTableTableManager get contenutiRifiutati =>
      $$ContenutiRifiutatiTableTableManager(_db, _db.contenutiRifiutati);
  $$AllenamentiDaOrologioTableTableManager get allenamentiDaOrologio =>
      $$AllenamentiDaOrologioTableTableManager(_db, _db.allenamentiDaOrologio);
  $$SeduteAllenamentoTableTableManager get seduteAllenamento =>
      $$SeduteAllenamentoTableTableManager(_db, _db.seduteAllenamento);
  $$SerieDelleSeduteTableTableManager get serieDelleSedute =>
      $$SerieDelleSeduteTableTableManager(_db, _db.serieDelleSedute);
  $$SettimanaProgrammataTableTableManager get settimanaProgrammata =>
      $$SettimanaProgrammataTableTableManager(_db, _db.settimanaProgrammata);
  $$AnalisiDelleSchedeTableTableManager get analisiDelleSchede =>
      $$AnalisiDelleSchedeTableTableManager(_db, _db.analisiDelleSchede);
  $$VersioniDelleSchedeTableTableManager get versioniDelleSchede =>
      $$VersioniDelleSchedeTableTableManager(_db, _db.versioniDelleSchede);
  $$BruciateDichiarateTableTableManager get bruciateDichiarate =>
      $$BruciateDichiarateTableTableManager(_db, _db.bruciateDichiarate);
  $$SchedeSulTelefonoTableTableManager get schedeSulTelefono =>
      $$SchedeSulTelefonoTableTableManager(_db, _db.schedeSulTelefono);
  $$VociDiarioTableTableManager get vociDiario =>
      $$VociDiarioTableTableManager(_db, _db.vociDiario);
  $$PreferitiCiboTableTableManager get preferitiCibo =>
      $$PreferitiCiboTableTableManager(_db, _db.preferitiCibo);
  $$ConsigliDelGiornoTableTableManager get consigliDelGiorno =>
      $$ConsigliDelGiornoTableTableManager(_db, _db.consigliDelGiorno);
  $$DocumentiImportatiTableTableManager get documentiImportati =>
      $$DocumentiImportatiTableTableManager(_db, _db.documentiImportati);
}
