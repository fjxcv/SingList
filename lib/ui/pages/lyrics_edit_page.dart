import 'package:flutter/material.dart';

import '../../lyrics/furigana_parser.dart';
import '../../lyrics/lyrics_repository.dart';

class LyricsEditPage extends StatefulWidget {
  const LyricsEditPage({
    super.key,
    required this.songId,
    required this.songTitle,
    required this.repository,
    this.initialJapanese = '',
    this.initialTranslation = '',
  });

  final int songId;
  final String songTitle;
  final LyricsRepository repository;
  final String initialJapanese;
  final String initialTranslation;

  @override
  State<LyricsEditPage> createState() => _LyricsEditPageState();
}

class _LyricsEditPageState extends State<LyricsEditPage> {
  late final TextEditingController _japaneseController;
  late final TextEditingController _translationController;
  String? _validationMessage;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _japaneseController = TextEditingController(text: widget.initialJapanese);
    _translationController =
        TextEditingController(text: widget.initialTranslation);
  }

  @override
  void dispose() {
    _japaneseController.dispose();
    _translationController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final japanese = _japaneseController.text;
    if (japanese.trim().isEmpty) {
      setState(() => _validationMessage = '请输入日文注音歌词');
      return;
    }
    final error = const FuriganaParser().validate(japanese);
    if (error != null) {
      setState(() => _validationMessage = error.toString());
      return;
    }

    setState(() {
      _validationMessage = null;
      _saving = true;
    });
    await widget.repository.save(
      songId: widget.songId,
      japanese: japanese,
      translation: _translationController.text,
    );
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('编辑歌词 · ${widget.songTitle}'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('保存'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '注音格式',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '用 [汉字|平假名] 标记注音；普通假名、标点直接输入。'
                    '歌词和翻译均支持多行，并默认按行对应。',
                  ),
                  const SizedBox(height: 8),
                  const SelectableText(
                    '[未熟|みじゅく]、[無常|むじょう]されど'
                    '[美|うつく]しくあれ',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _japaneseController,
            minLines: 8,
            maxLines: null,
            decoration: InputDecoration(
              labelText: '日文注音歌词',
              alignLabelWithHint: true,
              errorText: _validationMessage,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _translationController,
            minLines: 6,
            maxLines: null,
            decoration: const InputDecoration(
              labelText: '中文翻译（可选）',
              alignLabelWithHint: true,
              helperText: '行数可以少于或多于日文歌词，空缺行会留空。',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}
