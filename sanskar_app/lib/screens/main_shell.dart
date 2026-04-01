import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../services/ws_service.dart';
import '../widgets/live_announcement_banner.dart';
import 'home_screen.dart';
import 'schedule_screen.dart';
import 'media_gallery_screen.dart';
import 'chat_list_screen.dart';
import 'profile_screen.dart';

/// Bottom-navigation shell wrapping the main screens.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final _screens = const [
    HomeScreen(),
    ScheduleScreen(),
    MediaGalleryScreen(),
    ChatListScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Auto-connect WebSocket after login
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WsService>().connect();
    });
  }

  @override
  void dispose() {
    // Disconnect WS when leaving shell
    // (don't dispose provider—it's managed by MultiProvider)
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ws = context.watch<WsService>();

    return Scaffold(
      body: Column(
        children: [
          // Live announcement banner (slides in from top)
          LiveAnnouncementBanner(ws: ws),
          // Main content
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: SanskarTheme.softWhite,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(15),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  isSelected: _currentIndex == 0,
                  onTap: () => setState(() => _currentIndex = 0),
                ),
                _NavItem(
                  icon: Icons.calendar_month,
                  label: 'Schedule',
                  isSelected: _currentIndex == 1,
                  onTap: () => setState(() => _currentIndex = 1),
                ),
                _NavItem(
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery',
                  isSelected: _currentIndex == 2,
                  onTap: () => setState(() => _currentIndex = 2),
                ),
                _NavItem(
                  icon: Icons.chat_rounded,
                  label: 'Chat',
                  isSelected: _currentIndex == 3,
                  onTap: () => setState(() => _currentIndex = 3),
                ),
                _NavItem(
                  icon: Icons.person_rounded,
                  label: 'Profile',
                  isSelected: _currentIndex == 4,
                  onTap: () => setState(() => _currentIndex = 4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 14 : 10,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected ? SanskarTheme.saffron.withAlpha(18) : Colors.transparent,
          borderRadius: SanskarTheme.radiusMd,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? SanskarTheme.saffron : SanskarTheme.darkCharcoal.withAlpha(120),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? SanskarTheme.saffron : SanskarTheme.darkCharcoal.withAlpha(120),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
