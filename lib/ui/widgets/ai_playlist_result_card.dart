import 'package:flutter/material.dart';

import '../../ai_playlist/ai_playlist_models.dart';

class AiPlaylistResultCard extends StatelessWidget {
  const AiPlaylistResultCard({
    super.key,
    required this.titleController,
    required this.recommendations,
    required this.selectedSongIds,
    required this.externalRecommendations,
    required this.saving,
    required this.onSelectionChanged,
    required this.onRemove,
    required this.onReorder,
    required this.onAddExternal,
    required this.onCreateNormal,
    required this.onCreateQueue,
    required this.onAddToNormal,
    required this.onAddToQueue,
    required this.onDiscard,
  });

  final TextEditingController titleController;
  final List<AiPlaylistRecommendation> recommendations;
  final Set<int> selectedSongIds;
  final List<AiExternalRecommendation> externalRecommendations;
  final bool saving;
  final void Function(int songId, bool selected) onSelectionChanged;
  final void Function(int songId) onRemove;
  final void Function(int oldIndex, int newIndex) onReorder;
  final void Function(AiExternalRecommendation item) onAddExternal;
  final VoidCallback onCreateNormal;
  final VoidCallback onCreateQueue;
  final VoidCallback onAddToNormal;
  final VoidCallback onAddToQueue;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final selectedCount = recommendations
        .where((item) => selectedSongIds.contains(item.song.id))
        .length;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.library_music_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '我的曲库',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ),
                Text('已选 $selectedCount/${recommendations.length}'),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: '歌单名称',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
            if (recommendations.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('本轮没有可用的本地歌曲推荐'),
              )
            else ...[
              const SizedBox(height: 10),
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: recommendations.length,
                onReorder: onReorder,
                itemBuilder: (context, index) {
                  final item = recommendations[index];
                  final selected = selectedSongIds.contains(item.song.id);
                  return _RecommendationTile(
                    key: ValueKey(item.song.id),
                    index: index,
                    item: item,
                    selected: selected,
                    onChanged: (value) =>
                        onSelectionChanged(item.song.id, value),
                    onRemove: () => onRemove(item.song.id),
                  );
                },
              ),
            ],
            if (externalRecommendations.isNotEmpty) ...[
              const Divider(height: 28),
              Row(
                children: [
                  Icon(
                    Icons.travel_explore,
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '发现新歌',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'AI 推荐，尚未加入曲库，也没有经过联网核验。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              for (final item in externalRecommendations)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text('${item.artist}\n${item.reason}'),
                  isThreeLine: true,
                  trailing: OutlinedButton(
                    onPressed: saving ? null : () => onAddExternal(item),
                    child: const Text('加入曲库'),
                  ),
                ),
            ],
            const Divider(height: 28),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  key: const Key('ai-playlist-create-normal'),
                  onPressed:
                      saving || selectedCount == 0 ? null : onCreateNormal,
                  icon: const Icon(Icons.playlist_add),
                  label: const Text('创建普通歌单'),
                ),
                FilledButton.tonalIcon(
                  key: const Key('ai-playlist-create-queue'),
                  onPressed:
                      saving || selectedCount == 0 ? null : onCreateQueue,
                  icon: const Icon(Icons.queue_music),
                  label: const Text('创建 KQueue'),
                ),
                OutlinedButton(
                  onPressed:
                      saving || selectedCount == 0 ? null : onAddToNormal,
                  child: const Text('加入已有歌单'),
                ),
                OutlinedButton(
                  onPressed: saving || selectedCount == 0 ? null : onAddToQueue,
                  child: const Text('加入已有 KQueue'),
                ),
                TextButton(
                  onPressed: saving ? null : onDiscard,
                  child: const Text('放弃本次结果'),
                ),
              ],
            ),
            if (saving) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }
}

class _RecommendationTile extends StatelessWidget {
  const _RecommendationTile({
    super.key,
    required this.index,
    required this.item,
    required this.selected,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final AiPlaylistRecommendation item;
  final bool selected;
  final ValueChanged<bool> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: selected,
              onChanged: (value) => onChanged(value ?? false),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.song.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      item.song.artist,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (item.song.tags.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          for (final tag in item.song.tags.take(4))
                            Chip(
                              visualDensity: VisualDensity.compact,
                              label: Text(tag),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 3),
                    Text(item.reason),
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: '从本次结果移除',
              onPressed: onRemove,
              icon: const Icon(Icons.close),
            ),
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                child: Icon(Icons.drag_handle),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
