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
  @override
  List<GeneratedColumn> get $columns => [id, percorso, scattataIl, sessioneId];
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
  const FotoProgresso({
    required this.id,
    required this.percorso,
    required this.scattataIl,
    this.sessioneId,
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
    };
  }

  FotoProgresso copyWith({
    int? id,
    String? percorso,
    DateTime? scattataIl,
    Value<int?> sessioneId = const Value.absent(),
  }) => FotoProgresso(
    id: id ?? this.id,
    percorso: percorso ?? this.percorso,
    scattataIl: scattataIl ?? this.scattataIl,
    sessioneId: sessioneId.present ? sessioneId.value : this.sessioneId,
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
    );
  }

  @override
  String toString() {
    return (StringBuffer('FotoProgresso(')
          ..write('id: $id, ')
          ..write('percorso: $percorso, ')
          ..write('scattataIl: $scattataIl, ')
          ..write('sessioneId: $sessioneId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, percorso, scattataIl, sessioneId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FotoProgresso &&
          other.id == this.id &&
          other.percorso == this.percorso &&
          other.scattataIl == this.scattataIl &&
          other.sessioneId == this.sessioneId);
}

class FotoProgressiCompanion extends UpdateCompanion<FotoProgresso> {
  final Value<int> id;
  final Value<String> percorso;
  final Value<DateTime> scattataIl;
  final Value<int?> sessioneId;
  const FotoProgressiCompanion({
    this.id = const Value.absent(),
    this.percorso = const Value.absent(),
    this.scattataIl = const Value.absent(),
    this.sessioneId = const Value.absent(),
  });
  FotoProgressiCompanion.insert({
    this.id = const Value.absent(),
    required String percorso,
    required DateTime scattataIl,
    this.sessioneId = const Value.absent(),
  }) : percorso = Value(percorso),
       scattataIl = Value(scattataIl);
  static Insertable<FotoProgresso> custom({
    Expression<int>? id,
    Expression<String>? percorso,
    Expression<DateTime>? scattataIl,
    Expression<int>? sessioneId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (percorso != null) 'percorso': percorso,
      if (scattataIl != null) 'scattata_il': scattataIl,
      if (sessioneId != null) 'sessione_id': sessioneId,
    });
  }

  FotoProgressiCompanion copyWith({
    Value<int>? id,
    Value<String>? percorso,
    Value<DateTime>? scattataIl,
    Value<int?>? sessioneId,
  }) {
    return FotoProgressiCompanion(
      id: id ?? this.id,
      percorso: percorso ?? this.percorso,
      scattataIl: scattataIl ?? this.scattataIl,
      sessioneId: sessioneId ?? this.sessioneId,
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
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FotoProgressiCompanion(')
          ..write('id: $id, ')
          ..write('percorso: $percorso, ')
          ..write('scattataIl: $scattataIl, ')
          ..write('sessioneId: $sessioneId')
          ..write(')'))
        .toString();
  }
}

class $SchedeRicevuteTable extends SchedeRicevute
    with TableInfo<$SchedeRicevuteTable, SchedaRicevuta> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SchedeRicevuteTable(this.attachedDatabase, [this._alias]);
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    messaggioId,
    mittenteId,
    nome,
    scheda,
    ricevutaIl,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'schede_ricevute';
  @override
  VerificationContext validateIntegrity(
    Insertable<SchedaRicevuta> instance, {
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
    if (data.containsKey('ricevuta_il')) {
      context.handle(
        _ricevutaIlMeta,
        ricevutaIl.isAcceptableOrUnknown(data['ricevuta_il']!, _ricevutaIlMeta),
      );
    } else if (isInserting) {
      context.missing(_ricevutaIlMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SchedaRicevuta map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SchedaRicevuta(
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
      nome: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nome'],
      )!,
      scheda: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scheda'],
      )!,
      ricevutaIl: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ricevuta_il'],
      )!,
    );
  }

  @override
  $SchedeRicevuteTable createAlias(String alias) {
    return $SchedeRicevuteTable(attachedDatabase, alias);
  }
}

class SchedaRicevuta extends DataClass implements Insertable<SchedaRicevuta> {
  final int id;

  /// 🚨 **L'id del messaggio, unico.** È ciò che impedisce che toccare due
  /// volte «aggiungi» produca due copie della stessa scheda.
  ///
  /// ⚠️ Non è l'id della *scheda*: lo stesso modello può arrivare due volte —
  /// il trainer lo rimanda dopo averlo corretto — e sono **due schede diverse**
  /// nella vita di chi le riceve.
  final int messaggioId;
  final int mittenteId;

  /// Il nome, estratto per poterlo mostrare senza aprire il JSON a ogni riga.
  final String nome;

  /// La scheda intera, serializzata.
  final String scheda;
  final DateTime ricevutaIl;
  const SchedaRicevuta({
    required this.id,
    required this.messaggioId,
    required this.mittenteId,
    required this.nome,
    required this.scheda,
    required this.ricevutaIl,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['messaggio_id'] = Variable<int>(messaggioId);
    map['mittente_id'] = Variable<int>(mittenteId);
    map['nome'] = Variable<String>(nome);
    map['scheda'] = Variable<String>(scheda);
    map['ricevuta_il'] = Variable<DateTime>(ricevutaIl);
    return map;
  }

  SchedeRicevuteCompanion toCompanion(bool nullToAbsent) {
    return SchedeRicevuteCompanion(
      id: Value(id),
      messaggioId: Value(messaggioId),
      mittenteId: Value(mittenteId),
      nome: Value(nome),
      scheda: Value(scheda),
      ricevutaIl: Value(ricevutaIl),
    );
  }

  factory SchedaRicevuta.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SchedaRicevuta(
      id: serializer.fromJson<int>(json['id']),
      messaggioId: serializer.fromJson<int>(json['messaggioId']),
      mittenteId: serializer.fromJson<int>(json['mittenteId']),
      nome: serializer.fromJson<String>(json['nome']),
      scheda: serializer.fromJson<String>(json['scheda']),
      ricevutaIl: serializer.fromJson<DateTime>(json['ricevutaIl']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'messaggioId': serializer.toJson<int>(messaggioId),
      'mittenteId': serializer.toJson<int>(mittenteId),
      'nome': serializer.toJson<String>(nome),
      'scheda': serializer.toJson<String>(scheda),
      'ricevutaIl': serializer.toJson<DateTime>(ricevutaIl),
    };
  }

  SchedaRicevuta copyWith({
    int? id,
    int? messaggioId,
    int? mittenteId,
    String? nome,
    String? scheda,
    DateTime? ricevutaIl,
  }) => SchedaRicevuta(
    id: id ?? this.id,
    messaggioId: messaggioId ?? this.messaggioId,
    mittenteId: mittenteId ?? this.mittenteId,
    nome: nome ?? this.nome,
    scheda: scheda ?? this.scheda,
    ricevutaIl: ricevutaIl ?? this.ricevutaIl,
  );
  SchedaRicevuta copyWithCompanion(SchedeRicevuteCompanion data) {
    return SchedaRicevuta(
      id: data.id.present ? data.id.value : this.id,
      messaggioId: data.messaggioId.present
          ? data.messaggioId.value
          : this.messaggioId,
      mittenteId: data.mittenteId.present
          ? data.mittenteId.value
          : this.mittenteId,
      nome: data.nome.present ? data.nome.value : this.nome,
      scheda: data.scheda.present ? data.scheda.value : this.scheda,
      ricevutaIl: data.ricevutaIl.present
          ? data.ricevutaIl.value
          : this.ricevutaIl,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SchedaRicevuta(')
          ..write('id: $id, ')
          ..write('messaggioId: $messaggioId, ')
          ..write('mittenteId: $mittenteId, ')
          ..write('nome: $nome, ')
          ..write('scheda: $scheda, ')
          ..write('ricevutaIl: $ricevutaIl')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, messaggioId, mittenteId, nome, scheda, ricevutaIl);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SchedaRicevuta &&
          other.id == this.id &&
          other.messaggioId == this.messaggioId &&
          other.mittenteId == this.mittenteId &&
          other.nome == this.nome &&
          other.scheda == this.scheda &&
          other.ricevutaIl == this.ricevutaIl);
}

class SchedeRicevuteCompanion extends UpdateCompanion<SchedaRicevuta> {
  final Value<int> id;
  final Value<int> messaggioId;
  final Value<int> mittenteId;
  final Value<String> nome;
  final Value<String> scheda;
  final Value<DateTime> ricevutaIl;
  const SchedeRicevuteCompanion({
    this.id = const Value.absent(),
    this.messaggioId = const Value.absent(),
    this.mittenteId = const Value.absent(),
    this.nome = const Value.absent(),
    this.scheda = const Value.absent(),
    this.ricevutaIl = const Value.absent(),
  });
  SchedeRicevuteCompanion.insert({
    this.id = const Value.absent(),
    required int messaggioId,
    required int mittenteId,
    required String nome,
    required String scheda,
    required DateTime ricevutaIl,
  }) : messaggioId = Value(messaggioId),
       mittenteId = Value(mittenteId),
       nome = Value(nome),
       scheda = Value(scheda),
       ricevutaIl = Value(ricevutaIl);
  static Insertable<SchedaRicevuta> custom({
    Expression<int>? id,
    Expression<int>? messaggioId,
    Expression<int>? mittenteId,
    Expression<String>? nome,
    Expression<String>? scheda,
    Expression<DateTime>? ricevutaIl,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (messaggioId != null) 'messaggio_id': messaggioId,
      if (mittenteId != null) 'mittente_id': mittenteId,
      if (nome != null) 'nome': nome,
      if (scheda != null) 'scheda': scheda,
      if (ricevutaIl != null) 'ricevuta_il': ricevutaIl,
    });
  }

  SchedeRicevuteCompanion copyWith({
    Value<int>? id,
    Value<int>? messaggioId,
    Value<int>? mittenteId,
    Value<String>? nome,
    Value<String>? scheda,
    Value<DateTime>? ricevutaIl,
  }) {
    return SchedeRicevuteCompanion(
      id: id ?? this.id,
      messaggioId: messaggioId ?? this.messaggioId,
      mittenteId: mittenteId ?? this.mittenteId,
      nome: nome ?? this.nome,
      scheda: scheda ?? this.scheda,
      ricevutaIl: ricevutaIl ?? this.ricevutaIl,
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
    if (nome.present) {
      map['nome'] = Variable<String>(nome.value);
    }
    if (scheda.present) {
      map['scheda'] = Variable<String>(scheda.value);
    }
    if (ricevutaIl.present) {
      map['ricevuta_il'] = Variable<DateTime>(ricevutaIl.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SchedeRicevuteCompanion(')
          ..write('id: $id, ')
          ..write('messaggioId: $messaggioId, ')
          ..write('mittenteId: $mittenteId, ')
          ..write('nome: $nome, ')
          ..write('scheda: $scheda, ')
          ..write('ricevutaIl: $ricevutaIl')
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
  late final $SchedeRicevuteTable schedeRicevute = $SchedeRicevuteTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    lettureSalute,
    campioniSonno,
    misureCorpo,
    fotoProgressi,
    schedeRicevute,
  ];
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
    });
typedef $$FotoProgressiTableUpdateCompanionBuilder =
    FotoProgressiCompanion Function({
      Value<int> id,
      Value<String> percorso,
      Value<DateTime> scattataIl,
      Value<int?> sessioneId,
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
              }) => FotoProgressiCompanion(
                id: id,
                percorso: percorso,
                scattataIl: scattataIl,
                sessioneId: sessioneId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String percorso,
                required DateTime scattataIl,
                Value<int?> sessioneId = const Value.absent(),
              }) => FotoProgressiCompanion.insert(
                id: id,
                percorso: percorso,
                scattataIl: scattataIl,
                sessioneId: sessioneId,
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
typedef $$SchedeRicevuteTableCreateCompanionBuilder =
    SchedeRicevuteCompanion Function({
      Value<int> id,
      required int messaggioId,
      required int mittenteId,
      required String nome,
      required String scheda,
      required DateTime ricevutaIl,
    });
typedef $$SchedeRicevuteTableUpdateCompanionBuilder =
    SchedeRicevuteCompanion Function({
      Value<int> id,
      Value<int> messaggioId,
      Value<int> mittenteId,
      Value<String> nome,
      Value<String> scheda,
      Value<DateTime> ricevutaIl,
    });

class $$SchedeRicevuteTableFilterComposer
    extends Composer<_$ArchivioSalute, $SchedeRicevuteTable> {
  $$SchedeRicevuteTableFilterComposer({
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

  ColumnFilters<String> get nome => $composableBuilder(
    column: $table.nome,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scheda => $composableBuilder(
    column: $table.scheda,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get ricevutaIl => $composableBuilder(
    column: $table.ricevutaIl,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SchedeRicevuteTableOrderingComposer
    extends Composer<_$ArchivioSalute, $SchedeRicevuteTable> {
  $$SchedeRicevuteTableOrderingComposer({
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

  ColumnOrderings<String> get nome => $composableBuilder(
    column: $table.nome,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scheda => $composableBuilder(
    column: $table.scheda,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get ricevutaIl => $composableBuilder(
    column: $table.ricevutaIl,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SchedeRicevuteTableAnnotationComposer
    extends Composer<_$ArchivioSalute, $SchedeRicevuteTable> {
  $$SchedeRicevuteTableAnnotationComposer({
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

  GeneratedColumn<String> get nome =>
      $composableBuilder(column: $table.nome, builder: (column) => column);

  GeneratedColumn<String> get scheda =>
      $composableBuilder(column: $table.scheda, builder: (column) => column);

  GeneratedColumn<DateTime> get ricevutaIl => $composableBuilder(
    column: $table.ricevutaIl,
    builder: (column) => column,
  );
}

class $$SchedeRicevuteTableTableManager
    extends
        RootTableManager<
          _$ArchivioSalute,
          $SchedeRicevuteTable,
          SchedaRicevuta,
          $$SchedeRicevuteTableFilterComposer,
          $$SchedeRicevuteTableOrderingComposer,
          $$SchedeRicevuteTableAnnotationComposer,
          $$SchedeRicevuteTableCreateCompanionBuilder,
          $$SchedeRicevuteTableUpdateCompanionBuilder,
          (
            SchedaRicevuta,
            BaseReferences<
              _$ArchivioSalute,
              $SchedeRicevuteTable,
              SchedaRicevuta
            >,
          ),
          SchedaRicevuta,
          PrefetchHooks Function()
        > {
  $$SchedeRicevuteTableTableManager(
    _$ArchivioSalute db,
    $SchedeRicevuteTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SchedeRicevuteTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SchedeRicevuteTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SchedeRicevuteTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> messaggioId = const Value.absent(),
                Value<int> mittenteId = const Value.absent(),
                Value<String> nome = const Value.absent(),
                Value<String> scheda = const Value.absent(),
                Value<DateTime> ricevutaIl = const Value.absent(),
              }) => SchedeRicevuteCompanion(
                id: id,
                messaggioId: messaggioId,
                mittenteId: mittenteId,
                nome: nome,
                scheda: scheda,
                ricevutaIl: ricevutaIl,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int messaggioId,
                required int mittenteId,
                required String nome,
                required String scheda,
                required DateTime ricevutaIl,
              }) => SchedeRicevuteCompanion.insert(
                id: id,
                messaggioId: messaggioId,
                mittenteId: mittenteId,
                nome: nome,
                scheda: scheda,
                ricevutaIl: ricevutaIl,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SchedeRicevuteTableProcessedTableManager =
    ProcessedTableManager<
      _$ArchivioSalute,
      $SchedeRicevuteTable,
      SchedaRicevuta,
      $$SchedeRicevuteTableFilterComposer,
      $$SchedeRicevuteTableOrderingComposer,
      $$SchedeRicevuteTableAnnotationComposer,
      $$SchedeRicevuteTableCreateCompanionBuilder,
      $$SchedeRicevuteTableUpdateCompanionBuilder,
      (
        SchedaRicevuta,
        BaseReferences<_$ArchivioSalute, $SchedeRicevuteTable, SchedaRicevuta>,
      ),
      SchedaRicevuta,
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
  $$SchedeRicevuteTableTableManager get schedeRicevute =>
      $$SchedeRicevuteTableTableManager(_db, _db.schedeRicevute);
}
