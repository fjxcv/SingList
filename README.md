# K歌选歌（SingList）

本项目是一个完全离线、本地优先的 Flutter 3.x 跨端 MVP，用于管理 K 歌歌曲、标签、歌单与 KQueue 队列，并支持刷歌/随机生成、分享与粘贴导入。

## 运行方式
1. 安装 Flutter 3.22+ 环境。
2. 获取依赖：
   ```bash
   flutter pub get
   ```
3. 生成 Drift 代码（若需要重新生成）：
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```
4. 运行：
   ```bash
   flutter run
   ```

## 依赖栈
- Flutter 3.x + Dart 3
- Drift + sqlite3_flutter_libs（本地数据库）
- 状态管理：flutter_riverpod
- 分享：share_plus
- 导入：Clipboard 粘贴 + 自定义解析
- 列表拖拽排序：ReorderableListView
- UI：Material 3

## 功能概览
- **歌曲库**：新增/编辑/删除/搜索，支持多选批量加标签、批量加入普通歌单。
- **标签**：预置“开嗓/气氛/收尾”，可增删改；查看标签下歌曲。
- **歌单**：普通歌单（去重）与 KQueue 队列（允许重复、拖拽排序、删除、清空）。
- **生成器**：
  - 刷歌模式：逐首浏览来源（全部/标签/歌单），标记 ⭐特别想唱 / ✅想唱 / ❌不想。完成后生成新的 KQueue，顺序为开嗓暖场（随机 N 首带“开嗓”标签）→ ⭐ → ✅。
  - 随机模式：选择来源与数量，可开关“本次尽量不重复”，直接生成 KQueue。
- **分享与导入**：
  - 队列一键导出文本（每行“歌名 - 歌手”，顶部“#K歌歌单”标题）。
  - 粘贴文本导入（支持“歌名 - 歌手”或“歌名/歌手”），自动补齐歌曲并按顺序生成新的队列。

## 数据模型
- **Song**：`title`, `artist`, `titleNorm`, `artistNorm`（歌名+歌手唯一，规范化规则：trim、压缩空格、转小写）。
- **Tag**：`name` 全局唯一。
- **SongTag**：多对多唯一 `(songId, tagId)`。
- **Playlist**：`type = normal | kQueue`。
- **PlaylistEntries**：普通歌单的歌曲，不允许重复 `(playlistId, songId)`。
- **QueueItems**：KQueue 队列条目，允许重复并记录 `position` 用于拖拽排序。

## 测试
运行核心逻辑单元测试：
```bash
flutter test
```
包含规范化、导入解析、生成排序规则等测试用例。
