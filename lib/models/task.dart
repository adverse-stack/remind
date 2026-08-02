enum RepeatType { once, daily, weekly }

class Task {
  final int? id;
  final String title;
  final String description;
  final DateTime scheduledTime;
  final RepeatType repeatType;
  final List<int>? repeatDays; // 0=Sun, 1=Mon ... 6=Sat

  Task({
    this.id,
    required this.title,
    required this.description,
    required this.scheduledTime,
    this.repeatType = RepeatType.once,
    this.repeatDays,
  });

  Task copyWith({
    int? id,
    String? title,
    String? description,
    DateTime? scheduledTime,
    RepeatType? repeatType,
    List<int>? repeatDays,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      repeatType: repeatType ?? this.repeatType,
      repeatDays: repeatDays ?? this.repeatDays,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'scheduledTime': scheduledTime.toIso8601String(),
      'repeatType': repeatType.index,
      'repeatDays': repeatDays?.join(','),
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      scheduledTime: DateTime.parse(map['scheduledTime']),
      repeatType: RepeatType.values[map['repeatType']],
      repeatDays: map['repeatDays'] != null
          ? map['repeatDays'].split(',').map(int.parse).toList()
          : null,
    );
  }

  // Helper: get a display string for repeat type
  String get repeatLabel {
    switch (repeatType) {
      case RepeatType.once:
        return 'Once';
      case RepeatType.daily:
        return 'Daily';
      case RepeatType.weekly:
        if (repeatDays == null || repeatDays!.isEmpty) return 'Weekly';
        final weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
        return repeatDays!.map((d) => weekdays[d]).join(', ');
    }
  }
}
