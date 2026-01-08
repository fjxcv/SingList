import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/brush_generator_state.dart';
import '../../state/providers.dart';
import '../../state/random_queue_state.dart';
import 'queue_page.dart';
import '../widgets/bottom_fab_action.dart';

class RandomQueuePage extends ConsumerWidget {
  const RandomQueuePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(randomQueueProvider);
    final notifier = ref.read(randomQueueProvider.notifier);
    final tags = ref.watch(tagsProvider).valueOrNull ?? [];
    final playlists = ref.watch(normalPlaylistsProvider).valueOrNull ?? [];

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
                    onChanged: notifier.updateTag,
                  ),
                if (state.sourceType == BrushSourceType.playlist)
                  DropdownButtonFormField<int>(
                    value: state.selectedPlaylistId,
                    decoration: const InputDecoration(labelText: '选择普通歌单'),
                    items: playlists
                        .map((p) => DropdownMenuItem(value: p.id, child: Text(p.name)))
                        .toList(),
                    onChanged: notifier.updatePlaylist,
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    SizedBox(
                      width: 64,
                      child: TextFormField(
                        key: ValueKey('count-${state.count}'),
                        initialValue: state.count.toString(),
                        decoration: const InputDecoration(
                          labelText: '数量',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (v) => notifier.updateCount(int.parse(v.trim())),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('歌曲不重复出现'),
                        value: state.avoidRepeat,
                        onChanged: notifier.updateAvoidRepeat,
                      ),
                    ),
                  ],
                ),
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
                        key: ValueKey('warmup-${state.warmupCount}-${state.warmupEnabled}'),
                        initialValue: state.warmupCount.toString(),
                        decoration: const InputDecoration(
                          labelText: '数量',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (v) => notifier.updateWarmupCount(
                          int.parse(v.trim()),
                        ),
                      ),
                    ),
                  ],
                ),
                if (state.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(state.error!, style: const TextStyle(color: Colors.red)),
                  ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 12,
            child: Center(
              child: BottomFabAction(
                onPressed: state.isLoading
                    ? null
                    : () async {
                        final candidates = await notifier.loadCandidates();
                        if (candidates.isEmpty) {
                          final playlist = await notifier.generateQueue();
                          if (playlist == null || !context.mounted) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => QueuePage(playlist: playlist),
                            ),
                          );
                          return;
                        }
                        var overrideAvoidRepeat = false;
                        if (state.avoidRepeat && state.count > candidates.length) {
                          final proceed = await _showConfirmDialog(
                            context,
                            title: '提示',
                            message: '当前可选歌曲数量不足，无法满足不重复生成，是否继续生成？',
                          );
                          if (!proceed) return;
                          overrideAvoidRepeat = true;
                        }
                        if ((!state.avoidRepeat || overrideAvoidRepeat) &&
                            candidates.length <= 1 &&
                            state.count > 1) {
                          final proceed = await _showConfirmDialog(
                            context,
                            title: '提示',
                            message: '当前可选歌曲数量较少，随机生成时可能会出现大量重复，建议适当减少生成数量。',
                          );
                          if (!proceed) return;
                        }
                        final playlist = await notifier.generateQueue(
                          avoidRepeatOverride: overrideAvoidRepeat ? false : null,
                        );
                        if (playlist == null || !context.mounted) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => QueuePage(playlist: playlist),
                          ),
                        );
                      },
                icon: Icons.casino,
                label: state.isLoading ? '生成中...' : '随机生成 KQueue',
                isLoading: state.isLoading,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _showConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('继续')),
        ],
      ),
    );
    return confirmed ?? false;
  }
}
