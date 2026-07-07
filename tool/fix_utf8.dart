import 'dart:io';

void main() {
  _writePubspec();
  _fixTestFile();
  _fixIosComponents();
  print('UTF-8 fixes applied');
}

void _writePubspec() {
  final desc =
      'K\u6b4c\u9009\u6b4c - \u672c\u5730\u6b4c\u66f2\u7ba1\u7406 Flutter MVP';
  final content = '''
name: sing_list
description: "$desc"
version: 0.1.0
publish_to: 'none'

environment:
  sdk: ">=3.3.0 <4.0.0"
  flutter: ">=3.22.0 <4.0.0"

dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.5.1
  flutter_hooks: ^0.18.6
  drift: ^2.17.0
  sqlite3_flutter_libs: ^0.5.24
  path: ^1.9.0
  path_provider: ^2.1.4
  share_plus: ^7.2.1
  intl: ^0.19.0
  file_picker: ^8.0.0

flutter:
  uses-material-design: true

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
  drift_dev: ^2.17.0
  build_runner: ^2.4.8
  freezed: ^2.5.2
  lint: ^2.3.0
  very_good_analysis: ^5.1.0
''';
  File('pubspec.yaml').writeAsStringSync(content);
}

void _fixTestFile() {
  final header = '#K\u6b4c\u6b4c\u5355';
  final path = 'test/kqueue_text_service_test.dart';
  final bytes = File(path).readAsBytesSync();
  var text = String.fromCharCodes(bytes);
  text = text.replaceAllMapped(
    RegExp(r"importFromText\('.*?\\nHello - Singer"),
    (_) => "importFromText('$header\\nHello - Singer",
  );
  text = text.replaceAllMapped(
    RegExp(r"expect\(text\.trim\(\), '.*?\\nSong1"),
    (_) => "expect(text.trim(), '$header\\nSong1",
  );
  File(path).writeAsStringSync(text);
}

void _fixIosComponents() {
  final path = 'lib/ui/widgets/ios_components.dart';
  final bytes = File(path).readAsBytesSync();
  var text = String.fromCharCodes(bytes);
  text = text.replaceFirst(
    RegExp(r"this\.label = '[^']*', required this\.onPressed\)"),
    "this.label = '\u77e5\u9053\u4e86', required this.onPressed)",
  );
  text = text.replaceAll(
    "String cancelLabel = '\u00c8\u00a1\u00cf\u00fb',",
    "String cancelLabel = '\u53d6\u6d88',",
  );
  text = text.replaceAll(
    "String confirmLabel = '\u00c8\u00b7\u00b6\u00a8',",
    "String confirmLabel = '\u786e\u5b9a',",
  );
  File(path).writeAsStringSync(text);
}
