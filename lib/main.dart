import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_state.dart';
import 'screens/login_screen.dart';
import 'screens/map_screen.dart';
import 'screens/leaderboard_screen.dart';
import 'screens/activity_feed_screen.dart';
import 'screens/player_profile_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const FitTerraApp(),
    ),
  );
}

class FitTerraApp extends StatelessWidget {
  const FitTerraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FitTerra',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: const Color(0xFFE040FB),
        scaffoldBackgroundColor: const Color(0xFFF5F5F7),
        fontFamily: 'Roboto', // Custom premium look fallback
        colorScheme: const ColorScheme.light(
          primary: Color(0xFFE040FB), // Neon Violet
          secondary: Color(0xFF00E5FF), // Neon Cyan
          surface: Colors.white,
        ),
        useMaterial3: true,
      ),
      home: const AuthenticationWrapper(),
    );
  }
}

class AuthenticationWrapper extends StatelessWidget {
  const AuthenticationWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    return state.isLoggedIn ? const MainTabNavigation() : const LoginScreen();
  }
}

class MainTabNavigation extends StatefulWidget {
  const MainTabNavigation({super.key});

  @override
  State<MainTabNavigation> createState() => _MainTabNavigationState();
}

class _MainTabNavigationState extends State<MainTabNavigation> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    MapScreen(),
    LeaderboardScreen(),
    ActivityFeedScreen(),
    PlayerProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFFE040FB),
        unselectedItemColor: Colors.grey.shade600,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5),
        unselectedLabelStyle: const TextStyle(fontSize: 10),
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          
          // Pull updates depending on selected tab
          if (index == 1) {
            state.fetchLeaderboard();
          } else if (index == 2) {
            state.fetchEvents();
          } else if (index == 3) {
            state.fetchProgression();
            state.fetchMissions();
            state.fetchAchievements();
            state.fetchRewards();
            state.fetchContributionHistory();
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map, color: Color(0xFFE040FB)),
            label: 'MAP',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.emoji_events_outlined),
            activeIcon: Icon(Icons.emoji_events, color: Color(0xFFE040FB)),
            label: 'LEADERBOARD',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.feed_outlined),
            activeIcon: Icon(Icons.feed, color: Color(0xFFE040FB)),
            label: 'FEED',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person, color: Color(0xFFE040FB)),
            label: 'PROFILE',
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drawer User Header
              Container(
                padding: const EdgeInsets.all(24),
                color: const Color(0xFFF5F5F7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: _parseColor(state.color),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          state.username ?? 'Explorer',
                          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      state.email ?? '',
                      style: const TextStyle(color: Colors.black54, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'TOTAL TERRITORY: ${state.totalTerritoryArea.toStringAsFixed(1)} m²',
                      style: const TextStyle(color: Color(0xFFE040FB), fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              const Spacer(),
              const Divider(color: Color(0xFFE040FB), thickness: 0.5),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: const Text('Exit Game', style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(context);
                  state.logout();
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Color _parseColor(String hex) {
    final clean = hex.replaceAll('#', '');
    return Color(int.parse('FF$clean', radix: 16));
  }
}
