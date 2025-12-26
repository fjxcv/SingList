// GENERATED CODE - MANUAL SNAPSHOT FOR MVP
// ignore_for_file: type=lint
part of 'app_database.dart';

class Song extends DataClass implements Insertable<Song> {
  final int id;
  final String title;
  final String artist;
  final String titleNorm;
  final String artistNorm;
  final DateTime createdAt;
  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.titleNorm,
    required this.artistNorm,
    required this.createdAt,
  });

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    return {
      'id': Variable<int>(id),
      'title': Variable<String>(title),
      'artist': Variable<String>(artist),
      'title_norm': Variable<String>(titleNorm),
      'artist_norm': Variable<String>(artistNorm),
      'created_at': Variable<DateTime>(createdAt),
    };
  }

  SongsCompanion toCompanion(bool nullToAbsent) {
    return SongsCompanion(
      id: Value(id),
      title: Value(title),
      artist: Value(artist),
      titleNorm: Value(titleNorm),
      artistNorm: Value(artistNorm),
      createdAt: Value(createdAt),
    );
  }

  factory Song.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Song(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      artist: serializer.fromJson<String>(json['artist']),
      titleNorm: serializer.fromJson<String>(json['titleNorm']),
      artistNorm: serializer.fromJson<String>(json['artistNorm']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return {
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'artist': serializer.toJson<String>(artist),
      'titleNorm': serializer.toJson<String>(titleNorm),
      'artistNorm': serializer.toJson<String>(artistNorm),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }
}

class SongsCompanion extends UpdateCompanion<Song> {
  final Value<int> id;
  final Value<String> title;
  final Value<String> artist;
  final Value<String> titleNorm;
  final Value<String> artistNorm;
  final Value<DateTime> createdAt;
  const SongsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.artist = const Value.absent(),
    this.titleNorm = const Value.absent(),
    this.artistNorm = const Value.absent(),
    this.createdAt = const Value.absent(),
  });

  SongsCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    required String artist,
    required String titleNorm,
    required String artistNorm,
    this.createdAt = const Value.absent(),
  })  : title = Value(title),
        artist = Value(artist),
        titleNorm = Value(titleNorm),
        artistNorm = Value(artistNorm);

  static Insertable<Song> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<String>? artist,
    Expression<String>? titleNorm,
    Expression<String>? artistNorm,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (artist != null) 'artist': artist,
      if (titleNorm != null) 'title_norm': titleNorm,
      if (artistNorm != null) 'artist_norm': artistNorm,
      if (createdAt != null) 'created_at': createdAt,
    });
  }
}

class $SongsTable extends Songs with TableInfo<$SongsTable, Song> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SongsTable(this.attachedDatabase, [this._alias]);

  static const VerificationMeta _idMeta = VerificationMeta('id');
  static const VerificationMeta _titleMeta = VerificationMeta('title');
  static const VerificationMeta _artistMeta = VerificationMeta('artist');
  static const VerificationMeta _titleNormMeta = VerificationMeta('titleNorm');
  static const VerificationMeta _artistNormMeta = VerificationMeta('artistNorm');
  static const VerificationMeta _createdAtMeta = VerificationMeta('createdAt');

  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    hasAutoIncrement: true,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'),
  );
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumn<String> artist = GeneratedColumn<String>(
    'artist',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumn<String> titleNorm = GeneratedColumn<String>(
    'title_norm',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumn<String> artistNorm = GeneratedColumn<String>(
    'artist_norm',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: const CurrentDateAndTime(),
  );
  @override
  List<GeneratedColumn> get $columns => [id, title, artist, titleNorm, artistNorm, createdAt];
  @override
  String get aliasedName => _alias ?? 'songs';
  @override
  String get actualTableName => 'songs';

  @override
  VerificationContext validateIntegrity(Insertable<Song> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(_titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('artist')) {
      context.handle(_artistMeta, artist.isAcceptableOrUnknown(data['artist']!, _artistMeta));
    } else if (isInserting) {
      context.missing(_artistMeta);
    }
    if (data.containsKey('title_norm')) {
      context.handle(_titleNormMeta, titleNorm.isAcceptableOrUnknown(data['title_norm']!, _titleNormMeta));
    } else if (isInserting) {
      context.missing(_titleNormMeta);
    }
    if (data.containsKey('artist_norm')) {
      context.handle(_artistNormMeta, artistNorm.isAcceptableOrUnknown(data['artist_norm']!, _artistNormMeta));
    } else if (isInserting) {
      context.missing(_artistNormMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta, createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};

  @override
  Song map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Song(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      title: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      artist: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}artist'])!,
      titleNorm: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}title_norm'])!,
      artistNorm: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}artist_norm'])!,
      createdAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }
}

class Tag extends DataClass implements Insertable<Tag> {
  final int id;
  final String name;
  final DateTime createdAt;
  const Tag({required this.id, required this.name, required this.createdAt});

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) => {
        'id': Variable<int>(id),
        'name': Variable<String>(name),
        'created_at': Variable<DateTime>(createdAt),
      };

  TagsCompanion toCompanion(bool nullToAbsent) => TagsCompanion(
        id: Value(id),
        name: Value(name),
        createdAt: Value(createdAt),
      );
}

class TagsCompanion extends UpdateCompanion<Tag> {
  final Value<int> id;
  final Value<String> name;
  final Value<DateTime> createdAt;
  const TagsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  TagsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.createdAt = const Value.absent(),
  }) : name = Value(name);
}

class $TagsTable extends Tags with TableInfo<$TagsTable, Tag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TagsTable(this.attachedDatabase, [this._alias]);

  static const VerificationMeta _idMeta = VerificationMeta('id');
  static const VerificationMeta _nameMeta = VerificationMeta('name');
  static const VerificationMeta _createdAtMeta = VerificationMeta('createdAt');

  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>('id', aliasedName, false,
      type: DriftSqlType.int,
      hasAutoIncrement: true,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>('name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true, defaultConstraints: 'UNIQUE');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: const CurrentDateAndTime(),
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, createdAt];
  @override
  String get aliasedName => _alias ?? 'tags';
  @override
  String get actualTableName => 'tags';

  @override
  VerificationContext validateIntegrity(Insertable<Tag> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(_nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta, createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};

  @override
  Tag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Tag(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      createdAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }
}

class SongTag extends DataClass implements Insertable<SongTag> {
  final int songId;
  final int tagId;
  const SongTag({required this.songId, required this.tagId});

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) => {
        'song_id': Variable<int>(songId),
        'tag_id': Variable<int>(tagId),
      };

  SongTagsCompanion toCompanion(bool nullToAbsent) => SongTagsCompanion(
        songId: Value(songId),
        tagId: Value(tagId),
      );
}

class SongTagsCompanion extends UpdateCompanion<SongTag> {
  final Value<int> songId;
  final Value<int> tagId;
  const SongTagsCompanion({this.songId = const Value.absent(), this.tagId = const Value.absent()});
  SongTagsCompanion.insert({required int songId, required int tagId})
      : songId = Value(songId),
        tagId = Value(tagId);
}

class $SongTagsTable extends SongTags with TableInfo<$SongTagsTable, SongTag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SongTagsTable(this.attachedDatabase, [this._alias]);

  static const VerificationMeta _songIdMeta = VerificationMeta('songId');
  static const VerificationMeta _tagIdMeta = VerificationMeta('tagId');

  @override
  late final GeneratedColumn<int> songId = GeneratedColumn<int>('song_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true, defaultConstraints: 'REFERENCES songs (id) ON DELETE CASCADE');
  @override
  late final GeneratedColumn<int> tagId = GeneratedColumn<int>('tag_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true, defaultConstraints: 'REFERENCES tags (id) ON DELETE CASCADE');

  @override
  List<GeneratedColumn> get $columns => [songId, tagId];
  @override
  String get aliasedName => _alias ?? 'song_tags';
  @override
  String get actualTableName => 'song_tags';

  @override
  Set<GeneratedColumn> get $primaryKey => {songId, tagId};

  @override
  VerificationContext validateIntegrity(Insertable<SongTag> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('song_id')) {
      context.handle(_songIdMeta, songId.isAcceptableOrUnknown(data['song_id']!, _songIdMeta));
    } else if (isInserting) {
      context.missing(_songIdMeta);
    }
    if (data.containsKey('tag_id')) {
      context.handle(_tagIdMeta, tagId.isAcceptableOrUnknown(data['tag_id']!, _tagIdMeta));
    } else if (isInserting) {
      context.missing(_tagIdMeta);
    }
    return context;
  }

  @override
  SongTag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SongTag(
      songId: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}song_id'])!,
      tagId: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}tag_id'])!,
    );
  }
}

class Playlist extends DataClass implements Insertable<Playlist> {
  final int id;
  final String name;
  final PlaylistType type;
  final DateTime createdAt;
  const Playlist({required this.id, required this.name, required this.type, required this.createdAt});

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) => {
        'id': Variable<int>(id),
        'name': Variable<String>(name),
        'type': Variable<int>(type.index),
        'created_at': Variable<DateTime>(createdAt),
      };

  PlaylistsCompanion toCompanion(bool nullToAbsent) => PlaylistsCompanion(
        id: Value(id),
        name: Value(name),
        type: Value(type),
        createdAt: Value(createdAt),
      );
}

class PlaylistsCompanion extends UpdateCompanion<Playlist> {
  final Value<int> id;
  final Value<String> name;
  final Value<PlaylistType> type;
  final Value<DateTime> createdAt;
  const PlaylistsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  PlaylistsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required PlaylistType type,
    this.createdAt = const Value.absent(),
  })  : name = Value(name),
        type = Value(type);
}

class $PlaylistsTable extends Playlists with TableInfo<$PlaylistsTable, Playlist> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaylistsTable(this.attachedDatabase, [this._alias]);

  static const VerificationMeta _idMeta = VerificationMeta('id');
  static const VerificationMeta _nameMeta = VerificationMeta('name');
  static const VerificationMeta _typeMeta = VerificationMeta('type');
  static const VerificationMeta _createdAtMeta = VerificationMeta('createdAt');

  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>('id', aliasedName, false,
      type: DriftSqlType.int,
      hasAutoIncrement: true,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  @override
  late final GeneratedColumnWithTypeConverter<PlaylistType, int> type =
      GeneratedColumn<int>('type', aliasedName, false, type: DriftSqlType.int, requiredDuringInsert: true)
          .withConverter(const EnumIndexConverter<PlaylistType>(PlaylistType.values));
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>('name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: const CurrentDateAndTime(),
  );

  @override
  List<GeneratedColumn> get $columns => [id, name, type, createdAt];
  @override
  String get aliasedName => _alias ?? 'playlists';
  @override
  String get actualTableName => 'playlists';

  @override
  VerificationContext validateIntegrity(Insertable<Playlist> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(_nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('type')) {
      context.handle(_typeMeta, const VerificationResult.success());
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta, createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};

  @override
  Playlist map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Playlist(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      type: const EnumIndexConverter<PlaylistType>(PlaylistType.values)
          .mapToDart(attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}type']))!,
      createdAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }
}

class PlaylistEntry extends DataClass implements Insertable<PlaylistEntry> {
  final int id;
  final int playlistId;
  final int songId;
  final int position;
  const PlaylistEntry({required this.id, required this.playlistId, required this.songId, required this.position});

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) => {
        'id': Variable<int>(id),
        'playlist_id': Variable<int>(playlistId),
        'song_id': Variable<int>(songId),
        'position': Variable<int>(position),
      };

  PlaylistEntriesCompanion toCompanion(bool nullToAbsent) => PlaylistEntriesCompanion(
        id: Value(id),
        playlistId: Value(playlistId),
        songId: Value(songId),
        position: Value(position),
      );
}

class PlaylistEntriesCompanion extends UpdateCompanion<PlaylistEntry> {
  final Value<int> id;
  final Value<int> playlistId;
  final Value<int> songId;
  final Value<int> position;
  const PlaylistEntriesCompanion({
    this.id = const Value.absent(),
    this.playlistId = const Value.absent(),
    this.songId = const Value.absent(),
    this.position = const Value.absent(),
  });
  PlaylistEntriesCompanion.insert({
    this.id = const Value.absent(),
    required int playlistId,
    required int songId,
    this.position = const Value.absent(),
  })  : playlistId = Value(playlistId),
        songId = Value(songId);
}

class $PlaylistEntriesTable extends PlaylistEntries with TableInfo<$PlaylistEntriesTable, PlaylistEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaylistEntriesTable(this.attachedDatabase, [this._alias]);

  static const VerificationMeta _idMeta = VerificationMeta('id');
  static const VerificationMeta _playlistIdMeta = VerificationMeta('playlistId');
  static const VerificationMeta _songIdMeta = VerificationMeta('songId');
  static const VerificationMeta _positionMeta = VerificationMeta('position');

  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>('id', aliasedName, false,
      type: DriftSqlType.int,
      hasAutoIncrement: true,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  @override
  late final GeneratedColumn<int> playlistId = GeneratedColumn<int>('playlist_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true, defaultConstraints: 'REFERENCES playlists (id) ON DELETE CASCADE');
  @override
  late final GeneratedColumn<int> songId = GeneratedColumn<int>('song_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true, defaultConstraints: 'REFERENCES songs (id) ON DELETE CASCADE');
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>('position', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false, defaultValue: const Constant(0));

  @override
  List<GeneratedColumn> get $columns => [id, playlistId, songId, position];
  @override
  String get aliasedName => _alias ?? 'playlist_entries';
  @override
  String get actualTableName => 'playlist_entries';

  @override
  VerificationContext validateIntegrity(Insertable<PlaylistEntry> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('playlist_id')) {
      context.handle(_playlistIdMeta, playlistId.isAcceptableOrUnknown(data['playlist_id']!, _playlistIdMeta));
    } else if (isInserting) {
      context.missing(_playlistIdMeta);
    }
    if (data.containsKey('song_id')) {
      context.handle(_songIdMeta, songId.isAcceptableOrUnknown(data['song_id']!, _songIdMeta));
    } else if (isInserting) {
      context.missing(_songIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(_positionMeta, position.isAcceptableOrUnknown(data['position']!, _positionMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};

  @override
  PlaylistEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaylistEntry(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      playlistId: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}playlist_id'])!,
      songId: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}song_id'])!,
      position: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}position'])!,
    );
  }
}

class QueueItem extends DataClass implements Insertable<QueueItem> {
  final int id;
  final int playlistId;
  final int songId;
  final int position;
  const QueueItem({required this.id, required this.playlistId, required this.songId, required this.position});

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) => {
        'id': Variable<int>(id),
        'playlist_id': Variable<int>(playlistId),
        'song_id': Variable<int>(songId),
        'position': Variable<int>(position),
      };

  QueueItemsCompanion toCompanion(bool nullToAbsent) => QueueItemsCompanion(
        id: Value(id),
        playlistId: Value(playlistId),
        songId: Value(songId),
        position: Value(position),
      );
}

class QueueItemsCompanion extends UpdateCompanion<QueueItem> {
  final Value<int> id;
  final Value<int> playlistId;
  final Value<int> songId;
  final Value<int> position;
  const QueueItemsCompanion({
    this.id = const Value.absent(),
    this.playlistId = const Value.absent(),
    this.songId = const Value.absent(),
    this.position = const Value.absent(),
  });
  QueueItemsCompanion.insert({
    this.id = const Value.absent(),
    required int playlistId,
    required int songId,
    this.position = const Value.absent(),
  })  : playlistId = Value(playlistId),
        songId = Value(songId);
}

class $QueueItemsTable extends QueueItems with TableInfo<$QueueItemsTable, QueueItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QueueItemsTable(this.attachedDatabase, [this._alias]);

  static const VerificationMeta _idMeta = VerificationMeta('id');
  static const VerificationMeta _playlistIdMeta = VerificationMeta('playlistId');
  static const VerificationMeta _songIdMeta = VerificationMeta('songId');
  static const VerificationMeta _positionMeta = VerificationMeta('position');

  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>('id', aliasedName, false,
      type: DriftSqlType.int,
      hasAutoIncrement: true,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  @override
  late final GeneratedColumn<int> playlistId = GeneratedColumn<int>('playlist_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true, defaultConstraints: 'REFERENCES playlists (id) ON DELETE CASCADE');
  @override
  late final GeneratedColumn<int> songId = GeneratedColumn<int>('song_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true, defaultConstraints: 'REFERENCES songs (id) ON DELETE CASCADE');
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>('position', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false, defaultValue: const Constant(0));

  @override
  List<GeneratedColumn> get $columns => [id, playlistId, songId, position];
  @override
  String get aliasedName => _alias ?? 'queue_items';
  @override
  String get actualTableName => 'queue_items';

  @override
  VerificationContext validateIntegrity(Insertable<QueueItem> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('playlist_id')) {
      context.handle(_playlistIdMeta, playlistId.isAcceptableOrUnknown(data['playlist_id']!, _playlistIdMeta));
    } else if (isInserting) {
      context.missing(_playlistIdMeta);
    }
    if (data.containsKey('song_id')) {
      context.handle(_songIdMeta, songId.isAcceptableOrUnknown(data['song_id']!, _songIdMeta));
    } else if (isInserting) {
      context.missing(_songIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(_positionMeta, position.isAcceptableOrUnknown(data['position']!, _positionMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};

  @override
  QueueItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return QueueItem(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      playlistId: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}playlist_id'])!,
      songId: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}song_id'])!,
      position: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}position'])!,
    );
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  late final $SongsTable songs = $SongsTable(this);
  late final $TagsTable tags = $TagsTable(this);
  late final $SongTagsTable songTags = $SongTagsTable(this);
  late final $PlaylistsTable playlists = $PlaylistsTable(this);
  late final $PlaylistEntriesTable playlistEntries = $PlaylistEntriesTable(this);
  late final $QueueItemsTable queueItems = $QueueItemsTable(this);

  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      [songs, tags, songTags, playlists, playlistEntries, queueItems];
}
