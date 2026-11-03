import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../models/task_model.dart';
import '../utils/constants.dart' hide Priority;

class NotificationService {
  static final _notifications = FlutterLocalNotificationsPlugin();

  // ── Initialise ──────────────────────────────────────────────
  static Future<void> init() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kuala_Lumpur'));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (details) {},
    );

    // Request permission for Android 13+
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  // ── Notification Details ─────────────────────────────────────
  static NotificationDetails _details({String channelId = 'farm_tasks'}) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        'Farm Task Reminders',
        channelDescription: 'Reminders for farm tasks and deadlines',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        enableVibration: true,
        playSound: true,
      ),
    );
  }

  // ── Show Immediate Notification ──────────────────────────────
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    await _notifications.show(id, title, body, _details());
  }

  // ── Schedule Notification ────────────────────────────────────
  static Future<void> scheduleTaskReminder(TaskModel task) async {
    await cancelNotification(task.id.hashCode);
    if (task.status == TaskStatus.done) return;

    final now = DateTime.now();
    final deadline = task.deadline;

    // Schedule for 8 AM on the deadline day
    final reminderTime = DateTime(
      deadline.year,
      deadline.month,
      deadline.day,
      8,
      0,
    );

    if (reminderTime.isAfter(now)) {
      await _notifications.zonedSchedule(
        task.id.hashCode,
        '📋 Task Due Today: ${task.title}',
        '${task.cropType} • ${task.category} • Assigned to: ${task.assignedTo}',
        tz.TZDateTime.from(reminderTime, tz.local),
        _details(channelId: 'farm_tasks_scheduled'),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      );
    }

    // 1-day-before reminder
    final dayBefore = reminderTime.subtract(const Duration(days: 1));
    if (dayBefore.isAfter(now)) {
      await _notifications.zonedSchedule(
        task.id.hashCode + 10000,
        '⏰ Task Due Tomorrow: ${task.title}',
        'Don\'t forget: ${task.category} for ${task.cropType} is due tomorrow!',
        tz.TZDateTime.from(dayBefore, tz.local),
        _details(channelId: 'farm_tasks_scheduled'),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  // ── Cancel ───────────────────────────────────────────────────
  static Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
    await _notifications.cancel(id + 10000);
  }

  static Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  // ── Check Overdue & Notify ───────────────────────────────────
  static Future<void> checkAndNotifyOverdue(List<TaskModel> tasks) async {
    final overdue  = tasks.where((t) => t.isOverdue).toList();
    final dueToday = tasks.where((t) => t.isDueToday && t.status != TaskStatus.done).toList();

    if (overdue.isNotEmpty) {
      await showNotification(
        id: 99999,
        title: '🔴 ${overdue.length} Overdue Task${overdue.length > 1 ? 's' : ''}!',
        body: overdue.map((t) => t.title).join(', '),
      );
    }
    if (dueToday.isNotEmpty) {
      await showNotification(
        id: 99998,
        title: '📅 ${dueToday.length} Task${dueToday.length > 1 ? 's' : ''} Due Today!',
        body: dueToday.map((t) => t.title).join(', '),
      );
    }
  }
}
