import 'dart:convert';
import 'dart:io';

void main() {
  final path = 'lib/ui/pages/generator_page.dart';
  final bytes = File(path).readAsBytesSync();
  try {
    utf8.decode(bytes, allowMalformed: false);
    print('valid');
  } catch (e) {
    print(e);
    for (var i = 0; i < bytes.length; i++) {
      if (bytes[i] >= 0x80) {
        try {
          utf8.decode(bytes.sublist(i, i + 3 > bytes.length ? bytes.length : i + 3));
        } catch (_) {
          print('bad byte at $i: 0x${bytes[i].toRadixString(16)} context=${String.fromCharCodes(bytes.sublist(i > 20 ? i - 20 : 0, i + 20 > bytes.length ? bytes.length : i + 20))}');
          break;
        }
      }
    }
  }
}
