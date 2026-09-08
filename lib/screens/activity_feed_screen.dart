import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';

/// A tab-based screen rendering social events and player workout activity logs.
///
/// [Why] Allows users to review a live ledger of territory captures and their personal fitness diary history.
class ActivityFeedScreen extends StatefulWidget {
  const ActivityFeedScreen({super.key});

  @override
  State<ActivityFeedScreen> createState() => _ActivityFeedScreenState();
}

class _ActivityFeedScreenState extends State<ActivityFeedScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loadingMyActivities = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadMyActivities();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Pulls the latest completed workout entries from the remote server.
  ///
  /// [Why] Refreshes personal activities history log list view.
  ///
  /// [How] Accesses [AppState.fetchActivities] within a local loading spinner state constraint.
  Future<void> _loadMyActivities() async {
    final state = Provider.of<AppState>(context, listen: false);
    if (state.userId == null) return;
    
    setState(() => _loadingMyActivities = true);
    try {
      await state.fetchActivities();
      if (mounted) {
        setState(() => _loadingMyActivities = false);
      }
    } catch (e) {
      debugPrint('Error loading my activities: $e');
      if (mounted) {
        setState(() => _loadingMyActivities = false);
      }
    }
  }

  /// Utility to convert seconds into `MM:SS` format.
  String _formatDuration(int seconds) {
    final m = (seconds / 60).floor().toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('GAME FEED', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        shape: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 1)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFE040FB),
          labelColor: Colors.black87,
          unselectedLabelColor: Colors.grey.shade600,
          tabs: const [
            Tab(text: 'CAPTURES'),
            Tab(text: 'MY LOGS'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Captures/Ledger events tab
          RefreshIndicator(
            color: const Color(0xFFE040FB),
            backgroundColor: Colors.white,
            onRefresh: () async {
              await state.fetchEvents();
            },
            child: state.recentEvents.isEmpty
                ? const Center(
                    child: Text(
                      'No territory capture events yet.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: state.recentEvents.length,
                    itemBuilder: (context, index) {
                      final logStr = state.recentEvents[index];
                      // Style highlights (such as username, captured keyword)
                      final isCapture = logStr.contains('captured');
                      return Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isCapture 
                                ? Colors.redAccent.withOpacity(0.3) 
                                : Colors.green.shade600.withOpacity(0.3),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              isCapture ? Icons.gavel : Icons.add_location_alt,
                              color: isCapture ? Colors.redAccent : Colors.green.shade600,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                logStr,
                                style: const TextStyle(color: Colors.black87, fontSize: 13, height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // User's personal activities history log tab
          RefreshIndicator(
            color: const Color(0xFFE040FB),
            backgroundColor: Colors.white,
            onRefresh: _loadMyActivities,
            child: _loadingMyActivities
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFE040FB)))
                : state.activities.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE040FB).withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.directions_run, color: Color(0xFFE040FB), size: 48),
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'Record Your First Activity',
                                style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Track your walk, run, or cycle on the live GPS map to burn calories, earn XP, and conquer territory for your club!',
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
                                icon: const Icon(Icons.map, size: 18),
                                label: const Text('START ON MAP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.8)),
                                onPressed: () {
                                  state.setTab(0); // Switch to Map Tab
                                },
                              ),
                            ],
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          _buildWeeklyChart(state),
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: state.activities.length,
                              itemBuilder: (context, index) {
                                final act = state.activities[index];
                                final isClosed = act['closedLoop'] == true;
                                final status = act['status'] as String;
                                final distance = (act['distance'] as num).toDouble();
                                final duration = act['duration'] as int;
                                final type = act['type'] as String;

                                return Card(
                                  color: Colors.white,
                                  margin: const EdgeInsets.only(bottom: 10),
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(color: Colors.grey.shade200, width: 1),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                    child: Row(
                                      children: [
                                        // Icon based on type
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFF5F5F7),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            type.toUpperCase() == 'CYCLE' 
                                                ? Icons.directions_bike 
                                                : Icons.directions_run,
                                            color: const Color(0xFFE040FB),
                                            size: 22,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        
                                        // Details Column
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      '$type Session',
                                                      style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    _formatDateTime(act['startTime'] as String?),
                                                    style: TextStyle(color: Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.bold),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Distance: ${distance.toStringAsFixed(0)} m  •  Duration: ${_formatDuration(duration)}',
                                                style: const TextStyle(color: Colors.black54, fontSize: 12),
                                              ),
                                            ],
                                          ),
                                        ),

                                        const SizedBox(width: 8),

                                        // Status Badge
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: _getStatusColor(status).withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: _getStatusColor(status).withOpacity(0.4)),
                                              ),
                                              child: Text(
                                                status,
                                                style: TextStyle(color: _getStatusColor(status), fontSize: 10, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            if (isClosed)
                                              Row(
                                                children: [
                                                  Icon(Icons.loop, color: Colors.green.shade700, size: 12),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'CLOSED LOOP',
                                                    style: TextStyle(color: Colors.green.shade700, fontSize: 10, fontWeight: FontWeight.bold),
                                                  ),
                                                ],
                                              ),
                                            if (status.toUpperCase() == 'COMPLETED' || status.toUpperCase() == 'VALIDATED') ...[
                                              const SizedBox(height: 6),
                                              TextButton.icon(
                                                onPressed: () {
                                                  _showInviteFriendsDialog(context, state, act['id']);
                                                },
                                                icon: const Icon(Icons.send, size: 10, color: Color(0xFFE040FB)),
                                                label: const Text('CHALLENGE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFE040FB))),
                                                style: TextButton.styleFrom(
                                                  padding: EdgeInsets.zero,
                                                  minimumSize: const Size(50, 20),
                                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  /// Formats raw ISO time strings into reader-friendly date displays.
  String _formatDateTime(String? isoString) {
    if (isoString == null) return '';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final month = months[dt.month - 1];
      final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$month ${dt.day}, $hour:$minute $ampm';
    } catch (_) {
      return '';
    }
  }

  /// Builds a weekly progress chart displaying cumulative daily run distances in kilometers.
  ///
  /// [Why] Provides the player with visual feedback on their workout volume over the last week.
  ///
  /// [How] Pulls activities list from state, determines the date range, sums distances, 
  /// and renders bar columns representing distance ratios relative to the weekly maximum.
  Widget _buildWeeklyChart(AppState state) {
    if (state.activities.isEmpty) return const SizedBox.shrink();

    // 1. Find the latest activity date to anchor the chart range (robust against phone timezone mismatch)
    DateTime latestDate = DateTime.now();
    for (var act in state.activities) {
      final startTimeStr = act['startTime'] as String?;
      if (startTimeStr != null) {
        try {
          final dt = DateTime.parse(startTimeStr).toLocal();
          if (dt.isAfter(latestDate)) {
            latestDate = dt;
          }
        } catch (_) {}
      }
    }

    // 2. Generate the last 7 days ending at midnight of the latest date
    final endDate = DateTime(latestDate.year, latestDate.month, latestDate.day);
    final last7Days = List.generate(7, (i) => endDate.subtract(Duration(days: 6 - i)));

    final Map<String, double> dailyDistance = {};
    for (var date in last7Days) {
      final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      dailyDistance[dateKey] = 0.0;
    }

    for (var act in state.activities) {
      final startTimeStr = act['startTime'] as String?;
      if (startTimeStr != null) {
        try {
          final dt = DateTime.parse(startTimeStr).toLocal();
          final dateKey = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
          if (dailyDistance.containsKey(dateKey)) {
            dailyDistance[dateKey] = dailyDistance[dateKey]! + (act['distance'] as num).toDouble();
          }
        } catch (_) {}
      }
    }

    double maxDistance = 1000.0;
    for (var dist in dailyDistance.values) {
      if (dist > maxDistance) {
        maxDistance = dist;
      }
    }

    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'WEEKLY PROGRESSION (KM)',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: last7Days.map((date) {
              final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
              final distance = dailyDistance[dateKey] ?? 0.0;
              final heightRatio = (distance / maxDistance).clamp(0.0, 1.0);
              final barHeight = 60.0 * heightRatio;
              final weekday = weekdays[date.weekday - 1];
              final dayLabel = '${date.day}';

              return Column(
                children: [
                  Text(
                    distance > 0 ? '${(distance / 1000).toStringAsFixed(1)}k' : '0k',
                    style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black54),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 12,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        Container(
                          width: 12,
                          height: barHeight,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFE040FB), Color(0xFF00E5FF)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    weekday,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dayLabel,
                    style: const TextStyle(fontSize: 9, color: Colors.black38, fontWeight: FontWeight.bold),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// Maps activity status keywords to specific UI color schemes.
  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
        return Colors.green.shade700;
      case 'REJECTED':
        return Colors.redAccent;
      case 'PENDING_REVIEW':
        return Colors.orange.shade800;
      case 'PROCESSING':
        return Colors.blue.shade700;
      default:
        return Colors.grey.shade600;
    }
  }

  /// Parses hex color strings into Color classes.
  Color _parseColor(String hex) {
    final clean = hex.replaceAll('#', '');
    return Color(int.parse('FF$clean', radix: 16));
  }

  /// Renders a dialog widget prompting the player to invite a friend to challenge this route.
  ///
  /// [Why] Facilitates competitive social route sharing.
  ///
  /// [How] Pops up a dialog listing friends with an invite button that calls [AppState.createRouteInvitation].
  void _showInviteFriendsDialog(BuildContext context, AppState state, int activityId) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Challenge a Friend', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: state.friendsList.isEmpty
              ? const Text('You don\'t have any friends added yet. Add friends on your profile tab to challenge them!')
              : SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: state.friendsList.length,
                    itemBuilder: (c, idx) {
                      final friend = state.friendsList[idx];
                      return ListTile(
                        leading: CircleAvatar(
                          radius: 12,
                          backgroundColor: _parseColor(friend.color),
                          child: Text(friend.username[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10)),
                        ),
                        title: Text(friend.username, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        trailing: ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            final success = await state.createRouteInvitation(friend.id, activityId);
                            if (success && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Challenge sent to ${friend.username}! 🏃')),
                              );
                            } else if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(state.errorMessage ?? 'Failed to send challenge.'),
                                  backgroundColor: Colors.redAccent,
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _parseColor(state.color),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            minimumSize: const Size(60, 28),
                          ),
                          child: const Text('Send', style: TextStyle(color: Colors.black87, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      );
                    },
                  ),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CLOSE'),
            )
          ],
        );
      },
    );
  }
}
