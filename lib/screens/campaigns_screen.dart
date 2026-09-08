import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import 'campaign_details_screen.dart';
import 'my_campaign_dashboard_screen.dart';

/// Central discovery and management hub for Trion Campaigns and Challenges.
///
/// Fully aligned with the app's parent theme (Material 3, Clean Light Surface, Neon Violet & Cyan Accents).
class CampaignsScreen extends StatefulWidget {
  const CampaignsScreen({super.key});

  @override
  State<CampaignsScreen> createState() => _CampaignsScreenState();
}

class _CampaignsScreenState extends State<CampaignsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedCategory = 'ALL';

  final List<Map<String, String>> _categories = [
    {'label': 'ALL', 'type': 'ALL'},
    {'label': '🎗️ AWARENESS', 'type': 'AWARENESS'},
    {'label': '🏃 MARATHON', 'type': 'MARATHON'},
    {'label': '🌳 CHARITY', 'type': 'CHARITY'},
    {'label': '🏢 CORPORATE', 'type': 'CORPORATE'},
    {'label': '🏫 COLLEGE', 'type': 'COLLEGE'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = Provider.of<AppState>(context, listen: false);
      state.fetchCampaigns();
      state.fetchMyCampaigns();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        shape: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 1)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFE040FB).withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.track_changes, color: Color(0xFFE040FB), size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'CAMPAIGNS',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                fontSize: 18,
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFE040FB),
          indicatorWeight: 3,
          labelColor: const Color(0xFFE040FB),
          unselectedLabelColor: Colors.black54,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Discover'),
                  if (state.discoverCampaigns.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE040FB).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${state.discoverCampaigns.length}',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFE040FB)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('My Campaigns'),
                  if (state.myCampaigns.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E5FF).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${state.myCampaigns.length}',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF00B0FF)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(text: 'Completed'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDiscoverTab(state),
          _buildMyCampaignsTab(state),
          _buildCompletedTab(state),
        ],
      ),
    );
  }

  Widget _buildCategoryFilterChips(AppState state) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: _categories.map((cat) {
          final isSelected = _selectedCategory == cat['type'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(cat['label']!),
              selected: isSelected,
              selectedColor: const Color(0xFFE040FB).withOpacity(0.15),
              backgroundColor: Colors.white,
              checkmarkColor: const Color(0xFFE040FB),
              labelStyle: TextStyle(
                color: isSelected ? const Color(0xFFE040FB) : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
              side: BorderSide(
                color: isSelected ? const Color(0xFFE040FB) : Colors.grey.shade300,
                width: 1,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              onSelected: (val) {
                setState(() {
                  _selectedCategory = cat['type']!;
                });
                state.fetchCampaigns(type: _selectedCategory);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDiscoverTab(AppState state) {
    if (state.isCampaignsLoading && state.discoverCampaigns.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFE040FB)));
    }

    final filtered = _selectedCategory == 'ALL'
        ? state.discoverCampaigns
        : state.discoverCampaigns.where((c) => c.type.toUpperCase() == _selectedCategory).toList();

    return RefreshIndicator(
      color: const Color(0xFFE040FB),
      backgroundColor: Colors.white,
      onRefresh: () async {
        await state.fetchCampaigns(type: _selectedCategory);
        await state.fetchMyCampaigns();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _buildCategoryFilterChips(state),

          // Hero Banner
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8E24AA), Color(0xFF4A148C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8E24AA).withOpacity(0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Text('🎯', style: TextStyle(fontSize: 28)),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Make Every Step Count',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Join awareness runs, charity marathons & corporate challenges. Every validated workout contributes automatically.',
                          style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.event_busy, color: Colors.grey.shade400, size: 48),
                  const SizedBox(height: 12),
                  Text('No active campaigns in this category.', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                ],
              ),
            )
          else
            ...filtered.map((campaign) => _buildCampaignCard(context, campaign, state)),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildCampaignCard(BuildContext context, CampaignModel campaign, AppState state) {
    final themeColor = _parseColor(campaign.colorHex);
    final pct = campaign.progressPercentage.clamp(0.0, 100.0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CampaignDetailsScreen(campaignId: campaign.id),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Emoji, Title & Type Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: themeColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: themeColor.withOpacity(0.3)),
                    ),
                    child: Text(campaign.iconEmoji, style: const TextStyle(fontSize: 22)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          campaign.title,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          campaign.organizerName.isNotEmpty ? campaign.organizerName : 'Trion Global',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: themeColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: themeColor.withOpacity(0.4)),
                    ),
                    child: Text(
                      campaign.type,
                      style: TextStyle(
                        color: themeColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Description Snippet
              Text(
                campaign.description,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13, height: 1.3),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 14),

              // Metrics Row: Participants & Target
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.people_alt_outlined, color: Colors.grey.shade600, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${campaign.participantCount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} Joined',
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(Icons.flag_outlined, color: themeColor, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Target: ${campaign.individualTargetKm.toStringAsFixed(0)} KM',
                        style: TextStyle(color: themeColor, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Community Goal Progress Bar
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'COMMUNITY GOAL',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                      Text(
                        '${campaign.currentDistanceKm.toStringAsFixed(0)} / ${campaign.targetDistanceKm.toStringAsFixed(0)} KM (${pct.toStringAsFixed(0)}%)',
                        style: TextStyle(color: themeColor, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct / 100.0,
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(themeColor),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Bottom Action Button
              Row(
                children: [
                  if (campaign.isJoined)
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00E5FF).withOpacity(0.12),
                          foregroundColor: const Color(0xFF0091EA),
                          side: const BorderSide(color: Color(0xFF00B0FF)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.dashboard_outlined, size: 16),
                        label: const Text('MY DASHBOARD', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MyCampaignDashboardScreen(campaignId: campaign.id),
                            ),
                          );
                        },
                      ),
                    )
                  else
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 1,
                        ),
                        onPressed: () async {
                          final ok = await state.joinCampaign(campaign.id);
                          if (ok && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('🎉 Joined ${campaign.title}! +50 Bonus Points credited.'),
                                backgroundColor: const Color(0xFF00C853),
                              ),
                            );
                          }
                        },
                        child: const Text('JOIN CAMPAIGN', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5)),
                      ),
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey.shade100,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: Icon(Icons.arrow_forward_ios, color: Colors.grey.shade700, size: 14),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CampaignDetailsScreen(campaignId: campaign.id),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMyCampaignsTab(AppState state) {
    if (state.myCampaigns.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFE040FB).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.flag_outlined, color: Color(0xFFE040FB), size: 48),
              ),
              const SizedBox(height: 20),
              const Text(
                'No Active Campaigns',
                style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                'Enroll in an awareness run, charity marathon, or corporate challenge in the Discover tab to start earning points!',
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
                  elevation: 1,
                ),
                icon: const Icon(Icons.explore, size: 18),
                label: const Text('DISCOVER CAMPAIGNS', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => _tabController.animateTo(0),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFFE040FB),
      backgroundColor: Colors.white,
      onRefresh: () => state.fetchMyCampaigns(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: state.myCampaigns.length,
        itemBuilder: (context, idx) {
          final campaign = state.myCampaigns[idx];
          final themeColor = _parseColor(campaign.colorHex);
          final userDist = campaign.userDistanceKm;
          final target = campaign.individualTargetKm > 0 ? campaign.individualTargetKm : 30.0;
          final pct = ((userDist / target) * 100).clamp(0.0, 100.0);

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  children: [
                    Text(campaign.iconEmoji, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            campaign.title,
                            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            'Personal Target: ${target.toStringAsFixed(0)} KM',
                            style: TextStyle(color: themeColor, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00C853).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Color(0xFF00C853), size: 12),
                          const SizedBox(width: 4),
                          Text(
                            '${campaign.userPoints} PTS',
                            style: const TextStyle(color: Color(0xFF00C853), fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${userDist.toStringAsFixed(1)} / ${target.toStringAsFixed(1)} KM',
                      style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      '${pct.toStringAsFixed(0)}%',
                      style: TextStyle(color: themeColor, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct / 100.0,
                    minHeight: 10,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(themeColor),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeColor.withOpacity(0.1),
                      foregroundColor: themeColor,
                      side: BorderSide(color: themeColor),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.speed, size: 16),
                    label: const Text('OPEN COCKPIT DASHBOARD', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MyCampaignDashboardScreen(campaignId: campaign.id),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCompletedTab(AppState state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB300).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.workspace_premium_outlined, color: Color(0xFFFFB300), size: 48),
            ),
            const SizedBox(height: 20),
            const Text(
              'Campaign Hall of Fame',
              style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Completed campaigns will appear here along with your digital finisher certificates and commemorative milestone badges.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
