import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../repository/tag_repository.dart';
import '../../state/providers.dart';

class SongsByTagPage extends ConsumerWidget {
  final Tag tag;
  const SongsByTagPage({super.key, required this.tag});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(tagRepoProvider);
    return Scaffold(
      appBar: AppBar(title: Text('#${tag.name}')),
      body: StreamBuilder(
        stream: repo.songsByTag(tag.id),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final songs = snapshot.data!;
          if (songs.isEmpty) {
            return const Center(child: Text('暂无歌曲'));
          }
          return ListView.builder(
            itemCount: songs.length,
            itemBuilder: (context, index) {
              final song = songs[index];
              return ListTile(
                title: Text(song.title),
                subtitle: Text(song.artist),
              );
            },
          );
        },
      ),
    );
  }
}
