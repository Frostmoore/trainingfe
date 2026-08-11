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

abstract class _$ArchivioSalute extends GeneratedDatabase {
  _$ArchivioSalute(QueryExecutor e) : super(e);
  $ArchivioSaluteManager get managers => $ArchivioSaluteManager(this);
  late final $LettureSaluteTable lettureSalute = $LettureSaluteTable(this);
  late final $CampioniSonnoTable campioniSonno = $CampioniSonnoTable(this);
  late final $MisureCorpoTable misureCorpo = $MisureCorpoTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    lettureSalute,
    campioniSonno,
    misureCorpo,
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

class $ArchivioSaluteManager {
  final _$ArchivioSalute _db;
  $ArchivioSaluteManager(this._db);
  $$LettureSaluteTableTableManager get lettureSalute =>
      $$LettureSaluteTableTableManager(_db, _db.lettureSalute);
  $$CampioniSonnoTableTableManager get campioniSonno =>
      $$CampioniSonnoTableTableManager(_db, _db.campioniSonno);
  $$MisureCorpoTableTableManager get misureCorpo =>
      $$MisureCorpoTableTableManager(_db, _db.misureCorpo);
}
