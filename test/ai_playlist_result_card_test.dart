import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sing_list/ai_playlist/ai_playlist_models.dart';
import 'package:sing_list/ui/widgets/ai_playlist_result_card.dart';

void main() {
  testWidgets('fits long recommendation content in a narrow window',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final titleController = TextEditingController(text: '很长的 AI 推荐歌单名称');
    addTearDown(titleController.dispose);
    const song = AiPlaylistCatalogSong(
      id: 1,
      title: '这是一首名称非常非常长但仍然应该能够正常换行显示的歌曲',
      artist: '同样名称很长的歌手组合',
      tags: ['日语', '抒情', '开嗓', '现场'],
      playlists: [],
      hasLyrics: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AiPlaylistResultCard(
              titleController: titleController,
              recommendations: const [
                AiPlaylistRecommendation(
                  song: song,
                  reason: '推荐理由同样可能很长，需要在 Windows 小窗口和手机上正常换行。',
                ),
              ],
              selectedSongIds: const {1},
              externalRecommendations: const [
                AiExternalRecommendation(
                  title: '尚未收藏的新歌',
                  artist: '外部歌手',
                  reason: '仅供发现，未经联网核验',
                ),
              ],
              saving: false,
              onSelectionChanged: (_, __) {},
              onRemove: (_) {},
              onReorder: (_, __) {},
              onAddExternal: (_) {},
              onCreateNormal: () {},
              onCreateQueue: () {},
              onAddToNormal: () {},
              onAddToQueue: () {},
              onDiscard: () {},
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('我的曲库'), findsOneWidget);
    expect(find.text('发现新歌'), findsOneWidget);
  });
}
