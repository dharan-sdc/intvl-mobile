import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'api_service.dart';

class AppState extends ChangeNotifier {
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
  int attackPrepDays = 0;
  bool attackPrepStarted = false;
  List<dynamic> territoryHistoryLogs = [];

  // Set default starting point for mapping simulation: e.g. Central Park, NY
  LatLng centerLocation = const LatLng(40.785091, -73.968285);

  Future<void> determineAndSetCurrentLocation({bool forceOpenSettings = false}) async {
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

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      centerLocation = LatLng(position.latitude, position.longitude);
      notifyListeners();
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  void setBaseUrl(String url) {
    api.setBaseUrl(url);
    notifyListeners();
  }

  void toggleSnapClosure(bool value) {
    snapClosure = value;
    notifyListeners();
  }

  void toggleInjectVelocityCheat(bool value) {
    injectVelocityCheat = value;
    notifyListeners();
  }

  void selectActivityType(String type) {
    activityType = type;
    notifyListeners();
  }

  // Auth Operations
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
      return true;
    } catch (e) {
      errorMessage = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> register(
    String emailInput,
    String passwordInput,
    String usernameInput,
    String colorHex,
    double weightInput,
    double heightInput,
    int ageInput,
    String genderInput,
  ) async {
    _setLoading(true);
    errorMessage = null;
    try {
      final res = await api.register(
        emailInputInput(emailInput),
        passwordInput,
        usernameInput,
        colorHex,
        weightInput,
        heightInput,
        ageInput,
        genderInput,
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
      return true;
    } catch (e) {
      errorMessage = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  // Workaround for register input
  String emailInputInput(String input) => input;

  void logout() {
    userId = null;
    username = null;
    email = null;
    isLoggedIn = false;
    territories.clear();
    leaderboard.clear();
    recentEvents.clear();
    pathPoints.clear();
    isRecording = false;
    notifyListeners();
  }

  Timer? _activityTimer;

  // GPS Recording Simulation Operations
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

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 3, // Update every 3 meters
    );

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

  void _stopGpsTracking() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    _activityTimer?.cancel();
    _activityTimer = null;
  }

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

      // Refresh stats, notifications, territories, and progression
      await fetchTerritories();
      await fetchLeaderboard();
      await fetchEvents();
      await fetchPlayerStats();
      await fetchNotifications();
      await fetchProgression();
      await fetchMissions();
      await fetchAchievements();
      await fetchRewards();
      await fetchContributionHistory();

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

  void cancelRecording() {
    _stopGpsTracking();
    isRecording = false;
    pathPoints.clear();
    durationSeconds = 0;
    distanceMeters = 0.0;
    notifyListeners();
  }

  // Data Fetching
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

  Future<void> fetchEvents() async {
    try {
      recentEvents = await api.getTerritoryEvents();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading events: $e');
    }
  }

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

  Future<void> fetchAttackPrep(int territoryId) async {
    if (userId == null) return;
    try {
      final data = await api.getAttackPrep(territoryId, userId!);
      attackPrepDays = data['uniqueAttackDays'] ?? 0;
      attackPrepStarted = data['started'] ?? false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading attack prep status: $e');
    }
  }

  Future<void> fetchNotifications() async {
    if (userId == null) return;
    try {
      final data = await api.getNotifications(userId!);
      notifications = data.map((json) => NotificationModel(
        id: json['id'],
        title: json['title'],
        message: json['message'],
        type: json['type'],
        isRead: json['isRead'] ?? json['read'] ?? false,
        createdAt: DateTime.parse(json['createdAt']),
      )).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading notifications: $e');
    }
  }

  Future<void> markNotificationRead(int notificationId) async {
    try {
      await api.markNotificationRead(notificationId);
      await fetchNotifications();
    } catch (e) {
      debugPrint('Error marking notification read: $e');
    }
  }

  Future<void> fetchTerritoryHistory(int territoryId) async {
    try {
      territoryHistoryLogs = await api.getTerritoryHistory(territoryId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading territory history: $e');
    }
  }

  void selectTargetTerritory(int? id) {
    targetTerritoryId = id;
    if (id != null) {
      fetchBattleStatus(id);
      fetchAttackPrep(id);
      fetchTerritoryHistory(id);
    } else {
      activeBattle = null;
      attackPrepDays = 0;
      attackPrepStarted = false;
      territoryHistoryLogs.clear();
    }
    notifyListeners();
  }

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

  void _setLoading(bool val) {
    isLoading = val;
    notifyListeners();
  }

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
  });
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
