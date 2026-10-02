import 'package:cloud_firestore/cloud_firestore.dart';

/// Domain layer for the Assessments feature, aligned with the ERD
/// (Figure H-5): `exams`, `participants`, and `pages` are real Firestore
/// collections — not derived live from Drive on every screen visit.
/// Drive is only walked once per exam, at import time (see
/// DriveImportService), which writes the participant/page documents
/// this domain layer models.

enum AssessmentType {
  exam,
  activity;

  static AssessmentType fromRaw(String raw) {
    return AssessmentType.values.firstWhere(
      (t) => t.name == raw.toLowerCase(),
      orElse: () => AssessmentType.activity,
    );
  }

  String get label => this == AssessmentType.exam ? 'Exam' : 'Activity';
}

enum AssessmentStatus {
  complete,
  incomplete;

  static AssessmentStatus fromRaw(String raw) {
    return AssessmentStatus.values.firstWhere(
      (s) => s.name == raw.toLowerCase(),
      orElse: () => AssessmentStatus.incomplete,
    );
  }

  String get label =>
      this == AssessmentStatus.complete ? 'Complete' : 'Incomplete';
}

/// The three parallel Drive trees every exam's scans live under. Raw is
/// the unedited phone scan; Cleaned is de-skewed/color-corrected;
/// Cropped is the final per-question-ready crop. Only used at import
/// time and when resolving which Drive file ID to download for preview
/// — everyday Firestore reads don't care about this.
enum ScanVariant {
  raw,
  cleaned,
  cropped;

  String get label {
    switch (this) {
      case ScanVariant.raw:
        return 'Raw';
      case ScanVariant.cleaned:
        return 'Cleaned';
      case ScanVariant.cropped:
        return 'Cropped';
    }
  }
}

/// Which page-layout cropper to run. Each template corresponds to a
/// distinct box-layout script on the backend (see crop_answers.py's
/// docstring for the "template-2" Activity layout it currently
/// implements). Only one of these has a working backend implementation
/// today — see [isImplemented].
enum CropTemplate {
  activityV1,
  activityV2,
  exam;

  /// Value sent to the backend's /crop/exam endpoint.
  String get raw {
    switch (this) {
      case CropTemplate.activityV1:
        return 'activity_v1';
      case CropTemplate.activityV2:
        return 'activity_v2';
      case CropTemplate.exam:
        return 'exam';
    }
  }

  String get label {
    switch (this) {
      case CropTemplate.activityV1:
        return 'Activity V1';
      case CropTemplate.activityV2:
        return 'Activity V2';
      case CropTemplate.exam:
        return 'Exam';
    }
  }

  /// Only Activity V1 has a working cropper on the backend right now
  /// (crop_answers.py implements this layout). V2 and Exam are listed
  /// so the option is visible/plannable in the UI, but selecting them
  /// is blocked until their backend croppers exist.
  bool get isImplemented => this == CropTemplate.activityV1;

  static CropTemplate fromRaw(String? raw) {
    return CropTemplate.values.firstWhere(
      (t) => t.raw == raw,
      orElse: () => CropTemplate.activityV1,
    );
  }
}

/// Parses a Firestore timestamp field defensively: the backend may write
/// a real `Timestamp`, an ISO-8601 string, or omit the field entirely
/// before a job has started.
DateTime? _parseTimestamp(dynamic raw) {
  if (raw == null) return null;
  if (raw is Timestamp) return raw.toDate();
  if (raw is DateTime) return raw;
  if (raw is String) return DateTime.tryParse(raw);
  return null;
}

/// `exams/{examId}` — one document per assessment (exam or activity).
class Assessment {
  const Assessment({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
    required this.participantCount,
    required this.pageCount,
    this.importStatus = 'not_started',
    this.importedPageCount = 0,
    this.importTotalPages = 0,
    this.importScanned = 0,
    this.importError,
    this.cleanStatus = 'not_started',
    this.cleanedPageCount = 0,
    this.cleanError,
    this.cleanStartedAt,
    this.cropStatus = 'not_started',
    this.croppedPageCount = 0,
    this.cropError,
    this.cropStartedAt,
    this.cropTemplate,
  });

  final String id;
  final String name;
  final AssessmentType type;
  final AssessmentStatus status;

  /// Denormalized counts, written by DriveImportService after import so
  /// the grid can show "N participants · N pages" without a query per
  /// card.
  final int participantCount;
  final int pageCount;

  /// One of: 'not_started', 'processing', 'ready', 'failed'. Written by
  /// DriveImportService.importExam as it runs — 'processing' from the
  /// very first moment the import starts (including the Drive folder
  /// scan, while [importTotalPages] is still 0), 'ready' once every
  /// participant has been written, 'failed' (with [importError] set) if
  /// the import throws partway through.
  /// Watched here — rather than kept as local widget state in
  /// AssessmentsGrid — so the live "N/total pages" indicator reflects
  /// the actual Firestore writes as they land, and keeps working even
  /// if the person closes the import dialog or navigates away mid-run.
  final String importStatus;

  /// Pages written so far, incremented once per participant (not once
  /// per individual page — that would mean one Firestore write per
  /// page, which is unnecessary network chatter for a progress number
  /// nobody needs single-page precision on).
  final int importedPageCount;

  /// Known only once the three Drive variant trees have been fully
  /// walked — before that, DriveImportService doesn't yet know how
  /// many pages it'll write, so 0 here specifically means "still
  /// scanning Drive," not "zero pages found."
  final int importTotalPages;

  /// Number of participant folders walked so far during the Drive scan
  /// phase. Lets the popup show activity ("Scanning Drive… 12 folders")
  /// while [importTotalPages] is still 0, so the scan doesn't look
  /// frozen.
  final int importScanned;
  final String? importError;

  bool get importing => importStatus == 'processing';

  /// Fraction of [importTotalPages] written so far, in [0, 1]. 0 when
  /// [importTotalPages] is 0 (either nothing is importing, or the
  /// Drive scan phase hasn't finished yet) to avoid a NaN from dividing
  /// by zero.
  double get importProgress => importTotalPages == 0
      ? 0.0
      : (importedPageCount / importTotalPages).clamp(0.0, 1.0);

  /// One of: 'not_started', 'processing', 'ready', 'failed'. Written by
  /// the backend's /clean/exam endpoint, watched here to drive the
  /// Cleaned folder's unlock state in ActivityInfoScreen.
  final String cleanStatus;

  /// Pages successfully cleaned so far. The backend is expected to
  /// increment this in Firestore as each page finishes (not just write
  /// it once at the end) so [cleanProgress]/[estimatedCleanRemaining]
  /// stay meaningful mid-job. NOTE: as of now this incremental write
  /// does not exist yet on the backend — see /clean/exam.
  final int cleanedPageCount;
  final String? cleanError;

  /// Set once by the backend the moment the /clean/exam job starts.
  /// Used, together with [cleanedPageCount], to estimate time remaining
  /// — never written to again for the same job run.
  final DateTime? cleanStartedAt;

  bool get cleanedReady => cleanStatus == 'ready';
  bool get cleaning => cleanStatus == 'processing';

  /// Fraction of [pageCount] cleaned so far, in [0, 1]. 0 when
  /// [pageCount] is 0 to avoid a NaN from dividing by zero.
  double get cleanProgress =>
      pageCount == 0 ? 0.0 : (cleanedPageCount / pageCount).clamp(0.0, 1.0);

  /// Estimated time left on the clean job, extrapolated linearly from
  /// pages-done-so-far vs. elapsed time. Returns null when there isn't
  /// enough information yet (job hasn't started, or no pages have
  /// completed so a rate can't be computed).
  Duration? estimatedCleanRemaining({DateTime? now}) => _estimateRemaining(
        startedAt: cleanStartedAt,
        done: cleanedPageCount,
        total: pageCount,
        now: now,
      );

  /// Same shape as [cleanStatus], but for the backend's /crop/exam
  /// endpoint. Only meaningful once [cleanedReady] is true — cropping
  /// runs on already-cleaned pages (see crop_answers.py's input
  /// assumption).
  final String cropStatus;

  /// Pages successfully cropped so far. Same incremental-write
  /// expectation as [cleanedPageCount].
  final int croppedPageCount;
  final String? cropError;

  /// Set once by the backend the moment the /crop/exam job starts.
  final DateTime? cropStartedAt;

  /// Which [CropTemplate] the most recent (or in-progress) crop job
  /// used, as recorded by the backend. Null before cropping has ever
  /// been triggered.
  final String? cropTemplate;

  bool get croppedReady => cropStatus == 'ready';
  bool get cropping => cropStatus == 'processing';

  /// Fraction of [pageCount] cropped so far, in [0, 1]. Cropping only
  /// ever runs over pages that finished cleaning, but since a clean run
  /// is expected to reach 100% before crop starts, [pageCount] is the
  /// right denominator here too rather than [cleanedPageCount].
  double get cropProgress =>
      pageCount == 0 ? 0.0 : (croppedPageCount / pageCount).clamp(0.0, 1.0);

  /// Estimated time left on the crop job — same linear extrapolation as
  /// [estimatedCleanRemaining].
  Duration? estimatedCropRemaining({DateTime? now}) => _estimateRemaining(
        startedAt: cropStartedAt,
        done: croppedPageCount,
        total: pageCount,
        now: now,
      );

  static Duration? _estimateRemaining({
    required DateTime? startedAt,
    required int done,
    required int total,
    DateTime? now,
  }) {
    if (startedAt == null || done <= 0 || total <= 0 || done >= total) {
      // No start time yet, no progress yet to derive a rate from, or
      // already finished — nothing sensible to estimate.
      return null;
    }
    final elapsed = (now ?? DateTime.now()).difference(startedAt);
    if (elapsed <= Duration.zero) return null;

    final secondsPerPage = elapsed.inMilliseconds / done / 1000;
    final remainingPages = total - done;
    final remainingSeconds = (secondsPerPage * remainingPages).round();
    return Duration(seconds: remainingSeconds);
  }

  factory Assessment.fromMap(String id, Map<String, dynamic> map) {
    return Assessment(
      id: id,
      name: (map['name'] as String?) ?? 'Untitled',
      type: AssessmentType.fromRaw((map['type'] as String?) ?? 'activity'),
      status: AssessmentStatus.fromRaw(
        (map['status'] as String?) ?? 'incomplete',
      ),
      participantCount: (map['participantCount'] as num?)?.toInt() ?? 0,
      pageCount: (map['pageCount'] as num?)?.toInt() ?? 0,
      importStatus: (map['importStatus'] as String?) ?? 'not_started',
      importedPageCount: (map['importedPageCount'] as num?)?.toInt() ?? 0,
      importTotalPages: (map['importTotalPages'] as num?)?.toInt() ?? 0,
      importScanned: (map['importScanned'] as num?)?.toInt() ?? 0,
      importError: map['importError'] as String?,
      cleanStatus: (map['cleanStatus'] as String?) ?? 'not_started',
      cleanedPageCount: (map['cleanedPageCount'] as num?)?.toInt() ?? 0,
      cleanError: map['cleanError'] as String?,
      cleanStartedAt: _parseTimestamp(map['cleanStartedAt']),
      cropStatus: (map['cropStatus'] as String?) ?? 'not_started',
      croppedPageCount: (map['croppedPageCount'] as num?)?.toInt() ?? 0,
      cropError: map['cropError'] as String?,
      cropStartedAt: _parseTimestamp(map['cropStartedAt']),
      cropTemplate: map['cropTemplate'] as String?,
    );
  }
}

/// `participants/{participantId}` — one document per participant
/// folder, scoped to a single exam via [examId]. Document ID is
/// deterministic (`{examId}__{code}`), so re-running import overwrites
/// rather than duplicating.
class Participant {
  const Participant({
    required this.id,
    required this.examId,
    required this.code,
    required this.pageCount,
    required this.status,
  });

  final String id;
  final String examId;
  final String code;
  final int pageCount;
  final AssessmentStatus status;

  factory Participant.fromMap(String id, Map<String, dynamic> map) {
    return Participant(
      id: id,
      examId: (map['examId'] as String?) ?? '',
      code: (map['code'] as String?) ?? id,
      pageCount: (map['pageCount'] as num?)?.toInt() ?? 0,
      status: AssessmentStatus.fromRaw(
        (map['status'] as String?) ?? 'complete',
      ),
    );
  }
}

/// `pages/{pageId}` — one document per scanned page, scoped to a single
/// participant via [participantId]. Holds a Drive file ID per variant
/// rather than the image bytes themselves; the actual bytes are only
/// downloaded on demand when a page is previewed.
class AssessmentPage {
  const AssessmentPage({
    required this.id,
    required this.participantId,
    required this.pageNumber,
    required this.driveFileIds,
    required this.scanStatus,
  });

  final String id;
  final String participantId;
  final int pageNumber;
  final Map<ScanVariant, String> driveFileIds;
  final String scanStatus;

  String? fileIdFor(ScanVariant variant) => driveFileIds[variant];

  factory AssessmentPage.fromMap(String id, Map<String, dynamic> map) {
    final ids = <ScanVariant, String>{};

    final raw = map['rawFileId'] as String?;
    final cleaned = map['cleanedFileId'] as String?;
    final cropped = map['croppedFileId'] as String?;

    if (raw != null) ids[ScanVariant.raw] = raw;
    if (cleaned != null) ids[ScanVariant.cleaned] = cleaned;
    if (cropped != null) ids[ScanVariant.cropped] = cropped;

    return AssessmentPage(
      id: id,
      participantId: (map['participantId'] as String?) ?? '',
      pageNumber: (map['pageNumber'] as num?)?.toInt() ?? 0,
      driveFileIds: ids,
      scanStatus: (map['scanStatus'] as String?) ?? 'scanned_ok',
    );
  }
}