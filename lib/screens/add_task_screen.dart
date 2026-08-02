import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../database/database_helper.dart';
import '../services/notification_service.dart';

class AddTaskScreen extends StatefulWidget {
  const AddTaskScreen({super.key});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  DateTime _selectedDateTime = DateTime.now().add(const Duration(hours: 1));
  RepeatType _repeatType = RepeatType.once;
  List<int> _selectedWeekdays = []; // 0=Sun

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Task'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              // Date & Time Picker
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('Scheduled Time'),
                subtitle: Text(
                  DateFormat('MMM d, y • HH:mm').format(_selectedDateTime),
                ),
                onTap: _pickDateTime,
                tileColor: Colors.grey.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(height: 16),
              // Repeat Type
              DropdownButtonFormField<RepeatType>(
                value: _repeatType,
                decoration: const InputDecoration(
                  labelText: 'Repeat',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.repeat),
                ),
                items: const [
                  DropdownMenuItem(value: RepeatType.once, child: Text('Once')),
                  DropdownMenuItem(value: RepeatType.daily, child: Text('Daily')),
                  DropdownMenuItem(value: RepeatType.weekly, child: Text('Weekly')),
                ],
                onChanged: (value) {
                  setState(() {
                    _repeatType = value!;
                    if (_repeatType != RepeatType.weekly) {
                      _selectedWeekdays = [];
                    }
                  });
                },
              ),
              const SizedBox(height: 16),
              // Weekly day picker (shown only when weekly is selected)
              if (_repeatType == RepeatType.weekly) ...[
                const Text('Select days:',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _dayChip('Sun', 0),
                    _dayChip('Mon', 1),
                    _dayChip('Tue', 2),
                    _dayChip('Wed', 3),
                    _dayChip('Thu', 4),
                    _dayChip('Fri', 5),
                    _dayChip('Sat', 6),
                  ],
                ),
                if (_selectedWeekdays.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('Select at least one day',
                        style: TextStyle(color: Colors.red, fontSize: 12)),
                  ),
                const SizedBox(height: 16),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submitTask,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Save Task', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dayChip(String label, int value) {
    final isSelected = _selectedWeekdays.contains(value);
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _selectedWeekdays.add(value);
          } else {
            _selectedWeekdays.remove(value);
          }
        });
      },
      selectedColor: Colors.teal.shade200,
      backgroundColor: Colors.grey.shade200,
    );
  }

  Future<void> _pickDateTime() async {
    // Date picker
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
    );
    if (time == null) return;

    setState(() {
      _selectedDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _submitTask() async {
    if (!_formKey.currentState!.validate()) return;
    if (_repeatType == RepeatType.weekly && _selectedWeekdays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one day for weekly repeat')),
      );
      return;
    }

    final task = Task(
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      scheduledTime: _selectedDateTime,
      repeatType: _repeatType,
      repeatDays: _repeatType == RepeatType.weekly ? _selectedWeekdays : null,
    );

    // Save to DB
    final id = await DatabaseHelper().insertTask(task);
    final savedTask = task.copyWith(id: id);

    // Schedule notifications
    if (_repeatType == RepeatType.once) {
      await NotificationService.scheduleReminder(savedTask);
    } else if (_repeatType == RepeatType.daily) {
      // Schedule for the next 30 days
      for (int i = 0; i < 30; i++) {
        final nextDay = savedTask.scheduledTime.add(Duration(days: i));
        final dailyTask = savedTask.copyWith(scheduledTime: nextDay);
        await NotificationService.scheduleReminder(dailyTask,
            customId: int.parse('${id}${i}'));
      }
    } else {
      // Weekly: schedule for the next 12 weeks
      for (int week = 0; week < 12; week++) {
        for (int day in _selectedWeekdays) {
          final nextDate = _nextWeekday(savedTask.scheduledTime, day, week);
          if (nextDate.isAfter(DateTime.now())) {
            final weeklyTask = savedTask.copyWith(scheduledTime: nextDate);
            final customId = int.parse('${id}${week}${day}');
            await NotificationService.scheduleReminder(weeklyTask,
                customId: customId);
          }
        }
      }
    }

    // Request overlay permission proactively
    await OverlayManager.requestPermission();

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Task created & scheduled!')),
    );
  }

  DateTime _nextWeekday(DateTime from, int targetWeekday, int weeksOffset) {
    // targetWeekday: 0=Sun, 1=Mon ...
    int daysUntil = targetWeekday - from.weekday % 7;
    if (daysUntil < 0) daysUntil += 7;
    return from.add(Duration(days: daysUntil + weeksOffset * 7));
  }
}
