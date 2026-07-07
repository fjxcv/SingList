import 'dart:io';

void main() {
  File('lib/ui/pages/simple_playlist_page.dart').writeAsStringSync(_content);
  print('simple_playlist_page.dart written');
}

const _content = r'''
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../repository/playlist_repository.dart';
import '../../repository/song_repository.dart';
import '../../service/normalize.dart';
import '../../state/providers.dart';
import '../widgets/ios_components.dart';
import 'song_detail_page.dart';

class SimplePlaylistPage extends ConsumerStatefulWidget {
  const SimplePlaylistPage({super.key, required this.playlist});

  final Playlist playlist;

  @override
  ConsumerState<SimplePlaylistPage> createState() => _SimplePlaylistPageState();
}

class _SimplePlaylistPageState extends ConsumerState<SimplePlaylistPage> {
  String keyword = '';
  final selectedSongIds = <int>{};
  bool batchMode = false;

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(playlistRepoProvider);
    final songRepo = ref.watch(songRepoProvider);

    return Scaffold(
      backgroundColor: AppColors.groupedBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  if (batchMode)
                    IosIconAction(
                      icon: Icons.close,
                      tooltip: '\u53d6\u6d88\u9009\u62e9',
                      onPressed: _exitBatchMode,
                    )
                  else
                    IosIconAction(
                      icon: Icons.playlist_add,
                      tooltip: '\u6dfb\u52a0\u6b4c\u66f2',
                      onPressed: () => _addSongDialog(context, repo, songRepo),
                    ),
                ],
              ),
            ),
            StreamBuilder<List<Song>>(
              stream: repo.songsInPlaylist(widget.playlist.id),
              builder: (context, snapshot) {
                final songs = snapshot.data ?? [];
                final titleText = batchMode
                    ? '\u5df2\u9009 ${selectedSongIds.length}'
                    : '${widget.playlist.name}${songs.isEmpty ? '' : ' (${songs.length})'}';

                return Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      IosLargeTitleHeader(title: titleText),
                      IosSearchField(
                        hintText: '\u6b4c\u540d/\u6b4c\u624b\u641c\u7d22',
                        onChanged: (v) => setState(() => keyword = v),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: _buildBody(context, repo, songs, snapshot),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: batchMode ? _buildBatchBar(context, repo) : null,
    );
  }

  Widget _buildBody(
    BuildContext context,
    PlaylistRepository repo,
    List<Song> songs,
    AsyncSnapshot<List<Song>> snapshot,
  ) {
    if (!snapshot.hasData) {
      return const Center(child: CircularProgressIndicator());
    }

    final filtered = songs.where((s) {
      return matchesSongKeyword(
        titleNorm: s.titleNorm,
        artistNorm: s.artistNorm,
        keyword: keyword,
      );
    }).toList();

    if (songs.isEmpty) {
      return const Center(child: Text('\u6b4c\u5355\u4e3a\u7a7a\uff0c\u70b9\u51fb\u53f3\u4e0a\u89d2\u6dfb\u52a0\u6b4c\u66f2'));
    }
    if (filtered.isEmpty) {
      return const Center(child: Text('\u6682\u65e0\u5339\u914d\u6b4c\u66f2'));
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        IosGroupedSection(
          children: filtered.map((song) {
            final checked = selectedSongIds.contains(song.id);
            return IosListRow(
              title: song.title,
              subtitle: song.artist,
              selected: checked,
              trailing: batchMode
                  ? Checkbox(value: checked, onChanged: (_) => _toggleSelection(song.id))
                  : null,
              onTap: () => batchMode
                  ? _toggleSelection(song.id)
                  : Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => SongDetailPage(song: song)),
                    ),
              onLongPress: () {
                if (batchMode) {
                  _toggleSelection(song.id);
                  return;
                }
                setState(() {
                  batchMode = true;
                  selectedSongIds.add(song.id);
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildBatchBar(BuildContext context, PlaylistRepository repo) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.separator, width: 0.5)),
        ),
        child: Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.tonal(
              onPressed: selectedSongIds.isEmpty ? null : () => _confirmBatchDelete(context, repo),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: const Text('\u5220\u9664'),
            ),
            Text('${selectedSongIds.length} \u5df2\u9009'),
            TextButton(onPressed: _exitBatchMode, child: const Text('\u53d6\u6d88')),
          ],
        ),
      ),
    );
  }

  Future<void> _addSongDialog(
    BuildContext context,
    PlaylistRepository repo,
    SongRepository songRepo,
  ) async {
    final allSongs = await songRepo.watchAll().first;
    final existing = await repo.songsInPlaylist(widget.playlist.id).first;
    final existingIds = existing.map((s) => s.id).toSet();
    final selectedIds = <int>{};
    String dialogKeyword = '';

    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          final candidates = allSongs.where((s) => !existingIds.contains(s.id)).toList();
          final filtered = dialogKeyword.isEmpty
              ? candidates
              : candidates
                  .where(
                    (s) => matchesSongKeyword(
                      titleNorm: s.titleNorm,
                      artistNorm: s.artistNorm,
                      keyword: dialogKeyword,
                    ),
                  )
                  .toList();
          final maxListHeight = MediaQuery.of(context).size.height * 0.45;
          return AlertDialog(
            title: const Text('\u6dfb\u52a0\u6b4c\u66f2'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: '\u6b4c\u540d/\u6b4c\u624b\u641c\u7d22',
                    ),
                    onChanged: (value) => setState(() => dialogKeyword = value),
                  ),
                  const SizedBox(height: 12),
                  if (selectedIds.isNotEmpty)
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
                        children: selectedIds
                            .map((id) => allSongs.firstWhere((song) => song.id == id))
                            .map(
                              (song) => Chip(
                                label: Text(song.title),
                                onDeleted: () => setState(() => selectedIds.remove(song.id)),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.maxFinite,
                    height: maxListHeight,
                    child: filtered.isEmpty
                        ? const Center(child: Text('\u6682\u65e0\u5339\u914d\u6b4c\u66f2'))
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final song = filtered[index];
                              final selected = selectedIds.contains(song.id);
                              return ListTile(
                                title: Text(song.title),
                                subtitle: Text(song.artist),
                                trailing: Icon(selected ? Icons.check_circle : Icons.add),
                                tileColor: selected
                                    ? Theme.of(context).colorScheme.surfaceVariant.withValues(alpha: 0.3)
                                    : null,
                                onTap: () {
                                  setState(() {
                                    if (selected) {
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
                ],
              ),
            ),
            actionsPadding: EdgeInsets.zero,
            actions: [
              IosDialogActions(
                cancelLabel: '\u53d6\u6d88',
                confirmLabel: '\u6dfb\u52a0',
                confirmEnabled: selectedIds.isNotEmpty,
                onCancel: () => Navigator.pop(dialogContext),
                onConfirm: () async {
                  await repo.addSongsToPlaylist(widget.playlist.id, selectedIds.toList());
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _toggleSelection(int songId) {
    setState(() {
      if (selectedSongIds.contains(songId)) {
        selectedSongIds.remove(songId);
      } else {
        selectedSongIds.add(songId);
      }
    });
  }

  void _exitBatchMode() {
    setState(() {
      batchMode = false;
      selectedSongIds.clear();
    });
  }

  Future<void> _confirmBatchDelete(BuildContext context, PlaylistRepository repo) async {
    final confirmed = await showIosConfirmDialog(
      context,
      title: '\u786e\u8ba4\u5220\u9664',
      message: '\u786e\u5b9a\u8981\u5220\u9664\u9009\u4e2d\u7684 ${selectedSongIds.length} \u9996\u6b4c\u66f2\u5417\uff1f',
    );
    if (confirmed != true) return;
    await repo.removeSongsFromPlaylist(widget.playlist.id, selectedSongIds.toList());
    if (mounted) _exitBatchMode();
  }
}
''';
