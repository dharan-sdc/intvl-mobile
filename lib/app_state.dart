import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'api_service.dart';

/// Global state management provider for the FitTerra application using ChangeNotifier.
///
/// [Why] Centralizes game engine progression stats, active GPS recording parameters, 
/// friend invitations list, and club profiles under a single reactive data store.
///
/// [How] Components watch or read [AppState] via Provider, triggering widget rebuilds 
/// when [notifyListeners] is called.
class AppState extends ChangeNotifier {
  /// Instance of the HTTP ApiService used to interact with backend endpoints.
  final ApiService api = ApiService();

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
  bool isSimulationMode = true;
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

  // Set default starting point for mapping simulation: e.g. Central Park, NY
  LatLng centerLocation = const LatLng(40.785091, -73.968285);

  /// Resolves the current coordinates of the player to center the map.
  ///
  /// [Why] Moves the map camera to where the player is currently located on initialization.
  ///
  /// [How] Checks saved cache coordinates in [SharedPreferences], then checks Geolocator 
  /// permissions, falling back to device's last known location and then live GPS.
  Future<void> determineAndSetCurrentLocation({bool forceOpenSettings = false}) async {
    // 1. Try to load panned/saved location from SharedPreferences first (instant load)
    try {
      final prefs = await SharedPreferences.getInstance();
      final double? savedLat = prefs.getDouble('last_lat');
      final double? savedLng = prefs.getDouble('last_lng');
      if (savedLat != null && savedLng != null) {
        centerLocation = LatLng(savedLat, savedLng);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading saved location: $e');
    }

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled.');
        if (forceOpenSettings) {
          await Geolocator.openLocationSettings();
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Location permissions are denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permissions are permanently denied.');
        return;
      }

      // 2. Try to get device's last known location (much faster fallback if no fresh lock)
      Position? lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null && centerLocation.latitude == 40.785091 && centerLocation.longitude == -73.968285) {
        centerLocation = LatLng(lastKnown.latitude, lastKnown.longitude);
        notifyListeners();
      }

      // 3. Get fresh active GPS position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 4),
      );
      centerLocation = LatLng(position.latitude, position.longitude);
      
      // Save it
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('last_lat', centerLocation.latitude);
      await prefs.setDouble('last_lng', centerLocation.longitude);
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  /// Caches the current center location coordinates of the map.
  ///
  /// [Why] Preserves map panning configuration across app restarts.
  Future<void> saveLastCenteredLocation(LatLng location) async {
    try {
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

  // Auth Operations

  /// Performs user log-in validation and boots state properties.
  ///
  /// [Why] authenticates player access and fetches their stored properties on sign-in.
  ///
  /// [How] Hits [api.login], registers credential variables, sets [isLoggedIn] to true, 
  /// and triggers parallel async fetches for all game models (achievements, territories, etc.).
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
      _setLoading(false);
      
      // Load initial data
      fetchTerritories();
      fetchLeaderboard();
      fetchEvents();
      fetchPlayerStats();
      fetchNotifications();
      fetchProgression();
      fetchMissions();
      fetchAchievements();
      fetchRewards();
      fetchContributionHistory();
      fetchActivities();
      fetchFriends();
      fetchPendingFriendRequests();
      fetchRouteInvitations();
      return true;
    } catch (e) {
      errorMessage = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  /// Registers a new player account and signs them in.
  ///
  /// [Why] Onboards a new user, establishing credentials and biometric parameters.
  ///
  /// [How] Calls [api.register] and triggers initial game profile data fetches on success.
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
      _setLoading(false);

      // Load initial data
      fetchTerritories();
      fetchLeaderboard();
      fetchEvents();
      fetchPlayerStats();
      fetchNotifications();
      fetchProgression();
      fetchMissions();
      fetchAchievements();
      fetchRewards();
      fetchContributionHistory();
      fetchActivities();
      fetchFriends();
      fetchPendingFriendRequests();
      fetchRouteInvitations();
      return true;
    } catch (e) {
      errorMessage = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  // Workaround for register input
  String emailInputInput(String input) => input;

  /// Logs out the user and clears all cached state arrays.
  ///
  /// [Why] Ends user session securely.
  void logout() {
    userId = null;
    username = null;
    email = null;
    isLoggedIn = false;
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

  // GPS Recording Simulation Operations

  /// Commences a route-tracking fitness session.
  ///
  /// [Why] Starts accumulating telemetry points and calculating distance.
  ///
  /// [How] Sets [isRecording] to true, clears previous path arrays, starts a periodic timer 
  /// incrementing session duration, and binds the phone's hardware GPS listener if simulation mode is off.
  void startRecording() {
    isRecording = true;
    pathPoints.clear();
    durationSeconds = 0;
    distanceMeters = 0.0;

    _activityTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      durationSeconds++;
      notifyListeners();
    });

    if (!isSimulationMode) {
      _startGpsTracking();
    } else {
      notifyListeners();
    }
  }

  /// Establishes the reactive GPS tracking stream.
  ///
  /// [Why] Records latitude and longitude coordinates while running/walking.
  ///
  /// [How] Checks permissions, requests configuration settings, and opens a geolocator position stream 
  /// adding coordinates to the route path and calculating incremental geodesic distances.
  void _startGpsTracking() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('Location services are disabled.');
      errorMessage = 'Location services are disabled. Please enable GPS.';
      isRecording = false;
      _activityTimer?.cancel();
      _activityTimer = null;
      notifyListeners();
      await Geolocator.openLocationSettings();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      debugPrint('Location permission denied, cannot track route.');
      errorMessage = 'Location permission denied. Please allow location access.';
      isRecording = false;
      _activityTimer?.cancel();
      _activityTimer = null;
      notifyListeners();
      return;
    }

    late final LocationSettings locationSettings;
    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 3,
        intervalDuration: const Duration(seconds: 5),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: "TRION Active Tracking",
          notificationText: "Tracking your activity route in the background...",
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

    _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {
      LatLng newPoint = LatLng(position.latitude, position.longitude);
      centerLocation = newPoint;

      if (pathPoints.isNotEmpty) {
        double stepDistance = const Distance().as(
          LengthUnit.Meter,
          pathPoints.last,
          newPoint,
        );
        distanceMeters += stepDistance;
      }

      pathPoints.add(newPoint);
      notifyListeners();
    });
  }

  /// Cancels the GPS coordinate stream.
  void _stopGpsTracking() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    _activityTimer?.cancel();
    _activityTimer = null;
  }

  /// Manually injects a geographic coordinate coordinate node into the current path.
  ///
  /// [Why] Supports tap-to-simulate route creation.
  ///
  /// [How] Appends the new point and calculates distance increment (artificially 
  /// inflating step distance if [injectVelocityCheat] is toggled).
  void addCoordinate(LatLng point) {
    if (!isRecording) return;

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
    notifyListeners();
  }

  /// Finalizes the activity recording, performs snap closure adjustments, and submits metrics to backend.
  ///
  /// [Why] Completes workout tracking session and uploads path for GPS validation and area claims.
  ///
  /// [How] Stops GPS tracking, snaps final coordinate to first node to ensure a closed loop, 
  /// calculates simulated duration based on distance to bypass anti-cheat speed triggers, 
  /// calls [api.submitActivity], and syncs profile/routes lists.
  Future<Map<String, dynamic>?> completeAndSubmitActivity() async {
    _stopGpsTracking();
    if (pathPoints.length < 2 || userId == null) {
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

    try {
      final res = await api.submitActivity(
        userId: userId!,
        type: activityType,
        duration: duration == 0 ? 300 : duration,
        distance: distanceMeters == 0 ? 1000.0 : distanceMeters,
        points: apiPoints,
        targetTerritoryId: targetTerritoryId,
      );

      await fetchFriends();
      await fetchPendingFriendRequests();
      await fetchRouteInvitations();

      // Retrieve updated total area of current user
      if (res['userId'] == userId && res['status'] == 'COMPLETED') {
        // Trigger area refresh
        for (var entry in leaderboard) {
          if (entry.username == username) {
            totalTerritoryArea = entry.score;
            break;
          }
        }
      }

      isRecording = false;
      pathPoints.clear();
      targetTerritoryId = null;
      activeInvitationId = null; // Clear challenge state on success
      _setLoading(false);
      return res;
    } catch (e) {
      errorMessage = e.toString().replaceAll('Exception: ', '');
      isRecording = false;
      pathPoints.clear();
      _setLoading(false);
      return {'status': 'ERROR', 'error': errorMessage};
    }
  }

  /// Cancels and discards the currently tracked workout session.
  void cancelRecording() {
    _stopGpsTracking();
    isRecording = false;
    pathPoints.clear();
    durationSeconds = 0;
    distanceMeters = 0.0;
    notifyListeners();
  }

  // Data Fetching

  /// Queries all global territories for rendering H3 polygons.
  ///
  /// [Why] Feeds map views with boundaries of all claimed territories.
  ///
  /// [How] Hits [api.getTerritories], decodes coordinates paths lists, and populates [territories] list.
  Future<void> fetchTerritories() async {
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
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading territories: $e');
    }
  }

  /// Loads leaderboard players list.
  ///
  /// [Why] Feeds the ranking screen.
  Future<void> fetchLeaderboard() async {
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
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading leaderboard: $e');
    }
  }

  /// Retrieves the list of recent territory events.
  ///
  /// [Why] Keeps player updated with other players' capture details.
  Future<void> fetchEvents() async {
    try {
      recentEvents = await api.getTerritoryEvents();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading events: $e');
    }
  }

  /// Loads the history list of logged activities.
  Future<void> fetchActivities() async {
    if (userId == null) return;
    try {
      activities = await api.getActivities(userId!);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading activities: $e');
    }
  }

  /// Loads core player bio/stat metrics.
  ///
  /// [Why] Keeps local settings and profile data synchronized.
  Future<void> fetchPlayerStats() async {
    if (userId == null) return;
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
      notifyListeners();
    } catch (e) {
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

  /// Queries user level and XP milestones stats.
  Future<void> fetchProgression() async {
    if (userId == null) return;
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
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading progression: $e');
    }
  }

  /// Loads active daily and weekly mission lists.
  Future<void> fetchMissions() async {
    if (userId == null) return;
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

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading missions: $e');
    }
  }

  /// Loads player achievement unlocked statuses.
  Future<void> fetchAchievements() async {
    if (userId == null) return;
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
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading achievements: $e');
    }
  }

  /// Loads available shop items cosmetics.
  Future<void> fetchRewards() async {
    if (userId == null) return;
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
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading rewards: $e');
    }
  }

  /// Loads contribution XP transactions logs.
  Future<void> fetchContributionHistory() async {
    if (userId == null) return;
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
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading contribution history: $e');
    }
  }

  /// Loads active friends roster.
  Future<void> fetchFriends() async {
    if (userId == null) return;
    try {
      final list = await api.getFriends(userId!);
      friendsList = list.map((json) => FriendModel(
        id: json['id'],
        username: json['username'],
        color: json['color'],
        totalTerritoryArea: (json['totalTerritoryArea'] as num).toDouble(),
      )).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading friends list: $e');
    }
  }

  /// Loads incoming pending friend requests list.
  Future<void> fetchPendingFriendRequests() async {
    if (userId == null) return;
    try {
      final list = await api.getPendingFriendRequests(userId!);
      pendingFriendRequests = list.map((json) => FriendshipRequestModel(
        id: json['id'],
        senderId: json['senderId'],
        senderUsername: json['senderUsername'],
        senderColor: json['senderColor'],
        createdAt: json['createdAt'],
      )).toList();
      notifyListeners();
    } catch (e) {
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
      errorMessage = e.toString().replaceAll('Exception: ', '');
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
      errorMessage = e.toString().replaceAll('Exception: ', '');
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
      errorMessage = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  /// Loads all incoming and outgoing route challenge invitations.
  Future<void> fetchRouteInvitations() async {
    if (userId == null) return;
    try {
      final pendingList = await api.getPendingInvitations(userId!);
      pendingRouteInvitations = pendingList.map((json) => mapRouteInvitation(json)).toList();

      final activeList = await api.getActiveInvitations(userId!);
      activeRouteInvitations = activeList.map((json) => mapRouteInvitation(json)).toList();

      final sentList = await api.getSentInvitations(userId!);
      sentRouteInvitations = sentList.map((json) => mapRouteInvitation(json)).toList();

      notifyListeners();
    } catch (e) {
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
      await fetchRouteInvitations();
      _setLoading(false);
      return true;
    } catch (e) {
      errorMessage = e.toString().replaceAll('Exception: ', '');
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
      await fetchRouteInvitations();
      _setLoading(false);
      return true;
    } catch (e) {
      errorMessage = e.toString().replaceAll('Exception: ', '');
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
      await fetchRouteInvitations();
      _setLoading(false);
      return true;
    } catch (e) {
      errorMessage = e.toString().replaceAll('Exception: ', '');
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

  /// Fetches details of the club the user belongs to.
  ///
  /// [Why] Keeps local club data synchronized with backend guild statistics.
  Future<void> fetchMyClub() async {
    if (userId == null) return;
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
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading my club: $e');
    }
  }

  /// Creates a new public club/guild.
  Future<bool> createClub(String name, String username, String description) async {
    if (userId == null) return false;
    _setLoading(true);
    errorMessage = null;
    try {
      final json = await api.createClub(userId!, name, username, description);
      await fetchProgression(); // Sync XP deduction
      await fetchMyClub();
      _setLoading(false);
      return true;
    } catch (e) {
      errorMessage = e.toString().replaceAll('Exception: ', '');
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
      await fetchMyClub();
      _setLoading(false);
      return true;
    } catch (e) {
      errorMessage = e.toString().replaceAll('Exception: ', '');
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
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = e.toString().replaceAll('Exception: ', '');
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
      await fetchMyClub();
      _setLoading(false);
      return true;
    } catch (e) {
      errorMessage = e.toString().replaceAll('Exception: ', '');
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
      await fetchMyClub();
      _setLoading(false);
      return true;
    } catch (e) {
      errorMessage = e.toString().replaceAll('Exception: ', '');
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
      errorMessage = e.toString().replaceAll('Exception: ', '');
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
      errorMessage = e.toString().replaceAll('Exception: ', '');
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
