// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $ItemsTable extends Items with TableInfo<$ItemsTable, Item> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<ItemKind, String> kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<ItemKind>($ItemsTable.$converterkind);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _folderIdMeta = const VerificationMeta(
    'folderId',
  );
  @override
  late final GeneratedColumn<String> folderId = GeneratedColumn<String>(
    'folder_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<SortState, String> sortState =
      GeneratedColumn<String>(
        'sort_state',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: Constant(SortState.pending.name),
      ).withConverter<SortState>($ItemsTable.$convertersortState);
  @override
  late final GeneratedColumnWithTypeConverter<SortedBy, String> sortedBy =
      GeneratedColumn<String>(
        'sorted_by',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: Constant(SortedBy.none.name),
      ).withConverter<SortedBy>($ItemsTable.$convertersortedBy);
  static const VerificationMeta _aiDescriptionMeta = const VerificationMeta(
    'aiDescription',
  );
  @override
  late final GeneratedColumn<String> aiDescription = GeneratedColumn<String>(
    'ai_description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _transcriptMeta = const VerificationMeta(
    'transcript',
  );
  @override
  late final GeneratedColumn<String> transcript = GeneratedColumn<String>(
    'transcript',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverPathMeta = const VerificationMeta(
    'coverPath',
  );
  @override
  late final GeneratedColumn<String> coverPath = GeneratedColumn<String>(
    'cover_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _previewTextMeta = const VerificationMeta(
    'previewText',
  );
  @override
  late final GeneratedColumn<String> previewText = GeneratedColumn<String>(
    'preview_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _previewSiteMeta = const VerificationMeta(
    'previewSite',
  );
  @override
  late final GeneratedColumn<String> previewSite = GeneratedColumn<String>(
    'preview_site',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _previewAuthorMeta = const VerificationMeta(
    'previewAuthor',
  );
  @override
  late final GeneratedColumn<String> previewAuthor = GeneratedColumn<String>(
    'preview_author',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationSecondsMeta = const VerificationMeta(
    'durationSeconds',
  );
  @override
  late final GeneratedColumn<int> durationSeconds = GeneratedColumn<int>(
    'duration_seconds',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _previewAtMeta = const VerificationMeta(
    'previewAt',
  );
  @override
  late final GeneratedColumn<DateTime> previewAt = GeneratedColumn<DateTime>(
    'preview_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reminderAtMeta = const VerificationMeta(
    'reminderAt',
  );
  @override
  late final GeneratedColumn<DateTime> reminderAt = GeneratedColumn<DateTime>(
    'reminder_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    title,
    body,
    url,
    folderId,
    sortState,
    sortedBy,
    aiDescription,
    transcript,
    coverPath,
    previewText,
    previewSite,
    previewAuthor,
    durationSeconds,
    previewAt,
    reminderAt,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'items';
  @override
  VerificationContext validateIntegrity(
    Insertable<Item> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    }
    if (data.containsKey('folder_id')) {
      context.handle(
        _folderIdMeta,
        folderId.isAcceptableOrUnknown(data['folder_id']!, _folderIdMeta),
      );
    }
    if (data.containsKey('ai_description')) {
      context.handle(
        _aiDescriptionMeta,
        aiDescription.isAcceptableOrUnknown(
          data['ai_description']!,
          _aiDescriptionMeta,
        ),
      );
    }
    if (data.containsKey('transcript')) {
      context.handle(
        _transcriptMeta,
        transcript.isAcceptableOrUnknown(data['transcript']!, _transcriptMeta),
      );
    }
    if (data.containsKey('cover_path')) {
      context.handle(
        _coverPathMeta,
        coverPath.isAcceptableOrUnknown(data['cover_path']!, _coverPathMeta),
      );
    }
    if (data.containsKey('preview_text')) {
      context.handle(
        _previewTextMeta,
        previewText.isAcceptableOrUnknown(
          data['preview_text']!,
          _previewTextMeta,
        ),
      );
    }
    if (data.containsKey('preview_site')) {
      context.handle(
        _previewSiteMeta,
        previewSite.isAcceptableOrUnknown(
          data['preview_site']!,
          _previewSiteMeta,
        ),
      );
    }
    if (data.containsKey('preview_author')) {
      context.handle(
        _previewAuthorMeta,
        previewAuthor.isAcceptableOrUnknown(
          data['preview_author']!,
          _previewAuthorMeta,
        ),
      );
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
        _durationSecondsMeta,
        durationSeconds.isAcceptableOrUnknown(
          data['duration_seconds']!,
          _durationSecondsMeta,
        ),
      );
    }
    if (data.containsKey('preview_at')) {
      context.handle(
        _previewAtMeta,
        previewAt.isAcceptableOrUnknown(data['preview_at']!, _previewAtMeta),
      );
    }
    if (data.containsKey('reminder_at')) {
      context.handle(
        _reminderAtMeta,
        reminderAt.isAcceptableOrUnknown(data['reminder_at']!, _reminderAtMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Item map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Item(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kind: $ItemsTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      ),
      folderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}folder_id'],
      ),
      sortState: $ItemsTable.$convertersortState.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}sort_state'],
        )!,
      ),
      sortedBy: $ItemsTable.$convertersortedBy.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}sorted_by'],
        )!,
      ),
      aiDescription: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ai_description'],
      ),
      transcript: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transcript'],
      ),
      coverPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_path'],
      ),
      previewText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preview_text'],
      ),
      previewSite: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preview_site'],
      ),
      previewAuthor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preview_author'],
      ),
      durationSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_seconds'],
      ),
      previewAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}preview_at'],
      ),
      reminderAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}reminder_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $ItemsTable createAlias(String alias) {
    return $ItemsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ItemKind, String, String> $converterkind =
      const EnumNameConverter<ItemKind>(ItemKind.values);
  static JsonTypeConverter2<SortState, String, String> $convertersortState =
      const EnumNameConverter<SortState>(SortState.values);
  static JsonTypeConverter2<SortedBy, String, String> $convertersortedBy =
      const EnumNameConverter<SortedBy>(SortedBy.values);
}

class Item extends DataClass implements Insertable<Item> {
  final String id;
  final ItemKind kind;
  final String title;
  final String body;
  final String? url;
  final String? folderId;
  final SortState sortState;
  final SortedBy sortedBy;

  /// Описание от ИИ: ищется, но не показывается как текст вещи.
  final String? aiDescription;
  final String? transcript;

  /// Превью ссылки или ролика: обложка (путь от папки приложения), описание
  /// страницы, имя сайта, автор ролика и длина. Пишет `LinkPreviewService`.
  final String? coverPath;
  final String? previewText;
  final String? previewSite;
  final String? previewAuthor;
  final int? durationSeconds;

  /// Когда превью загружено. Пусто — ещё не пробовали или сеть не ответила.
  final DateTime? previewAt;
  final DateTime? reminderAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const Item({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    this.url,
    this.folderId,
    required this.sortState,
    required this.sortedBy,
    this.aiDescription,
    this.transcript,
    this.coverPath,
    this.previewText,
    this.previewSite,
    this.previewAuthor,
    this.durationSeconds,
    this.previewAt,
    this.reminderAt,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    {
      map['kind'] = Variable<String>($ItemsTable.$converterkind.toSql(kind));
    }
    map['title'] = Variable<String>(title);
    map['body'] = Variable<String>(body);
    if (!nullToAbsent || url != null) {
      map['url'] = Variable<String>(url);
    }
    if (!nullToAbsent || folderId != null) {
      map['folder_id'] = Variable<String>(folderId);
    }
    {
      map['sort_state'] = Variable<String>(
        $ItemsTable.$convertersortState.toSql(sortState),
      );
    }
    {
      map['sorted_by'] = Variable<String>(
        $ItemsTable.$convertersortedBy.toSql(sortedBy),
      );
    }
    if (!nullToAbsent || aiDescription != null) {
      map['ai_description'] = Variable<String>(aiDescription);
    }
    if (!nullToAbsent || transcript != null) {
      map['transcript'] = Variable<String>(transcript);
    }
    if (!nullToAbsent || coverPath != null) {
      map['cover_path'] = Variable<String>(coverPath);
    }
    if (!nullToAbsent || previewText != null) {
      map['preview_text'] = Variable<String>(previewText);
    }
    if (!nullToAbsent || previewSite != null) {
      map['preview_site'] = Variable<String>(previewSite);
    }
    if (!nullToAbsent || previewAuthor != null) {
      map['preview_author'] = Variable<String>(previewAuthor);
    }
    if (!nullToAbsent || durationSeconds != null) {
      map['duration_seconds'] = Variable<int>(durationSeconds);
    }
    if (!nullToAbsent || previewAt != null) {
      map['preview_at'] = Variable<DateTime>(previewAt);
    }
    if (!nullToAbsent || reminderAt != null) {
      map['reminder_at'] = Variable<DateTime>(reminderAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  ItemsCompanion toCompanion(bool nullToAbsent) {
    return ItemsCompanion(
      id: Value(id),
      kind: Value(kind),
      title: Value(title),
      body: Value(body),
      url: url == null && nullToAbsent ? const Value.absent() : Value(url),
      folderId: folderId == null && nullToAbsent
          ? const Value.absent()
          : Value(folderId),
      sortState: Value(sortState),
      sortedBy: Value(sortedBy),
      aiDescription: aiDescription == null && nullToAbsent
          ? const Value.absent()
          : Value(aiDescription),
      transcript: transcript == null && nullToAbsent
          ? const Value.absent()
          : Value(transcript),
      coverPath: coverPath == null && nullToAbsent
          ? const Value.absent()
          : Value(coverPath),
      previewText: previewText == null && nullToAbsent
          ? const Value.absent()
          : Value(previewText),
      previewSite: previewSite == null && nullToAbsent
          ? const Value.absent()
          : Value(previewSite),
      previewAuthor: previewAuthor == null && nullToAbsent
          ? const Value.absent()
          : Value(previewAuthor),
      durationSeconds: durationSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(durationSeconds),
      previewAt: previewAt == null && nullToAbsent
          ? const Value.absent()
          : Value(previewAt),
      reminderAt: reminderAt == null && nullToAbsent
          ? const Value.absent()
          : Value(reminderAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Item.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Item(
      id: serializer.fromJson<String>(json['id']),
      kind: $ItemsTable.$converterkind.fromJson(
        serializer.fromJson<String>(json['kind']),
      ),
      title: serializer.fromJson<String>(json['title']),
      body: serializer.fromJson<String>(json['body']),
      url: serializer.fromJson<String?>(json['url']),
      folderId: serializer.fromJson<String?>(json['folderId']),
      sortState: $ItemsTable.$convertersortState.fromJson(
        serializer.fromJson<String>(json['sortState']),
      ),
      sortedBy: $ItemsTable.$convertersortedBy.fromJson(
        serializer.fromJson<String>(json['sortedBy']),
      ),
      aiDescription: serializer.fromJson<String?>(json['aiDescription']),
      transcript: serializer.fromJson<String?>(json['transcript']),
      coverPath: serializer.fromJson<String?>(json['coverPath']),
      previewText: serializer.fromJson<String?>(json['previewText']),
      previewSite: serializer.fromJson<String?>(json['previewSite']),
      previewAuthor: serializer.fromJson<String?>(json['previewAuthor']),
      durationSeconds: serializer.fromJson<int?>(json['durationSeconds']),
      previewAt: serializer.fromJson<DateTime?>(json['previewAt']),
      reminderAt: serializer.fromJson<DateTime?>(json['reminderAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(
        $ItemsTable.$converterkind.toJson(kind),
      ),
      'title': serializer.toJson<String>(title),
      'body': serializer.toJson<String>(body),
      'url': serializer.toJson<String?>(url),
      'folderId': serializer.toJson<String?>(folderId),
      'sortState': serializer.toJson<String>(
        $ItemsTable.$convertersortState.toJson(sortState),
      ),
      'sortedBy': serializer.toJson<String>(
        $ItemsTable.$convertersortedBy.toJson(sortedBy),
      ),
      'aiDescription': serializer.toJson<String?>(aiDescription),
      'transcript': serializer.toJson<String?>(transcript),
      'coverPath': serializer.toJson<String?>(coverPath),
      'previewText': serializer.toJson<String?>(previewText),
      'previewSite': serializer.toJson<String?>(previewSite),
      'previewAuthor': serializer.toJson<String?>(previewAuthor),
      'durationSeconds': serializer.toJson<int?>(durationSeconds),
      'previewAt': serializer.toJson<DateTime?>(previewAt),
      'reminderAt': serializer.toJson<DateTime?>(reminderAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  Item copyWith({
    String? id,
    ItemKind? kind,
    String? title,
    String? body,
    Value<String?> url = const Value.absent(),
    Value<String?> folderId = const Value.absent(),
    SortState? sortState,
    SortedBy? sortedBy,
    Value<String?> aiDescription = const Value.absent(),
    Value<String?> transcript = const Value.absent(),
    Value<String?> coverPath = const Value.absent(),
    Value<String?> previewText = const Value.absent(),
    Value<String?> previewSite = const Value.absent(),
    Value<String?> previewAuthor = const Value.absent(),
    Value<int?> durationSeconds = const Value.absent(),
    Value<DateTime?> previewAt = const Value.absent(),
    Value<DateTime?> reminderAt = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => Item(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    title: title ?? this.title,
    body: body ?? this.body,
    url: url.present ? url.value : this.url,
    folderId: folderId.present ? folderId.value : this.folderId,
    sortState: sortState ?? this.sortState,
    sortedBy: sortedBy ?? this.sortedBy,
    aiDescription: aiDescription.present
        ? aiDescription.value
        : this.aiDescription,
    transcript: transcript.present ? transcript.value : this.transcript,
    coverPath: coverPath.present ? coverPath.value : this.coverPath,
    previewText: previewText.present ? previewText.value : this.previewText,
    previewSite: previewSite.present ? previewSite.value : this.previewSite,
    previewAuthor: previewAuthor.present
        ? previewAuthor.value
        : this.previewAuthor,
    durationSeconds: durationSeconds.present
        ? durationSeconds.value
        : this.durationSeconds,
    previewAt: previewAt.present ? previewAt.value : this.previewAt,
    reminderAt: reminderAt.present ? reminderAt.value : this.reminderAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  Item copyWithCompanion(ItemsCompanion data) {
    return Item(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      title: data.title.present ? data.title.value : this.title,
      body: data.body.present ? data.body.value : this.body,
      url: data.url.present ? data.url.value : this.url,
      folderId: data.folderId.present ? data.folderId.value : this.folderId,
      sortState: data.sortState.present ? data.sortState.value : this.sortState,
      sortedBy: data.sortedBy.present ? data.sortedBy.value : this.sortedBy,
      aiDescription: data.aiDescription.present
          ? data.aiDescription.value
          : this.aiDescription,
      transcript: data.transcript.present
          ? data.transcript.value
          : this.transcript,
      coverPath: data.coverPath.present ? data.coverPath.value : this.coverPath,
      previewText: data.previewText.present
          ? data.previewText.value
          : this.previewText,
      previewSite: data.previewSite.present
          ? data.previewSite.value
          : this.previewSite,
      previewAuthor: data.previewAuthor.present
          ? data.previewAuthor.value
          : this.previewAuthor,
      durationSeconds: data.durationSeconds.present
          ? data.durationSeconds.value
          : this.durationSeconds,
      previewAt: data.previewAt.present ? data.previewAt.value : this.previewAt,
      reminderAt: data.reminderAt.present
          ? data.reminderAt.value
          : this.reminderAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Item(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('url: $url, ')
          ..write('folderId: $folderId, ')
          ..write('sortState: $sortState, ')
          ..write('sortedBy: $sortedBy, ')
          ..write('aiDescription: $aiDescription, ')
          ..write('transcript: $transcript, ')
          ..write('coverPath: $coverPath, ')
          ..write('previewText: $previewText, ')
          ..write('previewSite: $previewSite, ')
          ..write('previewAuthor: $previewAuthor, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('previewAt: $previewAt, ')
          ..write('reminderAt: $reminderAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    title,
    body,
    url,
    folderId,
    sortState,
    sortedBy,
    aiDescription,
    transcript,
    coverPath,
    previewText,
    previewSite,
    previewAuthor,
    durationSeconds,
    previewAt,
    reminderAt,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Item &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.title == this.title &&
          other.body == this.body &&
          other.url == this.url &&
          other.folderId == this.folderId &&
          other.sortState == this.sortState &&
          other.sortedBy == this.sortedBy &&
          other.aiDescription == this.aiDescription &&
          other.transcript == this.transcript &&
          other.coverPath == this.coverPath &&
          other.previewText == this.previewText &&
          other.previewSite == this.previewSite &&
          other.previewAuthor == this.previewAuthor &&
          other.durationSeconds == this.durationSeconds &&
          other.previewAt == this.previewAt &&
          other.reminderAt == this.reminderAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class ItemsCompanion extends UpdateCompanion<Item> {
  final Value<String> id;
  final Value<ItemKind> kind;
  final Value<String> title;
  final Value<String> body;
  final Value<String?> url;
  final Value<String?> folderId;
  final Value<SortState> sortState;
  final Value<SortedBy> sortedBy;
  final Value<String?> aiDescription;
  final Value<String?> transcript;
  final Value<String?> coverPath;
  final Value<String?> previewText;
  final Value<String?> previewSite;
  final Value<String?> previewAuthor;
  final Value<int?> durationSeconds;
  final Value<DateTime?> previewAt;
  final Value<DateTime?> reminderAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const ItemsCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.title = const Value.absent(),
    this.body = const Value.absent(),
    this.url = const Value.absent(),
    this.folderId = const Value.absent(),
    this.sortState = const Value.absent(),
    this.sortedBy = const Value.absent(),
    this.aiDescription = const Value.absent(),
    this.transcript = const Value.absent(),
    this.coverPath = const Value.absent(),
    this.previewText = const Value.absent(),
    this.previewSite = const Value.absent(),
    this.previewAuthor = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.previewAt = const Value.absent(),
    this.reminderAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ItemsCompanion.insert({
    required String id,
    required ItemKind kind,
    required String title,
    this.body = const Value.absent(),
    this.url = const Value.absent(),
    this.folderId = const Value.absent(),
    this.sortState = const Value.absent(),
    this.sortedBy = const Value.absent(),
    this.aiDescription = const Value.absent(),
    this.transcript = const Value.absent(),
    this.coverPath = const Value.absent(),
    this.previewText = const Value.absent(),
    this.previewSite = const Value.absent(),
    this.previewAuthor = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.previewAt = const Value.absent(),
    this.reminderAt = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       title = Value(title),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Item> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? title,
    Expression<String>? body,
    Expression<String>? url,
    Expression<String>? folderId,
    Expression<String>? sortState,
    Expression<String>? sortedBy,
    Expression<String>? aiDescription,
    Expression<String>? transcript,
    Expression<String>? coverPath,
    Expression<String>? previewText,
    Expression<String>? previewSite,
    Expression<String>? previewAuthor,
    Expression<int>? durationSeconds,
    Expression<DateTime>? previewAt,
    Expression<DateTime>? reminderAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      if (url != null) 'url': url,
      if (folderId != null) 'folder_id': folderId,
      if (sortState != null) 'sort_state': sortState,
      if (sortedBy != null) 'sorted_by': sortedBy,
      if (aiDescription != null) 'ai_description': aiDescription,
      if (transcript != null) 'transcript': transcript,
      if (coverPath != null) 'cover_path': coverPath,
      if (previewText != null) 'preview_text': previewText,
      if (previewSite != null) 'preview_site': previewSite,
      if (previewAuthor != null) 'preview_author': previewAuthor,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (previewAt != null) 'preview_at': previewAt,
      if (reminderAt != null) 'reminder_at': reminderAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ItemsCompanion copyWith({
    Value<String>? id,
    Value<ItemKind>? kind,
    Value<String>? title,
    Value<String>? body,
    Value<String?>? url,
    Value<String?>? folderId,
    Value<SortState>? sortState,
    Value<SortedBy>? sortedBy,
    Value<String?>? aiDescription,
    Value<String?>? transcript,
    Value<String?>? coverPath,
    Value<String?>? previewText,
    Value<String?>? previewSite,
    Value<String?>? previewAuthor,
    Value<int?>? durationSeconds,
    Value<DateTime?>? previewAt,
    Value<DateTime?>? reminderAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return ItemsCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      body: body ?? this.body,
      url: url ?? this.url,
      folderId: folderId ?? this.folderId,
      sortState: sortState ?? this.sortState,
      sortedBy: sortedBy ?? this.sortedBy,
      aiDescription: aiDescription ?? this.aiDescription,
      transcript: transcript ?? this.transcript,
      coverPath: coverPath ?? this.coverPath,
      previewText: previewText ?? this.previewText,
      previewSite: previewSite ?? this.previewSite,
      previewAuthor: previewAuthor ?? this.previewAuthor,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      previewAt: previewAt ?? this.previewAt,
      reminderAt: reminderAt ?? this.reminderAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
        $ItemsTable.$converterkind.toSql(kind.value),
      );
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (folderId.present) {
      map['folder_id'] = Variable<String>(folderId.value);
    }
    if (sortState.present) {
      map['sort_state'] = Variable<String>(
        $ItemsTable.$convertersortState.toSql(sortState.value),
      );
    }
    if (sortedBy.present) {
      map['sorted_by'] = Variable<String>(
        $ItemsTable.$convertersortedBy.toSql(sortedBy.value),
      );
    }
    if (aiDescription.present) {
      map['ai_description'] = Variable<String>(aiDescription.value);
    }
    if (transcript.present) {
      map['transcript'] = Variable<String>(transcript.value);
    }
    if (coverPath.present) {
      map['cover_path'] = Variable<String>(coverPath.value);
    }
    if (previewText.present) {
      map['preview_text'] = Variable<String>(previewText.value);
    }
    if (previewSite.present) {
      map['preview_site'] = Variable<String>(previewSite.value);
    }
    if (previewAuthor.present) {
      map['preview_author'] = Variable<String>(previewAuthor.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<int>(durationSeconds.value);
    }
    if (previewAt.present) {
      map['preview_at'] = Variable<DateTime>(previewAt.value);
    }
    if (reminderAt.present) {
      map['reminder_at'] = Variable<DateTime>(reminderAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ItemsCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('url: $url, ')
          ..write('folderId: $folderId, ')
          ..write('sortState: $sortState, ')
          ..write('sortedBy: $sortedBy, ')
          ..write('aiDescription: $aiDescription, ')
          ..write('transcript: $transcript, ')
          ..write('coverPath: $coverPath, ')
          ..write('previewText: $previewText, ')
          ..write('previewSite: $previewSite, ')
          ..write('previewAuthor: $previewAuthor, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('previewAt: $previewAt, ')
          ..write('reminderAt: $reminderAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AttachmentsTable extends Attachments
    with TableInfo<$AttachmentsTable, Attachment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AttachmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mimeMeta = const VerificationMeta('mime');
  @override
  late final GeneratedColumn<String> mime = GeneratedColumn<String>(
    'mime',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<int> size = GeneratedColumn<int>(
    'size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<int> width = GeneratedColumn<int>(
    'width',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<int> height = GeneratedColumn<int>(
    'height',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _thumbPathMeta = const VerificationMeta(
    'thumbPath',
  );
  @override
  late final GeneratedColumn<String> thumbPath = GeneratedColumn<String>(
    'thumb_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    itemId,
    path,
    mime,
    size,
    width,
    height,
    thumbPath,
    position,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'attachments';
  @override
  VerificationContext validateIntegrity(
    Insertable<Attachment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('mime')) {
      context.handle(
        _mimeMeta,
        mime.isAcceptableOrUnknown(data['mime']!, _mimeMeta),
      );
    } else if (isInserting) {
      context.missing(_mimeMeta);
    }
    if (data.containsKey('size')) {
      context.handle(
        _sizeMeta,
        size.isAcceptableOrUnknown(data['size']!, _sizeMeta),
      );
    } else if (isInserting) {
      context.missing(_sizeMeta);
    }
    if (data.containsKey('width')) {
      context.handle(
        _widthMeta,
        width.isAcceptableOrUnknown(data['width']!, _widthMeta),
      );
    }
    if (data.containsKey('height')) {
      context.handle(
        _heightMeta,
        height.isAcceptableOrUnknown(data['height']!, _heightMeta),
      );
    }
    if (data.containsKey('thumb_path')) {
      context.handle(
        _thumbPathMeta,
        thumbPath.isAcceptableOrUnknown(data['thumb_path']!, _thumbPathMeta),
      );
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Attachment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Attachment(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      mime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime'],
      )!,
      size: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size'],
      )!,
      width: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}width'],
      ),
      height: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}height'],
      ),
      thumbPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thumb_path'],
      ),
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
    );
  }

  @override
  $AttachmentsTable createAlias(String alias) {
    return $AttachmentsTable(attachedDatabase, alias);
  }
}

class Attachment extends DataClass implements Insertable<Attachment> {
  final String id;
  final String itemId;

  /// Путь от папки приложения: абсолютный протухает после переустановки.
  final String path;
  final String mime;
  final int size;
  final int? width;
  final int? height;
  final String? thumbPath;
  final int position;
  const Attachment({
    required this.id,
    required this.itemId,
    required this.path,
    required this.mime,
    required this.size,
    this.width,
    this.height,
    this.thumbPath,
    required this.position,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['item_id'] = Variable<String>(itemId);
    map['path'] = Variable<String>(path);
    map['mime'] = Variable<String>(mime);
    map['size'] = Variable<int>(size);
    if (!nullToAbsent || width != null) {
      map['width'] = Variable<int>(width);
    }
    if (!nullToAbsent || height != null) {
      map['height'] = Variable<int>(height);
    }
    if (!nullToAbsent || thumbPath != null) {
      map['thumb_path'] = Variable<String>(thumbPath);
    }
    map['position'] = Variable<int>(position);
    return map;
  }

  AttachmentsCompanion toCompanion(bool nullToAbsent) {
    return AttachmentsCompanion(
      id: Value(id),
      itemId: Value(itemId),
      path: Value(path),
      mime: Value(mime),
      size: Value(size),
      width: width == null && nullToAbsent
          ? const Value.absent()
          : Value(width),
      height: height == null && nullToAbsent
          ? const Value.absent()
          : Value(height),
      thumbPath: thumbPath == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbPath),
      position: Value(position),
    );
  }

  factory Attachment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Attachment(
      id: serializer.fromJson<String>(json['id']),
      itemId: serializer.fromJson<String>(json['itemId']),
      path: serializer.fromJson<String>(json['path']),
      mime: serializer.fromJson<String>(json['mime']),
      size: serializer.fromJson<int>(json['size']),
      width: serializer.fromJson<int?>(json['width']),
      height: serializer.fromJson<int?>(json['height']),
      thumbPath: serializer.fromJson<String?>(json['thumbPath']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'itemId': serializer.toJson<String>(itemId),
      'path': serializer.toJson<String>(path),
      'mime': serializer.toJson<String>(mime),
      'size': serializer.toJson<int>(size),
      'width': serializer.toJson<int?>(width),
      'height': serializer.toJson<int?>(height),
      'thumbPath': serializer.toJson<String?>(thumbPath),
      'position': serializer.toJson<int>(position),
    };
  }

  Attachment copyWith({
    String? id,
    String? itemId,
    String? path,
    String? mime,
    int? size,
    Value<int?> width = const Value.absent(),
    Value<int?> height = const Value.absent(),
    Value<String?> thumbPath = const Value.absent(),
    int? position,
  }) => Attachment(
    id: id ?? this.id,
    itemId: itemId ?? this.itemId,
    path: path ?? this.path,
    mime: mime ?? this.mime,
    size: size ?? this.size,
    width: width.present ? width.value : this.width,
    height: height.present ? height.value : this.height,
    thumbPath: thumbPath.present ? thumbPath.value : this.thumbPath,
    position: position ?? this.position,
  );
  Attachment copyWithCompanion(AttachmentsCompanion data) {
    return Attachment(
      id: data.id.present ? data.id.value : this.id,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      path: data.path.present ? data.path.value : this.path,
      mime: data.mime.present ? data.mime.value : this.mime,
      size: data.size.present ? data.size.value : this.size,
      width: data.width.present ? data.width.value : this.width,
      height: data.height.present ? data.height.value : this.height,
      thumbPath: data.thumbPath.present ? data.thumbPath.value : this.thumbPath,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Attachment(')
          ..write('id: $id, ')
          ..write('itemId: $itemId, ')
          ..write('path: $path, ')
          ..write('mime: $mime, ')
          ..write('size: $size, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('thumbPath: $thumbPath, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    itemId,
    path,
    mime,
    size,
    width,
    height,
    thumbPath,
    position,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Attachment &&
          other.id == this.id &&
          other.itemId == this.itemId &&
          other.path == this.path &&
          other.mime == this.mime &&
          other.size == this.size &&
          other.width == this.width &&
          other.height == this.height &&
          other.thumbPath == this.thumbPath &&
          other.position == this.position);
}

class AttachmentsCompanion extends UpdateCompanion<Attachment> {
  final Value<String> id;
  final Value<String> itemId;
  final Value<String> path;
  final Value<String> mime;
  final Value<int> size;
  final Value<int?> width;
  final Value<int?> height;
  final Value<String?> thumbPath;
  final Value<int> position;
  final Value<int> rowid;
  const AttachmentsCompanion({
    this.id = const Value.absent(),
    this.itemId = const Value.absent(),
    this.path = const Value.absent(),
    this.mime = const Value.absent(),
    this.size = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.thumbPath = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AttachmentsCompanion.insert({
    required String id,
    required String itemId,
    required String path,
    required String mime,
    required int size,
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.thumbPath = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       itemId = Value(itemId),
       path = Value(path),
       mime = Value(mime),
       size = Value(size);
  static Insertable<Attachment> custom({
    Expression<String>? id,
    Expression<String>? itemId,
    Expression<String>? path,
    Expression<String>? mime,
    Expression<int>? size,
    Expression<int>? width,
    Expression<int>? height,
    Expression<String>? thumbPath,
    Expression<int>? position,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (itemId != null) 'item_id': itemId,
      if (path != null) 'path': path,
      if (mime != null) 'mime': mime,
      if (size != null) 'size': size,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (thumbPath != null) 'thumb_path': thumbPath,
      if (position != null) 'position': position,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AttachmentsCompanion copyWith({
    Value<String>? id,
    Value<String>? itemId,
    Value<String>? path,
    Value<String>? mime,
    Value<int>? size,
    Value<int?>? width,
    Value<int?>? height,
    Value<String?>? thumbPath,
    Value<int>? position,
    Value<int>? rowid,
  }) {
    return AttachmentsCompanion(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      path: path ?? this.path,
      mime: mime ?? this.mime,
      size: size ?? this.size,
      width: width ?? this.width,
      height: height ?? this.height,
      thumbPath: thumbPath ?? this.thumbPath,
      position: position ?? this.position,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (mime.present) {
      map['mime'] = Variable<String>(mime.value);
    }
    if (size.present) {
      map['size'] = Variable<int>(size.value);
    }
    if (width.present) {
      map['width'] = Variable<int>(width.value);
    }
    if (height.present) {
      map['height'] = Variable<int>(height.value);
    }
    if (thumbPath.present) {
      map['thumb_path'] = Variable<String>(thumbPath.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AttachmentsCompanion(')
          ..write('id: $id, ')
          ..write('itemId: $itemId, ')
          ..write('path: $path, ')
          ..write('mime: $mime, ')
          ..write('size: $size, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('thumbPath: $thumbPath, ')
          ..write('position: $position, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FoldersTable extends Folders with TableInfo<$FoldersTable, Folder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FoldersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
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
    requiredDuringInsert: true,
  );
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
    'icon',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _shapeMeta = const VerificationMeta('shape');
  @override
  late final GeneratedColumn<String> shape = GeneratedColumn<String>(
    'shape',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdByAiMeta = const VerificationMeta(
    'createdByAi',
  );
  @override
  late final GeneratedColumn<bool> createdByAi = GeneratedColumn<bool>(
    'created_by_ai',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("created_by_ai" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  late final GeneratedColumnWithTypeConverter<FolderView, String> view =
      GeneratedColumn<String>(
        'view',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: Constant(FolderView.auto.name),
      ).withConverter<FolderView>($FoldersTable.$converterview);
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    icon,
    shape,
    sortOrder,
    createdByAi,
    view,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'folders';
  @override
  VerificationContext validateIntegrity(
    Insertable<Folder> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('icon')) {
      context.handle(
        _iconMeta,
        icon.isAcceptableOrUnknown(data['icon']!, _iconMeta),
      );
    } else if (isInserting) {
      context.missing(_iconMeta);
    }
    if (data.containsKey('shape')) {
      context.handle(
        _shapeMeta,
        shape.isAcceptableOrUnknown(data['shape']!, _shapeMeta),
      );
    } else if (isInserting) {
      context.missing(_shapeMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('created_by_ai')) {
      context.handle(
        _createdByAiMeta,
        createdByAi.isAcceptableOrUnknown(
          data['created_by_ai']!,
          _createdByAiMeta,
        ),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Folder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Folder(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      icon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon'],
      )!,
      shape: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}shape'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      createdByAi: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}created_by_ai'],
      )!,
      view: $FoldersTable.$converterview.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}view'],
        )!,
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $FoldersTable createAlias(String alias) {
    return $FoldersTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<FolderView, String, String> $converterview =
      const EnumNameConverter<FolderView>(FolderView.values);
}

class Folder extends DataClass implements Insertable<Folder> {
  final String id;
  final String name;

  /// Имя иконки Material Symbols.
  final String icon;

  /// Имя формы значка (BadgeShape.name).
  final String shape;
  final int sortOrder;
  final bool createdByAi;
  final FolderView view;
  final DateTime? deletedAt;
  const Folder({
    required this.id,
    required this.name,
    required this.icon,
    required this.shape,
    required this.sortOrder,
    required this.createdByAi,
    required this.view,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['icon'] = Variable<String>(icon);
    map['shape'] = Variable<String>(shape);
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_by_ai'] = Variable<bool>(createdByAi);
    {
      map['view'] = Variable<String>($FoldersTable.$converterview.toSql(view));
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  FoldersCompanion toCompanion(bool nullToAbsent) {
    return FoldersCompanion(
      id: Value(id),
      name: Value(name),
      icon: Value(icon),
      shape: Value(shape),
      sortOrder: Value(sortOrder),
      createdByAi: Value(createdByAi),
      view: Value(view),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Folder.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Folder(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      icon: serializer.fromJson<String>(json['icon']),
      shape: serializer.fromJson<String>(json['shape']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdByAi: serializer.fromJson<bool>(json['createdByAi']),
      view: $FoldersTable.$converterview.fromJson(
        serializer.fromJson<String>(json['view']),
      ),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'icon': serializer.toJson<String>(icon),
      'shape': serializer.toJson<String>(shape),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdByAi': serializer.toJson<bool>(createdByAi),
      'view': serializer.toJson<String>(
        $FoldersTable.$converterview.toJson(view),
      ),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  Folder copyWith({
    String? id,
    String? name,
    String? icon,
    String? shape,
    int? sortOrder,
    bool? createdByAi,
    FolderView? view,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => Folder(
    id: id ?? this.id,
    name: name ?? this.name,
    icon: icon ?? this.icon,
    shape: shape ?? this.shape,
    sortOrder: sortOrder ?? this.sortOrder,
    createdByAi: createdByAi ?? this.createdByAi,
    view: view ?? this.view,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  Folder copyWithCompanion(FoldersCompanion data) {
    return Folder(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      icon: data.icon.present ? data.icon.value : this.icon,
      shape: data.shape.present ? data.shape.value : this.shape,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdByAi: data.createdByAi.present
          ? data.createdByAi.value
          : this.createdByAi,
      view: data.view.present ? data.view.value : this.view,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Folder(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('icon: $icon, ')
          ..write('shape: $shape, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdByAi: $createdByAi, ')
          ..write('view: $view, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    icon,
    shape,
    sortOrder,
    createdByAi,
    view,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Folder &&
          other.id == this.id &&
          other.name == this.name &&
          other.icon == this.icon &&
          other.shape == this.shape &&
          other.sortOrder == this.sortOrder &&
          other.createdByAi == this.createdByAi &&
          other.view == this.view &&
          other.deletedAt == this.deletedAt);
}

class FoldersCompanion extends UpdateCompanion<Folder> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> icon;
  final Value<String> shape;
  final Value<int> sortOrder;
  final Value<bool> createdByAi;
  final Value<FolderView> view;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const FoldersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.icon = const Value.absent(),
    this.shape = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdByAi = const Value.absent(),
    this.view = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FoldersCompanion.insert({
    required String id,
    required String name,
    required String icon,
    required String shape,
    this.sortOrder = const Value.absent(),
    this.createdByAi = const Value.absent(),
    this.view = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       icon = Value(icon),
       shape = Value(shape);
  static Insertable<Folder> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? icon,
    Expression<String>? shape,
    Expression<int>? sortOrder,
    Expression<bool>? createdByAi,
    Expression<String>? view,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (icon != null) 'icon': icon,
      if (shape != null) 'shape': shape,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdByAi != null) 'created_by_ai': createdByAi,
      if (view != null) 'view': view,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FoldersCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? icon,
    Value<String>? shape,
    Value<int>? sortOrder,
    Value<bool>? createdByAi,
    Value<FolderView>? view,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return FoldersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      shape: shape ?? this.shape,
      sortOrder: sortOrder ?? this.sortOrder,
      createdByAi: createdByAi ?? this.createdByAi,
      view: view ?? this.view,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (shape.present) {
      map['shape'] = Variable<String>(shape.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdByAi.present) {
      map['created_by_ai'] = Variable<bool>(createdByAi.value);
    }
    if (view.present) {
      map['view'] = Variable<String>(
        $FoldersTable.$converterview.toSql(view.value),
      );
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FoldersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('icon: $icon, ')
          ..write('shape: $shape, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdByAi: $createdByAi, ')
          ..write('view: $view, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TagsTable extends Tags with TableInfo<$TagsTable, Tag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
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
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  @override
  late final GeneratedColumnWithTypeConverter<TagIconKind, String> iconKind =
      GeneratedColumn<String>(
        'icon_kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: Constant(TagIconKind.symbol.name),
      ).withConverter<TagIconKind>($TagsTable.$convertericonKind);
  static const VerificationMeta _iconValueMeta = const VerificationMeta(
    'iconValue',
  );
  @override
  late final GeneratedColumn<String> iconValue = GeneratedColumn<String>(
    'icon_value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('label'),
  );
  static const VerificationMeta _pinnedMeta = const VerificationMeta('pinned');
  @override
  late final GeneratedColumn<bool> pinned = GeneratedColumn<bool>(
    'pinned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("pinned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _pinOrderMeta = const VerificationMeta(
    'pinOrder',
  );
  @override
  late final GeneratedColumn<int> pinOrder = GeneratedColumn<int>(
    'pin_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    iconKind,
    iconValue,
    pinned,
    pinOrder,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<Tag> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('icon_value')) {
      context.handle(
        _iconValueMeta,
        iconValue.isAcceptableOrUnknown(data['icon_value']!, _iconValueMeta),
      );
    }
    if (data.containsKey('pinned')) {
      context.handle(
        _pinnedMeta,
        pinned.isAcceptableOrUnknown(data['pinned']!, _pinnedMeta),
      );
    }
    if (data.containsKey('pin_order')) {
      context.handle(
        _pinOrderMeta,
        pinOrder.isAcceptableOrUnknown(data['pin_order']!, _pinOrderMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Tag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Tag(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      iconKind: $TagsTable.$convertericonKind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}icon_kind'],
        )!,
      ),
      iconValue: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon_value'],
      )!,
      pinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}pinned'],
      )!,
      pinOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pin_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $TagsTable createAlias(String alias) {
    return $TagsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<TagIconKind, String, String> $convertericonKind =
      const EnumNameConverter<TagIconKind>(TagIconKind.values);
}

class Tag extends DataClass implements Insertable<Tag> {
  final String id;

  /// Нормализованное имя (normalizeTagName), второй тег с тем же именем не заводится.
  final String name;
  final TagIconKind iconKind;
  final String iconValue;
  final bool pinned;
  final int pinOrder;
  final DateTime createdAt;
  const Tag({
    required this.id,
    required this.name,
    required this.iconKind,
    required this.iconValue,
    required this.pinned,
    required this.pinOrder,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    {
      map['icon_kind'] = Variable<String>(
        $TagsTable.$convertericonKind.toSql(iconKind),
      );
    }
    map['icon_value'] = Variable<String>(iconValue);
    map['pinned'] = Variable<bool>(pinned);
    map['pin_order'] = Variable<int>(pinOrder);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  TagsCompanion toCompanion(bool nullToAbsent) {
    return TagsCompanion(
      id: Value(id),
      name: Value(name),
      iconKind: Value(iconKind),
      iconValue: Value(iconValue),
      pinned: Value(pinned),
      pinOrder: Value(pinOrder),
      createdAt: Value(createdAt),
    );
  }

  factory Tag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Tag(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      iconKind: $TagsTable.$convertericonKind.fromJson(
        serializer.fromJson<String>(json['iconKind']),
      ),
      iconValue: serializer.fromJson<String>(json['iconValue']),
      pinned: serializer.fromJson<bool>(json['pinned']),
      pinOrder: serializer.fromJson<int>(json['pinOrder']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'iconKind': serializer.toJson<String>(
        $TagsTable.$convertericonKind.toJson(iconKind),
      ),
      'iconValue': serializer.toJson<String>(iconValue),
      'pinned': serializer.toJson<bool>(pinned),
      'pinOrder': serializer.toJson<int>(pinOrder),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Tag copyWith({
    String? id,
    String? name,
    TagIconKind? iconKind,
    String? iconValue,
    bool? pinned,
    int? pinOrder,
    DateTime? createdAt,
  }) => Tag(
    id: id ?? this.id,
    name: name ?? this.name,
    iconKind: iconKind ?? this.iconKind,
    iconValue: iconValue ?? this.iconValue,
    pinned: pinned ?? this.pinned,
    pinOrder: pinOrder ?? this.pinOrder,
    createdAt: createdAt ?? this.createdAt,
  );
  Tag copyWithCompanion(TagsCompanion data) {
    return Tag(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      iconKind: data.iconKind.present ? data.iconKind.value : this.iconKind,
      iconValue: data.iconValue.present ? data.iconValue.value : this.iconValue,
      pinned: data.pinned.present ? data.pinned.value : this.pinned,
      pinOrder: data.pinOrder.present ? data.pinOrder.value : this.pinOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Tag(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('iconKind: $iconKind, ')
          ..write('iconValue: $iconValue, ')
          ..write('pinned: $pinned, ')
          ..write('pinOrder: $pinOrder, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, iconKind, iconValue, pinned, pinOrder, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Tag &&
          other.id == this.id &&
          other.name == this.name &&
          other.iconKind == this.iconKind &&
          other.iconValue == this.iconValue &&
          other.pinned == this.pinned &&
          other.pinOrder == this.pinOrder &&
          other.createdAt == this.createdAt);
}

class TagsCompanion extends UpdateCompanion<Tag> {
  final Value<String> id;
  final Value<String> name;
  final Value<TagIconKind> iconKind;
  final Value<String> iconValue;
  final Value<bool> pinned;
  final Value<int> pinOrder;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const TagsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.iconKind = const Value.absent(),
    this.iconValue = const Value.absent(),
    this.pinned = const Value.absent(),
    this.pinOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TagsCompanion.insert({
    required String id,
    required String name,
    this.iconKind = const Value.absent(),
    this.iconValue = const Value.absent(),
    this.pinned = const Value.absent(),
    this.pinOrder = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<Tag> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? iconKind,
    Expression<String>? iconValue,
    Expression<bool>? pinned,
    Expression<int>? pinOrder,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (iconKind != null) 'icon_kind': iconKind,
      if (iconValue != null) 'icon_value': iconValue,
      if (pinned != null) 'pinned': pinned,
      if (pinOrder != null) 'pin_order': pinOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TagsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<TagIconKind>? iconKind,
    Value<String>? iconValue,
    Value<bool>? pinned,
    Value<int>? pinOrder,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return TagsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      iconKind: iconKind ?? this.iconKind,
      iconValue: iconValue ?? this.iconValue,
      pinned: pinned ?? this.pinned,
      pinOrder: pinOrder ?? this.pinOrder,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (iconKind.present) {
      map['icon_kind'] = Variable<String>(
        $TagsTable.$convertericonKind.toSql(iconKind.value),
      );
    }
    if (iconValue.present) {
      map['icon_value'] = Variable<String>(iconValue.value);
    }
    if (pinned.present) {
      map['pinned'] = Variable<bool>(pinned.value);
    }
    if (pinOrder.present) {
      map['pin_order'] = Variable<int>(pinOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TagsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('iconKind: $iconKind, ')
          ..write('iconValue: $iconValue, ')
          ..write('pinned: $pinned, ')
          ..write('pinOrder: $pinOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ItemTagsTable extends ItemTags with TableInfo<$ItemTagsTable, ItemTag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ItemTagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tagIdMeta = const VerificationMeta('tagId');
  @override
  late final GeneratedColumn<String> tagId = GeneratedColumn<String>(
    'tag_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<TagSource, String> source =
      GeneratedColumn<String>(
        'source',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<TagSource>($ItemTagsTable.$convertersource);
  @override
  List<GeneratedColumn> get $columns => [itemId, tagId, source];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'item_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<ItemTag> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('tag_id')) {
      context.handle(
        _tagIdMeta,
        tagId.isAcceptableOrUnknown(data['tag_id']!, _tagIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tagIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {itemId, tagId};
  @override
  ItemTag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ItemTag(
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      tagId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag_id'],
      )!,
      source: $ItemTagsTable.$convertersource.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}source'],
        )!,
      ),
    );
  }

  @override
  $ItemTagsTable createAlias(String alias) {
    return $ItemTagsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<TagSource, String, String> $convertersource =
      const EnumNameConverter<TagSource>(TagSource.values);
}

class ItemTag extends DataClass implements Insertable<ItemTag> {
  final String itemId;
  final String tagId;
  final TagSource source;
  const ItemTag({
    required this.itemId,
    required this.tagId,
    required this.source,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['item_id'] = Variable<String>(itemId);
    map['tag_id'] = Variable<String>(tagId);
    {
      map['source'] = Variable<String>(
        $ItemTagsTable.$convertersource.toSql(source),
      );
    }
    return map;
  }

  ItemTagsCompanion toCompanion(bool nullToAbsent) {
    return ItemTagsCompanion(
      itemId: Value(itemId),
      tagId: Value(tagId),
      source: Value(source),
    );
  }

  factory ItemTag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ItemTag(
      itemId: serializer.fromJson<String>(json['itemId']),
      tagId: serializer.fromJson<String>(json['tagId']),
      source: $ItemTagsTable.$convertersource.fromJson(
        serializer.fromJson<String>(json['source']),
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'itemId': serializer.toJson<String>(itemId),
      'tagId': serializer.toJson<String>(tagId),
      'source': serializer.toJson<String>(
        $ItemTagsTable.$convertersource.toJson(source),
      ),
    };
  }

  ItemTag copyWith({String? itemId, String? tagId, TagSource? source}) =>
      ItemTag(
        itemId: itemId ?? this.itemId,
        tagId: tagId ?? this.tagId,
        source: source ?? this.source,
      );
  ItemTag copyWithCompanion(ItemTagsCompanion data) {
    return ItemTag(
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      tagId: data.tagId.present ? data.tagId.value : this.tagId,
      source: data.source.present ? data.source.value : this.source,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ItemTag(')
          ..write('itemId: $itemId, ')
          ..write('tagId: $tagId, ')
          ..write('source: $source')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(itemId, tagId, source);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ItemTag &&
          other.itemId == this.itemId &&
          other.tagId == this.tagId &&
          other.source == this.source);
}

class ItemTagsCompanion extends UpdateCompanion<ItemTag> {
  final Value<String> itemId;
  final Value<String> tagId;
  final Value<TagSource> source;
  final Value<int> rowid;
  const ItemTagsCompanion({
    this.itemId = const Value.absent(),
    this.tagId = const Value.absent(),
    this.source = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ItemTagsCompanion.insert({
    required String itemId,
    required String tagId,
    required TagSource source,
    this.rowid = const Value.absent(),
  }) : itemId = Value(itemId),
       tagId = Value(tagId),
       source = Value(source);
  static Insertable<ItemTag> custom({
    Expression<String>? itemId,
    Expression<String>? tagId,
    Expression<String>? source,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (itemId != null) 'item_id': itemId,
      if (tagId != null) 'tag_id': tagId,
      if (source != null) 'source': source,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ItemTagsCompanion copyWith({
    Value<String>? itemId,
    Value<String>? tagId,
    Value<TagSource>? source,
    Value<int>? rowid,
  }) {
    return ItemTagsCompanion(
      itemId: itemId ?? this.itemId,
      tagId: tagId ?? this.tagId,
      source: source ?? this.source,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (tagId.present) {
      map['tag_id'] = Variable<String>(tagId.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(
        $ItemTagsTable.$convertersource.toSql(source.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ItemTagsCompanion(')
          ..write('itemId: $itemId, ')
          ..write('tagId: $tagId, ')
          ..write('source: $source, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RulesTable extends Rules with TableInfo<$RulesTable, Rule> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RulesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<RuleConditionKind, String>
  conditionKind = GeneratedColumn<String>(
    'condition_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<RuleConditionKind>($RulesTable.$converterconditionKind);
  static const VerificationMeta _conditionValueMeta = const VerificationMeta(
    'conditionValue',
  );
  @override
  late final GeneratedColumn<String> conditionValue = GeneratedColumn<String>(
    'condition_value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<RuleActionKind, String>
  actionKind = GeneratedColumn<String>(
    'action_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<RuleActionKind>($RulesTable.$converteractionKind);
  static const VerificationMeta _actionValueMeta = const VerificationMeta(
    'actionValue',
  );
  @override
  late final GeneratedColumn<String> actionValue = GeneratedColumn<String>(
    'action_value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    conditionKind,
    conditionValue,
    actionKind,
    actionValue,
    enabled,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rules';
  @override
  VerificationContext validateIntegrity(
    Insertable<Rule> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('condition_value')) {
      context.handle(
        _conditionValueMeta,
        conditionValue.isAcceptableOrUnknown(
          data['condition_value']!,
          _conditionValueMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_conditionValueMeta);
    }
    if (data.containsKey('action_value')) {
      context.handle(
        _actionValueMeta,
        actionValue.isAcceptableOrUnknown(
          data['action_value']!,
          _actionValueMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_actionValueMeta);
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Rule map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Rule(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      conditionKind: $RulesTable.$converterconditionKind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}condition_kind'],
        )!,
      ),
      conditionValue: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}condition_value'],
      )!,
      actionKind: $RulesTable.$converteractionKind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}action_kind'],
        )!,
      ),
      actionValue: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action_value'],
      )!,
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $RulesTable createAlias(String alias) {
    return $RulesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<RuleConditionKind, String, String>
  $converterconditionKind = const EnumNameConverter<RuleConditionKind>(
    RuleConditionKind.values,
  );
  static JsonTypeConverter2<RuleActionKind, String, String>
  $converteractionKind = const EnumNameConverter<RuleActionKind>(
    RuleActionKind.values,
  );
}

class Rule extends DataClass implements Insertable<Rule> {
  final String id;
  final RuleConditionKind conditionKind;
  final String conditionValue;
  final RuleActionKind actionKind;
  final String actionValue;
  final bool enabled;
  final int sortOrder;
  const Rule({
    required this.id,
    required this.conditionKind,
    required this.conditionValue,
    required this.actionKind,
    required this.actionValue,
    required this.enabled,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    {
      map['condition_kind'] = Variable<String>(
        $RulesTable.$converterconditionKind.toSql(conditionKind),
      );
    }
    map['condition_value'] = Variable<String>(conditionValue);
    {
      map['action_kind'] = Variable<String>(
        $RulesTable.$converteractionKind.toSql(actionKind),
      );
    }
    map['action_value'] = Variable<String>(actionValue);
    map['enabled'] = Variable<bool>(enabled);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  RulesCompanion toCompanion(bool nullToAbsent) {
    return RulesCompanion(
      id: Value(id),
      conditionKind: Value(conditionKind),
      conditionValue: Value(conditionValue),
      actionKind: Value(actionKind),
      actionValue: Value(actionValue),
      enabled: Value(enabled),
      sortOrder: Value(sortOrder),
    );
  }

  factory Rule.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Rule(
      id: serializer.fromJson<String>(json['id']),
      conditionKind: $RulesTable.$converterconditionKind.fromJson(
        serializer.fromJson<String>(json['conditionKind']),
      ),
      conditionValue: serializer.fromJson<String>(json['conditionValue']),
      actionKind: $RulesTable.$converteractionKind.fromJson(
        serializer.fromJson<String>(json['actionKind']),
      ),
      actionValue: serializer.fromJson<String>(json['actionValue']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'conditionKind': serializer.toJson<String>(
        $RulesTable.$converterconditionKind.toJson(conditionKind),
      ),
      'conditionValue': serializer.toJson<String>(conditionValue),
      'actionKind': serializer.toJson<String>(
        $RulesTable.$converteractionKind.toJson(actionKind),
      ),
      'actionValue': serializer.toJson<String>(actionValue),
      'enabled': serializer.toJson<bool>(enabled),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  Rule copyWith({
    String? id,
    RuleConditionKind? conditionKind,
    String? conditionValue,
    RuleActionKind? actionKind,
    String? actionValue,
    bool? enabled,
    int? sortOrder,
  }) => Rule(
    id: id ?? this.id,
    conditionKind: conditionKind ?? this.conditionKind,
    conditionValue: conditionValue ?? this.conditionValue,
    actionKind: actionKind ?? this.actionKind,
    actionValue: actionValue ?? this.actionValue,
    enabled: enabled ?? this.enabled,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  Rule copyWithCompanion(RulesCompanion data) {
    return Rule(
      id: data.id.present ? data.id.value : this.id,
      conditionKind: data.conditionKind.present
          ? data.conditionKind.value
          : this.conditionKind,
      conditionValue: data.conditionValue.present
          ? data.conditionValue.value
          : this.conditionValue,
      actionKind: data.actionKind.present
          ? data.actionKind.value
          : this.actionKind,
      actionValue: data.actionValue.present
          ? data.actionValue.value
          : this.actionValue,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Rule(')
          ..write('id: $id, ')
          ..write('conditionKind: $conditionKind, ')
          ..write('conditionValue: $conditionValue, ')
          ..write('actionKind: $actionKind, ')
          ..write('actionValue: $actionValue, ')
          ..write('enabled: $enabled, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    conditionKind,
    conditionValue,
    actionKind,
    actionValue,
    enabled,
    sortOrder,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Rule &&
          other.id == this.id &&
          other.conditionKind == this.conditionKind &&
          other.conditionValue == this.conditionValue &&
          other.actionKind == this.actionKind &&
          other.actionValue == this.actionValue &&
          other.enabled == this.enabled &&
          other.sortOrder == this.sortOrder);
}

class RulesCompanion extends UpdateCompanion<Rule> {
  final Value<String> id;
  final Value<RuleConditionKind> conditionKind;
  final Value<String> conditionValue;
  final Value<RuleActionKind> actionKind;
  final Value<String> actionValue;
  final Value<bool> enabled;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const RulesCompanion({
    this.id = const Value.absent(),
    this.conditionKind = const Value.absent(),
    this.conditionValue = const Value.absent(),
    this.actionKind = const Value.absent(),
    this.actionValue = const Value.absent(),
    this.enabled = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RulesCompanion.insert({
    required String id,
    required RuleConditionKind conditionKind,
    required String conditionValue,
    required RuleActionKind actionKind,
    required String actionValue,
    this.enabled = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       conditionKind = Value(conditionKind),
       conditionValue = Value(conditionValue),
       actionKind = Value(actionKind),
       actionValue = Value(actionValue);
  static Insertable<Rule> custom({
    Expression<String>? id,
    Expression<String>? conditionKind,
    Expression<String>? conditionValue,
    Expression<String>? actionKind,
    Expression<String>? actionValue,
    Expression<bool>? enabled,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (conditionKind != null) 'condition_kind': conditionKind,
      if (conditionValue != null) 'condition_value': conditionValue,
      if (actionKind != null) 'action_kind': actionKind,
      if (actionValue != null) 'action_value': actionValue,
      if (enabled != null) 'enabled': enabled,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RulesCompanion copyWith({
    Value<String>? id,
    Value<RuleConditionKind>? conditionKind,
    Value<String>? conditionValue,
    Value<RuleActionKind>? actionKind,
    Value<String>? actionValue,
    Value<bool>? enabled,
    Value<int>? sortOrder,
    Value<int>? rowid,
  }) {
    return RulesCompanion(
      id: id ?? this.id,
      conditionKind: conditionKind ?? this.conditionKind,
      conditionValue: conditionValue ?? this.conditionValue,
      actionKind: actionKind ?? this.actionKind,
      actionValue: actionValue ?? this.actionValue,
      enabled: enabled ?? this.enabled,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (conditionKind.present) {
      map['condition_kind'] = Variable<String>(
        $RulesTable.$converterconditionKind.toSql(conditionKind.value),
      );
    }
    if (conditionValue.present) {
      map['condition_value'] = Variable<String>(conditionValue.value);
    }
    if (actionKind.present) {
      map['action_kind'] = Variable<String>(
        $RulesTable.$converteractionKind.toSql(actionKind.value),
      );
    }
    if (actionValue.present) {
      map['action_value'] = Variable<String>(actionValue.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RulesCompanion(')
          ..write('id: $id, ')
          ..write('conditionKind: $conditionKind, ')
          ..write('conditionValue: $conditionValue, ')
          ..write('actionKind: $actionKind, ')
          ..write('actionValue: $actionValue, ')
          ..write('enabled: $enabled, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LinksTable extends Links with TableInfo<$LinksTable, Link> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LinksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _fromIdMeta = const VerificationMeta('fromId');
  @override
  late final GeneratedColumn<String> fromId = GeneratedColumn<String>(
    'from_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _toIdMeta = const VerificationMeta('toId');
  @override
  late final GeneratedColumn<String> toId = GeneratedColumn<String>(
    'to_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<LinkSource, String> source =
      GeneratedColumn<String>(
        'source',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<LinkSource>($LinksTable.$convertersource);
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
    'reason',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rejectedMeta = const VerificationMeta(
    'rejected',
  );
  @override
  late final GeneratedColumn<bool> rejected = GeneratedColumn<bool>(
    'rejected',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("rejected" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    fromId,
    toId,
    source,
    reason,
    rejected,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'links';
  @override
  VerificationContext validateIntegrity(
    Insertable<Link> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('from_id')) {
      context.handle(
        _fromIdMeta,
        fromId.isAcceptableOrUnknown(data['from_id']!, _fromIdMeta),
      );
    } else if (isInserting) {
      context.missing(_fromIdMeta);
    }
    if (data.containsKey('to_id')) {
      context.handle(
        _toIdMeta,
        toId.isAcceptableOrUnknown(data['to_id']!, _toIdMeta),
      );
    } else if (isInserting) {
      context.missing(_toIdMeta);
    }
    if (data.containsKey('reason')) {
      context.handle(
        _reasonMeta,
        reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta),
      );
    }
    if (data.containsKey('rejected')) {
      context.handle(
        _rejectedMeta,
        rejected.isAcceptableOrUnknown(data['rejected']!, _rejectedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {fromId, toId};
  @override
  Link map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Link(
      fromId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}from_id'],
      )!,
      toId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}to_id'],
      )!,
      source: $LinksTable.$convertersource.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}source'],
        )!,
      ),
      reason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason'],
      ),
      rejected: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}rejected'],
      )!,
    );
  }

  @override
  $LinksTable createAlias(String alias) {
    return $LinksTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<LinkSource, String, String> $convertersource =
      const EnumNameConverter<LinkSource>(LinkSource.values);
}

class Link extends DataClass implements Insertable<Link> {
  final String fromId;
  final String toId;
  final LinkSource source;
  final String? reason;
  final bool rejected;
  const Link({
    required this.fromId,
    required this.toId,
    required this.source,
    this.reason,
    required this.rejected,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['from_id'] = Variable<String>(fromId);
    map['to_id'] = Variable<String>(toId);
    {
      map['source'] = Variable<String>(
        $LinksTable.$convertersource.toSql(source),
      );
    }
    if (!nullToAbsent || reason != null) {
      map['reason'] = Variable<String>(reason);
    }
    map['rejected'] = Variable<bool>(rejected);
    return map;
  }

  LinksCompanion toCompanion(bool nullToAbsent) {
    return LinksCompanion(
      fromId: Value(fromId),
      toId: Value(toId),
      source: Value(source),
      reason: reason == null && nullToAbsent
          ? const Value.absent()
          : Value(reason),
      rejected: Value(rejected),
    );
  }

  factory Link.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Link(
      fromId: serializer.fromJson<String>(json['fromId']),
      toId: serializer.fromJson<String>(json['toId']),
      source: $LinksTable.$convertersource.fromJson(
        serializer.fromJson<String>(json['source']),
      ),
      reason: serializer.fromJson<String?>(json['reason']),
      rejected: serializer.fromJson<bool>(json['rejected']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'fromId': serializer.toJson<String>(fromId),
      'toId': serializer.toJson<String>(toId),
      'source': serializer.toJson<String>(
        $LinksTable.$convertersource.toJson(source),
      ),
      'reason': serializer.toJson<String?>(reason),
      'rejected': serializer.toJson<bool>(rejected),
    };
  }

  Link copyWith({
    String? fromId,
    String? toId,
    LinkSource? source,
    Value<String?> reason = const Value.absent(),
    bool? rejected,
  }) => Link(
    fromId: fromId ?? this.fromId,
    toId: toId ?? this.toId,
    source: source ?? this.source,
    reason: reason.present ? reason.value : this.reason,
    rejected: rejected ?? this.rejected,
  );
  Link copyWithCompanion(LinksCompanion data) {
    return Link(
      fromId: data.fromId.present ? data.fromId.value : this.fromId,
      toId: data.toId.present ? data.toId.value : this.toId,
      source: data.source.present ? data.source.value : this.source,
      reason: data.reason.present ? data.reason.value : this.reason,
      rejected: data.rejected.present ? data.rejected.value : this.rejected,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Link(')
          ..write('fromId: $fromId, ')
          ..write('toId: $toId, ')
          ..write('source: $source, ')
          ..write('reason: $reason, ')
          ..write('rejected: $rejected')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(fromId, toId, source, reason, rejected);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Link &&
          other.fromId == this.fromId &&
          other.toId == this.toId &&
          other.source == this.source &&
          other.reason == this.reason &&
          other.rejected == this.rejected);
}

class LinksCompanion extends UpdateCompanion<Link> {
  final Value<String> fromId;
  final Value<String> toId;
  final Value<LinkSource> source;
  final Value<String?> reason;
  final Value<bool> rejected;
  final Value<int> rowid;
  const LinksCompanion({
    this.fromId = const Value.absent(),
    this.toId = const Value.absent(),
    this.source = const Value.absent(),
    this.reason = const Value.absent(),
    this.rejected = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LinksCompanion.insert({
    required String fromId,
    required String toId,
    required LinkSource source,
    this.reason = const Value.absent(),
    this.rejected = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : fromId = Value(fromId),
       toId = Value(toId),
       source = Value(source);
  static Insertable<Link> custom({
    Expression<String>? fromId,
    Expression<String>? toId,
    Expression<String>? source,
    Expression<String>? reason,
    Expression<bool>? rejected,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (fromId != null) 'from_id': fromId,
      if (toId != null) 'to_id': toId,
      if (source != null) 'source': source,
      if (reason != null) 'reason': reason,
      if (rejected != null) 'rejected': rejected,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LinksCompanion copyWith({
    Value<String>? fromId,
    Value<String>? toId,
    Value<LinkSource>? source,
    Value<String?>? reason,
    Value<bool>? rejected,
    Value<int>? rowid,
  }) {
    return LinksCompanion(
      fromId: fromId ?? this.fromId,
      toId: toId ?? this.toId,
      source: source ?? this.source,
      reason: reason ?? this.reason,
      rejected: rejected ?? this.rejected,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (fromId.present) {
      map['from_id'] = Variable<String>(fromId.value);
    }
    if (toId.present) {
      map['to_id'] = Variable<String>(toId.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(
        $LinksTable.$convertersource.toSql(source.value),
      );
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (rejected.present) {
      map['rejected'] = Variable<bool>(rejected.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LinksCompanion(')
          ..write('fromId: $fromId, ')
          ..write('toId: $toId, ')
          ..write('source: $source, ')
          ..write('reason: $reason, ')
          ..write('rejected: $rejected, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AiJobsTable extends AiJobs with TableInfo<$AiJobsTable, AiJob> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AiJobsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _nextTryAtMeta = const VerificationMeta(
    'nextTryAt',
  );
  @override
  late final GeneratedColumn<DateTime> nextTryAt = GeneratedColumn<DateTime>(
    'next_try_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    itemId,
    kind,
    attempts,
    nextTryAt,
    lastError,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ai_jobs';
  @override
  VerificationContext validateIntegrity(
    Insertable<AiJob> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('next_try_at')) {
      context.handle(
        _nextTryAtMeta,
        nextTryAt.isAcceptableOrUnknown(data['next_try_at']!, _nextTryAtMeta),
      );
    } else if (isInserting) {
      context.missing(_nextTryAtMeta);
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {itemId};
  @override
  AiJob map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AiJob(
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      nextTryAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_try_at'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
    );
  }

  @override
  $AiJobsTable createAlias(String alias) {
    return $AiJobsTable(attachedDatabase, alias);
  }
}

class AiJob extends DataClass implements Insertable<AiJob> {
  final String itemId;
  final String kind;
  final int attempts;
  final DateTime nextTryAt;
  final String? lastError;
  const AiJob({
    required this.itemId,
    required this.kind,
    required this.attempts,
    required this.nextTryAt,
    this.lastError,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['item_id'] = Variable<String>(itemId);
    map['kind'] = Variable<String>(kind);
    map['attempts'] = Variable<int>(attempts);
    map['next_try_at'] = Variable<DateTime>(nextTryAt);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    return map;
  }

  AiJobsCompanion toCompanion(bool nullToAbsent) {
    return AiJobsCompanion(
      itemId: Value(itemId),
      kind: Value(kind),
      attempts: Value(attempts),
      nextTryAt: Value(nextTryAt),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
    );
  }

  factory AiJob.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AiJob(
      itemId: serializer.fromJson<String>(json['itemId']),
      kind: serializer.fromJson<String>(json['kind']),
      attempts: serializer.fromJson<int>(json['attempts']),
      nextTryAt: serializer.fromJson<DateTime>(json['nextTryAt']),
      lastError: serializer.fromJson<String?>(json['lastError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'itemId': serializer.toJson<String>(itemId),
      'kind': serializer.toJson<String>(kind),
      'attempts': serializer.toJson<int>(attempts),
      'nextTryAt': serializer.toJson<DateTime>(nextTryAt),
      'lastError': serializer.toJson<String?>(lastError),
    };
  }

  AiJob copyWith({
    String? itemId,
    String? kind,
    int? attempts,
    DateTime? nextTryAt,
    Value<String?> lastError = const Value.absent(),
  }) => AiJob(
    itemId: itemId ?? this.itemId,
    kind: kind ?? this.kind,
    attempts: attempts ?? this.attempts,
    nextTryAt: nextTryAt ?? this.nextTryAt,
    lastError: lastError.present ? lastError.value : this.lastError,
  );
  AiJob copyWithCompanion(AiJobsCompanion data) {
    return AiJob(
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      kind: data.kind.present ? data.kind.value : this.kind,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      nextTryAt: data.nextTryAt.present ? data.nextTryAt.value : this.nextTryAt,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AiJob(')
          ..write('itemId: $itemId, ')
          ..write('kind: $kind, ')
          ..write('attempts: $attempts, ')
          ..write('nextTryAt: $nextTryAt, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(itemId, kind, attempts, nextTryAt, lastError);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiJob &&
          other.itemId == this.itemId &&
          other.kind == this.kind &&
          other.attempts == this.attempts &&
          other.nextTryAt == this.nextTryAt &&
          other.lastError == this.lastError);
}

class AiJobsCompanion extends UpdateCompanion<AiJob> {
  final Value<String> itemId;
  final Value<String> kind;
  final Value<int> attempts;
  final Value<DateTime> nextTryAt;
  final Value<String?> lastError;
  final Value<int> rowid;
  const AiJobsCompanion({
    this.itemId = const Value.absent(),
    this.kind = const Value.absent(),
    this.attempts = const Value.absent(),
    this.nextTryAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AiJobsCompanion.insert({
    required String itemId,
    required String kind,
    this.attempts = const Value.absent(),
    required DateTime nextTryAt,
    this.lastError = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : itemId = Value(itemId),
       kind = Value(kind),
       nextTryAt = Value(nextTryAt);
  static Insertable<AiJob> custom({
    Expression<String>? itemId,
    Expression<String>? kind,
    Expression<int>? attempts,
    Expression<DateTime>? nextTryAt,
    Expression<String>? lastError,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (itemId != null) 'item_id': itemId,
      if (kind != null) 'kind': kind,
      if (attempts != null) 'attempts': attempts,
      if (nextTryAt != null) 'next_try_at': nextTryAt,
      if (lastError != null) 'last_error': lastError,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AiJobsCompanion copyWith({
    Value<String>? itemId,
    Value<String>? kind,
    Value<int>? attempts,
    Value<DateTime>? nextTryAt,
    Value<String?>? lastError,
    Value<int>? rowid,
  }) {
    return AiJobsCompanion(
      itemId: itemId ?? this.itemId,
      kind: kind ?? this.kind,
      attempts: attempts ?? this.attempts,
      nextTryAt: nextTryAt ?? this.nextTryAt,
      lastError: lastError ?? this.lastError,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (nextTryAt.present) {
      map['next_try_at'] = Variable<DateTime>(nextTryAt.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AiJobsCompanion(')
          ..write('itemId: $itemId, ')
          ..write('kind: $kind, ')
          ..write('attempts: $attempts, ')
          ..write('nextTryAt: $nextTryAt, ')
          ..write('lastError: $lastError, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AiLogTable extends AiLog with TableInfo<$AiLogTable, AiLogData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AiLogTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _atMeta = const VerificationMeta('at');
  @override
  late final GeneratedColumn<DateTime> at = GeneratedColumn<DateTime>(
    'at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _requestMeta = const VerificationMeta(
    'request',
  );
  @override
  late final GeneratedColumn<String> request = GeneratedColumn<String>(
    'request',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _responseMeta = const VerificationMeta(
    'response',
  );
  @override
  late final GeneratedColumn<String> response = GeneratedColumn<String>(
    'response',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorMeta = const VerificationMeta('error');
  @override
  late final GeneratedColumn<String> error = GeneratedColumn<String>(
    'error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    at,
    itemId,
    request,
    response,
    error,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ai_log';
  @override
  VerificationContext validateIntegrity(
    Insertable<AiLogData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('at')) {
      context.handle(_atMeta, at.isAcceptableOrUnknown(data['at']!, _atMeta));
    } else if (isInserting) {
      context.missing(_atMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    }
    if (data.containsKey('request')) {
      context.handle(
        _requestMeta,
        request.isAcceptableOrUnknown(data['request']!, _requestMeta),
      );
    } else if (isInserting) {
      context.missing(_requestMeta);
    }
    if (data.containsKey('response')) {
      context.handle(
        _responseMeta,
        response.isAcceptableOrUnknown(data['response']!, _responseMeta),
      );
    }
    if (data.containsKey('error')) {
      context.handle(
        _errorMeta,
        error.isAcceptableOrUnknown(data['error']!, _errorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AiLogData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AiLogData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      at: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}at'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      ),
      request: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}request'],
      )!,
      response: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}response'],
      ),
      error: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error'],
      ),
    );
  }

  @override
  $AiLogTable createAlias(String alias) {
    return $AiLogTable(attachedDatabase, alias);
  }
}

class AiLogData extends DataClass implements Insertable<AiLogData> {
  final int id;
  final DateTime at;
  final String? itemId;
  final String request;
  final String? response;
  final String? error;
  const AiLogData({
    required this.id,
    required this.at,
    this.itemId,
    required this.request,
    this.response,
    this.error,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['at'] = Variable<DateTime>(at);
    if (!nullToAbsent || itemId != null) {
      map['item_id'] = Variable<String>(itemId);
    }
    map['request'] = Variable<String>(request);
    if (!nullToAbsent || response != null) {
      map['response'] = Variable<String>(response);
    }
    if (!nullToAbsent || error != null) {
      map['error'] = Variable<String>(error);
    }
    return map;
  }

  AiLogCompanion toCompanion(bool nullToAbsent) {
    return AiLogCompanion(
      id: Value(id),
      at: Value(at),
      itemId: itemId == null && nullToAbsent
          ? const Value.absent()
          : Value(itemId),
      request: Value(request),
      response: response == null && nullToAbsent
          ? const Value.absent()
          : Value(response),
      error: error == null && nullToAbsent
          ? const Value.absent()
          : Value(error),
    );
  }

  factory AiLogData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AiLogData(
      id: serializer.fromJson<int>(json['id']),
      at: serializer.fromJson<DateTime>(json['at']),
      itemId: serializer.fromJson<String?>(json['itemId']),
      request: serializer.fromJson<String>(json['request']),
      response: serializer.fromJson<String?>(json['response']),
      error: serializer.fromJson<String?>(json['error']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'at': serializer.toJson<DateTime>(at),
      'itemId': serializer.toJson<String?>(itemId),
      'request': serializer.toJson<String>(request),
      'response': serializer.toJson<String?>(response),
      'error': serializer.toJson<String?>(error),
    };
  }

  AiLogData copyWith({
    int? id,
    DateTime? at,
    Value<String?> itemId = const Value.absent(),
    String? request,
    Value<String?> response = const Value.absent(),
    Value<String?> error = const Value.absent(),
  }) => AiLogData(
    id: id ?? this.id,
    at: at ?? this.at,
    itemId: itemId.present ? itemId.value : this.itemId,
    request: request ?? this.request,
    response: response.present ? response.value : this.response,
    error: error.present ? error.value : this.error,
  );
  AiLogData copyWithCompanion(AiLogCompanion data) {
    return AiLogData(
      id: data.id.present ? data.id.value : this.id,
      at: data.at.present ? data.at.value : this.at,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      request: data.request.present ? data.request.value : this.request,
      response: data.response.present ? data.response.value : this.response,
      error: data.error.present ? data.error.value : this.error,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AiLogData(')
          ..write('id: $id, ')
          ..write('at: $at, ')
          ..write('itemId: $itemId, ')
          ..write('request: $request, ')
          ..write('response: $response, ')
          ..write('error: $error')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, at, itemId, request, response, error);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiLogData &&
          other.id == this.id &&
          other.at == this.at &&
          other.itemId == this.itemId &&
          other.request == this.request &&
          other.response == this.response &&
          other.error == this.error);
}

class AiLogCompanion extends UpdateCompanion<AiLogData> {
  final Value<int> id;
  final Value<DateTime> at;
  final Value<String?> itemId;
  final Value<String> request;
  final Value<String?> response;
  final Value<String?> error;
  const AiLogCompanion({
    this.id = const Value.absent(),
    this.at = const Value.absent(),
    this.itemId = const Value.absent(),
    this.request = const Value.absent(),
    this.response = const Value.absent(),
    this.error = const Value.absent(),
  });
  AiLogCompanion.insert({
    this.id = const Value.absent(),
    required DateTime at,
    this.itemId = const Value.absent(),
    required String request,
    this.response = const Value.absent(),
    this.error = const Value.absent(),
  }) : at = Value(at),
       request = Value(request);
  static Insertable<AiLogData> custom({
    Expression<int>? id,
    Expression<DateTime>? at,
    Expression<String>? itemId,
    Expression<String>? request,
    Expression<String>? response,
    Expression<String>? error,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (at != null) 'at': at,
      if (itemId != null) 'item_id': itemId,
      if (request != null) 'request': request,
      if (response != null) 'response': response,
      if (error != null) 'error': error,
    });
  }

  AiLogCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? at,
    Value<String?>? itemId,
    Value<String>? request,
    Value<String?>? response,
    Value<String?>? error,
  }) {
    return AiLogCompanion(
      id: id ?? this.id,
      at: at ?? this.at,
      itemId: itemId ?? this.itemId,
      request: request ?? this.request,
      response: response ?? this.response,
      error: error ?? this.error,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (at.present) {
      map['at'] = Variable<DateTime>(at.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (request.present) {
      map['request'] = Variable<String>(request.value);
    }
    if (response.present) {
      map['response'] = Variable<String>(response.value);
    }
    if (error.present) {
      map['error'] = Variable<String>(error.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AiLogCompanion(')
          ..write('id: $id, ')
          ..write('at: $at, ')
          ..write('itemId: $itemId, ')
          ..write('request: $request, ')
          ..write('response: $response, ')
          ..write('error: $error')
          ..write(')'))
        .toString();
  }
}

class $WordStatsTable extends WordStats
    with TableInfo<$WordStatsTable, WordStat> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WordStatsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _wordMeta = const VerificationMeta('word');
  @override
  late final GeneratedColumn<String> word = GeneratedColumn<String>(
    'word',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetKindMeta = const VerificationMeta(
    'targetKind',
  );
  @override
  late final GeneratedColumn<String> targetKind = GeneratedColumn<String>(
    'target_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetIdMeta = const VerificationMeta(
    'targetId',
  );
  @override
  late final GeneratedColumn<String> targetId = GeneratedColumn<String>(
    'target_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _countMeta = const VerificationMeta('count');
  @override
  late final GeneratedColumn<int> count = GeneratedColumn<int>(
    'count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [word, targetKind, targetId, count];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'word_stats';
  @override
  VerificationContext validateIntegrity(
    Insertable<WordStat> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('word')) {
      context.handle(
        _wordMeta,
        word.isAcceptableOrUnknown(data['word']!, _wordMeta),
      );
    } else if (isInserting) {
      context.missing(_wordMeta);
    }
    if (data.containsKey('target_kind')) {
      context.handle(
        _targetKindMeta,
        targetKind.isAcceptableOrUnknown(data['target_kind']!, _targetKindMeta),
      );
    } else if (isInserting) {
      context.missing(_targetKindMeta);
    }
    if (data.containsKey('target_id')) {
      context.handle(
        _targetIdMeta,
        targetId.isAcceptableOrUnknown(data['target_id']!, _targetIdMeta),
      );
    } else if (isInserting) {
      context.missing(_targetIdMeta);
    }
    if (data.containsKey('count')) {
      context.handle(
        _countMeta,
        count.isAcceptableOrUnknown(data['count']!, _countMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {word, targetKind, targetId};
  @override
  WordStat map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WordStat(
      word: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}word'],
      )!,
      targetKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_kind'],
      )!,
      targetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_id'],
      )!,
      count: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}count'],
      )!,
    );
  }

  @override
  $WordStatsTable createAlias(String alias) {
    return $WordStatsTable(attachedDatabase, alias);
  }
}

class WordStat extends DataClass implements Insertable<WordStat> {
  final String word;
  final String targetKind;
  final String targetId;
  final int count;
  const WordStat({
    required this.word,
    required this.targetKind,
    required this.targetId,
    required this.count,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['word'] = Variable<String>(word);
    map['target_kind'] = Variable<String>(targetKind);
    map['target_id'] = Variable<String>(targetId);
    map['count'] = Variable<int>(count);
    return map;
  }

  WordStatsCompanion toCompanion(bool nullToAbsent) {
    return WordStatsCompanion(
      word: Value(word),
      targetKind: Value(targetKind),
      targetId: Value(targetId),
      count: Value(count),
    );
  }

  factory WordStat.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WordStat(
      word: serializer.fromJson<String>(json['word']),
      targetKind: serializer.fromJson<String>(json['targetKind']),
      targetId: serializer.fromJson<String>(json['targetId']),
      count: serializer.fromJson<int>(json['count']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'word': serializer.toJson<String>(word),
      'targetKind': serializer.toJson<String>(targetKind),
      'targetId': serializer.toJson<String>(targetId),
      'count': serializer.toJson<int>(count),
    };
  }

  WordStat copyWith({
    String? word,
    String? targetKind,
    String? targetId,
    int? count,
  }) => WordStat(
    word: word ?? this.word,
    targetKind: targetKind ?? this.targetKind,
    targetId: targetId ?? this.targetId,
    count: count ?? this.count,
  );
  WordStat copyWithCompanion(WordStatsCompanion data) {
    return WordStat(
      word: data.word.present ? data.word.value : this.word,
      targetKind: data.targetKind.present
          ? data.targetKind.value
          : this.targetKind,
      targetId: data.targetId.present ? data.targetId.value : this.targetId,
      count: data.count.present ? data.count.value : this.count,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WordStat(')
          ..write('word: $word, ')
          ..write('targetKind: $targetKind, ')
          ..write('targetId: $targetId, ')
          ..write('count: $count')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(word, targetKind, targetId, count);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WordStat &&
          other.word == this.word &&
          other.targetKind == this.targetKind &&
          other.targetId == this.targetId &&
          other.count == this.count);
}

class WordStatsCompanion extends UpdateCompanion<WordStat> {
  final Value<String> word;
  final Value<String> targetKind;
  final Value<String> targetId;
  final Value<int> count;
  final Value<int> rowid;
  const WordStatsCompanion({
    this.word = const Value.absent(),
    this.targetKind = const Value.absent(),
    this.targetId = const Value.absent(),
    this.count = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WordStatsCompanion.insert({
    required String word,
    required String targetKind,
    required String targetId,
    this.count = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : word = Value(word),
       targetKind = Value(targetKind),
       targetId = Value(targetId);
  static Insertable<WordStat> custom({
    Expression<String>? word,
    Expression<String>? targetKind,
    Expression<String>? targetId,
    Expression<int>? count,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (word != null) 'word': word,
      if (targetKind != null) 'target_kind': targetKind,
      if (targetId != null) 'target_id': targetId,
      if (count != null) 'count': count,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WordStatsCompanion copyWith({
    Value<String>? word,
    Value<String>? targetKind,
    Value<String>? targetId,
    Value<int>? count,
    Value<int>? rowid,
  }) {
    return WordStatsCompanion(
      word: word ?? this.word,
      targetKind: targetKind ?? this.targetKind,
      targetId: targetId ?? this.targetId,
      count: count ?? this.count,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (word.present) {
      map['word'] = Variable<String>(word.value);
    }
    if (targetKind.present) {
      map['target_kind'] = Variable<String>(targetKind.value);
    }
    if (targetId.present) {
      map['target_id'] = Variable<String>(targetId.value);
    }
    if (count.present) {
      map['count'] = Variable<int>(count.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WordStatsCompanion(')
          ..write('word: $word, ')
          ..write('targetKind: $targetKind, ')
          ..write('targetId: $targetId, ')
          ..write('count: $count, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CorrectionsTable extends Corrections
    with TableInfo<$CorrectionsTable, Correction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CorrectionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fromFolderIdMeta = const VerificationMeta(
    'fromFolderId',
  );
  @override
  late final GeneratedColumn<String> fromFolderId = GeneratedColumn<String>(
    'from_folder_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _toFolderIdMeta = const VerificationMeta(
    'toFolderId',
  );
  @override
  late final GeneratedColumn<String> toFolderId = GeneratedColumn<String>(
    'to_folder_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _atMeta = const VerificationMeta('at');
  @override
  late final GeneratedColumn<DateTime> at = GeneratedColumn<DateTime>(
    'at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    itemId,
    fromFolderId,
    toFolderId,
    at,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'corrections';
  @override
  VerificationContext validateIntegrity(
    Insertable<Correction> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('from_folder_id')) {
      context.handle(
        _fromFolderIdMeta,
        fromFolderId.isAcceptableOrUnknown(
          data['from_folder_id']!,
          _fromFolderIdMeta,
        ),
      );
    }
    if (data.containsKey('to_folder_id')) {
      context.handle(
        _toFolderIdMeta,
        toFolderId.isAcceptableOrUnknown(
          data['to_folder_id']!,
          _toFolderIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_toFolderIdMeta);
    }
    if (data.containsKey('at')) {
      context.handle(_atMeta, at.isAcceptableOrUnknown(data['at']!, _atMeta));
    } else if (isInserting) {
      context.missing(_atMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Correction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Correction(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      fromFolderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}from_folder_id'],
      ),
      toFolderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}to_folder_id'],
      )!,
      at: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}at'],
      )!,
    );
  }

  @override
  $CorrectionsTable createAlias(String alias) {
    return $CorrectionsTable(attachedDatabase, alias);
  }
}

class Correction extends DataClass implements Insertable<Correction> {
  final String id;
  final String itemId;
  final String? fromFolderId;
  final String toFolderId;
  final DateTime at;
  const Correction({
    required this.id,
    required this.itemId,
    this.fromFolderId,
    required this.toFolderId,
    required this.at,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['item_id'] = Variable<String>(itemId);
    if (!nullToAbsent || fromFolderId != null) {
      map['from_folder_id'] = Variable<String>(fromFolderId);
    }
    map['to_folder_id'] = Variable<String>(toFolderId);
    map['at'] = Variable<DateTime>(at);
    return map;
  }

  CorrectionsCompanion toCompanion(bool nullToAbsent) {
    return CorrectionsCompanion(
      id: Value(id),
      itemId: Value(itemId),
      fromFolderId: fromFolderId == null && nullToAbsent
          ? const Value.absent()
          : Value(fromFolderId),
      toFolderId: Value(toFolderId),
      at: Value(at),
    );
  }

  factory Correction.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Correction(
      id: serializer.fromJson<String>(json['id']),
      itemId: serializer.fromJson<String>(json['itemId']),
      fromFolderId: serializer.fromJson<String?>(json['fromFolderId']),
      toFolderId: serializer.fromJson<String>(json['toFolderId']),
      at: serializer.fromJson<DateTime>(json['at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'itemId': serializer.toJson<String>(itemId),
      'fromFolderId': serializer.toJson<String?>(fromFolderId),
      'toFolderId': serializer.toJson<String>(toFolderId),
      'at': serializer.toJson<DateTime>(at),
    };
  }

  Correction copyWith({
    String? id,
    String? itemId,
    Value<String?> fromFolderId = const Value.absent(),
    String? toFolderId,
    DateTime? at,
  }) => Correction(
    id: id ?? this.id,
    itemId: itemId ?? this.itemId,
    fromFolderId: fromFolderId.present ? fromFolderId.value : this.fromFolderId,
    toFolderId: toFolderId ?? this.toFolderId,
    at: at ?? this.at,
  );
  Correction copyWithCompanion(CorrectionsCompanion data) {
    return Correction(
      id: data.id.present ? data.id.value : this.id,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      fromFolderId: data.fromFolderId.present
          ? data.fromFolderId.value
          : this.fromFolderId,
      toFolderId: data.toFolderId.present
          ? data.toFolderId.value
          : this.toFolderId,
      at: data.at.present ? data.at.value : this.at,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Correction(')
          ..write('id: $id, ')
          ..write('itemId: $itemId, ')
          ..write('fromFolderId: $fromFolderId, ')
          ..write('toFolderId: $toFolderId, ')
          ..write('at: $at')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, itemId, fromFolderId, toFolderId, at);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Correction &&
          other.id == this.id &&
          other.itemId == this.itemId &&
          other.fromFolderId == this.fromFolderId &&
          other.toFolderId == this.toFolderId &&
          other.at == this.at);
}

class CorrectionsCompanion extends UpdateCompanion<Correction> {
  final Value<String> id;
  final Value<String> itemId;
  final Value<String?> fromFolderId;
  final Value<String> toFolderId;
  final Value<DateTime> at;
  final Value<int> rowid;
  const CorrectionsCompanion({
    this.id = const Value.absent(),
    this.itemId = const Value.absent(),
    this.fromFolderId = const Value.absent(),
    this.toFolderId = const Value.absent(),
    this.at = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CorrectionsCompanion.insert({
    required String id,
    required String itemId,
    this.fromFolderId = const Value.absent(),
    required String toFolderId,
    required DateTime at,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       itemId = Value(itemId),
       toFolderId = Value(toFolderId),
       at = Value(at);
  static Insertable<Correction> custom({
    Expression<String>? id,
    Expression<String>? itemId,
    Expression<String>? fromFolderId,
    Expression<String>? toFolderId,
    Expression<DateTime>? at,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (itemId != null) 'item_id': itemId,
      if (fromFolderId != null) 'from_folder_id': fromFolderId,
      if (toFolderId != null) 'to_folder_id': toFolderId,
      if (at != null) 'at': at,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CorrectionsCompanion copyWith({
    Value<String>? id,
    Value<String>? itemId,
    Value<String?>? fromFolderId,
    Value<String>? toFolderId,
    Value<DateTime>? at,
    Value<int>? rowid,
  }) {
    return CorrectionsCompanion(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      fromFolderId: fromFolderId ?? this.fromFolderId,
      toFolderId: toFolderId ?? this.toFolderId,
      at: at ?? this.at,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (fromFolderId.present) {
      map['from_folder_id'] = Variable<String>(fromFolderId.value);
    }
    if (toFolderId.present) {
      map['to_folder_id'] = Variable<String>(toFolderId.value);
    }
    if (at.present) {
      map['at'] = Variable<DateTime>(at.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CorrectionsCompanion(')
          ..write('id: $id, ')
          ..write('itemId: $itemId, ')
          ..write('fromFolderId: $fromFolderId, ')
          ..write('toFolderId: $toFolderId, ')
          ..write('at: $at, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CanvasPositionsTable extends CanvasPositions
    with TableInfo<$CanvasPositionsTable, CanvasPosition> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CanvasPositionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _folderIdMeta = const VerificationMeta(
    'folderId',
  );
  @override
  late final GeneratedColumn<String> folderId = GeneratedColumn<String>(
    'folder_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _xMeta = const VerificationMeta('x');
  @override
  late final GeneratedColumn<double> x = GeneratedColumn<double>(
    'x',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _yMeta = const VerificationMeta('y');
  @override
  late final GeneratedColumn<double> y = GeneratedColumn<double>(
    'y',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<double> width = GeneratedColumn<double>(
    'width',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [folderId, itemId, x, y, width];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'canvas_positions';
  @override
  VerificationContext validateIntegrity(
    Insertable<CanvasPosition> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('folder_id')) {
      context.handle(
        _folderIdMeta,
        folderId.isAcceptableOrUnknown(data['folder_id']!, _folderIdMeta),
      );
    } else if (isInserting) {
      context.missing(_folderIdMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('x')) {
      context.handle(_xMeta, x.isAcceptableOrUnknown(data['x']!, _xMeta));
    } else if (isInserting) {
      context.missing(_xMeta);
    }
    if (data.containsKey('y')) {
      context.handle(_yMeta, y.isAcceptableOrUnknown(data['y']!, _yMeta));
    } else if (isInserting) {
      context.missing(_yMeta);
    }
    if (data.containsKey('width')) {
      context.handle(
        _widthMeta,
        width.isAcceptableOrUnknown(data['width']!, _widthMeta),
      );
    } else if (isInserting) {
      context.missing(_widthMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {folderId, itemId};
  @override
  CanvasPosition map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CanvasPosition(
      folderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}folder_id'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      x: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}x'],
      )!,
      y: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}y'],
      )!,
      width: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}width'],
      )!,
    );
  }

  @override
  $CanvasPositionsTable createAlias(String alias) {
    return $CanvasPositionsTable(attachedDatabase, alias);
  }
}

class CanvasPosition extends DataClass implements Insertable<CanvasPosition> {
  final String folderId;
  final String itemId;
  final double x;
  final double y;
  final double width;
  const CanvasPosition({
    required this.folderId,
    required this.itemId,
    required this.x,
    required this.y,
    required this.width,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['folder_id'] = Variable<String>(folderId);
    map['item_id'] = Variable<String>(itemId);
    map['x'] = Variable<double>(x);
    map['y'] = Variable<double>(y);
    map['width'] = Variable<double>(width);
    return map;
  }

  CanvasPositionsCompanion toCompanion(bool nullToAbsent) {
    return CanvasPositionsCompanion(
      folderId: Value(folderId),
      itemId: Value(itemId),
      x: Value(x),
      y: Value(y),
      width: Value(width),
    );
  }

  factory CanvasPosition.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CanvasPosition(
      folderId: serializer.fromJson<String>(json['folderId']),
      itemId: serializer.fromJson<String>(json['itemId']),
      x: serializer.fromJson<double>(json['x']),
      y: serializer.fromJson<double>(json['y']),
      width: serializer.fromJson<double>(json['width']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'folderId': serializer.toJson<String>(folderId),
      'itemId': serializer.toJson<String>(itemId),
      'x': serializer.toJson<double>(x),
      'y': serializer.toJson<double>(y),
      'width': serializer.toJson<double>(width),
    };
  }

  CanvasPosition copyWith({
    String? folderId,
    String? itemId,
    double? x,
    double? y,
    double? width,
  }) => CanvasPosition(
    folderId: folderId ?? this.folderId,
    itemId: itemId ?? this.itemId,
    x: x ?? this.x,
    y: y ?? this.y,
    width: width ?? this.width,
  );
  CanvasPosition copyWithCompanion(CanvasPositionsCompanion data) {
    return CanvasPosition(
      folderId: data.folderId.present ? data.folderId.value : this.folderId,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      x: data.x.present ? data.x.value : this.x,
      y: data.y.present ? data.y.value : this.y,
      width: data.width.present ? data.width.value : this.width,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CanvasPosition(')
          ..write('folderId: $folderId, ')
          ..write('itemId: $itemId, ')
          ..write('x: $x, ')
          ..write('y: $y, ')
          ..write('width: $width')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(folderId, itemId, x, y, width);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CanvasPosition &&
          other.folderId == this.folderId &&
          other.itemId == this.itemId &&
          other.x == this.x &&
          other.y == this.y &&
          other.width == this.width);
}

class CanvasPositionsCompanion extends UpdateCompanion<CanvasPosition> {
  final Value<String> folderId;
  final Value<String> itemId;
  final Value<double> x;
  final Value<double> y;
  final Value<double> width;
  final Value<int> rowid;
  const CanvasPositionsCompanion({
    this.folderId = const Value.absent(),
    this.itemId = const Value.absent(),
    this.x = const Value.absent(),
    this.y = const Value.absent(),
    this.width = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CanvasPositionsCompanion.insert({
    required String folderId,
    required String itemId,
    required double x,
    required double y,
    required double width,
    this.rowid = const Value.absent(),
  }) : folderId = Value(folderId),
       itemId = Value(itemId),
       x = Value(x),
       y = Value(y),
       width = Value(width);
  static Insertable<CanvasPosition> custom({
    Expression<String>? folderId,
    Expression<String>? itemId,
    Expression<double>? x,
    Expression<double>? y,
    Expression<double>? width,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (folderId != null) 'folder_id': folderId,
      if (itemId != null) 'item_id': itemId,
      if (x != null) 'x': x,
      if (y != null) 'y': y,
      if (width != null) 'width': width,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CanvasPositionsCompanion copyWith({
    Value<String>? folderId,
    Value<String>? itemId,
    Value<double>? x,
    Value<double>? y,
    Value<double>? width,
    Value<int>? rowid,
  }) {
    return CanvasPositionsCompanion(
      folderId: folderId ?? this.folderId,
      itemId: itemId ?? this.itemId,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (folderId.present) {
      map['folder_id'] = Variable<String>(folderId.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (x.present) {
      map['x'] = Variable<double>(x.value);
    }
    if (y.present) {
      map['y'] = Variable<double>(y.value);
    }
    if (width.present) {
      map['width'] = Variable<double>(width.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CanvasPositionsCompanion(')
          ..write('folderId: $folderId, ')
          ..write('itemId: $itemId, ')
          ..write('x: $x, ')
          ..write('y: $y, ')
          ..write('width: $width, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ItemsTable items = $ItemsTable(this);
  late final $AttachmentsTable attachments = $AttachmentsTable(this);
  late final $FoldersTable folders = $FoldersTable(this);
  late final $TagsTable tags = $TagsTable(this);
  late final $ItemTagsTable itemTags = $ItemTagsTable(this);
  late final $RulesTable rules = $RulesTable(this);
  late final $LinksTable links = $LinksTable(this);
  late final $AiJobsTable aiJobs = $AiJobsTable(this);
  late final $AiLogTable aiLog = $AiLogTable(this);
  late final $WordStatsTable wordStats = $WordStatsTable(this);
  late final $CorrectionsTable corrections = $CorrectionsTable(this);
  late final $CanvasPositionsTable canvasPositions = $CanvasPositionsTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    items,
    attachments,
    folders,
    tags,
    itemTags,
    rules,
    links,
    aiJobs,
    aiLog,
    wordStats,
    corrections,
    canvasPositions,
  ];
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}

typedef $$ItemsTableCreateCompanionBuilder = ItemsCompanion Function({
  required String id,
  required ItemKind kind,
  required String title,
  Value<String> body,
  Value<String?> url,
  Value<String?> folderId,
  Value<SortState> sortState,
  Value<SortedBy> sortedBy,
  Value<String?> aiDescription,
  Value<String?> transcript,
  Value<String?> coverPath,
  Value<String?> previewText,
  Value<String?> previewSite,
  Value<String?> previewAuthor,
  Value<int?> durationSeconds,
  Value<DateTime?> previewAt,
  Value<DateTime?> reminderAt,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});
typedef $$ItemsTableUpdateCompanionBuilder = ItemsCompanion Function({
  Value<String> id,
  Value<ItemKind> kind,
  Value<String> title,
  Value<String> body,
  Value<String?> url,
  Value<String?> folderId,
  Value<SortState> sortState,
  Value<SortedBy> sortedBy,
  Value<String?> aiDescription,
  Value<String?> transcript,
  Value<String?> coverPath,
  Value<String?> previewText,
  Value<String?> previewSite,
  Value<String?> previewAuthor,
  Value<int?> durationSeconds,
  Value<DateTime?> previewAt,
  Value<DateTime?> reminderAt,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});

class $$ItemsTableFilterComposer extends Composer<_$AppDatabase, $ItemsTable> {
  $$ItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ItemKind, ItemKind, String> get kind =>
      $composableBuilder(
        column: $table.kind,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get folderId => $composableBuilder(
    column: $table.folderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<SortState, SortState, String> get sortState =>
      $composableBuilder(
        column: $table.sortState,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<SortedBy, SortedBy, String> get sortedBy =>
      $composableBuilder(
        column: $table.sortedBy,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get aiDescription => $composableBuilder(
    column: $table.aiDescription,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transcript => $composableBuilder(
    column: $table.transcript,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverPath => $composableBuilder(
    column: $table.coverPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get previewText => $composableBuilder(
    column: $table.previewText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get previewSite => $composableBuilder(
    column: $table.previewSite,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get previewAuthor => $composableBuilder(
    column: $table.previewAuthor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get previewAt => $composableBuilder(
    column: $table.previewAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get reminderAt => $composableBuilder(
    column: $table.reminderAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $ItemsTable> {
  $$ItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get folderId => $composableBuilder(
    column: $table.folderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sortState => $composableBuilder(
    column: $table.sortState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sortedBy => $composableBuilder(
    column: $table.sortedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get aiDescription => $composableBuilder(
    column: $table.aiDescription,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transcript => $composableBuilder(
    column: $table.transcript,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverPath => $composableBuilder(
    column: $table.coverPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get previewText => $composableBuilder(
    column: $table.previewText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get previewSite => $composableBuilder(
    column: $table.previewSite,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get previewAuthor => $composableBuilder(
    column: $table.previewAuthor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get previewAt => $composableBuilder(
    column: $table.previewAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get reminderAt => $composableBuilder(
    column: $table.reminderAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ItemsTable> {
  $$ItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ItemKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get folderId =>
      $composableBuilder(column: $table.folderId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<SortState, String> get sortState =>
      $composableBuilder(column: $table.sortState, builder: (column) => column);

  GeneratedColumnWithTypeConverter<SortedBy, String> get sortedBy =>
      $composableBuilder(column: $table.sortedBy, builder: (column) => column);

  GeneratedColumn<String> get aiDescription => $composableBuilder(
    column: $table.aiDescription,
    builder: (column) => column,
  );

  GeneratedColumn<String> get transcript => $composableBuilder(
    column: $table.transcript,
    builder: (column) => column,
  );

  GeneratedColumn<String> get coverPath =>
      $composableBuilder(column: $table.coverPath, builder: (column) => column);

  GeneratedColumn<String> get previewText => $composableBuilder(
    column: $table.previewText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get previewSite => $composableBuilder(
    column: $table.previewSite,
    builder: (column) => column,
  );

  GeneratedColumn<String> get previewAuthor => $composableBuilder(
    column: $table.previewAuthor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get previewAt =>
      $composableBuilder(column: $table.previewAt, builder: (column) => column);

  GeneratedColumn<DateTime> get reminderAt => $composableBuilder(
    column: $table.reminderAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$ItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ItemsTable,
          Item,
          $$ItemsTableFilterComposer,
          $$ItemsTableOrderingComposer,
          $$ItemsTableAnnotationComposer,
          $$ItemsTableCreateCompanionBuilder,
          $$ItemsTableUpdateCompanionBuilder,
          (Item, BaseReferences<_$AppDatabase, $ItemsTable, Item>),
          Item,
          PrefetchHooks Function()
        > {
  $$ItemsTableTableManager(_$AppDatabase db, $ItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<ItemKind> kind = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<String?> url = const Value.absent(),
                Value<String?> folderId = const Value.absent(),
                Value<SortState> sortState = const Value.absent(),
                Value<SortedBy> sortedBy = const Value.absent(),
                Value<String?> aiDescription = const Value.absent(),
                Value<String?> transcript = const Value.absent(),
                Value<String?> coverPath = const Value.absent(),
                Value<String?> previewText = const Value.absent(),
                Value<String?> previewSite = const Value.absent(),
                Value<String?> previewAuthor = const Value.absent(),
                Value<int?> durationSeconds = const Value.absent(),
                Value<DateTime?> previewAt = const Value.absent(),
                Value<DateTime?> reminderAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ItemsCompanion(
                id: id,
                kind: kind,
                title: title,
                body: body,
                url: url,
                folderId: folderId,
                sortState: sortState,
                sortedBy: sortedBy,
                aiDescription: aiDescription,
                transcript: transcript,
                coverPath: coverPath,
                previewText: previewText,
                previewSite: previewSite,
                previewAuthor: previewAuthor,
                durationSeconds: durationSeconds,
                previewAt: previewAt,
                reminderAt: reminderAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required ItemKind kind,
                required String title,
                Value<String> body = const Value.absent(),
                Value<String?> url = const Value.absent(),
                Value<String?> folderId = const Value.absent(),
                Value<SortState> sortState = const Value.absent(),
                Value<SortedBy> sortedBy = const Value.absent(),
                Value<String?> aiDescription = const Value.absent(),
                Value<String?> transcript = const Value.absent(),
                Value<String?> coverPath = const Value.absent(),
                Value<String?> previewText = const Value.absent(),
                Value<String?> previewSite = const Value.absent(),
                Value<String?> previewAuthor = const Value.absent(),
                Value<int?> durationSeconds = const Value.absent(),
                Value<DateTime?> previewAt = const Value.absent(),
                Value<DateTime?> reminderAt = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ItemsCompanion.insert(
                id: id,
                kind: kind,
                title: title,
                body: body,
                url: url,
                folderId: folderId,
                sortState: sortState,
                sortedBy: sortedBy,
                aiDescription: aiDescription,
                transcript: transcript,
                coverPath: coverPath,
                previewText: previewText,
                previewSite: previewSite,
                previewAuthor: previewAuthor,
                durationSeconds: durationSeconds,
                previewAt: previewAt,
                reminderAt: reminderAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ItemsTable, Item>(table),
                  BaseReferences<_$AppDatabase, $ItemsTable, Item>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ItemsTable,
      Item,
      $$ItemsTableFilterComposer,
      $$ItemsTableOrderingComposer,
      $$ItemsTableAnnotationComposer,
      $$ItemsTableCreateCompanionBuilder,
      $$ItemsTableUpdateCompanionBuilder,
      (Item, BaseReferences<_$AppDatabase, $ItemsTable, Item>),
      Item,
      PrefetchHooks Function()
    >;
typedef $$AttachmentsTableCreateCompanionBuilder =
    AttachmentsCompanion Function({
      required String id,
      required String itemId,
      required String path,
      required String mime,
      required int size,
      Value<int?> width,
      Value<int?> height,
      Value<String?> thumbPath,
      Value<int> position,
      Value<int> rowid,
    });
typedef $$AttachmentsTableUpdateCompanionBuilder =
    AttachmentsCompanion Function({
      Value<String> id,
      Value<String> itemId,
      Value<String> path,
      Value<String> mime,
      Value<int> size,
      Value<int?> width,
      Value<int?> height,
      Value<String?> thumbPath,
      Value<int> position,
      Value<int> rowid,
    });

class $$AttachmentsTableFilterComposer
    extends Composer<_$AppDatabase, $AttachmentsTable> {
  $$AttachmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mime => $composableBuilder(
    column: $table.mime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get thumbPath => $composableBuilder(
    column: $table.thumbPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AttachmentsTableOrderingComposer
    extends Composer<_$AppDatabase, $AttachmentsTable> {
  $$AttachmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mime => $composableBuilder(
    column: $table.mime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get thumbPath => $composableBuilder(
    column: $table.thumbPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AttachmentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AttachmentsTable> {
  $$AttachmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get mime =>
      $composableBuilder(column: $table.mime, builder: (column) => column);

  GeneratedColumn<int> get size =>
      $composableBuilder(column: $table.size, builder: (column) => column);

  GeneratedColumn<int> get width =>
      $composableBuilder(column: $table.width, builder: (column) => column);

  GeneratedColumn<int> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);

  GeneratedColumn<String> get thumbPath =>
      $composableBuilder(column: $table.thumbPath, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);
}

class $$AttachmentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AttachmentsTable,
          Attachment,
          $$AttachmentsTableFilterComposer,
          $$AttachmentsTableOrderingComposer,
          $$AttachmentsTableAnnotationComposer,
          $$AttachmentsTableCreateCompanionBuilder,
          $$AttachmentsTableUpdateCompanionBuilder,
          (
            Attachment,
            BaseReferences<_$AppDatabase, $AttachmentsTable, Attachment>,
          ),
          Attachment,
          PrefetchHooks Function()
        > {
  $$AttachmentsTableTableManager(_$AppDatabase db, $AttachmentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AttachmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AttachmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AttachmentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> itemId = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<String> mime = const Value.absent(),
                Value<int> size = const Value.absent(),
                Value<int?> width = const Value.absent(),
                Value<int?> height = const Value.absent(),
                Value<String?> thumbPath = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AttachmentsCompanion(
                id: id,
                itemId: itemId,
                path: path,
                mime: mime,
                size: size,
                width: width,
                height: height,
                thumbPath: thumbPath,
                position: position,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String itemId,
                required String path,
                required String mime,
                required int size,
                Value<int?> width = const Value.absent(),
                Value<int?> height = const Value.absent(),
                Value<String?> thumbPath = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AttachmentsCompanion.insert(
                id: id,
                itemId: itemId,
                path: path,
                mime: mime,
                size: size,
                width: width,
                height: height,
                thumbPath: thumbPath,
                position: position,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AttachmentsTable, Attachment>(table),
                  BaseReferences<_$AppDatabase, $AttachmentsTable, Attachment>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AttachmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AttachmentsTable,
      Attachment,
      $$AttachmentsTableFilterComposer,
      $$AttachmentsTableOrderingComposer,
      $$AttachmentsTableAnnotationComposer,
      $$AttachmentsTableCreateCompanionBuilder,
      $$AttachmentsTableUpdateCompanionBuilder,
      (
        Attachment,
        BaseReferences<_$AppDatabase, $AttachmentsTable, Attachment>,
      ),
      Attachment,
      PrefetchHooks Function()
    >;
typedef $$FoldersTableCreateCompanionBuilder = FoldersCompanion Function({
  required String id,
  required String name,
  required String icon,
  required String shape,
  Value<int> sortOrder,
  Value<bool> createdByAi,
  Value<FolderView> view,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});
typedef $$FoldersTableUpdateCompanionBuilder = FoldersCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> icon,
  Value<String> shape,
  Value<int> sortOrder,
  Value<bool> createdByAi,
  Value<FolderView> view,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});

class $$FoldersTableFilterComposer
    extends Composer<_$AppDatabase, $FoldersTable> {
  $$FoldersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get shape => $composableBuilder(
    column: $table.shape,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get createdByAi => $composableBuilder(
    column: $table.createdByAi,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<FolderView, FolderView, String> get view =>
      $composableBuilder(
        column: $table.view,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FoldersTableOrderingComposer
    extends Composer<_$AppDatabase, $FoldersTable> {
  $$FoldersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get shape => $composableBuilder(
    column: $table.shape,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get createdByAi => $composableBuilder(
    column: $table.createdByAi,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get view => $composableBuilder(
    column: $table.view,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FoldersTableAnnotationComposer
    extends Composer<_$AppDatabase, $FoldersTable> {
  $$FoldersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<String> get shape =>
      $composableBuilder(column: $table.shape, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<bool> get createdByAi => $composableBuilder(
    column: $table.createdByAi,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<FolderView, String> get view =>
      $composableBuilder(column: $table.view, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$FoldersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FoldersTable,
          Folder,
          $$FoldersTableFilterComposer,
          $$FoldersTableOrderingComposer,
          $$FoldersTableAnnotationComposer,
          $$FoldersTableCreateCompanionBuilder,
          $$FoldersTableUpdateCompanionBuilder,
          (Folder, BaseReferences<_$AppDatabase, $FoldersTable, Folder>),
          Folder,
          PrefetchHooks Function()
        > {
  $$FoldersTableTableManager(_$AppDatabase db, $FoldersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FoldersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FoldersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FoldersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> icon = const Value.absent(),
                Value<String> shape = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> createdByAi = const Value.absent(),
                Value<FolderView> view = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FoldersCompanion(
                id: id,
                name: name,
                icon: icon,
                shape: shape,
                sortOrder: sortOrder,
                createdByAi: createdByAi,
                view: view,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String icon,
                required String shape,
                Value<int> sortOrder = const Value.absent(),
                Value<bool> createdByAi = const Value.absent(),
                Value<FolderView> view = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FoldersCompanion.insert(
                id: id,
                name: name,
                icon: icon,
                shape: shape,
                sortOrder: sortOrder,
                createdByAi: createdByAi,
                view: view,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FoldersTable, Folder>(table),
                  BaseReferences<_$AppDatabase, $FoldersTable, Folder>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FoldersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FoldersTable,
      Folder,
      $$FoldersTableFilterComposer,
      $$FoldersTableOrderingComposer,
      $$FoldersTableAnnotationComposer,
      $$FoldersTableCreateCompanionBuilder,
      $$FoldersTableUpdateCompanionBuilder,
      (Folder, BaseReferences<_$AppDatabase, $FoldersTable, Folder>),
      Folder,
      PrefetchHooks Function()
    >;
typedef $$TagsTableCreateCompanionBuilder = TagsCompanion Function({
  required String id,
  required String name,
  Value<TagIconKind> iconKind,
  Value<String> iconValue,
  Value<bool> pinned,
  Value<int> pinOrder,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$TagsTableUpdateCompanionBuilder = TagsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<TagIconKind> iconKind,
  Value<String> iconValue,
  Value<bool> pinned,
  Value<int> pinOrder,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$TagsTableFilterComposer extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<TagIconKind, TagIconKind, String>
  get iconKind => $composableBuilder(
    column: $table.iconKind,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get iconValue => $composableBuilder(
    column: $table.iconValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get pinned => $composableBuilder(
    column: $table.pinned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pinOrder => $composableBuilder(
    column: $table.pinOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TagsTableOrderingComposer extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get iconKind => $composableBuilder(
    column: $table.iconKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get iconValue => $composableBuilder(
    column: $table.iconValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get pinned => $composableBuilder(
    column: $table.pinned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pinOrder => $composableBuilder(
    column: $table.pinOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumnWithTypeConverter<TagIconKind, String> get iconKind =>
      $composableBuilder(column: $table.iconKind, builder: (column) => column);

  GeneratedColumn<String> get iconValue =>
      $composableBuilder(column: $table.iconValue, builder: (column) => column);

  GeneratedColumn<bool> get pinned =>
      $composableBuilder(column: $table.pinned, builder: (column) => column);

  GeneratedColumn<int> get pinOrder =>
      $composableBuilder(column: $table.pinOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$TagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TagsTable,
          Tag,
          $$TagsTableFilterComposer,
          $$TagsTableOrderingComposer,
          $$TagsTableAnnotationComposer,
          $$TagsTableCreateCompanionBuilder,
          $$TagsTableUpdateCompanionBuilder,
          (Tag, BaseReferences<_$AppDatabase, $TagsTable, Tag>),
          Tag,
          PrefetchHooks Function()
        > {
  $$TagsTableTableManager(_$AppDatabase db, $TagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<TagIconKind> iconKind = const Value.absent(),
                Value<String> iconValue = const Value.absent(),
                Value<bool> pinned = const Value.absent(),
                Value<int> pinOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TagsCompanion(
                id: id,
                name: name,
                iconKind: iconKind,
                iconValue: iconValue,
                pinned: pinned,
                pinOrder: pinOrder,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<TagIconKind> iconKind = const Value.absent(),
                Value<String> iconValue = const Value.absent(),
                Value<bool> pinned = const Value.absent(),
                Value<int> pinOrder = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => TagsCompanion.insert(
                id: id,
                name: name,
                iconKind: iconKind,
                iconValue: iconValue,
                pinned: pinned,
                pinOrder: pinOrder,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TagsTable, Tag>(table),
                  BaseReferences<_$AppDatabase, $TagsTable, Tag>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TagsTable,
      Tag,
      $$TagsTableFilterComposer,
      $$TagsTableOrderingComposer,
      $$TagsTableAnnotationComposer,
      $$TagsTableCreateCompanionBuilder,
      $$TagsTableUpdateCompanionBuilder,
      (Tag, BaseReferences<_$AppDatabase, $TagsTable, Tag>),
      Tag,
      PrefetchHooks Function()
    >;
typedef $$ItemTagsTableCreateCompanionBuilder = ItemTagsCompanion Function({
  required String itemId,
  required String tagId,
  required TagSource source,
  Value<int> rowid,
});
typedef $$ItemTagsTableUpdateCompanionBuilder = ItemTagsCompanion Function({
  Value<String> itemId,
  Value<String> tagId,
  Value<TagSource> source,
  Value<int> rowid,
});

class $$ItemTagsTableFilterComposer
    extends Composer<_$AppDatabase, $ItemTagsTable> {
  $$ItemTagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tagId => $composableBuilder(
    column: $table.tagId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<TagSource, TagSource, String> get source =>
      $composableBuilder(
        column: $table.source,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );
}

class $$ItemTagsTableOrderingComposer
    extends Composer<_$AppDatabase, $ItemTagsTable> {
  $$ItemTagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tagId => $composableBuilder(
    column: $table.tagId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ItemTagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ItemTagsTable> {
  $$ItemTagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<String> get tagId =>
      $composableBuilder(column: $table.tagId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<TagSource, String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);
}

class $$ItemTagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ItemTagsTable,
          ItemTag,
          $$ItemTagsTableFilterComposer,
          $$ItemTagsTableOrderingComposer,
          $$ItemTagsTableAnnotationComposer,
          $$ItemTagsTableCreateCompanionBuilder,
          $$ItemTagsTableUpdateCompanionBuilder,
          (ItemTag, BaseReferences<_$AppDatabase, $ItemTagsTable, ItemTag>),
          ItemTag,
          PrefetchHooks Function()
        > {
  $$ItemTagsTableTableManager(_$AppDatabase db, $ItemTagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ItemTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ItemTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ItemTagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> itemId = const Value.absent(),
                Value<String> tagId = const Value.absent(),
                Value<TagSource> source = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ItemTagsCompanion(
                itemId: itemId,
                tagId: tagId,
                source: source,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String itemId,
                required String tagId,
                required TagSource source,
                Value<int> rowid = const Value.absent(),
              }) => ItemTagsCompanion.insert(
                itemId: itemId,
                tagId: tagId,
                source: source,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ItemTagsTable, ItemTag>(table),
                  BaseReferences<_$AppDatabase, $ItemTagsTable, ItemTag>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ItemTagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ItemTagsTable,
      ItemTag,
      $$ItemTagsTableFilterComposer,
      $$ItemTagsTableOrderingComposer,
      $$ItemTagsTableAnnotationComposer,
      $$ItemTagsTableCreateCompanionBuilder,
      $$ItemTagsTableUpdateCompanionBuilder,
      (ItemTag, BaseReferences<_$AppDatabase, $ItemTagsTable, ItemTag>),
      ItemTag,
      PrefetchHooks Function()
    >;
typedef $$RulesTableCreateCompanionBuilder = RulesCompanion Function({
  required String id,
  required RuleConditionKind conditionKind,
  required String conditionValue,
  required RuleActionKind actionKind,
  required String actionValue,
  Value<bool> enabled,
  Value<int> sortOrder,
  Value<int> rowid,
});
typedef $$RulesTableUpdateCompanionBuilder = RulesCompanion Function({
  Value<String> id,
  Value<RuleConditionKind> conditionKind,
  Value<String> conditionValue,
  Value<RuleActionKind> actionKind,
  Value<String> actionValue,
  Value<bool> enabled,
  Value<int> sortOrder,
  Value<int> rowid,
});

class $$RulesTableFilterComposer extends Composer<_$AppDatabase, $RulesTable> {
  $$RulesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<RuleConditionKind, RuleConditionKind, String>
  get conditionKind => $composableBuilder(
    column: $table.conditionKind,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get conditionValue => $composableBuilder(
    column: $table.conditionValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<RuleActionKind, RuleActionKind, String>
  get actionKind => $composableBuilder(
    column: $table.actionKind,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get actionValue => $composableBuilder(
    column: $table.actionValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RulesTableOrderingComposer
    extends Composer<_$AppDatabase, $RulesTable> {
  $$RulesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conditionKind => $composableBuilder(
    column: $table.conditionKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conditionValue => $composableBuilder(
    column: $table.conditionValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actionKind => $composableBuilder(
    column: $table.actionKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actionValue => $composableBuilder(
    column: $table.actionValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RulesTableAnnotationComposer
    extends Composer<_$AppDatabase, $RulesTable> {
  $$RulesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<RuleConditionKind, String>
  get conditionKind => $composableBuilder(
    column: $table.conditionKind,
    builder: (column) => column,
  );

  GeneratedColumn<String> get conditionValue => $composableBuilder(
    column: $table.conditionValue,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<RuleActionKind, String> get actionKind =>
      $composableBuilder(
        column: $table.actionKind,
        builder: (column) => column,
      );

  GeneratedColumn<String> get actionValue => $composableBuilder(
    column: $table.actionValue,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);
}

class $$RulesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RulesTable,
          Rule,
          $$RulesTableFilterComposer,
          $$RulesTableOrderingComposer,
          $$RulesTableAnnotationComposer,
          $$RulesTableCreateCompanionBuilder,
          $$RulesTableUpdateCompanionBuilder,
          (Rule, BaseReferences<_$AppDatabase, $RulesTable, Rule>),
          Rule,
          PrefetchHooks Function()
        > {
  $$RulesTableTableManager(_$AppDatabase db, $RulesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RulesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RulesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RulesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<RuleConditionKind> conditionKind = const Value.absent(),
                Value<String> conditionValue = const Value.absent(),
                Value<RuleActionKind> actionKind = const Value.absent(),
                Value<String> actionValue = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RulesCompanion(
                id: id,
                conditionKind: conditionKind,
                conditionValue: conditionValue,
                actionKind: actionKind,
                actionValue: actionValue,
                enabled: enabled,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required RuleConditionKind conditionKind,
                required String conditionValue,
                required RuleActionKind actionKind,
                required String actionValue,
                Value<bool> enabled = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RulesCompanion.insert(
                id: id,
                conditionKind: conditionKind,
                conditionValue: conditionValue,
                actionKind: actionKind,
                actionValue: actionValue,
                enabled: enabled,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RulesTable, Rule>(table),
                  BaseReferences<_$AppDatabase, $RulesTable, Rule>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RulesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RulesTable,
      Rule,
      $$RulesTableFilterComposer,
      $$RulesTableOrderingComposer,
      $$RulesTableAnnotationComposer,
      $$RulesTableCreateCompanionBuilder,
      $$RulesTableUpdateCompanionBuilder,
      (Rule, BaseReferences<_$AppDatabase, $RulesTable, Rule>),
      Rule,
      PrefetchHooks Function()
    >;
typedef $$LinksTableCreateCompanionBuilder = LinksCompanion Function({
  required String fromId,
  required String toId,
  required LinkSource source,
  Value<String?> reason,
  Value<bool> rejected,
  Value<int> rowid,
});
typedef $$LinksTableUpdateCompanionBuilder = LinksCompanion Function({
  Value<String> fromId,
  Value<String> toId,
  Value<LinkSource> source,
  Value<String?> reason,
  Value<bool> rejected,
  Value<int> rowid,
});

class $$LinksTableFilterComposer extends Composer<_$AppDatabase, $LinksTable> {
  $$LinksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get fromId => $composableBuilder(
    column: $table.fromId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get toId => $composableBuilder(
    column: $table.toId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<LinkSource, LinkSource, String> get source =>
      $composableBuilder(
        column: $table.source,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get rejected => $composableBuilder(
    column: $table.rejected,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LinksTableOrderingComposer
    extends Composer<_$AppDatabase, $LinksTable> {
  $$LinksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get fromId => $composableBuilder(
    column: $table.fromId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get toId => $composableBuilder(
    column: $table.toId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get rejected => $composableBuilder(
    column: $table.rejected,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LinksTableAnnotationComposer
    extends Composer<_$AppDatabase, $LinksTable> {
  $$LinksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get fromId =>
      $composableBuilder(column: $table.fromId, builder: (column) => column);

  GeneratedColumn<String> get toId =>
      $composableBuilder(column: $table.toId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<LinkSource, String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<bool> get rejected =>
      $composableBuilder(column: $table.rejected, builder: (column) => column);
}

class $$LinksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LinksTable,
          Link,
          $$LinksTableFilterComposer,
          $$LinksTableOrderingComposer,
          $$LinksTableAnnotationComposer,
          $$LinksTableCreateCompanionBuilder,
          $$LinksTableUpdateCompanionBuilder,
          (Link, BaseReferences<_$AppDatabase, $LinksTable, Link>),
          Link,
          PrefetchHooks Function()
        > {
  $$LinksTableTableManager(_$AppDatabase db, $LinksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LinksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LinksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LinksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> fromId = const Value.absent(),
                Value<String> toId = const Value.absent(),
                Value<LinkSource> source = const Value.absent(),
                Value<String?> reason = const Value.absent(),
                Value<bool> rejected = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LinksCompanion(
                fromId: fromId,
                toId: toId,
                source: source,
                reason: reason,
                rejected: rejected,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String fromId,
                required String toId,
                required LinkSource source,
                Value<String?> reason = const Value.absent(),
                Value<bool> rejected = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LinksCompanion.insert(
                fromId: fromId,
                toId: toId,
                source: source,
                reason: reason,
                rejected: rejected,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LinksTable, Link>(table),
                  BaseReferences<_$AppDatabase, $LinksTable, Link>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LinksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LinksTable,
      Link,
      $$LinksTableFilterComposer,
      $$LinksTableOrderingComposer,
      $$LinksTableAnnotationComposer,
      $$LinksTableCreateCompanionBuilder,
      $$LinksTableUpdateCompanionBuilder,
      (Link, BaseReferences<_$AppDatabase, $LinksTable, Link>),
      Link,
      PrefetchHooks Function()
    >;
typedef $$AiJobsTableCreateCompanionBuilder = AiJobsCompanion Function({
  required String itemId,
  required String kind,
  Value<int> attempts,
  required DateTime nextTryAt,
  Value<String?> lastError,
  Value<int> rowid,
});
typedef $$AiJobsTableUpdateCompanionBuilder = AiJobsCompanion Function({
  Value<String> itemId,
  Value<String> kind,
  Value<int> attempts,
  Value<DateTime> nextTryAt,
  Value<String?> lastError,
  Value<int> rowid,
});

class $$AiJobsTableFilterComposer
    extends Composer<_$AppDatabase, $AiJobsTable> {
  $$AiJobsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextTryAt => $composableBuilder(
    column: $table.nextTryAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AiJobsTableOrderingComposer
    extends Composer<_$AppDatabase, $AiJobsTable> {
  $$AiJobsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextTryAt => $composableBuilder(
    column: $table.nextTryAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AiJobsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AiJobsTable> {
  $$AiJobsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<DateTime> get nextTryAt =>
      $composableBuilder(column: $table.nextTryAt, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);
}

class $$AiJobsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AiJobsTable,
          AiJob,
          $$AiJobsTableFilterComposer,
          $$AiJobsTableOrderingComposer,
          $$AiJobsTableAnnotationComposer,
          $$AiJobsTableCreateCompanionBuilder,
          $$AiJobsTableUpdateCompanionBuilder,
          (AiJob, BaseReferences<_$AppDatabase, $AiJobsTable, AiJob>),
          AiJob,
          PrefetchHooks Function()
        > {
  $$AiJobsTableTableManager(_$AppDatabase db, $AiJobsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AiJobsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AiJobsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AiJobsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> itemId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<DateTime> nextTryAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AiJobsCompanion(
                itemId: itemId,
                kind: kind,
                attempts: attempts,
                nextTryAt: nextTryAt,
                lastError: lastError,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String itemId,
                required String kind,
                Value<int> attempts = const Value.absent(),
                required DateTime nextTryAt,
                Value<String?> lastError = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AiJobsCompanion.insert(
                itemId: itemId,
                kind: kind,
                attempts: attempts,
                nextTryAt: nextTryAt,
                lastError: lastError,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AiJobsTable, AiJob>(table),
                  BaseReferences<_$AppDatabase, $AiJobsTable, AiJob>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AiJobsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AiJobsTable,
      AiJob,
      $$AiJobsTableFilterComposer,
      $$AiJobsTableOrderingComposer,
      $$AiJobsTableAnnotationComposer,
      $$AiJobsTableCreateCompanionBuilder,
      $$AiJobsTableUpdateCompanionBuilder,
      (AiJob, BaseReferences<_$AppDatabase, $AiJobsTable, AiJob>),
      AiJob,
      PrefetchHooks Function()
    >;
typedef $$AiLogTableCreateCompanionBuilder = AiLogCompanion Function({
  Value<int> id,
  required DateTime at,
  Value<String?> itemId,
  required String request,
  Value<String?> response,
  Value<String?> error,
});
typedef $$AiLogTableUpdateCompanionBuilder = AiLogCompanion Function({
  Value<int> id,
  Value<DateTime> at,
  Value<String?> itemId,
  Value<String> request,
  Value<String?> response,
  Value<String?> error,
});

class $$AiLogTableFilterComposer extends Composer<_$AppDatabase, $AiLogTable> {
  $$AiLogTableFilterComposer({
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

  ColumnFilters<DateTime> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get request => $composableBuilder(
    column: $table.request,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get response => $composableBuilder(
    column: $table.response,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AiLogTableOrderingComposer
    extends Composer<_$AppDatabase, $AiLogTable> {
  $$AiLogTableOrderingComposer({
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

  ColumnOrderings<DateTime> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get request => $composableBuilder(
    column: $table.request,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get response => $composableBuilder(
    column: $table.response,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AiLogTableAnnotationComposer
    extends Composer<_$AppDatabase, $AiLogTable> {
  $$AiLogTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get at =>
      $composableBuilder(column: $table.at, builder: (column) => column);

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<String> get request =>
      $composableBuilder(column: $table.request, builder: (column) => column);

  GeneratedColumn<String> get response =>
      $composableBuilder(column: $table.response, builder: (column) => column);

  GeneratedColumn<String> get error =>
      $composableBuilder(column: $table.error, builder: (column) => column);
}

class $$AiLogTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AiLogTable,
          AiLogData,
          $$AiLogTableFilterComposer,
          $$AiLogTableOrderingComposer,
          $$AiLogTableAnnotationComposer,
          $$AiLogTableCreateCompanionBuilder,
          $$AiLogTableUpdateCompanionBuilder,
          (AiLogData, BaseReferences<_$AppDatabase, $AiLogTable, AiLogData>),
          AiLogData,
          PrefetchHooks Function()
        > {
  $$AiLogTableTableManager(_$AppDatabase db, $AiLogTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AiLogTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AiLogTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AiLogTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> at = const Value.absent(),
                Value<String?> itemId = const Value.absent(),
                Value<String> request = const Value.absent(),
                Value<String?> response = const Value.absent(),
                Value<String?> error = const Value.absent(),
              }) => AiLogCompanion(
                id: id,
                at: at,
                itemId: itemId,
                request: request,
                response: response,
                error: error,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime at,
                Value<String?> itemId = const Value.absent(),
                required String request,
                Value<String?> response = const Value.absent(),
                Value<String?> error = const Value.absent(),
              }) => AiLogCompanion.insert(
                id: id,
                at: at,
                itemId: itemId,
                request: request,
                response: response,
                error: error,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AiLogTable, AiLogData>(table),
                  BaseReferences<_$AppDatabase, $AiLogTable, AiLogData>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AiLogTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AiLogTable,
      AiLogData,
      $$AiLogTableFilterComposer,
      $$AiLogTableOrderingComposer,
      $$AiLogTableAnnotationComposer,
      $$AiLogTableCreateCompanionBuilder,
      $$AiLogTableUpdateCompanionBuilder,
      (AiLogData, BaseReferences<_$AppDatabase, $AiLogTable, AiLogData>),
      AiLogData,
      PrefetchHooks Function()
    >;
typedef $$WordStatsTableCreateCompanionBuilder = WordStatsCompanion Function({
  required String word,
  required String targetKind,
  required String targetId,
  Value<int> count,
  Value<int> rowid,
});
typedef $$WordStatsTableUpdateCompanionBuilder = WordStatsCompanion Function({
  Value<String> word,
  Value<String> targetKind,
  Value<String> targetId,
  Value<int> count,
  Value<int> rowid,
});

class $$WordStatsTableFilterComposer
    extends Composer<_$AppDatabase, $WordStatsTable> {
  $$WordStatsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get word => $composableBuilder(
    column: $table.word,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetKind => $composableBuilder(
    column: $table.targetKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetId => $composableBuilder(
    column: $table.targetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get count => $composableBuilder(
    column: $table.count,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WordStatsTableOrderingComposer
    extends Composer<_$AppDatabase, $WordStatsTable> {
  $$WordStatsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get word => $composableBuilder(
    column: $table.word,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetKind => $composableBuilder(
    column: $table.targetKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetId => $composableBuilder(
    column: $table.targetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get count => $composableBuilder(
    column: $table.count,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WordStatsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WordStatsTable> {
  $$WordStatsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get word =>
      $composableBuilder(column: $table.word, builder: (column) => column);

  GeneratedColumn<String> get targetKind => $composableBuilder(
    column: $table.targetKind,
    builder: (column) => column,
  );

  GeneratedColumn<String> get targetId =>
      $composableBuilder(column: $table.targetId, builder: (column) => column);

  GeneratedColumn<int> get count =>
      $composableBuilder(column: $table.count, builder: (column) => column);
}

class $$WordStatsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WordStatsTable,
          WordStat,
          $$WordStatsTableFilterComposer,
          $$WordStatsTableOrderingComposer,
          $$WordStatsTableAnnotationComposer,
          $$WordStatsTableCreateCompanionBuilder,
          $$WordStatsTableUpdateCompanionBuilder,
          (WordStat, BaseReferences<_$AppDatabase, $WordStatsTable, WordStat>),
          WordStat,
          PrefetchHooks Function()
        > {
  $$WordStatsTableTableManager(_$AppDatabase db, $WordStatsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WordStatsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WordStatsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WordStatsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> word = const Value.absent(),
                Value<String> targetKind = const Value.absent(),
                Value<String> targetId = const Value.absent(),
                Value<int> count = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WordStatsCompanion(
                word: word,
                targetKind: targetKind,
                targetId: targetId,
                count: count,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String word,
                required String targetKind,
                required String targetId,
                Value<int> count = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WordStatsCompanion.insert(
                word: word,
                targetKind: targetKind,
                targetId: targetId,
                count: count,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WordStatsTable, WordStat>(table),
                  BaseReferences<_$AppDatabase, $WordStatsTable, WordStat>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WordStatsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WordStatsTable,
      WordStat,
      $$WordStatsTableFilterComposer,
      $$WordStatsTableOrderingComposer,
      $$WordStatsTableAnnotationComposer,
      $$WordStatsTableCreateCompanionBuilder,
      $$WordStatsTableUpdateCompanionBuilder,
      (WordStat, BaseReferences<_$AppDatabase, $WordStatsTable, WordStat>),
      WordStat,
      PrefetchHooks Function()
    >;
typedef $$CorrectionsTableCreateCompanionBuilder =
    CorrectionsCompanion Function({
      required String id,
      required String itemId,
      Value<String?> fromFolderId,
      required String toFolderId,
      required DateTime at,
      Value<int> rowid,
    });
typedef $$CorrectionsTableUpdateCompanionBuilder =
    CorrectionsCompanion Function({
      Value<String> id,
      Value<String> itemId,
      Value<String?> fromFolderId,
      Value<String> toFolderId,
      Value<DateTime> at,
      Value<int> rowid,
    });

class $$CorrectionsTableFilterComposer
    extends Composer<_$AppDatabase, $CorrectionsTable> {
  $$CorrectionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fromFolderId => $composableBuilder(
    column: $table.fromFolderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get toFolderId => $composableBuilder(
    column: $table.toFolderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CorrectionsTableOrderingComposer
    extends Composer<_$AppDatabase, $CorrectionsTable> {
  $$CorrectionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fromFolderId => $composableBuilder(
    column: $table.fromFolderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get toFolderId => $composableBuilder(
    column: $table.toFolderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CorrectionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CorrectionsTable> {
  $$CorrectionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<String> get fromFolderId => $composableBuilder(
    column: $table.fromFolderId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get toFolderId => $composableBuilder(
    column: $table.toFolderId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get at =>
      $composableBuilder(column: $table.at, builder: (column) => column);
}

class $$CorrectionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CorrectionsTable,
          Correction,
          $$CorrectionsTableFilterComposer,
          $$CorrectionsTableOrderingComposer,
          $$CorrectionsTableAnnotationComposer,
          $$CorrectionsTableCreateCompanionBuilder,
          $$CorrectionsTableUpdateCompanionBuilder,
          (
            Correction,
            BaseReferences<_$AppDatabase, $CorrectionsTable, Correction>,
          ),
          Correction,
          PrefetchHooks Function()
        > {
  $$CorrectionsTableTableManager(_$AppDatabase db, $CorrectionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CorrectionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CorrectionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CorrectionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> itemId = const Value.absent(),
                Value<String?> fromFolderId = const Value.absent(),
                Value<String> toFolderId = const Value.absent(),
                Value<DateTime> at = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CorrectionsCompanion(
                id: id,
                itemId: itemId,
                fromFolderId: fromFolderId,
                toFolderId: toFolderId,
                at: at,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String itemId,
                Value<String?> fromFolderId = const Value.absent(),
                required String toFolderId,
                required DateTime at,
                Value<int> rowid = const Value.absent(),
              }) => CorrectionsCompanion.insert(
                id: id,
                itemId: itemId,
                fromFolderId: fromFolderId,
                toFolderId: toFolderId,
                at: at,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CorrectionsTable, Correction>(table),
                  BaseReferences<_$AppDatabase, $CorrectionsTable, Correction>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CorrectionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CorrectionsTable,
      Correction,
      $$CorrectionsTableFilterComposer,
      $$CorrectionsTableOrderingComposer,
      $$CorrectionsTableAnnotationComposer,
      $$CorrectionsTableCreateCompanionBuilder,
      $$CorrectionsTableUpdateCompanionBuilder,
      (
        Correction,
        BaseReferences<_$AppDatabase, $CorrectionsTable, Correction>,
      ),
      Correction,
      PrefetchHooks Function()
    >;
typedef $$CanvasPositionsTableCreateCompanionBuilder =
    CanvasPositionsCompanion Function({
      required String folderId,
      required String itemId,
      required double x,
      required double y,
      required double width,
      Value<int> rowid,
    });
typedef $$CanvasPositionsTableUpdateCompanionBuilder =
    CanvasPositionsCompanion Function({
      Value<String> folderId,
      Value<String> itemId,
      Value<double> x,
      Value<double> y,
      Value<double> width,
      Value<int> rowid,
    });

class $$CanvasPositionsTableFilterComposer
    extends Composer<_$AppDatabase, $CanvasPositionsTable> {
  $$CanvasPositionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get folderId => $composableBuilder(
    column: $table.folderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get x => $composableBuilder(
    column: $table.x,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get y => $composableBuilder(
    column: $table.y,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CanvasPositionsTableOrderingComposer
    extends Composer<_$AppDatabase, $CanvasPositionsTable> {
  $$CanvasPositionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get folderId => $composableBuilder(
    column: $table.folderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get x => $composableBuilder(
    column: $table.x,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get y => $composableBuilder(
    column: $table.y,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CanvasPositionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CanvasPositionsTable> {
  $$CanvasPositionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get folderId =>
      $composableBuilder(column: $table.folderId, builder: (column) => column);

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<double> get x =>
      $composableBuilder(column: $table.x, builder: (column) => column);

  GeneratedColumn<double> get y =>
      $composableBuilder(column: $table.y, builder: (column) => column);

  GeneratedColumn<double> get width =>
      $composableBuilder(column: $table.width, builder: (column) => column);
}

class $$CanvasPositionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CanvasPositionsTable,
          CanvasPosition,
          $$CanvasPositionsTableFilterComposer,
          $$CanvasPositionsTableOrderingComposer,
          $$CanvasPositionsTableAnnotationComposer,
          $$CanvasPositionsTableCreateCompanionBuilder,
          $$CanvasPositionsTableUpdateCompanionBuilder,
          (
            CanvasPosition,
            BaseReferences<
              _$AppDatabase,
              $CanvasPositionsTable,
              CanvasPosition
            >,
          ),
          CanvasPosition,
          PrefetchHooks Function()
        > {
  $$CanvasPositionsTableTableManager(
    _$AppDatabase db,
    $CanvasPositionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CanvasPositionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CanvasPositionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CanvasPositionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> folderId = const Value.absent(),
                Value<String> itemId = const Value.absent(),
                Value<double> x = const Value.absent(),
                Value<double> y = const Value.absent(),
                Value<double> width = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CanvasPositionsCompanion(
                folderId: folderId,
                itemId: itemId,
                x: x,
                y: y,
                width: width,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String folderId,
                required String itemId,
                required double x,
                required double y,
                required double width,
                Value<int> rowid = const Value.absent(),
              }) => CanvasPositionsCompanion.insert(
                folderId: folderId,
                itemId: itemId,
                x: x,
                y: y,
                width: width,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CanvasPositionsTable, CanvasPosition>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $CanvasPositionsTable,
                    CanvasPosition
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CanvasPositionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CanvasPositionsTable,
      CanvasPosition,
      $$CanvasPositionsTableFilterComposer,
      $$CanvasPositionsTableOrderingComposer,
      $$CanvasPositionsTableAnnotationComposer,
      $$CanvasPositionsTableCreateCompanionBuilder,
      $$CanvasPositionsTableUpdateCompanionBuilder,
      (
        CanvasPosition,
        BaseReferences<_$AppDatabase, $CanvasPositionsTable, CanvasPosition>,
      ),
      CanvasPosition,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ItemsTableTableManager get items =>
      $$ItemsTableTableManager(_db, _db.items);
  $$AttachmentsTableTableManager get attachments =>
      $$AttachmentsTableTableManager(_db, _db.attachments);
  $$FoldersTableTableManager get folders =>
      $$FoldersTableTableManager(_db, _db.folders);
  $$TagsTableTableManager get tags => $$TagsTableTableManager(_db, _db.tags);
  $$ItemTagsTableTableManager get itemTags =>
      $$ItemTagsTableTableManager(_db, _db.itemTags);
  $$RulesTableTableManager get rules =>
      $$RulesTableTableManager(_db, _db.rules);
  $$LinksTableTableManager get links =>
      $$LinksTableTableManager(_db, _db.links);
  $$AiJobsTableTableManager get aiJobs =>
      $$AiJobsTableTableManager(_db, _db.aiJobs);
  $$AiLogTableTableManager get aiLog =>
      $$AiLogTableTableManager(_db, _db.aiLog);
  $$WordStatsTableTableManager get wordStats =>
      $$WordStatsTableTableManager(_db, _db.wordStats);
  $$CorrectionsTableTableManager get corrections =>
      $$CorrectionsTableTableManager(_db, _db.corrections);
  $$CanvasPositionsTableTableManager get canvasPositions =>
      $$CanvasPositionsTableTableManager(_db, _db.canvasPositions);
}
