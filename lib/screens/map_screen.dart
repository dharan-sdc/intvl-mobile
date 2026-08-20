import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import '../app_state.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  LatLng? _lastCenteredLocation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final state = Provider.of<AppState>(context, listen: false);
      state.addListener(_onStateChanged);
      await state.determineAndSetCurrentLocation();
      if (mounted) {
        _mapController.move(state.centerLocation, 14.5);
      }
    });
  }

  @override
  void dispose() {
    final state = Provider.of<AppState>(context, listen: false);
    state.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (!mounted) return;
    final state = Provider.of<AppState>(context, listen: false);
    
    // Auto-center during active real GPS tracking
    if (state.isRecording && !state.isSimulationMode) {
      if (_lastCenteredLocation != state.centerLocation) {
        _lastCenteredLocation = state.centerLocation;
        _mapController.move(state.centerLocation, _mapController.camera.zoom);
      }
    }
  }

  Color _parseColor(String hex, {double opacity = 1.0}) {
    final clean = hex.replaceAll('#', '');
    final val = int.parse('FF$clean', radix: 16);
    return Color(val).withOpacity(opacity);
  }

  String _formatDuration(int totalSeconds) {
    final minutes = (totalSeconds / 60).floor().toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _showHistoryBottomSheet(BuildContext context, AppState state, int territoryId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'TERRITORY HISTORY',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.black54),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(color: Colors.black12),
              Expanded(
                child: state.territoryHistoryLogs.isEmpty
                    ? const Center(
                        child: Text(
                          'No history recorded yet.',
                          style: TextStyle(color: Colors.black54),
                        ),
                      )
                    : ListView.builder(
                        itemCount: state.territoryHistoryLogs.length,
                        itemBuilder: (c, idx) {
                          final logEntry = state.territoryHistoryLogs[idx];
                          final action = logEntry['action'] ?? 'EVENT';
                          final desc = logEntry['description'] ?? '';
                          final actorName = logEntry['actorName'] ?? 'SYSTEM';
                          final timestamp = logEntry['timestamp'] != null 
                              ? logEntry['timestamp'].toString().substring(0, 10) 
                              : '';

                          IconData iconData = Icons.info_outline;
                          Color iconColor = Colors.grey;

                          switch (action) {
                            case 'CREATED':
                              iconData = Icons.add_box;
                              iconColor = Colors.greenAccent;
                              break;
                            case 'ATTACK_STARTED':
                            case 'ATTACKED':
                              iconData = Icons.colorize_outlined;
                              iconColor = Colors.orangeAccent;
                              break;
                            case 'DEFENDED':
                              iconData = Icons.shield;
                              iconColor = Colors.blueAccent;
                              break;
                            case 'CAPTURED':
                              iconData = Icons.flag;
                              iconColor = Colors.redAccent;
                              break;
                          }

                          return ListTile(
                            leading: Icon(iconData, color: iconColor),
                            title: Text(
                              desc,
                              style: const TextStyle(color: Colors.black87, fontSize: 13),
                            ),
                            subtitle: Text(
                              'By $actorName • $timestamp',
                              style: const TextStyle(color: Colors.black54, fontSize: 11),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);

    // Convert loaded territories into flutter_map Polygons
    final List<Polygon> mapPolygons = [];
    for (var t in state.territories) {
      final isSelected = t.id == state.targetTerritoryId;
      Color color = _parseColor(t.color, opacity: 0.3);
      Color borderColor = _parseColor(t.color, opacity: 0.8);
      double borderStroke = isSelected ? 6.0 : 3.0;

      // Under attack/critical border coloring overrides
      if (t.status == 'CRITICAL' || t.status == 'CAPTURE_WINDOW') {
        borderColor = Colors.redAccent;
        color = Colors.red.withOpacity(0.35);
      } else if (t.status == 'WEAKENED' || t.status == 'CONTESTED') {
        borderColor = Colors.orangeAccent;
        color = Colors.orange.withOpacity(0.3);
      }

      for (var path in t.paths) {
        if (path.length >= 3) {
          mapPolygons.add(
            Polygon(
              points: path,
              color: color,
              borderColor: borderColor,
              borderStrokeWidth: borderStroke,
              isFilled: true,
            ),
          );
        }
      }
    }

    return Scaffold(
      body: Stack(
        children: [
          // 1. Flutter Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: state.centerLocation,
              initialZoom: 14.5,
              onTap: (tapPosition, point) {
                if (state.isRecording) {
                  state.addCoordinate(point);
                } else {
                  // Find closest territory to focused tap
                  double minDistance = 99999.0;
                  TerritoryModel? closest;
                  for (var t in state.territories) {
                    for (var path in t.paths) {
                      for (var pt in path) {
                        double dist = const Distance().as(
                          LengthUnit.Meter,
                          LatLng(pt.latitude, pt.longitude),
                          LatLng(point.latitude, point.longitude),
                        );
                        if (dist < minDistance) {
                          minDistance = dist;
                          closest = t;
                        }
                      }
                    }
                  }
                  if (minDistance < 300.0 && closest != null) {
                    state.selectTargetTerritory(closest.id);
                  } else {
                    state.selectTargetTerritory(null);
                  }
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                maxZoom: 19,
                userAgentPackageName: 'com.fitterra.app',
                tileProvider: NetworkTileProvider(
                  headers: Map<String, String>.from({
                    'User-Agent': 'FitTerra Mobile App v1.0.0 (contact@fitterra.com) package com.fitterra.app',
                  }),
                ),
              ),
              PolygonLayer(polygons: mapPolygons),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: state.pathPoints,
                    color: state.injectVelocityCheat ? Colors.redAccent : const Color(0xFF00E676),
                    strokeWidth: 4.5,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  // Live Current Location Marker (Blue Dot)
                  Marker(
                    point: state.centerLocation,
                    width: 26,
                    height: 26,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF007AFF).withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: const Color(0xFF007AFF),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.25),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (state.pathPoints.isNotEmpty)
                    Marker(
                      point: state.pathPoints.first,
                      width: 14,
                      height: 14,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF00B0FF),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  if (state.pathPoints.length >= 2)
                    Marker(
                      point: state.pathPoints.last,
                      width: 14,
                      height: 14,
                      child: Container(
                        decoration: BoxDecoration(
                          color: state.snapClosure ? const Color(0xFF00B0FF) : Colors.orangeAccent,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // 2. Premium Game Header / Profile Stats Bar
          Positioned(
            top: 50,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.92),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE040FB).withOpacity(0.4), width: 1.5),
                boxShadow: [
                  BoxShadow(color: const Color(0xFFE040FB).withOpacity(0.1), blurRadius: 10, spreadRadius: 2)
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: _parseColor(state.color),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            state.username ?? 'EXPLORER',
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Level ${state.level} • XP ${state.xp}',
                        style: const TextStyle(color: Colors.black87, fontSize: 11),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Column(
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.monetization_on, color: Colors.amber, size: 14),
                              SizedBox(width: 4),
                              Text('COINS', style: TextStyle(color: Colors.black54, fontSize: 8)),
                            ],
                          ),
                          Text(
                            '${state.coins}',
                            style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Column(
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.local_fire_department, color: Colors.orange, size: 14),
                              SizedBox(width: 4),
                              Text('STREAK', style: TextStyle(color: Colors.black54, fontSize: 8)),
                            ],
                          ),
                          Text(
                            '${state.streak} Days',
                            style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 3. Tapping Hint (Only when recording)
          if (state.isRecording)
            Positioned(
              top: 120,
              left: 20,
              right: 20,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE040FB), width: 1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.touch_app, color: Color(0xFFE040FB), size: 16),
                      const SizedBox(width: 8),
                      Text(
                        state.targetTerritoryId != null 
                            ? 'RUN INSIDE THE ATTACK ZONE' 
                            : 'TAP THE MAP TO SIMULATE YOUR ROUTE',
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 4. Control Panels (Bottom Overlays)
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!state.isRecording) ...[
                  // Case A: Target Territory Focused Dashboard Card
                  if (state.targetTerritoryId != null) ...[
                    _buildBattleDashboardCard(context, state),
                    const SizedBox(height: 12),
                  ],

                  // Case B: General Activity Session Chips and Start Button
                  _buildStartSessionCard(state),
                ] else ...[
                  // Case C: Active tracking fitness panel
                  _buildTrackingSessionCard(state),
                ],
              ],
            ),
          ),

          // 5. My Location Button
          Positioned(
            right: 16,
            bottom: state.isRecording 
                ? 180 
                : (state.targetTerritoryId != null ? 360 : 200),
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white.withOpacity(0.92),
              foregroundColor: const Color(0xFFE040FB),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: const Color(0xFFE040FB).withOpacity(0.4), width: 1.5),
              ),
              onPressed: () async {
                await state.determineAndSetCurrentLocation(forceOpenSettings: true);
                _mapController.move(state.centerLocation, 14.5);
              },
              child: const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartSessionCard(AppState state) {
    return Card(
      color: Colors.white.withOpacity(0.95),
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.shade200, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: ['RUN', 'WALK', 'CYCLE'].map((sport) {
                final isSelected = state.activityType == sport;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: ChoiceChip(
                    label: Text(sport),
                    selected: isSelected,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                    selectedColor: const Color(0xFFE040FB),
                    backgroundColor: Colors.grey.shade200,
                    onSelected: (val) {
                      if (val) state.selectActivityType(sport);
                    },
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.gps_fixed, color: Color(0xFFE040FB), size: 16),
                const SizedBox(width: 8),
                const Text(
                  'REAL GPS TRACKING',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: !state.isSimulationMode,
                  activeColor: const Color(0xFFE040FB),
                  onChanged: (val) {
                    state.toggleSimulationMode(!val);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: () => state.startRecording(),
                icon: const Icon(Icons.play_arrow, color: Colors.white),
                label: const Text(
                  'START GENERAL FITNESS ROUTE',
                  style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE040FB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackingSessionCard(AppState state) {
    return Card(
      color: Colors.white.withOpacity(0.95),
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF00E676), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatWidget(
                  label: 'DISTANCE',
                  value: '${state.distanceMeters.toStringAsFixed(0)} m',
                  icon: Icons.directions_run,
                ),
                _buildStatWidget(
                  label: 'TIME',
                  value: _formatDuration(state.durationSeconds),
                  icon: Icons.timer,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => state.cancelRecording(),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.redAccent),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('CANCEL', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: state.isLoading ? null : () async {
                      final res = await state.completeAndSubmitActivity();
                      if (res != null && mounted) {
                        if (res['status'] == 'REJECTED') {
                          _showStatusDialog(
                            title: 'Activity Rejected ❌',
                            message: 'Anti-cheat validation failed due to velocity anomalies or spoofing pattern matching. Progress voided.',
                            isSuccess: false,
                          );
                        } else if (res['status'] == 'ERROR') {
                          _showStatusDialog(
                            title: 'Submission Failed ⚠️',
                            message: res['error'] ?? 'An error occurred while saving your activity. Please try again.',
                            isSuccess: false,
                          );
                        } else if (res['isClosedLoop'] == true && res['territoryArea'] != null) {
                          final area = (res['territoryArea'] as num).toStringAsFixed(0);
                          _showStatusDialog(
                            title: 'Loop Complete! 🏰',
                            message: 'You successfully enclosed unclaimed cells and claimed a new territory of $area m²!',
                            isSuccess: true,
                          );
                        } else if (res['isClosedLoop'] == true) {
                          _showStatusDialog(
                            title: 'Loop Complete! 🏁',
                            message: 'Your route was recorded as a closed loop, but no new unclaimed cells were enclosed within it.',
                            isSuccess: true,
                          );
                        } else {
                          _showStatusDialog(
                            title: 'Activity Saved 🏁',
                            message: 'Your route was recorded. To claim territory directly, ensure your activity forms a closed loop.',
                            isSuccess: true,
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E676),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      state.isLoading ? 'VALIDATING...' : 'COMPLETE & CLAIM',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBattleDashboardCard(BuildContext context, AppState state) {
    // Find target territory model
    final territory = state.territories.firstWhere((t) => t.id == state.targetTerritoryId, 
        orElse: () => TerritoryModel(id: 0, ownerId: 0, ownerName: 'Unknown', color: '#888888', area: 0, level: 1, defenseScore: 1000, status: 'OWNED', paths: []));

    if (territory.id == 0) return const SizedBox.shrink();

    final isOwner = territory.ownerId == state.userId;
    Color statusColor = Colors.greenAccent;
    if (territory.status == 'CRITICAL' || territory.status == 'CAPTURE_WINDOW') {
      statusColor = Colors.redAccent;
    } else if (territory.status == 'WEAKENED' || territory.status == 'CONTESTED') {
      statusColor = Colors.orangeAccent;
    }

    return Card(
      color: Colors.white.withOpacity(0.96),
      elevation: 10,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: statusColor.withOpacity(0.6), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Territory Details & Exits
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TERRITORY #TR-${territory.id}',
                      style: const TextStyle(color: Colors.black54, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Owner: ${territory.ownerName} ${isOwner ? "(You)" : ""}',
                      style: const TextStyle(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor, width: 1),
                  ),
                  child: Text(
                    territory.status,
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.layers, color: Colors.black45, size: 14),
                const SizedBox(width: 4),
                Text('Level ${territory.level}', style: const TextStyle(color: Colors.black54, fontSize: 11)),
                const SizedBox(width: 16),
                const Icon(Icons.aspect_ratio, color: Colors.black45, size: 14),
                const SizedBox(width: 4),
                Text('${territory.area.toStringAsFixed(0)} m²', style: const TextStyle(color: Colors.black54, fontSize: 11)),
              ],
            ),
            const Divider(color: Colors.black12, height: 24),

            // Row 2: Battle Score details
            if (state.activeBattle != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Attacker: ${state.activeBattle!.attackerName}',
                    style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Net Capture Progress: ${(state.activeBattle!.captureProgress * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(color: Colors.black87, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: state.activeBattle!.captureProgress,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '⚔️ Attack Score: ${state.activeBattle!.attackScore}',
                    style: const TextStyle(color: Colors.orangeAccent, fontSize: 11),
                  ),
                  Text(
                    '🛡️ Defense Score: ${state.activeBattle!.defenseScore}',
                    style: const TextStyle(color: Colors.blueAccent, fontSize: 11),
                  ),
                ],
              ),
              if (territory.status == 'CAPTURE_WINDOW' && state.activeBattle!.captureWindowExpiresAt != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.timer, color: Colors.redAccent, size: 13),
                    const SizedBox(width: 4),
                    Text(
                      'Capture Window expires in: ${state.activeBattle!.captureWindowExpiresAt!.difference(DateTime.now()).inHours} hours',
                      style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ] else ...[
              // Standalone / Preparation Status
              if (!isOwner) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Attack Preparation Progress', style: TextStyle(color: Colors.black87, fontSize: 12)),
                    Text('${state.attackPrepDays}/7 Days Completed', style: const TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: state.attackPrepDays / 7.0,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.orangeAccent),
                    minHeight: 6,
                  ),
                ),
              ] else ...[
                const Row(
                  children: [
                    Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 16),
                    SizedBox(width: 8),
                    Text('Fortified Defense: 1000/1000', style: TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ],

            const SizedBox(height: 16),

            // Row 3: Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      state.startRecording();
                    },
                    icon: Icon(
                      isOwner ? Icons.shield : (territory.status == 'CAPTURE_WINDOW' ? Icons.flag : Icons.colorize),
                      color: Colors.black,
                      size: 16,
                    ),
                    label: Text(
                      isOwner 
                          ? 'DEFEND ZONE' 
                          : (territory.status == 'CAPTURE_WINDOW' ? 'FINAL CAPTURE' : (state.attackPrepStarted ? 'ATTACK ZONE' : 'ATTACK PREP RUN')),
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: statusColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () {
                    _showHistoryBottomSheet(context, state, territory.id);
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('HISTORY', style: TextStyle(color: Colors.black87, fontSize: 10)),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.black54, size: 20),
                  onPressed: () => state.selectTargetTerritory(null),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatWidget({required String label, required String value, required IconData icon}) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFFE040FB), size: 14),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.black54, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(color: Colors.black87, fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  void _showStatusDialog({required String title, required String message, required bool isSuccess}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        content: Text(message, style: const TextStyle(color: Colors.black54)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'OK',
              style: TextStyle(
                color: isSuccess ? Colors.greenAccent : Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
