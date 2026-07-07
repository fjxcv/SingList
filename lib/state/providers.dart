import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/app_database.dart';
import '../repository/playlist_repository.dart';
import '../repository/song_repository.dart';
import '../repository/tag_repository.dart';
import '../service/backup_service.dart';
import '../service/duplicate_merge_service.dart';
import '../service/import_service.dart';
import '../service/kqueue_text_service.dart';
import '../service/settings_service.dart';

final databaseProvider = Provider<AppDatabase>((ref) => throw UnimplementedError());

final songRepoProvider = Provider((ref) => SongRepository(ref.watch(databaseProvider)));
final tagRepoProvider = Provider((ref) => TagRepository(ref.watch(databaseProvider)));
final playlistRepoProvider = Provider((ref) => PlaylistRepository(ref.watch(databaseProvider)));
final kqueueTextServiceProvider = Provider(
  (ref) => KQueueTextService(
    ref.watch(songRepoProvider),
    ref.watch(playlistRepoProvider),
  ),
);
final settingsServiceProvider = Provider((ref) => SettingsService());
final importServiceProvider = Provider((ref) => ImportService(ref.watch(databaseProvider)));
final backupServiceProvider = Provider(
  (ref) => BackupService(
    ref.watch(databaseProvider),
    ref.watch(songRepoProvider),
    ref.watch(tagRepoProvider),
    ref.watch(playlistRepoProvider),
  ),
);
final duplicateMergeServiceProvider = Provider(
  (ref) => DuplicateMergeService(ref.watch(databaseProvider), ref.watch(songRepoProvider)),
);

final songsProvider = StreamProvider.autoDispose((ref) {
  final repo = ref.watch(songRepoProvider);
  return repo.watchAll();
});

final tagsProvider = StreamProvider.autoDispose((ref) {
  final repo = ref.watch(tagRepoProvider);
  return repo.watchAll();
});

final tagsWithCountProvider = StreamProvider.autoDispose((ref) {
  final repo = ref.watch(tagRepoProvider);
  return repo.watchTagsWithCount();
});

final normalPlaylistsProvider = StreamProvider.autoDispose((ref) {
  final repo = ref.watch(playlistRepoProvider);
  return repo.watchByType(PlaylistType.normal);
});

final queuePlaylistsProvider = StreamProvider.autoDispose((ref) {
  final repo = ref.watch(playlistRepoProvider);
  return repo.watchByType(PlaylistType.kQueue);
});
