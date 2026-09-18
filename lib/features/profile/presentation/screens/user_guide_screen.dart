import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile/app_state.dart';

/// Comprehensive User Guide and Tactical Field Manual Screen.
///
/// [Why] Provides players with an in-depth, professional game manual explaining 
/// all gameplay mechanics (GPS loops, H3 hex grid, DP/Sieges, Clubs, Challenges, Offline Sync, Store).
class UserGuideScreen extends StatefulWidget {
  final bool isFirstTime;

  const UserGuideScreen({super.key, this.isFirstTime = false});

  @override
  State<UserGuideScreen> createState() => _UserGuideScreenState();
}

class _UserGuideScreenState extends State<UserGuideScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedCategoryIndex = 0;

  final List<Map<String, dynamic>> _categories = [
    {'title': 'GPS & LOOPS', 'icon': Icons.radar, 'color': Color(0xFFE040FB)},
    {'title': 'DEFENSE & SIEGES', 'icon': Icons.shield_outlined, 'color': Color(0xFF00E5FF)},
    {'title': 'GUILDS & CLUBS', 'icon': Icons.groups_outlined, 'color': Color(0xFFFF007F)},
    {'title': 'CHALLENGES', 'icon': Icons.directions_run, 'color': Color(0xFF39FF14)},
    {'title': 'OFFLINE SYNC', 'icon': Icons.wifi_off_outlined, 'color': Color(0xFFFF9800)},
    {'title': 'XP & REWARDS', 'icon': Icons.military_tech_outlined, 'color': Color(0xFFFFD600)},
    {'title': 'BIOMETRICS', 'icon': Icons.fitness_center, 'color': Color(0xFF00B0FF)},
    {'title': 'FAQ & TIPS', 'icon': Icons.help_outline, 'color': Color(0xFF9C27B0)},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && mounted) {
        setState(() {
          _selectedCategoryIndex = _tabController.index;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        shape: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 1)),
        title: Column(
          children: [
            const Text(
              'TACTICAL FIELD MANUAL',
              style: TextStyle(
                color: Color(0xFF1E1E24),
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
                fontSize: 15,
              ),
            ),
            Text(
              'TRION SYSTEM v2.4 • AGENT GUIDE',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        centerTitle: true,
        leading: widget.isFirstTime
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
                onPressed: () => Navigator.pop(context),
              ),
        actions: [
          if (widget.isFirstTime)
            TextButton(
              onPressed: () async {
                await state.markUserGuideSeen(seen: true);
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text(
                'SKIP',
                style: TextStyle(color: Color(0xFFE040FB), fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // 1. Top Category Pill Carousel
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isSelected = _selectedCategoryIndex == index;
                  final Color catColor = cat['color'];

                  return GestureDetector(
                    onTap: () {
                      _tabController.animateTo(index);
                      setState(() => _selectedCategoryIndex = index);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? catColor.withOpacity(0.12) : const Color(0xFFF1F3F9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? catColor : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            cat['icon'],
                            size: 16,
                            color: isSelected ? catColor : Colors.grey.shade600,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            cat['title'],
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? catColor : Colors.grey.shade700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // 2. Tab Content Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildGpsAndLoopsTab(),
                _buildDefenseAndSiegesTab(),
                _buildGuildsAndClubsTab(),
                _buildChallengesTab(),
                _buildOfflineSyncTab(),
                _buildProgressionAndRewardsTab(),
                _buildBiometricsTab(),
                _buildFaqAndTipsTab(state),
              ],
            ),
          ),

          // 3. Bottom Action Bar / CTA
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                child: widget.isFirstTime
                    ? ElevatedButton.icon(
                        onPressed: () async {
                          await state.markUserGuideSeen(seen: true);
                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        },
                        icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                        label: const Text(
                          'I\'M READY TO CONQUER (ENTER MAP)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            fontSize: 13,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE040FB),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 4,
                        ),
                      )
                    : ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E1E24),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('CLOSE MANUAL', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 1: GPS & LOOPS ---
  Widget _buildGpsAndLoopsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeroCard(
            title: 'Territory GPS Loop Conquest',
            subtitle: 'Enclose real-world space to claim H3 hexagonal cells.',
            icon: Icons.radar,
            color: const Color(0xFFE040FB),
            badge: 'CORE GAMEPLAY',
          ),
          const SizedBox(height: 16),

          _buildStepCard(
            stepNumber: '1',
            title: 'Select Sport & Start Recording',
            description: 'Choose your activity type (Walk, Run, or Cycle) on the Map screen and tap START. The GPS hardware engine begins logging your real-time path coordinates.',
            color: const Color(0xFFE040FB),
          ),
          const SizedBox(height: 12),

          _buildStepCard(
            stepNumber: '2',
            title: 'Walk in a Closed Loop (30-Meter Rule)',
            description: 'Navigate around city blocks or parks to form a polygon. To trigger a Loop Closure, your current position must return within 30 meters of your workout starting coordinate.',
            color: const Color(0xFFE040FB),
            highlight: '★ Rule: The map line turns bright glowing Green once a closed loop is completed!',
          ),
          const SizedBox(height: 12),

          _buildStepCard(
            stepNumber: '3',
            title: 'Uber H3 Hexagonal Grid Claiming',
            description: 'The server divides the Earth into Resolution 9 hexagonal cells (~100m diameter). All unoccupied hexagons fully enclosed inside your loop path become your claimed territory!',
            color: const Color(0xFFE040FB),
          ),
          const SizedBox(height: 12),

          _buildInfoCallout(
            title: 'Loop Pro-Tip',
            message: 'Avoid crossing your own path in figure-8s; simple convex loops yield the highest territory area score!',
            icon: Icons.lightbulb_outline,
            color: const Color(0xFFE040FB),
          ),
        ],
      ),
    );
  }

  // --- TAB 2: DEFENSE & SIEGES ---
  Widget _buildDefenseAndSiegesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeroCard(
            title: 'Territory Defense & Rival Sieges',
            subtitle: 'Guard your borders or conquer enemy sectors through physical movement.',
            icon: Icons.shield_outlined,
            color: const Color(0xFF00E5FF),
            badge: 'BATTLE MECHANICS',
          ),
          const SizedBox(height: 16),

          _buildDetailCard(
            title: 'Defense Points (DP)',
            description: 'Each newly claimed territory starts with 100 Defense Points (DP). DP represents the resilience of your sector against competing players.',
            icon: Icons.health_and_safety_outlined,
            color: const Color(0xFF00E5FF),
          ),
          const SizedBox(height: 12),

          _buildDetailCard(
            title: 'Enemy Sieges & Invasions',
            description: 'When an opponent runner records a route inside your territory, they initiate a Siege, damaging your sector\'s DP. If DP reaches 0, the territory is conquered by the attacker!',
            icon: Icons.local_fire_department_outlined,
            color: const Color(0xFFFF3D00),
          ),
          const SizedBox(height: 12),

          _buildDetailCard(
            title: 'Territory Energy Decay',
            description: 'Territories lose 5 DP per day if left neglected. Regularly running through your own zones repairs and fortifies their DP back to maximum!',
            icon: Icons.trending_down,
            color: const Color(0xFFFF9800),
          ),
          const SizedBox(height: 12),

          _buildInfoCallout(
            title: 'Defense Strategy',
            message: 'Join a Club! Teammates stationed near your zone will automatically assist in fortifying and defending shared territory borders.',
            icon: Icons.security,
            color: const Color(0xFF00E5FF),
          ),
        ],
      ),
    );
  }

  // --- TAB 3: GUILDS & CLUBS ---
  Widget _buildGuildsAndClubsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeroCard(
            title: 'Clubs & Guild Warfare',
            subtitle: 'Unite with other runners to form global athletic syndicates.',
            icon: Icons.groups_outlined,
            color: const Color(0xFFFF007F),
            badge: 'CO-OP MULTIPLAYER',
          ),
          const SizedBox(height: 16),

          _buildStepCard(
            stepNumber: '1',
            title: 'Club Creation Requirements',
            description: 'Reach Level 10 and spend 500 XP to establish a new Club. Choose a unique guild name, handle (@guildname), and description.',
            color: const Color(0xFFFF007F),
          ),
          const SizedBox(height: 12),

          _buildStepCard(
            stepNumber: '2',
            title: 'Invite Codes & Roster Caps',
            description: 'Every club receives a 6-character Invite Code (e.g. CW7K92). Share your code with friends to let them join your roster instantly.',
            color: const Color(0xFFFF007F),
          ),
          const SizedBox(height: 12),

          _buildDetailCard(
            title: 'Guild Leadership Roles',
            description: '• Leader: Full control, can promote officers, transfer ownership, or disband.\n• Officer: Can recruit members and manage roster kicks.\n• Member: Contributes workout XP and shared defense.',
            icon: Icons.military_tech,
            color: const Color(0xFFFF007F),
          ),
          const SizedBox(height: 12),

          _buildInfoCallout(
            title: 'Club XP Milestones',
            message: 'Every kilometer logged by any guild member adds to the Club\'s XP pool, unlocking higher member caps and guild defense bonuses.',
            icon: Icons.stars_outlined,
            color: const Color(0xFFFF007F),
          ),
        ],
      ),
    );
  }

  // --- TAB 4: CHALLENGES ---
  Widget _buildChallengesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeroCard(
            title: 'Route Challenges & Social Racing',
            subtitle: 'Challenge friends to race against your recorded route telemetry.',
            icon: Icons.directions_run,
            color: const Color(0xFF39FF14),
            badge: 'HEAD-TO-HEAD',
          ),
          const SizedBox(height: 16),

          _buildStepCard(
            stepNumber: '1',
            title: 'Send Challenge from Activity Logs',
            description: 'Head to the Feed tab, tap on any completed workout, and click "CHALLENGE A FRIEND" to select a friend from your roster.',
            color: const Color(0xFF39FF14),
          ),
          const SizedBox(height: 12),

          _buildStepCard(
            stepNumber: '2',
            title: 'Accept & Race Against Ghost Pace',
            description: 'Recipients receive a challenge invitation card under Profile > Friends. Tapping ACCEPT allows them to run the exact route against your completion time!',
            color: const Color(0xFF39FF14),
          ),
          const SizedBox(height: 12),

          _buildDetailCard(
            title: 'Weekly Progression Analytics',
            description: 'Monitor your cumulative 7-day volume on the Game Feed chart to ensure consistent athletic progression and challenge readiness.',
            icon: Icons.bar_chart,
            color: const Color(0xFF39FF14),
          ),
        ],
      ),
    );
  }

  // --- TAB 5: OFFLINE SYNC ---
  Widget _buildOfflineSyncTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeroCard(
            title: 'Zero Data Loss Offline Engine',
            subtitle: 'Exercise anywhere with 100% telemetry persistence, even without cellular service.',
            icon: Icons.wifi_off_outlined,
            color: const Color(0xFFFF9800),
            badge: 'OFFLINE RESILIENCE',
          ),
          const SizedBox(height: 16),

          _buildDetailCard(
            title: 'Continuous Disk Caching',
            description: 'Every GPS coordinate point, elapsed second, and distance calculation is serialized to device flash storage in real-time.',
            icon: Icons.save_outlined,
            color: const Color(0xFFFF9800),
          ),
          const SizedBox(height: 12),

          _buildDetailCard(
            title: 'Automatic Session Recovery',
            description: 'If your phone restarts or the app process is closed during a run, TRION automatically restores your active session upon relaunch!',
            icon: Icons.restore,
            color: const Color(0xFFFF9800),
          ),
          const SizedBox(height: 12),

          _buildDetailCard(
            title: 'Offline Submission Queue',
            description: 'If you complete a workout while offline, your route & loop are queued securely on-device. An Offline Banner appears with a "SYNC NOW" button that auto-syncs when reconnected.',
            icon: Icons.sync,
            color: const Color(0xFFFF9800),
          ),
          const SizedBox(height: 12),

          _buildInfoCallout(
            title: 'Never Lose a Loop',
            message: 'You can finish long workouts in deep trails with zero cell reception—your territory claims will register the moment you reconnect!',
            icon: Icons.check_circle_outline,
            color: const Color(0xFFFF9800),
          ),
        ],
      ),
    );
  }

  // --- TAB 6: XP & REWARDS ---
  Widget _buildProgressionAndRewardsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeroCard(
            title: 'XP Leveling & Store Rewards',
            subtitle: 'Convert physical sweat into levels, coins, and real-world fitness rewards.',
            icon: Icons.military_tech_outlined,
            color: const Color(0xFFFFD600),
            badge: 'PROGRESSION',
          ),
          const SizedBox(height: 16),

          _buildDetailCard(
            title: 'Level Formula: XP = Level × 1000',
            description: 'Gain XP by logging distance, closing loops, and defending territory. Each level increases your territory defense capabilities and prestige.',
            icon: Icons.star_outline,
            color: const Color(0xFFFFD600),
          ),
          const SizedBox(height: 12),

          _buildDetailCard(
            title: 'TRION Coins Currency',
            description: 'Earn Coins proportional to the square meters (m²) of territory captured. Coins can be spent in the Rewards Store on exclusive gear.',
            icon: Icons.monetization_on_outlined,
            color: const Color(0xFFFFD600),
          ),
          const SizedBox(height: 12),

          _buildDetailCard(
            title: 'Global Leaderboards & Podiums',
            description: 'Compete for the #1 Gold, #2 Silver, and #3 Bronze podium spots ranked by cumulative territory owned across the world.',
            icon: Icons.emoji_events_outlined,
            color: const Color(0xFFFFD600),
          ),
        ],
      ),
    );
  }

  // --- TAB 7: BIOMETRICS ---
  Widget _buildBiometricsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeroCard(
            title: 'Biometrics & Caloric Analytics',
            subtitle: 'Personalized health tracking and customized neon player styling.',
            icon: Icons.fitness_center,
            color: const Color(0xFF00B0FF),
            badge: 'HEALTH & THEMES',
          ),
          const SizedBox(height: 16),

          _buildDetailCard(
            title: 'MET Calorie Calculation Formula',
            description: 'Caloric expenditure is dynamically calculated using your Weight (kg), Height (cm), Age, and activity MET intensity (Walking = 3.5 MET, Running = 9.8 MET, Cycling = 7.5 MET).',
            icon: Icons.calculate_outlined,
            color: const Color(0xFF00B0FF),
          ),
          const SizedBox(height: 12),

          _buildDetailCard(
            title: '6 Custom Map Neon Theme Colors',
            description: 'Choose your signature neon player color in Edit Profile (Violet, Pink, Cyan, Green, Yellow, Orange-Red). Your claimed territories glow in your custom color on the map!',
            icon: Icons.palette_outlined,
            color: const Color(0xFF00B0FF),
          ),
        ],
      ),
    );
  }

  // --- TAB 8: FAQ & SETTINGS ---
  Widget _buildFaqAndTipsTab(AppState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeroCard(
            title: 'Frequently Asked Questions & Tips',
            subtitle: 'Troubleshooting guide and user guide display settings.',
            icon: Icons.help_outline,
            color: const Color(0xFF9C27B0),
            badge: 'HELP CENTER',
          ),
          const SizedBox(height: 16),

          _buildFaqItem(
            question: 'Why did my loop not close?',
            answer: 'To close a loop, you must return within 30 meters of your start location. Make sure GPS accuracy is high and you walk in a complete convex circle or polygon.',
          ),
          const SizedBox(height: 10),

          _buildFaqItem(
            question: 'What happens if my phone dies during a run?',
            answer: 'TRION saves your path to disk continuously. Once you recharge and open the app, your workout session automatically resumes where you left off!',
          ),
          const SizedBox(height: 10),

          _buildFaqItem(
            question: 'How do I claim a territory owned by someone else?',
            answer: 'Record a run passing directly through their hexagonal sector. Each pass inflicts siege damage on their Defense Points (DP). When their DP hits 0, the zone is conquered by you!',
          ),
          const SizedBox(height: 10),

          _buildFaqItem(
            question: 'How do I unlock Clubs?',
            answer: 'Reach Level 10 and accumulate 500 XP to found a new Club, or ask an existing club leader for their 6-character Invite Code to join immediately.',
          ),
          const SizedBox(height: 20),

          // Settings Controls Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'GUIDE PREFERENCES',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.0),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Show Tactical Guide on First Launch', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Toggle whether the guide pops up automatically for new sessions.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  value: !state.hasSeenUserGuide,
                  activeColor: const Color(0xFFE040FB),
                  onChanged: (val) {
                    state.markUserGuideSeen(seen: !val);
                  },
                ),
                const Divider(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Show Welcome Onboarding on Sign Out', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Displays introductory slides on the login screen when signed out.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  value: !state.hasSeenWelcomeOnboarding,
                  activeColor: const Color(0xFFE040FB),
                  onChanged: (val) {
                    state.markWelcomeOnboardingSeen(seen: !val);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- REUSABLE UI BUILDERS ---

  Widget _buildHeroCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String badge,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.15), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.0),
                ),
              ),
              Icon(icon, color: color, size: 28),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1E1E24)),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard({
    required String stepNumber,
    required String title,
    required String description,
    required Color color,
    String? highlight,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              stepNumber,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E1E24)),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.4),
                ),
                if (highlight != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Text(
                      highlight,
                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E1E24)),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCallout({
    required String title,
    required String message,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: TextStyle(color: Colors.grey.shade800, fontSize: 11, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaqItem({required String question, required String answer}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ExpansionTile(
        title: Text(
          question,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E1E24)),
        ),
        iconColor: const Color(0xFFE040FB),
        collapsedIconColor: Colors.grey,
        childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            answer,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.4),
          ),
        ],
      ),
    );
  }
}
