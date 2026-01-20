import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'utils/constants.dart';
import 'services/supabase_service.dart';
import 'auth/login_screen.dart';
import 'feed/feed_screen.dart';
import 'feed/create_post_screen.dart';
import 'friends/friends_screen.dart';
import 'notifications/notifications_screen.dart';
import 'menu/menu_screen.dart';
import 'search/search_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
  );

  // Load current user profile into cache
  await SupabaseService.refreshCurrentProfile();

  runApp(const FacebookCloneApp());
}

class FacebookCloneApp extends StatelessWidget {
  const FacebookCloneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Facebook Clone',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: AppConstants.primaryColor,
        scaffoldBackgroundColor: AppConstants.scaffoldBackgroundColor,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.black),
          titleTextStyle: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppConstants.primaryColor,
            foregroundColor: Colors.white,
          ),
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

/// AuthWrapper checks if the user is already logged in or not.
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _isLoggedIn = SupabaseService.session != null;

    SupabaseService.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.signedIn) {
        setState(() => _isLoggedIn = true);
      } else if (event == AuthChangeEvent.signedOut) {
        setState(() => _isLoggedIn = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoggedIn) {
      return const MainContainer();
    } else {
      return const LoginScreen();
    }
  }
}

/// MainContainer with Facebook-style 5-tab bottom navigation
class MainContainer extends StatefulWidget {
  const MainContainer({super.key});

  @override
  State<MainContainer> createState() => _MainContainerState();
}

class _MainContainerState extends State<MainContainer> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'facebook',
            style: TextStyle(
              color: AppConstants.primaryColor,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: -1.2,
            ),
          ),
          actions: [
            _CircleAction(
              icon: Icons.search,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              ),
            ),
            const SizedBox(width: 8),
            _CircleAction(icon: Icons.messenger_outline),
            const SizedBox(width: 12),
          ],
          bottom: TabBar(
            labelColor: AppConstants.primaryColor,
            unselectedLabelColor: Colors.grey[600],
            indicatorColor: AppConstants.primaryColor,
            indicatorWeight: 3,
            labelPadding: EdgeInsets.zero,
            tabs: const [
              Tab(icon: Icon(Icons.home, size: 28)),
              Tab(icon: Icon(Icons.people_outline, size: 28)),
              Tab(icon: Icon(Icons.notifications_none, size: 28)),
              Tab(icon: Icon(Icons.menu, size: 28)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            FeedScreen(),
            FriendsScreen(),
            NotificationsScreen(),
            MenuScreen(),
          ],
        ),
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _CircleAction({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[200],
          shape: BoxShape.circle,
        ),
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 22, color: Colors.black87),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final bool isActive;
  final VoidCallback onTap;
  final bool isCenter;
  final int? badgeCount;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.isActive,
    required this.onTap,
    this.isCenter = false,
    this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: isCenter ? const EdgeInsets.all(4) : EdgeInsets.zero,
                  decoration: isCenter
                      ? BoxDecoration(
                          color: AppConstants.primaryColor.withAlpha(25),
                          shape: BoxShape.circle,
                        )
                      : null,
                  child: Icon(
                    isActive ? activeIcon : icon,
                    size: isCenter ? 32 : 28,
                    color: isActive ? AppConstants.primaryColor : Colors.grey[600],
                  ),
                ),
                if (badgeCount != null && badgeCount! > 0)
                  Positioned(
                    right: -6,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$badgeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (isActive && !isCenter)
              Container(
                margin: const EdgeInsets.only(top: 4),
                height: 3,
                width: 28,
                decoration: BoxDecoration(
                  color: AppConstants.primaryColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
