import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';

/// Screen component displaying top player rankings based on total claimed territory area.
///
/// [Why] Promotes game-wide competition by ranking players on a podium and leaderboard list.
class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('GLOBAL STANDINGS', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        shape: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 1)),
      ),
      body: RefreshIndicator(
        color: const Color(0xFFE040FB),
        backgroundColor: Colors.white,
        onRefresh: () async {
          await state.fetchLeaderboard();
        },
        child: state.leaderboard.isEmpty
            ? const Center(
                child: Text(
                  'No standings recorded yet.\nBe the first to claim a territory!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              )
            : Column(
                children: [
                  // Top 3 Podium Header (Visually Premium)
                  if (state.leaderboard.length >= 3)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 1)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // 2nd Place
                          _buildPodiumColumn(
                            username: state.leaderboard[1].username,
                            score: state.leaderboard[1].score,
                            rank: 2,
                            height: 80,
                            color: const Color(0xFFB0BEC5), // Silver
                          ),
                          // 1st Place
                          _buildPodiumColumn(
                            username: state.leaderboard[0].username,
                            score: state.leaderboard[0].score,
                            rank: 1,
                            height: 110,
                            color: const Color(0xFFFFD54F), // Gold
                          ),
                          // 3rd Place
                          _buildPodiumColumn(
                            username: state.leaderboard[2].username,
                            score: state.leaderboard[2].score,
                            rank: 3,
                            height: 60,
                            color: const Color(0xFFFFAB91), // Bronze
                          ),
                        ],
                      ),
                    ),
                  
                  // Rankings List
                  Expanded(
                    child: ListView.builder(
                      itemCount: state.leaderboard.length,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemBuilder: (context, index) {
                        final entry = state.leaderboard[index];
                        final isMe = entry.username == state.username;
                        
                        return Card(
                          color: isMe ? const Color(0xFFF3E5F5) : Colors.white,
                          margin: const EdgeInsets.only(bottom: 8),
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: isMe 
                                ? const BorderSide(color: Color(0xFFE040FB), width: 1.5)
                                : BorderSide(color: Colors.grey.shade200, width: 1),
                          ),
                          child: ListTile(
                            leading: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: _getRankColor(entry.rank),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${entry.rank}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold, 
                                  color: entry.rank <= 3 ? Colors.white : Colors.black87
                                ),
                              ),
                            ),
                            title: Text(
                              entry.username,
                              style: TextStyle(
                                color: Colors.black87,
                                fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            trailing: Text(
                              '${entry.score.toStringAsFixed(0)} m²',
                              style: const TextStyle(
                                color: Color(0xFFE040FB),
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Outfit',
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// Builds a podium bar column representing 1st, 2nd, or 3rd place.
  Widget _buildPodiumColumn({
    required String username,
    required double score,
    required int rank,
    required double height,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(
          rank == 1 ? Icons.emoji_events : Icons.military_tech,
          color: color,
          size: rank == 1 ? 32 : 24,
        ),
        const SizedBox(height: 6),
        Text(
          username,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 13),
        ),
        Text(
          '${score.toStringAsFixed(0)} m²',
          style: const TextStyle(color: Colors.black54, fontSize: 11),
        ),
        const SizedBox(height: 8),
        Container(
          width: 60,
          height: height,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border.all(color: color.withOpacity(0.5), width: 1.5),
          ),
          alignment: Alignment.center,
          child: Text(
            '#$rank',
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
      ],
    );
  }

  /// Maps rankings (1, 2, 3) to gold, silver, bronze color tokens.
  Color _getRankColor(int rank) {
    if (rank == 1) return const Color(0xFFFFD54F);
    if (rank == 2) return const Color(0xFFB0BEC5);
    if (rank == 3) return const Color(0xFFFFAB91);
    return Colors.grey.shade300;
  }
}
