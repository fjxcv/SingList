import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../repository/playlist_repository.dart';
import '../../repository/song_repository.dart';
import '../../repository/tag_repository.dart';
import '../../service/import_parser.dart';
import '../../service/queue_generator.dart';
import '../../state/providers.dart';

class GeneratorPage extends ConsumerStatefulWidget {
  const GeneratorPage({super.key});

  @override
  ConsumerState<GeneratorPage> createState() => _GeneratorPageState();
}

class _GeneratorPageState extends ConsumerState<GeneratorPage> {
  String sourceType = 'all';
  int? selectedTag;
  int? selectedPlaylist;
  int randomCount = 15;
  bool avoidRepeat = true;
  int warmupCount = 2;
  List<Song> _warmupSongs = const [];

  @override
  Widget build(BuildContext context) {
    final tags = ref.watch(tagsProvider).valueOrNull ?? [];
    final playlists = ref.watch(normalPlaylistsProvider).valueOrNull ?? [];
    return Scaffold(
      appBar: AppBar(title: const Text('生成 / 导入')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const Text('来源选择'),
          Row(
            children: [
              ChoiceChip(
                label: const Text('全部歌曲'),
                selected: sourceType == 'all',
                onSelected: (_) => setState(() => sourceType = 'all'),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('按标签'),
                selected: sourceType == 'tag',
                onSelected: (_) => setState(() => sourceType = 'tag'),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('普通歌单'),
                selected: sourceType == 'playlist',
                onSelected: (_) => setState(() => sourceType = 'playlist'),
              ),
            ],
          ),
          if (sourceType == 'tag')
            DropdownButtonFormField<int>(
              value: selectedTag,
              hint: const Text('选择标签'),
              items: tags.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))).toList(),
              onChanged: (v) => setState(() => selectedTag = v),
            ),
          if (sourceType == 'playlist')
            DropdownButtonFormField<int>(
              value: selectedPlaylist,
              hint: const Text('选择普通歌单'),
              items: playlists.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
              onChanged: (v) => setState(() => selectedPlaylist = v),
            ),
          const SizedBox(height: 12),
          const Divider(),
          _buildBrushGenerator(context),
          const Divider(),
          _buildRandomGenerator(context),
          const Divider(),
          _buildImportSection(context),
        ],
      ),
    );
  }

  Future<List<Song>> _loadSource() async {
    final songRepo = ref.read(songRepoProvider);
    if (sourceType == 'all') {
      return songRepo.watchAll().first;
    } else if (sourceType == 'tag' && selectedTag != null) {
      return ref.read(tagRepoProvider).songsByTag(selectedTag!).first;
    } else if (sourceType == 'playlist' && selectedPlaylist != null) {
      return ref.read(playlistRepoProvider).songsInPlaylist(selectedPlaylist!).first;
    }
    return [];
  }

  Future<List<Song>> _loadWarmupSongs() async {
    final tags = await ref.read(tagRepoProvider).watchAll().first;
    if (tags.isEmpty) return [];
    final warmupTag = tags.firstWhere((t) => t.name == '开嗓', orElse: () => tags.first);
    return ref.read(tagRepoProvider).songsByTag(warmupTag.id).first;
  }

  Widget _buildBrushGenerator(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('A) 刷歌生成器', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('逐首浏览来源歌曲，标记 ⭐/✅/❌，结束后生成新的 KQueue'),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('开嗓暖场随机数：'),
                SizedBox(
                  width: 80,
                  child: TextFormField(
                    initialValue: warmupCount.toString(),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => setState(() => warmupCount = int.tryParse(v) ?? 0),
                  ),
                )
              ],
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () async {
                final source = await _loadSource();
                if (source.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先选择有效来源')));
                  return;
                }
                _warmupSongs = await _loadWarmupSongs();
                if (!mounted) return;
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BrushFlowPage(
                      songs: source,
                      warmupCount: warmupCount,
                      warmupSongs: _warmupSongs,
                    ),
                  ),
                ) as BrushSelection?;
                if (result != null) {
                  await _persistQueue(result.mergeOrder());
                }
              },
              child: const Text('开始刷歌'),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildRandomGenerator(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('B) 随机生成器', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('数量：'),
              SizedBox(
                width: 80,
                child: TextFormField(
                  initialValue: randomCount.toString(),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(() => randomCount = int.tryParse(v) ?? 15),
                ),
              ),
              const SizedBox(width: 12),
              Switch(
                value: avoidRepeat,
                onChanged: (v) => setState(() => avoidRepeat = v),
              ),
              const Text('本次尽量不重复'),
            ],
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () async {
              final source = await _loadSource();
              if (source.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先选择有效来源')));
                return;
              }
              final chosen = pickRandomSongs(source, randomCount, avoidRepeat: avoidRepeat);
              final selection = BrushSelection(favorites: chosen, likes: const []);
              await _persistQueue(selection.mergeOrder());
            },
            child: const Text('生成 KQueue'),
          )
        ]),
      ),
    );
  }

  Widget _buildImportSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('粘贴导入'),
          const SizedBox(height: 8),
          const Text('从剪贴板读取文本，格式：每行 “歌名 - 歌手” 或 “歌名/歌手”'),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: () async {
              final data = await Clipboard.getData('text/plain');
              final content = data?.text ?? '';
              final parsed = parseImportText(content);
              if (parsed.isEmpty) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('未识别到歌曲行')));
                return;
              }
              await _importSongs(parsed);
            },
            child: const Text('粘贴并导入为新队列'),
          ),
        ]),
      ),
    );
  }

  Future<void> _persistQueue(List<Song> songs) async {
    if (songs.isEmpty) return;
    final repo = ref.read(playlistRepoProvider);
    final queueId = await repo.create('KQueue ${DateTime.now().toIso8601String()}', PlaylistType.kQueue);
    for (var i = 0; i < songs.length; i++) {
      await repo.enqueue(queueId, songs[i].id, i);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已生成新的队列（共${songs.length}首）')));
  }

  Future<void> _importSongs(List<ParsedSong> parsed) async {
    final songRepo = ref.read(songRepoProvider);
    final db = ref.read(databaseProvider);
    final songs = <Song>[];
    for (final item in parsed) {
      await songRepo.addSong(item.title, item.artist);
      final existing = await (db.select(db.songs)
            ..where((tbl) => tbl.title.equals(item.title) & tbl.artist.equals(item.artist)))
          .getSingle();
      songs.add(existing);
    }
    await _persistQueue(songs);
  }
}

class BrushFlowPage extends StatefulWidget {
  final List<Song> songs;
  final int warmupCount;
  final List<Song> warmupSongs;
  const BrushFlowPage({super.key, required this.songs, required this.warmupCount, required this.warmupSongs});

  @override
  State<BrushFlowPage> createState() => _BrushFlowPageState();
}

class _BrushFlowPageState extends State<BrushFlowPage> {
  int index = 0;
  final favorites = <Song>[];
  final likes = <Song>[];

  @override
  Widget build(BuildContext context) {
    if (index >= widget.songs.length) {
      final warmup = _buildWarmup(widget.songs);
      return _finish(context, warmup);
    }
    final song = widget.songs[index];
    return Scaffold(
      appBar: AppBar(title: Text('刷歌 ${index + 1}/${widget.songs.length}')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(song.title, style: Theme.of(context).textTheme.headlineSmall),
            Text(song.artist),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: () => _mark(song, favorites),
                  icon: const Icon(Icons.star),
                  label: const Text('特别想唱'),
                ),
                FilledButton.icon(
                  onPressed: () => _mark(song, likes),
                  icon: const Icon(Icons.check),
                  label: const Text('想唱'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _skip(),
                  icon: const Icon(Icons.close),
                  label: const Text('不想'),
                )
              ],
            )
          ],
        ),
      ),
    );
  }

  List<Song> _buildWarmup(List<Song> source) {
    if (widget.warmupCount <= 0) return [];
    final warmups = List<Song>.from(widget.warmupSongs);
    warmups.shuffle(Random());
    return warmups.take(widget.warmupCount).toList();
  }

  Widget _finish(BuildContext context, List<Song> warmups) {
    return Scaffold(
      appBar: AppBar(title: const Text('完成')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('⭐ ${favorites.length} | ✅ ${likes.length}'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  BrushSelection(favorites: favorites, likes: likes, warmups: warmups),
                );
              },
              child: const Text('生成队列'),
            )
          ],
        ),
      ),
    );
  }

  void _mark(Song song, List<Song> bucket) {
    bucket.add(song);
    setState(() => index++);
  }

  void _skip() => setState(() => index++);
}

extension on BrushSelection {
  List<Song> mergeOrder() => mergeBrushSelections(this);
}
