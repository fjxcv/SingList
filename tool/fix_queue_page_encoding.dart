import 'dart:convert';
import 'dart:io';

void main() {
  final path = 'lib/ui/pages/queue_page.dart';
  final bytes = File(path).readAsBytesSync();
  var text = utf8.decode(bytes, allowMalformed: true);

  final fixes = <RegExp, String>{
    RegExp(
      r"title: Text\(selectionMode \? '[^']*' : widget\.playlist\.name\)",
    ): r"title: Text(selectionMode ? '\u5df2\u9009 ${selectedItemIds.length}' : widget.playlist.name)",
    RegExp(
      r"onPressed: \(\) => _handleMoveSelected\(context, repo\),\s*\n\s*child: Text\('[^']*'\)",
    ): r"onPressed: () => _handleMoveSelected(context, repo),\n                      child: Text('\u79fb\u52a8...')",
    RegExp(
      r": \(\) => _confirmDeleteSelected\(context, repo\),\s*\n\s*child: Text\('[^']*'\)",
    ): r": () => _confirmDeleteSelected(context, repo),\n                      child: const Text('\u5220\u9664\u6240\u9009')",
    RegExp(
      r"Text\('\$\{selectedItemIds\.length\} [^']*'\)",
    ): r"Text('${selectedItemIds.length} \u5df2\u9009')",
    RegExp(
      r"title: Text\('添加歌曲到[^']*'\)",
    ): r"title: const Text('\u6dfb\u52a0\u6b4c\u66f2\u5230\u961f\u5217')",
    RegExp(
      r"message: '确定要删除[^']*'",
    ): r"message: '\u786e\u5b9a\u8981\u5220\u9664\u9009\u4e2d\u7684 ${selectedItemIds.length} \u9996\u6b4c\u66f2\u5417\uff1f'",
    RegExp(
      r"SnackBar\(content: Text\('删除成功 \$\{selectedItemIds\.length\} [^']*'\)\)",
    ): r"SnackBar(content: Text('\u5220\u9664\u6210\u529f ${selectedItemIds.length} \u9996'))",
    RegExp(
      r"builder: \(context, setState\) => AlertDialog\(\s*\n\s*title: Text\('[^']*'\)",
    ): r"builder: (context, setState) => AlertDialog(\n          title: const Text('\u79fb\u52a8...')",
    RegExp(
      r"labelText: '或[^']*'",
    ): r"labelText: '\u6216\u9009\u62e9\u6b4c\u66f2'",
    RegExp(
      r"errorText = '位置[^']*'",
    ): r"errorText = '\u4f4d\u7f6e\u9700\u5728 1 \u5230 $maxPosition \u4e4b\u95f4'",
  };

  var changed = 0;
  for (final entry in fixes.entries) {
    final before = text;
    text = text.replaceAll(entry.key, entry.value);
    if (text != before) changed++;
  }

  File(path).writeAsStringSync(text, encoding: utf8);
  print('fixed $changed patterns');
}
