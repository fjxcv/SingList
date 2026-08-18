import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../lyrics/lyric_candidate.dart';
import '../../lyrics/lyric_search_service.dart';
import '../../lyrics/network_connectivity_service.dart';
import '../../state/providers.dart';
import 'ai_settings_page.dart';
import 'lyrics_edit_page.dart';
import 'lyrics_processing_page.dart';

enum LyricsSearchResultAction {
  processWithAi,
  editDirectly,
}

class LyricsSearchPage extends ConsumerStatefulWidget {
  const LyricsSearchPage({
    super.key,
    required this.song,
    this.resultAction = LyricsSearchResultAction.processWithAi,
  });

  final Song song;
  final LyricsSearchResultAction resultAction;

  @override
  ConsumerState<LyricsSearchPage> createState() => _LyricsSearchPageState();
}

class _LyricsSearchPageState extends ConsumerState<LyricsSearchPage> {
  late final TextEditingController _titleController;
  late final TextEditingController _artistController;
  List<LyricCandidate> _candidates = [];
  bool _loading = false;
  String _loadingMessage = '正在搜索歌词…';
  String? _error;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.song.title);
    _artistController = TextEditingController(text: widget.song.artist);
    WidgetsBinding.instance.addPostFrameCallback((_) => _search());
  }

  Future<void> _search() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _loadingMessage =
          widget.resultAction == LyricsSearchResultAction.processWithAi
              ? '正在检查网络…'
              : '正在搜索歌词…';
    });
    try {
      if (widget.resultAction == LyricsSearchResultAction.processWithAi) {
        await ref
            .read(networkConnectivityServiceProvider)
            .checkInternetAccess();
        if (!mounted) return;
        setState(() => _loadingMessage = '网络正常，正在连接歌词服务…');
      }
      final result = await ref.read(lyricSearchServiceProvider).search(
            trackName: _titleController.text,
            artistName: _artistController.text,
          );
      if (!mounted) return;
      setState(() => _candidates = result);
    } on NetworkConnectivityException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } on LyricSearchException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _choose(LyricCandidate candidate) async {
    if (candidate.instrumental) return;
    final version = [
      if (candidate.albumName?.isNotEmpty == true) candidate.albumName!,
      if (candidate.durationSeconds != null)
        _durationLabel(candidate.durationSeconds!),
    ].join(' · ');
    if (widget.resultAction == LyricsSearchResultAction.editDirectly) {
      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => LyricsEditPage(
            songId: widget.song.id,
            songTitle: widget.song.title,
            repository: ref.read(lyricsRepoProvider),
            initialJapanese: candidate.lyrics,
            originalText: candidate.lyrics,
            sourceName: candidate.sourceName,
            sourceUrl: candidate.sourceUrl,
            versionLabel: version.isEmpty ? null : version,
          ),
        ),
      );
      if (saved == true && mounted) Navigator.pop(context, true);
      return;
    }

    final configRepository = ref.read(aiConfigRepositoryProvider);
    final config = await configRepository.loadConfig();
    final apiKey = await configRepository.readApiKey();
    if (!mounted) return;
    if (!config.enabled || apiKey == null || apiKey.isEmpty) {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(builder: (_) => const AiSettingsPage()),
      );
      return;
    }
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => LyricsProcessingPage(
          song: widget.song,
          rawLyrics: candidate.lyrics,
          sourceName: candidate.sourceName,
          sourceUrl: candidate.sourceUrl,
          versionLabel: version.isEmpty ? null : version,
        ),
      ),
    );
    if (saved == true && mounted) Navigator.pop(context, true);
  }

  Future<void> _manual() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => LyricsEditPage(
          songId: widget.song.id,
          songTitle: widget.song.title,
          repository: ref.read(lyricsRepoProvider),
        ),
      ),
    );
    if (saved == true && mounted) Navigator.pop(context, true);
  }

  String _durationLabel(double seconds) {
    final total = seconds.round();
    return '${total ~/ 60}:${(total % 60).toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.resultAction == LyricsSearchResultAction.processWithAi
              ? '自动添加歌词'
              : '从 LRCLIB 查找',
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: '歌名',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _artistController,
                  decoration: const InputDecoration(
                    labelText: '歌手',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _loading ? null : _search,
                    icon: const Icon(Icons.search),
                    label: const Text('搜索 LRCLIB'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 14),
                        Text(_loadingMessage),
                      ],
                    ),
                  )
                : _buildResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_error != null) {
      return _EmptyState(message: _error!, onManual: _manual);
    }
    if (_candidates.isEmpty) {
      return _EmptyState(
        message: '没有找到合适的歌词版本',
        onManual: _manual,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
      itemCount: _candidates.length + 1,
      itemBuilder: (context, index) {
        if (index == _candidates.length) {
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton(
              onPressed: _manual,
              child: const Text('都不正确，直接进入编辑'),
            ),
          );
        }
        final item = _candidates[index];
        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: item.instrumental ? null : () => _choose(item),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.trackName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      if (item.instrumental) const Chip(label: Text('纯音乐')),
                    ],
                  ),
                  Text(item.artistName),
                  if (item.albumName?.isNotEmpty == true)
                    Text('专辑：${item.albumName}'),
                  if (item.durationSeconds != null)
                    Text('时长：${_durationLabel(item.durationSeconds!)}'),
                  const Text('来源：LRCLIB'),
                  if (!item.instrumental) ...[
                    const Divider(),
                    for (final line in item.previewLines)
                      Text(
                        line,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message, required this.onManual});

  final String message;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: onManual,
              child: const Text('直接进入编辑'),
            ),
          ],
        ),
      ),
    );
  }
}
