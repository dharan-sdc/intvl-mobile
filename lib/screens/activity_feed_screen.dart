import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';

class ActivityFeedScreen extends StatefulWidget {
  const ActivityFeedScreen({super.key});

  @override
  State<ActivityFeedScreen> createState() => _ActivityFeedScreenState();
}

class _ActivityFeedScreenState extends State<ActivityFeedScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _myActivities = [];
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

  Future<void> _loadMyActivities() async {
    final state = Provider.of<AppState>(context, listen: false);
    if (state.userId == null) return;
    
    setState(() => _loadingMyActivities = true);
    try {
      final list = await state.api.getActivities(state.userId!);
      setState(() {
        _myActivities = list;
        _loadingMyActivities = false;
      });
    } catch (e) {
      debugPrint('Error loading my activities: $e');
      setState(() => _loadingMyActivities = false);
    }
  }

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
                : _myActivities.isEmpty
                    ? const Center(
                        child: Text(
                          'You haven\'t recorded any activities yet.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _myActivities.length,
                        itemBuilder: (context, index) {
                          final act = _myActivities[index];
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
                                        Text(
                                          '$type Session',
                                          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Distance: ${distance.toStringAsFixed(0)} m  •  Duration: ${_formatDuration(duration)}',
                                          style: const TextStyle(color: Colors.black54, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),

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
    );
  }

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
}
