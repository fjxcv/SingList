import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/db/app_database.dart';
import 'state/providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await createDatabase();
  runApp(ProviderScope(
    overrides: [databaseProvider.overrideWithValue(db)],
    child: const SingListApp(),
  ));
}
