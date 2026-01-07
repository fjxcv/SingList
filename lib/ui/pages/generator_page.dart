import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../state/brush_generator_state.dart';
import '../../state/providers.dart';
import 'queue_page.dart';
import 'random_queue_page.dart';

class GeneratorPage extends StatelessWidget {
  const GeneratorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('生成 KQueue'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '刷歌模式'),
              Tab(text: '随机生成'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _BrushGeneratorTab(),
            RandomQueuePage(),
          ],
        ),
      ),
    );
  }
}

class _BrushGeneratorTab extends ConsumerWidget {
  const _BrushGeneratorTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(brushGeneratorProvider);
    final notifier = ref.read(brushGeneratorProvider.notifier);
    final tags = ref.watch(tagsProvider).valueOrNull ?? [];
    final playlists = ref.watch(normalPlaylistsProvider).valueOrNull ?? [];

    if (state.inBrushMode) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: _BrushBody(
          state: state,
          onFavorite: notifier.markFavorite,
          onLike: notifier.markLike,
          onSkip: notifier.skip,
          onFinish: () async {
            final playlist = await notifier.createQueue();
            if (playlist == null || !context.mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => QueuePage(playlist: playlist),
              ),
            );
          },
          onBack: () => _handleBack(context, notifier),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('全部歌曲'),
                selected: state.sourceType == BrushSourceType.all,
                onSelected: (_) => notifier.updateSourceType(BrushSourceType.all),
              ),
              ChoiceChip(
                label: const Text('按标签'),
                selected: state.sourceType == BrushSourceType.tag,
                onSelected: (_) => notifier.updateSourceType(BrushSourceType.tag),
              ),
              ChoiceChip(
                label: const Text('普通歌单'),
                selected: state.sourceType == BrushSourceType.playlist,
                onSelected: (_) => notifier.updateSourceType(BrushSourceType.playlist),
              ),
              FilledButton.icon(
                onPressed: state.isLoading ? null : () => notifier.loadSongs(),
                icon: const Icon(Icons.play_arrow),
                label: const Text('开始刷歌'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (state.sourceType == BrushSourceType.tag)
            DropdownButtonFormField<int>(
              value: state.selectedTagId,
              decoration: const InputDecoration(labelText: '选择标签'),
              items:
                  tags.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))).toList(),
              onChanged: (v) => notifier.updateTag(v),
            ),
          if (state.sourceType == BrushSourceType.playlist)
            DropdownButtonFormField<int>(
              value: state.selectedPlaylistId,
              decoration: const InputDecoration(labelText: '选择普通歌单'),
              items: playlists
                  .map((p) => DropdownMenuItem(value: p.id, child: Text(p.name)))
                  .toList(),
              onChanged: (v) => notifier.updatePlaylist(v),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Switch(
                value: state.warmupEnabled,
                onChanged: notifier.updateWarmupEnabled,
              ),
              const Text('开嗓随机暖场'),
              const SizedBox(width: 8),
              SizedBox(
                width: 72,
                child: TextFormField(
                  initialValue: state.warmupCount.toString(),
                  decoration: const InputDecoration(labelText: '数量'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) {
                    notifier.updateWarmupCount(int.parse(v.trim()));
                  },
                ),
              ),
            ],
          ),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(state.error!, style: const TextStyle(color: Colors.red)),
            ),
          const Spacer(),
          const Center(child: Text('选择来源后开始刷歌')),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Future<void> _handleBack(
    BuildContext context,
    BrushGeneratorNotifier notifier,
  ) async {
    final action = await showDialog<_BrushBackAction>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('返回刷歌设置'),
        content: const Text('是否保存已刷的歌并生成 KQueue 歌单？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _BrushBackAction.cancel),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _BrushBackAction.discard),
            child: const Text('不保存'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, _BrushBackAction.save),
            child: const Text('保存并生成'),
          ),
        ],
      ),
    );
    if (action == null || action == _BrushBackAction.cancel) return;
    if (action == _BrushBackAction.save) {
      final playlist = await notifier.createQueue();
      if (playlist != null && context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => QueuePage(playlist: playlist),
          ),
        );
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('暂无可保存的歌曲')),
        );
      }
    }
    notifier.exitBrushMode();
  }
}

enum _BrushBackAction { cancel, discard, save }

class _BrushBody extends StatelessWidget {
  const _BrushBody({
    required this.state,
    required this.onFavorite,
    required this.onLike,
    required this.onSkip,
    required this.onFinish,
    required this.onBack,
  });

  final BrushGeneratorState state;
  final VoidCallback onFavorite;
  final VoidCallback onLike;
  final VoidCallback onSkip;
  final VoidCallback onFinish;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    Widget content;
    if (state.currentSong != null) {
      content = _SongCard(
        song: state.currentSong!,
        progress: '${state.currentIndex + 1}/${state.songs.length}',
        onFavorite: onFavorite,
        onLike: onLike,
        onSkip: onSkip,
        onBack: onBack,
      );
    } else if (state.completed) {
      content = _FinishCard(
        favorites: state.favorites,
        likes: state.likes,
        onFinish: onFinish,
        onBack: onBack,
      );
    } else {
      content = const Text('选择来源后开始刷歌');
    }
    return Center(
      child: SingleChildScrollView(
        child: content,
      ),
    );
  }
}

class _SongCard extends StatelessWidget {
  const _SongCard({
    required this.song,
    required this.progress,
    required this.onFavorite,
    required this.onLike,
    required this.onSkip,
    required this.onBack,
  });

  final Song song;
  final String progress;
  final VoidCallback onFavorite;
  final VoidCallback onLike;
  final VoidCallback onSkip;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: '返回',
                onPressed: onBack,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Text(progress, style: Theme.of(context).textTheme.bodyMedium),
            ),
            const SizedBox(height: 8),
            Text(song.title, style: Theme.of(context).textTheme.headlineSmall),
            Text(song.artist, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: onFavorite,
                  icon: const Icon(Icons.star),
                  label: const Text('特别想唱'),
                ),
                FilledButton.icon(
                  onPressed: onLike,
                  icon: const Icon(Icons.check),
                  label: const Text('想唱'),
                ),
                OutlinedButton.icon(
                  onPressed: onSkip,
                  icon: const Icon(Icons.close),
                  label: const Text('不想唱'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FinishCard extends StatelessWidget {
  const _FinishCard({
    required this.favorites,
    required this.likes,
    required this.onFinish,
    required this.onBack,
  });

  final List<Song> favorites;
  final List<Song> likes;
  final VoidCallback onFinish;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: '返回',
                onPressed: onBack,
              ),
            ),
            Text('⭐ ${favorites.length} | ✅ ${likes.length}'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onFinish,
              child: const Text('生成 KQueue 并查看'),
            ),
          ],
        ),
      ),
    );
  }
}
