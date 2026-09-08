import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_state.dart';
import 'screens/login_screen.dart';
import 'screens/map_screen.dart';
import 'screens/campaigns_screen.dart';
import 'screens/leaderboard_screen.dart';
import 'screens/activity_feed_screen.dart';
import 'screens/player_profile_screen.dart';
import 'screens/club_screen.dart';
import 'screens/user_guide_screen.dart';
import 'widgets/welcome_tour_dialog.dart';

/// Entry point of the mobile application.
/// Sets up the [AppState] ChangeNotifierProvider at the top level.
void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const FitTerraApp(),
    ),
  );
}

/// The root Widget of the FitTerra app.
///
/// [Why] Initializes global styling parameters, color themes, fonts, and Material3 configuration.
class FitTerraApp extends StatelessWidget {
  const FitTerraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TRION',
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

/// An authentication wrapper checking the active login state.
///
/// [Why] Routes anonymous users to the sign-in forms while logged-in users 
/// go directly to the primary tab dashboard.
class AuthenticationWrapper extends StatelessWidget {
  const AuthenticationWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    return state.isLoggedIn ? const MainTabNavigation() : const LoginScreen();
  }
}

/// Core tab-based shell widget containing the primary application navigation.
///
/// [Why] Renders bottom navigation tabs and the side navigation drawer containing club info.
class MainTabNavigation extends StatefulWidget {
  const MainTabNavigation({super.key});

  @override
  State<MainTabNavigation> createState() => _MainTabNavigationState();
}

class _MainTabNavigationState extends State<MainTabNavigation> {
  final List<Widget> _screens = const [
    MapScreen(),
    CampaignsScreen(),
    LeaderboardScreen(),
    ActivityFeedScreen(),
    PlayerProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        WelcomeTourDialog.showIfFirstTime(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);

    return Scaffold(
      body: IndexedStack(
        index: state.currentTab,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: state.currentTab,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFFE040FB),
        unselectedItemColor: Colors.grey.shade600,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 0.5),
        unselectedLabelStyle: const TextStyle(fontSize: 9),
        onTap: (index) {
          state.setTab(index);
          
          // Pull updates depending on selected tab
          if (index == 1) {
            state.fetchCampaigns();
            state.fetchMyCampaigns();
          } else if (index == 2) {
            state.fetchLeaderboard();
          } else if (index == 3) {
            state.fetchEvents();
            state.fetchActivities();
          } else if (index == 4) {
            state.fetchProgression();
            state.fetchMissions();
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map, color: Color(0xFFE040FB)),
            label: 'MAP',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.track_changes_outlined),
            activeIcon: Icon(Icons.track_changes, color: Color(0xFFE040FB)),
            label: 'CAMPAIGNS',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.emoji_events_outlined),
            activeIcon: Icon(Icons.emoji_events, color: Color(0xFFE040FB)),
            label: 'LEADERS',
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
              ListTile(
                leading: const Icon(Icons.track_changes, color: Color(0xFFE040FB)),
                title: const Text('Campaigns & Challenges', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                subtitle: const Text('Awareness runs, marathons & charity', style: TextStyle(fontSize: 10, color: Colors.grey)),
                onTap: () {
                  Navigator.pop(context); // Close drawer
                  state.setTab(1); // Switch to Campaigns tab
                },
              ),
              ListTile(
                leading: const Icon(Icons.groups, color: Color(0xFFE040FB)),
                title: const Text('Clubs', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                onTap: () {
                  Navigator.pop(context); // Close drawer
                  state.fetchMyClub(); // Pre-fetch club details
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ClubScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.menu_book, color: Color(0xFFE040FB)),
                title: const Text('Field Manual & Guide', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                subtitle: const Text('Game rules, H3 grid, and sieges', style: TextStyle(fontSize: 10, color: Colors.grey)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const UserGuideScreen()),
                  );
                },
              ),
              
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
