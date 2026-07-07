import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'import_service.dart';

class ImportHistoryEntry {
  const ImportHistoryEntry({
    required this.timestamp,
    required this.target,
    required this.created,
    required this.existed,
    required this.errorCount,
    this.playlistName,
  });

  final DateTime timestamp;
  final ImportTarget target;
  final int created;
  final int existed;
  final int errorCount;
  final String? playlistName;

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'target': target.name,
        'created': created,
        'existed': existed,
        'errorCount': errorCount,
        'playlistName': playlistName,
      };

  factory ImportHistoryEntry.fromJson(Map<String, dynamic> json) => ImportHistoryEntry(
        timestamp: DateTime.parse(json['timestamp'] as String),
        target: ImportTarget.values.firstWhere((e) => e.name == json['target']),
        created: json['created'] as int,
        existed: json['existed'] as int,
        errorCount: json['errorCount'] as int,
        playlistName: json['playlistName'] as String?,
      );
}

class SettingsService {
  static const _maxHistory = 3;

  Future<File> _settingsFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, 'singlist_settings.json'));
  }

  Future<Map<String, dynamic>> _load() async {
    final file = await _settingsFile();
    if (!await file.exists()) return {};
    try {
      return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  Future<void> _save(Map<String, dynamic> data) async {
    final file = await _settingsFile();
    await file.writeAsString(jsonEncode(data));
  }

  ImportTarget? loadLastImportTarget() {
    return null;
  }

  Future<ImportTarget?> loadLastImportTargetAsync() async {
    final data = await _load();
    final name = data['lastImportTarget'] as String?;
    if (name == null) return null;
    return ImportTarget.values.cast<ImportTarget?>().firstWhere(
          (e) => e?.name == name,
          orElse: () => null,
        );
  }

  Future<void> saveLastImportTarget(ImportTarget target) async {
    final data = await _load();
    data['lastImportTarget'] = target.name;
    await _save(data);
  }

  List<ImportHistoryEntry> loadImportHistory() => [];

  Future<List<ImportHistoryEntry>> loadImportHistoryAsync() async {
    final data = await _load();
    final list = data['importHistory'] as List<dynamic>? ?? [];
    return list
        .map((e) => ImportHistoryEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> recordImportHistory(ImportHistoryEntry entry) async {
    final data = await _load();
    final history = await loadImportHistoryAsync();
    final updated = [entry, ...history].take(_maxHistory).toList();
    data['importHistory'] = updated.map((e) => e.toJson()).toList();
    await _save(data);
  }
}
