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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    messaggioId,
    mittenteId,
    nome,
    scheda,
    origineId,
    ricevutaIl,
    aggiornatoIl,
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
    if (data.containsKey('origine_id')) {
      context.handle(
        _origineIdMeta,
        origineId.isAcceptableOrUnknown(data['origine_id']!, _origineIdMeta),
      );
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
      origineId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origine_id'],
      ),
      ricevutaIl: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ricevuta_il'],
      )!,
      aggiornatoIl: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}aggiornato_il'],
      ),
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

  /// 🆕 G8 — l'identita' stabile (D15). Vedi `PianiRicevuti.origineId`.
  final String? origineId;
  final DateTime ricevutaIl;
  final DateTime? aggiornatoIl;
  const SchedaRicevuta({
    required this.id,
    required this.messaggioId,
    required this.mittenteId,
    required this.nome,
    required this.scheda,
    this.origineId,
    required this.ricevutaIl,
    this.aggiornatoIl,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['messaggio_id'] = Variable<int>(messaggioId);
    map['mittente_id'] = Variable<int>(mittenteId);
    map['nome'] = Variable<String>(nome);
    map['scheda'] = Variable<String>(scheda);
    if (!nullToAbsent || origineId != null) {
      map['origine_id'] = Variable<String>(origineId);
    }
    map['ricevuta_il'] = Variable<DateTime>(ricevutaIl);
    if (!nullToAbsent || aggiornatoIl != null) {
      map['aggiornato_il'] = Variable<DateTime>(aggiornatoIl);
    }
    return map;
  }

  SchedeRicevuteCompanion toCompanion(bool nullToAbsent) {
    return SchedeRicevuteCompanion(
      id: Value(id),
      messaggioId: Value(messaggioId),
      mittenteId: Value(mittenteId),
      nome: Value(nome),
      scheda: Value(scheda),
      origineId: origineId == null && nullToAbsent
          ? const Value.absent()
          : Value(origineId),
      ricevutaIl: Value(ricevutaIl),
      aggiornatoIl: aggiornatoIl == null && nullToAbsent
          ? const Value.absent()
          : Value(aggiornatoIl),
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
      origineId: serializer.fromJson<String?>(json['origineId']),
      ricevutaIl: serializer.fromJson<DateTime>(json['ricevutaIl']),
      aggiornatoIl: serializer.fromJson<DateTime?>(json['aggiornatoIl']),
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
      'origineId': serializer.toJson<String?>(origineId),
      'ricevutaIl': serializer.toJson<DateTime>(ricevutaIl),
      'aggiornatoIl': serializer.toJson<DateTime?>(aggiornatoIl),
    };
  }

  SchedaRicevuta copyWith({
    int? id,
    int? messaggioId,
    int? mittenteId,
    String? nome,
    String? scheda,
    Value<String?> origineId = const Value.absent(),
    DateTime? ricevutaIl,
    Value<DateTime?> aggiornatoIl = const Value.absent(),
  }) => SchedaRicevuta(
    id: id ?? this.id,
    messaggioId: messaggioId ?? this.messaggioId,
    mittenteId: mittenteId ?? this.mittenteId,
    nome: nome ?? this.nome,
    scheda: scheda ?? this.scheda,
    origineId: origineId.present ? origineId.value : this.origineId,
    ricevutaIl: ricevutaIl ?? this.ricevutaIl,
    aggiornatoIl: aggiornatoIl.present ? aggiornatoIl.value : this.aggiornatoIl,
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
      origineId: data.origineId.present ? data.origineId.value : this.origineId,
      ricevutaIl: data.ricevutaIl.present
          ? data.ricevutaIl.value
          : this.ricevutaIl,
      aggiornatoIl: data.aggiornatoIl.present
          ? data.aggiornatoIl.value
          : this.aggiornatoIl,
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
          ..write('origineId: $origineId, ')
          ..write('ricevutaIl: $ricevutaIl, ')
          ..write('aggiornatoIl: $aggiornatoIl')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    messaggioId,
    mittenteId,
    nome,
    scheda,
    origineId,
    ricevutaIl,
    aggiornatoIl,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SchedaRicevuta &&
          other.id == this.id &&
          other.messaggioId == this.messaggioId &&
          other.mittenteId == this.mittenteId &&
          other.nome == this.nome &&
          other.scheda == this.scheda &&
          other.origineId == this.origineId &&
          other.ricevutaIl == this.ricevutaIl &&
          other.aggiornatoIl == this.aggiornatoIl);
}

class SchedeRicevuteCompanion extends UpdateCompanion<SchedaRicevuta> {
  final Value<int> id;
  final Value<int> messaggioId;
  final Value<int> mittenteId;
  final Value<String> nome;
  final Value<String> scheda;
  final Value<String?> origineId;
  final Value<DateTime> ricevutaIl;
  final Value<DateTime?> aggiornatoIl;
  const SchedeRicevuteCompanion({
    this.id = const Value.absent(),
    this.messaggioId = const Value.absent(),
    this.mittenteId = const Value.absent(),
    this.nome = const Value.absent(),
    this.scheda = const Value.absent(),
    this.origineId = const Value.absent(),
    this.ricevutaIl = const Value.absent(),
    this.aggiornatoIl = const Value.absent(),
  });
  SchedeRicevuteCompanion.insert({
    this.id = const Value.absent(),
    required int messaggioId,
    required int mittenteId,
    required String nome,
    required String scheda,
    this.origineId = const Value.absent(),
    required DateTime ricevutaIl,
    this.aggiornatoIl = const Value.absent(),
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
    Expression<String>? origineId,
    Expression<DateTime>? ricevutaIl,
    Expression<DateTime>? aggiornatoIl,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (messaggioId != null) 'messaggio_id': messaggioId,
      if (mittenteId != null) 'mittente_id': mittenteId,
      if (nome != null) 'nome': nome,
      if (scheda != null) 'scheda': scheda,
      if (origineId != null) 'origine_id': origineId,
      if (ricevutaIl != null) 'ricevuta_il': ricevutaIl,
      if (aggiornatoIl != null) 'aggiornato_il': aggiornatoIl,
    });
  }

  SchedeRicevuteCompanion copyWith({
    Value<int>? id,
    Value<int>? messaggioId,
    Value<int>? mittenteId,
    Value<String>? nome,
    Value<String>? scheda,
    Value<String?>? origineId,
    Value<DateTime>? ricevutaIl,
    Value<DateTime?>? aggiornatoIl,
  }) {
    return SchedeRicevuteCompanion(
      id: id ?? this.id,
      messaggioId: messaggioId ?? this.messaggioId,
      mittenteId: mittenteId ?? this.mittenteId,
      nome: nome ?? this.nome,
      scheda: scheda ?? this.scheda,
      origineId: origineId ?? this.origineId,
      ricevutaIl: ricevutaIl ?? this.ricevutaIl,
      aggiornatoIl: aggiornatoIl ?? this.aggiornatoIl,
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
    if (origineId.present) {
      map['origine_id'] = Variable<String>(origineId.value);
    }
    if (ricevutaIl.present) {
      map['ricevuta_il'] = Variable<DateTime>(ricevutaIl.value);
    }
    if (aggiornatoIl.present) {
      map['aggiornato_il'] = Variable<DateTime>(aggiornatoIl.value);
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
          ..write('origineId: $origineId, ')
          ..write('ricevutaIl: $ricevutaIl, ')
          ..write('aggiornatoIl: $aggiornatoIl')
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
    nascosto,
    staccato,
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
      nascosto: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}nascosto'],
      )!,
      staccato: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}staccato'],
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
  /// 💡 È l'`id` locale di `SchedeRicevute`. `null` vuol dire «non l'ho
  /// assegnata», che è lo stato normale: la maggior parte delle corse non
  /// corrisponde a nessuna scheda.
  ///
  /// 🚨 **Una risincronizzazione non la cancella**: `scriviAllenamenti()` usa
  /// `insertOrIgnore`, quindi una riga già presente non viene riscritta. ⚠️ Con
  /// `insertOrReplace` l'orologio sovrascriverebbe una scelta della persona
  /// ogni volta che si rileggono gli ultimi sette giorni — cioè a ogni avvio.
  final int? schedaAssegnata;

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
    required this.nascosto,
    required this.staccato,
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
    map['nascosto'] = Variable<bool>(nascosto);
    map['staccato'] = Variable<bool>(staccato);
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
      nascosto: Value(nascosto),
      staccato: Value(staccato),
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
      nascosto: serializer.fromJson<bool>(json['nascosto']),
      staccato: serializer.fromJson<bool>(json['staccato']),
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
      'nascosto': serializer.toJson<bool>(nascosto),
      'staccato': serializer.toJson<bool>(staccato),
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
    bool? nascosto,
    bool? staccato,
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
    nascosto: nascosto ?? this.nascosto,
    staccato: staccato ?? this.staccato,
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
      nascosto: data.nascosto.present ? data.nascosto.value : this.nascosto,
      staccato: data.staccato.present ? data.staccato.value : this.staccato,
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
          ..write('nascosto: $nascosto, ')
          ..write('staccato: $staccato')
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
    nascosto,
    staccato,
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
          other.nascosto == this.nascosto &&
          other.staccato == this.staccato);
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
  final Value<bool> nascosto;
  final Value<bool> staccato;
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
    this.nascosto = const Value.absent(),
    this.staccato = const Value.absent(),
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
    this.nascosto = const Value.absent(),
    this.staccato = const Value.absent(),
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
    Expression<bool>? nascosto,
    Expression<bool>? staccato,
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
      if (nascosto != null) 'nascosto': nascosto,
      if (staccato != null) 'staccato': staccato,
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
    Value<bool>? nascosto,
    Value<bool>? staccato,
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
      nascosto: nascosto ?? this.nascosto,
      staccato: staccato ?? this.staccato,
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
    if (nascosto.present) {
      map['nascosto'] = Variable<bool>(nascosto.value);
    }
    if (staccato.present) {
      map['staccato'] = Variable<bool>(staccato.value);
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
          ..write('nascosto: $nascosto, ')
          ..write('staccato: $staccato')
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

  /// L'`id` che questa seduta aveva sul server, se ci è mai stata.
  final int? idServer;

  /// L'`id` **del server** della scheda eseguita, come lo mandava `plan_id`.
  ///
  /// ⚠️ Non l'id locale di `SchedeRicevute`: quello cambia da telefono a
  /// telefono, questo no. Le due cose si incrociano su `SchedeRicevute.origineId`.
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

abstract class _$ArchivioSalute extends GeneratedDatabase {
  _$ArchivioSalute(QueryExecutor e) : super(e);
  $ArchivioSaluteManager get managers => $ArchivioSaluteManager(this);
  late final $LettureSaluteTable lettureSalute = $LettureSaluteTable(this);
  late final $CampioniSonnoTable campioniSonno = $CampioniSonnoTable(this);
  late final $MisureCorpoTable misureCorpo = $MisureCorpoTable(this);
  late final $FotoProgressiTable fotoProgressi = $FotoProgressiTable(this);
  late final $SchedeRicevuteTable schedeRicevute = $SchedeRicevuteTable(this);
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
  late final $BruciateDichiarateTable bruciateDichiarate =
      $BruciateDichiarateTable(this);
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
    pianiRicevuti,
    contenutiRifiutati,
    allenamentiDaOrologio,
    seduteAllenamento,
    serieDelleSedute,
    bruciateDichiarate,
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
      Value<String?> origineId,
      required DateTime ricevutaIl,
      Value<DateTime?> aggiornatoIl,
    });
typedef $$SchedeRicevuteTableUpdateCompanionBuilder =
    SchedeRicevuteCompanion Function({
      Value<int> id,
      Value<int> messaggioId,
      Value<int> mittenteId,
      Value<String> nome,
      Value<String> scheda,
      Value<String?> origineId,
      Value<DateTime> ricevutaIl,
      Value<DateTime?> aggiornatoIl,
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

  ColumnFilters<String> get origineId => $composableBuilder(
    column: $table.origineId,
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

  ColumnOrderings<String> get origineId => $composableBuilder(
    column: $table.origineId,
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

  GeneratedColumn<String> get origineId =>
      $composableBuilder(column: $table.origineId, builder: (column) => column);

  GeneratedColumn<DateTime> get ricevutaIl => $composableBuilder(
    column: $table.ricevutaIl,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get aggiornatoIl => $composableBuilder(
    column: $table.aggiornatoIl,
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
                Value<String?> origineId = const Value.absent(),
                Value<DateTime> ricevutaIl = const Value.absent(),
                Value<DateTime?> aggiornatoIl = const Value.absent(),
              }) => SchedeRicevuteCompanion(
                id: id,
                messaggioId: messaggioId,
                mittenteId: mittenteId,
                nome: nome,
                scheda: scheda,
                origineId: origineId,
                ricevutaIl: ricevutaIl,
                aggiornatoIl: aggiornatoIl,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int messaggioId,
                required int mittenteId,
                required String nome,
                required String scheda,
                Value<String?> origineId = const Value.absent(),
                required DateTime ricevutaIl,
                Value<DateTime?> aggiornatoIl = const Value.absent(),
              }) => SchedeRicevuteCompanion.insert(
                id: id,
                messaggioId: messaggioId,
                mittenteId: mittenteId,
                nome: nome,
                scheda: scheda,
                origineId: origineId,
                ricevutaIl: ricevutaIl,
                aggiornatoIl: aggiornatoIl,
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
      Value<bool> nascosto,
      Value<bool> staccato,
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
      Value<bool> nascosto,
      Value<bool> staccato,
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

  ColumnFilters<bool> get nascosto => $composableBuilder(
    column: $table.nascosto,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get staccato => $composableBuilder(
    column: $table.staccato,
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

  ColumnOrderings<bool> get nascosto => $composableBuilder(
    column: $table.nascosto,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get staccato => $composableBuilder(
    column: $table.staccato,
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

  GeneratedColumn<bool> get nascosto =>
      $composableBuilder(column: $table.nascosto, builder: (column) => column);

  GeneratedColumn<bool> get staccato =>
      $composableBuilder(column: $table.staccato, builder: (column) => column);
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
                Value<bool> nascosto = const Value.absent(),
                Value<bool> staccato = const Value.absent(),
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
                nascosto: nascosto,
                staccato: staccato,
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
                Value<bool> nascosto = const Value.absent(),
                Value<bool> staccato = const Value.absent(),
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
                nascosto: nascosto,
                staccato: staccato,
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
  $$BruciateDichiarateTableTableManager get bruciateDichiarate =>
      $$BruciateDichiarateTableTableManager(_db, _db.bruciateDichiarate);
}
