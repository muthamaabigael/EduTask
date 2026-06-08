import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/task_service.dart';
import '../theme/app_theme.dart';
import '../widgets/top_alert.dart';
import '../widgets/loading_indicator.dart';
import 'add_task_screen.dart';
import 'edit_tasks_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _email = '';
  String _firstName = '';
  String _lastName = '';
  String _profileImagePath = '';
  bool _isLoading = true;
  int _selectedIndex = 0;
  int _notificationCount = 0;
  List<Task> _tasks = [];

  // Calendar state
  late DateTime _currentMonth;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
    _selectedDate = DateTime.now();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = await AuthService.instance.getRegisteredUser();
    final tasks = await TaskService.instance.getTasks();
    await NotificationService.instance.ensureInitialNotifications();
    final notifications = await NotificationService.instance.getNotifications();
    if (!mounted) return;

    setState(() {
      _email = user['email'] ?? '';
      _firstName = user['firstName'] ?? '';
      _lastName = user['lastName'] ?? '';
      _profileImagePath = user['profileImagePath'] ?? '';
      _tasks = tasks;
      _notificationCount = notifications.where((notification) => !notification.isRead).length;
      _isLoading = false;
    });
  }

  void _openEditTasks() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const EditTasksScreen()),
    );

    if (!mounted) return;
    _loadData();
  }

  void _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );

    final notifications = await NotificationService.instance.getNotifications();
    if (!mounted) return;

    setState(() {
      _notificationCount = notifications.where((notification) => !notification.isRead).length;
    });
  }

  Future<void> _pickProfileImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 85,
    );

    if (pickedFile == null) return;

    final directory = await getApplicationDocumentsDirectory();
    final extension = pickedFile.path.split('.').last;
    final savedFile = await File(pickedFile.path).copy(
      '${directory.path}/profile_${DateTime.now().millisecondsSinceEpoch}.$extension',
    );

    await AuthService.instance.saveProfileImagePath(savedFile.path);
    if (!mounted) return;

    setState(() {
      _profileImagePath = savedFile.path;
    });

    showTopAlert(context, 'Profile photo updated.', success: true);
  }

  String get _greetingName {
    if (_firstName.isNotEmpty) return _firstName;
    if (_lastName.isNotEmpty) return _lastName;
    return 'Friend';
  }

  String get _greetingTime {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning!';
    if (hour < 17) return 'Good Afternoon!';
    return 'Good Evening!';
  }

  // ── Calendar helpers ──────────────────────────────────────────────────────

  int get _daysInMonth =>
      DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;

  /// Weekday of the 1st (1=Mon … 7=Sun); we map to 0-based Sunday-first grid.
  int get _firstWeekdayOffset {
    final wd = DateTime(_currentMonth.year, _currentMonth.month, 1).weekday;
    // weekday: Mon=1…Sun=7 → Sunday-first offset: Sun=0, Mon=1 … Sat=6
    return wd % 7;
  }

  void _previousMonth() => setState(() {
        _currentMonth =
            DateTime(_currentMonth.year, _currentMonth.month - 1);
      });

  void _nextMonth() => setState(() {
        _currentMonth =
            DateTime(_currentMonth.year, _currentMonth.month + 1);
      });

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2563EB), Color(0xFFEFF3FF)],
            stops: [0.0, 0.55],
          ),
        ),
        child: _isLoading
            ? const Center(child: LoadingIndicator())
            : SafeArea(
                child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildLogo(),
                          const SizedBox(height: 20),
                          _buildGreetingRow(),
                          const SizedBox(height: 16),
                          _buildSearchBar(),
                          const SizedBox(height: 24),
                          _buildCalendarCard(),
                          const SizedBox(height: 24),
                          _buildUpcomingSection(),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                  _buildBottomBar(context),
                ],
              ),
            ),
          ),
        );
  }

  // ── Logo ──────────────────────────────────────────────────────────────────

  Widget _buildLogo() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Image.asset(
            'assets/images/logo.png',
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.menu_book,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: 8),
        RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'Edu',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              TextSpan(
                text: 'Task',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFF97316),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Greeting row ──────────────────────────────────────────────────────────

  Widget _buildGreetingRow() {
    return Row(
      children: [
        GestureDetector(
          onTap: _pickProfileImage,
          child: CircleAvatar(
            radius: 26,
            backgroundColor: const Color(0xFFD1D5DB),
            backgroundImage: _profileImagePath.isNotEmpty
                ? FileImage(File(_profileImagePath))
                : null,
            child: _profileImagePath.isEmpty
                ? const Icon(Icons.person, size: 28, color: Colors.white)
                : null,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                  children: [
                    const TextSpan(
                      text: 'Hello, ',
                      style: TextStyle(color: Color(0xFF1E293B)),
                    ),
                    TextSpan(
                      text: _greetingName,
                      style: const TextStyle(color: Color(0xFF2563EB)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _greetingTime,
                style: const TextStyle(
                    fontSize: 14, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 6),
              Text(
                _email,
                style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: _openNotifications,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    const BoxShadow(
                      color: Color.fromRGBO(0, 0, 0, 0.06),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.notifications_none,
                    color: Color(0xFF1E293B), size: 22),
              ),
              if (_notificationCount > 0)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: Color(0xFF2563EB),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        _notificationCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Search bar ────────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          const BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.04),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: const [
          Icon(Icons.search, color: Color(0xFF94A3B8), size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Search',
              style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  // ── Full monthly calendar ─────────────────────────────────────────────────

  Widget _buildCalendarCard() {
    final monthName = _monthName(_currentMonth.month);
    final year = _currentMonth.year;
    final today = DateTime.now();
    final offset = _firstWeekdayOffset; // 0=Sun … 6=Sat
    final totalCells = offset + _daysInMonth;
    final rows = (totalCells / 7).ceil();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          const BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.04),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Month navigation header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Calendar',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B)),
              ),
              Row(
                children: [
                  GestureDetector(
                    onTap: _previousMonth,
                    child: const Icon(Icons.chevron_left,
                        color: Color(0xFF64748B)),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$monthName $year',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: _nextMonth,
                    child: const Icon(Icons.chevron_right,
                        color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Day-of-week headers
          Row(
            children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                .map(
                  (d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),

          // Date grid
          ...List.generate(rows, (rowIdx) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: List.generate(7, (colIdx) {
                  final cellIdx = rowIdx * 7 + colIdx;
                  final day = cellIdx - offset + 1;

                  if (day < 1 || day > _daysInMonth) {
                    return const Expanded(child: SizedBox(height: 40));
                  }

                  final date = DateTime(
                      _currentMonth.year, _currentMonth.month, day);
                  final isToday = date.year == today.year &&
                      date.month == today.month &&
                      date.day == today.day;
                  final isSelected = _selectedDate != null &&
                      date.year == _selectedDate!.year &&
                      date.month == _selectedDate!.month &&
                      date.day == _selectedDate!.day;

                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedDate = date),
                      child: Container(
                        height: 40,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF2563EB)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            '$day',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isToday || isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected
                                  ? Colors.white
                                  : isToday
                                      ? const Color(0xFFF97316)
                                      : const Color(0xFF1E293B),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Upcoming events ───────────────────────────────────────────────────────

  Widget _buildUpcomingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Upcoming Event',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B)),
            ),
            Text(
              'See All',
              style: TextStyle(
                  color: Colors.blue.shade700, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_tasks.isEmpty)
          _taskCard(
            title: 'No upcoming tasks yet.',
            subtitle: 'Tap + to create your first task.',
          )
        else
          ..._tasks.map((task) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _taskCard(
                  title: task.name,
                  subtitle: task.category,
                ),
              )),
      ],
    );
  }

  Widget _taskCard({required String title, required String subtitle}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF3FF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios,
              size: 16, color: Color(0xFF94A3B8)),
        ],
      ),
    );
  }

  // ── Bottom navigation bar ─────────────────────────────────────────────────

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.06),
            blurRadius: 12,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 30),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _navItem(Icons.home_rounded, 'Home', 0),
          _navItem(Icons.edit_outlined, 'Edit', 1),
          _navItemAdd(context),
          _navItem(Icons.notifications_none, 'Alerts', 3),
          _navItem(Icons.person_outline, 'Profile', 4),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;

    VoidCallback? onTap;
    if (index == 0) {
      onTap = () => setState(() => _selectedIndex = 0);
    } else if (index == 1) {
      onTap = _openEditTasks;
    } else if (index == 3) {
      onTap = _openNotifications;
    } else if (index == 4) {
      onTap = () {
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const ProfileScreen()))
            .then((_) {
          if (!mounted) return;
          _loadData();
          setState(() => _selectedIndex = 0);
        });
      };
    }

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 26,
              color: isSelected
                  ? const Color(0xFF2563EB)
                  : const Color(0xFF94A3B8)),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight:
                  isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected
                  ? const Color(0xFF2563EB)
                  : const Color(0xFF94A3B8),
            ),
          ),
          if (isSelected)
            Container(
              margin: const EdgeInsets.only(top: 4),
              width: 20,
              height: 3,
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }

  /// The circular blue "+" add button in the center of the bottom bar
  Widget _navItemAdd(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const AddTaskScreen()))
            .then((_) {
          if (!mounted) return;
          _loadData();
          setState(() => _selectedIndex = 0);
        });
      },
      child: Container(
        width: 52,
        height: 52,
        decoration: const BoxDecoration(
          color: Color(0xFF2563EB),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color(0x402563EB),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child:
            const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _monthName(int month) {
    const names = [
      'January', 'February', 'March', 'April',
      'May', 'June', 'July', 'August',
      'September', 'October', 'November', 'December',
    ];
    return names[month - 1];
  }
}