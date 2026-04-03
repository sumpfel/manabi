import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/profile/ai_chat_screen.dart'; // Using the UI's defined models ChatMessage and ChatConversation
import 'database_service.dart';

final aiRepositoryProvider = Provider<AiRepository>((ref) {
  return AiRepository(ref.read(databaseProvider));
});

class AiRepository {
  final DatabaseService _dbService;

  AiRepository(this._dbService);

  Future<List<ChatConversation>> getConversations() async {
    final db = await _dbService.database;
    final maps = await db.query('ai_conversations', orderBy: 'updated_at DESC');
    return maps.map((m) => ChatConversation(
      id: m['id'] as int,
      title: m['title'] as String,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(m['updated_at'] as int),
    )).toList();
  }

  Future<int> addConversation(String title) async {
    final db = await _dbService.database;
    return await db.insert('ai_conversations', {
      'title': title,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> updateConversationTime(int id) async {
    final db = await _dbService.database;
    await db.update(
      'ai_conversations',
      {'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateConversationTitle(int id, String title) async {
    final db = await _dbService.database;
    await db.update(
      'ai_conversations',
      {'title': title},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteConversation(int id) async {
    final db = await _dbService.database;
    await db.delete('ai_conversations', where: 'id = ?', whereArgs: [id]);
  }

  /// Get messages for a conversation, collapsing regenerated versions.
  /// Only returns the LATEST version for each parent_message_id group.
  Future<List<ChatMessage>> getMessages(int conversationId) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'ai_messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'id ASC',
    );

    // Group messages by parent_message_id for version tracking
    final allMessages = <ChatMessage>[];
    final versionGroups = <int, List<Map<String, Object?>>>{};

    for (final m in maps) {
      final parentId = m['parent_message_id'] as int?;
      if (parentId != null) {
        versionGroups.putIfAbsent(parentId, () => []);
        versionGroups[parentId]!.add(m);
      } else {
        allMessages.add(_mapToMessage(m));
      }
    }

    // For messages that have versions, attach version info
    final result = <ChatMessage>[];
    for (final msg in allMessages) {
      if (msg.id != null && versionGroups.containsKey(msg.id)) {
        final versions = versionGroups[msg.id]!;
        // Show the latest version by default
        final latestVersion = versions.last;
        final totalVersions = versions.length + 1; // +1 for the original
        result.add(ChatMessage(
          id: latestVersion['id'] as int,
          content: latestVersion['content'] as String,
          isUser: false,
          timestamp: DateTime.fromMillisecondsSinceEpoch(latestVersion['created_at'] as int),
          isEdited: (latestVersion['is_edited'] as int) == 1,
          parentMessageId: msg.id,
          versionIndex: totalVersions - 1,
          totalVersions: totalVersions,
          allVersionContents: [
            msg.content,
            ...versions.map((v) => v['content'] as String),
          ],
        ));
      } else {
        result.add(msg);
      }
    }
    return result;
  }

  ChatMessage _mapToMessage(Map<String, Object?> m) {
    return ChatMessage(
      id: m['id'] as int,
      content: m['content'] as String,
      isUser: m['role'] == 'user',
      timestamp: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
      isEdited: (m['is_edited'] as int) == 1,
    );
  }

  Future<int> addMessage(int conversationId, ChatMessage msg, {int? parentMessageId}) async {
    final db = await _dbService.database;
    return await db.insert('ai_messages', {
      'conversation_id': conversationId,
      'role': msg.isUser ? 'user' : 'model',
      'content': msg.content,
      'is_edited': msg.isEdited ? 1 : 0,
      'created_at': msg.timestamp.millisecondsSinceEpoch,
      'parent_message_id': parentMessageId,
    });
  }

  Future<void> updateMessageContent(int messageId, String newContent) async {
    final db = await _dbService.database;
    await db.update(
      'ai_messages',
      {'content': newContent, 'is_edited': 1},
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }
}
