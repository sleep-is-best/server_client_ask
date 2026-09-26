import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/message.dart';
import '../models/chat_message.dart';
import '../models/question.dart';
import '../models/answer.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;
  static Isar? _isar;

  final _questionsController = StreamController<List<Question>>.broadcast();
  Stream<List<Question>> get questionsStream async* {
    yield await getQuestions();
    yield* _questionsController.stream;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Isar> get isar async {
    if (_isar != null) return _isar!;
    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [ChatMessageSchema],
      directory: dir.path,
    );
    return _isar!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'educational_platform.db');
    return await openDatabase(
      path,
      version: 10,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE messages(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            senderId TEXT,
            targetId TEXT,
            text TEXT,
            type TEXT,
            mediaUrl TEXT,
            fileName TEXT,
            localPath TEXT,
            senderMsgId TEXT UNIQUE,
            timestamp TEXT,
            isMe INTEGER,
            status INTEGER,
            burnDuration INTEGER,
            burnAt TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE questions (
            id TEXT PRIMARY KEY,
            userId TEXT,
            content TEXT,
            mediaUrls TEXT,
            mediaType TEXT,
            timestamp TEXT,
            points INTEGER,
            answerCount INTEGER DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE answers (
            id TEXT PRIMARY KEY,
            questionId TEXT,
            userId TEXT,
            content TEXT,
            timestamp TEXT,
            isBest INTEGER DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE sync_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            action TEXT,
            data TEXT,
            timestamp TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 10) {
          try {
            await db.execute('DROP TABLE IF EXISTS answers');
            await db.execute('''
              CREATE TABLE answers (
                id TEXT PRIMARY KEY,
                questionId TEXT,
                userId TEXT,
                content TEXT,
                timestamp TEXT,
                isBest INTEGER DEFAULT 0
              )
            ''');
          } catch (e) {
            print("Database upgrade error (v10): $e");
          }
        }
        if (oldVersion < 9) {
          try {
            await db.execute('ALTER TABLE questions ADD COLUMN mediaUrls TEXT');
          } catch (e) {
            print("Database upgrade error (v9): $e");
          }
        }
        if (oldVersion < 8) {
          try {
            await db.execute('ALTER TABLE questions ADD COLUMN mediaUrl TEXT');
            await db.execute('ALTER TABLE questions ADD COLUMN mediaType TEXT');
          } catch (e) {
            print("Database upgrade error: $e");
          }
        }
      },
    );
  }

  final _messagesController = StreamController<List<Message>>.broadcast();
  Stream<List<Message>> getRecentChatsStream(String myId) async* {
    yield await getRecentChats(myId);
    yield* _messagesController.stream;
  }

  Future<int> insertMessage(Message message) async {
    final db = await database;
    final id = await db.insert(
      'messages',
      message.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    
    // Refresh streams
    final recentChats = await getRecentChats(message.isMe ? message.senderId : message.targetId);
    _messagesController.add(recentChats);
    
    try {
      final isarDb = await isar;
      final chatMsg = ChatMessage.create(
        senderId: message.senderId,
        receiverId: message.targetId,
        text: message.text,
        timestamp: message.timestamp,
        isMe: message.isMe,
        type: message.type,
        mediaUrl: message.mediaUrl,
        fileName: message.fileName,
        localPath: message.localPath,
        senderMsgId: message.senderMsgId,
        status: message.status.index,
        burnDuration: message.burnDuration,
        burnAt: message.burnAt,
      );
      await isarDb.writeTxn(() async {
        await isarDb.chatMessages.put(chatMsg);
      });
    } catch (e) {
      print('Isar insert error: $e');
    }
    
    return id;
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('messages');
      await txn.delete('questions');
      await txn.delete('answers');
      await txn.delete('sync_queue');
    });
    
    try {
      final isarDb = await isar;
      await isarDb.writeTxn(() async {
        await isarDb.chatMessages.clear();
      });
    } catch (e) {
      print('Isar clear error: $e');
    }
    
    // Refresh streams with empty data
    _messagesController.add([]);
    _questionsController.add([]);
  }

  Future<List<Message>> getMessages(String myId, String peerId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'messages',
      where: '(senderId = ? AND targetId = ?) OR (senderId = ? AND targetId = ?)',
      whereArgs: [myId, peerId, peerId, myId],
      orderBy: 'timestamp DESC',
    );

    return List.generate(maps.length, (i) {
      return Message.fromMap(maps[i]);
    });
  }

  Future<List<Message>> getRecentChats(String myId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT * FROM messages 
      WHERE id IN (
        SELECT MAX(id) FROM messages 
        WHERE senderId = ? OR targetId = ?
        GROUP BY CASE 
          WHEN senderId = ? THEN targetId 
          ELSE senderId 
        END
      )
      ORDER BY timestamp DESC
    ''', [myId, myId, myId]);

    return List.generate(maps.length, (i) {
      return Message.fromMap(maps[i]);
    });
  }

  // Question Methods
  Future<void> insertQuestion(Question question) async {
    final db = await database;
    final map = question.toMap();
    if (map['mediaUrls'] != null && map['mediaUrls'] is List) {
      map['mediaUrls'] = jsonEncode(map['mediaUrls']);
    }
    await db.insert('questions', map, conflictAlgorithm: ConflictAlgorithm.replace);
    
    // Refresh the stream after insertion
    final allQuestions = await getQuestions();
    _questionsController.add(allQuestions);
  }

  Future<void> replaceQuestions(List<Question> questions) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('questions');
      for (var q in questions) {
        final map = q.toMap();
        if (map['mediaUrls'] != null && map['mediaUrls'] is List) {
          map['mediaUrls'] = jsonEncode(map['mediaUrls']);
        }
        await txn.insert('questions', map);
      }
    });
    _questionsController.add(questions);
  }

  Future<List<Question>> getQuestions() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('questions', orderBy: 'timestamp DESC');
    return maps.map((m) {
      final mutableMap = Map<String, dynamic>.from(m);
      if (mutableMap['mediaUrls'] != null && mutableMap['mediaUrls'] is String) {
        try {
          mutableMap['mediaUrls'] = jsonDecode(mutableMap['mediaUrls']);
        } catch (e) {
          mutableMap['mediaUrls'] = [mutableMap['mediaUrls']];
        }
      }
      return Question.fromMap(mutableMap);
    }).toList();
  }

  // Answer Methods
  Future<void> insertAnswer(Answer answer) async {
    final db = await database;
    await db.insert('answers', answer.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Answer>> getAnswersForQuestion(String questionId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'answers',
      where: 'questionId = ?',
      whereArgs: [questionId],
      orderBy: 'isBest DESC, timestamp ASC',
    );
    return maps.map((m) => Answer.fromMap(m)).toList();
  }

  Future<void> markBestAnswer(String questionId, String answerId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update('answers', {'isBest': 0}, where: 'questionId = ?', whereArgs: [questionId]);
      await txn.update('answers', {'isBest': 1}, where: 'id = ?', whereArgs: [answerId]);
    });
  }

  Future<void> markAllAsRead(String peerId) async {
    final db = await database;
    await db.update('messages', {'status': MessageStatus.read.index}, where: 'senderId = ?', whereArgs: [peerId]);
  }

  Future<void> addToSyncQueue(String action, Map<String, dynamic> data) async {
    final db = await database;
    
    // Check queue size before adding to prevent OOM
    final countResult = await db.rawQuery('SELECT COUNT(*) as total FROM sync_queue');
    final int count = Sqflite.firstIntValue(countResult) ?? 0;
    
    if (count >= 100) {
      // Remove the oldest item if queue is full
      final oldestItem = await db.query('sync_queue', orderBy: 'timestamp ASC', limit: 1);
      if (oldestItem.isNotEmpty) {
        await db.delete('sync_queue', where: 'id = ?', whereArgs: [oldestItem.first['id']]);
      }
    }

    await db.insert('sync_queue', {
      'action': action,
      'data': jsonEncode(data),
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getSyncQueue() async {
    final db = await database;
    return await db.query('sync_queue', orderBy: 'timestamp ASC');
  }

  Future<void> removeFromSyncQueue(int id) async {
    final db = await database;
    await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateMessageStatus(String clientMsgId, int status) async {
    final db = await database;
    await db.update(
      'messages',
      {'status': status},
      where: 'senderMsgId = ?',
      whereArgs: [clientMsgId],
    );
    
    try {
      final isarDb = await isar;
      final chatMsg = await isarDb.chatMessages.filter().senderMsgIdEqualTo(clientMsgId).findFirst();
      if (chatMsg != null) {
        await isarDb.writeTxn(() async {
          chatMsg.status = status;
          await isarDb.chatMessages.put(chatMsg);
        });
      }
    } catch (e) {
      print('Isar update status error: $e');
    }
  }

  Future<void> deleteMessage(int id) async {
    final db = await database;
    await db.delete('messages', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteQuestion(String id) async {
    final db = await database;
    await db.delete('questions', where: 'id = ?', whereArgs: [id]);
    await db.delete('answers', where: 'questionId = ?', whereArgs: [id]);
    
    // Refresh the stream
    final allQuestions = await getQuestions();
    _questionsController.add(allQuestions);
  }
}
