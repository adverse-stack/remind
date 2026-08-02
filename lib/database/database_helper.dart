import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/task.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'tasks.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE tasks('
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'title TEXT, '
          'description TEXT, '
          'scheduledTime TEXT, '
          'repeatType INTEGER, '
          'repeatDays TEXT)',
        );
      },
    );
  }

  Future<int> insertTask(Task task) async {
    final db = await database;
    return await db.insert('tasks', task.toMap());
  }

  Future<List<Task>> getAllTasks() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('tasks');
    return maps.map((map) => Task.fromMap(map)).toList();
  }

  Future<List<Task>> getTasksForDate(DateTime date) async {
    final all = await getAllTasks();
    return all.where((task) {
      // For one-time tasks, compare exact date
      if (task.repeatType == RepeatType.once) {
        return task.scheduledTime.year == date.year &&
            task.scheduledTime.month == date.month &&
            task.scheduledTime.day == date.day;
      }
      // For daily tasks, they always show up (or we filter by time? we show them)
      if (task.repeatType == RepeatType.daily) {
        return true;
      }
      // For weekly tasks, check if today's weekday is in repeatDays
      if (task.repeatType == RepeatType.weekly) {
        final todayWeekday = date.weekday % 7; // Monday=1, Sunday=0
        return task.repeatDays?.contains(todayWeekday) ?? false;
      }
      return false;
    }).toList();
  }

  Future<void> deleteTask(int id) async {
    final db = await database;
    await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }
}
