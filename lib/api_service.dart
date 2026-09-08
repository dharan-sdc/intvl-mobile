import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// The central API client for the FitTerra / Trion mobile application.
///
/// Features automated request/response logging, latency measurement,
/// connection diagnostic probes, and structured error extraction.
class ApiService {
   String _baseUrl = 'http://localhost:8080';
  //String _baseUrl = 'https://intvl-api.onrender.com';
  // String _baseUrl = 'http://[IP_ADDRESS]'; // Replace with your actual local IP

  ApiService({String? initialBaseUrl}) {
    if (initialBaseUrl != null && initialBaseUrl.isNotEmpty) {
      _baseUrl = initialBaseUrl;
    }
  }

  /// Returns the current active server base URL.
  String get baseUrl => _baseUrl;

  /// Updates the server base URL configuration.
  void setBaseUrl(String url) {
    if (url.isNotEmpty) {
      _baseUrl = url;
      debugPrint('🔄 [API CONFIG] Base URL updated to: $_baseUrl');
    }
  }

  // ==========================================
  // CENTRAL LOGGING HTTP CLIENT WRAPPERS
  // ==========================================

  String _truncate(String text, int maxLen) {
    if (text.length <= maxLen) return text;
    return '${text.substring(0, maxLen)}...';
  }

  Future<http.Response> _httpGet(Uri uri, {Map<String, String>? headers}) async {
    final sw = Stopwatch()..start();
    debugPrint('🌐 [API REQ] GET $uri');
    try {
      final response = await http.get(uri, headers: headers);
      sw.stop();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('✅ [API RES ${response.statusCode}] GET $uri (${sw.elapsedMilliseconds}ms)');
      } else {
        debugPrint('⚠️ [API RES ${response.statusCode}] GET $uri (${sw.elapsedMilliseconds}ms) -> ${_truncate(response.body, 150)}');
      }
      return response;
    } catch (e) {
      sw.stop();
      debugPrint('🚫 [API CONNECTION FAILED] GET $uri (${sw.elapsedMilliseconds}ms) -> Error: $e');
      debugPrint('💡 [DIAGNOSTIC] Check backend server at $_baseUrl (ensure Spring Boot is running and reachable).');
      rethrow;
    }
  }

  Future<http.Response> _httpPost(Uri uri, {Map<String, String>? headers, Object? body}) async {
    final sw = Stopwatch()..start();
    debugPrint('🌐 [API REQ] POST $uri');
    try {
      final response = await http.post(uri, headers: headers, body: body);
      sw.stop();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('✅ [API RES ${response.statusCode}] POST $uri (${sw.elapsedMilliseconds}ms)');
      } else {
        debugPrint('⚠️ [API RES ${response.statusCode}] POST $uri (${sw.elapsedMilliseconds}ms) -> ${_truncate(response.body, 150)}');
      }
      return response;
    } catch (e) {
      sw.stop();
      debugPrint('🚫 [API CONNECTION FAILED] POST $uri (${sw.elapsedMilliseconds}ms) -> Error: $e');
      debugPrint('💡 [DIAGNOSTIC] Check backend server at $_baseUrl (ensure Spring Boot is running and reachable).');
      rethrow;
    }
  }

  Future<http.Response> _httpPut(Uri uri, {Map<String, String>? headers, Object? body}) async {
    final sw = Stopwatch()..start();
    debugPrint('🌐 [API REQ] PUT $uri');
    try {
      final response = await http.put(uri, headers: headers, body: body);
      sw.stop();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('✅ [API RES ${response.statusCode}] PUT $uri (${sw.elapsedMilliseconds}ms)');
      } else {
        debugPrint('⚠️ [API RES ${response.statusCode}] PUT $uri (${sw.elapsedMilliseconds}ms) -> ${_truncate(response.body, 150)}');
      }
      return response;
    } catch (e) {
      sw.stop();
      debugPrint('🚫 [API CONNECTION FAILED] PUT $uri (${sw.elapsedMilliseconds}ms) -> Error: $e');
      debugPrint('💡 [DIAGNOSTIC] Check backend server at $_baseUrl (ensure Spring Boot is running and reachable).');
      rethrow;
    }
  }

  /// Pings backend health check to verify connectivity.
  Future<bool> checkBackendConnection() async {
    debugPrint('🔍 [BACKEND PROBE] Testing connection to: $_baseUrl/api/v1/health ...');
    try {
      final response = await _httpGet(Uri.parse('$_baseUrl/api/v1/health'));
      if (response.statusCode == 200) {
        debugPrint('🎉 [BACKEND ONLINE] Successfully connected to backend at $_baseUrl (status: UP)');
        return true;
      } else {
        debugPrint('⚠️ [BACKEND WARNING] Ping returned HTTP ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ [BACKEND OFFLINE] Could not establish connection to $_baseUrl: $e');
      return false;
    }
  }

  /// Extracts error messages from backend responses (JSON/HTML/Plaintext).
  String _extractErrorMessage(http.Response response, String defaultMsg) {
    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          if (decoded['message'] != null && decoded['message'].toString().trim().isNotEmpty) {
            return decoded['message'].toString().trim();
          }
          if (decoded['error'] != null && decoded['error'].toString().trim().isNotEmpty) {
            return decoded['error'].toString().trim();
          }
          if (decoded['detail'] != null && decoded['detail'].toString().trim().isNotEmpty) {
            return decoded['detail'].toString().trim();
          }
        }
      } catch (_) {}

      if (response.body.startsWith('<') || response.body.contains('<html')) {
        if (response.statusCode == 502) return 'Server is temporarily unavailable (502 Bad Gateway).';
        if (response.statusCode == 503) return 'Server is down for maintenance (503 Service Unavailable).';
        if (response.statusCode == 504) return 'Server request timed out (504 Gateway Timeout).';
        if (response.statusCode == 500) return 'Internal server error (500). Please try again later.';
        if (response.statusCode == 404) return 'Resource not found (404).';
        if (response.statusCode == 401) return 'Invalid credentials or session expired.';
        if (response.statusCode == 403) return 'Access denied (403).';
        return 'Server error (${response.statusCode}). Please try again later.';
      }
      return response.body;
    }
    return defaultMsg;
  }

  // ==========================================
  // AUTHENTICATION APIS
  // ==========================================

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _httpPost(
      Uri.parse('$_baseUrl/api/v1/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(_extractErrorMessage(response, 'Failed to login'));
    }
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String username,
    required String firstName,
    required String lastName,
    required String dob,
    required String profilePic,
    required String color,
    required double weight,
    required double height,
    required int age,
    required String gender,
  }) async {
    final response = await _httpPost(
      Uri.parse('$_baseUrl/api/v1/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'username': username,
        'firstName': firstName,
        'lastName': lastName,
        'dob': dob,
        'profilePic': profilePic,
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
      throw Exception(_extractErrorMessage(response, 'Failed to register'));
    }
  }

  // ==========================================
  // ACTIVITIES & TRACKING APIS
  // ==========================================

  Future<Map<String, dynamic>> submitActivity({
    required int userId,
    required String type,
    required int duration,
    required double distance,
    required List<Map<String, double>> points,
    int? targetTerritoryId,
    int? routeInvitationId,
  }) async {
    final response = await _httpPost(
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
        'routeInvitationId': routeInvitationId,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 400) {
      try {
        return jsonDecode(response.body);
      } catch (_) {}
    }
    throw Exception(_extractErrorMessage(response, 'Failed to submit activity'));
  }

  Future<List<dynamic>> getActivities(int userId) async {
    final response = await _httpGet(
      Uri.parse('$_baseUrl/api/v1/activities?userId=$userId'),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load activities');
    }
  }

  // ==========================================
  // TERRITORIES & MAP APIS
  // ==========================================

  Future<List<dynamic>> getTerritories({double? minLng, double? minLat, double? maxLng, double? maxLat}) async {
    String url = '$_baseUrl/api/v1/territories';
    if (minLng != null && minLat != null && maxLng != null && maxLat != null) {
      url += '?minLng=$minLng&minLat=$minLat&maxLng=$maxLng&maxLat=$maxLat';
    }

    final response = await _httpGet(Uri.parse(url));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load territories');
    }
  }

  Future<List<dynamic>> getLeaderboard() async {
    final response = await _httpGet(Uri.parse('$_baseUrl/api/v1/leaderboards'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load leaderboard');
    }
  }

  Future<List<String>> getTerritoryEvents() async {
    final response = await _httpGet(Uri.parse('$_baseUrl/api/v1/territories/events'));
    if (response.statusCode == 200) {
      return List<String>.from(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load territory events');
    }
  }

  Future<Map<String, dynamic>> getPlayerStats(int userId) async {
    final response = await _httpGet(Uri.parse('$_baseUrl/api/v1/players/me/stats?userId=$userId'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load player stats');
    }
  }

  Future<Map<String, dynamic>?> getBattleStatus(int territoryId) async {
    final response = await _httpGet(Uri.parse('$_baseUrl/api/v1/battles/$territoryId'));
    if (response.statusCode == 200) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load battle status');
    }
  }

  Future<Map<String, dynamic>> getAttackPrep(int territoryId, int userId) async {
    final response = await _httpGet(Uri.parse('$_baseUrl/api/v1/battles/$territoryId/attack-prep?userId=$userId'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load attack prep status');
    }
  }

  Future<List<dynamic>> getNotifications(int userId) async {
    final response = await _httpGet(Uri.parse('$_baseUrl/api/v1/notifications?userId=$userId'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load notifications');
    }
  }

  Future<void> markNotificationRead(int notificationId) async {
    final response = await _httpPost(Uri.parse('$_baseUrl/api/v1/notifications/$notificationId/read'));
    if (response.statusCode != 200) {
      throw Exception('Failed to mark notification as read');
    }
  }

  Future<List<dynamic>> getTerritoryHistory(int territoryId) async {
    final response = await _httpGet(Uri.parse('$_baseUrl/api/v1/territories/$territoryId/history'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load territory history');
    }
  }

  // ==========================================
  // PROGRESSION, MISSIONS & REWARDS APIS
  // ==========================================

  Future<Map<String, dynamic>> getProgression(int userId) async {
    final response = await _httpGet(Uri.parse('$_baseUrl/api/v1/progression?userId=$userId'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load progression stats');
    }
  }

  Future<List<dynamic>> getDailyMissions(int userId) async {
    final response = await _httpGet(Uri.parse('$_baseUrl/api/v1/missions/daily?userId=$userId'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load daily missions');
    }
  }

  Future<List<dynamic>> getWeeklyMissions(int userId) async {
    final response = await _httpGet(Uri.parse('$_baseUrl/api/v1/missions/weekly?userId=$userId'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load weekly missions');
    }
  }

  Future<List<dynamic>> getAchievements(int userId) async {
    final response = await _httpGet(Uri.parse('$_baseUrl/api/v1/achievements/me?userId=$userId'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load achievements');
    }
  }

  Future<List<dynamic>> getRewards(int userId) async {
    final response = await _httpGet(Uri.parse('$_baseUrl/api/v1/rewards/me?userId=$userId'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load rewards');
    }
  }

  Future<void> claimReward(int userId, int rewardId) async {
    final response = await _httpPost(Uri.parse('$_baseUrl/api/v1/rewards/$rewardId/claim?userId=$userId'));
    if (response.statusCode != 200) {
      throw Exception(_extractErrorMessage(response, 'Failed to claim reward'));
    }
  }

  Future<List<dynamic>> getContributionHistory(int userId) async {
    final response = await _httpGet(Uri.parse('$_baseUrl/api/v1/contribution/history?userId=$userId'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(_extractErrorMessage(response, 'Failed to load contribution history'));
    }
  }

  Future<Map<String, dynamic>> updateProfile(int userId, String username, String color, double weight, double height, int age, String gender) async {
    final response = await _httpPut(
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
      throw Exception(_extractErrorMessage(response, 'Failed to update profile'));
    }
  }

  // ==========================================
  // FRIENDSHIP & ROUTE CHALLENGE APIS
  // ==========================================

  Future<List<dynamic>> getFriends(int userId) async {
    final response = await _httpGet(Uri.parse('$_baseUrl/api/v1/friends?userId=$userId'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(_extractErrorMessage(response, 'Failed to load friends list'));
    }
  }

  Future<List<dynamic>> getPendingFriendRequests(int userId) async {
    final response = await _httpGet(Uri.parse('$_baseUrl/api/v1/friends/pending?userId=$userId'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(_extractErrorMessage(response, 'Failed to load pending friend requests'));
    }
  }

  Future<Map<String, dynamic>> sendFriendRequest(int userId, String friendUsername) async {
    final response = await _httpPost(
      Uri.parse('$_baseUrl/api/v1/friends/request?userId=$userId&friendUsername=$friendUsername'),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(_extractErrorMessage(response, 'Failed to send friend request'));
    }
  }

  Future<Map<String, dynamic>> acceptFriendRequest(int userId, int friendshipId) async {
    final response = await _httpPost(
      Uri.parse('$_baseUrl/api/v1/friends/accept?userId=$userId&friendshipId=$friendshipId'),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(_extractErrorMessage(response, 'Failed to accept friend request'));
    }
  }

  Future<Map<String, dynamic>> rejectFriendRequest(int userId, int friendshipId) async {
    final response = await _httpPost(
      Uri.parse('$_baseUrl/api/v1/friends/reject?userId=$userId&friendshipId=$friendshipId'),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(_extractErrorMessage(response, 'Failed to reject friend request'));
    }
  }

  Future<List<dynamic>> getPendingInvitations(int userId) async {
    final response = await _httpGet(Uri.parse('$_baseUrl/api/v1/route-invitations/pending?userId=$userId'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(_extractErrorMessage(response, 'Failed to load pending invitations'));
    }
  }

  Future<List<dynamic>> getActiveInvitations(int userId) async {
    final response = await _httpGet(Uri.parse('$_baseUrl/api/v1/route-invitations/active?userId=$userId'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(_extractErrorMessage(response, 'Failed to load active challenges'));
    }
  }

  Future<List<dynamic>> getSentInvitations(int userId) async {
    final response = await _httpGet(Uri.parse('$_baseUrl/api/v1/route-invitations/sent?userId=$userId'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(_extractErrorMessage(response, 'Failed to load sent invitations'));
    }
  }

  Future<Map<String, dynamic>> createInvitation(int userId, int friendId, int activityId) async {
    final response = await _httpPost(
      Uri.parse('$_baseUrl/api/v1/route-invitations?userId=$userId&friendId=$friendId&activityId=$activityId'),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(_extractErrorMessage(response, 'Failed to send route invitation'));
    }
  }

  Future<Map<String, dynamic>> acceptInvitation(int userId, int invitationId) async {
    final response = await _httpPost(
      Uri.parse('$_baseUrl/api/v1/route-invitations/$invitationId/accept?userId=$userId'),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(_extractErrorMessage(response, 'Failed to accept route invitation'));
    }
  }

  Future<Map<String, dynamic>> rejectInvitation(int userId, int invitationId) async {
    final response = await _httpPost(
      Uri.parse('$_baseUrl/api/v1/route-invitations/$invitationId/reject?userId=$userId'),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(_extractErrorMessage(response, 'Failed to reject route invitation'));
    }
  }

  // ==========================================
  // CLUB / GUILD APIS
  // ==========================================

  Future<Map<String, dynamic>?> getMyClub(int userId) async {
    final response = await _httpGet(
      Uri.parse('$_baseUrl/api/v1/clubs/me'),
      headers: {'X-User-Id': userId.toString()},
    );
    if (response.statusCode == 200) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    } else {
      throw Exception(_extractErrorMessage(response, 'Failed to load club details'));
    }
  }

  Future<Map<String, dynamic>> createClub(int userId, String name, String username, String description, {String? logo}) async {
    final response = await _httpPost(
      Uri.parse('$_baseUrl/api/v1/clubs'),
      headers: {
        'Content-Type': 'application/json',
        'X-User-Id': userId.toString(),
      },
      body: jsonEncode({
        'name': name,
        'username': username,
        'description': description,
        'logo': logo,
      }),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception(_extractErrorMessage(response, 'Failed to create club'));
    }
  }

  Future<Map<String, dynamic>> joinClub(int userId, String inviteCode) async {
    final response = await _httpPost(
      Uri.parse('$_baseUrl/api/v1/clubs/join?inviteCode=${Uri.encodeComponent(inviteCode)}'),
      headers: {'X-User-Id': userId.toString()},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(_extractErrorMessage(response, 'Failed to join club'));
    }
  }

  Future<void> leaveClub(int userId) async {
    final response = await _httpPost(
      Uri.parse('$_baseUrl/api/v1/clubs/leave'),
      headers: {'X-User-Id': userId.toString()},
    );
    if (response.statusCode != 200) {
      throw Exception(_extractErrorMessage(response, 'Failed to leave club'));
    }
  }

  Future<void> updateMemberRole(int userId, int targetUserId, String role) async {
    final response = await _httpPost(
      Uri.parse('$_baseUrl/api/v1/clubs/members/$targetUserId/role?role=$role'),
      headers: {'X-User-Id': userId.toString()},
    );
    if (response.statusCode != 200) {
      throw Exception(_extractErrorMessage(response, 'Failed to update role'));
    }
  }

  Future<void> kickMember(int userId, int targetUserId) async {
    final response = await _httpPost(
      Uri.parse('$_baseUrl/api/v1/clubs/members/$targetUserId/kick'),
      headers: {'X-User-Id': userId.toString()},
    );
    if (response.statusCode != 200) {
      throw Exception(_extractErrorMessage(response, 'Failed to kick member'));
    }
  }

  Future<List<dynamic>> searchClubs(String query) async {
    final response = await _httpGet(
      Uri.parse('$_baseUrl/api/v1/clubs/search?query=${Uri.encodeComponent(query)}'),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(_extractErrorMessage(response, 'Failed to search clubs'));
    }
  }

  // ==========================================
  // CAMPAIGNS & AWARENESS CHALLENGES API
  // ==========================================

  Future<List<dynamic>> getCampaigns({String? type, String? status, int? userId}) async {
    final queryParams = <String, String>{};
    if (type != null && type.isNotEmpty && type != 'ALL') queryParams['type'] = type;
    if (status != null && status.isNotEmpty) queryParams['status'] = status;
    if (userId != null) queryParams['userId'] = userId.toString();

    final uri = Uri.parse('$_baseUrl/api/v1/campaigns').replace(queryParameters: queryParams.isEmpty ? null : queryParams);
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (userId != null) headers['X-User-Id'] = userId.toString();

    final response = await _httpGet(uri, headers: headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(_extractErrorMessage(response, 'Failed to load campaigns'));
    }
  }

  Future<Map<String, dynamic>> getCampaignDetails(int campaignId, {int? userId}) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (userId != null) headers['X-User-Id'] = userId.toString();

    final uri = Uri.parse('$_baseUrl/api/v1/campaigns/$campaignId${userId != null ? '?userId=$userId' : ''}');
    final response = await _httpGet(uri, headers: headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(_extractErrorMessage(response, 'Failed to load campaign details'));
    }
  }

  Future<Map<String, dynamic>> joinCampaign(int campaignId, int userId, {int? organizationId, String? organizationName, int? clubId}) async {
    final response = await _httpPost(
      Uri.parse('$_baseUrl/api/v1/campaigns/$campaignId/join'),
      headers: {
        'Content-Type': 'application/json',
        'X-User-Id': userId.toString(),
      },
      body: jsonEncode({
        if (organizationId != null) 'organizationId': organizationId,
        if (organizationName != null) 'organizationName': organizationName,
        if (clubId != null) 'clubId': clubId,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(_extractErrorMessage(response, 'Failed to join campaign'));
    }
  }

  Future<List<dynamic>> getMyCampaigns(int userId) async {
    final response = await _httpGet(
      Uri.parse('$_baseUrl/api/v1/campaigns/me'),
      headers: {
        'Content-Type': 'application/json',
        'X-User-Id': userId.toString(),
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(_extractErrorMessage(response, 'Failed to load enrolled campaigns'));
    }
  }

  Future<Map<String, dynamic>> getCampaignDashboard(int campaignId, int userId) async {
    final response = await _httpGet(
      Uri.parse('$_baseUrl/api/v1/campaigns/$campaignId/dashboard'),
      headers: {
        'Content-Type': 'application/json',
        'X-User-Id': userId.toString(),
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(_extractErrorMessage(response, 'Failed to load campaign dashboard'));
    }
  }

  Future<Map<String, dynamic>> getCampaignLeaderboard(int campaignId, {String view = 'INDIVIDUAL', int? userId}) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (userId != null) headers['X-User-Id'] = userId.toString();

    final response = await _httpGet(
      Uri.parse('$_baseUrl/api/v1/campaigns/$campaignId/leaderboard?view=$view${userId != null ? '&userId=$userId' : ''}'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(_extractErrorMessage(response, 'Failed to load campaign leaderboard'));
    }
  }
}
