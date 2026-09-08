import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import 'api_service.dart';
import 'error_handler.dart';

/// Operational state of the Unified Location Subsystem.
enum TrackingMode {
  /// App in background/closed and not recording. Hardware GNSS inactive (0% drain).
  idle,

  /// App active in foreground. Live cursor moves on map without sticky notification.
  foregroundLocation,

  /// Active workout recording with high-precision GNSS in foreground.
  activeWorkout,

  /// Active workout recording persisting through background/screen sleep with Foreground Service.
  activeWorkoutBackground,
}

/// Global state management provider for the FitTerra application using ChangeNotifier.
///
/// [Why] Centralizes game engine progression stats, active GPS recording parameters, 
/// friend invitations list, and club profiles under a single reactive data store.
///
/// [How] Components watch or read [AppState] via Provider, triggering widget rebuilds 
/// when [notifyListeners] is called.
class AppState extends ChangeNotifier with WidgetsBindingObserver {
  /// Instance of the HTTP ApiService used to interact with backend endpoints.
  final ApiService api = ApiService();

  // Storage Cache Keys for Offline Resilience
  static const String _keyActiveSession = 'fitterra_active_recording_session';
  static const String _keyPendingActivities = 'fitterra_pending_offline_activities';

  // Offline Synchronization & In-flight State
  List<Map<String, dynamic>> pendingOfflineActivities = [];
  bool isSyncingOfflineActivities = false;
  DateTime? _lastDiskSaveTime;

  // User Guide & Onboarding Flags
  bool hasSeenUserGuide = false;
  bool hasSeenWelcomeOnboarding = false;

  // Backend Connectivity Status
  bool isBackendOnline = false;

  // Unified Location Tracking Subsystem
  TrackingMode trackingMode = TrackingMode.idle;
  LatLng? userLiveLocation;
  bool isCameraFollowingUser = true;
  DateTime? sessionStartTime;
  Duration totalPausedDuration = Duration.zero;

  AppState() {
    WidgetsBinding.instance.addObserver(this);
    _initPersistence();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionStreamSubscription?.cancel();
    _activityTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (isRecording) {
        updateTrackingMode(TrackingMode.activeWorkout);
      } else {
        updateTrackingMode(TrackingMode.foregroundLocation);
      }
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      if (isRecording) {
        updateTrackingMode(TrackingMode.activeWorkoutBackground);
      } else {
        updateTrackingMode(TrackingMode.idle);
      }
    }
  }

  /// Restores cached login session, tests backend health, and syncs offline items.
  Future<void> _initPersistence() async {
    await _loadLocationPreferences();
    await _loadUserGuidePreferences();
    await checkBackendConnection();
    await _restoreUserSession();
    await _loadPendingOfflineActivities();
    await restoreRecordingSession();
    if (isLoggedIn && pendingOfflineActivities.isNotEmpty) {
      syncPendingOfflineActivities();
    }
  }

  /// Tests backend health and updates isBackendOnline status.
  Future<bool> checkBackendConnection() async {
    try {
      final online = await api.checkBackendConnection();
      isBackendOnline = online;
      notifyListeners();
      return online;
    } catch (e) {
      isBackendOnline = false;
      notifyListeners();
      return false;
    }
  }

  // Authentication State
  int? userId;
  String? username;
  String? email;
  String color = '#FF007F';
  double totalTerritoryArea = 0.0;
  bool isLoggedIn = false;
  bool isLoading = false;
  String? errorMessage;
  int currentTab = 0;

  /// Changes the currently active navigation drawer/bar tab.
  ///
  /// [Why] Controls core navigation panel transitions.
  void setTab(int index) {
    currentTab = index;
    notifyListeners();
  }

  /// Clears active error notification messages across screens.
  void clearErrorMessage() {
    if (errorMessage != null) {
      errorMessage = null;
      notifyListeners();
    }
  }

  // Player Game Profile Stats
  int level = 1;
  int xp = 0;
  int coins = 0;
  int streak = 0;
  int territoriesCaptured = 0;
  int territoriesLost = 0;
  int territoriesDefended = 0;
  double totalDistance = 0.0;
  int totalActivities = 0;
  int xpRequiredForCurrentLevel = 0;
  int xpRequiredForNextLevel = 500;
  int contributionScore = 0;

  // Friendship & Route Challenge States
  List<FriendModel> friendsList = [];
  List<FriendshipRequestModel> pendingFriendRequests = [];
  List<RouteInvitationModel> pendingRouteInvitations = [];
  List<RouteInvitationModel> activeRouteInvitations = [];
  List<RouteInvitationModel> sentRouteInvitations = [];
  int? activeInvitationId;

  // Club System State
  ClubModel? myClub;
  List<ClubSearchModel> searchClubResults = [];

  // Campaign & Awareness Challenge Platform State
  List<CampaignModel> discoverCampaigns = [];
  List<CampaignModel> myCampaigns = [];
  List<CampaignModel> completedCampaigns = [];
  CampaignDetailModel? selectedCampaignDetails;
  CampaignDashboardModel? selectedCampaignDashboard;
  CampaignLeaderboardModel? selectedCampaignLeaderboard;
  List<CampaignImpactModel> lastWorkoutCampaignImpacts = [];
  bool isCampaignsLoading = false;

  // Live route loop detection
  bool get isLoopCompleted {
    if (pathPoints.length < 3) return false;
    final start = pathPoints.first;
    final current = pathPoints.last;

    // Check that the user actually ventured away from the starting point (at least 20 meters)
    double maxDistFromStart = 0.0;
    for (var pt in pathPoints) {
      final d = const Distance().as(LengthUnit.Meter, start, pt);
      if (d > maxDistFromStart) maxDistFromStart = d;
    }
    if (maxDistFromStart < 20.0) return false;

    final dist = const Distance().as(
      LengthUnit.Meter,
      start,
      current,
    );
    return dist <= 40.0 && distanceMeters >= 40.0;
  }

  double get distanceToStart {
    if (pathPoints.length < 2) return 0.0;
    return const Distance().as(
      LengthUnit.Meter,
      pathPoints.first,
      pathPoints.last,
    );
  }

  // Active Fitness Session State
  bool isRecording = false;
  String activityType = 'RUN'; // RUN, WALK, CYCLE
  List<LatLng> pathPoints = [];
  int durationSeconds = 0;
  double distanceMeters = 0.0;
  int? targetTerritoryId;

  // Simulator Settings
  bool snapClosure = true;
  bool injectVelocityCheat = false;

  // Real GPS vs Simulation Toggle & Player Physical Stats
  bool isSimulationMode = false;
  double weight = 70.0;
  double height = 170.0;
  int age = 25;
  String gender = 'Male';

  StreamSubscription<Position>? _positionStreamSubscription;

  /// Configures whether map tracking uses simulated tap coordinates or live phone GPS.
  ///
  /// [Why] Enables mock routes execution inside the emulator.
  void toggleSimulationMode(bool value) {
    isSimulationMode = value;
    notifyListeners();
  }

  // Loaded Data Models
  List<TerritoryModel> territories = [];
  List<LeaderboardEntryModel> leaderboard = [];
  List<String> recentEvents = [];
  List<NotificationModel> notifications = [];
  BattleModel? activeBattle;
  List<MissionModel> dailyMissions = [];
  List<MissionModel> weeklyMissions = [];
  List<AchievementModel> achievements = [];
  List<RewardModel> rewards = [];
  List<ContributionHistoryModel> contributionHistory = [];
  List<dynamic> activities = [];
  int attackPrepDays = 0;
  int attackPrepRequiredDays = 2;
  bool attackPrepStarted = false;
  List<dynamic> territoryHistoryLogs = [];

  // Location and Home Base Preferences (No hardcoded New York default)
  LatLng? homeLocation;
  LatLng centerLocation = const LatLng(13.0827, 80.2707); // Neutral initial center before local cache loads
  bool hasRequestedLocationPermission = false;
  bool isGpsEnabled = true;
  bool isLocating = false;

  /// Loads cached home location, last panned coordinates, and permission states from SharedPreferences.
  Future<void> _loadLocationPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userPrefix = userId != null ? 'user_${userId}_' : '';
      final double? homeLat = prefs.getDouble('${userPrefix}home_lat') ?? prefs.getDouble('home_lat');
      final double? homeLng = prefs.getDouble('${userPrefix}home_lng') ?? prefs.getDouble('home_lng');
      final double? lastLat = prefs.getDouble('${userPrefix}last_lat') ?? prefs.getDouble('last_lat');
      final double? lastLng = prefs.getDouble('${userPrefix}last_lng') ?? prefs.getDouble('last_lng');
      hasRequestedLocationPermission = prefs.getBool('has_requested_loc_permission') ?? false;

      if (homeLat != null && homeLng != null) {
        homeLocation = LatLng(homeLat, homeLng);
        centerLocation = homeLocation!;
      } else if (lastLat != null && lastLng != null) {
        centerLocation = LatLng(lastLat, lastLng);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading location preferences: $e');
    }
  }

  /// Sets and permanently stores the player's primary Home Base location.
  Future<void> setHomeLocation(LatLng location) async {
    try {
      homeLocation = location;
      final prefs = await SharedPreferences.getInstance();
      final userPrefix = userId != null ? 'user_${userId}_' : '';
      await prefs.setDouble('${userPrefix}home_lat', location.latitude);
      await prefs.setDouble('${userPrefix}home_lng', location.longitude);
      await prefs.setDouble('home_lat', location.latitude);
      await prefs.setDouble('home_lng', location.longitude);
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving home location: $e');
    }
  }

  /// Instantly resets the map camera center to the user's saved Home Base.
  void resetToHomeLocation() {
    if (homeLocation != null) {
      centerLocation = homeLocation!;
      isCameraFollowingUser = false;
      notifyListeners();
    }
  }

  /// Configures whether the map camera auto-follows user live GPS position.
  void setCameraFollowMode(bool follow) {
    if (isCameraFollowingUser != follow) {
      isCameraFollowingUser = follow;
      notifyListeners();
    }
  }

  /// Snaps the map camera directly back to the user's current live physical coordinates.
  void recenterCameraToUser() {
    isCameraFollowingUser = true;
    if (userLiveLocation != null) {
      centerLocation = userLiveLocation!;
    }
    notifyListeners();
  }

  /// Transitions the operational tracking state and synchronizes the platform GNSS stream.
  Future<void> updateTrackingMode(TrackingMode newMode) async {
    if (trackingMode == newMode && _positionStreamSubscription != null) return;
    trackingMode = newMode;
    notifyListeners();
    await _syncLocationStream();
  }

  /// Resolves the current coordinates of the player to center the map and initiates live tracking.
  ///
  /// [Why] Moves the map camera to where the player is currently located and begins real-time cursor tracking.
  Future<bool> determineAndSetCurrentLocation({
    bool userInitiated = false,
    bool forceOpenSettings = false,
  }) async {
    isLocating = true;
    notifyListeners();
    try {
      // 1. Check if location services (GPS) are enabled on the hardware
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      isGpsEnabled = serviceEnabled;
      if (!serviceEnabled) {
        debugPrint('Location services are disabled on the device.');
        if (forceOpenSettings || userInitiated) {
          await Geolocator.openLocationSettings();
        }
        isLocating = false;
        notifyListeners();
        return false;
      }

      // 2. Check current permission status & request if needed
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        hasRequestedLocationPermission = true;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('has_requested_loc_permission', true);

        if (permission == LocationPermission.denied) {
          debugPrint('Location permissions are denied by user.');
          isLocating = false;
          notifyListeners();
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permissions are permanently denied.');
        if (forceOpenSettings || userInitiated) {
          await Geolocator.openAppSettings();
        }
        isLocating = false;
        notifyListeners();
        return false;
      }

      // 3. Fast lock using last known position (cached on device/Google Play Services)
      try {
        Position? lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          userLiveLocation = LatLng(lastKnown.latitude, lastKnown.longitude);
          if (isCameraFollowingUser || homeLocation == null) {
            centerLocation = userLiveLocation!;
          }
          if (homeLocation == null) {
            await setHomeLocation(userLiveLocation!);
          }
          notifyListeners();
        }
      } catch (e) {
        debugPrint('getLastKnownPosition error: $e');
      }

      // 4. Start live foreground stream immediately with distanceFilter: 0
      await updateTrackingMode(isRecording ? TrackingMode.activeWorkout : TrackingMode.foregroundLocation);

      // 5. Multi-tier GPS snapshot: high accuracy with fast fallback to network/coarse
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best,
          timeLimit: const Duration(seconds: 4),
        );
      } catch (_) {
        try {
          // Fallback to medium accuracy (WiFi/Cell towers - fast indoor fix)
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
            timeLimit: const Duration(seconds: 3),
          );
        } catch (_) {
          try {
            // Fallback to lowest latency coarse location
            position = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.low,
              timeLimit: const Duration(seconds: 3),
            );
          } catch (e) {
            debugPrint('All position fallback attempts timed out: $e');
          }
        }
      }

      if (position != null) {
        userLiveLocation = LatLng(position.latitude, position.longitude);
        if (isCameraFollowingUser || homeLocation == null) {
          centerLocation = userLiveLocation!;
        }

        // Auto-save user's first acquired location as Home Location
        if (homeLocation == null) {
          await setHomeLocation(userLiveLocation!);
        }

        // Cache last known location
        final prefs = await SharedPreferences.getInstance();
        final userPrefix = userId != null ? 'user_${userId}_' : '';
        await prefs.setDouble('${userPrefix}last_lat', userLiveLocation!.latitude);
        await prefs.setDouble('${userPrefix}last_lng', userLiveLocation!.longitude);
      }

      isLocating = false;
      notifyListeners();
      return userLiveLocation != null;
    } catch (e) {
      debugPrint('Error getting location: $e');
      isLocating = false;
      notifyListeners();
      return false;
    }
  }

  /// Caches the current center location coordinates of the map.
  ///
  /// [Why] Preserves map panning configuration across app restarts.
  Future<void> saveLastCenteredLocation(LatLng location) async {
    try {
      centerLocation = location;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('last_lat', location.latitude);
      await prefs.setDouble('last_lng', location.longitude);
    } catch (e) {
      debugPrint('Error saving location: $e');
    }
  }

  /// Sets the active server base URL configurations.
  void setBaseUrl(String url) {
    api.setBaseUrl(url);
    notifyListeners();
  }

  /// Toggles the mock map route snap closure simulation setting.
  void toggleSnapClosure(bool value) {
    snapClosure = value;
    notifyListeners();
  }

  /// Configures whether velocity/teleport simulation coordinates are injected to test the validation engine.
  void toggleInjectVelocityCheat(bool value) {
    injectVelocityCheat = value;
    notifyListeners();
  }

  /// Updates the type of workout (Walk, Run, Cycle) selected.
  void selectActivityType(String type) {
    activityType = type;
    notifyListeners();
  }

  // User Auth Session Persistence Helpers

  Future<void> _saveUserSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (userId != null) {
        await prefs.setInt('user_id', userId!);
        await prefs.setString('user_username', username ?? '');
        await prefs.setString('user_email', email ?? '');
        await prefs.setString('user_color', color);
        await prefs.setBool('is_logged_in', true);
      }
    } catch (e) {
      debugPrint('Error saving user session: $e');
    }
  }

  Future<void> _clearUserSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_id');
      await prefs.remove('user_username');
      await prefs.remove('user_email');
      await prefs.remove('user_color');
      await prefs.setBool('is_logged_in', false);
    } catch (e) {
      debugPrint('Error clearing user session: $e');
    }
  }

  Future<void> _restoreUserSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final loggedIn = prefs.getBool('is_logged_in') ?? false;
      final savedId = prefs.getInt('user_id');
      if (loggedIn && savedId != null) {
        userId = savedId;
        username = prefs.getString('user_username') ?? 'Explorer';
        email = prefs.getString('user_email') ?? '';
        color = prefs.getString('user_color') ?? '#FF007F';
        isLoggedIn = true;
        await _loadLocationPreferences();
        notifyListeners();
        
        // Lazy load: fetch active landing screen data (Territories & Player Stats)
        fetchTerritories();
        fetchPlayerStats();
        syncPendingOfflineActivities();
        determineAndSetCurrentLocation(userInitiated: false);
      }
    } catch (e) {
      debugPrint('Error restoring user session: $e');
    }
  }

  Future<void> _loadUserGuidePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      hasSeenUserGuide = prefs.getBool('fitterra_has_seen_guide') ?? false;
      hasSeenWelcomeOnboarding = prefs.getBool('fitterra_has_seen_welcome_onboarding') ?? false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading user guide preferences: $e');
    }
  }

  /// Sets whether the first-time user guide has been viewed.
  Future<void> markUserGuideSeen({bool seen = true}) async {
    try {
      hasSeenUserGuide = seen;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('fitterra_has_seen_guide', seen);
      notifyListeners();
    } catch (e) {
      debugPrint('Error marking user guide seen: $e');
    }
  }

  /// Sets whether the pre-login onboarding slides have been viewed.
  Future<void> markWelcomeOnboardingSeen({bool seen = true}) async {
    try {
      hasSeenWelcomeOnboarding = seen;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('fitterra_has_seen_welcome_onboarding', seen);
      notifyListeners();
    } catch (e) {
      debugPrint('Error marking welcome onboarding seen: $e');
    }
  }


  // Auth Operations

  /// Performs user log-in validation and boots state properties.
  ///
  /// [Why] authenticates player access and fetches their stored properties on sign-in.
  ///
  /// [How] Hits [api.login], registers credential variables, sets [isLoggedIn] to true, 
  /// and triggers lazy on-demand fetches for game models.
  Future<bool> login(String emailInput, String passwordInput) async {
    _setLoading(true);
    errorMessage = null;
    try {
      final res = await api.login(emailInput, passwordInput);
      userId = res['id'];
      username = res['username'];
      email = res['email'];
      color = res['color'];
      totalTerritoryArea = (res['totalTerritoryArea'] as num).toDouble();
      isLoggedIn = true;
      await _saveUserSession();
      await _loadLocationPreferences();
      _setLoading(false);
      
      // Lazy load initial landing screen data
      fetchTerritories();
      fetchPlayerStats();
      syncPendingOfflineActivities();

      // Immediately determine and acquire location permissions and live fix
      determineAndSetCurrentLocation(userInitiated: true);
      return true;
    } catch (e) {
      errorMessage = ErrorHandler.parse(e, 'Failed to log in. Please check your credentials.');
      _setLoading(false);
      return false;
    }
  }

  /// Registers a new player account and signs them in.
  ///
  /// [Why] Onboards a new user, establishing credentials and biometric parameters.
  ///
  /// [How] Calls [api.register] and initializes game profile on success.
  Future<bool> register({
    required String emailInput,
    required String passwordInput,
    required String usernameInput,
    required String firstName,
    required String lastName,
    required String dob,
    required String profilePic,
    required String colorHex,
    required double weightInput,
    required double heightInput,
    required int ageInput,
    required String genderInput,
  }) async {
    _setLoading(true);
    errorMessage = null;
    try {
      final res = await api.register(
        email: emailInput,
        password: passwordInput,
        username: usernameInput,
        firstName: firstName,
        lastName: lastName,
        dob: dob,
        profilePic: profilePic,
        color: colorHex,
        weight: weightInput,
        height: heightInput,
        age: ageInput,
        gender: genderInput,
      );
      userId = res['id'];
      username = res['username'];
      email = res['email'];
      color = res['color'];
      totalTerritoryArea = (res['totalTerritoryArea'] as num).toDouble();
      isLoggedIn = true;
      await _saveUserSession();
      await _loadLocationPreferences();
      _setLoading(false);

      // Lazy load initial landing screen data
      fetchTerritories();
      fetchPlayerStats();
      syncPendingOfflineActivities();

      // Immediately determine and acquire location permissions and live fix
      determineAndSetCurrentLocation(userInitiated: true);
      return true;
    } catch (e) {
      errorMessage = ErrorHandler.parse(e, 'Failed to register account.');
      _setLoading(false);
      return false;
    }
  }

  // Workaround for register input
  String emailInputInput(String input) => input;

  /// Logs out the user and clears all cached state arrays and persistent session.
  ///
  /// [Why] Ends user session securely.
  void logout() {
    _stopGpsTracking();
    _clearRecordingSessionCache();
    _clearUserSession();
    userId = null;
    username = null;
    email = null;
    isLoggedIn = false;
    userLiveLocation = null;
    homeLocation = null;
    isLocating = false;
    trackingMode = TrackingMode.idle;
    territories.clear();
    leaderboard.clear();
    recentEvents.clear();
    activities.clear();
    pathPoints.clear();
    isRecording = false;
    friendsList.clear();
    pendingFriendRequests.clear();
    pendingRouteInvitations.clear();
    activeRouteInvitations.clear();
    sentRouteInvitations.clear();
    activeInvitationId = null;
    myClub = null;
    searchClubResults.clear();
    notifyListeners();
  }

  Timer? _activityTimer;

  // In-flight Recording Session Persistence

  /// Serializes active in-flight workout parameters and GPS points to local storage.
  ///
  /// [Why] Prevents data loss if the app is paused, killed by the OS, or network switches while walking.
  Future<void> _saveRecordingSessionToDisk({bool force = false}) async {
    if (!isRecording) return;
    final now = DateTime.now();
    if (!force && _lastDiskSaveTime != null && now.difference(_lastDiskSaveTime!).inMilliseconds < 1500) {
      return;
    }
    _lastDiskSaveTime = now;

    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionData = {
        'isRecording': isRecording,
        'activityType': activityType,
        'durationSeconds': durationSeconds,
        'distanceMeters': distanceMeters,
        'targetTerritoryId': targetTerritoryId,
        'activeInvitationId': activeInvitationId,
        'isSimulationMode': isSimulationMode,
        'sessionStartTimeMs': sessionStartTime?.millisecondsSinceEpoch,
        'totalPausedDurationSeconds': totalPausedDuration.inSeconds,
        'timestamp': now.millisecondsSinceEpoch,
        'pathPoints': pathPoints.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList(),
      };
      await prefs.setString(_keyActiveSession, jsonEncode(sessionData));
    } catch (e) {
      debugPrint('Error saving recording session to disk: $e');
    }
  }

  /// Clears the cached recording session from local storage once completed or canceled.
  Future<void> _clearRecordingSessionCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyActiveSession);
    } catch (e) {
      debugPrint('Error clearing recording session cache: $e');
    }
  }

  /// Restores an active workout session from local storage if the app crashed or restarted.
  Future<void> restoreRecordingSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionJson = prefs.getString(_keyActiveSession);
      if (sessionJson == null) return;

      final sessionData = jsonDecode(sessionJson) as Map<String, dynamic>;
      if (sessionData['isRecording'] == true) {
        activityType = sessionData['activityType'] ?? 'RUN';
        durationSeconds = sessionData['durationSeconds'] ?? 0;
        distanceMeters = (sessionData['distanceMeters'] as num?)?.toDouble() ?? 0.0;
        targetTerritoryId = sessionData['targetTerritoryId'];
        activeInvitationId = sessionData['activeInvitationId'];
        isSimulationMode = sessionData['isSimulationMode'] ?? true;

        final startMs = sessionData['sessionStartTimeMs'] as int?;
        if (startMs != null) {
          sessionStartTime = DateTime.fromMillisecondsSinceEpoch(startMs);
        } else {
          sessionStartTime = DateTime.now().subtract(Duration(seconds: durationSeconds));
        }

        final pausedSecs = sessionData['totalPausedDurationSeconds'] as int? ?? 0;
        totalPausedDuration = Duration(seconds: pausedSecs);

        final rawPoints = sessionData['pathPoints'] as List<dynamic>?;
        if (rawPoints != null) {
          pathPoints = rawPoints.map((pt) => LatLng(
            (pt['lat'] as num).toDouble(),
            (pt['lng'] as num).toDouble(),
          )).toList();
        }

        if (pathPoints.isNotEmpty) {
          userLiveLocation = pathPoints.last;
          if (isCameraFollowingUser) {
            centerLocation = pathPoints.last;
          }
        }

        isRecording = true;

        // Resume timer and periodic disk persistence via wall-clock time
        _activityTimer?.cancel();
        _activityTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (sessionStartTime != null) {
            durationSeconds = (DateTime.now().difference(sessionStartTime!).inSeconds - totalPausedDuration.inSeconds).clamp(0, 86400);
          } else {
            durationSeconds++;
          }
          if (durationSeconds % 5 == 0) {
            _saveRecordingSessionToDisk();
          }
          notifyListeners();
        });

        // Resume active tracking mode
        if (!isSimulationMode) {
          updateTrackingMode(TrackingMode.activeWorkout);
        }

        notifyListeners();
        debugPrint('Restored active workout session: ${pathPoints.length} points, $durationSeconds s, $distanceMeters m');
      }
    } catch (e) {
      debugPrint('Error restoring recording session: $e');
    }
  }

  // Offline Activity Queue Operations

  Future<void> _loadPendingOfflineActivities() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dataStr = prefs.getString(_keyPendingActivities);
      if (dataStr != null) {
        final List<dynamic> decoded = jsonDecode(dataStr);
        pendingOfflineActivities = decoded.cast<Map<String, dynamic>>();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading pending offline activities: $e');
    }
  }

  Future<void> _savePendingOfflineActivity(Map<String, dynamic> activityData) async {
    try {
      pendingOfflineActivities.add(activityData);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyPendingActivities, jsonEncode(pendingOfflineActivities));
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving pending offline activity: $e');
    }
  }

  /// Synchronizes all offline-queued activities with the backend once internet connection is restored.
  Future<Map<String, dynamic>> syncPendingOfflineActivities() async {
    if (pendingOfflineActivities.isEmpty || isSyncingOfflineActivities) {
      return {'status': 'NOOP', 'synced': 0};
    }

    isSyncingOfflineActivities = true;
    notifyListeners();

    int syncedCount = 0;
    List<Map<String, dynamic>> remaining = [];

    for (var act in List<Map<String, dynamic>>.from(pendingOfflineActivities)) {
      try {
        final pointsRaw = (act['points'] as List<dynamic>).map((p) => {
          'lat': (p['lat'] as num).toDouble(),
          'lng': (p['lng'] as num).toDouble(),
        }).toList();

        await api.submitActivity(
          userId: act['userId'] ?? userId ?? 1,
          type: act['type'] ?? 'RUN',
          duration: act['duration'] ?? 300,
          distance: (act['distance'] as num?)?.toDouble() ?? 1000.0,
          points: pointsRaw,
          targetTerritoryId: act['targetTerritoryId'],
          routeInvitationId: act['routeInvitationId'],
        );
        syncedCount++;
      } catch (e) {
        debugPrint('Failed to sync offline activity: $e');
        remaining.add(act);
      }
    }

    pendingOfflineActivities = remaining;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyPendingActivities, jsonEncode(pendingOfflineActivities));
    } catch (e) {
      debugPrint('Error persisting remaining offline activities: $e');
    }

    isSyncingOfflineActivities = false;

    if (syncedCount > 0) {
      await fetchTerritories();
      await fetchActivities();
      await fetchPlayerStats();
      await fetchLeaderboard();
    }

    notifyListeners();
    return {
      'status': 'COMPLETED',
      'synced': syncedCount,
      'remaining': remaining.length,
    };
  }

  // GPS Recording & Unified Location Operations

  /// Commences a route-tracking fitness session.
  ///
  /// [Why] Starts accumulating telemetry points, wall-clock duration, and calculating distance.
  ///
  /// [How] Sets [isRecording] to true, clears previous path arrays, starts wall-clock duration tracking,
  /// and escalates the Unified Location Subsystem to [TrackingMode.activeWorkout].
  void startRecording() {
    isRecording = true;
    isSimulationMode = false;
    pathPoints.clear();
    durationSeconds = 0;
    distanceMeters = 0.0;
    sessionStartTime = DateTime.now();
    totalPausedDuration = Duration.zero;
    if (userLiveLocation != null) {
      pathPoints.add(userLiveLocation!);
    }
    _saveRecordingSessionToDisk(force: true);

    _activityTimer?.cancel();
    _activityTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (sessionStartTime != null) {
        durationSeconds = (DateTime.now().difference(sessionStartTime!).inSeconds - totalPausedDuration.inSeconds).clamp(0, 86400);
      } else {
        durationSeconds++;
      }
      if (durationSeconds % 5 == 0) {
        _saveRecordingSessionToDisk();
      }
      notifyListeners();
    });

    if (!isSimulationMode) {
      updateTrackingMode(TrackingMode.activeWorkout);
    } else {
      notifyListeners();
    }
  }

  /// Synchronizes the active platform GNSS stream according to the current [trackingMode].
  Future<void> _syncLocationStream() async {
    if (trackingMode == TrackingMode.idle) {
      _positionStreamSubscription?.cancel();
      _positionStreamSubscription = null;
      return;
    }

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    isGpsEnabled = serviceEnabled;
    if (!serviceEnabled) {
      debugPrint('Location services are disabled on the device.');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      debugPrint('Location permission not granted for stream.');
      return;
    }

    // Cancel existing stream before attaching new settings
    await _positionStreamSubscription?.cancel();

    late final LocationSettings locationSettings;
    if (trackingMode == TrackingMode.activeWorkout || trackingMode == TrackingMode.activeWorkoutBackground) {
      if (defaultTargetPlatform == TargetPlatform.android) {
        locationSettings = AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 3,
          intervalDuration: const Duration(seconds: 2),
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationTitle: "TRION Workout Active",
            notificationText: "Tracking your activity route and territory loop in the background...",
            notificationIcon: AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
            enableWakeLock: true,
          ),
        );
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        locationSettings = AppleSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 3,
          activityType: ActivityType.fitness,
          pauseLocationUpdatesAutomatically: false,
          showBackgroundLocationIndicator: true,
        );
      } else {
        locationSettings = const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 3,
        );
      }
    } else {
      // Foreground live-location mode (Tier 1: no foreground notification, light footprint, instant updates)
      if (defaultTargetPlatform == TargetPlatform.android) {
        locationSettings = AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
          intervalDuration: const Duration(seconds: 1),
        );
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        locationSettings = AppleSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
          pauseLocationUpdatesAutomatically: false,
        );
      } else {
        locationSettings = const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
        );
      }
    }

    _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {
      final newPoint = LatLng(position.latitude, position.longitude);
      userLiveLocation = newPoint;
      isGpsEnabled = true;
      isLocating = false;

      if (homeLocation == null) {
        setHomeLocation(newPoint);
      }

      if (isCameraFollowingUser && !isSimulationMode) {
        centerLocation = newPoint;
      }

      if (isRecording && !isSimulationMode) {
        // Noise gate: ignore low accuracy GPS spikes
        if (position.accuracy <= 25.0) {
          if (pathPoints.isNotEmpty) {
            double stepDistance = const Distance().as(
              LengthUnit.Meter,
              pathPoints.last,
              newPoint,
            );
            // Ignore micro stationary jitter (< 2.0m when moving slowly)
            if (stepDistance >= 2.0 || position.speed >= 0.5) {
              distanceMeters += stepDistance;
              pathPoints.add(newPoint);
              _saveRecordingSessionToDisk();
            }
          } else {
            pathPoints.add(newPoint);
            _saveRecordingSessionToDisk();
          }
        }
      }

      notifyListeners();
    }, onError: (err) {
      debugPrint('Error in unified location stream: $err');
      isLocating = false;
      notifyListeners();
    });
  }

  /// Cancels the GPS coordinate stream and resets tracking.
  void _stopGpsTracking() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    _activityTimer?.cancel();
    _activityTimer = null;
  }

  /// Manually injects a geographic coordinate node into the current path.
  ///
  /// [Why] Supports tap-to-simulate route creation.
  ///
  /// [How] Appends the new point and calculates distance increment (artificially 
  /// inflating step distance if [injectVelocityCheat] is toggled).
  void addCoordinate(LatLng point) {
    if (!isRecording) return;

    // Automatically activate simulation mode when manually tapping on the map
    isSimulationMode = true;

    userLiveLocation = point;
    if (isCameraFollowingUser) {
      centerLocation = point;
    }

    if (pathPoints.isNotEmpty) {
      final lastPoint = pathPoints.last;
      double stepDistance = const Distance().as(
        LengthUnit.Meter,
        LatLng(lastPoint.latitude, lastPoint.longitude),
        LatLng(point.latitude, point.longitude),
      );

      if (injectVelocityCheat) {
        // Teleportation injection: artificially inflate step distance to trigger anti-cheat limits
        stepDistance += 6000.0; 
      }

      distanceMeters += stepDistance;
    }

    pathPoints.add(point);
    _saveRecordingSessionToDisk();
    notifyListeners();
  }

  /// Finalizes the activity recording, performs snap closure adjustments, and submits metrics to backend.
  ///
  /// [Why] Completes workout tracking session and uploads path for GPS validation and area claims.
  ///
  /// [How] Stops GPS tracking, snaps final coordinate to first node to ensure a closed loop, 
  /// calculates simulated duration based on distance to bypass anti-cheat speed triggers, 
  /// calls [api.submitActivity], and syncs profile/routes lists. If network is offline, securely stores workout on disk for auto-sync.
  Future<Map<String, dynamic>?> completeAndSubmitActivity() async {
    _stopGpsTracking();
    if (pathPoints.length < 2 || userId == null) {
      await _clearRecordingSessionCache();
      isRecording = false;
      pathPoints.clear();
      notifyListeners();
      return null;
    }

    _setLoading(true);
    
    // Snap closure simulation
    if (snapClosure && pathPoints.length >= 3) {
      // Force final coordinate to be exactly equal to the first coordinate
      pathPoints[pathPoints.length - 1] = pathPoints.first;
    }

    // Convert list coordinates to API request body format
    List<Map<String, double>> apiPoints = pathPoints.map((p) => {
      'lat': p.latitude,
      'lng': p.longitude,
    }).toList();

    int duration = durationSeconds;
    if (isSimulationMode) {
      // Calculate a realistic duration based on distance so the average speed doesn't trigger anti-cheat limits.
      // Target speeds: WALK ~1.4 m/s (~5 km/h), CYCLE ~6.0 m/s (~21.6 km/h), RUN ~3.5 m/s (~12.6 km/h).
      double simulatedSpeed = 3.5;
      if (activityType == 'WALK') {
        simulatedSpeed = 1.4;
      } else if (activityType == 'CYCLE') {
        simulatedSpeed = 6.0;
      }
      double minDuration = distanceMeters / simulatedSpeed;
      if (durationSeconds < minDuration) {
        duration = minDuration.ceil();
      }
    }

    final savedUserId = userId!;
    final savedType = activityType;
    final savedDuration = duration == 0 ? 300 : duration;
    final savedDistance = distanceMeters == 0 ? 1000.0 : distanceMeters;
    final savedTargetId = targetTerritoryId;
    final savedInvitationId = activeInvitationId;
    final isLoop = isLoopCompleted;

    try {
      final res = await api.submitActivity(
        userId: savedUserId,
        type: savedType,
        duration: savedDuration,
        distance: savedDistance,
        points: apiPoints,
        targetTerritoryId: savedTargetId,
        routeInvitationId: savedInvitationId,
      );

      await _clearRecordingSessionCache();

      // Immediately fetch latest territories, activities, and stats to reflect on the map in real-time
      await fetchTerritories();
      await fetchActivities();
      await fetchLeaderboard();
      await fetchPlayerStats();
      await fetchProgression();
      await fetchAchievements();
      await fetchFriends();
      await fetchPendingFriendRequests();
      await fetchRouteInvitations();
      await fetchMyCampaigns();
      await _evaluateCampaignImpactsForRun(savedDistance);

      // Retrieve updated total area of current user
      if (res['userId'] == userId && res['status'] == 'COMPLETED') {
        for (var entry in leaderboard) {
          if (entry.username == username) {
            totalTerritoryArea = entry.score;
            break;
          }
        }
      }

      isRecording = false;
      pathPoints.clear();
      sessionStartTime = null;
      targetTerritoryId = null;
      activeInvitationId = null; // Clear challenge state on success
      _activityTimer?.cancel();
      _activityTimer = null;
      updateTrackingMode(TrackingMode.foregroundLocation);
      _setLoading(false);
      return res;
    } catch (e) {
      debugPrint('Network error during activity submission: $e');
      errorMessage = ErrorHandler.parse(e, 'Failed to submit workout activity.');

      // Resilient Fallback: Queue activity for offline synchronization without losing data
      final offlinePayload = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'userId': savedUserId,
        'type': savedType,
        'duration': savedDuration,
        'distance': savedDistance,
        'points': apiPoints,
        'targetTerritoryId': savedTargetId,
        'routeInvitationId': savedInvitationId,
        'isClosedLoop': isLoop,
        'savedAt': DateTime.now().toIso8601String(),
      };

      await _savePendingOfflineActivity(offlinePayload);
      await _clearRecordingSessionCache();

      isRecording = false;
      pathPoints.clear();
      sessionStartTime = null;
      targetTerritoryId = null;
      activeInvitationId = null;
      _activityTimer?.cancel();
      _activityTimer = null;
      updateTrackingMode(TrackingMode.foregroundLocation);
      _setLoading(false);

      return {
        'status': 'SAVED_OFFLINE',
        'isClosedLoop': isLoop,
        'message': 'Network connection issue detected. Your route & loop were safely stored offline on your device and will sync automatically when you reconnect!',
      };
    }
  }

  /// Cancels and discards the currently tracked workout session.
  void cancelRecording() {
    _activityTimer?.cancel();
    _activityTimer = null;
    _clearRecordingSessionCache();
    isRecording = false;
    pathPoints.clear();
    durationSeconds = 0;
    distanceMeters = 0.0;
    sessionStartTime = null;
    totalPausedDuration = Duration.zero;
    updateTrackingMode(TrackingMode.foregroundLocation);
    notifyListeners();
  }

  // In-Memory Cache & Fetch Throttling
  final Map<String, DateTime> _lastFetchTime = {};
  final Map<String, bool> _isFetching = {};

  /// Evaluates whether an API endpoint should be fetched based on cache TTL and in-flight status.
  bool _shouldFetch(String key, {Duration ttl = const Duration(minutes: 2), bool force = false}) {
    if (_isFetching[key] == true) return false; // Prevent in-flight duplicate requests
    if (force) return true;
    final lastTime = _lastFetchTime[key];
    if (lastTime == null) return true;
    return DateTime.now().difference(lastTime) > ttl;
  }

  void _recordFetchStart(String key) {
    _isFetching[key] = true;
  }

  void _recordFetchEnd(String key) {
    _isFetching[key] = false;
    _lastFetchTime[key] = DateTime.now();
  }

  /// Invalidates the cache for a given key or all keys (forces subsequent fetch to hit backend).
  void invalidateCache([String? key]) {
    if (key != null) {
      _lastFetchTime.remove(key);
    } else {
      _lastFetchTime.clear();
    }
  }

  // Data Fetching

  /// Queries all global territories for rendering H3 polygons with 30s cache TTL.
  Future<void> fetchTerritories({bool force = false}) async {
    const cacheKey = 'territories';
    if (!_shouldFetch(cacheKey, ttl: const Duration(seconds: 30), force: force)) return;
    _recordFetchStart(cacheKey);
    try {
      final data = await api.getTerritories();
      territories = data.map((json) {
        List<List<LatLng>> paths = [];
        if (json['paths'] != null) {
          for (var p in json['paths']) {
            List<LatLng> pts = [];
            for (var pt in p) {
              pts.add(LatLng(pt['lat'], pt['lng']));
            }
            paths.add(pts);
          }
        }
        return TerritoryModel(
          id: json['id'],
          ownerId: json['ownerId'],
          ownerName: json['ownerName'],
          color: json['color'],
          area: (json['area'] as num).toDouble(),
          level: json['level'] ?? 1,
          defenseScore: json['defenseScore'] ?? 1000,
          status: json['status'] ?? 'OWNED',
          paths: paths,
        );
      }).toList();
      _recordFetchEnd(cacheKey);
      notifyListeners();
    } catch (e) {
      _isFetching[cacheKey] = false;
      debugPrint('Error loading territories: $e');
    }
  }

  /// Loads leaderboard players list with 1min cache TTL.
  Future<void> fetchLeaderboard({bool force = false}) async {
    const cacheKey = 'leaderboard';
    if (!_shouldFetch(cacheKey, ttl: const Duration(minutes: 1), force: force)) return;
    _recordFetchStart(cacheKey);
    try {
      final data = await api.getLeaderboard();
      leaderboard = data.map((json) => LeaderboardEntryModel(
        username: json['username'],
        score: (json['score'] as num).toDouble(),
        rank: json['rank'],
      )).toList();
      
      // Update our local area count if we find our username
      for (var entry in leaderboard) {
        if (entry.username == username) {
          totalTerritoryArea = entry.score;
        }
      }
      _recordFetchEnd(cacheKey);
      notifyListeners();
    } catch (e) {
      _isFetching[cacheKey] = false;
      debugPrint('Error loading leaderboard: $e');
    }
  }

  /// Retrieves the list of recent territory events with 1min cache TTL.
  Future<void> fetchEvents({bool force = false}) async {
    const cacheKey = 'events';
    if (!_shouldFetch(cacheKey, ttl: const Duration(minutes: 1), force: force)) return;
    _recordFetchStart(cacheKey);
    try {
      recentEvents = await api.getTerritoryEvents();
      _recordFetchEnd(cacheKey);
      notifyListeners();
    } catch (e) {
      _isFetching[cacheKey] = false;
      debugPrint('Error loading events: $e');
    }
  }

  /// Loads the history list of logged activities with 1min cache TTL.
  Future<void> fetchActivities({bool force = false}) async {
    if (userId == null) return;
    const cacheKey = 'activities';
    if (!_shouldFetch(cacheKey, ttl: const Duration(minutes: 1), force: force)) return;
    _recordFetchStart(cacheKey);
    try {
      activities = await api.getActivities(userId!);
      _recordFetchEnd(cacheKey);
      notifyListeners();
    } catch (e) {
      _isFetching[cacheKey] = false;
      debugPrint('Error loading activities: $e');
    }
  }

  /// Loads core player bio/stat metrics with 2min cache TTL.
  Future<void> fetchPlayerStats({bool force = false}) async {
    if (userId == null) return;
    const cacheKey = 'player_stats';
    if (!_shouldFetch(cacheKey, ttl: const Duration(minutes: 2), force: force)) return;
    _recordFetchStart(cacheKey);
    try {
      final data = await api.getPlayerStats(userId!);
      level = data['level'] ?? 1;
      xp = data['xp'] ?? 0;
      coins = data['coins'] ?? 0;
      streak = data['currentStreak'] ?? 0;
      territoriesCaptured = data['territoriesCaptured'] ?? 0;
      territoriesLost = data['territoriesLost'] ?? 0;
      territoriesDefended = data['territoriesDefended'] ?? 0;
      totalDistance = (data['totalDistance'] as num?)?.toDouble() ?? 0.0;
      totalActivities = data['totalActivities'] ?? 0;
      weight = (data['weight'] as num?)?.toDouble() ?? 70.0;
      height = (data['height'] as num?)?.toDouble() ?? 170.0;
      age = data['age'] ?? 25;
      gender = data['gender'] ?? 'Male';
      _recordFetchEnd(cacheKey);
      notifyListeners();
    } catch (e) {
      _isFetching[cacheKey] = false;
      debugPrint('Error loading player stats: $e');
    }
  }

  /// Checks the combat/siege status of a selected territory.
  ///
  /// [Why] Feeds map info widgets when clicking contesting zones.
  Future<void> fetchBattleStatus(int territoryId) async {
    try {
      final data = await api.getBattleStatus(territoryId);
      if (data == null) {
        activeBattle = null;
      } else {
        activeBattle = BattleModel(
          id: data['id'],
          territoryId: data['territoryId'],
          attackerId: data['attackerId'],
          attackerName: data['attackerName'],
          defenderId: data['defenderId'],
          defenderName: data['defenderName'],
          status: data['status'],
          attackScore: data['attackScore'],
          defenseScore: data['defenseScore'],
          requiredScore: data['requiredScore'],
          captureProgress: (data['captureProgress'] as num).toDouble(),
          captureWindowExpiresAt: data['captureWindowExpiresAt'] != null 
              ? DateTime.parse(data['captureWindowExpiresAt']) 
              : null,
        );
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading battle status: $e');
      activeBattle = null;
      notifyListeners();
    }
  }

  /// Loads preparation state of the player against a territory.
  ///
  /// [Why] Updates siege preparation meters.
  Future<void> fetchAttackPrep(int territoryId) async {
    if (userId == null) return;
    try {
      final data = await api.getAttackPrep(territoryId, userId!);
      attackPrepDays = data['uniqueAttackDays'] ?? 0;
      attackPrepRequiredDays = data['requiredDays'] ?? 2;
      attackPrepStarted = data['started'] ?? false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading attack prep status: $e');
    }
  }

  /// Gathers notifications feed alerts from server.
  Future<void> fetchNotifications() async {
    if (userId == null) return;
    try {
      final data = await api.getNotifications(userId!);
      notifications = data.map((json) => NotificationModel(
        id: json['id'] ?? 0,
        title: json['title'] ?? 'Notification',
        message: json['message'] ?? '',
        type: json['type'] ?? 'INFO',
        isRead: json['isRead'] ?? json['read'] ?? false,
        createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
      )).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading notifications: $e');
    }
  }

  /// Marks the specified alert notification as read.
  Future<void> markNotificationRead(int notificationId) async {
    try {
      await api.markNotificationRead(notificationId);
      await fetchNotifications();
    } catch (e) {
      debugPrint('Error marking notification read: $e');
    }
  }

  /// Loads historical log entries for a territory.
  Future<void> fetchTerritoryHistory(int territoryId) async {
    try {
      territoryHistoryLogs = await api.getTerritoryHistory(territoryId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading territory history: $e');
    }
  }

  /// Selects a territory on the map, loading its combat data.
  ///
  /// [Why] Triggers side panels showing details when clicking a territory cell.
  void selectTargetTerritory(int? id) {
    targetTerritoryId = id;
    if (id != null) {
      fetchBattleStatus(id);
      fetchAttackPrep(id);
      fetchTerritoryHistory(id);
    } else {
      activeBattle = null;
      attackPrepDays = 0;
      attackPrepRequiredDays = 2;
      attackPrepStarted = false;
      territoryHistoryLogs.clear();
    }
    notifyListeners();
  }

  /// Queries user level and XP milestones stats with 2min cache TTL.
  Future<void> fetchProgression({bool force = false}) async {
    if (userId == null) return;
    const cacheKey = 'progression';
    if (!_shouldFetch(cacheKey, ttl: const Duration(minutes: 2), force: force)) return;
    _recordFetchStart(cacheKey);
    try {
      final data = await api.getProgression(userId!);
      level = data['level'] ?? 1;
      xp = data['xp'] ?? 0;
      coins = data['coins'] ?? 0;
      streak = data['currentStreak'] ?? 0;
      xpRequiredForCurrentLevel = data['xpRequiredForCurrentLevel'] ?? 0;
      xpRequiredForNextLevel = data['xpRequiredForNextLevel'] ?? 500;
      territoriesCaptured = data['territoriesCaptured'] ?? 0;
      territoriesLost = data['territoriesLost'] ?? 0;
      territoriesDefended = data['territoriesDefended'] ?? 0;
      totalDistance = (data['totalDistance'] as num?)?.toDouble() ?? 0.0;
      totalActivities = data['totalActivities'] ?? 0;
      weight = (data['weight'] as num?)?.toDouble() ?? 70.0;
      height = (data['height'] as num?)?.toDouble() ?? 170.0;
      age = data['age'] ?? 25;
      gender = data['gender'] ?? 'Male';
      _recordFetchEnd(cacheKey);
      notifyListeners();
    } catch (e) {
      _isFetching[cacheKey] = false;
      debugPrint('Error loading progression: $e');
    }
  }

  /// Loads active daily and weekly mission lists with 2min cache TTL.
  Future<void> fetchMissions({bool force = false}) async {
    if (userId == null) return;
    const cacheKey = 'missions';
    if (!_shouldFetch(cacheKey, ttl: const Duration(minutes: 2), force: force)) return;
    _recordFetchStart(cacheKey);
    try {
      final dailies = await api.getDailyMissions(userId!);
      dailyMissions = dailies.map((json) => MissionModel(
        id: json['id'],
        missionId: json['missionId'],
        title: json['title'],
        description: json['description'],
        targetType: json['targetType'],
        targetValue: (json['targetValue'] as num).toDouble(),
        progress: (json['progress'] as num).toDouble(),
        status: json['status'],
        xpReward: json['xpReward'],
        coinReward: json['coinReward'],
        contributionReward: json['contributionReward'],
        date: json['date'],
      )).toList();

      final weeklies = await api.getWeeklyMissions(userId!);
      weeklyMissions = weeklies.map((json) => MissionModel(
        id: json['id'],
        missionId: json['missionId'],
        title: json['title'],
        description: json['description'],
        targetType: json['targetType'],
        targetValue: (json['targetValue'] as num).toDouble(),
        progress: (json['progress'] as num).toDouble(),
        status: json['status'],
        xpReward: json['xpReward'],
        coinReward: json['coinReward'],
        contributionReward: json['contributionReward'],
        date: json['date'],
      )).toList();

      _recordFetchEnd(cacheKey);
      notifyListeners();
    } catch (e) {
      _isFetching[cacheKey] = false;
      debugPrint('Error loading missions: $e');
    }
  }

  /// Loads player achievement unlocked statuses with 2min cache TTL.
  Future<void> fetchAchievements({bool force = false}) async {
    if (userId == null) return;
    const cacheKey = 'achievements';
    if (!_shouldFetch(cacheKey, ttl: const Duration(minutes: 2), force: force)) return;
    _recordFetchStart(cacheKey);
    try {
      final data = await api.getAchievements(userId!);
      achievements = data.map((json) => AchievementModel(
        id: json['id'],
        achievementId: json['achievementId'],
        title: json['title'],
        description: json['description'],
        category: json['category'],
        targetValue: (json['targetValue'] as num).toDouble(),
        progress: (json['progress'] as num).toDouble(),
        isUnlocked: json['isUnlocked'] ?? false,
        unlockedAt: json['unlockedAt'] ?? '',
        xpReward: json['xpReward'],
        badgeIcon: json['badgeIcon'] ?? '',
      )).toList();
      _recordFetchEnd(cacheKey);
      notifyListeners();
    } catch (e) {
      _isFetching[cacheKey] = false;
      debugPrint('Error loading achievements: $e');
    }
  }

  /// Loads available shop items cosmetics with 5min cache TTL.
  Future<void> fetchRewards({bool force = false}) async {
    if (userId == null) return;
    const cacheKey = 'rewards';
    if (!_shouldFetch(cacheKey, ttl: const Duration(minutes: 5), force: force)) return;
    _recordFetchStart(cacheKey);
    try {
      final data = await api.getRewards(userId!);
      rewards = data.map((json) => RewardModel(
        id: json['id'],
        title: json['title'],
        description: json['description'],
        type: json['type'],
        unlockedAtLevel: json['unlockedAtLevel'],
        costInCoins: json['costInCoins'],
        isClaimed: json['isClaimed'] ?? false,
      )).toList();
      _recordFetchEnd(cacheKey);
      notifyListeners();
    } catch (e) {
      _isFetching[cacheKey] = false;
      debugPrint('Error loading rewards: $e');
    }
  }

  /// Loads contribution XP transactions logs with 2min cache TTL.
  Future<void> fetchContributionHistory({bool force = false}) async {
    if (userId == null) return;
    const cacheKey = 'contribution_history';
    if (!_shouldFetch(cacheKey, ttl: const Duration(minutes: 2), force: force)) return;
    _recordFetchStart(cacheKey);
    try {
      final data = await api.getContributionHistory(userId!);
      contributionHistory = data.map((json) => ContributionHistoryModel(
        id: json['id'],
        sourceType: json['sourceType'],
        sourceId: json['sourceId'],
        amount: json['amount'],
        createdAt: json['createdAt'],
      )).toList();

      // Recalculate local contribution score
      contributionScore = contributionHistory.fold(0, (sum, item) => sum + item.amount);
      _recordFetchEnd(cacheKey);
      notifyListeners();
    } catch (e) {
      _isFetching[cacheKey] = false;
      debugPrint('Error loading contribution history: $e');
    }
  }

  /// Loads active friends roster with 1min cache TTL.
  Future<void> fetchFriends({bool force = false}) async {
    if (userId == null) return;
    const cacheKey = 'friends';
    if (!_shouldFetch(cacheKey, ttl: const Duration(minutes: 1), force: force)) return;
    _recordFetchStart(cacheKey);
    try {
      final list = await api.getFriends(userId!);
      friendsList = list.map((json) => FriendModel(
        id: json['id'],
        username: json['username'],
        color: json['color'],
        totalTerritoryArea: (json['totalTerritoryArea'] as num).toDouble(),
      )).toList();
      _recordFetchEnd(cacheKey);
      notifyListeners();
    } catch (e) {
      _isFetching[cacheKey] = false;
      debugPrint('Error loading friends list: $e');
    }
  }

  /// Loads incoming pending friend requests list with 45s cache TTL.
  Future<void> fetchPendingFriendRequests({bool force = false}) async {
    if (userId == null) return;
    const cacheKey = 'pending_friend_requests';
    if (!_shouldFetch(cacheKey, ttl: const Duration(seconds: 45), force: force)) return;
    _recordFetchStart(cacheKey);
    try {
      final list = await api.getPendingFriendRequests(userId!);
      pendingFriendRequests = list.map((json) => FriendshipRequestModel(
        id: json['id'],
        senderId: json['senderId'],
        senderUsername: json['senderUsername'],
        senderColor: json['senderColor'],
        createdAt: json['createdAt'],
      )).toList();
      _recordFetchEnd(cacheKey);
      notifyListeners();
    } catch (e) {
      _isFetching[cacheKey] = false;
      debugPrint('Error loading pending friend requests: $e');
    }
  }

  /// Dispatches a new friend invitation to username.
  Future<bool> sendFriendRequest(String username) async {
    if (userId == null) return false;
    _setLoading(true);
    errorMessage = null;
    try {
      await api.sendFriendRequest(userId!, username);
      _setLoading(false);
      return true;
    } catch (e) {
      errorMessage = ErrorHandler.parse(e, 'Failed to send friend request.');
      _setLoading(false);
      return false;
    }
  }

  /// Approves friendship request from a friend.
  Future<bool> acceptFriendRequest(int friendshipId) async {
    if (userId == null) return false;
    _setLoading(true);
    errorMessage = null;
    try {
      await api.acceptFriendRequest(userId!, friendshipId);
      await fetchFriends();
      await fetchPendingFriendRequests();
      _setLoading(false);
      return true;
    } catch (e) {
      errorMessage = ErrorHandler.parse(e, 'Failed to accept friend request.');
      _setLoading(false);
      return false;
    }
  }

  /// Declines friendship request from a friend.
  Future<bool> rejectFriendRequest(int friendshipId) async {
    if (userId == null) return false;
    _setLoading(true);
    errorMessage = null;
    try {
      await api.rejectFriendRequest(userId!, friendshipId);
      await fetchPendingFriendRequests();
      _setLoading(false);
      return true;
    } catch (e) {
      errorMessage = ErrorHandler.parse(e, 'Failed to reject friend request.');
      _setLoading(false);
      return false;
    }
  }

  /// Loads all incoming and outgoing route challenge invitations with 45s cache TTL.
  Future<void> fetchRouteInvitations({bool force = false}) async {
    if (userId == null) return;
    const cacheKey = 'route_invitations';
    if (!_shouldFetch(cacheKey, ttl: const Duration(seconds: 45), force: force)) return;
    _recordFetchStart(cacheKey);
    try {
      final pendingList = await api.getPendingInvitations(userId!);
      pendingRouteInvitations = pendingList.map((json) => mapRouteInvitation(json)).toList();

      final activeList = await api.getActiveInvitations(userId!);
      activeRouteInvitations = activeList.map((json) => mapRouteInvitation(json)).toList();

      final sentList = await api.getSentInvitations(userId!);
      sentRouteInvitations = sentList.map((json) => mapRouteInvitation(json)).toList();

      _recordFetchEnd(cacheKey);
      notifyListeners();
    } catch (e) {
      _isFetching[cacheKey] = false;
      debugPrint('Error loading route invitations: $e');
    }
  }

  /// Maps json data values to a structured [RouteInvitationModel].
  RouteInvitationModel mapRouteInvitation(dynamic json) {
    List<LatLng> pts = [];
    if (json['points'] != null) {
      for (var pt in json['points']) {
        pts.add(LatLng(pt['lat'], pt['lng']));
      }
    }
    return RouteInvitationModel(
      id: json['id'],
      inviterId: json['inviterId'],
      inviterUsername: json['inviterUsername'],
      inviteeId: json['inviteeId'],
      inviteeUsername: json['inviteeUsername'],
      activityId: json['activityId'],
      activityDistance: (json['activityDistance'] as num).toDouble(),
      activityDuration: json['activityDuration'],
      activityType: json['activityType'],
      points: pts,
      status: json['status'],
      createdAt: json['createdAt'],
      completedActivityId: json['completedActivityId'],
    );
  }

  /// Creates and sends a route challenge invitation to a friend.
  Future<bool> createRouteInvitation(int friendId, int activityId) async {
    if (userId == null) return false;
    _setLoading(true);
    errorMessage = null;
    try {
      await api.createInvitation(userId!, friendId, activityId);
      await fetchRouteInvitations(force: true);
      _setLoading(false);
      return true;
    } catch (e) {
      errorMessage = ErrorHandler.parse(e, 'Failed to send route invitation.');
      _setLoading(false);
      return false;
    }
  }

  /// Approves a pending route matching challenge.
  Future<bool> acceptRouteInvitation(int invitationId) async {
    if (userId == null) return false;
    _setLoading(true);
    errorMessage = null;
    try {
      await api.acceptInvitation(userId!, invitationId);
      await fetchRouteInvitations(force: true);
      _setLoading(false);
      return true;
    } catch (e) {
      errorMessage = ErrorHandler.parse(e, 'Failed to accept route challenge.');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> rejectRouteInvitation(int invitationId) async {
    if (userId == null) return false;
    _setLoading(true);
    errorMessage = null;
    try {
      await api.rejectInvitation(userId!, invitationId);
      await fetchRouteInvitations(force: true);
      _setLoading(false);
      return true;
    } catch (e) {
      errorMessage = ErrorHandler.parse(e, 'Failed to reject route challenge.');
      _setLoading(false);
      return false;
    }
  }

  /// Selects an active route matching challenge for map display.
  void selectRouteChallenge(int? invitationId) {
    activeInvitationId = invitationId;
    targetTerritoryId = null; // Clear territory target if challenge is selected
    notifyListeners();
  }

  /// Fetches details of the club the user belongs to with 1min cache TTL.
  Future<void> fetchMyClub({bool force = false}) async {
    if (userId == null) return;
    const cacheKey = 'my_club';
    if (!_shouldFetch(cacheKey, ttl: const Duration(minutes: 1), force: force)) return;
    _recordFetchStart(cacheKey);
    try {
      final json = await api.getMyClub(userId!);
      if (json == null) {
        myClub = null;
      } else {
        List<ClubMemberModel> membersList = [];
        if (json['members'] != null) {
          for (var m in json['members']) {
            membersList.add(ClubMemberModel(
              userId: m['userId'],
              username: m['username'],
              color: m['color'],
              role: m['role'],
              joinedAt: m['joinedAt'],
            ));
          }
        }
        myClub = ClubModel(
          id: json['id'],
          name: json['name'],
          username: json['username'],
          inviteCode: json['inviteCode'],
          description: json['description'] ?? '',
          logo: json['logo'],
          level: json['level'],
          xp: json['xp'],
          defensePoints: json['defensePoints'],
          maxMembers: json['maxMembers'],
          memberCount: json['memberCount'],
          myRole: json['myRole'],
          members: membersList,
        );
      }
      _recordFetchEnd(cacheKey);
      notifyListeners();
    } catch (e) {
      _isFetching[cacheKey] = false;
      debugPrint('Error loading my club: $e');
    }
  }

  /// Creates a new public club/guild.
  Future<bool> createClub(String name, String username, String description) async {
    if (userId == null) return false;
    _setLoading(true);
    errorMessage = null;
    try {
      await api.createClub(userId!, name, username, description);
      await fetchProgression(force: true); // Sync XP deduction
      await fetchMyClub(force: true);
      _setLoading(false);
      return true;
    } catch (e) {
      errorMessage = ErrorHandler.parse(e, 'Failed to create club.');
      _setLoading(false);
      return false;
    }
  }

  /// Joins a club using its 6-digit invite code.
  Future<bool> joinClub(String inviteCode) async {
    if (userId == null) return false;
    _setLoading(true);
    errorMessage = null;
    try {
      await api.joinClub(userId!, inviteCode);
      await fetchMyClub(force: true);
      _setLoading(false);
      return true;
    } catch (e) {
      errorMessage = ErrorHandler.parse(e, 'Failed to join club. Please check the invite code.');
      _setLoading(false);
      return false;
    }
  }

  /// Leaves the current club.
  Future<bool> leaveClub() async {
    if (userId == null) return false;
    _setLoading(true);
    errorMessage = null;
    try {
      await api.leaveClub(userId!);
      myClub = null;
      invalidateCache('my_club');
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = ErrorHandler.parse(e, 'Failed to leave club.');
      _setLoading(false);
      return false;
    }
  }

  /// Updates the role/rank of a target member.
  Future<bool> updateMemberRole(int targetUserId, String role) async {
    if (userId == null) return false;
    _setLoading(true);
    errorMessage = null;
    try {
      await api.updateMemberRole(userId!, targetUserId, role);
      await fetchMyClub(force: true);
      _setLoading(false);
      return true;
    } catch (e) {
      errorMessage = ErrorHandler.parse(e, 'Failed to update member role.');
      _setLoading(false);
      return false;
    }
  }

  /// Expels a member from the club roster.
  Future<bool> kickMember(int targetUserId) async {
    if (userId == null) return false;
    _setLoading(true);
    errorMessage = null;
    try {
      await api.kickMember(userId!, targetUserId);
      await fetchMyClub(force: true);
      _setLoading(false);
      return true;
    } catch (e) {
      errorMessage = ErrorHandler.parse(e, 'Failed to kick member.');
      _setLoading(false);
      return false;
    }
  }

  /// Searches for public clubs by keyword matching.
  Future<void> searchClubs(String query) async {
    try {
      final list = await api.searchClubs(query);
      searchClubResults = list.map<ClubSearchModel>((json) => ClubSearchModel(
        id: json['id'],
        name: json['name'],
        username: json['username'],
        level: json['level'],
        memberCount: json['memberCount'],
        maxMembers: json['maxMembers'],
        description: json['description'] ?? '',
        inviteCode: json['inviteCode'] ?? '',
      )).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error searching clubs: $e');
    }
  }

  // ==========================================
  // CAMPAIGNS & AWARENESS CHALLENGES METHODS
  // ==========================================

  /// Fetches discoverable and completed campaigns with 2min cache TTL.
  Future<void> fetchCampaigns({String? type, String? status, bool force = false}) async {
    final cacheKey = 'campaigns_${type ?? 'all'}_${status ?? 'active'}';
    if (!_shouldFetch(cacheKey, ttl: const Duration(minutes: 2), force: force)) return;
    _recordFetchStart(cacheKey);
    isCampaignsLoading = true;
    notifyListeners();
    try {
      final list = await api.getCampaigns(type: type, status: status, userId: userId);
      final mapped = list.map<CampaignModel>((json) => CampaignModel.fromJson(json)).toList();
      
      if (status == 'COMPLETED') {
        completedCampaigns = mapped;
      } else {
        discoverCampaigns = mapped;
      }
      _recordFetchEnd(cacheKey);
    } catch (e) {
      _isFetching[cacheKey] = false;
      debugPrint('Error loading campaigns: $e');
    } finally {
      isCampaignsLoading = false;
      notifyListeners();
    }
  }

  /// Fetches all campaigns enrolled by the user with 2min cache TTL.
  Future<void> fetchMyCampaigns({bool force = false}) async {
    if (userId == null) return;
    const cacheKey = 'my_campaigns';
    if (!_shouldFetch(cacheKey, ttl: const Duration(minutes: 2), force: force)) return;
    _recordFetchStart(cacheKey);
    try {
      final list = await api.getMyCampaigns(userId!);
      myCampaigns = list.map<CampaignModel>((json) => CampaignModel.fromJson(json)).toList();
      _recordFetchEnd(cacheKey);
      notifyListeners();
    } catch (e) {
      _isFetching[cacheKey] = false;
      debugPrint('Error loading my campaigns: $e');
    }
  }

  /// Retrieves full campaign details, rules, and milestone tiers.
  Future<CampaignDetailModel?> fetchCampaignDetails(int campaignId) async {
    try {
      final json = await api.getCampaignDetails(campaignId, userId: userId);
      selectedCampaignDetails = CampaignDetailModel.fromJson(json);
      notifyListeners();
      return selectedCampaignDetails;
    } catch (e) {
      debugPrint('Error loading campaign details: $e');
      return null;
    }
  }

  /// Enrolls the player into a campaign and triggers immediate state sync.
  Future<bool> joinCampaign(int campaignId, {int? organizationId, String? organizationName, int? clubId}) async {
    if (userId == null) return false;
    _setLoading(true);
    try {
      await api.joinCampaign(campaignId, userId!,
          organizationId: organizationId,
          organizationName: organizationName,
          clubId: clubId ?? myClub?.id);
      await fetchCampaigns();
      await fetchMyCampaigns();
      await fetchCampaignDetails(campaignId);
      _setLoading(false);
      return true;
    } catch (e) {
      errorMessage = ErrorHandler.parse(e, 'Failed to join campaign.');
      _setLoading(false);
      return false;
    }
  }

  /// Retrieves the personal dashboard for an enrolled campaign.
  Future<CampaignDashboardModel?> fetchCampaignDashboard(int campaignId) async {
    if (userId == null) return null;
    try {
      final json = await api.getCampaignDashboard(campaignId, userId!);
      selectedCampaignDashboard = CampaignDashboardModel.fromJson(json);
      notifyListeners();
      return selectedCampaignDashboard;
    } catch (e) {
      debugPrint('Error loading campaign dashboard: $e');
      return null;
    }
  }

  /// Retrieves the multi-tier leaderboard for a campaign.
  Future<CampaignLeaderboardModel?> fetchCampaignLeaderboard(int campaignId, {String view = 'INDIVIDUAL'}) async {
    try {
      final json = await api.getCampaignLeaderboard(campaignId, view: view, userId: userId);
      selectedCampaignLeaderboard = CampaignLeaderboardModel.fromJson(json);
      notifyListeners();
      return selectedCampaignLeaderboard;
    } catch (e) {
      debugPrint('Error loading campaign leaderboard: $e');
      return null;
    }
  }

  /// Evaluates multi-campaign progress impact locally for instant HUD display after a run.
  Future<void> _evaluateCampaignImpactsForRun(double distanceMeters) async {
    final distKm = distanceMeters / 1000.0;
    if (distKm < 0.1) return;

    lastWorkoutCampaignImpacts.clear();
    for (var c in myCampaigns) {
      if (c.status == 'ACTIVE') {
        final pts = (distKm * 10).round();
        final prevDist = c.userDistanceKm;
        final newDist = prevDist + distKm;
        final target = c.individualTargetKm > 0 ? c.individualTargetKm : 30.0;
        final pct = (newDist / target * 100).clamp(0.0, 100.0);

        lastWorkoutCampaignImpacts.add(CampaignImpactModel(
          campaignId: c.id,
          campaignTitle: c.title,
          iconEmoji: c.iconEmoji,
          colorHex: c.colorHex,
          distanceContributedKm: distKm,
          pointsEarned: pts,
          previousDistanceKm: prevDist,
          newDistanceKm: newDist,
          goalPercentage: pct,
        ));
      }
    }
    notifyListeners();
  }

  /// Attempts to claim a cosmetic shop reward.
  Future<bool> tryClaimReward(int rewardId) async {
    if (userId == null) return false;
    _setLoading(true);
    try {
      await api.claimReward(userId!, rewardId);
      await fetchProgression();
      await fetchRewards();
      _setLoading(false);
      return true;
    } catch (e) {
      errorMessage = ErrorHandler.parse(e, 'Failed to claim reward.');
      _setLoading(false);
      return false;
    }
  }

  /// Toggles the global [isLoading] spinner state.
  void _setLoading(bool val) {
    isLoading = val;
    notifyListeners();
  }

  /// Updates local user profile bio data on successful server validation.
  Future<bool> updateUserProfile({
    required String usernameInput,
    required String colorHex,
    required double weightInput,
    required double heightInput,
    required int ageInput,
    required String genderInput,
  }) async {
    if (userId == null) return false;
    _setLoading(true);
    errorMessage = null;
    try {
      final res = await api.updateProfile(
        userId!,
        usernameInput,
        colorHex,
        weightInput,
        heightInput,
        ageInput,
        genderInput,
      );
      if (res['status'] == 'SUCCESS') {
        username = usernameInput;
        color = colorHex;
        weight = weightInput;
        height = heightInput;
        age = ageInput;
        gender = genderInput;
        _setLoading(false);
        // Refresh local listings/leaderboards
        await fetchLeaderboard();
        await fetchPlayerStats();
        return true;
      }
      _setLoading(false);
      return false;
    } catch (e) {
      errorMessage = ErrorHandler.parse(e, 'Failed to update profile.');
      _setLoading(false);
      return false;
    }
  }
}

class TerritoryModel {
  final int id;
  final int ownerId;
  final String ownerName;
  final String color;
  final Color parsedColor;
  final double area;
  final int level;
  final int defenseScore;
  final String status;
  final List<List<LatLng>> paths;

  TerritoryModel({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    required this.color,
    required this.area,
    required this.level,
    required this.defenseScore,
    required this.status,
    required this.paths,
  }) : parsedColor = _parseHexColor(color);

  static Color _parseHexColor(String hex) {
    final clean = hex.replaceAll('#', '');
    try {
      final val = int.parse('FF$clean', radix: 16);
      return Color(val);
    } catch (_) {
      return Colors.pink;
    }
  }
}

class LeaderboardEntryModel {
  final String username;
  final double score;
  final int rank;

  LeaderboardEntryModel({
    required this.username,
    required this.score,
    required this.rank,
  });
}

class BattleModel {
  final int id;
  final int territoryId;
  final int attackerId;
  final String attackerName;
  final int defenderId;
  final String defenderName;
  final String status;
  final int attackScore;
  final int defenseScore;
  final int requiredScore;
  final double captureProgress;
  final DateTime? captureWindowExpiresAt;

  BattleModel({
    required this.id,
    required this.territoryId,
    required this.attackerId,
    required this.attackerName,
    required this.defenderId,
    required this.defenderName,
    required this.status,
    required this.attackScore,
    required this.defenseScore,
    required this.requiredScore,
    required this.captureProgress,
    this.captureWindowExpiresAt,
  });
}

class NotificationModel {
  final int id;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    required this.createdAt,
  });
}

class MissionModel {
  final int id;
  final int missionId;
  final String title;
  final String description;
  final String targetType;
  final double targetValue;
  final double progress;
  final String status;
  final int xpReward;
  final int coinReward;
  final int contributionReward;
  final String date;

  MissionModel({
    required this.id,
    required this.missionId,
    required this.title,
    required this.description,
    required this.targetType,
    required this.targetValue,
    required this.progress,
    required this.status,
    required this.xpReward,
    required this.coinReward,
    required this.contributionReward,
    required this.date,
  });
}

class AchievementModel {
  final int id;
  final int achievementId;
  final String title;
  final String description;
  final String category;
  final double targetValue;
  final double progress;
  final bool isUnlocked;
  final String unlockedAt;
  final int xpReward;
  final String badgeIcon;

  AchievementModel({
    required this.id,
    required this.achievementId,
    required this.title,
    required this.description,
    required this.category,
    required this.targetValue,
    required this.progress,
    required this.isUnlocked,
    required this.unlockedAt,
    required this.xpReward,
    required this.badgeIcon,
  });
}

class RewardModel {
  final int id;
  final String title;
  final String description;
  final String type;
  final int unlockedAtLevel;
  final int costInCoins;
  final bool isClaimed;

  RewardModel({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.unlockedAtLevel,
    required this.costInCoins,
    required this.isClaimed,
  });
}

class ContributionHistoryModel {
  final int id;
  final String sourceType;
  final int sourceId;
  final int amount;
  final String createdAt;

  ContributionHistoryModel({
    required this.id,
    required this.sourceType,
    required this.sourceId,
    required this.amount,
    required this.createdAt,
  });
}

class FriendModel {
  final int id;
  final String username;
  final String color;
  final double totalTerritoryArea;

  FriendModel({
    required this.id,
    required this.username,
    required this.color,
    required this.totalTerritoryArea,
  });
}

class FriendshipRequestModel {
  final int id;
  final int senderId;
  final String senderUsername;
  final String senderColor;
  final String createdAt;

  FriendshipRequestModel({
    required this.id,
    required this.senderId,
    required this.senderUsername,
    required this.senderColor,
    required this.createdAt,
  });
}

class RouteInvitationModel {
  final int id;
  final int inviterId;
  final String inviterUsername;
  final int inviteeId;
  final String inviteeUsername;
  final int activityId;
  final double activityDistance;
  final int activityDuration;
  final String activityType;
  final List<LatLng> points;
  final String status;
  final String createdAt;
  final int? completedActivityId;

  RouteInvitationModel({
    required this.id,
    required this.inviterId,
    required this.inviterUsername,
    required this.inviteeId,
    required this.inviteeUsername,
    required this.activityId,
    required this.activityDistance,
    required this.activityDuration,
    required this.activityType,
    required this.points,
    required this.status,
    required this.createdAt,
    this.completedActivityId,
  });
}

class ClubModel {
  final int id;
  final String name;
  final String username;
  final String inviteCode;
  final String description;
  final String? logo;
  final int level;
  final int xp;
  final int defensePoints;
  final int maxMembers;
  final int memberCount;
  final String? myRole;
  final List<ClubMemberModel> members;

  ClubModel({
    required this.id,
    required this.name,
    required this.username,
    required this.inviteCode,
    required this.description,
    this.logo,
    required this.level,
    required this.xp,
    required this.defensePoints,
    required this.maxMembers,
    required this.memberCount,
    this.myRole,
    required this.members,
  });
}

class ClubMemberModel {
  final int userId;
  final String username;
  final String color;
  final String role;
  final String joinedAt;

  ClubMemberModel({
    required this.userId,
    required this.username,
    required this.color,
    required this.role,
    required this.joinedAt,
  });
}

class ClubSearchModel {
  final int id;
  final String name;
  final String username;
  final int level;
  final int memberCount;
  final int maxMembers;
  final String description;
  final String inviteCode;

  ClubSearchModel({
    required this.id,
    required this.name,
    required this.username,
    required this.level,
    required this.memberCount,
    required this.maxMembers,
    required this.description,
    required this.inviteCode,
  });
}

// ==========================================
// CAMPAIGN DOMAIN MODELS
// ==========================================

class CampaignModel {
  final int id;
  final String title;
  final String slug;
  final String type;
  final String description;
  final String organizerName;
  final String? bannerUrl;
  final String iconEmoji;
  final String colorHex;
  final String startAt;
  final String endAt;
  final double targetDistanceKm;
  final double currentDistanceKm;
  final double progressPercentage;
  final int participantCount;
  final int? participantLimit;
  final double individualTargetKm;
  final String status;
  final bool isJoined;
  final double userDistanceKm;
  final int userPoints;

  CampaignModel({
    required this.id,
    required this.title,
    required this.slug,
    required this.type,
    required this.description,
    required this.organizerName,
    this.bannerUrl,
    required this.iconEmoji,
    required this.colorHex,
    required this.startAt,
    required this.endAt,
    required this.targetDistanceKm,
    required this.currentDistanceKm,
    required this.progressPercentage,
    required this.participantCount,
    this.participantLimit,
    required this.individualTargetKm,
    required this.status,
    required this.isJoined,
    required this.userDistanceKm,
    required this.userPoints,
  });

  factory CampaignModel.fromJson(Map<String, dynamic> json) {
    return CampaignModel(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      slug: json['slug'] ?? '',
      type: json['type'] ?? 'AWARENESS',
      description: json['description'] ?? '',
      organizerName: json['organizerName'] ?? '',
      bannerUrl: json['bannerUrl'],
      iconEmoji: json['iconEmoji'] ?? '🎯',
      colorHex: json['colorHex'] ?? '#E040FB',
      startAt: json['startAt'] ?? '',
      endAt: json['endAt'] ?? '',
      targetDistanceKm: (json['targetDistanceKm'] as num?)?.toDouble() ?? 100000.0,
      currentDistanceKm: (json['currentDistanceKm'] as num?)?.toDouble() ?? 0.0,
      progressPercentage: (json['progressPercentage'] as num?)?.toDouble() ?? 0.0,
      participantCount: json['participantCount'] ?? 0,
      participantLimit: json['participantLimit'],
      individualTargetKm: (json['individualTargetKm'] as num?)?.toDouble() ?? 30.0,
      status: json['status'] ?? 'ACTIVE',
      isJoined: json['joined'] ?? json['isJoined'] ?? false,
      userDistanceKm: (json['userDistanceKm'] as num?)?.toDouble() ?? 0.0,
      userPoints: json['userPoints'] ?? 0,
    );
  }
}

class CampaignRuleModel {
  final int participationPoints;
  final double pointsPerKm;
  final double minActivityDistanceKm;
  final int completionBonusPoints;
  final String allowedActivityTypes;

  CampaignRuleModel({
    required this.participationPoints,
    required this.pointsPerKm,
    required this.minActivityDistanceKm,
    required this.completionBonusPoints,
    required this.allowedActivityTypes,
  });

  factory CampaignRuleModel.fromJson(Map<String, dynamic> json) {
    return CampaignRuleModel(
      participationPoints: json['participationPoints'] ?? 50,
      pointsPerKm: (json['pointsPerKm'] as num?)?.toDouble() ?? 10.0,
      minActivityDistanceKm: (json['minActivityDistanceKm'] as num?)?.toDouble() ?? 0.5,
      completionBonusPoints: json['completionBonusPoints'] ?? 500,
      allowedActivityTypes: json['allowedActivityTypes'] ?? 'RUN,WALK,CYCLE',
    );
  }
}

class CampaignMilestoneModel {
  final int id;
  final double thresholdKm;
  final int bonusPoints;
  final String title;
  final String milestoneType;
  final bool isAchieved;

  CampaignMilestoneModel({
    required this.id,
    required this.thresholdKm,
    required this.bonusPoints,
    required this.title,
    required this.milestoneType,
    required this.isAchieved,
  });

  factory CampaignMilestoneModel.fromJson(Map<String, dynamic> json) {
    return CampaignMilestoneModel(
      id: json['id'] ?? 0,
      thresholdKm: (json['thresholdKm'] as num?)?.toDouble() ?? 0.0,
      bonusPoints: json['bonusPoints'] ?? 0,
      title: json['title'] ?? '',
      milestoneType: json['milestoneType'] ?? 'DISTANCE_THRESHOLD',
      isAchieved: json['achieved'] ?? json['isAchieved'] ?? false,
    );
  }
}

class CampaignDetailModel {
  final CampaignModel summary;
  final CampaignRuleModel rules;
  final List<CampaignMilestoneModel> milestones;

  CampaignDetailModel({
    required this.summary,
    required this.rules,
    required this.milestones,
  });

  factory CampaignDetailModel.fromJson(Map<String, dynamic> json) {
    return CampaignDetailModel(
      summary: CampaignModel.fromJson(json['summary'] ?? {}),
      rules: CampaignRuleModel.fromJson(json['rules'] ?? {}),
      milestones: (json['milestones'] as List<dynamic>? ?? [])
          .map((m) => CampaignMilestoneModel.fromJson(m))
          .toList(),
    );
  }
}

class CampaignPointTransactionModel {
  final int id;
  final String transactionType;
  final int points;
  final String? referenceId;
  final String? description;
  final String createdAt;

  CampaignPointTransactionModel({
    required this.id,
    required this.transactionType,
    required this.points,
    this.referenceId,
    this.description,
    required this.createdAt,
  });

  factory CampaignPointTransactionModel.fromJson(Map<String, dynamic> json) {
    return CampaignPointTransactionModel(
      id: json['id'] ?? 0,
      transactionType: json['transactionType'] ?? 'DISTANCE',
      points: json['points'] ?? 0,
      referenceId: json['referenceId'],
      description: json['description'],
      createdAt: json['createdAt'] ?? '',
    );
  }
}

class CampaignActivitySummaryModel {
  final int id;
  final int activityId;
  final double distanceKm;
  final int basePoints;
  final int milestonePoints;
  final int completionPoints;
  final int totalPoints;
  final String createdAt;

  CampaignActivitySummaryModel({
    required this.id,
    required this.activityId,
    required this.distanceKm,
    required this.basePoints,
    required this.milestonePoints,
    required this.completionPoints,
    required this.totalPoints,
    required this.createdAt,
  });

  factory CampaignActivitySummaryModel.fromJson(Map<String, dynamic> json) {
    return CampaignActivitySummaryModel(
      id: json['id'] ?? 0,
      activityId: json['activityId'] ?? 0,
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0.0,
      basePoints: json['basePoints'] ?? 0,
      milestonePoints: json['milestonePoints'] ?? 0,
      completionPoints: json['completionPoints'] ?? 0,
      totalPoints: json['totalPoints'] ?? 0,
      createdAt: json['createdAt'] ?? '',
    );
  }
}

class CampaignDashboardModel {
  final CampaignModel campaign;
  final double currentDistanceKm;
  final double targetDistanceKm;
  final double progressPercentage;
  final int totalPoints;
  final int rank;
  final bool isGoalCompleted;
  final String? completedAt;
  final List<CampaignPointTransactionModel> transactions;
  final List<CampaignActivitySummaryModel> recentActivities;

  CampaignDashboardModel({
    required this.campaign,
    required this.currentDistanceKm,
    required this.targetDistanceKm,
    required this.progressPercentage,
    required this.totalPoints,
    required this.rank,
    required this.isGoalCompleted,
    this.completedAt,
    required this.transactions,
    required this.recentActivities,
  });

  factory CampaignDashboardModel.fromJson(Map<String, dynamic> json) {
    return CampaignDashboardModel(
      campaign: CampaignModel.fromJson(json['campaign'] ?? {}),
      currentDistanceKm: (json['currentDistanceKm'] as num?)?.toDouble() ?? 0.0,
      targetDistanceKm: (json['targetDistanceKm'] as num?)?.toDouble() ?? 30.0,
      progressPercentage: (json['progressPercentage'] as num?)?.toDouble() ?? 0.0,
      totalPoints: json['totalPoints'] ?? 0,
      rank: json['rank'] ?? 1,
      isGoalCompleted: json['isGoalCompleted'] ?? false,
      completedAt: json['completedAt'],
      transactions: (json['transactions'] as List<dynamic>? ?? [])
          .map((t) => CampaignPointTransactionModel.fromJson(t))
          .toList(),
      recentActivities: (json['recentActivities'] as List<dynamic>? ?? [])
          .map((a) => CampaignActivitySummaryModel.fromJson(a))
          .toList(),
    );
  }
}

class CampaignLeaderboardEntryModel {
  final int rank;
  final int id;
  final String name;
  final String? avatar;
  final double totalDistanceKm;
  final int totalPoints;
  final int? memberCount;
  final String subtitle;
  final bool isCurrentUser;

  CampaignLeaderboardEntryModel({
    required this.rank,
    required this.id,
    required this.name,
    this.avatar,
    required this.totalDistanceKm,
    required this.totalPoints,
    this.memberCount,
    required this.subtitle,
    required this.isCurrentUser,
  });

  factory CampaignLeaderboardEntryModel.fromJson(Map<String, dynamic> json) {
    return CampaignLeaderboardEntryModel(
      rank: json['rank'] ?? 1,
      id: json['id'] ?? 0,
      name: json['name'] ?? 'Runner',
      avatar: json['avatar'],
      totalDistanceKm: (json['totalDistanceKm'] as num?)?.toDouble() ?? 0.0,
      totalPoints: json['totalPoints'] ?? 0,
      memberCount: json['memberCount'],
      subtitle: json['subtitle'] ?? '',
      isCurrentUser: json['isCurrentUser'] ?? json['currentUser'] ?? false,
    );
  }
}

class CampaignLeaderboardModel {
  final int campaignId;
  final String campaignTitle;
  final String view;
  final List<CampaignLeaderboardEntryModel> entries;
  final CampaignLeaderboardEntryModel? userStanding;

  CampaignLeaderboardModel({
    required this.campaignId,
    required this.campaignTitle,
    required this.view,
    required this.entries,
    this.userStanding,
  });

  factory CampaignLeaderboardModel.fromJson(Map<String, dynamic> json) {
    return CampaignLeaderboardModel(
      campaignId: json['campaignId'] ?? 0,
      campaignTitle: json['campaignTitle'] ?? '',
      view: json['view'] ?? 'INDIVIDUAL',
      entries: (json['entries'] as List<dynamic>? ?? [])
          .map((e) => CampaignLeaderboardEntryModel.fromJson(e))
          .toList(),
      userStanding: json['userStanding'] != null
          ? CampaignLeaderboardEntryModel.fromJson(json['userStanding'])
          : null,
    );
  }
}

class CampaignImpactModel {
  final int campaignId;
  final String campaignTitle;
  final String iconEmoji;
  final String colorHex;
  final double distanceContributedKm;
  final int pointsEarned;
  final String? milestoneTitle;
  final double previousDistanceKm;
  final double newDistanceKm;
  final double goalPercentage;

  CampaignImpactModel({
    required this.campaignId,
    required this.campaignTitle,
    required this.iconEmoji,
    required this.colorHex,
    required this.distanceContributedKm,
    required this.pointsEarned,
    this.milestoneTitle,
    required this.previousDistanceKm,
    required this.newDistanceKm,
    required this.goalPercentage,
  });
}
