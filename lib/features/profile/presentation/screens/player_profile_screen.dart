import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile/app_state.dart';
import 'package:mobile/shared/widgets/celebration_dialog.dart';
import 'edit_profile_screen.dart';
import 'user_guide_screen.dart';

/// Screen displaying the active player's level, progression XP meters, claimed area land metrics, and tab navigation.
///
/// [Why] Serves as the central user profile cockpit showing fitness statistics, 
/// achievements, pending invite challenges, and cosmetic store catalogs.
class PlayerProfileScreen extends StatefulWidget {
  const PlayerProfileScreen({super.key});

  @override
  State<PlayerProfileScreen> createState() => _PlayerProfileScreenState();
}

class _PlayerProfileScreenState extends State<PlayerProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _friendUsernameController = TextEditingController();
  String _selectedAchievementCategory = 'ALL';
  AppState? _appState;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _appState = Provider.of<AppState>(context, listen: false);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && mounted && _appState != null) {
        if (_tabController.index == 0) {
          _appState!.fetchMissions();
        } else if (_tabController.index == 1) {
          _appState!.fetchAchievements();
        } else if (_tabController.index == 2) {
          _appState!.fetchRewards();
        } else if (_tabController.index == 3) {
          _appState!.fetchFriends(force: true);
          _appState!.fetchPendingFriendRequests(force: true);
          _appState!.fetchSentFriendRequests(force: true);
          _appState!.fetchRouteInvitations(force: true);
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _appState != null) {
        _appState!.fetchFriends(force: true);
        _appState!.fetchPendingFriendRequests(force: true);
        _appState!.fetchSentFriendRequests(force: true);
        _appState!.fetchRouteInvitations(force: true);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _friendUsernameController.dispose();
    _appState = null;
    super.dispose();
  }

  /// Parses hex color strings into Color classes.
  Color _parseColor(String hex, {double opacity = 1.0}) {
    final clean = hex.replaceAll('#', '');
    try {
      final val = int.parse('FF$clean', radix: 16);
      return Color(val).withOpacity(opacity);
    } catch (_) {
      return Colors.pink.withOpacity(opacity);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);

    // Calculate XP progress percentage
    double xpProgress = 0.0;
    int currentXpInLevel = state.xp - state.xpRequiredForCurrentLevel;
    int totalXpNeededInLevel = state.xpRequiredForNextLevel - state.xpRequiredForCurrentLevel;
    if (totalXpNeededInLevel > 0) {
      xpProgress = (currentXpInLevel / totalXpNeededInLevel).clamp(0.0, 1.0);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        shape: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 1)),
        title: const Text(
          'PLAYER PROFILE',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_book, color: Color(0xFFE040FB)),
            tooltip: 'Tactical Field Manual',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const UserGuideScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.black87),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const EditProfileScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: () {
              state.fetchProgression();
              state.fetchMissions();
              state.fetchAchievements();
              state.fetchRewards();
              state.fetchContributionHistory();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () {
              state.logout();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Upper Profile Card (Light theme design)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey.shade200,
                  width: 1.5,
                ),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    // Level Circle
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            _parseColor(state.color),
                            const Color(0xFFE040FB),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        // boxShadow: [
                        //   BoxShadow(
                        //     color: _parseColor(state.color, opacity: 0.4),
                        //     blurRadius: 12,
                        //     spreadRadius: 2,
                        //   )
                        // ],
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'LVL',
                              style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${state.level}',
                              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),
                    // Username & Streak & Physical Stats
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            state.username?.toUpperCase() ?? 'EXPLORER',
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.orangeAccent, width: 1),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.local_fire_department, color: Colors.orangeAccent, size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${state.streak} DAY STREAK',
                                      style: const TextStyle(
                                        color: Colors.orangeAccent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.amber, width: 1),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.monetization_on, color: Colors.amber, size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${state.coins} COINS',
                                      style: const TextStyle(
                                        color: Colors.amber,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Age: ${state.age} • Height: ${state.height.toStringAsFixed(0)} cm • Weight: ${state.weight.toStringAsFixed(0)} kg • ${state.gender}',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 10.5,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                // XP Progress Bar
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'XP: $currentXpInLevel / $totalXpNeededInLevel',
                          style: const TextStyle(color: Colors.black87, fontSize: 11),
                        ),
                        Text(
                          'Total XP: ${state.xp}',
                          style: const TextStyle(color: Colors.black54, fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: xpProgress,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(_parseColor(state.color)),
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. Stats Grid
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatMiniCard('LAND', '${(state.totalTerritoryArea).toStringAsFixed(0)}m²', Icons.layers_outlined),
                _buildStatMiniCard('DEFENSE', '${state.territoriesDefended * 100}', Icons.shield_outlined),
                _buildStatMiniCard('CONTRIBUTION', '${state.contributionScore}', Icons.star_border),
              ],
            ),
          ),

          // 3. Navigation Tab Bar
          TabBar(
            controller: _tabController,
            indicatorColor: _parseColor(state.color),
            labelColor: Colors.black87,
            unselectedLabelColor: Colors.grey.shade600,
            labelPadding: const EdgeInsets.symmetric(horizontal: 4),
            labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            unselectedLabelStyle: const TextStyle(fontSize: 11),
            tabs: [
              const Tab(text: 'MISSIONS'),
              const Tab(text: 'BADGES'),
              const Tab(text: 'REWARDS'),
              Tab(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('FRIENDS'),
                      if (state.pendingFriendRequests.isNotEmpty || state.pendingRouteInvitations.isNotEmpty) ...[
                        const SizedBox(width: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${state.pendingFriendRequests.length + state.pendingRouteInvitations.length}',
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),

          // 4. Tab Contents
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMissionsTab(state),
                _buildAchievementsTab(state),
                _buildRewardsTab(state),
                _buildFriendsTab(state),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds standardized vertical label/value cards to present inside row headers.
  Widget _buildStatMiniCard(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFFE040FB), size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.black54, fontSize: 9, letterSpacing: 0.8),
        ),
      ],
    );
  }

  /// Builds the scrollable list of active daily and weekly quest missions.
  ///
  /// [Why] Lets players track daily fitness objectives and claim reward items.
  Widget _buildMissionsTab(AppState state) {
    final allMissions = [...state.dailyMissions, ...state.weeklyMissions];

    if (allMissions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.military_tech_outlined, color: Color(0xFF00E5FF), size: 48),
              ),
              const SizedBox(height: 20),
              const Text(
                'Missions Ready to Deploy',
                style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                'New daily and weekly tactical objectives will automatically refresh. Start tracking your activities on the map to complete goals!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF),
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  elevation: 1,
                ),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('REFRESH MISSIONS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.8)),
                onPressed: () {
                  state.fetchMissions(force: true);
                },
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: allMissions.length,
      itemBuilder: (ctx, idx) {
        final m = allMissions[idx];
        final isDaily = state.dailyMissions.contains(m);
        final completed = m.status == 'COMPLETED' || m.status == 'CLAIMED';
        double progressRatio = m.targetValue > 0 ? (m.progress / m.targetValue).clamp(0.0, 1.0) : 0.0;

        String displayProgress = m.targetType == 'DISTANCE' 
            ? '${(m.progress / 1000).toStringAsFixed(1)} / ${(m.targetValue / 1000).toStringAsFixed(0)} km'
            : '${m.progress.toStringAsFixed(0)} / ${m.targetValue.toStringAsFixed(0)}';

        return Card(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: completed ? Colors.green.withOpacity(0.4) : Colors.grey.shade200,
              width: 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => CelebrationDialog.showMission(context, mission: m),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        m.title,
                        style: TextStyle(
                          color: completed ? Colors.green.shade700 : Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDaily ? Colors.blue.withOpacity(0.15) : Colors.purple.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isDaily ? 'DAILY' : 'WEEKLY',
                          style: TextStyle(
                            color: isDaily ? Colors.blueAccent : Colors.purpleAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    m.description,
                    style: const TextStyle(color: Colors.black54, fontSize: 11),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        displayProgress,
                        style: const TextStyle(color: Colors.black87, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      if (completed)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade400, width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle, color: Colors.green.shade700, size: 13),
                              const SizedBox(width: 4),
                              Text('COMPLETED 🏆', style: TextStyle(color: Colors.green.shade800, fontSize: 10, fontWeight: FontWeight.w900)),
                            ],
                          ),
                        )
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progressRatio,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(completed ? Colors.green.shade600 : Colors.grey.shade400),
                      minHeight: 5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildRewardBadge('+${m.xpReward} XP', Colors.lightBlueAccent),
                      const SizedBox(width: 8),
                      _buildRewardBadge('+${m.coinReward} Coins', Colors.amber),
                      const SizedBox(width: 8),
                      _buildRewardBadge('+${m.contributionReward} CS', Colors.tealAccent),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Builds a tag-like badge overlay presenting XP/Coin reward parameters.
  Widget _buildRewardBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.5), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }

  /// Builds the 2-column grid displaying star trophy badge achievements.
  Widget _buildAchievementsTab(AppState state) {
    if (state.achievements.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD600).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.emoji_events_outlined, color: Color(0xFFFFD600), size: 48),
              ),
              const SizedBox(height: 20),
              const Text(
                'Unlock Star Trophies',
                style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                'Complete distance milestones, claim territory hexagons, and participate in campaigns to unlock Bronze, Silver, and Gold badges!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD600),
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  elevation: 1,
                ),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('CHECK MILESTONES', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.8)),
                onPressed: () {
                  state.fetchAchievements(force: true);
                },
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: state.achievements.length,
      itemBuilder: (ctx, idx) {
        final a = state.achievements[idx];
        final progressRatio = a.targetValue > 0 ? (a.progress / a.targetValue).clamp(0.0, 1.0) : 0.0;

        return Card(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: a.isUnlocked ? Colors.amber : Colors.grey.shade200,
              width: a.isUnlocked ? 1.5 : 1.0,
            ),
          ),
          child: InkWell(
            onTap: () => CelebrationDialog.showAchievement(context, achievement: a),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    a.isUnlocked ? Icons.stars : Icons.stars_outlined,
                    color: a.isUnlocked ? Colors.amber : Colors.grey.shade300,
                    size: 40,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    a.title,
                    style: TextStyle(
                      color: a.isUnlocked ? Colors.amber.shade800 : Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    a.description,
                    style: const TextStyle(color: Colors.black54, fontSize: 9),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  if (a.isUnlocked)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade400, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.stars, color: Colors.amber, size: 12),
                          SizedBox(width: 4),
                          Text(
                            'STAR BADGE ⭐',
                            style: TextStyle(
                              color: Color(0xFFD97706),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    Text(
                      '${a.progress.toStringAsFixed(0)} / ${a.targetValue.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progressRatio,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          a.isUnlocked ? Colors.amber : const Color(0xFFE040FB),
                        ),
                        minHeight: 4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Builds the cosmetics item catalog store list.
  ///
  /// [Why] Lets players unlock title banners and map color themes by spending coins.
  Widget _buildRewardsTab(AppState state) {
    if (state.rewards.isEmpty) {
      return const Center(
        child: Text('Cosmetics shop is empty.', style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: state.rewards.length,
      itemBuilder: (ctx, idx) {
        final r = state.rewards[idx];
        final levelMet = state.level >= r.unlockedAtLevel;
        final hasCoins = state.coins >= r.costInCoins;

        return Card(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: r.isClaimed ? Colors.pink.withOpacity(0.3) : Colors.grey.shade200,
              width: 1,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Icon(
              r.type == 'TITLE' ? Icons.title : Icons.palette,
              color: r.isClaimed ? _parseColor(state.color) : Colors.grey.shade400,
              size: 32,
            ),
            title: Text(
              r.title,
              style: TextStyle(
                color: r.isClaimed ? _parseColor(state.color) : Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.description, style: const TextStyle(color: Colors.black54, fontSize: 11)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'Req Lvl ${r.unlockedAtLevel}',
                      style: TextStyle(
                        color: levelMet ? Colors.green.shade700 : Colors.red,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Row(
                      children: [
                        const Icon(Icons.monetization_on, color: Colors.amber, size: 12),
                        const SizedBox(width: 2),
                        Text(
                          '${r.costInCoins}',
                          style: TextStyle(
                            color: hasCoins ? Colors.amber.shade800 : Colors.red,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            trailing: r.isClaimed
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.pink.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('CLAIMED', style: TextStyle(color: Colors.pinkAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                  )
                : ElevatedButton(
                    onPressed: (levelMet && hasCoins && !state.isLoading)
                        ? () async {
                            final success = await state.tryClaimReward(r.id);
                            if (success && mounted) {
                              CelebrationDialog.showRewardClaimed(
                                context,
                                reward: r,
                                remainingCoins: state.coins,
                                userColor: state.color,
                              );
                            } else if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(state.errorMessage ?? 'Failed to claim reward.'),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _parseColor(state.color),
                      disabledBackgroundColor: Colors.grey.shade200,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: const Text('CLAIM', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
          ),
        );
      },
    );
  }

  /// Builds the interactive list of social relationships, pending challenge invites, and requests.
  ///
  /// [Why] Lets users search and invite other players to challenge their recorded route activities.
  Widget _buildFriendsTab(AppState state) {
    return RefreshIndicator(
      onRefresh: () async {
        await state.fetchFriends(force: true);
        await state.fetchPendingFriendRequests(force: true);
        await state.fetchRouteInvitations(force: true);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // 1. Add Friend Card
            Card(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200, width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ADD A FRIEND',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _friendUsernameController,
                            decoration: InputDecoration(
                              hintText: 'Enter friend\'s username...',
                              hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: _parseColor(state.color)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: state.isLoading ? null : () async {
                            final username = _friendUsernameController.text.trim();
                            if (username.isNotEmpty) {
                              final success = await state.sendFriendRequest(username);
                              if (success && mounted) {
                                _friendUsernameController.clear();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Friend request sent to $username! ✉️'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              } else if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(state.errorMessage ?? 'User not found.'),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.person_add, size: 16, color: Colors.black87),
                          label: const Text('ADD', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 11)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _parseColor(state.color),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 2. Incoming Friend Requests List
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      'INCOMING FRIEND REQUESTS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                        letterSpacing: 1.5,
                      ),
                    ),
                    if (state.pendingFriendRequests.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(10)),
                        child: Text(
                          '${state.pendingFriendRequests.length}',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
                TextButton.icon(
                  onPressed: () {
                    state.fetchPendingFriendRequests(force: true);
                    state.fetchSentFriendRequests(force: true);
                    state.fetchFriends(force: true);
                  },
                  icon: const Icon(Icons.refresh, size: 14, color: Colors.black54),
                  label: const Text('REFRESH', style: TextStyle(fontSize: 10, color: Colors.black54, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (state.pendingFriendRequests.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.mark_email_read_outlined, size: 20, color: Colors.grey.shade400),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'No pending incoming friend requests.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: state.pendingFriendRequests.length,
                itemBuilder: (_, index) {
                  final req = state.pendingFriendRequests[index];
                  return Card(
                    color: Colors.white,
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                    child: ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: _parseColor(req.senderColor),
                        child: Text(
                          req.senderUsername.isNotEmpty ? req.senderUsername[0].toUpperCase() : '?',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(req.senderUsername, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: Text('Wants to be friends! • ${req.createdAt.length >= 10 ? req.createdAt.substring(0, 10) : req.createdAt}', style: const TextStyle(fontSize: 10, color: Colors.black54)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton.icon(
                            icon: const Icon(Icons.check, color: Colors.white, size: 14),
                            label: const Text('ACCEPT', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () async {
                              final ok = await state.acceptFriendRequest(req.id);
                              if (mounted) {
                                if (ok) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Accepted friend request from ${req.senderUsername}! 🎉'), backgroundColor: Colors.green),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(state.errorMessage ?? 'Failed to accept friend request.'), backgroundColor: Colors.redAccent),
                                  );
                                }
                              }
                            },
                          ),
                          const SizedBox(width: 6),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.close, color: Colors.redAccent, size: 14),
                            label: const Text('DECLINE', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.redAccent),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () async {
                              final ok = await state.rejectFriendRequest(req.id);
                              if (mounted) {
                                if (ok) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Friend request declined.')),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(state.errorMessage ?? 'Failed to decline friend request.'), backgroundColor: Colors.redAccent),
                                  );
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 16),

            // 2.5 Sent Friend Requests (Outgoing, Awaiting Friend Approval)
            if (state.sentFriendRequests.isNotEmpty) ...[
              Row(
                children: [
                  const Text(
                    'SENT REQUESTS (Awaiting Friend)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.black54,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.amber.shade800, borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      '${state.sentFriendRequests.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: state.sentFriendRequests.length,
                itemBuilder: (_, index) {
                  final sentReq = state.sentFriendRequests[index];
                  return Card(
                    color: Colors.white,
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                    child: ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: _parseColor(sentReq.receiverColor),
                        child: Text(
                          sentReq.receiverUsername.isNotEmpty ? sentReq.receiverUsername[0].toUpperCase() : '?',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(sentReq.receiverUsername, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: const Text('⏳ Waiting for friend to accept...', style: TextStyle(fontSize: 10, color: Colors.orange)),
                      trailing: TextButton.icon(
                        icon: const Icon(Icons.close, size: 14, color: Colors.redAccent),
                        label: const Text('CANCEL', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () async {
                          final ok = await state.cancelSentFriendRequest(sentReq.id);
                          if (mounted) {
                            if (ok) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Canceled friend request to ${sentReq.receiverUsername}.')),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(state.errorMessage ?? 'Failed to cancel friend request.'), backgroundColor: Colors.redAccent),
                              );
                            }
                          }
                        },
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],

            // 3. Pending Received Challenges
            if (state.pendingRouteInvitations.isNotEmpty) ...[
              const Text(
                'PENDING CHALLENGES',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: state.pendingRouteInvitations.length,
                itemBuilder: (_, index) {
                  final challenge = state.pendingRouteInvitations[index];
                  return Card(
                    color: Colors.white,
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${challenge.inviterUsername.toUpperCase()}\'S ROUTE CHALLENGE',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: Colors.purple.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                                child: Text(
                                  challenge.activityType,
                                  style: const TextStyle(color: Colors.purple, fontWeight: FontWeight.bold, fontSize: 9),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Distance: ${(challenge.activityDistance / 1000).toStringAsFixed(2)} km  •  Duration: ${(challenge.activityDuration / 60).toStringAsFixed(0)} mins',
                            style: const TextStyle(color: Colors.black54, fontSize: 11),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () async {
                                  final ok = await state.rejectRouteInvitation(challenge.id);
                                  if (mounted) {
                                    if (ok) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Challenge declined.')),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(state.errorMessage ?? 'Failed to decline challenge.'), backgroundColor: Colors.redAccent),
                                      );
                                    }
                                  }
                                },
                                child: const Text('DECLINE', style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () async {
                                  final success = await state.acceptRouteInvitation(challenge.id);
                                  if (mounted) {
                                    if (success) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Challenge accepted! Go to active challenges to run it.'), backgroundColor: Colors.green),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(state.errorMessage ?? 'Failed to accept challenge.'), backgroundColor: Colors.redAccent),
                                      );
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _parseColor(state.color),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text('ACCEPT', style: TextStyle(color: Colors.black87, fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
            ],

            // 4. Active (Accepted) Challenges
            if (state.activeRouteInvitations.isNotEmpty) ...[
              const Text(
                'ACTIVE CHALLENGES',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: state.activeRouteInvitations.length,
                itemBuilder: (_, index) {
                  final challenge = state.activeRouteInvitations[index];
                  final isSelected = state.activeInvitationId == challenge.id;
                  return Card(
                    color: isSelected ? Colors.green.shade50 : Colors.white,
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: isSelected ? Colors.green : Colors.grey.shade200, width: 1.5),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Run ${challenge.inviterUsername}\'s Route',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${challenge.activityType} • ${(challenge.activityDistance / 1000).toStringAsFixed(2)} km • ${(challenge.activityDuration / 60).toStringAsFixed(0)} mins',
                                  style: const TextStyle(color: Colors.black54, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () {
                              if (isSelected) {
                                state.selectRouteChallenge(null);
                              } else {
                                state.selectRouteChallenge(challenge.id);
                                // Auto-navigate to Map tab (tab index 0)
                                state.setTab(0);
                              }
                            },
                            icon: Icon(isSelected ? Icons.check : Icons.directions_run, size: 14, color: isSelected ? Colors.white : Colors.black87),
                            label: Text(isSelected ? 'SELECTED' : 'RUN', style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 10)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isSelected ? Colors.green : _parseColor(state.color),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
            ],

            // 5. Friends List
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'MY FRIENDS (${state.friendsList.length})',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                    letterSpacing: 1.5,
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    state.fetchFriends(force: true);
                  },
                  icon: const Icon(Icons.refresh, size: 14, color: Colors.black54),
                  label: const Text('REFRESH', style: TextStyle(fontSize: 10, color: Colors.black54, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            state.friendsList.isEmpty
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        Icon(Icons.people_outline, size: 36, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        const Text('No friends added yet.', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 4),
                        const Text('Enter a player\'s username above to send a friend request!', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: state.friendsList.length,
                    itemBuilder: (_, index) {
                      final friend = state.friendsList[index];
                      return Card(
                        color: Colors.white,
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                        child: ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: _parseColor(friend.color),
                            child: Text(friend.username.isNotEmpty ? friend.username[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                          title: Text(friend.username, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Territory Area: ${friend.totalTerritoryArea.toStringAsFixed(0)} m²', style: const TextStyle(fontSize: 10)),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}
