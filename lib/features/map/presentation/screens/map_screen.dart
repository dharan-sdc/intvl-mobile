import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile/app_state.dart';
import 'package:mobile/shared/widgets/celebration_dialog.dart';
import 'package:mobile/widgets/contextual_tip_banner.dart';
import 'package:mobile/screens/user_guide_screen.dart';

/// Interactive map screen showing GPS paths, territories claimed, and real-time navigation controls.
///
/// [Why] Acts as the primary interface of the game, letting users explore, 
/// start workout routes, and visually target and capture/defend H3 hex-polygon zones.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

/// The state controller for MapScreen responsible for managing map interactions, 
/// location updates, and rendering map-specific UI components like markers and polygons.
class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  LatLng? _lastCenteredLocation;
  Timer? _mapRefreshTimer;
  AppState? _appState;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = Provider.of<AppState>(context, listen: false);
    if (_appState != state) {
      _appState?.removeListener(_onStateChanged);
      _appState = state;
      _appState?.addListener(_onStateChanged);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _appState == null) return;
      final state = _appState!;
      
      // 1. Immediately center map camera to cached position or home base on first frame
      final target = state.userLiveLocation ?? state.centerLocation;
      _lastCenteredLocation = target;
      try {
        _mapController.move(target, 15.0);
      } catch (_) {}

      // 2. Refresh territories and activities immediately on map load
      state.fetchTerritories(force: true);
      if (state.userId != null) {
        state.fetchActivities(force: true);
        state.syncPendingOfflineActivities();
      }

      // 3. Resolve fresh GPS location
      state.determineAndSetCurrentLocation(userInitiated: false);
    });

    // 4. Periodic background refresh every 45 seconds ONLY when active on the map tab (when not recording)
    _mapRefreshTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (mounted && _appState != null) {
        final state = _appState!;
        if (state.currentTab == 0 && !state.isRecording) {
          state.fetchTerritories();
          if (state.userId != null) {
            state.fetchActivities();
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _mapRefreshTimer?.cancel();
    _mapRefreshTimer = null;
    _appState?.removeListener(_onStateChanged);
    _appState = null;
    super.dispose();
  }

  /// Triggers map panning updates when the device resolves a new GPS position coordinates node.
  ///
  /// [Why] Automatically keeps the map centered on the player when camera follow mode is active.
  void _onStateChanged() {
    if (!mounted || _appState == null) return;
    final state = _appState!;
    
    // Auto-center camera only if camera follow mode is active
    if (state.isCameraFollowingUser && state.userLiveLocation != null) {
      if (_lastCenteredLocation != state.userLiveLocation) {
        _lastCenteredLocation = state.userLiveLocation;
        try {
          final zoom = _mapController.camera.zoom > 0 ? _mapController.camera.zoom : 15.5;
          _mapController.move(state.userLiveLocation!, zoom);
        } catch (_) {}
      }
    } else if (_lastCenteredLocation == null) {
      _lastCenteredLocation = state.centerLocation;
      try {
        _mapController.move(state.centerLocation, 14.5);
      } catch (_) {}
    }
  }

  /// Shows the friendly in-app dialog when device location / GPS services are turned off.
  void _showEnableGpsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.location_off, color: Color(0xFFE040FB)),
            SizedBox(width: 10),
            Text(
              'Turn On Location',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: const Text(
          'Location services (GPS) are currently turned off on your device. Please turn on location to view your live position, track runs, and conquer territories.',
          style: TextStyle(fontSize: 14, color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Not Now', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await Geolocator.openLocationSettings();
            },
            icon: const Icon(Icons.settings, size: 16),
            label: const Text('Turn On Location'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE040FB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  /// Shows settings redirection dialog when location permission has been permanently denied.
  void _showPermissionSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.security, color: Color(0xFFE040FB)),
            SizedBox(width: 10),
            Text(
              'Location Access',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: const Text(
          'Location access is required to track your GPS workouts. Please enable location permission in your device app settings.',
          style: TextStyle(fontSize: 14, color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await Geolocator.openAppSettings();
            },
            icon: const Icon(Icons.settings, size: 16),
            label: const Text('Open Settings'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE040FB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  /// Validates GPS service and location permissions before starting a recording session.
  Future<void> _handleStartRecording(AppState state) async {
    if (!state.isSimulationMode) {
      final isGpsOn = await Geolocator.isLocationServiceEnabled();
      if (!isGpsOn) {
        _showEnableGpsDialog();
        return;
      }
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        state.hasRequestedLocationPermission = true;
      }
      if (perm == LocationPermission.deniedForever) {
        _showPermissionSettingsDialog();
        return;
      }
      if (perm == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission is required for real GPS tracking.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }
    }
    state.startRecording();
  }

  /// Displays dialog allowing the user to set the current map view center as their persistent Home Base.
  void _showSetHomeLocationDialog(AppState state) {
    final currentCenter = _mapController.camera.center;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.home, color: Color(0xFFE040FB)),
            SizedBox(width: 10),
            Text('Set Home Base', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text(
          'Set current map position (${currentCenter.latitude.toStringAsFixed(4)}, ${currentCenter.longitude.toStringAsFixed(4)}) as your permanent Home Base?\n\nThe map will automatically open here every time.',
          style: const TextStyle(fontSize: 14, color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await state.setHomeLocation(currentCenter);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🏠 Home Base saved successfully!'),
                    backgroundColor: Color(0xFFE040FB),
                  ),
                );
              }
            },
            icon: const Icon(Icons.check, size: 16),
            label: const Text('Save Home Base'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE040FB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  /// Parses hex color strings into Color classes.
  Color _parseColor(String hex, {double opacity = 1.0}) {
    final clean = hex.replaceAll('#', '');
    final val = int.parse('FF$clean', radix: 16);
    return Color(val).withOpacity(opacity);
  }

  /// Utility to convert seconds into `MM:SS` format.
  String _formatDuration(int totalSeconds) {
    final minutes = (totalSeconds / 60).floor().toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// Shows the history logs bottom drawer list for a specific territory.
  ///
  /// [Why] Displays list of sieges, defenses, and creation logs.
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
      Color color = t.parsedColor.withOpacity(0.3);
      Color borderColor = t.parsedColor.withOpacity(0.8);
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

    // Live Loop Completion Preview Polygon
    if (state.isRecording && state.isLoopCompleted && state.pathPoints.length >= 3) {
      mapPolygons.add(
        Polygon(
          points: state.pathPoints,
          color: const Color(0xFF00E676).withOpacity(0.22),
          borderColor: const Color(0xFF00E676),
          borderStrokeWidth: 2.0,
          isFilled: true,
        ),
      );
    }

    final List<Polyline> completedPolylines = [];
    for (var act in state.activities) {
      final pointsData = act['points'] as List<dynamic>?;
      if (pointsData != null && pointsData.isNotEmpty) {
        final List<LatLng> points = pointsData.map((pt) {
          final lat = (pt['lat'] as num).toDouble();
          final lng = (pt['lng'] as num).toDouble();
          return LatLng(lat, lng);
        }).toList();

        if (points.length >= 2) {
          final status = act['status'] as String? ?? 'COMPLETED';
          final isFailed = status == 'FAILED_TERRITORY';
          
          completedPolylines.add(
            Polyline(
              points: points,
              strokeWidth: isFailed ? 3.0 : 4.5,
              borderColor: isFailed 
                  ? Colors.redAccent.withOpacity(0.3) 
                  : const Color(0xFFE040FB).withOpacity(0.3),
              borderStrokeWidth: 1.0,
              color: isFailed 
                  ? Colors.red.withOpacity(0.6) 
                  : const Color(0xFFE040FB).withOpacity(0.6),
              strokeCap: StrokeCap.round,
              strokeJoin: StrokeJoin.round,
            ),
          );
        }
      }
    }

    final List<Marker> mapMarkers = [];

    // Add small start point markers for completed activities
    for (var act in state.activities) {
      final pointsData = act['points'] as List<dynamic>?;
      if (pointsData != null && pointsData.isNotEmpty) {
        final List<LatLng> points = pointsData.map((pt) {
          final lat = (pt['lat'] as num).toDouble();
          final lng = (pt['lng'] as num).toDouble();
          return LatLng(lat, lng);
        }).toList();

        if (points.length >= 2) {
          final status = act['status'] as String? ?? 'COMPLETED';
          final isFailed = status == 'FAILED_TERRITORY';
          final startPoint = points.first;
          
          mapMarkers.add(
            Marker(
              point: startPoint,
              width: 10,
              height: 10,
              child: Container(
                decoration: BoxDecoration(
                  color: isFailed ? Colors.redAccent : const Color(0xFFE040FB),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
          );
        }
      }
    }

    // Add Live Current Location Marker (Blue Dot)
    final liveMarkerPoint = state.userLiveLocation ?? state.centerLocation;
    mapMarkers.add(
      Marker(
        point: liveMarkerPoint,
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
    );

    // Add Home Base Marker if registered
    if (state.homeLocation != null) {
      mapMarkers.add(
        Marker(
          point: state.homeLocation!,
          width: 32,
          height: 32,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFE040FB),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE040FB).withOpacity(0.4),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.home, color: Colors.white, size: 18),
          ),
        ),
      );
    }

    if (state.pathPoints.isNotEmpty) {
      mapMarkers.add(
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
      );
    }
    if (state.pathPoints.length >= 2) {
      mapMarkers.add(
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
      );
    }

    // Add territory center owner avatar markers!
    for (var t in state.territories) {
      for (var path in t.paths) {
        if (path.isNotEmpty) {
          final center = _calculateCentroid(path);
          final initial = t.ownerName.isNotEmpty ? t.ownerName[0].toUpperCase() : '?';
          final color = t.parsedColor;
          final isCritical = t.status == 'CRITICAL' || t.status == 'CAPTURE_WINDOW';
          final isTargetedAndReady = state.targetTerritoryId == t.id && state.attackPrepDays >= state.attackPrepRequiredDays;
          final showCrown = isCritical || isTargetedAndReady;

          mapMarkers.add(
            Marker(
              point: center,
              width: 50,
              height: 50,
              child: GestureDetector(
                onTap: () {
                  _showOwnerDetailsPopup(context, state, t);
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 6,
                            spreadRadius: 1,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(2.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              initial,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (showCrown)
                      const Positioned(
                        top: -14,
                        right: 8,
                        child: Text(
                          '👑',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
          // Only add a marker for the first path of the territory to avoid duplicates
          break;
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
              onPositionChanged: (camera, hasGesture) {
                if (hasGesture) {
                  state.setCameraFollowMode(false);
                  state.saveLastCenteredLocation(camera.center);
                }
              },
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
                userAgentPackageName: 'com.trion.app',
                evictErrorTileStrategy: EvictErrorTileStrategy.none,
                errorTileCallback: (tile, error, stackTrace) {
                  // Gracefully ignore offline DNS/network errors for tile rendering
                },
                tileProvider: NetworkTileProvider(
                  headers: Map<String, String>.from({
                    'User-Agent': 'TRION Mobile App v1.0.0 (contact@trion.com) package com.trion.app',
                  }),
                ),
              ),
              PolygonLayer(polygons: mapPolygons),
              PolylineLayer(
                polylines: [
                  ...completedPolylines,
                  Polyline(
                    points: state.pathPoints,
                    strokeWidth: 6.0,
                    borderColor: Colors.black.withOpacity(0.3),
                    borderStrokeWidth: 1.5,
                    strokeCap: StrokeCap.round,
                    strokeJoin: StrokeJoin.round,
                    gradientColors: state.injectVelocityCheat
                        ? [Colors.redAccent, Colors.red.shade900]
                        : [const Color(0xFF00E676), const Color(0xFF00B0FF)],
                  ),
                ],
              ),
              MarkerLayer(markers: mapMarkers),
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
                      const SizedBox(width: 14),
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
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.help_outline, color: Color(0xFFE040FB), size: 20),
                        tooltip: 'Tactical Field Manual',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const UserGuideScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 2.3 GPS Acquisition / Disabled / Lost Signal Indicator Banner
          if (!state.isGpsEnabled || (state.isRecording && !state.hasGpsSignal) || (!state.isRecording && state.activeInvitationId == null && state.isLocating && state.userLiveLocation == null))
            Positioned(
              top: 120,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: (!state.isGpsEnabled
                          ? Colors.red.shade900
                          : (state.isRecording && !state.hasGpsSignal
                              ? Colors.amber.shade900
                              : Colors.indigo.shade900))
                      .withOpacity(0.92),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 6),
                  ],
                ),
                child: Row(
                  children: [
                    if (!state.isGpsEnabled)
                      const Icon(Icons.location_off, color: Colors.white, size: 16)
                    else if (state.isRecording && !state.hasGpsSignal)
                      const Icon(Icons.gps_not_fixed, color: Colors.white, size: 16)
                    else
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                      ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        !state.isGpsEnabled
                            ? 'Location is turned OFF on device. Tap to enable.'
                            : (state.isRecording && !state.hasGpsSignal
                                ? 'Searching for GPS satellite fix...'
                                : 'Acquiring high-accuracy GPS position...'),
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (!state.isGpsEnabled)
                      TextButton(
                        onPressed: () => Geolocator.openLocationSettings(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('ENABLE', style: TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                  ],
                ),
              ),
            ),

          // 2.5 Active Challenge Selected Banner
          if (state.activeInvitationId != null && !state.isRecording)
            Positioned(
              top: 120,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green, width: 1.5),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.directions_run, color: Colors.green, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ROUTE CHALLENGE ACTIVE',
                            style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1.2),
                          ),
                          Text(
                            'Follow friend\'s route to earn +150 XP!',
                            style: TextStyle(color: Colors.green.shade800, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.redAccent, size: 20),
                      onPressed: () {
                        state.selectRouteChallenge(null);
                      },
                    ),
                  ],
                ),
              ),
            ),

          // 2.7 Pending Offline Sync Banner
          if (state.pendingOfflineActivities.isNotEmpty && !state.isRecording)
            Positioned(
              top: state.activeInvitationId != null ? 180 : 120,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade700, width: 1.2),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.cloud_off, color: Colors.amber.shade800, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'OFFLINE WORKOUTS SAVED',
                            style: TextStyle(color: Colors.brown, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1.1),
                          ),
                          Text(
                            '${state.pendingOfflineActivities.length} workout(s) stored locally on device',
                            style: TextStyle(color: Colors.amber.shade900, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: state.isSyncingOfflineActivities
                          ? null
                          : () async {
                              final messenger = ScaffoldMessenger.of(context);
                              final result = await state.syncPendingOfflineActivities();
                              if (result['synced'] > 0) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text('Successfully synced ${result['synced']} offline workout(s)!'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: const Size(60, 32),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(
                        state.isSyncingOfflineActivities ? 'SYNCING...' : 'SYNC NOW',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 2.9 Contextual Discovery Tip (Dismissable)
          if (!state.isRecording && state.activeInvitationId == null && state.pendingOfflineActivities.isEmpty)
            const Positioned(
              top: 110,
              left: 0,
              right: 0,
              child: ContextualTipBanner(
                tipId: 'map_loop_conquest',
                title: 'TERRITORY CONQUEST',
                message: 'Walk, run, or cycle in a closed loop around any area to capture that H3 hexagon for your profile!',
                icon: Icons.radar,
                accentColor: Color(0xFFE040FB),
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

          // 5. Floating Controls (Home Base + My Location)
          Positioned(
            right: 16,
            bottom: state.isRecording 
                ? 180 
                : (state.targetTerritoryId != null ? 360 : 200),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Live Sync / Refresh Territories FAB
                FloatingActionButton(
                  mini: true,
                  heroTag: 'refresh_territories_fab',
                  backgroundColor: Colors.white.withOpacity(0.95),
                  foregroundColor: const Color(0xFF00E676),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: const Color(0xFF00E676).withOpacity(0.5), width: 1.5),
                  ),
                  tooltip: 'Refresh Territories & Routes',
                  onPressed: () async {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('🔄 Refreshing live territory map and routes...'),
                        duration: Duration(milliseconds: 1000),
                      ),
                    );
                    await state.fetchTerritories(force: true);
                    if (state.userId != null) {
                      await state.fetchActivities(force: true);
                    }
                  },
                  child: const Icon(Icons.sync),
                ),
                const SizedBox(height: 8),

                // Home Base Quick Jump & Long-Press Setter
                FloatingActionButton(
                  mini: true,
                  heroTag: 'home_base_fab',
                  backgroundColor: Colors.white.withOpacity(0.95),
                  foregroundColor: const Color(0xFFE040FB),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: const Color(0xFFE040FB).withOpacity(0.5), width: 1.5),
                  ),
                  tooltip: state.homeLocation != null ? 'Go to Home Base (Long-press to update)' : 'Set Current Map as Home Base',
                  onPressed: () {
                    if (state.homeLocation != null) {
                      _mapController.move(state.homeLocation!, 15.0);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('🏠 Centered on Home Base'),
                          duration: Duration(milliseconds: 1500),
                        ),
                      );
                    } else {
                      _showSetHomeLocationDialog(state);
                    }
                  },
                  child: const Icon(Icons.home),
                ),
                const SizedBox(height: 8),

                // My Location FAB with Smart GPS / Permission Handling & Recenter
                FloatingActionButton(
                  mini: true,
                  heroTag: 'my_location_fab',
                  backgroundColor: Colors.white.withOpacity(0.95),
                  foregroundColor: state.isCameraFollowingUser ? const Color(0xFF00E5FF) : const Color(0xFFE040FB),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: state.isCameraFollowingUser ? const Color(0xFF00E5FF) : const Color(0xFFE040FB).withOpacity(0.5),
                      width: 1.5,
                    ),
                  ),
                  tooltip: 'Recenter on My Location',
                  onPressed: () async {
                    final isGpsOn = await Geolocator.isLocationServiceEnabled();
                    if (!isGpsOn) {
                      _showEnableGpsDialog();
                      return;
                    }
                    state.setCameraFollowMode(true);
                    final success = await state.determineAndSetCurrentLocation(userInitiated: true);
                    if (mounted) {
                      final targetLoc = state.userLiveLocation ?? state.centerLocation;
                      _lastCenteredLocation = targetLoc;
                      try {
                        _mapController.move(targetLoc, 15.5);
                      } catch (_) {}
                      if (state.userLiveLocation != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('📍 Centered on your live GPS location'),
                            duration: Duration(milliseconds: 1500),
                          ),
                        );
                      } else if (!success) {
                        LocationPermission perm = await Geolocator.checkPermission();
                        if (perm == LocationPermission.deniedForever) {
                          _showPermissionSettingsDialog();
                        }
                      }
                    }
                  },
                  child: Icon(
                    state.isCameraFollowingUser ? Icons.my_location : Icons.location_searching,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the dashboard card allowing the player to select sport types and launch tracking.
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
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => _handleStartRecording(state),
                icon: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
                label: const Text(
                  'START WORKOUT ROUTE',
                  style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE040FB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the tracking session metrics view overlay displaying distance/time statistics.
  ///
  /// [Why] Provides real-time workout stats during active recording, 
  /// with buttons to cancel or submit completed loops.
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
            if (state.isLoopCompleted)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E676).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF00E676), width: 1.5),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: Color(0xFF00C853), size: 18),
                    SizedBox(width: 8),
                    Text(
                      'LOOP COMPLETED - Ready to Capture! 🏰',
                      style: TextStyle(
                        color: Color(0xFF007E33),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              )
            else if (state.pathPoints.length >= 2)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.near_me, color: Colors.blueAccent, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'Distance to start: ${state.distanceToStart.toStringAsFixed(0)} m (Return to start to close loop)',
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 11),
                    ),
                  ],
                ),
              ),
            // Multi-Campaign Contributing Indicator
            if (state.myCampaigns.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE040FB).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE040FB).withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.track_changes, color: Color(0xFFE040FB), size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'Contributing to ${state.myCampaigns.length} ${state.myCampaigns.length == 1 ? 'Campaign' : 'Campaigns'} (${state.myCampaigns.take(3).map((c) => c.iconEmoji).join(' ')})',
                      style: const TextStyle(color: Color(0xFFE040FB), fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ],
                ),
              ),
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
                      final initialLevel = state.level;
                      final savedDistance = state.distanceMeters;
                      final savedDuration = state.durationSeconds;
                      final res = await state.completeAndSubmitActivity();
                      if (res != null && mounted) {
                        if (res['status'] == 'SAVED_OFFLINE') {
                          _showStatusDialog(
                            title: 'Saved Offline 📡',
                            message: res['message'] ?? 'Network is disconnected. Your walk and loop have been safely stored on your device and will automatically sync when you reconnect!',
                            isSuccess: true,
                          );
                        } else if (res['status'] == 'REJECTED') {
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
                        } else {
                          final impacts = state.lastWorkoutCampaignImpacts;
                          if (res['isClosedLoop'] == true && res['territoryArea'] != null && (res['territoryArea'] as num) > 0) {
                            final area = (res['territoryArea'] as num).toDouble();
                            await CelebrationDialog.show(
                              context,
                              title: 'VICTORY! TERRITORY CLAIMED! 🏰',
                              message: 'You successfully enclosed unclaimed territory and claimed ${area.toStringAsFixed(0)} m² for your profile!',
                              distanceMeters: savedDistance,
                              durationSeconds: savedDuration,
                              territoryArea: area,
                              xpGained: 250,
                              achievementUnlocked: 'Territory Conqueror',
                              campaignImpacts: impacts,
                            );
                          } else if (res['isClosedLoop'] == true) {
                            await CelebrationDialog.show(
                              context,
                              title: 'LOOP COMPLETED! 🏆',
                              message: 'Great run! You completed a full closed loop route.',
                              distanceMeters: savedDistance,
                              durationSeconds: savedDuration,
                              xpGained: 150,
                              achievementUnlocked: savedDistance >= 5000 ? '5K Milestone' : null,
                              campaignImpacts: impacts,
                            );
                          } else {
                            await CelebrationDialog.show(
                              context,
                              title: 'WORKOUT COMPLETED! 🏁',
                              message: 'Fantastic effort! Your workout telemetry has been logged.',
                              distanceMeters: savedDistance,
                              durationSeconds: savedDuration,
                              xpGained: 100,
                              achievementUnlocked: savedDistance >= 1000 ? 'First Stride' : null,
                              campaignImpacts: impacts,
                            );
                          }

                          // Automatically pop up star badge achievements unlocked
                          final newAchievements = state.consumeNewlyUnlockedAchievements();
                          if (mounted && newAchievements.isNotEmpty) {
                            for (final achievement in newAchievements) {
                              if (mounted) {
                                await CelebrationDialog.showAchievement(
                                  context,
                                  achievement: achievement,
                                );
                              }
                            }
                          }

                          // Automatically pop up missions completed
                          final newMissions = state.consumeNewlyCompletedMissions();
                          if (mounted && newMissions.isNotEmpty) {
                            for (final mission in newMissions) {
                              if (mounted) {
                                await CelebrationDialog.showMission(
                                  context,
                                  mission: mission,
                                );
                              }
                            }
                          }

                          // Check for level up celebration
                          if (mounted && state.level > initialLevel) {
                            final coinBonus = state.level == 5 ? 100 : (state.level == 10 ? 250 : 50);
                            await CelebrationDialog.showLevelUp(
                              context,
                              newLevel: state.level,
                              bonusCoins: coinBonus,
                              unlockedPerk: 'Unlocked New Shop Items & Badges',
                            );
                          }
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

  /// Builds the contestation dashboard card overlay for a clicked territory cell.
  ///
  /// [Why] Shows current claim details, net siege captures progress meters, and defense score levels.
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
                    Text('${state.attackPrepDays}/${state.attackPrepRequiredDays} Days Completed', style: const TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: state.attackPrepRequiredDays > 0 ? state.attackPrepDays / state.attackPrepRequiredDays.toDouble() : 0.0,
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
                      _handleStartRecording(state);
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

  /// Builds a small key-value stat panel inside tracking bars.
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

  /// Calculates the geometric center of a list of coordinates.
  LatLng _calculateCentroid(List<LatLng> points) {
    if (points.isEmpty) return const LatLng(0, 0);
    double latSum = 0;
    double lngSum = 0;
    for (var p in points) {
      latSum += p.latitude;
      lngSum += p.longitude;
    }
    return LatLng(latSum / points.length, lngSum / points.length);
  }

  /// Triggers dialog showing profile details of a territory owner.
  void _showOwnerDetailsPopup(BuildContext context, AppState state, TerritoryModel territory) {
    showDialog(
      context: context,
      builder: (ctx) {
        return OwnerDetailsDialog(state: state, territory: territory);
      },
    );
  }

  /// Displays basic alerts and multi-campaign impact summaries after completing workouts.
  void _showStatusDialog({required String title, required String message, required bool isSuccess}) {
    final state = Provider.of<AppState>(context, listen: false);
    final impacts = state.lastWorkoutCampaignImpacts;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: isSuccess ? const Color(0xFF00E676).withOpacity(0.5) : Colors.redAccent.withOpacity(0.5), width: 1.5),
        ),
        title: Text(title, style: const TextStyle(color: Color(0xFF1A202C), fontWeight: FontWeight.bold, fontSize: 18)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message, style: const TextStyle(color: Color(0xFF4A5568), fontSize: 13, height: 1.4)),
              
              if (impacts.isNotEmpty) ...[
                const SizedBox(height: 16),
                Divider(color: Colors.grey.shade200),
                const SizedBox(height: 8),
                const Row(
                  children: [
                    Icon(Icons.track_changes, color: Color(0xFFE040FB), size: 16),
                    SizedBox(width: 6),
                    Text(
                      'CAMPAIGN IMPACT',
                      style: TextStyle(color: Color(0xFF1A202C), fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...impacts.map((imp) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(imp.iconEmoji, style: const TextStyle(fontSize: 16)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                imp.campaignTitle,
                                style: const TextStyle(color: Color(0xFF1A202C), fontWeight: FontWeight.bold, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '+${imp.pointsEarned} PTS',
                              style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.w900, fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '+${imp.distanceContributedKm.toStringAsFixed(2)} KM Contributed',
                              style: const TextStyle(color: Color(0xFF0097A7), fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${imp.goalPercentage.toStringAsFixed(0)}% Goal',
                              style: const TextStyle(color: Colors.black54, fontSize: 11),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: imp.goalPercentage / 100.0,
                            minHeight: 5,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE040FB)),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
        actions: [
          if (impacts.isNotEmpty)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                state.setTab(1); // Switch to Campaigns tab
              },
              child: const Text('VIEW CAMPAIGNS', style: TextStyle(color: Color(0xFFE040FB), fontWeight: FontWeight.bold)),
            ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isSuccess ? const Color(0xFF00E676) : Colors.redAccent,
              foregroundColor: isSuccess ? Colors.black : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('DONE', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

/// Dialog overlay displaying the level, coins, and streak statistics of a territory owner.
///
/// [Why] Lets players inspect the profile of the person who claimed a territory.
class OwnerDetailsDialog extends StatefulWidget {
  final AppState state;
  final TerritoryModel territory;

  const OwnerDetailsDialog({
    super.key,
    required this.state,
    required this.territory,
  });

  @override
  State<OwnerDetailsDialog> createState() => _OwnerDetailsDialogState();
}

class _OwnerDetailsDialogState extends State<OwnerDetailsDialog> {
  late final Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.state.api.getPlayerStats(widget.territory.ownerId);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (c, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              height: 200,
              alignment: Alignment.center,
              child: const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE040FB)),
              ),
            );
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return Container(
              padding: const EdgeInsets.all(24),
              height: 200,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
                  const SizedBox(height: 12),
                  const Text(
                    'Failed to load owner details',
                    style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.pop(c),
                    child: const Text('CLOSE'),
                  ),
                ],
              ),
            );
          }

          final profile = snapshot.data!;
          final level = profile['level'] ?? 1;
          final xp = profile['xp'] ?? 0;
          final coins = profile['coins'] ?? 0;
          final streak = profile['currentStreak'] ?? 0;
          final color = widget.territory.parsedColor;

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Owner Profile Header
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: color,
                      child: Text(
                        widget.territory.ownerName.isNotEmpty ? widget.territory.ownerName[0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.territory.ownerName.toUpperCase(),
                            style: const TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'User ID: #${widget.territory.ownerId}',
                            style: const TextStyle(color: Colors.black54, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.stars, color: Colors.amber, size: 28),
                  ],
                ),
                const Divider(color: Colors.black12, height: 24),

                // Stats Grid
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildPopupStat('LEVEL', '$level ($xp XP)', Icons.trending_up, Colors.blue),
                    _buildPopupStat('STREAK', '$streak Days', Icons.local_fire_department, Colors.orange),
                    _buildPopupStat('COINS', '$coins', Icons.monetization_on, Colors.amber),
                  ],
                ),
                const SizedBox(height: 16),

                // Territory Details
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Territory ID', style: TextStyle(color: Colors.black54, fontSize: 11)),
                          Text('#TR-${widget.territory.id}', style: const TextStyle(color: Colors.black87, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Territory Area', style: TextStyle(color: Colors.black54, fontSize: 11)),
                          Text('${widget.territory.area.toStringAsFixed(0)} m²', style: const TextStyle(color: Colors.black87, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Defense Strength', style: TextStyle(color: Colors.black54, fontSize: 11)),
                          Text('${widget.territory.defenseScore}/1000', style: const TextStyle(color: Colors.black87, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(c),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('CLOSE', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(c);
                          widget.state.selectTargetTerritory(widget.territory.id);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE040FB),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('SELECT TARGET', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Builds a small vertical stat panel inside owner profile details popup views.
  Widget _buildPopupStat(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.black54, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
      ],
    );
  }
}
