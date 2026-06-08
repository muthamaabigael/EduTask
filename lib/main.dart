import 'package:flutter/material.dart';
import 'screens/landing_screen.dart';
import 'theme/app_theme.dart';
import 'services/notification_service.dart';
import 'services/task_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init();
  await NotificationService.instance.ensureInitialNotifications();
  // TaskService.instance.startScheduler();
  runApp(const EduTaskApp());
}

class EduTaskApp extends StatelessWidget {
  const EduTaskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'EduTask',
      theme: AppTheme.themeData,

      // First screen
      home: const LandingScreen(),
    );
  }
}
