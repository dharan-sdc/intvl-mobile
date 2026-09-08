import 'dart:convert';

/// Centralized error handling and user-facing message translation utility.
///
/// [Why] Translates technical runtime exceptions, SocketExceptions, HTTP error codes,
/// timeout errors, and raw JSON/HTML responses into clear, friendly messages for the UI.
class ErrorHandler {
  /// Parses any exception or error object and returns a clean, human-readable user message.
  static String parse(dynamic error, [String defaultMessage = 'An unexpected error occurred. Please try again.']) {
    if (error == null) return defaultMessage;

    String errStr = error.toString().trim();

    // 1. Clean Dart error prefixes
    errStr = errStr
        .replaceAll('Exception: ', '')
        .replaceAll('ClientException: ', '')
        .replaceAll('SocketException: ', '')
        .replaceAll('HttpException: ', '')
        .replaceAll('FormatException: ', '')
        .replaceAll('TimeoutException: ', '')
        .replaceAll('PlatformException: ', '')
        .trim();

    final lower = errStr.toLowerCase();

    // 2. Network connectivity & socket failure matching
    if (lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('no address associated with hostname') ||
        lower.contains('network is unreachable') ||
        lower.contains('connection refused') ||
        lower.contains('connection reset') ||
        lower.contains('connection closed') ||
        lower.contains('software caused connection abort') ||
        lower.contains('connection timed out') ||
        lower.contains('clientexception') ||
        lower.contains('no internet') ||
        lower.contains('network error')) {
      return 'No internet connection. Please check your network and try again.';
    }

    // 3. Timeout failures
    if (lower.contains('timeoutexception') ||
        lower.contains('future not completed') ||
        lower.contains('timed out') ||
        lower.contains('deadline exceeded')) {
      return 'Connection timed out. The server took too long to respond. Please try again.';
    }

    // 4. SSL / Handshake failures
    if (lower.contains('handshakeexception') ||
        lower.contains('cert_authority_invalid') ||
        lower.contains('tlsexception') ||
        lower.contains('certificate')) {
      return 'Secure connection failed. Please check your device date & time and network.';
    }

    // 5. HTML error pages (e.g. 502 Bad Gateway / Cloudflare / 503)
    if (errStr.startsWith('<!DOCTYPE') ||
        errStr.startsWith('<html') ||
        errStr.contains('<html>') ||
        errStr.contains('<head>') ||
        errStr.contains('<body>')) {
      if (errStr.contains('502') || errStr.contains('Bad Gateway')) {
        return 'Server is temporarily unavailable (502 Bad Gateway). Please try again shortly.';
      } else if (errStr.contains('503') || errStr.contains('Service Unavailable')) {
        return 'Server is undergoing maintenance (503). Please check back soon.';
      } else if (errStr.contains('504') || errStr.contains('Gateway Timeout')) {
        return 'Server gateway timed out (504). Please try again in a few moments.';
      } else if (errStr.contains('500') || errStr.contains('Internal Server Error')) {
        return 'Server encountered an internal error (500). Please try again later.';
      }
      return 'Server is currently unreachable. Please try again shortly.';
    }

    // 6. JSON error payloads (e.g. {"message": "...", "error": "...", "status": 400})
    if ((errStr.startsWith('{') && errStr.endsWith('}')) || (errStr.startsWith('[') && errStr.endsWith(']'))) {
      try {
        final decoded = jsonDecode(errStr);
        if (decoded is Map<String, dynamic>) {
          if (decoded['message'] != null && decoded['message'].toString().trim().isNotEmpty) {
            return _cleanMessage(decoded['message'].toString());
          }
          if (decoded['error'] != null && decoded['error'].toString().trim().isNotEmpty) {
            return _cleanMessage(decoded['error'].toString());
          }
          if (decoded['detail'] != null && decoded['detail'].toString().trim().isNotEmpty) {
            return _cleanMessage(decoded['detail'].toString());
          }
          if (decoded['reason'] != null && decoded['reason'].toString().trim().isNotEmpty) {
            return _cleanMessage(decoded['reason'].toString());
          }
          if (decoded['status'] == 401) {
            return 'Invalid email or password.';
          }
          if (decoded['status'] == 403) {
            return 'Access denied. You do not have permission.';
          }
          if (decoded['status'] == 404) {
            return 'Requested item was not found.';
          }
        }
      } catch (_) {
        // Not valid JSON, proceed
      }
    }

    // 7. Common business logic error phrases
    if (lower.contains('failed to register') ||
        lower.contains('user already exists') ||
        lower.contains('email already in use') ||
        lower.contains('email already exists') ||
        lower.contains('username already taken')) {
      if (lower.contains('email')) return 'This email address is already registered.';
      if (lower.contains('username') || lower.contains('handle')) return 'This username is already taken. Please choose another.';
      return 'An account with this email or username already exists.';
    }

    if (lower.contains('invalid credentials') ||
        lower.contains('bad credentials') ||
        lower.contains('failed to login') ||
        lower.contains('password incorrect') ||
        lower.contains('unauthorized')) {
      return 'Incorrect email or password. Please try again.';
    }

    if (lower.contains('location permission denied') || lower.contains('permission_denied')) {
      return 'Location permission is required to track routes. Please enable location permissions.';
    }

    if (lower.contains('location services are disabled') || lower.contains('location_disabled')) {
      return 'GPS / Location services are turned off. Please turn on GPS in your device settings.';
    }

    if (lower.contains('club not found') || lower.contains('invalid invite code')) {
      return 'Invalid club invite code or club no longer exists.';
    }

    if (lower.contains('already in a club') || lower.contains('already member')) {
      return 'You are already a member of a club. Leave your current club first.';
    }

    if (lower.contains('not enough xp') || lower.contains('insufficient xp')) {
      return 'You need at least 500 XP to create a new club.';
    }

    if (lower.contains('not enough coins') || lower.contains('insufficient coins')) {
      return 'You do not have enough coins for this reward.';
    }

    if (lower.contains('friend request already sent') || lower.contains('already friends')) {
      return 'Friend request already sent or you are already friends.';
    }

    if (errStr.isEmpty) {
      return defaultMessage;
    }

    return _cleanMessage(errStr);
  }

  static String _cleanMessage(String msg) {
    var cleaned = msg.trim();
    if (cleaned.startsWith('Exception: ')) {
      cleaned = cleaned.substring('Exception: '.length).trim();
    }
    if (cleaned.isEmpty) return 'An unexpected error occurred.';
    return cleaned.length > 1 ? '${cleaned[0].toUpperCase()}${cleaned.substring(1)}' : cleaned;
  }
}
