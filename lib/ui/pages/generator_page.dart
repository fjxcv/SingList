import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../state/brush_generator_state.dart';
import '../../state/providers.dart';
import 'queue_page.dart';
import 'random_queue_page.dart';
import '../widgets/bottom_fab_action.dart';

class GeneratorPage extends StatelessWidget {
  const GeneratorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 48,
          title: const Text('生成 KQueue'),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(40),
            child: TabBar(
              tabs: [
                Tab(text: '刷歌模式'),
                Tab(text: '随机生成'),
              ],
            ),
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
          onFinish: () => _handleFinish(context, notifier),
          onBack: () => _handleBack(context, notifier),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 96),
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
                  ],
                ),
                const SizedBox(height: 8),
                if (state.sourceType == BrushSourceType.tag)
                  DropdownButtonFormField<int>(
                    value: state.selectedTagId,
                    decoration: const InputDecoration(labelText: '选择标签'),
                    items: tags
                        .map((t) => DropdownMenuItem(value: t.id, child: Text(t.name)))
                        .toList(),
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
                    const Text('随机开嗓曲'),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 56,
                      child: TextFormField(
                        key: ValueKey('warmup-${state.warmupCount}'),
                        initialValue: state.warmupCount.toString(),
                        decoration: const InputDecoration(
                          labelText: '数量',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (v) {
                          final value = int.tryParse(v.trim()) ?? 0;
                          notifier.updateWarmupCount(value);
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
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 12,
            child: Center(
              child: BottomFabAction(
                onPressed:
                    state.isLoading ? null : () => _handleStartBrush(context, notifier),
                icon: Icons.play_arrow,
                label: '开始刷歌',
                isLoading: state.isLoading,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleStartBrush(
    BuildContext context,
    BrushGeneratorNotifier notifier,
  ) async {
    final state = notifier.state;
    if (state.warmupEnabled && state.warmupCount > 0) {
      final count = await notifier.fetchWarmupTagCount();
      if (count < state.warmupCount && context.mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('开嗓歌曲不足'),
            content: Text('需要 ${state.warmupCount} 首，当前只有 $count 首。'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('知道了')),
            ],
          ),
        );
        return;
      }
    }
    await notifier.loadSongs();
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
        notifier.exitBrushMode();
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

  Future<void> _handleFinish(
    BuildContext context,
    BrushGeneratorNotifier notifier,
  ) async {
    List<Song> warmups = [];
    if (notifier.state.warmupEnabled && notifier.state.warmupCount > 0) {
      final plan = notifier.buildWarmupPlan();
      warmups = [...plan.forced];
      var remaining = plan.requiredCount - warmups.length;
      if (remaining > 0 && plan.liked.isNotEmpty) {
        final likedSelected = notifier.pickRandomLikedWarmups(plan.liked, remaining);
        warmups.addAll(likedSelected);
        remaining = plan.requiredCount - warmups.length;
      }
      if (remaining > 0) {
        final wantMore = await _confirmWarmupShortage(
          context,
          warmups,
          remaining,
        );
        if (wantMore == true) {
          final candidates = notifier.state.warmupSongs
              .where((song) => warmups.every((selected) => selected.id != song.id))
              .toList();
          final extras = await _selectExtraWarmups(context, candidates, remaining);
          if (extras != null) {
            warmups.addAll(extras);
          }
        }
      }
    }
    final playlist = await notifier.createQueue(selectedWarmups: warmups);
    if (playlist == null) {
      notifier.exitBrushMode();
      return;
    }
    if (!context.mounted) return;
    notifier.exitBrushMode();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QueuePage(playlist: playlist),
      ),
    );
  }

  Future<bool?> _confirmWarmupShortage(
    BuildContext context,
    List<Song> selected,
    int missing,
  ) {
    final selectedNames = selected.isEmpty
        ? '暂未选择'
        : selected.map((s) => s.title).join('、');
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('开嗓歌曲不足'),
        content: Text('已选择：$selectedNames\n还差 $missing 首，是否从开嗓标签中补选？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('否')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('是')),
        ],
      ),
    );
  }

  Future<List<Song>?> _selectExtraWarmups(
    BuildContext context,
    List<Song> candidates,
    int needed,
  ) async {
    if (candidates.isEmpty) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('暂无可选歌曲'),
          content: const Text('开嗓标签下没有更多歌曲可选。'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('知道了')),
          ],
        ),
      );
      return [];
    }
    final selectedIds = <int>{};
    String keyword = '';
    final result = await showDialog<List<Song>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          final filtered = keyword.isEmpty
              ? candidates
              : candidates
                  .where((s) => s.title.contains(keyword) || s.artist.contains(keyword))
                  .toList();
          final selectedSongs = candidates.where((s) => selectedIds.contains(s.id)).toList();
          return AlertDialog(
            title: Text('补选开嗓歌曲 ($needed 首)'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: '搜索歌曲',
                  ),
                  onChanged: (value) => setState(() => keyword = value),
                ),
                const SizedBox(height: 12),
                if (selectedSongs.isNotEmpty)
                  Container(
                    width: double.maxFinite,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: selectedSongs
                          .map(
                            (song) => Chip(
                              label: Text(song.title),
                              onDeleted: () {
                                setState(() {
                                  selectedIds.remove(song.id);
                                });
                              },
                            ),
                          )
                          .toList(),
                    ),
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.maxFinite,
                  height: 280,
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final song = filtered[index];
                      final checked = selectedIds.contains(song.id);
                      return CheckboxListTile(
                        value: checked,
                        title: Text(song.title),
                        subtitle: Text(song.artist),
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: (value) {
                          setState(() {
                            if (checked) {
                              selectedIds.remove(song.id);
                            } else {
                              selectedIds.add(song.id);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('已选 ${selectedIds.length}/$needed'),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('取消')),
              FilledButton(
                onPressed: () {
                  if (selectedIds.length != needed) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(content: Text('需要补选 $needed 首，当前已选 ${selectedIds.length} 首')),
                    );
                    return;
                  }
                  Navigator.pop(
                    dialogContext,
                    candidates.where((s) => selectedIds.contains(s.id)).toList(),
                  );
                },
                child: const Text('确认'),
              ),
            ],
          );
        },
      ),
    );
    return result;
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
