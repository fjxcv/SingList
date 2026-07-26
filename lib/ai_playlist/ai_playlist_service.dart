import '../ai/ai_exception.dart';
import '../ai/ai_provider_config.dart';
import '../ai/openai_compatible_client.dart';
import 'ai_playlist_models.dart';
import 'ai_playlist_prompt.dart';
import 'ai_playlist_result_parser.dart';
import 'song_catalog_service.dart';

class AiPlaylistService {
  const AiPlaylistService({
    required this.client,
    required this.catalogService,
    this.resultParser = const AiPlaylistResultParser(),
  });

  final OpenAiCompatibleClient client;
  final SongCatalogService catalogService;
  final AiPlaylistResultParser resultParser;

  Future<AiPlaylistServiceResult> send({
    required AiProviderConfig config,
    required String apiKey,
    required String userMessage,
    required List<AiPlaylistHistoryMessage> history,
    required bool allowExternal,
    AiCancellationToken? cancellationToken,
  }) async {
    final input = userMessage.trim();
    if (input.isEmpty) {
      throw const AiException(
        AiErrorKind.invalidConfiguration,
        '请输入你的选歌需求',
      );
    }
    if (!config.enabled) {
      throw const AiException(
        AiErrorKind.invalidConfiguration,
        '请先启用 AI 服务',
      );
    }
    if (apiKey.trim().isEmpty) {
      throw const AiException(
        AiErrorKind.invalidConfiguration,
        '请先配置 API Key',
      );
    }
    if (config.model.trim().isEmpty) {
      throw const AiException(
        AiErrorKind.invalidConfiguration,
        '请先填写模型名',
      );
    }
    OpenAiCompatibleClient.chatCompletionsUri(config.baseUrl);

    late final SongCatalogContext catalog;
    try {
      catalog = await catalogService.buildContext(userQuery: input);
    } on SongCatalogTooLargeException catch (error) {
      throw AiException(AiErrorKind.invalidConfiguration, error.message);
    }
    if (catalog.songs.isEmpty) {
      throw const AiException(
        AiErrorKind.invalidConfiguration,
        '曲库为空，请先添加歌曲',
      );
    }

    final response = await client.complete(
      config: config,
      apiKey: apiKey,
      messages: AiPlaylistPrompt.buildMessages(
        catalog: catalog,
        history: history,
        userMessage: input,
        allowExternal: allowExternal,
      ),
      temperature: 0.25,
      maxTokens: 4096,
      cancellationToken: cancellationToken,
    );
    final result = resultParser.parse(
      response.content,
      candidateSongs: catalog.songsById,
      allowExternal: allowExternal,
    );
    return AiPlaylistServiceResult(
      result: result,
      catalog: catalog,
      actualModel: response.model,
    );
  }
}
