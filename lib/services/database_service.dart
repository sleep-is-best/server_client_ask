import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/message.dart';

class DatabaseService {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'chat_database.db');
    return await openDatabase(
      path,
      version: 4,
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
            senderMsgId INTEGER,
            timestamp TEXT,
            isMe INTEGER,
            status INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE call_logs(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            callerId TEXT,
            receiverId TEXT,
            timestamp TEXT,
            duration INTEGER,
            type TEXT,
            status TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 5) {
           await db.execute('''
            CREATE TABLE IF NOT EXISTS call_logs(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              callerId TEXT,
              receiverId TEXT,
              timestamp TEXT,
              duration INTEGER,
              type TEXT,
              status TEXT
            )
          ''');
        }
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE messages ADD COLUMN fileName TEXT');
          await db.execute('ALTER TABLE messages ADD COLUMN status INTEGER DEFAULT 1');
        }
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE messages ADD COLUMN localPath TEXT');
        }
        if (oldVersion < 4) {
          await db.execute('ALTER TABLE messages ADD COLUMN senderMsgId INTEGER');
        }
      },
    );
  }

  Future<int> insertMessage(Message message) async {
    final db = await database;
    return await db.insert(
      'messages',
      message.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Message>> getMessages(String peerId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'messages',
      where: 'senderId = ? OR targetId = ?',
      whereArgs: [peerId, peerId],
      orderBy: 'timestamp DESC',
    );

    return List.generate(maps.length, (i) {
      return Message.fromMap(maps[i]);
    });
  }

  Future<List<Message>> getRecentChats(String myId) async {
    final db = await database;
    // استعلام لجلب آخر رسالة من كل محادثة
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

  Future<void> markAsRead(String peerId) async {
    final db = await database;
    await db.update(
      'messages',
      {'status': MessageStatus.read.index},
      where: 'senderId = ? AND status != ?',
      whereArgs: [peerId, MessageStatus.read.index],
    );
  }

  Future<void> updateMessageStatus(int id, MessageStatus status) async {
    final db = await database;
    await db.update(
      'messages',
      {'status': status.index},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Call Logs
  Future<int> insertCallLog(Map<String, dynamic> log) async {
    final db = await database;
    return await db.insert('call_logs', log);
  }

  Future<List<Map<String, dynamic>>> getCallLogs() async {
    final db = await database;
    return await db.query('call_logs', orderBy: 'timestamp DESC');
  }
}
