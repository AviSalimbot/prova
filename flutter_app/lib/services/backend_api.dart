import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Points at the Python FastAPI backend (see /backend). Override at build
/// time with:
///   flutter run --dart-define=BACKEND_BASE_URL=https://your-backend-url
const _backendBaseUrl = String.fromEnvironment(
  'BACKEND_BASE_URL',
  defaultValue: 'http://localhost:8000',
);

final backendApiProvider = Provider<BackendApi>((ref) => BackendApi());

/// Thin wrapper around the endpoints exposed by backend/app/api.
/// Mirrors the Pipe-and-Filter application track (Figure 3): submit a
/// scanned page, then poll/stream the per-item result.
class BackendApi {
  final Dio _dio = Dio(BaseOptions(baseUrl: _backendBaseUrl));

  /// POST /runs — configure + start a pipeline run pinned to the given
  /// OCR/BERT model versions (Figure H-6 sequence: resolvePinnedVersionPair).
  Future<Map<String, dynamic>> startRun({
    required String ocrVersionId,
    required String bertVersionId,
    required double confidenceThreshold,
    required List<String> pageImagePaths,
  }) async {
    final response = await _dio.post('/runs', data: {
      'ocr_version_id': ocrVersionId,
      'bert_version_id': bertVersionId,
      'confidence_threshold': confidenceThreshold,
      'page_image_paths': pageImagePaths,
    });
    return response.data as Map<String, dynamic>;
  }

  /// GET /runs/{runId}/status
  Future<Map<String, dynamic>> getRunStatus(String runId) async {
    final response = await _dio.get('/runs/$runId/status');
    return response.data as Map<String, dynamic>;
  }

  /// POST /evaluation/{runId} — Compare against gold-standard (Figure 4/10).
  Future<Map<String, dynamic>> evaluateRun(String runId) async {
    final response = await _dio.post('/evaluation/$runId');
    return response.data as Map<String, dynamic>;
  }

  /// POST /retraining-cycles — Figure 11 retraining trigger.
  Future<Map<String, dynamic>> triggerRetraining({
    required String triggerCondition,
    required String authorizedBy,
  }) async {
    final response = await _dio.post('/retraining-cycles', data: {
      'trigger_condition': triggerCondition,
      'authorized_by': authorizedBy,
    });
    return response.data as Map<String, dynamic>;
  }
}
