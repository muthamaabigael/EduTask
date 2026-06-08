import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'notification_service.dart';
import 'auth_service.dart';

class Task {
  final String id;
  final String name;
  final String category;
  final String description;
  final DateTime dateTime;
  final String reminder;
  final bool notified;

  Task({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.dateTime,
    required this.reminder,
    this.notified = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'description': description,
      'dateTime': dateTime.toIso8601String(),
      'reminder': reminder,
      'notified': notified,
    };
  }

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      description: json['description'] as String,
      dateTime: DateTime.parse(json['dateTime'] as String),
      reminder: json['reminder'] as String,
      notified: json['notified'] == true,
    );
  }
}

class TaskService {
  TaskService._();

  static final TaskService instance = TaskService._();

  static const String _taskKeyBase = 'user_tasks';
  // Timer? _scheduler;

  Future<List<Task>> getTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final email =
        (await AuthService.instance.getRegisteredUser())['email'] ?? '';
    final raw = prefs.getString(_keyFor(email));
    if (raw == null || raw.isEmpty) {
      return [];
    }

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => Task.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> addTask(Task task) async {
    final tasks = await getTasks();
    tasks.add(task);
    final prefs = await SharedPreferences.getInstance();
    final email =
        (await AuthService.instance.getRegisteredUser())['email'] ?? '';
    await prefs.setString(
      _keyFor(email),
      jsonEncode(tasks.map((item) => item.toJson()).toList()),
    );

    await NotificationService.instance.addNotification(
      'New task created',
      'Your task "${task.name}" has been added successfully.',
    );
    // Schedule OS-level notification for the task
    // try {
    //   final int nid = task.id.hashCode & 0x7fffffff;
    //   await NotificationService.instance.scheduleNotification(
    //     nid,
    //     'Task Reminder',
    //     '"${task.name}" is due now.',
    //     task.dateTime,
    //   );
    // } catch (_) {}
  }

  Future<void> updateTask(Task task) async {
    final tasks = await getTasks();
    final idx = tasks.indexWhere((t) => t.id == task.id);
    if (idx != -1) {
      tasks[idx] = task;
      final prefs = await SharedPreferences.getInstance();
      final email =
          (await AuthService.instance.getRegisteredUser())['email'] ?? '';
      await prefs.setString(
        _keyFor(email),
        jsonEncode(tasks.map((item) => item.toJson()).toList()),
      );
      // Cancel previous schedule and reschedule
      // try {
      //   final int nid = task.id.hashCode & 0x7fffffff;
      //   await NotificationService.instance.cancelNotification(nid);
      //   await NotificationService.instance.scheduleNotification(
      //     nid,
      //     'Task Reminder',
      //     '"${task.name}" is due now.',
      //     task.dateTime,
      //   );
      // } catch (_) {}
    }
  }

  Future<void> removeTask(String id) async {
    final tasks = await getTasks();
    final remaining = tasks.where((task) => task.id != id).toList();
    final prefs = await SharedPreferences.getInstance();
    final email =
        (await AuthService.instance.getRegisteredUser())['email'] ?? '';
    await prefs.setString(
      _keyFor(email),
      jsonEncode(remaining.map((item) => item.toJson()).toList()),
    );
    // try {
    //   final int nid = id.hashCode & 0x7fffffff;
    //   await NotificationService.instance.cancelNotification(nid);
    // } catch (_) {}
  }

  String _keyFor(String email) {
    if (email.isEmpty) return _taskKeyBase;
    final safe = email.replaceAll(RegExp('[^a-zA-Z0-9]'), '_');
    return '${_taskKeyBase}_$safe';
  }

  // void startScheduler() {
  //    _scheduler?.cancel();
  //    _scheduler = Timer.periodic(const Duration(minutes: 1), (_) async {
  //     final tasks = await getTasks();
  //     final now = DateTime.now();
  //     for (final task in tasks) {
  //       if (!task.notified && task.dateTime.isBefore(now.add(const Duration(seconds: 5)))) {
  //         await NotificationService.instance.addNotification(
  //           'Task Reminder',
  //           '"${task.name}" is due now.',
  //          );
  //          final updated = Task(
  //           id: task.id,
  //           name: task.name,
  //           category: task.category,
  //            description: task.description,
  //            dateTime: task.dateTime,
  //            reminder: task.reminder,
  //            notified: true,
  //          );
  //          await updateTask(updated);
  //        }
  //      }
  //    });
  //  }

  Future<void> clearTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final email =
        (await AuthService.instance.getRegisteredUser())['email'] ?? '';
    await prefs.remove(_keyFor(email));
  }
}
