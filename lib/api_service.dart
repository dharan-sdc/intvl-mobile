import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  String _baseUrl = 'https://intvl.onrender.com';

  ApiService() {
    // Automatically detect Android emulator vs local machine
    
      _baseUrl = 'https://intvl.onrender.com';
    
  }

  String get baseUrl => _baseUrl;

  void setBaseUrl(String url) {
    if (url.isNotEmpty) {
      _baseUrl = url;
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/v1/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(response.body.isNotEmpty ? response.body : 'Failed to login');
    }
  }

  Future<Map<String, dynamic>> register(String email, String password, String username, String color, double weight, double height, int age, String gender) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/v1/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'username': username,
        'color': color,
        'weight': weight,
        'height': height,
        'age': age,
        'gender': gender,
      }),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception(response.body.isNotEmpty ? response.body : 'Failed to register');
    }
  }

  Future<Map<String, dynamic>> submitActivity({
    required int userId,
    required String type,
    required int duration,
    required double distance,
    required List<Map<String, double>> points,
    int? targetTerritoryId,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/v1/activities'),
      headers: {
        'Content-Type': 'application/json',
        'X-User-Id': userId.toString(),
      },
      body: jsonEncode({
        'type': type,
        'duration': duration,
        'distance': distance,
        'points': points,
        'targetTerritoryId': targetTerritoryId,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 400) {
      try {
        return jsonDecode(response.body);
      } catch (_) {
        // Fallback to exception if body is not valid JSON
      }
    }
    throw Exception(response.body.isNotEmpty ? response.body : 'Failed to submit activity');
  }

  Future<List<dynamic>> getActivities(int userId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/api/v1/activities?userId=$userId'),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load activities');
    }
  }

  Future<List<dynamic>> getTerritories({double? minLng, double? minLat, double? maxLng, double? maxLat}) async {
    String url = '$_baseUrl/api/v1/territories';
    if (minLng != null && minLat != null && maxLng != null && maxLat != null) {
      url += '?minLng=$minLng&minLat=$minLat&maxLng=$maxLng&maxLat=$maxLat';
    }

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load territories');
    }
  }

  Future<List<dynamic>> getLeaderboard() async {
    final response = await http.get(Uri.parse('$_baseUrl/api/v1/leaderboards'));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load leaderboard');
    }
  }

  Future<List<String>> getTerritoryEvents() async {
    final response = await http.get(Uri.parse('$_baseUrl/api/v1/territories/events'));

    if (response.statusCode == 200) {
      return List<String>.from(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load territory events');
    }
  }

  Future<Map<String, dynamic>> getPlayerStats(int userId) async {
    final response = await http.get(Uri.parse('$_baseUrl/api/v1/players/me/stats?userId=$userId'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load player stats');
    }
  }

  Future<Map<String, dynamic>?> getBattleStatus(int territoryId) async {
    final response = await http.get(Uri.parse('$_baseUrl/api/v1/battles/$territoryId'));
    if (response.statusCode == 200) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load battle status');
    }
  }

  Future<Map<String, dynamic>> getAttackPrep(int territoryId, int userId) async {
    final response = await http.get(Uri.parse('$_baseUrl/api/v1/battles/$territoryId/attack-prep?userId=$userId'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load attack prep status');
    }
  }

  Future<List<dynamic>> getNotifications(int userId) async {
    final response = await http.get(Uri.parse('$_baseUrl/api/v1/notifications?userId=$userId'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load notifications');
    }
  }

  Future<void> markNotificationRead(int notificationId) async {
    final response = await http.post(Uri.parse('$_baseUrl/api/v1/notifications/$notificationId/read'));
    if (response.statusCode != 200) {
      throw Exception('Failed to mark notification as read');
    }
  }

  Future<List<dynamic>> getTerritoryHistory(int territoryId) async {
    final response = await http.get(Uri.parse('$_baseUrl/api/v1/territories/$territoryId/history'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load territory history');
    }
  }

  Future<Map<String, dynamic>> getProgression(int userId) async {
    final response = await http.get(Uri.parse('$_baseUrl/api/v1/progression?userId=$userId'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load progression stats');
    }
  }

  Future<List<dynamic>> getDailyMissions(int userId) async {
    final response = await http.get(Uri.parse('$_baseUrl/api/v1/missions/daily?userId=$userId'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load daily missions');
    }
  }

  Future<List<dynamic>> getWeeklyMissions(int userId) async {
    final response = await http.get(Uri.parse('$_baseUrl/api/v1/missions/weekly?userId=$userId'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load weekly missions');
    }
  }

  Future<List<dynamic>> getAchievements(int userId) async {
    final response = await http.get(Uri.parse('$_baseUrl/api/v1/achievements/me?userId=$userId'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load achievements');
    }
  }

  Future<List<dynamic>> getRewards(int userId) async {
    final response = await http.get(Uri.parse('$_baseUrl/api/v1/rewards/me?userId=$userId'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load rewards');
    }
  }

  Future<void> claimReward(int userId, int rewardId) async {
    final response = await http.post(Uri.parse('$_baseUrl/api/v1/rewards/$rewardId/claim?userId=$userId'));
    if (response.statusCode != 200) {
      throw Exception(response.body.isNotEmpty ? response.body : 'Failed to claim reward');
    }
  }

  Future<List<dynamic>> getContributionHistory(int userId) async {
    final response = await http.get(Uri.parse('$_baseUrl/api/v1/contribution/history?userId=$userId'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load contribution history');
    }
  }

  Future<Map<String, dynamic>> updateProfile(int userId, String username, String color, double weight, double height, int age, String gender) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/api/v1/players/me?userId=$userId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'color': color,
        'weight': weight,
        'height': height,
        'age': age,
        'gender': gender,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(response.body.isNotEmpty ? response.body : 'Failed to update profile');
    }
  }
}
