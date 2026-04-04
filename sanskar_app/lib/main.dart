import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/theme.dart';
import 'services/auth_service.dart';
import 'services/ws_service.dart';
import 'models/event.dart';

import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'screens/schedule_screen.dart';
import 'screens/event_detail_screen.dart';
import 'screens/media_gallery_screen.dart';
import 'screens/guest_list_screen.dart';
import 'screens/announcements_screen.dart';
import 'screens/blessings_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/chat_list_screen.dart';
import 'screens/chat_conversation_screen.dart';
import 'screens/media_upload_screen.dart';
import 'screens/media_viewer_screen.dart';
import 'config/routes.dart';
import 'models/media_item.dart';
import 'screens/admin/admin_entry_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => WsService()),
      ],
      child: const SanskarUtsavApp(),
    ),
  );
}

class SanskarUtsavApp extends StatelessWidget {
  const SanskarUtsavApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sanskar Utsav — Shrihan\'s Yogyopaveet',
      debugShowCheckedModeBanner: false,
      theme: SanskarTheme.lightTheme,
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return _fade(const SplashScreen());
          case '/login':
            return _fade(const LoginScreen());
          case '/home':
            return _fade(const MainShell());
          case '/schedule':
            return _slide(const ScheduleScreen());
          case '/event':
            final event = settings.arguments as CeremonyEvent;
            return _slide(EventDetailScreen(event: event));
          case '/media':
            return _slide(const MediaGalleryScreen());
          case '/guests':
            return _slide(const GuestListScreen());
          case '/announcements':
            return _slide(const AnnouncementsScreen());
          case '/blessings':
            return _slide(const BlessingsScreen());
          case '/notifications':
            return _slide(const NotificationsScreen());
          case '/profile':
            return _slide(const ProfileScreen());
          case '/chat':
            return _slide(const ChatListScreen());
          case '/chat/conversation':
            final args = settings.arguments as Map<String, dynamic>;
            return _slide(ChatConversationScreen(
              roomId: args['room_id'],
              roomName: args['name'],
            ));
          case '/media/upload':
            return _slide(const MediaUploadScreen());
          case '/media/view':
            final item = settings.arguments as MediaItem;
            return _fade(MediaViewerScreen(item: item));
          case AppRoutes.adminDashboard:
            return _slide(const AdminEntryScreen());
          default:
            return _fade(const SplashScreen());
        }
      },
    );
  }

  /// Fade transition for root-level screens.
  PageRoute _fade(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  /// Slide transition for sub-screens.
  PageRoute _slide(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          )),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }
}
