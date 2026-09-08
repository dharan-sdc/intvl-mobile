import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import 'my_campaign_dashboard_screen.dart';
import 'campaign_leaderboard_screen.dart';

/// Detailed view of a campaign displaying organizer info, cause mission, community meter,
/// and the complete structured points rules and milestone roadmaps.
///
/// Fully aligned with the app's parent theme.
class CampaignDetailsScreen extends StatefulWidget {
  final int campaignId;

  const CampaignDetailsScreen({super.key, required this.campaignId});

  @override
  State<CampaignDetailsScreen> createState() => _CampaignDetailsScreenState();
}

class _CampaignDetailsScreenState extends State<CampaignDetailsScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    final state = Provider.of<AppState>(context, listen: false);
    await state.fetchCampaignDetails(widget.campaignId);
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
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
    final detail = state.selectedCampaignDetails;

    if (_isLoading || detail == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F5F7),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Campaign Details', style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        body: const Center(child: CircularProgressIndicator(color: Color(0xFFE040FB))),
      );
    }

    final campaign = detail.summary;
    final rules = detail.rules;
    final milestones = detail.milestones;
    final themeColor = _parseColor(campaign.colorHex);
    final pct = campaign.progressPercentage.clamp(0.0, 100.0);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: CustomScrollView(
        slivers: [
          // Hero Sliver App Bar
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: Colors.white,
            elevation: 1,
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black87, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
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
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [themeColor.withOpacity(0.2), Colors.white],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 30),
                      Container(
                        width: 70,
                        height: 70,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: themeColor, width: 2.5),
                          boxShadow: [
                            BoxShadow(color: themeColor.withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: Text(campaign.iconEmoji, style: const TextStyle(fontSize: 34)),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: themeColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          campaign.type,
                          style: TextStyle(
                            color: themeColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Content List
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title & Organizer
                  Text(
                    campaign.title,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.verified, color: Color(0xFF00B0FF), size: 16),
                      const SizedBox(width: 4),
                      Text(
                        campaign.organizerName.isNotEmpty ? campaign.organizerName : 'Trion Global Foundation',
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Quick Stats Grid
                  Row(
                    children: [
                      _buildQuickStatCard(
                        icon: Icons.people,
                        label: 'Participants',
                        value: campaign.participantCount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},'),
                        color: const Color(0xFF0091EA),
                      ),
                      const SizedBox(width: 12),
                      _buildQuickStatCard(
                        icon: Icons.flag,
                        label: 'Your Target',
                        value: '${campaign.individualTargetKm.toStringAsFixed(0)} KM',
                        color: themeColor,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Community Goal Meter Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200, width: 1.2),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.public, color: Colors.grey.shade700, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  'COMMUNITY COLLECTIVE GOAL',
                                  style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5),
                                ),
                              ],
                            ),
                            Text(
                              '${pct.toStringAsFixed(0)}%',
                              style: TextStyle(color: themeColor, fontWeight: FontWeight.w900, fontSize: 16),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: pct / 100.0,
                            minHeight: 12,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation<Color>(themeColor),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${campaign.currentDistanceKm.toStringAsFixed(0)} KM logged',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                            ),
                            Text(
                              'Goal: ${campaign.targetDistanceKm.toStringAsFixed(0)} KM',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // About Section
                  const Text(
                    'ABOUT THE CAUSE',
                    style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    campaign.description,
                    style: TextStyle(color: Colors.grey.shade800, fontSize: 14, height: 1.5),
                  ),

                  const SizedBox(height: 20),

                  // Points System Rules Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200, width: 1.2),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.military_tech, color: Color(0xFFFFA000), size: 20),
                            SizedBox(width: 8),
                            Text(
                              'HOW TO EARN POINTS',
                              style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildPointRow('Join Campaign Bonus', '+${rules.participationPoints} PTS', Colors.grey.shade800, const Color(0xFF00C853)),
                        Divider(color: Colors.grey.shade200, height: 16),
                        _buildPointRow('Every 1.0 KM Logged', '+${rules.pointsPerKm.toStringAsFixed(0)} PTS / KM', Colors.grey.shade800, const Color(0xFF0091EA)),
                        Divider(color: Colors.grey.shade200, height: 16),
                        _buildPointRow('Reach Individual Goal (${campaign.individualTargetKm.toStringAsFixed(0)} KM)', '+${rules.completionBonusPoints} PTS', Colors.grey.shade800, const Color(0xFFFFA000)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Milestones Roadmap Card
                  if (milestones.isNotEmpty) ...[
                    const Text(
                      'DISTANCE MILESTONES',
                      style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 12),
                    ...milestones.map((m) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: m.isAchieved ? const Color(0xFF00C853).withOpacity(0.5) : Colors.grey.shade200,
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(
                              m.isAchieved ? Icons.check_circle : Icons.radio_button_unchecked,
                              color: m.isAchieved ? const Color(0xFF00C853) : Colors.grey.shade400,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    m.title,
                                    style: TextStyle(
                                      color: m.isAchieved ? const Color(0xFF00C853) : Colors.black87,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    '${m.thresholdKm.toStringAsFixed(1)} KM Milestone',
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFA000).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '+${m.bonusPoints} PTS',
                                style: const TextStyle(color: Color(0xFFE65100), fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, -2)),
          ],
        ),
        child: SafeArea(
          child: campaign.isJoined
              ? ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E5FF).withOpacity(0.15),
                    foregroundColor: const Color(0xFF0091EA),
                    side: const BorderSide(color: Color(0xFF00B0FF), width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.dashboard_outlined, size: 20),
                  label: const Text('OPEN MY CAMPAIGN DASHBOARD', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5)),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MyCampaignDashboardScreen(campaignId: campaign.id),
                      ),
                    );
                  },
                )
              : ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 1,
                  ),
                  icon: const Icon(Icons.check, size: 20),
                  label: const Text('JOIN CAMPAIGN (+50 PTS)', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5)),
                  onPressed: () async {
                    final ok = await state.joinCampaign(campaign.id);
                    if (ok && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('🎉 Enrolled in ${campaign.title}! +50 Bonus Points credited.'),
                          backgroundColor: const Color(0xFF00C853),
                        ),
                      );
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MyCampaignDashboardScreen(campaignId: campaign.id),
                        ),
                      );
                    }
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildQuickStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200, width: 1.2),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                  Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPointRow(String label, String points, Color labelColor, Color pointsColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(label, style: TextStyle(color: labelColor, fontSize: 13, fontWeight: FontWeight.w500)),
        ),
        Text(points, style: TextStyle(color: pointsColor, fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }
}
