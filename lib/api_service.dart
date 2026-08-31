import 'dart:convert';
import 'package:http/http.dart' as http;

/// The central API client for the FitTerra mobile application.
///
/// [Why] This service exists to manage all network operations, mapping mobile user actions
/// to REST requests on the Spring Boot backend server.
///
/// [How] It wraps the `http` package, handling payload serialization, request header injection 
/// (such as `X-User-Id`), status code evaluation, and JSON decoding.
class ApiService {
  // String _baseUrl = 'https://intvl.onrender.com';
  String _baseUrl = 'http://localhost:8080';
 // String _baseUrl = 'http://192.168.1.5:8080'; // Replace with your actual local IP

  /// Instantiates the API service and defines base URL defaults.
  ApiService() {
    // Automatically detect Android emulator vs local machine
    
      // _baseUrl = 'https://intvl.onrender.com';
      _baseUrl = 'http://localhost:8080';
     //  _baseUrl = 'http://[IP_ADDRESS]'; // Replace with your actual local IP

    
  }

  /// Returns the current active server base URL.
  String get baseUrl => _baseUrl;

  /// Updates the server base URL configuration.
  ///
  /// [Why] Allows switching environments (local test, staging, or production) at runtime.
  void setBaseUrl(String url) {
    if (url.isNotEmpty) {
      _baseUrl = url;
    }
  }

  /// Authenticates a player using their email and password.
  ///
  /// [Why] Validates credentials and fetches the authenticated user's profile and session metadata.
  ///
  /// [How] Fires an HTTP POST request to the `/api/v1/auth/login` endpoint. It expects a 200 OK 
  /// response containing the JWT token and user info, otherwise throwing a descriptive exception.
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

  /// Registers a new player account with the system.
  ///
  /// [Why] Allows users to establish their profile metrics, choose theme colors, and seed starting stats.
  ///
  /// [How] Sends an HTTP POST containing player characteristics to `/api/v1/auth/register`. 
  /// It verifies response code 201 Created to validate registration success.
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
    final response = await http.post(
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
      throw Exception(response.body.isNotEmpty ? response.body : 'Failed to register');
    }
  }

  /// Submits completed physical workout metrics and telemetry GPS paths for validation and conquest.
  ///
  /// [Why] Triggers the server-side validation checks (anti-spoofing) and engages the battle/capture engines.
  ///
  /// [How] Fires an HTTP POST to `/api/v1/activities` with the `X-User-Id` header. 
  /// It returns the validation result maps (points earned, level increases, and claimed coordinates).
  Future<Map<String, dynamic>> submitActivity({
    required int userId,
    required String type,
    required int duration,
    required double distance,
    required List<Map<String, double>> points,
    int? targetTerritoryId,
    int? routeInvitationId,
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
        'routeInvitationId': routeInvitationId,
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

  /// Retrieves the history of workout activities logged by the player.
  ///
  /// [Why] Populates the activity list page/feed in the player's diary.
  ///
  /// [How] Hits the GET `/api/v1/activities` endpoint with the target player ID query parameter.
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

  /// Fetches territories from the database within optional bounding box coordinates.
  ///
  /// [Why] Restricts grid query rendering to the user's visible map viewport.
  ///
  /// [How] Hits GET `/api/v1/territories` appending `minLng, minLat, maxLng, maxLat` as URL parameters if supplied.
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

  /// Retrieves the leaderboard standings list.
  ///
  /// [Why] Shows the top players sorted by total claimed area.
  ///
  /// [How] Sends GET request to `/api/v1/leaderboards` returning list of ranks.
  Future<List<dynamic>> getLeaderboard() async {
    final response = await http.get(Uri.parse('$_baseUrl/api/v1/leaderboards'));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load leaderboard');
    }
  }

  /// Retrieves global territory events (captures, siege creations, etc.).
  ///
  /// [Why] Feeds the scrolling news ticker feed on the map screen dashboard.
  ///
  /// [How] Hits GET `/api/v1/territories/events` returning descriptive strings list.
  Future<List<String>> getTerritoryEvents() async {
    final response = await http.get(Uri.parse('$_baseUrl/api/v1/territories/events'));

    if (response.statusCode == 200) {
      return List<String>.from(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load territory events');
    }
  }

  /// Retrieves active player profiles statistics (e.g. area, level, distance).
  ///
  /// [Why] Displays current stats on the user profile tab.
  ///
  /// [How] Fires GET to `/api/v1/players/me/stats?userId=$userId`.
  Future<Map<String, dynamic>> getPlayerStats(int userId) async {
    final response = await http.get(Uri.parse('$_baseUrl/api/v1/players/me/stats?userId=$userId'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load player stats');
    }
  }

  /// Retrieves current active battle/siege parameters for a given territory.
  ///
  /// [Why] Feeds combat panel indicators showing attack progress and timers on the map.
  ///
  /// [How] Hits GET `/api/v1/battles/$territoryId`, returning JSON parameters or null if peaceful.
  Future<Map<String, dynamic>?> getBattleStatus(int territoryId) async {
    final response = await http.get(Uri.parse('$_baseUrl/api/v1/battles/$territoryId'));
    if (response.statusCode == 200) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load battle status');
    }
  }

  /// Gets the count of unique attack prep days logged by a player for a target territory.
  ///
  /// [Why] Shows attack countdown progress requirements (2 unique prep days).
  ///
  /// [How] Fires GET request to `/api/v1/battles/$territoryId/attack-prep?userId=$userId`.
  Future<Map<String, dynamic>> getAttackPrep(int territoryId, int userId) async {
    final response = await http.get(Uri.parse('$_baseUrl/api/v1/battles/$territoryId/attack-prep?userId=$userId'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load attack prep status');
    }
  }

  /// Retrieves unread alert notifications sent to the user.
  ///
  /// [Why] Populates the notification drawer icon and alert lists.
  ///
  /// [How] Queries GET `/api/v1/notifications?userId=$userId`.
  Future<List<dynamic>> getNotifications(int userId) async {
    final response = await http.get(Uri.parse('$_baseUrl/api/v1/notifications?userId=$userId'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load notifications');
    }
  }

  /// Marks a specific notification message as read/dismissed.
  ///
  /// [Why] Updates the unread badge and database state when a user clicks/dismisses alerts.
  ///
  /// [How] Sends POST to `/api/v1/notifications/$notificationId/read`.
  Future<void> markNotificationRead(int notificationId) async {
    final response = await http.post(Uri.parse('$_baseUrl/api/v1/notifications/$notificationId/read'));
    if (response.statusCode != 200) {
      throw Exception('Failed to mark notification as read');
    }
  }

  /// Retrieves audit records showing owner history of a territory.
  ///
  /// [Why] Populates history tickers detailing who created/captured/decayed the zone.
  ///
  /// [How] Gets history rows from `/api/v1/territories/$territoryId/history`.
  Future<List<dynamic>> getTerritoryHistory(int territoryId) async {
    final response = await http.get(Uri.parse('$_baseUrl/api/v1/territories/$territoryId/history'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load territory history');
    }
  }

  /// Gets player progression summary details (total XP, XP to next level, coin balance).
  ///
  /// [Why] Used to render progress bars and level indicators.
  ///
  /// [How] Fires GET `/api/v1/progression?userId=$userId`.
  Future<Map<String, dynamic>> getProgression(int userId) async {
    final response = await http.get(Uri.parse('$_baseUrl/api/v1/progression?userId=$userId'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load progression stats');
    }
  }

  /// Retrieves active daily missions for a user.
  ///
  /// [Why] Populates daily quest checklist panels.
  ///
  /// [How] Hits GET `/api/v1/missions/daily?userId=$userId`.
  Future<List<dynamic>> getDailyMissions(int userId) async {
    final response = await http.get(Uri.parse('$_baseUrl/api/v1/missions/daily?userId=$userId'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load daily missions');
    }
  }

  /// Retrieves active weekly missions for a user.
  ///
  /// [Why] Populates weekly challenge checklists.
  ///
  /// [How] Hits GET `/api/v1/missions/weekly?userId=$userId`.
  Future<List<dynamic>> getWeeklyMissions(int userId) async {
    final response = await http.get(Uri.parse('$_baseUrl/api/v1/missions/weekly?userId=$userId'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load weekly missions');
    }
  }

  /// Fetches achievements unlock progress metadata.
  ///
  /// [Why] Shows unlocked badges and locked milestones in the user achievements pane.
  ///
  /// [How] Hits GET `/api/v1/achievements/me?userId=$userId`.
  Future<List<dynamic>> getAchievements(int userId) async {
    final response = await http.get(Uri.parse('$_baseUrl/api/v1/achievements/me?userId=$userId'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load achievements');
    }
  }

  /// Retrieves available cosmetic/title rewards templates and user claim logs.
  ///
  /// [Why] Populates the store/shop dashboard for buying cosmetics.
  ///
  /// [How] Hits GET `/api/v1/rewards/me?userId=$userId`.
  Future<List<dynamic>> getRewards(int userId) async {
    final response = await http.get(Uri.parse('$_baseUrl/api/v1/rewards/me?userId=$userId'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load rewards');
    }
  }

  /// Claims/purchases a specific cosmetic reward using virtual coins.
  ///
  /// [Why] Allows users to unlock badges/avatars when they reach level/coin thresholds.
  ///
  /// [How] Fires POST to `/api/v1/rewards/$rewardId/claim?userId=$userId`.
  Future<void> claimReward(int userId, int rewardId) async {
    final response = await http.post(Uri.parse('$_baseUrl/api/v1/rewards/$rewardId/claim?userId=$userId'));
    if (response.statusCode != 200) {
      throw Exception(response.body.isNotEmpty ? response.body : 'Failed to claim reward');
    }
  }

  /// Retrieves historical record of XP contributions.
  ///
  /// [Why] Used to display workout and level progression history lines.
  ///
  /// [How] Hits GET `/api/v1/contribution/history?userId=$userId`.
  Future<List<dynamic>> getContributionHistory(int userId) async {
    final response = await http.get(Uri.parse('$_baseUrl/api/v1/contribution/history?userId=$userId'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load contribution history');
    }
  }

  /// Updates profile metadata metrics (username, avatar tint color, weight, height, age, gender).
  ///
  /// [Why] Essential to customize visual markers and anti-cheat validation variables.
  ///
  /// [How] Sends PUT to `/api/v1/players/me?userId=$userId` containing JSON updates.
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

  // Friendship APIs

  /// Retrieves the active friends list for a user.
  ///
  /// [Why] Populates lists on the friends list dashboard.
  ///
  /// [How] Hits GET `/api/v1/friends?userId=$userId`.
  Future<List<dynamic>> getFriends(int userId) async {
    final response = await http.get(Uri.parse('$_baseUrl/api/v1/friends?userId=$userId'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load friends list');
    }
  }

  /// Retrieves pending incoming friend invitations.
  ///
  /// [Why] Alerts the player to request acceptances pending response.
  ///
  /// [How] Hits GET `/api/v1/friends/pending?userId=$userId`.
  Future<List<dynamic>> getPendingFriendRequests(int userId) async {
    final response = await http.get(Uri.parse('$_baseUrl/api/v1/friends/pending?userId=$userId'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load pending friend requests');
    }
  }

  /// Dispatches a new friend invitation request.
  ///
  /// [Why] Lets players add friends by searching their handles.
  ///
  /// [How] Fires POST to `/api/v1/friends/request?userId=$userId&friendUsername=$friendUsername`.
  Future<Map<String, dynamic>> sendFriendRequest(int userId, String friendUsername) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/v1/friends/request?userId=$userId&friendUsername=$friendUsername'),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final body = jsonDecode(response.body);
      throw Exception(body['error'] ?? 'Failed to send friend request');
    }
  }

  /// Approves a pending friend invitation.
  ///
  /// [Why] Establishes a mutual friendship, opening access to route challenges.
  ///
  /// [How] Fires POST to `/api/v1/friends/accept?userId=$userId&friendshipId=$friendshipId`.
  Future<Map<String, dynamic>> acceptFriendRequest(int userId, int friendshipId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/v1/friends/accept?userId=$userId&friendshipId=$friendshipId'),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final body = jsonDecode(response.body);
      throw Exception(body['error'] ?? 'Failed to accept friend request');
    }
  }

  /// Rejects or cancels a pending friend invitation.
  ///
  /// [Why] Dismisses or deletes request lines.
  ///
  /// [How] Fires POST to `/api/v1/friends/reject?userId=$userId&friendshipId=$friendshipId`.
  Future<Map<String, dynamic>> rejectFriendRequest(int userId, int friendshipId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/v1/friends/reject?userId=$userId&friendshipId=$friendshipId'),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final body = jsonDecode(response.body);
      throw Exception(body['error'] ?? 'Failed to reject/remove friend request');
    }
  }

  // Route Invitation APIs

  /// Retrieves pending route matching invitations.
  ///
  /// [Why] Lists route runs friends challenged you to repeat.
  ///
  /// [How] Hits GET `/api/v1/route-invitations/pending?userId=$userId`.
  Future<List<dynamic>> getPendingInvitations(int userId) async {
    final response = await http.get(Uri.parse('$_baseUrl/api/v1/route-invitations/pending?userId=$userId'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load pending invitations');
    }
  }

  /// Retrieves active challenges the player accepted.
  ///
  /// [Why] Displays challenges that you can record matching runs for on the map.
  ///
  /// [How] Hits GET `/api/v1/route-invitations/active?userId=$userId`.
  Future<List<dynamic>> getActiveInvitations(int userId) async {
    final response = await http.get(Uri.parse('$_baseUrl/api/v1/route-invitations/active?userId=$userId'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load active challenges');
    }
  }

  /// Retrieves challenges the user sent to friends.
  ///
  /// [Why] Lists outgoing challenges that friends have not completed yet.
  ///
  /// [How] Hits GET `/api/v1/route-invitations/sent?userId=$userId`.
  Future<List<dynamic>> getSentInvitations(int userId) async {
    final response = await http.get(Uri.parse('$_baseUrl/api/v1/route-invitations/sent?userId=$userId'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load sent invitations');
    }
  }

  /// Dispatches a route challenge invitation to a friend.
  ///
  /// [Why] Invites friends to repeat a specific run path and match the GPS telemetry.
  ///
  /// [How] Hits POST `/api/v1/route-invitations` with friend and activity parameters.
  Future<Map<String, dynamic>> createInvitation(int userId, int friendId, int activityId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/v1/route-invitations?userId=$userId&friendId=$friendId&activityId=$activityId'),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final body = jsonDecode(response.body);
      throw Exception(body['error'] ?? 'Failed to send route invitation');
    }
  }

  /// Accepts a pending route challenge.
  ///
  /// [Why] Transitions a challenge state to active, letting the user try to run it.
  ///
  /// [How] Hits POST `/api/v1/route-invitations/$invitationId/accept?userId=$userId`.
  Future<Map<String, dynamic>> acceptInvitation(int userId, int invitationId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/v1/route-invitations/$invitationId/accept?userId=$userId'),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final body = jsonDecode(response.body);
      throw Exception(body['error'] ?? 'Failed to accept route invitation');
    }
  }

  /// Rejects a pending route challenge.
  ///
  /// [Why] Dismisses or deletes incoming challenge records.
  ///
  /// [How] Hits POST `/api/v1/route-invitations/$invitationId/reject?userId=$userId`.
  Future<Map<String, dynamic>> rejectInvitation(int userId, int invitationId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/v1/route-invitations/$invitationId/reject?userId=$userId'),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final body = jsonDecode(response.body);
      throw Exception(body['error'] ?? 'Failed to reject route invitation');
    }
  }

  // Club APIs

  /// Retrieves details of the club the user belongs to.
  ///
  /// [Why] Feeds fields on the Club Dashboard tab.
  ///
  /// [How] Hits GET `/api/v1/clubs/me` with `X-User-Id` header.
  Future<Map<String, dynamic>?> getMyClub(int userId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/api/v1/clubs/me'),
      headers: {'X-User-Id': userId.toString()},
    );
    if (response.statusCode == 200) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load club details');
    }
  }

  /// Creates a new public club.
  ///
  /// [Why] Allows users to start a guild and invite other players.
  ///
  /// [How] Sends POST to `/api/v1/clubs` with metadata fields and `X-User-Id` header.
  Future<Map<String, dynamic>> createClub(int userId, String name, String username, String description) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/v1/clubs'),
      headers: {
        'X-User-Id': userId.toString(),
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'name': name,
        'username': username,
        'description': description,
      }),
    );
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception(response.body.isNotEmpty ? response.body : 'Failed to create club');
    }
  }

  /// Joins an existing club using an invite code.
  ///
  /// [Why] Adds the player to the club roster to contribute stats and XP.
  ///
  /// [How] Sends POST to `/api/v1/clubs/join` with `inviteCode` and `X-User-Id` header.
  Future<Map<String, dynamic>> joinClub(int userId, String inviteCode) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/v1/clubs/join'),
      headers: {
        'X-User-Id': userId.toString(),
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'inviteCode': inviteCode,
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(response.body.isNotEmpty ? response.body : 'Failed to join club');
    }
  }

  /// Leaves the current club.
  ///
  /// [Why] Removes the member status from the club.
  ///
  /// [How] Fires POST to `/api/v1/clubs/leave` with the caller's user ID in headers.
  Future<void> leaveClub(int userId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/v1/clubs/leave'),
      headers: {'X-User-Id': userId.toString()},
    );
    if (response.statusCode != 200) {
      throw Exception(response.body.isNotEmpty ? response.body : 'Failed to leave club');
    }
  }

  /// Updates the role/rank of a target member.
  ///
  /// [Why] Allows leaders/admins to promote or demote members.
  ///
  /// [How] Hits POST `/api/v1/clubs/members/$targetUserId/role?role=$role` with the administrator user ID in headers.
  Future<void> updateMemberRole(int userId, int targetUserId, String role) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/v1/clubs/members/$targetUserId/role?role=$role'),
      headers: {'X-User-Id': userId.toString()},
    );
    if (response.statusCode != 200) {
      throw Exception(response.body.isNotEmpty ? response.body : 'Failed to update role');
    }
  }

  /// Kicks/expels a target member from the club.
  ///
  /// [Why] Allows club moderators to remove inactive/unruly players.
  ///
  /// [How] Hits POST `/api/v1/clubs/members/$targetUserId/kick` with user ID headers.
  Future<void> kickMember(int userId, int targetUserId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/v1/clubs/members/$targetUserId/kick'),
      headers: {'X-User-Id': userId.toString()},
    );
    if (response.statusCode != 200) {
      throw Exception(response.body.isNotEmpty ? response.body : 'Failed to kick member');
    }
  }

  /// Searches public clubs by name or handle keyword match.
  ///
  /// [Why] Populates list items in the club discovery tab.
  ///
  /// [How] Fires GET to `/api/v1/clubs/search?query=$query`.
  Future<List<dynamic>> searchClubs(String query) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/api/v1/clubs/search?query=${Uri.encodeComponent(query)}'),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to search clubs');
    }
  }
}
