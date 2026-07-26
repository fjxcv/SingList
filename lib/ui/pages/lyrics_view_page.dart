import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/db/app_database.dart';
import '../../lyrics/lyrics_repository.dart';
import '../../service/screen_awake_service.dart';
import '../widgets/furigana_lyrics_view.dart';
import 'lyrics_edit_page.dart';

class LyricsViewPage extends StatefulWidget {
  const LyricsViewPage({
    super.key,
    required this.song,
    required this.initialLyrics,
    required this.repository,
  });

  final Song song;
  final SongLyric initialLyrics;
  final LyricsRepository repository;

  @override
  State<LyricsViewPage> createState() => _LyricsViewPageState();
}

class _LyricsViewPageState extends State<LyricsViewPage> {
  static const _screenAwake = ScreenAwakeService();

  late SongLyric _lyrics;
  double _fontSize = 28;
  bool _showTranslation = true;
  bool _ktvMode = false;

  @override
  void initState() {
    super.initState();
    _lyrics = widget.initialLyrics;
    _screenAwake.setEnabled(true);
  }

  @override
  void dispose() {
    _screenAwake.setEnabled(false);
    if (_ktvMode) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  Future<void> _toggleKtvMode() async {
    final enabled = !_ktvMode;
    setState(() => _ktvMode = enabled);
    await SystemChrome.setEnabledSystemUIMode(
      enabled ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
  }

  Future<void> _edit() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => LyricsEditPage(
          songId: widget.song.id,
          songTitle: widget.song.title,
          repository: widget.repository,
          initialJapanese: _lyrics.japaneseText,
          initialTranslation: _lyrics.chineseTranslation,
        ),
      ),
    );
    if (saved == true) {
      final updated = await widget.repository.findForSong(widget.song.id);
      if (updated != null && mounted) setState(() => _lyrics = updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final background = _ktvMode ? const Color(0xFF090B10) : null;
    final foreground = _ktvMode ? const Color(0xFFF7F7FA) : null;
    return Scaffold(
      backgroundColor: background,
      appBar: _ktvMode
          ? null
          : AppBar(
              title: Text(widget.song.title),
              actions: [
                IconButton(
                  tooltip: '编辑歌词',
                  onPressed: _edit,
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
      body: SafeArea(
        child: Column(
          children: [
            Material(
              color: _ktvMode
                  ? const Color(0xFF151923)
                  : Theme.of(context).colorScheme.surfaceContainer,
              child: Row(
                children: [
                  if (_ktvMode)
                    IconButton(
                      tooltip: '返回',
                      color: foreground,
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                    ),
                  IconButton(
                    tooltip: '减小字号',
                    color: foreground,
                    onPressed: _fontSize <= 18
                        ? null
                        : () => setState(() => _fontSize -= 2),
                    icon: const Icon(Icons.text_decrease),
                  ),
                  Text(
                    '${_fontSize.round()}',
                    style: TextStyle(color: foreground),
                  ),
                  IconButton(
                    tooltip: '增大字号',
                    color: foreground,
                    onPressed: _fontSize >= 48
                        ? null
                        : () => setState(() => _fontSize += 2),
                    icon: const Icon(Icons.text_increase),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: _showTranslation ? '隐藏中文翻译' : '显示中文翻译',
                    color: foreground,
                    onPressed: () => setState(
                      () => _showTranslation = !_showTranslation,
                    ),
                    icon: Icon(
                      _showTranslation
                          ? Icons.subtitles
                          : Icons.subtitles_off_outlined,
                    ),
                  ),
                  IconButton(
                    tooltip: _ktvMode ? '退出 KTV 模式' : 'KTV 模式',
                    color: foreground,
                    onPressed: _toggleKtvMode,
                    icon: Icon(
                      _ktvMode ? Icons.fullscreen_exit : Icons.fullscreen,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  _ktvMode ? 24 : 18,
                  _ktvMode ? 28 : 20,
                  _ktvMode ? 24 : 18,
                  48,
                ),
                child: FuriganaLyricsView(
                  japanese: _lyrics.japaneseText,
                  translation: _lyrics.chineseTranslation,
                  fontSize: _ktvMode ? _fontSize + 6 : _fontSize,
                  showTranslation: _showTranslation,
                  textColor: foreground,
                  translationColor: _ktvMode ? const Color(0xFFBFC7D5) : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
