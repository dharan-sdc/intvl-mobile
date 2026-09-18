import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile/app_state.dart';
import 'package:mobile/shared/widgets/celebration_dialog.dart';
import 'campaign_leaderboard_screen.dart';

/// Personal campaign dashboard / cockpit for an enrolled user.
///
/// Fully aligned with the app's parent theme.
class MyCampaignDashboardScreen extends StatefulWidget {
  final int campaignId;

  const MyCampaignDashboardScreen({super.key, required this.campaignId});

  @override
  State<MyCampaignDashboardScreen> createState() => _MyCampaignDashboardScreenState();
}

class _MyCampaignDashboardScreenState extends State<MyCampaignDashboardScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final state = Provider.of<AppState>(context, listen: false);
      await state.fetchCampaignDashboard(widget.campaignId);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Unable to load campaign dashboard. You might need to join this campaign first.';
        });
      }
    }
  }

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return const Color(0xFFE040FB);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final dashboard = state.selectedCampaignDashboard;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F5F7),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('My Campaign', style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFFE040FB)),
              SizedBox(height: 16),
              Text('Loading your campaign dashboard...', style: TextStyle(color: Colors.grey, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    if (dashboard == null || _errorMessage != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F5F7),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('My Campaign', style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.flag_outlined, color: Colors.grey.shade400, size: 54),
                const SizedBox(height: 16),
                const Text(
                  'Dashboard Unavailable',
                  style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage ?? 'Unable to retrieve campaign progress details.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE040FB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Retry'),
                  onPressed: _loadDashboard,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final campaign = dashboard.campaign;
    final themeColor = _parseColor(campaign.colorHex);
    final userDist = dashboard.currentDistanceKm;
    final targetDist = dashboard.targetDistanceKm;
    final pct = dashboard.progressPercentage.clamp(0.0, 100.0);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        shape: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 1)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Text(campaign.iconEmoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                campaign.title,
                style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard, color: Color(0xFFFFA000)),
            tooltip: 'Leaderboard',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CampaignLeaderboardScreen(campaignId: campaign.id),
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: const Color(0xFFE040FB),
        backgroundColor: Colors.white,
        onRefresh: _loadDashboard,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Progress Cockpit Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: themeColor.withValues(alpha: 0.4), width: 1.5),
                boxShadow: [
                  BoxShadow(color: themeColor.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'YOUR PROGRESS',
                        style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFA000).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFFFA000).withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.emoji_events, color: Color(0xFFFFA000), size: 14),
                            const SizedBox(width: 4),
                            Text(
                              'Rank #${dashboard.rank}',
                              style: const TextStyle(color: Color(0xFFE65100), fontWeight: FontWeight.w900, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        userDist.toStringAsFixed(1),
                        style: TextStyle(color: themeColor, fontWeight: FontWeight.w900, fontSize: 38),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        targetDist > 0 ? '/ ${targetDist.toStringAsFixed(1)} KM' : 'KM logged',
                        style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const Spacer(),
                      Text(
                        '${pct.toStringAsFixed(0)}%',
                        style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w900, fontSize: 24),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: pct / 100.0,
                      minHeight: 14,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(themeColor),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.military_tech, color: Color(0xFF00C853), size: 20),
                          const SizedBox(width: 6),
                          Text(
                            '${dashboard.totalPoints} Total Points',
                            style: const TextStyle(color: Color(0xFF00C853), fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                      if (dashboard.isGoalCompleted)
                        InkWell(
                          onTap: () {
                            CelebrationDialog.showCampaignMilestone(
                              context,
                              campaignTitle: campaign.title,
                              iconEmoji: campaign.iconEmoji,
                              milestoneTitle: 'Goal Completed',
                              thresholdKm: targetDist,
                              bonusPoints: 500,
                              currentDistanceKm: userDist,
                              targetDistanceKm: targetDist,
                              totalPoints: dashboard.totalPoints,
                              isGoalCompleted: true,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00C853).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.check_circle, color: Color(0xFF00C853), size: 12),
                                SizedBox(width: 4),
                                Text('GOAL REACHED', style: TextStyle(color: Color(0xFF00C853), fontWeight: FontWeight.bold, fontSize: 10)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Target Requirement Banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200, width: 1.2),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.track_changes, color: Color(0xFF0091EA), size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('TARGET REQUIREMENT', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(
                          targetDist > 0
                              ? 'Run ${targetDist.toStringAsFixed(0)} KM during the active campaign window.'
                              : 'Open community challenge: Every kilometer counts towards total ranking!',
                          style: const TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Point Ledger & History Section
            const Text(
              'AUDIT POINT TRANSACTIONS',
              style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
            ),
            const SizedBox(height: 10),

            if (dashboard.transactions.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: const Text('No point transactions recorded yet. Start a run to log points!', style: TextStyle(color: Colors.grey, fontSize: 12)),
              )
            else
              ...dashboard.transactions.map((tx) {
                Color badgeColor = const Color(0xFF0091EA);
                if (tx.transactionType == 'MILESTONE') badgeColor = const Color(0xFFFFA000);
                if (tx.transactionType == 'COMPLETION') badgeColor = const Color(0xFF00C853);
                if (tx.transactionType == 'PARTICIPATION') badgeColor = const Color(0xFF8E24AA);

                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    CelebrationDialog.showCampaignMilestone(
                      context,
                      campaignTitle: campaign.title,
                      iconEmoji: campaign.iconEmoji,
                      milestoneTitle: tx.description ?? tx.transactionType,
                      thresholdKm: userDist,
                      bonusPoints: tx.points,
                      currentDistanceKm: userDist,
                      targetDistanceKm: targetDist,
                      totalPoints: dashboard.totalPoints,
                      isGoalCompleted: tx.transactionType == 'COMPLETION',
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            tx.transactionType,
                            style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 10),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            tx.description ?? 'Point award',
                            style: const TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ),
                        Text(
                          '+${tx.points} PTS',
                          style: const TextStyle(color: Color(0xFF00C853), fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                );
              }),

            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, -2)),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E5FF),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 1,
                  ),
                  icon: const Icon(Icons.directions_run, size: 22),
                  label: const Text('START RUN', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.5)),
                  onPressed: () {
                    // Switch to Tab 0 (Map HUD) to start tracking
                    state.setTab(0);
                    Navigator.popUntil(context, (route) => route.isFirst);
                  },
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFFFA000).withValues(alpha: 0.12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.all(14),
                ),
                icon: const Icon(Icons.leaderboard, color: Color(0xFFFFA000)),
                tooltip: 'Leaderboard',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CampaignLeaderboardScreen(campaignId: campaign.id),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
