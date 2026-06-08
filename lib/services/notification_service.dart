import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

class NotificationItem {
  final String id;
  final String title;
  final String body;
  final String createdAt;
  final bool isRead;

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.isRead,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      createdAt: json['createdAt'] as String,
      isRead: json['isRead'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'createdAt': createdAt,
      'isRead': isRead,
    };
  }

  NotificationItem copyWith({bool? isRead}) {
    return NotificationItem(
      id: id,
      title: title,
      body: body,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
    );
  }
}

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const String _notificationsKeyBase = 'edu_notifications';

  // =========================
  // INIT (kept for compatibility)
  // =========================
  Future<void> init() async {
    // No external notification plugin anymore
    return;
  }

  // =========================
  // GET NOTIFICATIONS
  // =========================
  Future<List<NotificationItem>> getNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final email =
        (await AuthService.instance.getRegisteredUser())['email'] ?? '';

    final raw = prefs.getString(_keyFor(email));
    if (raw == null || raw.isEmpty) return [];

    final decoded = jsonDecode(raw) as List<dynamic>;

    return decoded
        .map((item) => NotificationItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  // =========================
  // SAVE NOTIFICATIONS
  // =========================
  Future<void> _saveNotifications(List<NotificationItem> notifications) async {
    final prefs = await SharedPreferences.getInstance();
    final email =
        (await AuthService.instance.getRegisteredUser())['email'] ?? '';

    final raw = jsonEncode(notifications.map((e) => e.toJson()).toList());

    await prefs.setString(_keyFor(email), raw);
  }

  // =========================
  // UNREAD COUNT
  // =========================
  Future<int> getUnreadCount() async {
    final notifications = await getNotifications();
    return notifications.where((n) => !n.isRead).length;
  }

  // =========================
  // ADD NOTIFICATION (IN-APP ONLY)
  // =========================
  Future<void> addNotification(String title, String body) async {
    final notifications = await getNotifications();

    final ts = DateTime.now().millisecondsSinceEpoch;

    final newNotification = NotificationItem(
      id: ts.toString(),
      title: title,
      body: body,
      createdAt: DateTime.now().toIso8601String(),
      isRead: false,
    );

    notifications.insert(0, newNotification);

    await _saveNotifications(notifications);
  }

  // =========================
  // CANCEL (NO-OP NOW)
  // =========================
  Future<void> cancelNotification(int id) async {
    // No OS notifications anymore
    return;
  }

  // =========================
  // MARK ALL AS READ
  // =========================
  Future<void> markAllAsRead() async {
    final notifications = await getNotifications();

    final updated = notifications.map((n) => n.copyWith(isRead: true)).toList();

    await _saveNotifications(updated);
  }

  // =========================
  // INITIAL WELCOME DATA
  // =========================
  Future<void> ensureInitialNotifications() async {
    final prefs = await SharedPreferences.getInstance();

    final email =
        (await AuthService.instance.getRegisteredUser())['email'] ?? '';

    if (prefs.containsKey(_keyFor(email))) return;

    final initialNotifications = [
      NotificationItem(
        id: 'welcome-1',
        title: 'Welcome to EduTask',
        body: 'Your task management is ready. Start by adding a new task.',
        createdAt: DateTime.now().toIso8601String(),
        isRead: false,
      ),
      NotificationItem(
        id: 'welcome-2',
        title: 'Profile ready',
        body:
            'Upload your photo and update your profile for a better experience.',
        createdAt: DateTime.now().toIso8601String(),
        isRead: false,
      ),
      NotificationItem(
        id: 'welcome-3',
        title: 'Tips for success',
        body: 'Use reminders to stay on top of your daily tasks.',
        createdAt: DateTime.now().toIso8601String(),
        isRead: false,
      ),
    ];

    await _saveNotifications(initialNotifications);
  }

  // =========================
  // KEY HANDLING
  // =========================
  String _keyFor(String email) {
    if (email.isEmpty) return _notificationsKeyBase;

    final safe = email.replaceAll(RegExp('[^a-zA-Z0-9]'), '_');

    return '${_notificationsKeyBase}_$safe';
  }
}
