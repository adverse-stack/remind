import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../database/database_helper.dart';
import '../models/task.dart';
import '../services/notification_service.dart';
import '../services/overlay_manager.dart';
import 'add_task_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  List<Task> _tasks = [];

  @override
  void initState() {
    super.initState();
    _loadTasks();

    // Listen for notification taps (to show overlay)
    NotificationService.onNotificationTappedController.stream.listen((taskId) {
      _handleNotificationTap(taskId);
    });
  }

  Future<void> _loadTasks() async {
    final db = DatabaseHelper();
    final tasks = await db.getAllTasks();
    setState(() {
      _tasks = tasks;
    });
  }

  List<Task> get _tasksForSelectedDay {
    return _tasks.where((task) {
      // One-time: exact date match
      if (task.repeatType == RepeatType.once) {
        return task.scheduledTime.year == _selectedDay.year &&
            task.scheduledTime.month == _selectedDay.month &&
            task.scheduledTime.day == _selectedDay.day;
      }
      // Daily: always show
      if (task.repeatType == RepeatType.daily) {
        return true;
      }
      // Weekly: check weekday
      if (task.repeatType == RepeatType.weekly) {
        final weekday = _selectedDay.weekday % 7; // 0=Sun
        return task.repeatDays?.contains(weekday) ?? false;
      }
      return false;
    }).toList();
  }

  // When a notification is tapped, show the overlay
  Future<void> _handleNotificationTap(int taskId) async {
    final task = _tasks.firstWhere((t) => t.id == taskId, orElse: () => throw Exception('Task not found'));
    if (task.id == null) return;

    // Show overlay
    await OverlayManager.showOverlay(
      taskId: task.id!,
      title: task.title,
      description: task.description,
      onComplete: () async {
        // Delete the task (or mark complete)
        await DatabaseHelper().deleteTask(task.id!);
        await NotificationService.cancelNotification(task.id!);
        _loadTasks();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task completed!')),
        );
      },
      onSnooze: () async {
        // Reschedule 5 minutes later
        final newTime = DateTime.now().add(const Duration(minutes: 5));
        final snoozedTask = task.copyWith(scheduledTime: newTime);
        await DatabaseHelper().insertTask(snoozedTask);
        await NotificationService.scheduleReminder(snoozedTask);
        _loadTasks();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Snoozed for 5 minutes')),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('My Schedule', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              await NotificationService.cancelAll();
              final db = DatabaseHelper();
              final all = await db.getAllTasks();
              for (var task in all) {
                await db.deleteTask(task.id!);
              }
              _loadTasks();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(12),
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: TableCalendar(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                onDaySelected: (selected, focused) {
                  setState(() {
                    _selectedDay = selected;
                    _focusedDay = focused;
                  });
                },
                calendarStyle: CalendarStyle(
                  selectedDecoration: BoxDecoration(
                    color: Colors.teal,
                    shape: BoxShape.circle,
                  ),
                  todayDecoration: BoxDecoration(
                    color: Colors.teal.shade100,
                    shape: BoxShape.circle,
                  ),
                  weekendTextStyle: TextStyle(color: Colors.red[400]),
                ),
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('EEEE, MMM d').format(_selectedDay),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                Text('${_tasksForSelectedDay.length} tasks',
                    style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          ),
          const Divider(height: 16, thickness: 1),
          Expanded(
            child: _tasksForSelectedDay.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text('No tasks for this day',
                            style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _tasksForSelectedDay.length,
                    itemBuilder: (context, index) {
                      final task = _tasksForSelectedDay[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.teal.shade100,
                            child: Icon(Icons.task_alt, color: Colors.teal[700]),
                          ),
                          title: Text(task.title,
                              style: const TextStyle(fontWeight: FontWeight.w500)),
                          subtitle: Text(
                            '${DateFormat('HH:mm').format(task.scheduledTime)} • ${task.repeatLabel}',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () async {
                              await DatabaseHelper().deleteTask(task.id!);
                              await NotificationService.cancelNotification(task.id!);
                              _loadTasks();
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddTaskScreen()),
          );
          _loadTasks();
        },
        icon: const Icon(Icons.add),
        label: const Text('New Task'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
    );
  }
}
