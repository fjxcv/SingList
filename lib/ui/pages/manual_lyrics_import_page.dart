import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../state/providers.dart';
import 'lyrics_edit_page.dart';
import 'lyrics_search_page.dart';

class ManualLyricsImportPage extends ConsumerWidget {
  const ManualLyricsImportPage({super.key, required this.song});

  final Song song;

  Future<void> _searchLrclib(BuildContext context) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => LyricsSearchPage(
          song: song,
          resultAction: LyricsSearchResultAction.editDirectly,
        ),
      ),
    );
    if (saved == true && context.mounted) Navigator.pop(context, true);
  }

  Future<void> _openEditor(BuildContext context, WidgetRef ref) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => LyricsEditPage(
          songId: song.id,
          songTitle: song.title,
          repository: ref.read(lyricsRepoProvider),
        ),
      ),
    );
    if (saved == true && context.mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('手动添加歌词')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Text(
            '${song.title} · ${song.artist}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          const Text('选择歌词来源。两种方式都会进入编辑页面，确认保存前不会修改现有歌词。'),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.search),
              title: const Text('从 LRCLIB 查找'),
              subtitle: const Text('选择一个歌词版本，然后进入编辑页面'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _searchLrclib(context),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('直接进入编辑'),
              subtitle: const Text('不查找歌词，在空白编辑页中粘贴或输入'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openEditor(context, ref),
            ),
          ),
        ],
      ),
    );
  }
}
