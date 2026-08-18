import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ai/ai_config_repository.dart';
import '../ai/openai_compatible_client.dart';
import '../ai/secure_api_key_store.dart';
import '../ai_playlist/ai_playlist_save_service.dart';
import '../ai_playlist/ai_playlist_service.dart';
import '../ai_playlist/song_catalog_service.dart';
import '../data/db/app_database.dart';
import '../lyrics/lyric_ai_processor.dart';
import '../lyrics/lyric_search_service.dart';
import '../lyrics/lyrics_repository.dart';
import '../lyrics/network_connectivity_service.dart';
import '../repository/playlist_repository.dart';
import '../repository/song_repository.dart';
import '../repository/tag_repository.dart';
import '../service/backup_service.dart';
import '../service/duplicate_merge_service.dart';
import '../service/import_service.dart';
import '../service/kqueue_text_service.dart';
import '../service/settings_service.dart';

final databaseProvider =
    Provider<AppDatabase>((ref) => throw UnimplementedError());

final songRepoProvider =
    Provider((ref) => SongRepository(ref.watch(databaseProvider)));
final lyricsRepoProvider =
    Provider((ref) => LyricsRepository(ref.watch(databaseProvider)));
final tagRepoProvider =
    Provider((ref) => TagRepository(ref.watch(databaseProvider)));
final playlistRepoProvider =
    Provider((ref) => PlaylistRepository(ref.watch(databaseProvider)));
final kqueueTextServiceProvider = Provider(
  (ref) => KQueueTextService(
    ref.watch(songRepoProvider),
    ref.watch(playlistRepoProvider),
  ),
);
final settingsServiceProvider = Provider((ref) => SettingsService());
final aiConfigRepositoryProvider = Provider(
  (ref) => AiConfigRepository(
    ref.watch(settingsServiceProvider),
    FlutterSecureApiKeyStore(),
  ),
);
final openAiCompatibleClientProvider =
    Provider((ref) => OpenAiCompatibleClient());
final lyricAiProcessorProvider = Provider(
  (ref) => LyricAiProcessor(ref.watch(openAiCompatibleClientProvider)),
);
final lyricSearchServiceProvider = Provider((ref) => LyricSearchService());
final networkConnectivityServiceProvider =
    Provider((ref) => NetworkConnectivityService());
final songCatalogServiceProvider = Provider(
  (ref) => SongCatalogService(ref.watch(databaseProvider)),
);
final aiPlaylistServiceProvider = Provider(
  (ref) => AiPlaylistService(
    client: ref.watch(openAiCompatibleClientProvider),
    catalogService: ref.watch(songCatalogServiceProvider),
  ),
);
final aiPlaylistSaveServiceProvider = Provider(
  (ref) => AiPlaylistSaveService(
    songRepository: ref.watch(songRepoProvider),
    playlistRepository: ref.watch(playlistRepoProvider),
  ),
);
final importServiceProvider =
    Provider((ref) => ImportService(ref.watch(databaseProvider)));
final backupServiceProvider = Provider(
  (ref) => BackupService(
    ref.watch(databaseProvider),
    ref.watch(songRepoProvider),
    ref.watch(tagRepoProvider),
    ref.watch(playlistRepoProvider),
  ),
);
final duplicateMergeServiceProvider = Provider(
  (ref) => DuplicateMergeService(
      ref.watch(databaseProvider), ref.watch(songRepoProvider)),
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
