import 'dart:io';

void main() {
  final path = 'lib/ui/pages/playlists_page.dart';
  var text = File(path).readAsStringSync();
  text = text.replaceFirst(
    RegExp(r"subtitle: '[^']*',\s*\n\s*onOpen: \(\) => Navigator\.push\(\s*\n\s*context,\s*\n\s*MaterialPageRoute\(builder: \(_\) => SimplePlaylistPage"),
    "subtitle: '\u6b4c\u66f2\u4e0d\u91cd\u590d',\n                              onOpen: () => Navigator.push(\n                                context,\n                                MaterialPageRoute(builder: (_) => SimplePlaylistPage",
  );
  File(path).writeAsStringSync(text);
  print('fixed');
}
