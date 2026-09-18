import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'drive_auth_service.dart';

/// TODO: replace with your deployed backend's base URL (the same host
/// that serves /evaluation, /runs, etc.).
const _backendBaseUrl = 'http://localhost:8000';

class CleanJobService {
  CleanJobService(this._auth, this._driveAuth);

  final FirebaseAuth _auth;
  final DriveAuthService _driveAuth;

  /// Kicks off the backend's /clean/exam job. Firestore's cleanStatus
  /// field (watched via examsStreamProvider) reflects progress
  /// reactively — this call just triggers the job and returns once the
  /// HTTP request completes, not once cleaning finishes.
  Future<void> triggerClean(String examId, String examName) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Not signed in');
    }
    final idToken = await user.getIdToken();

    // Uploads run under the signed-in user's own Drive quota (service
    // accounts have none) — see clean.py's docstring. Requires the
    // person to have signed in via Google (not email/password only),
    // since that's the only path that grants a Drive authorization.
    final driveAccessToken = await _driveAuth.getAccessToken();

    final response = await http.post(
      Uri.parse('$_backendBaseUrl/clean/exam'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
        'X-Drive-Access-Token': driveAccessToken,
      },
      body: jsonEncode({'exam_id': examId, 'exam_name': examName}),
    );

    if (response.statusCode >= 300) {
      throw Exception('Clean job failed: ${response.body}');
    }
  }
}

final cleanJobServiceProvider = Provider<CleanJobService>(
  (ref) => CleanJobService(
    FirebaseAuth.instance,
    ref.watch(driveAuthServiceProvider),
  ),
);