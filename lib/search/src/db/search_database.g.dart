// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_database.dart';

// ignore_for_file: type=lint
class $CardsTable extends Cards with TableInfo<$CardsTable, CardRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CardsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _imagePathMeta = const VerificationMeta(
    'imagePath',
  );
  @override
  late final GeneratedColumn<String> imagePath = GeneratedColumn<String>(
    'image_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _nameLowerMeta = const VerificationMeta(
    'nameLower',
  );
  @override
  late final GeneratedColumn<String> nameLower = GeneratedColumn<String>(
    'name_lower',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [id, imagePath, name, nameLower];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cards';
  @override
  VerificationContext validateIntegrity(
    Insertable<CardRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('image_path')) {
      context.handle(
        _imagePathMeta,
        imagePath.isAcceptableOrUnknown(data['image_path']!, _imagePathMeta),
      );
    } else if (isInserting) {
      context.missing(_imagePathMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('name_lower')) {
      context.handle(
        _nameLowerMeta,
        nameLower.isAcceptableOrUnknown(data['name_lower']!, _nameLowerMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {imagePath},
  ];
  @override
  CardRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CardRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      imagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_path'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      nameLower: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name_lower'],
      )!,
    );
  }

  @override
  $CardsTable createAlias(String alias) {
    return $CardsTable(attachedDatabase, alias);
  }
}

class CardRow extends DataClass implements Insertable<CardRow> {
  final int id;
  final String imagePath;
  final String name;
  final String nameLower;
  const CardRow({
    required this.id,
    required this.imagePath,
    required this.name,
    required this.nameLower,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['image_path'] = Variable<String>(imagePath);
    map['name'] = Variable<String>(name);
    map['name_lower'] = Variable<String>(nameLower);
    return map;
  }

  CardsCompanion toCompanion(bool nullToAbsent) {
    return CardsCompanion(
      id: Value(id),
      imagePath: Value(imagePath),
      name: Value(name),
      nameLower: Value(nameLower),
    );
  }

  factory CardRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CardRow(
      id: serializer.fromJson<int>(json['id']),
      imagePath: serializer.fromJson<String>(json['imagePath']),
      name: serializer.fromJson<String>(json['name']),
      nameLower: serializer.fromJson<String>(json['nameLower']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'imagePath': serializer.toJson<String>(imagePath),
      'name': serializer.toJson<String>(name),
      'nameLower': serializer.toJson<String>(nameLower),
    };
  }

  CardRow copyWith({
    int? id,
    String? imagePath,
    String? name,
    String? nameLower,
  }) => CardRow(
    id: id ?? this.id,
    imagePath: imagePath ?? this.imagePath,
    name: name ?? this.name,
    nameLower: nameLower ?? this.nameLower,
  );
  CardRow copyWithCompanion(CardsCompanion data) {
    return CardRow(
      id: data.id.present ? data.id.value : this.id,
      imagePath: data.imagePath.present ? data.imagePath.value : this.imagePath,
      name: data.name.present ? data.name.value : this.name,
      nameLower: data.nameLower.present ? data.nameLower.value : this.nameLower,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CardRow(')
          ..write('id: $id, ')
          ..write('imagePath: $imagePath, ')
          ..write('name: $name, ')
          ..write('nameLower: $nameLower')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, imagePath, name, nameLower);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CardRow &&
          other.id == this.id &&
          other.imagePath == this.imagePath &&
          other.name == this.name &&
          other.nameLower == this.nameLower);
}

class CardsCompanion extends UpdateCompanion<CardRow> {
  final Value<int> id;
  final Value<String> imagePath;
  final Value<String> name;
  final Value<String> nameLower;
  const CardsCompanion({
    this.id = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.name = const Value.absent(),
    this.nameLower = const Value.absent(),
  });
  CardsCompanion.insert({
    this.id = const Value.absent(),
    required String imagePath,
    this.name = const Value.absent(),
    this.nameLower = const Value.absent(),
  }) : imagePath = Value(imagePath);
  static Insertable<CardRow> custom({
    Expression<int>? id,
    Expression<String>? imagePath,
    Expression<String>? name,
    Expression<String>? nameLower,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (imagePath != null) 'image_path': imagePath,
      if (name != null) 'name': name,
      if (nameLower != null) 'name_lower': nameLower,
    });
  }

  CardsCompanion copyWith({
    Value<int>? id,
    Value<String>? imagePath,
    Value<String>? name,
    Value<String>? nameLower,
  }) {
    return CardsCompanion(
      id: id ?? this.id,
      imagePath: imagePath ?? this.imagePath,
      name: name ?? this.name,
      nameLower: nameLower ?? this.nameLower,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (imagePath.present) {
      map['image_path'] = Variable<String>(imagePath.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (nameLower.present) {
      map['name_lower'] = Variable<String>(nameLower.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CardsCompanion(')
          ..write('id: $id, ')
          ..write('imagePath: $imagePath, ')
          ..write('name: $name, ')
          ..write('nameLower: $nameLower')
          ..write(')'))
        .toString();
  }
}

class $CardVectorsTable extends CardVectors
    with TableInfo<$CardVectorsTable, CardVectorRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CardVectorsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _cardIdMeta = const VerificationMeta('cardId');
  @override
  late final GeneratedColumn<int> cardId = GeneratedColumn<int>(
    'card_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES cards (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _fieldMeta = const VerificationMeta('field');
  @override
  late final GeneratedColumn<String> field = GeneratedColumn<String>(
    'field',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chunkIndexMeta = const VerificationMeta(
    'chunkIndex',
  );
  @override
  late final GeneratedColumn<int> chunkIndex = GeneratedColumn<int>(
    'chunk_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _embeddingMeta = const VerificationMeta(
    'embedding',
  );
  @override
  late final GeneratedColumn<Uint8List> embedding = GeneratedColumn<Uint8List>(
    'embedding',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    cardId,
    field,
    chunkIndex,
    embedding,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'card_vectors';
  @override
  VerificationContext validateIntegrity(
    Insertable<CardVectorRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('card_id')) {
      context.handle(
        _cardIdMeta,
        cardId.isAcceptableOrUnknown(data['card_id']!, _cardIdMeta),
      );
    } else if (isInserting) {
      context.missing(_cardIdMeta);
    }
    if (data.containsKey('field')) {
      context.handle(
        _fieldMeta,
        field.isAcceptableOrUnknown(data['field']!, _fieldMeta),
      );
    } else if (isInserting) {
      context.missing(_fieldMeta);
    }
    if (data.containsKey('chunk_index')) {
      context.handle(
        _chunkIndexMeta,
        chunkIndex.isAcceptableOrUnknown(data['chunk_index']!, _chunkIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_chunkIndexMeta);
    }
    if (data.containsKey('embedding')) {
      context.handle(
        _embeddingMeta,
        embedding.isAcceptableOrUnknown(data['embedding']!, _embeddingMeta),
      );
    } else if (isInserting) {
      context.missing(_embeddingMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CardVectorRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CardVectorRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      cardId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}card_id'],
      )!,
      field: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}field'],
      )!,
      chunkIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chunk_index'],
      )!,
      embedding: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}embedding'],
      )!,
    );
  }

  @override
  $CardVectorsTable createAlias(String alias) {
    return $CardVectorsTable(attachedDatabase, alias);
  }
}

class CardVectorRow extends DataClass implements Insertable<CardVectorRow> {
  final int id;
  final int cardId;
  final String field;
  final int chunkIndex;
  final Uint8List embedding;
  const CardVectorRow({
    required this.id,
    required this.cardId,
    required this.field,
    required this.chunkIndex,
    required this.embedding,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['card_id'] = Variable<int>(cardId);
    map['field'] = Variable<String>(field);
    map['chunk_index'] = Variable<int>(chunkIndex);
    map['embedding'] = Variable<Uint8List>(embedding);
    return map;
  }

  CardVectorsCompanion toCompanion(bool nullToAbsent) {
    return CardVectorsCompanion(
      id: Value(id),
      cardId: Value(cardId),
      field: Value(field),
      chunkIndex: Value(chunkIndex),
      embedding: Value(embedding),
    );
  }

  factory CardVectorRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CardVectorRow(
      id: serializer.fromJson<int>(json['id']),
      cardId: serializer.fromJson<int>(json['cardId']),
      field: serializer.fromJson<String>(json['field']),
      chunkIndex: serializer.fromJson<int>(json['chunkIndex']),
      embedding: serializer.fromJson<Uint8List>(json['embedding']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'cardId': serializer.toJson<int>(cardId),
      'field': serializer.toJson<String>(field),
      'chunkIndex': serializer.toJson<int>(chunkIndex),
      'embedding': serializer.toJson<Uint8List>(embedding),
    };
  }

  CardVectorRow copyWith({
    int? id,
    int? cardId,
    String? field,
    int? chunkIndex,
    Uint8List? embedding,
  }) => CardVectorRow(
    id: id ?? this.id,
    cardId: cardId ?? this.cardId,
    field: field ?? this.field,
    chunkIndex: chunkIndex ?? this.chunkIndex,
    embedding: embedding ?? this.embedding,
  );
  CardVectorRow copyWithCompanion(CardVectorsCompanion data) {
    return CardVectorRow(
      id: data.id.present ? data.id.value : this.id,
      cardId: data.cardId.present ? data.cardId.value : this.cardId,
      field: data.field.present ? data.field.value : this.field,
      chunkIndex: data.chunkIndex.present
          ? data.chunkIndex.value
          : this.chunkIndex,
      embedding: data.embedding.present ? data.embedding.value : this.embedding,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CardVectorRow(')
          ..write('id: $id, ')
          ..write('cardId: $cardId, ')
          ..write('field: $field, ')
          ..write('chunkIndex: $chunkIndex, ')
          ..write('embedding: $embedding')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    cardId,
    field,
    chunkIndex,
    $driftBlobEquality.hash(embedding),
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CardVectorRow &&
          other.id == this.id &&
          other.cardId == this.cardId &&
          other.field == this.field &&
          other.chunkIndex == this.chunkIndex &&
          $driftBlobEquality.equals(other.embedding, this.embedding));
}

class CardVectorsCompanion extends UpdateCompanion<CardVectorRow> {
  final Value<int> id;
  final Value<int> cardId;
  final Value<String> field;
  final Value<int> chunkIndex;
  final Value<Uint8List> embedding;
  const CardVectorsCompanion({
    this.id = const Value.absent(),
    this.cardId = const Value.absent(),
    this.field = const Value.absent(),
    this.chunkIndex = const Value.absent(),
    this.embedding = const Value.absent(),
  });
  CardVectorsCompanion.insert({
    this.id = const Value.absent(),
    required int cardId,
    required String field,
    required int chunkIndex,
    required Uint8List embedding,
  }) : cardId = Value(cardId),
       field = Value(field),
       chunkIndex = Value(chunkIndex),
       embedding = Value(embedding);
  static Insertable<CardVectorRow> custom({
    Expression<int>? id,
    Expression<int>? cardId,
    Expression<String>? field,
    Expression<int>? chunkIndex,
    Expression<Uint8List>? embedding,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (cardId != null) 'card_id': cardId,
      if (field != null) 'field': field,
      if (chunkIndex != null) 'chunk_index': chunkIndex,
      if (embedding != null) 'embedding': embedding,
    });
  }

  CardVectorsCompanion copyWith({
    Value<int>? id,
    Value<int>? cardId,
    Value<String>? field,
    Value<int>? chunkIndex,
    Value<Uint8List>? embedding,
  }) {
    return CardVectorsCompanion(
      id: id ?? this.id,
      cardId: cardId ?? this.cardId,
      field: field ?? this.field,
      chunkIndex: chunkIndex ?? this.chunkIndex,
      embedding: embedding ?? this.embedding,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (cardId.present) {
      map['card_id'] = Variable<int>(cardId.value);
    }
    if (field.present) {
      map['field'] = Variable<String>(field.value);
    }
    if (chunkIndex.present) {
      map['chunk_index'] = Variable<int>(chunkIndex.value);
    }
    if (embedding.present) {
      map['embedding'] = Variable<Uint8List>(embedding.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CardVectorsCompanion(')
          ..write('id: $id, ')
          ..write('cardId: $cardId, ')
          ..write('field: $field, ')
          ..write('chunkIndex: $chunkIndex, ')
          ..write('embedding: $embedding')
          ..write(')'))
        .toString();
  }
}

class $CardFieldHashesTable extends CardFieldHashes
    with TableInfo<$CardFieldHashesTable, CardFieldHashRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CardFieldHashesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _cardIdMeta = const VerificationMeta('cardId');
  @override
  late final GeneratedColumn<int> cardId = GeneratedColumn<int>(
    'card_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES cards (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _fieldMeta = const VerificationMeta('field');
  @override
  late final GeneratedColumn<String> field = GeneratedColumn<String>(
    'field',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hashMeta = const VerificationMeta('hash');
  @override
  late final GeneratedColumn<String> hash = GeneratedColumn<String>(
    'hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [cardId, field, hash];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'card_field_hashes';
  @override
  VerificationContext validateIntegrity(
    Insertable<CardFieldHashRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('card_id')) {
      context.handle(
        _cardIdMeta,
        cardId.isAcceptableOrUnknown(data['card_id']!, _cardIdMeta),
      );
    } else if (isInserting) {
      context.missing(_cardIdMeta);
    }
    if (data.containsKey('field')) {
      context.handle(
        _fieldMeta,
        field.isAcceptableOrUnknown(data['field']!, _fieldMeta),
      );
    } else if (isInserting) {
      context.missing(_fieldMeta);
    }
    if (data.containsKey('hash')) {
      context.handle(
        _hashMeta,
        hash.isAcceptableOrUnknown(data['hash']!, _hashMeta),
      );
    } else if (isInserting) {
      context.missing(_hashMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {cardId, field};
  @override
  CardFieldHashRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CardFieldHashRow(
      cardId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}card_id'],
      )!,
      field: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}field'],
      )!,
      hash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hash'],
      )!,
    );
  }

  @override
  $CardFieldHashesTable createAlias(String alias) {
    return $CardFieldHashesTable(attachedDatabase, alias);
  }
}

class CardFieldHashRow extends DataClass
    implements Insertable<CardFieldHashRow> {
  final int cardId;
  final String field;
  final String hash;
  const CardFieldHashRow({
    required this.cardId,
    required this.field,
    required this.hash,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['card_id'] = Variable<int>(cardId);
    map['field'] = Variable<String>(field);
    map['hash'] = Variable<String>(hash);
    return map;
  }

  CardFieldHashesCompanion toCompanion(bool nullToAbsent) {
    return CardFieldHashesCompanion(
      cardId: Value(cardId),
      field: Value(field),
      hash: Value(hash),
    );
  }

  factory CardFieldHashRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CardFieldHashRow(
      cardId: serializer.fromJson<int>(json['cardId']),
      field: serializer.fromJson<String>(json['field']),
      hash: serializer.fromJson<String>(json['hash']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'cardId': serializer.toJson<int>(cardId),
      'field': serializer.toJson<String>(field),
      'hash': serializer.toJson<String>(hash),
    };
  }

  CardFieldHashRow copyWith({int? cardId, String? field, String? hash}) =>
      CardFieldHashRow(
        cardId: cardId ?? this.cardId,
        field: field ?? this.field,
        hash: hash ?? this.hash,
      );
  CardFieldHashRow copyWithCompanion(CardFieldHashesCompanion data) {
    return CardFieldHashRow(
      cardId: data.cardId.present ? data.cardId.value : this.cardId,
      field: data.field.present ? data.field.value : this.field,
      hash: data.hash.present ? data.hash.value : this.hash,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CardFieldHashRow(')
          ..write('cardId: $cardId, ')
          ..write('field: $field, ')
          ..write('hash: $hash')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(cardId, field, hash);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CardFieldHashRow &&
          other.cardId == this.cardId &&
          other.field == this.field &&
          other.hash == this.hash);
}

class CardFieldHashesCompanion extends UpdateCompanion<CardFieldHashRow> {
  final Value<int> cardId;
  final Value<String> field;
  final Value<String> hash;
  final Value<int> rowid;
  const CardFieldHashesCompanion({
    this.cardId = const Value.absent(),
    this.field = const Value.absent(),
    this.hash = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CardFieldHashesCompanion.insert({
    required int cardId,
    required String field,
    required String hash,
    this.rowid = const Value.absent(),
  }) : cardId = Value(cardId),
       field = Value(field),
       hash = Value(hash);
  static Insertable<CardFieldHashRow> custom({
    Expression<int>? cardId,
    Expression<String>? field,
    Expression<String>? hash,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (cardId != null) 'card_id': cardId,
      if (field != null) 'field': field,
      if (hash != null) 'hash': hash,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CardFieldHashesCompanion copyWith({
    Value<int>? cardId,
    Value<String>? field,
    Value<String>? hash,
    Value<int>? rowid,
  }) {
    return CardFieldHashesCompanion(
      cardId: cardId ?? this.cardId,
      field: field ?? this.field,
      hash: hash ?? this.hash,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (cardId.present) {
      map['card_id'] = Variable<int>(cardId.value);
    }
    if (field.present) {
      map['field'] = Variable<String>(field.value);
    }
    if (hash.present) {
      map['hash'] = Variable<String>(hash.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CardFieldHashesCompanion(')
          ..write('cardId: $cardId, ')
          ..write('field: $field, ')
          ..write('hash: $hash, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$SearchDatabase extends GeneratedDatabase {
  _$SearchDatabase(QueryExecutor e) : super(e);
  $SearchDatabaseManager get managers => $SearchDatabaseManager(this);
  late final $CardsTable cards = $CardsTable(this);
  late final $CardVectorsTable cardVectors = $CardVectorsTable(this);
  late final $CardFieldHashesTable cardFieldHashes = $CardFieldHashesTable(
    this,
  );
  late final Index idxCardsNameLower = Index(
    'idx_cards_name_lower',
    'CREATE INDEX idx_cards_name_lower ON cards (name_lower)',
  );
  late final Index idxCardVectorsCard = Index(
    'idx_card_vectors_card',
    'CREATE INDEX idx_card_vectors_card ON card_vectors (card_id)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    cards,
    cardVectors,
    cardFieldHashes,
    idxCardsNameLower,
    idxCardVectorsCard,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'cards',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('card_vectors', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'cards',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('card_field_hashes', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$CardsTableCreateCompanionBuilder =
    CardsCompanion Function({
      Value<int> id,
      required String imagePath,
      Value<String> name,
      Value<String> nameLower,
    });
typedef $$CardsTableUpdateCompanionBuilder =
    CardsCompanion Function({
      Value<int> id,
      Value<String> imagePath,
      Value<String> name,
      Value<String> nameLower,
    });

final class $$CardsTableReferences
    extends BaseReferences<_$SearchDatabase, $CardsTable, CardRow> {
  $$CardsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$CardVectorsTable, List<CardVectorRow>>
  _cardVectorsRefsTable(_$SearchDatabase db) => MultiTypedResultKey.fromTable(
    db.cardVectors,
    aliasName: 'cards__id__card_vectors__card_id',
  );

  $$CardVectorsTableProcessedTableManager get cardVectorsRefs {
    final manager = $$CardVectorsTableTableManager(
      $_db,
      $_db.cardVectors,
    ).filter((f) => f.cardId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_cardVectorsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$CardFieldHashesTable, List<CardFieldHashRow>>
  _cardFieldHashesRefsTable(_$SearchDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.cardFieldHashes,
        aliasName: 'cards__id__card_field_hashes__card_id',
      );

  $$CardFieldHashesTableProcessedTableManager get cardFieldHashesRefs {
    final manager = $$CardFieldHashesTableTableManager(
      $_db,
      $_db.cardFieldHashes,
    ).filter((f) => f.cardId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _cardFieldHashesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CardsTableFilterComposer
    extends Composer<_$SearchDatabase, $CardsTable> {
  $$CardsTableFilterComposer({
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

  ColumnFilters<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nameLower => $composableBuilder(
    column: $table.nameLower,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> cardVectorsRefs(
    Expression<bool> Function($$CardVectorsTableFilterComposer f) f,
  ) {
    final $$CardVectorsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cardVectors,
      getReferencedColumn: (t) => t.cardId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardVectorsTableFilterComposer(
            $db: $db,
            $table: $db.cardVectors,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> cardFieldHashesRefs(
    Expression<bool> Function($$CardFieldHashesTableFilterComposer f) f,
  ) {
    final $$CardFieldHashesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cardFieldHashes,
      getReferencedColumn: (t) => t.cardId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardFieldHashesTableFilterComposer(
            $db: $db,
            $table: $db.cardFieldHashes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CardsTableOrderingComposer
    extends Composer<_$SearchDatabase, $CardsTable> {
  $$CardsTableOrderingComposer({
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

  ColumnOrderings<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nameLower => $composableBuilder(
    column: $table.nameLower,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CardsTableAnnotationComposer
    extends Composer<_$SearchDatabase, $CardsTable> {
  $$CardsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get imagePath =>
      $composableBuilder(column: $table.imagePath, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get nameLower =>
      $composableBuilder(column: $table.nameLower, builder: (column) => column);

  Expression<T> cardVectorsRefs<T extends Object>(
    Expression<T> Function($$CardVectorsTableAnnotationComposer a) f,
  ) {
    final $$CardVectorsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cardVectors,
      getReferencedColumn: (t) => t.cardId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardVectorsTableAnnotationComposer(
            $db: $db,
            $table: $db.cardVectors,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> cardFieldHashesRefs<T extends Object>(
    Expression<T> Function($$CardFieldHashesTableAnnotationComposer a) f,
  ) {
    final $$CardFieldHashesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cardFieldHashes,
      getReferencedColumn: (t) => t.cardId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardFieldHashesTableAnnotationComposer(
            $db: $db,
            $table: $db.cardFieldHashes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CardsTableTableManager
    extends
        RootTableManager<
          _$SearchDatabase,
          $CardsTable,
          CardRow,
          $$CardsTableFilterComposer,
          $$CardsTableOrderingComposer,
          $$CardsTableAnnotationComposer,
          $$CardsTableCreateCompanionBuilder,
          $$CardsTableUpdateCompanionBuilder,
          (CardRow, $$CardsTableReferences),
          CardRow,
          PrefetchHooks Function({
            bool cardVectorsRefs,
            bool cardFieldHashesRefs,
          })
        > {
  $$CardsTableTableManager(_$SearchDatabase db, $CardsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CardsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CardsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CardsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> imagePath = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> nameLower = const Value.absent(),
              }) => CardsCompanion(
                id: id,
                imagePath: imagePath,
                name: name,
                nameLower: nameLower,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String imagePath,
                Value<String> name = const Value.absent(),
                Value<String> nameLower = const Value.absent(),
              }) => CardsCompanion.insert(
                id: id,
                imagePath: imagePath,
                name: name,
                nameLower: nameLower,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$CardsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({cardVectorsRefs = false, cardFieldHashesRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (cardVectorsRefs) db.cardVectors,
                    if (cardFieldHashesRefs) db.cardFieldHashes,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (cardVectorsRefs)
                        await $_getPrefetchedData<
                          CardRow,
                          $CardsTable,
                          CardVectorRow
                        >(
                          currentTable: table,
                          referencedTable: $$CardsTableReferences
                              ._cardVectorsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CardsTableReferences(
                                db,
                                table,
                                p0,
                              ).cardVectorsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.cardId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (cardFieldHashesRefs)
                        await $_getPrefetchedData<
                          CardRow,
                          $CardsTable,
                          CardFieldHashRow
                        >(
                          currentTable: table,
                          referencedTable: $$CardsTableReferences
                              ._cardFieldHashesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CardsTableReferences(
                                db,
                                table,
                                p0,
                              ).cardFieldHashesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.cardId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$CardsTableProcessedTableManager =
    ProcessedTableManager<
      _$SearchDatabase,
      $CardsTable,
      CardRow,
      $$CardsTableFilterComposer,
      $$CardsTableOrderingComposer,
      $$CardsTableAnnotationComposer,
      $$CardsTableCreateCompanionBuilder,
      $$CardsTableUpdateCompanionBuilder,
      (CardRow, $$CardsTableReferences),
      CardRow,
      PrefetchHooks Function({bool cardVectorsRefs, bool cardFieldHashesRefs})
    >;
typedef $$CardVectorsTableCreateCompanionBuilder =
    CardVectorsCompanion Function({
      Value<int> id,
      required int cardId,
      required String field,
      required int chunkIndex,
      required Uint8List embedding,
    });
typedef $$CardVectorsTableUpdateCompanionBuilder =
    CardVectorsCompanion Function({
      Value<int> id,
      Value<int> cardId,
      Value<String> field,
      Value<int> chunkIndex,
      Value<Uint8List> embedding,
    });

final class $$CardVectorsTableReferences
    extends BaseReferences<_$SearchDatabase, $CardVectorsTable, CardVectorRow> {
  $$CardVectorsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CardsTable _cardIdTable(_$SearchDatabase db) =>
      db.cards.createAlias('card_vectors__card_id__cards__id');

  $$CardsTableProcessedTableManager get cardId {
    final $_column = $_itemColumn<int>('card_id')!;

    final manager = $$CardsTableTableManager(
      $_db,
      $_db.cards,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_cardIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CardVectorsTableFilterComposer
    extends Composer<_$SearchDatabase, $CardVectorsTable> {
  $$CardVectorsTableFilterComposer({
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

  ColumnFilters<String> get field => $composableBuilder(
    column: $table.field,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get chunkIndex => $composableBuilder(
    column: $table.chunkIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get embedding => $composableBuilder(
    column: $table.embedding,
    builder: (column) => ColumnFilters(column),
  );

  $$CardsTableFilterComposer get cardId {
    final $$CardsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardId,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableFilterComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CardVectorsTableOrderingComposer
    extends Composer<_$SearchDatabase, $CardVectorsTable> {
  $$CardVectorsTableOrderingComposer({
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

  ColumnOrderings<String> get field => $composableBuilder(
    column: $table.field,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get chunkIndex => $composableBuilder(
    column: $table.chunkIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get embedding => $composableBuilder(
    column: $table.embedding,
    builder: (column) => ColumnOrderings(column),
  );

  $$CardsTableOrderingComposer get cardId {
    final $$CardsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardId,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableOrderingComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CardVectorsTableAnnotationComposer
    extends Composer<_$SearchDatabase, $CardVectorsTable> {
  $$CardVectorsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get field =>
      $composableBuilder(column: $table.field, builder: (column) => column);

  GeneratedColumn<int> get chunkIndex => $composableBuilder(
    column: $table.chunkIndex,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get embedding =>
      $composableBuilder(column: $table.embedding, builder: (column) => column);

  $$CardsTableAnnotationComposer get cardId {
    final $$CardsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardId,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableAnnotationComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CardVectorsTableTableManager
    extends
        RootTableManager<
          _$SearchDatabase,
          $CardVectorsTable,
          CardVectorRow,
          $$CardVectorsTableFilterComposer,
          $$CardVectorsTableOrderingComposer,
          $$CardVectorsTableAnnotationComposer,
          $$CardVectorsTableCreateCompanionBuilder,
          $$CardVectorsTableUpdateCompanionBuilder,
          (CardVectorRow, $$CardVectorsTableReferences),
          CardVectorRow,
          PrefetchHooks Function({bool cardId})
        > {
  $$CardVectorsTableTableManager(_$SearchDatabase db, $CardVectorsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CardVectorsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CardVectorsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CardVectorsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> cardId = const Value.absent(),
                Value<String> field = const Value.absent(),
                Value<int> chunkIndex = const Value.absent(),
                Value<Uint8List> embedding = const Value.absent(),
              }) => CardVectorsCompanion(
                id: id,
                cardId: cardId,
                field: field,
                chunkIndex: chunkIndex,
                embedding: embedding,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int cardId,
                required String field,
                required int chunkIndex,
                required Uint8List embedding,
              }) => CardVectorsCompanion.insert(
                id: id,
                cardId: cardId,
                field: field,
                chunkIndex: chunkIndex,
                embedding: embedding,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CardVectorsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({cardId = false}) {
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
                    if (cardId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.cardId,
                                referencedTable: $$CardVectorsTableReferences
                                    ._cardIdTable(db),
                                referencedColumn: $$CardVectorsTableReferences
                                    ._cardIdTable(db)
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

typedef $$CardVectorsTableProcessedTableManager =
    ProcessedTableManager<
      _$SearchDatabase,
      $CardVectorsTable,
      CardVectorRow,
      $$CardVectorsTableFilterComposer,
      $$CardVectorsTableOrderingComposer,
      $$CardVectorsTableAnnotationComposer,
      $$CardVectorsTableCreateCompanionBuilder,
      $$CardVectorsTableUpdateCompanionBuilder,
      (CardVectorRow, $$CardVectorsTableReferences),
      CardVectorRow,
      PrefetchHooks Function({bool cardId})
    >;
typedef $$CardFieldHashesTableCreateCompanionBuilder =
    CardFieldHashesCompanion Function({
      required int cardId,
      required String field,
      required String hash,
      Value<int> rowid,
    });
typedef $$CardFieldHashesTableUpdateCompanionBuilder =
    CardFieldHashesCompanion Function({
      Value<int> cardId,
      Value<String> field,
      Value<String> hash,
      Value<int> rowid,
    });

final class $$CardFieldHashesTableReferences
    extends
        BaseReferences<
          _$SearchDatabase,
          $CardFieldHashesTable,
          CardFieldHashRow
        > {
  $$CardFieldHashesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CardsTable _cardIdTable(_$SearchDatabase db) =>
      db.cards.createAlias('card_field_hashes__card_id__cards__id');

  $$CardsTableProcessedTableManager get cardId {
    final $_column = $_itemColumn<int>('card_id')!;

    final manager = $$CardsTableTableManager(
      $_db,
      $_db.cards,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_cardIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CardFieldHashesTableFilterComposer
    extends Composer<_$SearchDatabase, $CardFieldHashesTable> {
  $$CardFieldHashesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get field => $composableBuilder(
    column: $table.field,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hash => $composableBuilder(
    column: $table.hash,
    builder: (column) => ColumnFilters(column),
  );

  $$CardsTableFilterComposer get cardId {
    final $$CardsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardId,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableFilterComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CardFieldHashesTableOrderingComposer
    extends Composer<_$SearchDatabase, $CardFieldHashesTable> {
  $$CardFieldHashesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get field => $composableBuilder(
    column: $table.field,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hash => $composableBuilder(
    column: $table.hash,
    builder: (column) => ColumnOrderings(column),
  );

  $$CardsTableOrderingComposer get cardId {
    final $$CardsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardId,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableOrderingComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CardFieldHashesTableAnnotationComposer
    extends Composer<_$SearchDatabase, $CardFieldHashesTable> {
  $$CardFieldHashesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get field =>
      $composableBuilder(column: $table.field, builder: (column) => column);

  GeneratedColumn<String> get hash =>
      $composableBuilder(column: $table.hash, builder: (column) => column);

  $$CardsTableAnnotationComposer get cardId {
    final $$CardsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardId,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableAnnotationComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CardFieldHashesTableTableManager
    extends
        RootTableManager<
          _$SearchDatabase,
          $CardFieldHashesTable,
          CardFieldHashRow,
          $$CardFieldHashesTableFilterComposer,
          $$CardFieldHashesTableOrderingComposer,
          $$CardFieldHashesTableAnnotationComposer,
          $$CardFieldHashesTableCreateCompanionBuilder,
          $$CardFieldHashesTableUpdateCompanionBuilder,
          (CardFieldHashRow, $$CardFieldHashesTableReferences),
          CardFieldHashRow,
          PrefetchHooks Function({bool cardId})
        > {
  $$CardFieldHashesTableTableManager(
    _$SearchDatabase db,
    $CardFieldHashesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CardFieldHashesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CardFieldHashesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CardFieldHashesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> cardId = const Value.absent(),
                Value<String> field = const Value.absent(),
                Value<String> hash = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CardFieldHashesCompanion(
                cardId: cardId,
                field: field,
                hash: hash,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int cardId,
                required String field,
                required String hash,
                Value<int> rowid = const Value.absent(),
              }) => CardFieldHashesCompanion.insert(
                cardId: cardId,
                field: field,
                hash: hash,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CardFieldHashesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({cardId = false}) {
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
                    if (cardId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.cardId,
                                referencedTable:
                                    $$CardFieldHashesTableReferences
                                        ._cardIdTable(db),
                                referencedColumn:
                                    $$CardFieldHashesTableReferences
                                        ._cardIdTable(db)
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

typedef $$CardFieldHashesTableProcessedTableManager =
    ProcessedTableManager<
      _$SearchDatabase,
      $CardFieldHashesTable,
      CardFieldHashRow,
      $$CardFieldHashesTableFilterComposer,
      $$CardFieldHashesTableOrderingComposer,
      $$CardFieldHashesTableAnnotationComposer,
      $$CardFieldHashesTableCreateCompanionBuilder,
      $$CardFieldHashesTableUpdateCompanionBuilder,
      (CardFieldHashRow, $$CardFieldHashesTableReferences),
      CardFieldHashRow,
      PrefetchHooks Function({bool cardId})
    >;

class $SearchDatabaseManager {
  final _$SearchDatabase _db;
  $SearchDatabaseManager(this._db);
  $$CardsTableTableManager get cards =>
      $$CardsTableTableManager(_db, _db.cards);
  $$CardVectorsTableTableManager get cardVectors =>
      $$CardVectorsTableTableManager(_db, _db.cardVectors);
  $$CardFieldHashesTableTableManager get cardFieldHashes =>
      $$CardFieldHashesTableTableManager(_db, _db.cardFieldHashes);
}
