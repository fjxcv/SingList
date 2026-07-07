import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../state/providers.dart';
import '../widgets/ios_components.dart';
import 'song_detail_page.dart';

class SongsByTagPage extends ConsumerWidget {
  const SongsByTagPage({super.key, required this.tag});

  final Tag tag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(tagRepoProvider);
    return Scaffold(
      backgroundColor: AppColors.groupedBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      tag.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<Song>>(
                stream: repo.songsByTag(tag.id),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final songs = snapshot.data!;
                  if (songs.isEmpty) {
                    return const Center(child: Text('暂无歌曲'));
                  }
                  return ListView(
                    padding: const EdgeInsets.only(bottom: 16),
                    children: [
                      IosGroupedSection(
                        children: songs
                            .map(
                              (song) => IosListRow(
                                title: song.title,
                                subtitle: song.artist,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => SongDetailPage(song: song)),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
