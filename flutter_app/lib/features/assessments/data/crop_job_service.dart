// import 'dart:convert';

// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:http/http.dart' as http;

// import 'drive_auth_service.dart';

// /// TODO: replace with your deployed backend's base URL (the same host
// /// that serves /evaluation, /runs, /clean/exam, etc.).
// const _backendBaseUrl = 'http://localhost:8000';

// class CropJobService {
//   CropJobService(this._auth, this._driveAuth);

//   final FirebaseAuth _auth;
//   final DriveAuthService _driveAuth;

//   /// Kicks off the backend's /crop/exam job. Firestore's cropStatus
//   /// field (watched via examsStreamProvider) reflects progress
//   /// reactively — this call just triggers the job and returns once the
//   /// HTTP request completes, not once cropping finishes.
//   ///
//   /// Cropping reads from the exam's already-Cleaned Drive folder (see
//   /// crop_answers.py's input assumption — it expects cleaned, not raw,
//   /// scans), so the backend should reject this if cleanStatus isn't
//   /// 'ready' yet; the UI already gates the button on croppedReady/
//   /// cleanedReady but this is not a substitute for that server-side check.
//   Future<void> triggerCrop(String examId, String examName) async {
//     final user = _auth.currentUser;
//     if (user == null) {
//       throw StateError('Not signed in');
//     }
//     final idToken = await user.getIdToken();

//     // Uploads run under the signed-in user's own Drive quota (service
//     // accounts have none) — see clean.py's docstring, which applies
//     // identically here. Requires the person to have signed in via
//     // Google (not email/password only), since that's the only path
//     // that grants a Drive authorization.
//     final driveAccessToken = await _driveAuth.getAccessToken();

//     final response = await http.post(
//       Uri.parse('$_backendBaseUrl/crop/exam'),
//       headers: {
//         'Content-Type': 'application/json',
//         'Authorization': 'Bearer $idToken',
//         'X-Drive-Access-Token': driveAccessToken,
//       },
//       body: jsonEncode({'exam_id': examId, 'exam_name': examName}),
//     );

//     if (response.statusCode >= 300) {
//       throw Exception('Crop job failed: ${response.body}');
//     }
//   }
// }

// final cropJobServiceProvider = Provider<CropJobService>(
//   (ref) => CropJobService(
//     FirebaseAuth.instance,
//     ref.watch(driveAuthServiceProvider),
//   ),
// );





import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../domain/assessment.dart' show CropTemplate;
import 'drive_auth_service.dart';

/// TODO: replace with your deployed backend's base URL (the same host
/// that serves /evaluation, /runs, /clean/exam, etc.).
const _backendBaseUrl = 'http://localhost:8000';

class CropJobService {
  CropJobService(this._auth, this._driveAuth);

  final FirebaseAuth _auth;
  final DriveAuthService _driveAuth;

  /// Kicks off the backend's /crop/exam job for the given [template].
  /// Firestore's cropStatus field (watched via examsStreamProvider)
  /// reflects progress reactively — this call just triggers the job and
  /// returns once the HTTP request completes, not once cropping
  /// finishes.
  ///
  /// Cropping reads from the exam's already-Cleaned Drive folder (see
  /// crop_answers.py's input assumption — it expects cleaned, not raw,
  /// scans), so the backend should reject this if cleanStatus isn't
  /// 'ready' yet; the UI already gates the button on croppedReady/
  /// cleanedReady but this is not a substitute for that server-side check.
  ///
  /// Only [CropTemplate.activityV1] has a working backend cropper right
  /// now (crop_answers.py implements that layout) — the UI is expected
  /// to block selecting the other templates via [CropTemplate.isImplemented],
  /// but the backend should still validate `template` itself rather
  /// than trust the client.
  Future<void> triggerCrop(
    String examId,
    String examName,
    CropTemplate template,
  ) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Not signed in');
    }
    final idToken = await user.getIdToken();

    // Uploads run under the signed-in user's own Drive quota (service
    // accounts have none) — see clean.py's docstring, which applies
    // identically here. Requires the person to have signed in via
    // Google (not email/password only), since that's the only path
    // that grants a Drive authorization.
    final driveAccessToken = await _driveAuth.getAccessToken();

    final response = await http.post(
      Uri.parse('$_backendBaseUrl/crop/exam'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
        'X-Drive-Access-Token': driveAccessToken,
      },
      body: jsonEncode({
        'exam_id': examId,
        'exam_name': examName,
        'template': template.raw,
      }),
    );

    if (response.statusCode >= 300) {
      throw Exception('Crop job failed: ${response.body}');
    }
  }
}

final cropJobServiceProvider = Provider<CropJobService>(
  (ref) => CropJobService(
    FirebaseAuth.instance,
    ref.watch(driveAuthServiceProvider),
  ),
);