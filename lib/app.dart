import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'state/providers.dart';
import 'theme.dart';
import 'ui/pages/generator_page.dart';
import 'ui/pages/playlists_page.dart';
import 'ui/pages/songs_page.dart';
import 'ui/pages/tags_page.dart';

class SingListApp extends ConsumerStatefulWidget {
  const SingListApp({super.key});

  @override
  ConsumerState<SingListApp> createState() => _SingListAppState();
}

class _SingListAppState extends ConsumerState<SingListApp> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'K歌选歌',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(ref),
      home: Scaffold(
        body: IndexedStack(
          index: _index,
          children: const [
            SongsPage(),
            TagsPage(),
            PlaylistsPage(),
            GeneratorPage(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.library_music), label: '歌曲'),
            NavigationDestination(icon: Icon(Icons.sell), label: '标签'),
            NavigationDestination(icon: Icon(Icons.queue_music), label: '歌单'),
            NavigationDestination(icon: Icon(Icons.auto_awesome), label: '生成'),
          ],
          onDestinationSelected: (i) => setState(() => _index = i),
        ),
      ),
    );
  }
}
