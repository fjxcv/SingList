import 'dart:io';

void main() {
  _patchIosComponents();
}

void _patchIosComponents() {
  final path = 'lib/ui/widgets/ios_components.dart';
  var text = File(path).readAsStringSync();
  text = text.replaceFirst(
    RegExp(r"this\.label = '[^']*', required this\.onPressed\)"),
    "this.label = '\u77e5\u9053\u4e86', required this.onPressed)",
  );
  text = text.replaceFirst(
    RegExp(r"String cancelLabel = '[^']*',"),
    "String cancelLabel = '\u53d6\u6d88',",
  );
  text = text.replaceFirst(
    RegExp(r"String confirmLabel = '[^']*',"),
    "String confirmLabel = '\u786e\u5b9a',",
  );
  File(path).writeAsStringSync(text);
  print('ios_components patched');
}
