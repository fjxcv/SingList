import 'dart:io';

void main() {
  final path = 'lib/service/kqueue_text_service.dart';
  var text = File(path).readAsStringSync();
  text = text.replaceAll(
    RegExp(r"buffer\.writeln\('[^']*'\);"),
    "buffer.writeln('#K\u6b4c\u6b4c\u5355');",
  );
  text = text.replaceFirst(
    RegExp(r"throw Exception\('[^']*'\);"),
    "throw Exception('\u672a\u80fd\u89e3\u6790\u5230\u6709\u6548\u7684\u6b4c\u66f2');",
  );
  File(path).writeAsStringSync(text);
  print('kqueue_text_service fixed');
}
