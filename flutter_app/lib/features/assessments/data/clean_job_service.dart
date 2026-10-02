// import 'dart:convert';

// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:http/http.dart' as http;

// import 'drive_auth_service.dart';

// /// TODO: replace with your deployed backend's base URL (the same host
// /// that serves /evaluation, /runs, etc.).
// const _backendBaseUrl = 'http://localhost:8000';

// class CleanJobService {
//   CleanJobService(this._auth, this._driveAuth);

//   final FirebaseAuth _auth;
//   final DriveAuthService _driveAuth;

//   /// Kicks off the backend's /clean/exam job. Firestore's cleanStatus
//   /// field (watched via examsStreamProvider) reflects progress
//   /// reactively — this call just triggers the job and returns once the
//   /// HTTP request completes, not once cleaning finishes.
//   Future<void> triggerClean(String examId, String examName) async {
//     final user = _auth.currentUser;
//     if (user == null) {
//       throw StateError('Not signed in');
//     }
//     final idToken = await user.getIdToken();

//     // Uploads run under the signed-in user's own Drive quota (service
//     // accounts have none) — see clean.py's docstring. Requires the
//     // person to have signed in via Google (not email/password only),
//     // since that's the only path that grants a Drive authorization.
//     final driveAccessToken = await _driveAuth.getAccessToken();

//     final response = await http.post(
//       Uri.parse('$_backendBaseUrl/clean/exam'),
//       headers: {
//         'Content-Type': 'application/json',
//         'Authorization': 'Bearer $idToken',
//         'X-Drive-Access-Token': driveAccessToken,
//       },
//       body: jsonEncode({'exam_id': examId, 'exam_name': examName}),
//     );

//     if (response.statusCode >= 300) {
//       throw Exception('Clean job failed: ${response.body}');
//     }
//   }
// }

// final cleanJobServiceProvider = Provider<CleanJobService>(
//   (ref) => CleanJobService(
//     FirebaseAuth.instance,
//     ref.watch(driveAuthServiceProvider),
//   ),
// );

import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'drive_auth_service.dart';

/// TODO: replace with your deployed backend's base URL (the same host
/// that serves /evaluation, /runs, etc.).
const _backendBaseUrl = 'http://localhost:8000';

/// Thrown when Google's Drive token could not be obtained or was rejected
/// even after fetching a fresh one. The UI should tell the person to sign
/// in with Google again (see [message]).
class DriveAuthExpiredException implements Exception {
  DriveAuthExpiredException([
    this.message =
        'Your Google Drive session expired. Please sign in with Google again and retry.',
  ]);
  final String message;
  @override
  String toString() => message;
}

class CleanJobService {
  CleanJobService(this._auth, this._driveAuth);

  final FirebaseAuth _auth;
  final DriveAuthService _driveAuth;

  /// How long the Drive token must stay valid for a clean job to be safe
  /// to start. Tokens live ~55 min, so anything older than ~25 min is
  /// replaced first. Raise this for very large exams.
  static const _needValidFor = Duration(minutes: 30);

  /// Kicks off the backend's /clean/exam job. Firestore's cleanStatus
  /// field (watched via examsStreamProvider) reflects progress
  /// reactively — this call just triggers the job and returns once the
  /// HTTP request completes, not once cleaning finishes.
  ///
  /// Throws [DriveAuthExpiredException] when Google sign-in must be
  /// repeated; show its message to the person.
  Future<void> triggerClean(String examId, String examName) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Not signed in');
    }

    // Fetch the Drive token FIRST, before other awaits: on web, Google's
    // popup is only allowed right after the user's click. The service
    // replaces the token automatically if it is too old; it never reuses
    // an expired one.
    var driveAccessToken = await _getDriveToken(forceRefresh: false);
    final idToken = await user.getIdToken();

    var response = await _post(idToken, driveAccessToken, examId, examName);

    if (_isDriveTokenInvalid(response)) {
      // Backend says Google rejected the token: get a brand-new one and
      // retry exactly once.
      driveAccessToken = await _getDriveToken(forceRefresh: true);
      response = await _post(idToken, driveAccessToken, examId, examName);
      if (_isDriveTokenInvalid(response)) {
        throw DriveAuthExpiredException();
      }
    }

    if (response.statusCode >= 300) {
      throw Exception('Clean job failed: ${response.body}');
    }
  }

  Future<String> _getDriveToken({required bool forceRefresh}) async {
    try {
      final token = await _driveAuth.getAccessToken(
        forceRefresh: forceRefresh,
        needValidFor: _needValidFor,
      );
      return token.trim();
    } catch (_) {
      // Not signed in to Google, popup blocked/closed, consent revoked...
      throw DriveAuthExpiredException();
    }
  }

  Future<http.Response> _post(
    String? idToken,
    String driveAccessToken,
    String examId,
    String examName,
  ) {
    return http.post(
      Uri.parse('$_backendBaseUrl/clean/exam'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
        'X-Drive-Access-Token': driveAccessToken,
      },
      body: jsonEncode({'exam_id': examId, 'exam_name': examName}),
    );
  }

  bool _isDriveTokenInvalid(http.Response r) {
    if (r.statusCode != 401) return false;
    try {
      final detail = (jsonDecode(r.body) as Map)['detail'];
      return detail is Map && detail['code'] == 'DRIVE_TOKEN_INVALID';
    } catch (_) {
      return false;
    }
  }
}

final cleanJobServiceProvider = Provider<CleanJobService>(
  (ref) => CleanJobService(
    FirebaseAuth.instance,
    ref.watch(driveAuthServiceProvider),
  ),
);