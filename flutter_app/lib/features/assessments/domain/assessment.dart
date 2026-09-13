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

/// `exams/{examId}` — one document per assessment (exam or activity).
class Assessment {
  const Assessment({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
    required this.participantCount,
    required this.pageCount,
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