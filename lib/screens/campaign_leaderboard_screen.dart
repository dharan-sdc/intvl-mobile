import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';

/// Multi-tier Campaign Leaderboard displaying Individual, Club, and Organization rankings.
///
/// Fully aligned with the app's parent theme (Material 3, Clean Light Surface, Neon Violet & Cyan Accents).
class CampaignLeaderboardScreen extends StatefulWidget {
  final int campaignId;

  const CampaignLeaderboardScreen({super.key, required this.campaignId});

  @override
  State<CampaignLeaderboardScreen> createState() => _CampaignLeaderboardScreenState();
}

class _CampaignLeaderboardScreenState extends State<CampaignLeaderboardScreen> {
  String _activeView = 'INDIVIDUAL'; // INDIVIDUAL, CLUB, ORGANIZATION
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    final state = Provider.of<AppState>(context, listen: false);
    await state.fetchCampaignLeaderboard(widget.campaignId, view: _activeView);
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final lb = state.selectedCampaignLeaderboard;

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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'CAMPAIGN LEADERBOARD',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 1,
              ),
            ),
            if (lb != null)
              Text(
                lb.campaignTitle,
                style: const TextStyle(color: Colors.black54, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Tier Switcher Chips
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 1)),
            ),
            child: Row(
              children: [
                _buildTierChip('👤 Individual', 'INDIVIDUAL'),
                const SizedBox(width: 8),
                _buildTierChip('🛡️ Club', 'CLUB'),
                const SizedBox(width: 8),
                _buildTierChip('🏢 Organization', 'ORGANIZATION'),
              ],
            ),
          ),

          // Main Standings List or Loading
          Expanded(
            child: _isLoading || lb == null
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFE040FB)),
                  )
                : RefreshIndicator(
                    color: const Color(0xFFE040FB),
                    backgroundColor: Colors.white,
                    onRefresh: _loadLeaderboard,
                    child: lb.entries.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 80),
                              Center(
                                child: Text(
                                  'No standings recorded yet.\nBe the first to record an activity!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey, fontSize: 15),
                                ),
                              ),
                            ],
                          )
                        : ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              // Top 3 Podium (if >= 3 entries)
                              if (lb.entries.length >= 3) ...[
                                _buildPodium(lb.entries),
                                const SizedBox(height: 16),
                              ],

                              // Section title
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'ALL RANKINGS (${lb.entries.length})',
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    Text(
                                      'DIST / PTS',
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Rest of the Standings
                              ...lb.entries.map((entry) => _buildStandingRow(entry)),

                              const SizedBox(height: 70),
                            ],
                          ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: (lb != null && lb.userStanding != null)
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: const Border(
                  top: BorderSide(color: Color(0xFFE040FB), width: 2),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE040FB).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '#${lb.userStanding!.rank}',
                        style: const TextStyle(
                          color: Color(0xFFE040FB),
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'YOUR STANDING',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            '${lb.userStanding!.name} (You)',
                            style: const TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${lb.userStanding!.totalDistanceKm.toStringAsFixed(1)} KM',
                          style: const TextStyle(
                            color: Color(0xFF0091EA),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          '${lb.userStanding!.totalPoints} PTS',
                          style: const TextStyle(
                            color: Color(0xFF2E7D32),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildTierChip(String label, String viewKey) {
    final isSelected = _activeView == viewKey;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          if (_activeView != viewKey) {
            setState(() {
              _activeView = viewKey;
              _isLoading = true;
            });
            _loadLeaderboard();
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFF3E5F5) : const Color(0xFFF5F5F7),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFFE040FB) : Colors.grey.shade300,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? const Color(0xFFE040FB) : Colors.black87,
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPodium(List<CampaignLeaderboardEntryModel> entries) {
    final first = entries[0];
    final second = entries[1];
    final third = entries[2];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.emoji_events, color: Color(0xFFFFB300), size: 18),
              SizedBox(width: 6),
              Text(
                'PODIUM LEADERS',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 2nd Place (Silver)
              _buildPodiumColumn(second, 2, const Color(0xFF78909C), 90),
              const SizedBox(width: 8),
              // 1st Place (Gold)
              _buildPodiumColumn(first, 1, const Color(0xFFFFB300), 120),
              const SizedBox(width: 8),
              // 3rd Place (Bronze)
              _buildPodiumColumn(third, 3, const Color(0xFFB07D62), 70),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumColumn(CampaignLeaderboardEntryModel entry, int rank, Color color, double height) {
    return Expanded(
      child: Column(
        children: [
          // Avatar & Badge
          Stack(
            alignment: Alignment.topCenter,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
                child: Center(
                  child: Text(
                    entry.name.isNotEmpty ? entry.name[0].toUpperCase() : '?',
                    style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                ),
              ),
              if (rank == 1)
                const Icon(Icons.emoji_events, color: Color(0xFFFFB300), size: 20),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            entry.name,
            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 12),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          Text(
            '${entry.totalDistanceKm.toStringAsFixed(1)} KM',
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
          ),
          Text(
            '${entry.totalPoints} PTS',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 10, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Container(
            height: height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.25), color.withOpacity(0.08)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              border: Border.all(color: color.withOpacity(0.4)),
            ),
            child: Center(
              child: Text(
                '#$rank',
                style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStandingRow(CampaignLeaderboardEntryModel entry) {
    Color rankColor = Colors.grey.shade700;
    if (entry.rank == 1) rankColor = const Color(0xFFFFB300);
    if (entry.rank == 2) rankColor = const Color(0xFF78909C);
    if (entry.rank == 3) rankColor = const Color(0xFFB07D62);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: entry.isCurrentUser ? const Color(0xFFF3E5F5) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: entry.isCurrentUser ? const Color(0xFFE040FB) : Colors.grey.shade200,
          width: entry.isCurrentUser ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '#${entry.rank}',
              style: TextStyle(color: rankColor, fontWeight: FontWeight.w900, fontSize: 14),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 16,
            backgroundColor: rankColor.withOpacity(0.15),
            child: Text(
              entry.name.isNotEmpty ? entry.name[0].toUpperCase() : '?',
              style: TextStyle(color: rankColor, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name + (entry.isCurrentUser ? ' (You)' : ''),
                  style: TextStyle(
                    color: entry.isCurrentUser ? const Color(0xFFE040FB) : Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (entry.subtitle.isNotEmpty)
                  Text(
                    entry.subtitle,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entry.totalDistanceKm.toStringAsFixed(1)} KM',
                style: const TextStyle(color: Color(0xFF0091EA), fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Text(
                '${entry.totalPoints} PTS',
                style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
