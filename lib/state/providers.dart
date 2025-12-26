import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/app_database.dart';
import '../repository/playlist_repository.dart';
import '../repository/song_repository.dart';
import '../repository/tag_repository.dart';

final databaseProvider = Provider<AppDatabase>((ref) => throw UnimplementedError());

final songRepoProvider = Provider((ref) => SongRepository(ref.watch(databaseProvider)));
final tagRepoProvider = Provider((ref) => TagRepository(ref.watch(databaseProvider)));
final playlistRepoProvider = Provider((ref) => PlaylistRepository(ref.watch(databaseProvider)));

final songsProvider = StreamProvider.autoDispose((ref) {
  final repo = ref.watch(songRepoProvider);
  return repo.watchAll();
});

final tagsProvider = StreamProvider.autoDispose((ref) {
  final repo = ref.watch(tagRepoProvider);
  return repo.watchAll();
});

final normalPlaylistsProvider = StreamProvider.autoDispose((ref) {
  final repo = ref.watch(playlistRepoProvider);
  return repo.watchByType(PlaylistType.normal);
});

final queuePlaylistsProvider = StreamProvider.autoDispose((ref) {
  final repo = ref.watch(playlistRepoProvider);
  return repo.watchByType(PlaylistType.kQueue);
});
