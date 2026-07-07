import 'dart:convert';
import 'dart:io';

void main() {
  final bad = <String>[];
  for (final entity in Directory('.').listSync(recursive: true)) {
    if (entity is! File) continue;
    final path = entity.path.replaceAll('\\', '/');
    if (!path.endsWith('.dart') && !path.endsWith('.yaml')) continue;
    if (path.contains('/.dart_tool/') ||
        path.contains('/build/') ||
        path.contains('/.git/')) {
      continue;
    }
    final bytes = entity.readAsBytesSync();
    try {
      utf8.decode(bytes, allowMalformed: false);
    } catch (_) {
      bad.add(path);
    }
  }
  if (bad.isEmpty) {
    print('All scanned files are valid UTF-8');
  } else {
    print('Invalid UTF-8 files (${bad.length}):');
    for (final p in bad) {
      print('  $p');
    }
    exitCode = 1;
  }
}
