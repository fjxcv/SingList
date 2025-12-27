import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sing_list/app.dart';
import 'package:sing_list/data/db/app_database.dart';
import 'package:sing_list/state/providers.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Create an in-memory database for testing.
    final db = AppDatabase(NativeDatabase.memory());

    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
        child: const SingListApp(),
      ),
    );

    // Wait for all animations and async operations to complete.
    await tester.pumpAndSettle();

    // Verify that the initial page (SongsPage) is shown.
    expect(find.text('歌曲库'), findsOneWidget);
    expect(find.text('暂无歌曲，点击右上角新增'), findsOneWidget);
  });
}
