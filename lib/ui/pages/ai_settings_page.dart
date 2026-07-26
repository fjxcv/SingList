import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/ai_exception.dart';
import '../../ai/ai_provider_config.dart';
import '../../state/providers.dart';

class AiSettingsPage extends ConsumerStatefulWidget {
  const AiSettingsPage({super.key});

  @override
  ConsumerState<AiSettingsPage> createState() => _AiSettingsPageState();
}

class _AiSettingsPageState extends ConsumerState<AiSettingsPage> {
  final _baseUrlController = TextEditingController();
  final _modelController = TextEditingController();
  final _apiKeyController = TextEditingController();
  AiProvider _provider = AiProvider.deepSeek;
  double _timeout = 60;
  bool _enabled = false;
  bool _obscureKey = true;
  bool _loading = true;
  bool _testing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repository = ref.read(aiConfigRepositoryProvider);
    final config = await repository.loadConfig();
    final apiKey = await repository.readApiKey();
    if (!mounted) return;
    setState(() {
      _provider = config.provider;
      _baseUrlController.text = config.baseUrl;
      _modelController.text = config.model;
      _apiKeyController.text = apiKey ?? '';
      _timeout = config.timeoutSeconds.toDouble();
      _enabled = config.enabled;
      _loading = false;
    });
  }

  AiProviderConfig _currentConfig() {
    return AiProviderConfig(
      provider: _provider,
      baseUrl: _baseUrlController.text.trim(),
      model: _modelController.text.trim(),
      timeoutSeconds: _timeout.round(),
      enabled: _enabled,
    );
  }

  void _selectProvider(AiProvider? provider) {
    if (provider == null) return;
    final preset = AiProviderConfig.presetFor(provider);
    setState(() {
      _provider = provider;
      _baseUrlController.text = preset.baseUrl;
      _modelController.text = preset.model;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final repository = ref.read(aiConfigRepositoryProvider);
    await repository.saveConfig(_currentConfig());
    await repository.saveApiKey(_apiKeyController.text);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('AI 服务设置已保存')),
    );
  }

  Future<void> _testConnection() async {
    setState(() => _testing = true);
    try {
      final config = _currentConfig().copyWith(enabled: true);
      final response =
          await ref.read(openAiCompatibleClientProvider).testConnection(
                config: config,
                apiKey: _apiKeyController.text,
              );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${config.providerLabel} 连接成功，返回模型：${response.model}',
          ),
        ),
      );
    } on AiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _clearKey() async {
    await ref.read(aiConfigRepositoryProvider).clearApiKey();
    _apiKeyController.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API Key 已清除')),
      );
    }
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _modelController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI 服务')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      '使用你自己的 API，服务商可能按调用量收费。'
                      '只有你主动点击测试或整理歌词时才会发送请求。',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<AiProvider>(
                  initialValue: _provider,
                  decoration: const InputDecoration(
                    labelText: '服务商',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final provider in AiProvider.values)
                      DropdownMenuItem(
                        value: provider,
                        child: Text(
                          AiProviderConfig.presetFor(provider).providerLabel,
                        ),
                      ),
                  ],
                  onChanged: _selectProvider,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _baseUrlController,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Base URL',
                    helperText: '可填写根地址或完整 /chat/completions 地址',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_provider == AiProvider.qwen)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      '部分地域或企业工作区需要填写包含 WorkspaceId 的专属 Base URL。',
                    ),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: _modelController,
                  decoration: const InputDecoration(
                    labelText: '模型名',
                    helperText: '填写当前账号和服务商实际可用的模型名',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _apiKeyController,
                  obscureText: _obscureKey,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: 'API Key',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      tooltip: _obscureKey ? '显示' : '隐藏',
                      onPressed: () =>
                          setState(() => _obscureKey = !_obscureKey),
                      icon: Icon(
                        _obscureKey ? Icons.visibility : Icons.visibility_off,
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _clearKey,
                    child: const Text('清除 Key'),
                  ),
                ),
                Text('请求超时：${_timeout.round()} 秒'),
                Slider(
                  value: _timeout,
                  min: 15,
                  max: 180,
                  divisions: 11,
                  label: '${_timeout.round()} 秒',
                  onChanged: (value) => setState(() => _timeout = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('启用 AI 服务'),
                  value: _enabled,
                  onChanged: (value) => setState(() => _enabled = value),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _testing ? null : _testConnection,
                  icon: _testing
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.network_check),
                  label: const Text('测试连接'),
                ),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? '保存中…' : '保存设置'),
                ),
              ],
            ),
    );
  }
}
