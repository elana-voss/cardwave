// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_database.dart';

// ignore_for_file: type=lint
class $LibraryCardsTable extends LibraryCards
    with TableInfo<$LibraryCardsTable, LibraryCardRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LibraryCardsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _creatorMeta = const VerificationMeta(
    'creator',
  );
  @override
  late final GeneratedColumn<String> creator = GeneratedColumn<String>(
    'creator',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _creatorLowerMeta = const VerificationMeta(
    'creatorLower',
  );
  @override
  late final GeneratedColumn<String> creatorLower = GeneratedColumn<String>(
    'creator_lower',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _folderMeta = const VerificationMeta('folder');
  @override
  late final GeneratedColumn<String> folder = GeneratedColumn<String>(
    'folder',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('.'),
  );
  static const VerificationMeta _tagsJsonMeta = const VerificationMeta(
    'tagsJson',
  );
  @override
  late final GeneratedColumn<String> tagsJson = GeneratedColumn<String>(
    'tags_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _previewDescriptionMeta =
      const VerificationMeta('previewDescription');
  @override
  late final GeneratedColumn<String> previewDescription =
      GeneratedColumn<String>(
        'preview_description',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant(''),
      );
  static const VerificationMeta _rootIdMeta = const VerificationMeta('rootId');
  @override
  late final GeneratedColumn<String> rootId = GeneratedColumn<String>(
    'root_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parent_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _appCardIdMeta = const VerificationMeta(
    'appCardId',
  );
  @override
  late final GeneratedColumn<String> appCardId = GeneratedColumn<String>(
    'app_card_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _variantNotesMeta = const VerificationMeta(
    'variantNotes',
  );
  @override
  late final GeneratedColumn<String> variantNotes = GeneratedColumn<String>(
    'variant_notes',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _appCardTagsJsonMeta = const VerificationMeta(
    'appCardTagsJson',
  );
  @override
  late final GeneratedColumn<String> appCardTagsJson = GeneratedColumn<String>(
    'app_card_tags_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _isFavoriteMeta = const VerificationMeta(
    'isFavorite',
  );
  @override
  late final GeneratedColumn<bool> isFavorite = GeneratedColumn<bool>(
    'is_favorite',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_favorite" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isArchiveMeta = const VerificationMeta(
    'isArchive',
  );
  @override
  late final GeneratedColumn<bool> isArchive = GeneratedColumn<bool>(
    'is_archive',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_archive" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _pngTimestampImportedMeta =
      const VerificationMeta('pngTimestampImported');
  @override
  late final GeneratedColumn<int> pngTimestampImported = GeneratedColumn<int>(
    'png_timestamp_imported',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _pngTimestampLastSavedMeta =
      const VerificationMeta('pngTimestampLastSaved');
  @override
  late final GeneratedColumn<int> pngTimestampLastSaved = GeneratedColumn<int>(
    'png_timestamp_last_saved',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _timestampLastSavedMeta =
      const VerificationMeta('timestampLastSaved');
  @override
  late final GeneratedColumn<int> timestampLastSaved = GeneratedColumn<int>(
    'timestamp_last_saved',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _timestampLastChattedMeta =
      const VerificationMeta('timestampLastChatted');
  @override
  late final GeneratedColumn<int> timestampLastChatted = GeneratedColumn<int>(
    'timestamp_last_chatted',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _timestampLastChattedDismissedMeta =
      const VerificationMeta('timestampLastChattedDismissed');
  @override
  late final GeneratedColumn<int> timestampLastChattedDismissed =
      GeneratedColumn<int>(
        'timestamp_last_chatted_dismissed',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _tokenCountAllMeta = const VerificationMeta(
    'tokenCountAll',
  );
  @override
  late final GeneratedColumn<int> tokenCountAll = GeneratedColumn<int>(
    'token_count_all',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _mtimeMeta = const VerificationMeta('mtime');
  @override
  late final GeneratedColumn<int> mtime = GeneratedColumn<int>(
    'mtime',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<int> size = GeneratedColumn<int>(
    'size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    imagePath,
    name,
    nameLower,
    creator,
    creatorLower,
    folder,
    tagsJson,
    previewDescription,
    rootId,
    parentId,
    appCardId,
    variantNotes,
    appCardTagsJson,
    isFavorite,
    isArchive,
    pngTimestampImported,
    pngTimestampLastSaved,
    timestampLastSaved,
    timestampLastChatted,
    timestampLastChattedDismissed,
    tokenCountAll,
    mtime,
    size,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'library_cards';
  @override
  VerificationContext validateIntegrity(
    Insertable<LibraryCardRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
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
    if (data.containsKey('creator')) {
      context.handle(
        _creatorMeta,
        creator.isAcceptableOrUnknown(data['creator']!, _creatorMeta),
      );
    }
    if (data.containsKey('creator_lower')) {
      context.handle(
        _creatorLowerMeta,
        creatorLower.isAcceptableOrUnknown(
          data['creator_lower']!,
          _creatorLowerMeta,
        ),
      );
    }
    if (data.containsKey('folder')) {
      context.handle(
        _folderMeta,
        folder.isAcceptableOrUnknown(data['folder']!, _folderMeta),
      );
    }
    if (data.containsKey('tags_json')) {
      context.handle(
        _tagsJsonMeta,
        tagsJson.isAcceptableOrUnknown(data['tags_json']!, _tagsJsonMeta),
      );
    }
    if (data.containsKey('preview_description')) {
      context.handle(
        _previewDescriptionMeta,
        previewDescription.isAcceptableOrUnknown(
          data['preview_description']!,
          _previewDescriptionMeta,
        ),
      );
    }
    if (data.containsKey('root_id')) {
      context.handle(
        _rootIdMeta,
        rootId.isAcceptableOrUnknown(data['root_id']!, _rootIdMeta),
      );
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    }
    if (data.containsKey('app_card_id')) {
      context.handle(
        _appCardIdMeta,
        appCardId.isAcceptableOrUnknown(data['app_card_id']!, _appCardIdMeta),
      );
    }
    if (data.containsKey('variant_notes')) {
      context.handle(
        _variantNotesMeta,
        variantNotes.isAcceptableOrUnknown(
          data['variant_notes']!,
          _variantNotesMeta,
        ),
      );
    }
    if (data.containsKey('app_card_tags_json')) {
      context.handle(
        _appCardTagsJsonMeta,
        appCardTagsJson.isAcceptableOrUnknown(
          data['app_card_tags_json']!,
          _appCardTagsJsonMeta,
        ),
      );
    }
    if (data.containsKey('is_favorite')) {
      context.handle(
        _isFavoriteMeta,
        isFavorite.isAcceptableOrUnknown(data['is_favorite']!, _isFavoriteMeta),
      );
    }
    if (data.containsKey('is_archive')) {
      context.handle(
        _isArchiveMeta,
        isArchive.isAcceptableOrUnknown(data['is_archive']!, _isArchiveMeta),
      );
    }
    if (data.containsKey('png_timestamp_imported')) {
      context.handle(
        _pngTimestampImportedMeta,
        pngTimestampImported.isAcceptableOrUnknown(
          data['png_timestamp_imported']!,
          _pngTimestampImportedMeta,
        ),
      );
    }
    if (data.containsKey('png_timestamp_last_saved')) {
      context.handle(
        _pngTimestampLastSavedMeta,
        pngTimestampLastSaved.isAcceptableOrUnknown(
          data['png_timestamp_last_saved']!,
          _pngTimestampLastSavedMeta,
        ),
      );
    }
    if (data.containsKey('timestamp_last_saved')) {
      context.handle(
        _timestampLastSavedMeta,
        timestampLastSaved.isAcceptableOrUnknown(
          data['timestamp_last_saved']!,
          _timestampLastSavedMeta,
        ),
      );
    }
    if (data.containsKey('timestamp_last_chatted')) {
      context.handle(
        _timestampLastChattedMeta,
        timestampLastChatted.isAcceptableOrUnknown(
          data['timestamp_last_chatted']!,
          _timestampLastChattedMeta,
        ),
      );
    }
    if (data.containsKey('timestamp_last_chatted_dismissed')) {
      context.handle(
        _timestampLastChattedDismissedMeta,
        timestampLastChattedDismissed.isAcceptableOrUnknown(
          data['timestamp_last_chatted_dismissed']!,
          _timestampLastChattedDismissedMeta,
        ),
      );
    }
    if (data.containsKey('token_count_all')) {
      context.handle(
        _tokenCountAllMeta,
        tokenCountAll.isAcceptableOrUnknown(
          data['token_count_all']!,
          _tokenCountAllMeta,
        ),
      );
    }
    if (data.containsKey('mtime')) {
      context.handle(
        _mtimeMeta,
        mtime.isAcceptableOrUnknown(data['mtime']!, _mtimeMeta),
      );
    }
    if (data.containsKey('size')) {
      context.handle(
        _sizeMeta,
        size.isAcceptableOrUnknown(data['size']!, _sizeMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {imagePath};
  @override
  LibraryCardRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LibraryCardRow(
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
      creator: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}creator'],
      )!,
      creatorLower: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}creator_lower'],
      )!,
      folder: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}folder'],
      )!,
      tagsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags_json'],
      )!,
      previewDescription: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preview_description'],
      )!,
      rootId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}root_id'],
      )!,
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_id'],
      )!,
      appCardId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}app_card_id'],
      )!,
      variantNotes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}variant_notes'],
      )!,
      appCardTagsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}app_card_tags_json'],
      )!,
      isFavorite: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_favorite'],
      )!,
      isArchive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_archive'],
      )!,
      pngTimestampImported: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}png_timestamp_imported'],
      )!,
      pngTimestampLastSaved: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}png_timestamp_last_saved'],
      )!,
      timestampLastSaved: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}timestamp_last_saved'],
      ),
      timestampLastChatted: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}timestamp_last_chatted'],
      ),
      timestampLastChattedDismissed: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}timestamp_last_chatted_dismissed'],
      ),
      tokenCountAll: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}token_count_all'],
      )!,
      mtime: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}mtime'],
      )!,
      size: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size'],
      )!,
    );
  }

  @override
  $LibraryCardsTable createAlias(String alias) {
    return $LibraryCardsTable(attachedDatabase, alias);
  }
}

class LibraryCardRow extends DataClass implements Insertable<LibraryCardRow> {
  final String imagePath;
  final String name;
  final String nameLower;
  final String creator;
  final String creatorLower;
  final String folder;
  final String tagsJson;
  final String previewDescription;
  final String rootId;
  final String parentId;
  final String appCardId;
  final String variantNotes;
  final String appCardTagsJson;
  final bool isFavorite;
  final bool isArchive;
  final int pngTimestampImported;
  final int pngTimestampLastSaved;
  final int? timestampLastSaved;
  final int? timestampLastChatted;
  final int? timestampLastChattedDismissed;
  final int tokenCountAll;
  final int mtime;
  final int size;
  const LibraryCardRow({
    required this.imagePath,
    required this.name,
    required this.nameLower,
    required this.creator,
    required this.creatorLower,
    required this.folder,
    required this.tagsJson,
    required this.previewDescription,
    required this.rootId,
    required this.parentId,
    required this.appCardId,
    required this.variantNotes,
    required this.appCardTagsJson,
    required this.isFavorite,
    required this.isArchive,
    required this.pngTimestampImported,
    required this.pngTimestampLastSaved,
    this.timestampLastSaved,
    this.timestampLastChatted,
    this.timestampLastChattedDismissed,
    required this.tokenCountAll,
    required this.mtime,
    required this.size,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['image_path'] = Variable<String>(imagePath);
    map['name'] = Variable<String>(name);
    map['name_lower'] = Variable<String>(nameLower);
    map['creator'] = Variable<String>(creator);
    map['creator_lower'] = Variable<String>(creatorLower);
    map['folder'] = Variable<String>(folder);
    map['tags_json'] = Variable<String>(tagsJson);
    map['preview_description'] = Variable<String>(previewDescription);
    map['root_id'] = Variable<String>(rootId);
    map['parent_id'] = Variable<String>(parentId);
    map['app_card_id'] = Variable<String>(appCardId);
    map['variant_notes'] = Variable<String>(variantNotes);
    map['app_card_tags_json'] = Variable<String>(appCardTagsJson);
    map['is_favorite'] = Variable<bool>(isFavorite);
    map['is_archive'] = Variable<bool>(isArchive);
    map['png_timestamp_imported'] = Variable<int>(pngTimestampImported);
    map['png_timestamp_last_saved'] = Variable<int>(pngTimestampLastSaved);
    if (!nullToAbsent || timestampLastSaved != null) {
      map['timestamp_last_saved'] = Variable<int>(timestampLastSaved);
    }
    if (!nullToAbsent || timestampLastChatted != null) {
      map['timestamp_last_chatted'] = Variable<int>(timestampLastChatted);
    }
    if (!nullToAbsent || timestampLastChattedDismissed != null) {
      map['timestamp_last_chatted_dismissed'] = Variable<int>(
        timestampLastChattedDismissed,
      );
    }
    map['token_count_all'] = Variable<int>(tokenCountAll);
    map['mtime'] = Variable<int>(mtime);
    map['size'] = Variable<int>(size);
    return map;
  }

  LibraryCardsCompanion toCompanion(bool nullToAbsent) {
    return LibraryCardsCompanion(
      imagePath: Value(imagePath),
      name: Value(name),
      nameLower: Value(nameLower),
      creator: Value(creator),
      creatorLower: Value(creatorLower),
      folder: Value(folder),
      tagsJson: Value(tagsJson),
      previewDescription: Value(previewDescription),
      rootId: Value(rootId),
      parentId: Value(parentId),
      appCardId: Value(appCardId),
      variantNotes: Value(variantNotes),
      appCardTagsJson: Value(appCardTagsJson),
      isFavorite: Value(isFavorite),
      isArchive: Value(isArchive),
      pngTimestampImported: Value(pngTimestampImported),
      pngTimestampLastSaved: Value(pngTimestampLastSaved),
      timestampLastSaved: timestampLastSaved == null && nullToAbsent
          ? const Value.absent()
          : Value(timestampLastSaved),
      timestampLastChatted: timestampLastChatted == null && nullToAbsent
          ? const Value.absent()
          : Value(timestampLastChatted),
      timestampLastChattedDismissed:
          timestampLastChattedDismissed == null && nullToAbsent
          ? const Value.absent()
          : Value(timestampLastChattedDismissed),
      tokenCountAll: Value(tokenCountAll),
      mtime: Value(mtime),
      size: Value(size),
    );
  }

  factory LibraryCardRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LibraryCardRow(
      imagePath: serializer.fromJson<String>(json['imagePath']),
      name: serializer.fromJson<String>(json['name']),
      nameLower: serializer.fromJson<String>(json['nameLower']),
      creator: serializer.fromJson<String>(json['creator']),
      creatorLower: serializer.fromJson<String>(json['creatorLower']),
      folder: serializer.fromJson<String>(json['folder']),
      tagsJson: serializer.fromJson<String>(json['tagsJson']),
      previewDescription: serializer.fromJson<String>(
        json['previewDescription'],
      ),
      rootId: serializer.fromJson<String>(json['rootId']),
      parentId: serializer.fromJson<String>(json['parentId']),
      appCardId: serializer.fromJson<String>(json['appCardId']),
      variantNotes: serializer.fromJson<String>(json['variantNotes']),
      appCardTagsJson: serializer.fromJson<String>(json['appCardTagsJson']),
      isFavorite: serializer.fromJson<bool>(json['isFavorite']),
      isArchive: serializer.fromJson<bool>(json['isArchive']),
      pngTimestampImported: serializer.fromJson<int>(
        json['pngTimestampImported'],
      ),
      pngTimestampLastSaved: serializer.fromJson<int>(
        json['pngTimestampLastSaved'],
      ),
      timestampLastSaved: serializer.fromJson<int?>(json['timestampLastSaved']),
      timestampLastChatted: serializer.fromJson<int?>(
        json['timestampLastChatted'],
      ),
      timestampLastChattedDismissed: serializer.fromJson<int?>(
        json['timestampLastChattedDismissed'],
      ),
      tokenCountAll: serializer.fromJson<int>(json['tokenCountAll']),
      mtime: serializer.fromJson<int>(json['mtime']),
      size: serializer.fromJson<int>(json['size']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'imagePath': serializer.toJson<String>(imagePath),
      'name': serializer.toJson<String>(name),
      'nameLower': serializer.toJson<String>(nameLower),
      'creator': serializer.toJson<String>(creator),
      'creatorLower': serializer.toJson<String>(creatorLower),
      'folder': serializer.toJson<String>(folder),
      'tagsJson': serializer.toJson<String>(tagsJson),
      'previewDescription': serializer.toJson<String>(previewDescription),
      'rootId': serializer.toJson<String>(rootId),
      'parentId': serializer.toJson<String>(parentId),
      'appCardId': serializer.toJson<String>(appCardId),
      'variantNotes': serializer.toJson<String>(variantNotes),
      'appCardTagsJson': serializer.toJson<String>(appCardTagsJson),
      'isFavorite': serializer.toJson<bool>(isFavorite),
      'isArchive': serializer.toJson<bool>(isArchive),
      'pngTimestampImported': serializer.toJson<int>(pngTimestampImported),
      'pngTimestampLastSaved': serializer.toJson<int>(pngTimestampLastSaved),
      'timestampLastSaved': serializer.toJson<int?>(timestampLastSaved),
      'timestampLastChatted': serializer.toJson<int?>(timestampLastChatted),
      'timestampLastChattedDismissed': serializer.toJson<int?>(
        timestampLastChattedDismissed,
      ),
      'tokenCountAll': serializer.toJson<int>(tokenCountAll),
      'mtime': serializer.toJson<int>(mtime),
      'size': serializer.toJson<int>(size),
    };
  }

  LibraryCardRow copyWith({
    String? imagePath,
    String? name,
    String? nameLower,
    String? creator,
    String? creatorLower,
    String? folder,
    String? tagsJson,
    String? previewDescription,
    String? rootId,
    String? parentId,
    String? appCardId,
    String? variantNotes,
    String? appCardTagsJson,
    bool? isFavorite,
    bool? isArchive,
    int? pngTimestampImported,
    int? pngTimestampLastSaved,
    Value<int?> timestampLastSaved = const Value.absent(),
    Value<int?> timestampLastChatted = const Value.absent(),
    Value<int?> timestampLastChattedDismissed = const Value.absent(),
    int? tokenCountAll,
    int? mtime,
    int? size,
  }) => LibraryCardRow(
    imagePath: imagePath ?? this.imagePath,
    name: name ?? this.name,
    nameLower: nameLower ?? this.nameLower,
    creator: creator ?? this.creator,
    creatorLower: creatorLower ?? this.creatorLower,
    folder: folder ?? this.folder,
    tagsJson: tagsJson ?? this.tagsJson,
    previewDescription: previewDescription ?? this.previewDescription,
    rootId: rootId ?? this.rootId,
    parentId: parentId ?? this.parentId,
    appCardId: appCardId ?? this.appCardId,
    variantNotes: variantNotes ?? this.variantNotes,
    appCardTagsJson: appCardTagsJson ?? this.appCardTagsJson,
    isFavorite: isFavorite ?? this.isFavorite,
    isArchive: isArchive ?? this.isArchive,
    pngTimestampImported: pngTimestampImported ?? this.pngTimestampImported,
    pngTimestampLastSaved: pngTimestampLastSaved ?? this.pngTimestampLastSaved,
    timestampLastSaved: timestampLastSaved.present
        ? timestampLastSaved.value
        : this.timestampLastSaved,
    timestampLastChatted: timestampLastChatted.present
        ? timestampLastChatted.value
        : this.timestampLastChatted,
    timestampLastChattedDismissed: timestampLastChattedDismissed.present
        ? timestampLastChattedDismissed.value
        : this.timestampLastChattedDismissed,
    tokenCountAll: tokenCountAll ?? this.tokenCountAll,
    mtime: mtime ?? this.mtime,
    size: size ?? this.size,
  );
  LibraryCardRow copyWithCompanion(LibraryCardsCompanion data) {
    return LibraryCardRow(
      imagePath: data.imagePath.present ? data.imagePath.value : this.imagePath,
      name: data.name.present ? data.name.value : this.name,
      nameLower: data.nameLower.present ? data.nameLower.value : this.nameLower,
      creator: data.creator.present ? data.creator.value : this.creator,
      creatorLower: data.creatorLower.present
          ? data.creatorLower.value
          : this.creatorLower,
      folder: data.folder.present ? data.folder.value : this.folder,
      tagsJson: data.tagsJson.present ? data.tagsJson.value : this.tagsJson,
      previewDescription: data.previewDescription.present
          ? data.previewDescription.value
          : this.previewDescription,
      rootId: data.rootId.present ? data.rootId.value : this.rootId,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      appCardId: data.appCardId.present ? data.appCardId.value : this.appCardId,
      variantNotes: data.variantNotes.present
          ? data.variantNotes.value
          : this.variantNotes,
      appCardTagsJson: data.appCardTagsJson.present
          ? data.appCardTagsJson.value
          : this.appCardTagsJson,
      isFavorite: data.isFavorite.present
          ? data.isFavorite.value
          : this.isFavorite,
      isArchive: data.isArchive.present ? data.isArchive.value : this.isArchive,
      pngTimestampImported: data.pngTimestampImported.present
          ? data.pngTimestampImported.value
          : this.pngTimestampImported,
      pngTimestampLastSaved: data.pngTimestampLastSaved.present
          ? data.pngTimestampLastSaved.value
          : this.pngTimestampLastSaved,
      timestampLastSaved: data.timestampLastSaved.present
          ? data.timestampLastSaved.value
          : this.timestampLastSaved,
      timestampLastChatted: data.timestampLastChatted.present
          ? data.timestampLastChatted.value
          : this.timestampLastChatted,
      timestampLastChattedDismissed: data.timestampLastChattedDismissed.present
          ? data.timestampLastChattedDismissed.value
          : this.timestampLastChattedDismissed,
      tokenCountAll: data.tokenCountAll.present
          ? data.tokenCountAll.value
          : this.tokenCountAll,
      mtime: data.mtime.present ? data.mtime.value : this.mtime,
      size: data.size.present ? data.size.value : this.size,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LibraryCardRow(')
          ..write('imagePath: $imagePath, ')
          ..write('name: $name, ')
          ..write('nameLower: $nameLower, ')
          ..write('creator: $creator, ')
          ..write('creatorLower: $creatorLower, ')
          ..write('folder: $folder, ')
          ..write('tagsJson: $tagsJson, ')
          ..write('previewDescription: $previewDescription, ')
          ..write('rootId: $rootId, ')
          ..write('parentId: $parentId, ')
          ..write('appCardId: $appCardId, ')
          ..write('variantNotes: $variantNotes, ')
          ..write('appCardTagsJson: $appCardTagsJson, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('isArchive: $isArchive, ')
          ..write('pngTimestampImported: $pngTimestampImported, ')
          ..write('pngTimestampLastSaved: $pngTimestampLastSaved, ')
          ..write('timestampLastSaved: $timestampLastSaved, ')
          ..write('timestampLastChatted: $timestampLastChatted, ')
          ..write(
            'timestampLastChattedDismissed: $timestampLastChattedDismissed, ',
          )
          ..write('tokenCountAll: $tokenCountAll, ')
          ..write('mtime: $mtime, ')
          ..write('size: $size')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    imagePath,
    name,
    nameLower,
    creator,
    creatorLower,
    folder,
    tagsJson,
    previewDescription,
    rootId,
    parentId,
    appCardId,
    variantNotes,
    appCardTagsJson,
    isFavorite,
    isArchive,
    pngTimestampImported,
    pngTimestampLastSaved,
    timestampLastSaved,
    timestampLastChatted,
    timestampLastChattedDismissed,
    tokenCountAll,
    mtime,
    size,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LibraryCardRow &&
          other.imagePath == this.imagePath &&
          other.name == this.name &&
          other.nameLower == this.nameLower &&
          other.creator == this.creator &&
          other.creatorLower == this.creatorLower &&
          other.folder == this.folder &&
          other.tagsJson == this.tagsJson &&
          other.previewDescription == this.previewDescription &&
          other.rootId == this.rootId &&
          other.parentId == this.parentId &&
          other.appCardId == this.appCardId &&
          other.variantNotes == this.variantNotes &&
          other.appCardTagsJson == this.appCardTagsJson &&
          other.isFavorite == this.isFavorite &&
          other.isArchive == this.isArchive &&
          other.pngTimestampImported == this.pngTimestampImported &&
          other.pngTimestampLastSaved == this.pngTimestampLastSaved &&
          other.timestampLastSaved == this.timestampLastSaved &&
          other.timestampLastChatted == this.timestampLastChatted &&
          other.timestampLastChattedDismissed ==
              this.timestampLastChattedDismissed &&
          other.tokenCountAll == this.tokenCountAll &&
          other.mtime == this.mtime &&
          other.size == this.size);
}

class LibraryCardsCompanion extends UpdateCompanion<LibraryCardRow> {
  final Value<String> imagePath;
  final Value<String> name;
  final Value<String> nameLower;
  final Value<String> creator;
  final Value<String> creatorLower;
  final Value<String> folder;
  final Value<String> tagsJson;
  final Value<String> previewDescription;
  final Value<String> rootId;
  final Value<String> parentId;
  final Value<String> appCardId;
  final Value<String> variantNotes;
  final Value<String> appCardTagsJson;
  final Value<bool> isFavorite;
  final Value<bool> isArchive;
  final Value<int> pngTimestampImported;
  final Value<int> pngTimestampLastSaved;
  final Value<int?> timestampLastSaved;
  final Value<int?> timestampLastChatted;
  final Value<int?> timestampLastChattedDismissed;
  final Value<int> tokenCountAll;
  final Value<int> mtime;
  final Value<int> size;
  final Value<int> rowid;
  const LibraryCardsCompanion({
    this.imagePath = const Value.absent(),
    this.name = const Value.absent(),
    this.nameLower = const Value.absent(),
    this.creator = const Value.absent(),
    this.creatorLower = const Value.absent(),
    this.folder = const Value.absent(),
    this.tagsJson = const Value.absent(),
    this.previewDescription = const Value.absent(),
    this.rootId = const Value.absent(),
    this.parentId = const Value.absent(),
    this.appCardId = const Value.absent(),
    this.variantNotes = const Value.absent(),
    this.appCardTagsJson = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.isArchive = const Value.absent(),
    this.pngTimestampImported = const Value.absent(),
    this.pngTimestampLastSaved = const Value.absent(),
    this.timestampLastSaved = const Value.absent(),
    this.timestampLastChatted = const Value.absent(),
    this.timestampLastChattedDismissed = const Value.absent(),
    this.tokenCountAll = const Value.absent(),
    this.mtime = const Value.absent(),
    this.size = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LibraryCardsCompanion.insert({
    required String imagePath,
    this.name = const Value.absent(),
    this.nameLower = const Value.absent(),
    this.creator = const Value.absent(),
    this.creatorLower = const Value.absent(),
    this.folder = const Value.absent(),
    this.tagsJson = const Value.absent(),
    this.previewDescription = const Value.absent(),
    this.rootId = const Value.absent(),
    this.parentId = const Value.absent(),
    this.appCardId = const Value.absent(),
    this.variantNotes = const Value.absent(),
    this.appCardTagsJson = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.isArchive = const Value.absent(),
    this.pngTimestampImported = const Value.absent(),
    this.pngTimestampLastSaved = const Value.absent(),
    this.timestampLastSaved = const Value.absent(),
    this.timestampLastChatted = const Value.absent(),
    this.timestampLastChattedDismissed = const Value.absent(),
    this.tokenCountAll = const Value.absent(),
    this.mtime = const Value.absent(),
    this.size = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : imagePath = Value(imagePath);
  static Insertable<LibraryCardRow> custom({
    Expression<String>? imagePath,
    Expression<String>? name,
    Expression<String>? nameLower,
    Expression<String>? creator,
    Expression<String>? creatorLower,
    Expression<String>? folder,
    Expression<String>? tagsJson,
    Expression<String>? previewDescription,
    Expression<String>? rootId,
    Expression<String>? parentId,
    Expression<String>? appCardId,
    Expression<String>? variantNotes,
    Expression<String>? appCardTagsJson,
    Expression<bool>? isFavorite,
    Expression<bool>? isArchive,
    Expression<int>? pngTimestampImported,
    Expression<int>? pngTimestampLastSaved,
    Expression<int>? timestampLastSaved,
    Expression<int>? timestampLastChatted,
    Expression<int>? timestampLastChattedDismissed,
    Expression<int>? tokenCountAll,
    Expression<int>? mtime,
    Expression<int>? size,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (imagePath != null) 'image_path': imagePath,
      if (name != null) 'name': name,
      if (nameLower != null) 'name_lower': nameLower,
      if (creator != null) 'creator': creator,
      if (creatorLower != null) 'creator_lower': creatorLower,
      if (folder != null) 'folder': folder,
      if (tagsJson != null) 'tags_json': tagsJson,
      if (previewDescription != null) 'preview_description': previewDescription,
      if (rootId != null) 'root_id': rootId,
      if (parentId != null) 'parent_id': parentId,
      if (appCardId != null) 'app_card_id': appCardId,
      if (variantNotes != null) 'variant_notes': variantNotes,
      if (appCardTagsJson != null) 'app_card_tags_json': appCardTagsJson,
      if (isFavorite != null) 'is_favorite': isFavorite,
      if (isArchive != null) 'is_archive': isArchive,
      if (pngTimestampImported != null)
        'png_timestamp_imported': pngTimestampImported,
      if (pngTimestampLastSaved != null)
        'png_timestamp_last_saved': pngTimestampLastSaved,
      if (timestampLastSaved != null)
        'timestamp_last_saved': timestampLastSaved,
      if (timestampLastChatted != null)
        'timestamp_last_chatted': timestampLastChatted,
      if (timestampLastChattedDismissed != null)
        'timestamp_last_chatted_dismissed': timestampLastChattedDismissed,
      if (tokenCountAll != null) 'token_count_all': tokenCountAll,
      if (mtime != null) 'mtime': mtime,
      if (size != null) 'size': size,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LibraryCardsCompanion copyWith({
    Value<String>? imagePath,
    Value<String>? name,
    Value<String>? nameLower,
    Value<String>? creator,
    Value<String>? creatorLower,
    Value<String>? folder,
    Value<String>? tagsJson,
    Value<String>? previewDescription,
    Value<String>? rootId,
    Value<String>? parentId,
    Value<String>? appCardId,
    Value<String>? variantNotes,
    Value<String>? appCardTagsJson,
    Value<bool>? isFavorite,
    Value<bool>? isArchive,
    Value<int>? pngTimestampImported,
    Value<int>? pngTimestampLastSaved,
    Value<int?>? timestampLastSaved,
    Value<int?>? timestampLastChatted,
    Value<int?>? timestampLastChattedDismissed,
    Value<int>? tokenCountAll,
    Value<int>? mtime,
    Value<int>? size,
    Value<int>? rowid,
  }) {
    return LibraryCardsCompanion(
      imagePath: imagePath ?? this.imagePath,
      name: name ?? this.name,
      nameLower: nameLower ?? this.nameLower,
      creator: creator ?? this.creator,
      creatorLower: creatorLower ?? this.creatorLower,
      folder: folder ?? this.folder,
      tagsJson: tagsJson ?? this.tagsJson,
      previewDescription: previewDescription ?? this.previewDescription,
      rootId: rootId ?? this.rootId,
      parentId: parentId ?? this.parentId,
      appCardId: appCardId ?? this.appCardId,
      variantNotes: variantNotes ?? this.variantNotes,
      appCardTagsJson: appCardTagsJson ?? this.appCardTagsJson,
      isFavorite: isFavorite ?? this.isFavorite,
      isArchive: isArchive ?? this.isArchive,
      pngTimestampImported: pngTimestampImported ?? this.pngTimestampImported,
      pngTimestampLastSaved:
          pngTimestampLastSaved ?? this.pngTimestampLastSaved,
      timestampLastSaved: timestampLastSaved ?? this.timestampLastSaved,
      timestampLastChatted: timestampLastChatted ?? this.timestampLastChatted,
      timestampLastChattedDismissed:
          timestampLastChattedDismissed ?? this.timestampLastChattedDismissed,
      tokenCountAll: tokenCountAll ?? this.tokenCountAll,
      mtime: mtime ?? this.mtime,
      size: size ?? this.size,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (imagePath.present) {
      map['image_path'] = Variable<String>(imagePath.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (nameLower.present) {
      map['name_lower'] = Variable<String>(nameLower.value);
    }
    if (creator.present) {
      map['creator'] = Variable<String>(creator.value);
    }
    if (creatorLower.present) {
      map['creator_lower'] = Variable<String>(creatorLower.value);
    }
    if (folder.present) {
      map['folder'] = Variable<String>(folder.value);
    }
    if (tagsJson.present) {
      map['tags_json'] = Variable<String>(tagsJson.value);
    }
    if (previewDescription.present) {
      map['preview_description'] = Variable<String>(previewDescription.value);
    }
    if (rootId.present) {
      map['root_id'] = Variable<String>(rootId.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (appCardId.present) {
      map['app_card_id'] = Variable<String>(appCardId.value);
    }
    if (variantNotes.present) {
      map['variant_notes'] = Variable<String>(variantNotes.value);
    }
    if (appCardTagsJson.present) {
      map['app_card_tags_json'] = Variable<String>(appCardTagsJson.value);
    }
    if (isFavorite.present) {
      map['is_favorite'] = Variable<bool>(isFavorite.value);
    }
    if (isArchive.present) {
      map['is_archive'] = Variable<bool>(isArchive.value);
    }
    if (pngTimestampImported.present) {
      map['png_timestamp_imported'] = Variable<int>(pngTimestampImported.value);
    }
    if (pngTimestampLastSaved.present) {
      map['png_timestamp_last_saved'] = Variable<int>(
        pngTimestampLastSaved.value,
      );
    }
    if (timestampLastSaved.present) {
      map['timestamp_last_saved'] = Variable<int>(timestampLastSaved.value);
    }
    if (timestampLastChatted.present) {
      map['timestamp_last_chatted'] = Variable<int>(timestampLastChatted.value);
    }
    if (timestampLastChattedDismissed.present) {
      map['timestamp_last_chatted_dismissed'] = Variable<int>(
        timestampLastChattedDismissed.value,
      );
    }
    if (tokenCountAll.present) {
      map['token_count_all'] = Variable<int>(tokenCountAll.value);
    }
    if (mtime.present) {
      map['mtime'] = Variable<int>(mtime.value);
    }
    if (size.present) {
      map['size'] = Variable<int>(size.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LibraryCardsCompanion(')
          ..write('imagePath: $imagePath, ')
          ..write('name: $name, ')
          ..write('nameLower: $nameLower, ')
          ..write('creator: $creator, ')
          ..write('creatorLower: $creatorLower, ')
          ..write('folder: $folder, ')
          ..write('tagsJson: $tagsJson, ')
          ..write('previewDescription: $previewDescription, ')
          ..write('rootId: $rootId, ')
          ..write('parentId: $parentId, ')
          ..write('appCardId: $appCardId, ')
          ..write('variantNotes: $variantNotes, ')
          ..write('appCardTagsJson: $appCardTagsJson, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('isArchive: $isArchive, ')
          ..write('pngTimestampImported: $pngTimestampImported, ')
          ..write('pngTimestampLastSaved: $pngTimestampLastSaved, ')
          ..write('timestampLastSaved: $timestampLastSaved, ')
          ..write('timestampLastChatted: $timestampLastChatted, ')
          ..write(
            'timestampLastChattedDismissed: $timestampLastChattedDismissed, ',
          )
          ..write('tokenCountAll: $tokenCountAll, ')
          ..write('mtime: $mtime, ')
          ..write('size: $size, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$LibraryDatabase extends GeneratedDatabase {
  _$LibraryDatabase(QueryExecutor e) : super(e);
  $LibraryDatabaseManager get managers => $LibraryDatabaseManager(this);
  late final $LibraryCardsTable libraryCards = $LibraryCardsTable(this);
  late final Index idxLibraryCardsRoot = Index(
    'idx_library_cards_root',
    'CREATE INDEX idx_library_cards_root ON library_cards (root_id)',
  );
  late final Index idxLibraryCardsFolder = Index(
    'idx_library_cards_folder',
    'CREATE INDEX idx_library_cards_folder ON library_cards (folder)',
  );
  late final Index idxLibraryCardsCreator = Index(
    'idx_library_cards_creator',
    'CREATE INDEX idx_library_cards_creator ON library_cards (creator_lower)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    libraryCards,
    idxLibraryCardsRoot,
    idxLibraryCardsFolder,
    idxLibraryCardsCreator,
  ];
}

typedef $$LibraryCardsTableCreateCompanionBuilder =
    LibraryCardsCompanion Function({
      required String imagePath,
      Value<String> name,
      Value<String> nameLower,
      Value<String> creator,
      Value<String> creatorLower,
      Value<String> folder,
      Value<String> tagsJson,
      Value<String> previewDescription,
      Value<String> rootId,
      Value<String> parentId,
      Value<String> appCardId,
      Value<String> variantNotes,
      Value<String> appCardTagsJson,
      Value<bool> isFavorite,
      Value<bool> isArchive,
      Value<int> pngTimestampImported,
      Value<int> pngTimestampLastSaved,
      Value<int?> timestampLastSaved,
      Value<int?> timestampLastChatted,
      Value<int?> timestampLastChattedDismissed,
      Value<int> tokenCountAll,
      Value<int> mtime,
      Value<int> size,
      Value<int> rowid,
    });
typedef $$LibraryCardsTableUpdateCompanionBuilder =
    LibraryCardsCompanion Function({
      Value<String> imagePath,
      Value<String> name,
      Value<String> nameLower,
      Value<String> creator,
      Value<String> creatorLower,
      Value<String> folder,
      Value<String> tagsJson,
      Value<String> previewDescription,
      Value<String> rootId,
      Value<String> parentId,
      Value<String> appCardId,
      Value<String> variantNotes,
      Value<String> appCardTagsJson,
      Value<bool> isFavorite,
      Value<bool> isArchive,
      Value<int> pngTimestampImported,
      Value<int> pngTimestampLastSaved,
      Value<int?> timestampLastSaved,
      Value<int?> timestampLastChatted,
      Value<int?> timestampLastChattedDismissed,
      Value<int> tokenCountAll,
      Value<int> mtime,
      Value<int> size,
      Value<int> rowid,
    });

class $$LibraryCardsTableFilterComposer
    extends Composer<_$LibraryDatabase, $LibraryCardsTable> {
  $$LibraryCardsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
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

  ColumnFilters<String> get creator => $composableBuilder(
    column: $table.creator,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get creatorLower => $composableBuilder(
    column: $table.creatorLower,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get folder => $composableBuilder(
    column: $table.folder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tagsJson => $composableBuilder(
    column: $table.tagsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get previewDescription => $composableBuilder(
    column: $table.previewDescription,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rootId => $composableBuilder(
    column: $table.rootId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get appCardId => $composableBuilder(
    column: $table.appCardId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get variantNotes => $composableBuilder(
    column: $table.variantNotes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get appCardTagsJson => $composableBuilder(
    column: $table.appCardTagsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isArchive => $composableBuilder(
    column: $table.isArchive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pngTimestampImported => $composableBuilder(
    column: $table.pngTimestampImported,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pngTimestampLastSaved => $composableBuilder(
    column: $table.pngTimestampLastSaved,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timestampLastSaved => $composableBuilder(
    column: $table.timestampLastSaved,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timestampLastChatted => $composableBuilder(
    column: $table.timestampLastChatted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timestampLastChattedDismissed => $composableBuilder(
    column: $table.timestampLastChattedDismissed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tokenCountAll => $composableBuilder(
    column: $table.tokenCountAll,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get mtime => $composableBuilder(
    column: $table.mtime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LibraryCardsTableOrderingComposer
    extends Composer<_$LibraryDatabase, $LibraryCardsTable> {
  $$LibraryCardsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
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

  ColumnOrderings<String> get creator => $composableBuilder(
    column: $table.creator,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get creatorLower => $composableBuilder(
    column: $table.creatorLower,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get folder => $composableBuilder(
    column: $table.folder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tagsJson => $composableBuilder(
    column: $table.tagsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get previewDescription => $composableBuilder(
    column: $table.previewDescription,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rootId => $composableBuilder(
    column: $table.rootId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get appCardId => $composableBuilder(
    column: $table.appCardId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get variantNotes => $composableBuilder(
    column: $table.variantNotes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get appCardTagsJson => $composableBuilder(
    column: $table.appCardTagsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isArchive => $composableBuilder(
    column: $table.isArchive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pngTimestampImported => $composableBuilder(
    column: $table.pngTimestampImported,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pngTimestampLastSaved => $composableBuilder(
    column: $table.pngTimestampLastSaved,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timestampLastSaved => $composableBuilder(
    column: $table.timestampLastSaved,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timestampLastChatted => $composableBuilder(
    column: $table.timestampLastChatted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timestampLastChattedDismissed => $composableBuilder(
    column: $table.timestampLastChattedDismissed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tokenCountAll => $composableBuilder(
    column: $table.tokenCountAll,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get mtime => $composableBuilder(
    column: $table.mtime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LibraryCardsTableAnnotationComposer
    extends Composer<_$LibraryDatabase, $LibraryCardsTable> {
  $$LibraryCardsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get imagePath =>
      $composableBuilder(column: $table.imagePath, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get nameLower =>
      $composableBuilder(column: $table.nameLower, builder: (column) => column);

  GeneratedColumn<String> get creator =>
      $composableBuilder(column: $table.creator, builder: (column) => column);

  GeneratedColumn<String> get creatorLower => $composableBuilder(
    column: $table.creatorLower,
    builder: (column) => column,
  );

  GeneratedColumn<String> get folder =>
      $composableBuilder(column: $table.folder, builder: (column) => column);

  GeneratedColumn<String> get tagsJson =>
      $composableBuilder(column: $table.tagsJson, builder: (column) => column);

  GeneratedColumn<String> get previewDescription => $composableBuilder(
    column: $table.previewDescription,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rootId =>
      $composableBuilder(column: $table.rootId, builder: (column) => column);

  GeneratedColumn<String> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<String> get appCardId =>
      $composableBuilder(column: $table.appCardId, builder: (column) => column);

  GeneratedColumn<String> get variantNotes => $composableBuilder(
    column: $table.variantNotes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get appCardTagsJson => $composableBuilder(
    column: $table.appCardTagsJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isArchive =>
      $composableBuilder(column: $table.isArchive, builder: (column) => column);

  GeneratedColumn<int> get pngTimestampImported => $composableBuilder(
    column: $table.pngTimestampImported,
    builder: (column) => column,
  );

  GeneratedColumn<int> get pngTimestampLastSaved => $composableBuilder(
    column: $table.pngTimestampLastSaved,
    builder: (column) => column,
  );

  GeneratedColumn<int> get timestampLastSaved => $composableBuilder(
    column: $table.timestampLastSaved,
    builder: (column) => column,
  );

  GeneratedColumn<int> get timestampLastChatted => $composableBuilder(
    column: $table.timestampLastChatted,
    builder: (column) => column,
  );

  GeneratedColumn<int> get timestampLastChattedDismissed => $composableBuilder(
    column: $table.timestampLastChattedDismissed,
    builder: (column) => column,
  );

  GeneratedColumn<int> get tokenCountAll => $composableBuilder(
    column: $table.tokenCountAll,
    builder: (column) => column,
  );

  GeneratedColumn<int> get mtime =>
      $composableBuilder(column: $table.mtime, builder: (column) => column);

  GeneratedColumn<int> get size =>
      $composableBuilder(column: $table.size, builder: (column) => column);
}

class $$LibraryCardsTableTableManager
    extends
        RootTableManager<
          _$LibraryDatabase,
          $LibraryCardsTable,
          LibraryCardRow,
          $$LibraryCardsTableFilterComposer,
          $$LibraryCardsTableOrderingComposer,
          $$LibraryCardsTableAnnotationComposer,
          $$LibraryCardsTableCreateCompanionBuilder,
          $$LibraryCardsTableUpdateCompanionBuilder,
          (
            LibraryCardRow,
            BaseReferences<
              _$LibraryDatabase,
              $LibraryCardsTable,
              LibraryCardRow
            >,
          ),
          LibraryCardRow,
          PrefetchHooks Function()
        > {
  $$LibraryCardsTableTableManager(
    _$LibraryDatabase db,
    $LibraryCardsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LibraryCardsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LibraryCardsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LibraryCardsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> imagePath = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> nameLower = const Value.absent(),
                Value<String> creator = const Value.absent(),
                Value<String> creatorLower = const Value.absent(),
                Value<String> folder = const Value.absent(),
                Value<String> tagsJson = const Value.absent(),
                Value<String> previewDescription = const Value.absent(),
                Value<String> rootId = const Value.absent(),
                Value<String> parentId = const Value.absent(),
                Value<String> appCardId = const Value.absent(),
                Value<String> variantNotes = const Value.absent(),
                Value<String> appCardTagsJson = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<bool> isArchive = const Value.absent(),
                Value<int> pngTimestampImported = const Value.absent(),
                Value<int> pngTimestampLastSaved = const Value.absent(),
                Value<int?> timestampLastSaved = const Value.absent(),
                Value<int?> timestampLastChatted = const Value.absent(),
                Value<int?> timestampLastChattedDismissed =
                    const Value.absent(),
                Value<int> tokenCountAll = const Value.absent(),
                Value<int> mtime = const Value.absent(),
                Value<int> size = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LibraryCardsCompanion(
                imagePath: imagePath,
                name: name,
                nameLower: nameLower,
                creator: creator,
                creatorLower: creatorLower,
                folder: folder,
                tagsJson: tagsJson,
                previewDescription: previewDescription,
                rootId: rootId,
                parentId: parentId,
                appCardId: appCardId,
                variantNotes: variantNotes,
                appCardTagsJson: appCardTagsJson,
                isFavorite: isFavorite,
                isArchive: isArchive,
                pngTimestampImported: pngTimestampImported,
                pngTimestampLastSaved: pngTimestampLastSaved,
                timestampLastSaved: timestampLastSaved,
                timestampLastChatted: timestampLastChatted,
                timestampLastChattedDismissed: timestampLastChattedDismissed,
                tokenCountAll: tokenCountAll,
                mtime: mtime,
                size: size,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String imagePath,
                Value<String> name = const Value.absent(),
                Value<String> nameLower = const Value.absent(),
                Value<String> creator = const Value.absent(),
                Value<String> creatorLower = const Value.absent(),
                Value<String> folder = const Value.absent(),
                Value<String> tagsJson = const Value.absent(),
                Value<String> previewDescription = const Value.absent(),
                Value<String> rootId = const Value.absent(),
                Value<String> parentId = const Value.absent(),
                Value<String> appCardId = const Value.absent(),
                Value<String> variantNotes = const Value.absent(),
                Value<String> appCardTagsJson = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<bool> isArchive = const Value.absent(),
                Value<int> pngTimestampImported = const Value.absent(),
                Value<int> pngTimestampLastSaved = const Value.absent(),
                Value<int?> timestampLastSaved = const Value.absent(),
                Value<int?> timestampLastChatted = const Value.absent(),
                Value<int?> timestampLastChattedDismissed =
                    const Value.absent(),
                Value<int> tokenCountAll = const Value.absent(),
                Value<int> mtime = const Value.absent(),
                Value<int> size = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LibraryCardsCompanion.insert(
                imagePath: imagePath,
                name: name,
                nameLower: nameLower,
                creator: creator,
                creatorLower: creatorLower,
                folder: folder,
                tagsJson: tagsJson,
                previewDescription: previewDescription,
                rootId: rootId,
                parentId: parentId,
                appCardId: appCardId,
                variantNotes: variantNotes,
                appCardTagsJson: appCardTagsJson,
                isFavorite: isFavorite,
                isArchive: isArchive,
                pngTimestampImported: pngTimestampImported,
                pngTimestampLastSaved: pngTimestampLastSaved,
                timestampLastSaved: timestampLastSaved,
                timestampLastChatted: timestampLastChatted,
                timestampLastChattedDismissed: timestampLastChattedDismissed,
                tokenCountAll: tokenCountAll,
                mtime: mtime,
                size: size,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LibraryCardsTableProcessedTableManager =
    ProcessedTableManager<
      _$LibraryDatabase,
      $LibraryCardsTable,
      LibraryCardRow,
      $$LibraryCardsTableFilterComposer,
      $$LibraryCardsTableOrderingComposer,
      $$LibraryCardsTableAnnotationComposer,
      $$LibraryCardsTableCreateCompanionBuilder,
      $$LibraryCardsTableUpdateCompanionBuilder,
      (
        LibraryCardRow,
        BaseReferences<_$LibraryDatabase, $LibraryCardsTable, LibraryCardRow>,
      ),
      LibraryCardRow,
      PrefetchHooks Function()
    >;

class $LibraryDatabaseManager {
  final _$LibraryDatabase _db;
  $LibraryDatabaseManager(this._db);
  $$LibraryCardsTableTableManager get libraryCards =>
      $$LibraryCardsTableTableManager(_db, _db.libraryCards);
}
