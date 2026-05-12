import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/notification_service.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/lobby_screen.dart';
import 'screens/leaderboard_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/game_screen.dart';
import 'screens/waiting_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait mode
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set status bar style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Notification service init (FCM + Local Notifications)
  await NotificationService.init();

  runApp(const JankenApp());
}

class JankenApp extends StatelessWidget {
  const JankenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JANKEN – RPS Battle Arena',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return _fadeRoute(const SplashScreen(), settings);
          case '/login':
            return _slideRoute(const LoginScreen(), settings);
          case '/lobby':
            return _fadeRoute(const LobbyScreen(), settings);
          case '/leaderboard':
            return _fadeRoute(const LeaderboardScreen(), settings);
          case '/profile':
            return _fadeRoute(const ProfileScreen(), settings);
          case '/game':
            return _slideRoute(const GameScreen(), settings,
                direction: AxisDirection.up);
          case '/waiting':
            return _slideRoute(const WaitingScreen(), settings);
          default:
            return _fadeRoute(const SplashScreen(), settings);
        }
      },
    );
  }

  PageRoute _fadeRoute(Widget page, RouteSettings settings) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  PageRoute _slideRoute(Widget page, RouteSettings settings,
      {AxisDirection direction = AxisDirection.left}) {
    Offset begin;
    switch (direction) {
      case AxisDirection.up:
        begin = const Offset(0, 1);
        break;
      case AxisDirection.left:
        begin = const Offset(1, 0);
        break;
      default:
        begin = const Offset(1, 0);
    }
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween<Offset>(begin: begin, end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
      transitionDuration: const Duration(milliseconds: 350),
    );
  }
}
