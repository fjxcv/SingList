import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/ai_exception.dart';
import '../../ai/openai_compatible_client.dart';
import '../../ai_playlist/ai_playlist_models.dart';
import '../../ai_playlist/ai_playlist_save_service.dart';
import '../../data/db/app_database.dart';
import '../../repository/playlist_repository.dart';
import '../../repository/song_repository.dart';
import '../../state/providers.dart';
import '../widgets/ai_playlist_result_card.dart';
import 'ai_settings_page.dart';
import 'queue_page.dart';
import 'simple_playlist_page.dart';

class AiPlaylistChatPage extends ConsumerStatefulWidget {
  const AiPlaylistChatPage({super.key});

  @override
  ConsumerState<AiPlaylistChatPage> createState() => _AiPlaylistChatPageState();
}

class _AiPlaylistChatPageState extends ConsumerState<AiPlaylistChatPage> {
  static const _quickPrompts = [
    '今天适合唱什么？',
    '按我的心情选歌',
    '帮我挑几首开嗓曲',
    '想唱轻松一点的歌',
    '想唱情绪强烈的歌',
    '从我的曲库生成 KQueue',
    '根据某首歌找相似歌曲',
    '推荐一些没收藏的新歌',
  ];

  final _inputController = TextEditingController();
  final _playlistTitleController = TextEditingController(text: 'AI 推荐歌单');
  final _scrollController = ScrollController();
  final _history = <AiPlaylistHistoryMessage>[];
  final _messages = <_ConversationMessage>[];
  final _recommendations = <AiPlaylistRecommendation>[];
  final _externalRecommendations = <AiExternalRecommendation>[];
  final _selectedSongIds = <int>{};

  AiCancellationToken? _cancellationToken;
  bool _checkingReady = true;
  bool _ready = false;
  bool _sending = false;
  bool _saving = false;
  bool _allowExternal = false;
  String? _readinessError;
  String? _requestError;
  String? _catalogNotice;
  String? _filterNotice;

  @override
  void initState() {
    super.initState();
    _checkReadiness();
  }

  @override
  void dispose() {
    _cancellationToken?.cancel();
    _inputController.dispose();
    _playlistTitleController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<bool> _checkReadiness() async {
    final configRepository = ref.read(aiConfigRepositoryProvider);
    final catalogService = ref.read(songCatalogServiceProvider);
    if (mounted) {
      setState(() {
        _checkingReady = true;
        _readinessError = null;
      });
    }
    String? error;
    try {
      final config = await configRepository.loadConfig();
      final apiKey = await configRepository.readApiKey() ?? '';
      if (!config.enabled) {
        error = 'AI 服务尚未启用';
      } else if (apiKey.trim().isEmpty) {
        error = '尚未配置 API Key';
      } else if (config.model.trim().isEmpty) {
        error = '尚未填写模型名';
      } else {
        OpenAiCompatibleClient.chatCompletionsUri(config.baseUrl);
        final count = await catalogService.countSongs();
        if (count == 0) error = '曲库为空，请先添加歌曲';
      }
    } on AiException catch (exception) {
      error = exception.message;
    } catch (_) {
      error = '无法检查 AI 服务或曲库状态';
    }
    if (!mounted) return false;
    setState(() {
      _checkingReady = false;
      _ready = error == null;
      _readinessError = error;
    });
    return error == null;
  }

  Future<void> _openSettings() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const AiSettingsPage()),
    );
    if (mounted) await _checkReadiness();
  }

  Future<void> _send([String? quickPrompt]) async {
    if (_sending || _saving) return;
    if (quickPrompt != null) _inputController.text = quickPrompt;
    final input = _inputController.text.trim();
    if (input.isEmpty) return;
    if (!_ready && !await _checkReadiness()) return;

    final token = AiCancellationToken();
    final configRepository = ref.read(aiConfigRepositoryProvider);
    final playlistService = ref.read(aiPlaylistServiceProvider);
    _cancellationToken = token;
    setState(() {
      _sending = true;
      _requestError = null;
      _filterNotice = null;
    });
    try {
      final config = await configRepository.loadConfig();
      final apiKey = await configRepository.readApiKey() ?? '';
      final serviceResult = await playlistService.send(
        config: config,
        apiKey: apiKey,
        userMessage: input,
        history: List.unmodifiable(_history),
        allowExternal: _allowExternal,
        cancellationToken: token,
      );
      if (!mounted || token.isCancelled) return;
      final result = serviceResult.result;
      _history
        ..add(AiPlaylistHistoryMessage(role: 'user', content: input))
        ..add(
          AiPlaylistHistoryMessage(
            role: 'assistant',
            content: result.toHistoryContent(),
          ),
        );
      _messages
        ..add(_ConversationMessage(text: input, isUser: true))
        ..add(_ConversationMessage(text: result.reply, isUser: false));
      _inputController.clear();

      final hasNewResult = result.recommendations.isNotEmpty ||
          result.externalRecommendations.isNotEmpty;
      if (hasNewResult) {
        _recommendations
          ..clear()
          ..addAll(result.recommendations);
        _externalRecommendations
          ..clear()
          ..addAll(result.externalRecommendations);
        _selectedSongIds
          ..clear()
          ..addAll(result.recommendations.map((item) => item.song.id));
        final suggestedTitle = result.playlistTitle?.trim();
        if (suggestedTitle != null && suggestedTitle.isNotEmpty) {
          _playlistTitleController.text = suggestedTitle;
        }
      } else if (!result.needsClarification) {
        _requestError = 'AI 本轮没有返回可用推荐，已保留上一次有效结果';
      }

      _catalogNotice = serviceResult.catalog.isComplete
          ? null
          : serviceResult.catalog.scopeNotice;
      final filteredCount =
          result.filteredRecommendationCount + result.filteredExternalCount;
      if (filteredCount > 0) {
        _filterNotice = '已过滤 $filteredCount 条无效、重复或不允许的推荐';
      }
      setState(() {});
      _scrollToBottom();
    } on AiException catch (error) {
      if (!mounted) return;
      setState(() {
        _requestError = error.kind == AiErrorKind.cancelled
            ? '已取消本次请求，上一次有效结果仍然保留'
            : error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _requestError = 'AI 选歌失败，请重试；上一次有效结果仍然保留';
      });
    } finally {
      if (mounted && identical(_cancellationToken, token)) {
        setState(() => _sending = false);
      }
    }
  }

  void _cancelRequest() {
    _cancellationToken?.cancel();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  List<int> get _selectedIdsInOrder => [
        for (final item in _recommendations)
          if (_selectedSongIds.contains(item.song.id)) item.song.id,
      ];

  void _toggleSong(int songId, bool selected) {
    setState(() {
      if (selected) {
        _selectedSongIds.add(songId);
      } else {
        _selectedSongIds.remove(songId);
      }
    });
  }

  void _removeSong(int songId) {
    setState(() {
      _recommendations.removeWhere((item) => item.song.id == songId);
      _selectedSongIds.remove(songId);
    });
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      var target = newIndex;
      if (target > oldIndex) target--;
      final item = _recommendations.removeAt(oldIndex);
      _recommendations.insert(target, item);
    });
  }

  Future<void> _addExternal(AiExternalRecommendation item) async {
    if (_saving) return;
    final titleController = TextEditingController(text: item.title);
    final artistController = TextEditingController(text: item.artist);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('确认加入曲库'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('这首歌由 AI 推荐且尚未联网核验，请确认歌名和歌手。'),
            const SizedBox(height: 12),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: '歌名'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: artistController,
              decoration: const InputDecoration(labelText: '歌手'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (titleController.text.trim().isEmpty ||
                  artistController.text.trim().isEmpty) {
                return;
              }
              Navigator.pop(dialogContext, true);
            },
            child: const Text('确认加入'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      titleController.dispose();
      artistController.dispose();
      return;
    }
    final title = titleController.text.trim();
    final artist = artistController.text.trim();
    titleController.dispose();
    artistController.dispose();

    setState(() => _saving = true);
    try {
      final songRepository = ref.read(songRepoProvider);
      final songId = await songRepository.upsertByTitleArtist(title, artist);
      final song = await songRepository.findById(songId);
      if (song == null) throw StateError('歌曲写入后无法读取');
      if (!mounted) return;
      setState(() {
        if (_recommendations.every(
          (recommendation) => recommendation.song.id != songId,
        )) {
          _recommendations.add(
            AiPlaylistRecommendation(
              song: AiPlaylistCatalogSong(
                id: song.id,
                title: song.title,
                artist: song.artist,
                tags: const [],
                playlists: const [],
                hasLyrics: false,
              ),
              reason: item.reason,
            ),
          );
          _selectedSongIds.add(songId);
        }
        _externalRecommendations.remove(item);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('歌曲已加入曲库和当前推荐结果')),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('歌曲加入曲库失败，请重试')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _createNormal() async {
    final name = _playlistTitleController.text.trim();
    if (name.isEmpty) {
      _showMessage('请填写歌单名称');
      return;
    }
    final ids = _selectedIdsInOrder;
    if (!await _confirmSave(
      '将创建普通歌单“$name”，共 ${ids.length} 首歌曲。',
    )) {
      return;
    }
    await _performSave(
      () => ref.read(aiPlaylistSaveServiceProvider).createNormal(
            name: name,
            orderedSongIds: ids,
          ),
      PlaylistType.normal,
    );
  }

  Future<void> _createQueue() async {
    final name = _playlistTitleController.text.trim();
    if (name.isEmpty) {
      _showMessage('请填写 KQueue 名称');
      return;
    }
    final ids = _selectedIdsInOrder;
    if (!await _confirmSave(
      '将创建 KQueue“$name”，共 ${ids.length} 首歌曲，'
      '歌曲顺序将按当前列表保存。',
    )) {
      return;
    }
    await _performSave(
      () => ref.read(aiPlaylistSaveServiceProvider).createQueue(
            name: name,
            orderedSongIds: ids,
          ),
      PlaylistType.kQueue,
    );
  }

  Future<void> _addToExisting(PlaylistType type) async {
    final playlists = await ref.read(playlistRepoProvider).fetchByType(type);
    if (!mounted) return;
    if (playlists.isEmpty) {
      _showMessage(
        type == PlaylistType.normal ? '还没有普通歌单' : '还没有 KQueue',
      );
      return;
    }
    final target = await showDialog<Playlist>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(
          type == PlaylistType.normal ? '选择普通歌单' : '选择 KQueue',
        ),
        children: [
          for (final playlist in playlists)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, playlist),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(playlist.name),
              ),
            ),
        ],
      ),
    );
    if (target == null || !mounted) return;
    final ids = _selectedIdsInOrder;
    final description = type == PlaylistType.normal
        ? '将把 ${ids.length} 首歌曲加入“${target.name}”，已有歌曲不会重复添加。'
        : '将把 ${ids.length} 首歌曲按当前顺序追加到“${target.name}”。';
    if (!await _confirmSave(description)) return;
    await _performSave(
      () => ref.read(aiPlaylistSaveServiceProvider).addToExisting(
            playlistId: target.id,
            type: type,
            orderedSongIds: ids,
          ),
      type,
    );
  }

  Future<bool> _confirmSave(String message) async {
    if (_selectedIdsInOrder.isEmpty) {
      _showMessage('请至少选择一首仍在曲库中的歌曲');
      return false;
    }
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('确认保存'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('确认'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _performSave(
    Future<AiPlaylistSaveResult> Function() operation,
    PlaylistType type,
  ) async {
    if (_saving) return;
    final playlistRepository = ref.read(playlistRepoProvider);
    setState(() => _saving = true);
    try {
      final result = await operation();
      final playlist = await playlistRepository.findById(result.playlistId);
      if (playlist == null) throw StateError('保存后无法读取歌单');
      if (!mounted) return;
      final missing = result.filteredMissingCount == 0
          ? ''
          : '，另有 ${result.filteredMissingCount} 首已从曲库删除并被过滤';
      final open = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('保存成功'),
          content: Text('已保存 ${result.savedSongIds.length} 首歌曲$missing。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('留在当前页'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('打开歌单'),
            ),
          ],
        ),
      );
      if (open == true && mounted) {
        await Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) => type == PlaylistType.kQueue
                ? QueuePage(playlist: playlist)
                : SimplePlaylistPage(playlist: playlist),
          ),
        );
      }
    } on AiPlaylistSaveException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) _showMessage('歌单保存失败，数据库没有写入不完整结果');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 帮我选歌'),
        actions: [
          IconButton(
            tooltip: 'AI 设置',
            onPressed: _openSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
              children: [
                Card(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      '发送消息时，当前输入和必要的曲库摘要会提交给你配置的 '
                      'AI 服务商，可能产生 API 调用费用。不会发送完整歌词。',
                    ),
                  ),
                ),
                if (_checkingReady)
                  const Padding(
                    padding: EdgeInsets.all(18),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_readinessError != null)
                  Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: Text(_readinessError!),
                      subtitle: _readinessError!.contains('AI') ||
                              _readinessError!.contains('API') ||
                              _readinessError!.contains('模型')
                          ? const Text('设置完成返回后，已输入的选歌需求会保留。')
                          : null,
                      trailing: _readinessError!.contains('曲库')
                          ? null
                          : TextButton(
                              onPressed: _openSettings,
                              child: const Text('前往设置'),
                            ),
                    ),
                  ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('发现新歌'),
                  subtitle: const Text('默认关闭；开启后外部推荐仍需人工确认才能加入曲库'),
                  value: _allowExternal,
                  onChanged: _sending
                      ? null
                      : (value) => setState(() => _allowExternal = value),
                ),
                if (_messages.isEmpty) ...[
                  const SizedBox(height: 4),
                  const Text(
                    '你可以这样问',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      for (final prompt in _quickPrompts)
                        ActionChip(
                          label: Text(prompt),
                          onPressed: _sending ? null : () => _send(prompt),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                for (final message in _messages)
                  _MessageBubble(message: message),
                if (_catalogNotice != null)
                  _NoticeCard(
                    icon: Icons.filter_alt_outlined,
                    text: _catalogNotice!,
                  ),
                if (_filterNotice != null)
                  _NoticeCard(
                    icon: Icons.rule,
                    text: _filterNotice!,
                  ),
                if (_requestError != null)
                  Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(_requestError!),
                    ),
                  ),
                if (_recommendations.isNotEmpty ||
                    _externalRecommendations.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  AiPlaylistResultCard(
                    titleController: _playlistTitleController,
                    recommendations: _recommendations,
                    selectedSongIds: _selectedSongIds,
                    externalRecommendations: _externalRecommendations,
                    saving: _saving,
                    onSelectionChanged: _toggleSong,
                    onRemove: _removeSong,
                    onReorder: _reorder,
                    onAddExternal: _addExternal,
                    onCreateNormal: _createNormal,
                    onCreateQueue: _createQueue,
                    onAddToNormal: () => _addToExisting(PlaylistType.normal),
                    onAddToQueue: () => _addToExisting(PlaylistType.kQueue),
                    onDiscard: () => setState(() {
                      _recommendations.clear();
                      _externalRecommendations.clear();
                      _selectedSongIds.clear();
                    }),
                  ),
                ],
              ],
            ),
          ),
          Material(
            elevation: 8,
            color: Theme.of(context).colorScheme.surface,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 9, 8, 9),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('ai-playlist-input'),
                        controller: _inputController,
                        enabled: !_saving,
                        minLines: 1,
                        maxLines: 5,
                        textInputAction: TextInputAction.newline,
                        decoration: const InputDecoration(
                          hintText: '描述心情、场景、语言或歌曲数量…',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    if (_sending)
                      IconButton.filledTonal(
                        key: const Key('ai-playlist-cancel'),
                        tooltip: '取消请求',
                        onPressed: _cancelRequest,
                        icon: const Icon(Icons.stop),
                      )
                    else
                      IconButton.filled(
                        key: const Key('ai-playlist-send'),
                        tooltip: '发送',
                        onPressed:
                            _checkingReady || _saving ? null : () => _send(),
                        icon: const Icon(Icons.send),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationMessage {
  const _ConversationMessage({
    required this.text,
    required this.isUser,
  });

  final String text;
  final bool isUser;
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final _ConversationMessage message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 620),
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: message.isUser
              ? scheme.primaryContainer
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: SelectableText(message.text),
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(text),
        dense: true,
      ),
    );
  }
}
