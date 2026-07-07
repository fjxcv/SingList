import 'dart:io';

void main() {
  File('lib/ui/pages/generator_page.dart').writeAsStringSync(_content);
  print('generator_page.dart written');
}

const _content = r'''
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../state/brush_generator_state.dart';
import '../../state/providers.dart';
import 'queue_page.dart';
import 'random_queue_page.dart';
import '../widgets/bottom_fab_action.dart';
import '../widgets/ios_components.dart';

class GeneratorPage extends StatelessWidget {
  const GeneratorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('\u751f\u6210 KQueue'),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(44),
            child: TabBar(
              tabs: [
                Tab(text: '\u5237\u6b4c\u6a21\u5f0f'),
                Tab(text: '\u968f\u673a\u751f\u6210'),
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
      return _BrushBody(
          state: state,
          onFavorite: notifier.markFavorite,
          onLike: notifier.markLike,
          onSkip: notifier.skip,
          onGoPrevious: notifier.goPrevious,
          onFinish: () => _handleFinish(context, notifier),
          onBack: () => _handleBack(context, notifier),
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
                      label: const Text('\u5168\u90e8\u6b4c\u66f2'),
                      selected: state.sourceType == BrushSourceType.all,
                      onSelected: (_) => notifier.updateSourceType(BrushSourceType.all),
                    ),
                    ChoiceChip(
                      label: const Text('\u6309\u6807\u7b7e'),
                      selected: state.sourceType == BrushSourceType.tag,
                      onSelected: (_) => notifier.updateSourceType(BrushSourceType.tag),
                    ),
                    ChoiceChip(
                      label: const Text('\u666e\u901a\u6b4c\u5355'),
                      selected: state.sourceType == BrushSourceType.playlist,
                      onSelected: (_) => notifier.updateSourceType(BrushSourceType.playlist),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (state.sourceType == BrushSourceType.tag)
                  DropdownButtonFormField<int>(
                    value: state.selectedTagId,
                    decoration: const InputDecoration(labelText: '\u9009\u62e9\u6807\u7b7e'),
                    items: tags
                        .map((t) => DropdownMenuItem(value: t.id, child: Text(t.name)))
                        .toList(),
                    onChanged: (v) => notifier.updateTag(v),
                  ),
                if (state.sourceType == BrushSourceType.playlist)
                  DropdownButtonFormField<int>(
                    value: state.selectedPlaylistId,
                    decoration: const InputDecoration(labelText: '\u9009\u62e9\u666e\u901a\u6b4c\u5355'),
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
                    const Text('\u5f00\u55d4\u6696\u573a\u66f2'),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 56,
                      child: TextFormField(
                        key: ValueKey('warmup-${state.warmupCount}'),
                        initialValue: state.warmupCount.toString(),
                        decoration: const InputDecoration(
                          labelText: '\u6570\u91cf',
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
                const Center(child: Text('\u9009\u62e9\u6765\u6e90\u540e\u5f00\u59cb\u5237\u6b4c')),
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
                label: '\u5f00\u59cb\u5237\u6b4c',
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
            title: const Text('\u5f00\u55d4\u66f2\u6570\u91cf\u4e0d\u8db3'),
            content: Text('\u9700\u8981 ${state.warmupCount} \u9996\uff0c\u5f53\u524d\u53ea\u6709 $count \u9996\u6b4c'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('\u77e5\u9053\u4e86')),
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
        title: const Text('\u7ed3\u675f\u5237\u6b4c\u4f1a\u8bdd'),
        content: const Text('\u662f\u5426\u4fdd\u5b58\u672c\u6b21\u5237\u7684\u6b4c\u66f2\u5e76\u751f\u6210 KQueue \u6b4c\u5355\uff1f'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _BrushBackAction.cancel),
            child: const Text('\u53d6\u6d88'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _BrushBackAction.discard),
            child: const Text('\u4e0d\u4fdd\u5b58'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, _BrushBackAction.save),
            child: const Text('\u4fdd\u5b58\u5e76\u751f\u6210'),
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
          const SnackBar(content: Text('\u6682\u65e0\u53ef\u4fdd\u5b58\u7684\u6b4c\u66f2')),
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
        ? '\u5c1a\u672a\u9009\u62e9'
        : selected.map((s) => s.title).join('\u3001');
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('\u5f00\u55d4\u66f2\u6570\u91cf\u4e0d\u8db3'),
        content: Text('\u5df2\u9009 $selectedNames\n\u8fd8\u5dee $missing \u9996\uff0c\u662f\u5426\u4ece\u5f00\u55d4\u6807\u7b7e\u4e2d\u8865\u9009\uff1f'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('\u53d6\u6d88')),
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('\u5426')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('\u662f')),
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
          title: const Text('\u6682\u65e0\u53ef\u8865\u9009\u6b4c\u66f2'),
          content: const Text('\u5f00\u55d4\u6807\u7b7e\u91cc\u6ca1\u6709\u66f4\u591a\u6b4c\u66f2\u53ef\u8865\u9009'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('\u77e5\u9053\u4e86')),
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
            title: Text('\u8865\u9009\u5f00\u55d4\u66f2\u76ee ($needed \u9996)'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: '\u641c\u7d22\u6b4c\u540d',
                  ),
                  onChanged: (value) => setState(() => keyword = value),
                ),
                const SizedBox(height: 12),
                if (selectedSongs.isNotEmpty)
                  Container(
                    width: double.maxFinite,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant.withValues(alpha: 0.4),
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
                  child: Text('\u5df2\u9009 ${selectedIds.length}/$needed'),
                ),
              ],
            ),
            actionsPadding: EdgeInsets.zero,
            actions: [
              IosDialogActions(
                cancelLabel: '\u53d6\u6d88',
                confirmLabel: '\u786e\u5b9a',
                onCancel: () => Navigator.pop(dialogContext),
                onConfirm: () {
                  if (selectedIds.length != needed) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(content: Text('\u9700\u8981\u8865\u9009 $needed \u9996\uff0c\u5f53\u524d\u5df2\u9009 ${selectedIds.length} \u9996')),
                    );
                    return;
                  }
                  Navigator.pop(
                    dialogContext,
                    candidates.where((s) => selectedIds.contains(s.id)).toList(),
                  );
                },
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
    required this.onGoPrevious,
    required this.onFinish,
    required this.onBack,
  });

  final BrushGeneratorState state;
  final VoidCallback onFavorite;
  final VoidCallback onLike;
  final VoidCallback onSkip;
  final VoidCallback onGoPrevious;
  final VoidCallback onFinish;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.currentSong != null) {
      return _SongCard(
        state: state,
        song: state.currentSong!,
        onFavorite: onFavorite,
        onLike: onLike,
        onSkip: onSkip,
        onGoPrevious: onGoPrevious,
        onBack: onBack,
      );
    }
    if (state.completed) {
      return _FinishCard(
        state: state,
        onFinish: onFinish,
        onBack: onBack,
      );
    }
    return const Center(
      child: Text('\u9009\u62e9\u6765\u6e90\u540e\u5f00\u59cb\u5237\u6b4c', style: TextStyle(color: AppColors.secondaryLabel)),
    );
  }
}

class _SongCard extends StatelessWidget {
  const _SongCard({
    required this.state,
    required this.song,
    required this.onFavorite,
    required this.onLike,
    required this.onSkip,
    required this.onGoPrevious,
    required this.onBack,
  });

  final BrushGeneratorState state;
  final Song song;
  final VoidCallback onFavorite;
  final VoidCallback onLike;
  final VoidCallback onSkip;
  final VoidCallback onGoPrevious;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final progressText =
        '${state.phaseLabel} ${state.currentIndex + 1}/${state.songs.length}';
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.secondaryLabel),
                tooltip: '\u9000\u51fa\u5237\u6b4c',
                onPressed: onBack,
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      progressText,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: state.progressValue,
                        minHeight: 4,
                        backgroundColor: AppColors.separator.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.undo_rounded,
                  color: state.canGoPrevious
                      ? AppColors.systemBlue
                      : AppColors.secondaryLabel.withValues(alpha: 0.4),
                ),
                tooltip: '\u64a4\u9500',
                onPressed: state.canGoPrevious ? onGoPrevious : null,
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: IosSongCard(title: song.title, artist: song.artist),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(36, 28, 36, 28),
          child: Column(
            children: [
              IosPrimaryButton(
                label: '\u7279\u522b\u60f3\u5531',
                icon: Icons.star_rounded,
                onPressed: onFavorite,
              ),
              const SizedBox(height: 12),
              IosSecondaryButton(
                label: '\u60f3\u5531',
                icon: Icons.check_rounded,
                onPressed: onLike,
              ),
              const SizedBox(height: 12),
              IosGrayButton(
                label: '\u4e0d\u60f3\u5531',
                icon: Icons.close_rounded,
                onPressed: onSkip,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FinishCard extends StatelessWidget {
  const _FinishCard({
    required this.state,
    required this.onFinish,
    required this.onBack,
  });

  final BrushGeneratorState state;
  final VoidCallback onFinish;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: const Icon(Icons.close, color: AppColors.secondaryLabel),
              tooltip: '\u9000\u51fa\u5237\u6b4c',
              onPressed: onBack,
            ),
          ),
          const Text(
            '\u5237\u6b4c\u5b8c\u6210',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          if (state.warmupEnabled && state.warmupCount > 0) ...[
            Text(
              '\u5f00\u55d4\uff1a\u7279\u522b\u60f3\u5531 ${state.warmupFavorites.length} | \u60f3\u5531 ${state.warmupLikes.length}',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
          ],
          Text(
            '\u4e3b\u4f53\uff1a\u7279\u522b\u60f3\u5531 ${state.favorites.length} | \u60f3\u5531 ${state.likes.length}',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          IosPrimaryButton(
            label: '\u751f\u6210 KQueue \u5e76\u67e5\u770b',
            onPressed: onFinish,
          ),
        ],
      ),
    );
  }
}
''';
