import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sing_list/data/db/app_database.dart';
import 'package:sing_list/repository/song_repository.dart';
import 'package:sing_list/service/duplicate_merge_service.dart';

void main() {
  test('findDuplicateGroups empty when database has unique songs', () async {
    final db = AppDatabase(NativeDatabase.memory());
    await db.customStatement('PRAGMA foreign_keys = ON');
    final songRepo = SongRepository(db);
    final service = DuplicateMergeService(db, songRepo);

    await db.songDao.addSong('Song A', 'Artist A');
    await db.songDao.addSong('Song B', 'Artist B');

    final groups = await service.findDuplicateGroups();
    expect(groups, isEmpty);
    await db.close();
  });
}
