/// Plain data classes mirroring Figure H-5 (Entity-Relationship Diagram).
/// Kept dependency-free (no codegen) so the project compiles immediately;
/// swap for freezed/json_serializable later if you want immutability +
/// generated (de)serialization.
library entities;

class AppUser {
  final String userId;
  final String email;
  final String role; // 'operator' | 'annotator' | 'adjudicator'
  final String status;

  const AppUser({
    required this.userId,
    required this.email,
    required this.role,
    required this.status,
  });

  factory AppUser.fromMap(String id, Map<String, dynamic> m) => AppUser(
        userId: id,
        email: m['email'] ?? '',
        role: m['role'] ?? '',
        status: m['status'] ?? '',
      );

  Map<String, dynamic> toMap() => {
        'email': email,
        'role': role,
        'status': status,
      };
}

class Exam {
  final String examId;
  final String examName;
  final DateTime? administeredDate;
  final String templatePath;

  const Exam({
    required this.examId,
    required this.examName,
    this.administeredDate,
    required this.templatePath,
  });

  factory Exam.fromMap(String id, Map<String, dynamic> m) => Exam(
        examId: id,
        examName: m['exam_name'] ?? '',
        administeredDate: m['administered_date']?.toDate(),
        templatePath: m['template_path'] ?? '',
      );

  Map<String, dynamic> toMap() => {
        'exam_name': examName,
        'administered_date': administeredDate,
        'template_path': templatePath,
      };
}

class PageRecord {
  final String pageId;
  final String examId;
  final String studentCode;
  final int pageNumber;
  final String sourceScanPath;
  final String scanStatus;

  const PageRecord({
    required this.pageId,
    required this.examId,
    required this.studentCode,
    required this.pageNumber,
    required this.sourceScanPath,
    required this.scanStatus,
  });

  factory PageRecord.fromMap(String id, Map<String, dynamic> m) => PageRecord(
        pageId: id,
        examId: m['exam_id'] ?? '',
        studentCode: m['student_code'] ?? '',
        pageNumber: m['page_number'] ?? 0,
        sourceScanPath: m['source_scan_path'] ?? '',
        scanStatus: m['scan_status'] ?? '',
      );

  Map<String, dynamic> toMap() => {
        'exam_id': examId,
        'student_code': studentCode,
        'page_number': pageNumber,
        'source_scan_path': sourceScanPath,
        'scan_status': scanStatus,
      };
}

class ItemRecord {
  final String itemId;
  final String pageId;
  final int itemNumber;
  final String imagePath;
  final List<String> preprocessingSteps;
  final String cropStatus;

  const ItemRecord({
    required this.itemId,
    required this.pageId,
    required this.itemNumber,
    required this.imagePath,
    required this.preprocessingSteps,
    required this.cropStatus,
  });

  factory ItemRecord.fromMap(String id, Map<String, dynamic> m) => ItemRecord(
        itemId: id,
        pageId: m['page_id'] ?? '',
        itemNumber: m['item_number'] ?? 0,
        imagePath: m['image_path'] ?? '',
        preprocessingSteps: List<String>.from(m['preprocessing_steps'] ?? []),
        cropStatus: m['crop_status'] ?? '',
      );

  Map<String, dynamic> toMap() => {
        'page_id': pageId,
        'item_number': itemNumber,
        'image_path': imagePath,
        'preprocessing_steps': preprocessingSteps,
        'crop_status': cropStatus,
      };
}

/// A pipeline execution — pins one OCR version and one BERT version for its
/// full duration (Figure 3 / Figure H-6).
class RunRecord {
  final String runId;
  final String initiatedBy;
  final String inputBatch;
  final double confidenceThreshold;
  final String dataSeparation;
  final String status;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final Map<String, dynamic> configSnapshot;
  final String ocrVersionId;
  final String bertVersionId;

  const RunRecord({
    required this.runId,
    required this.initiatedBy,
    required this.inputBatch,
    required this.confidenceThreshold,
    required this.dataSeparation,
    required this.status,
    this.startedAt,
    this.completedAt,
    required this.configSnapshot,
    required this.ocrVersionId,
    required this.bertVersionId,
  });

  factory RunRecord.fromMap(String id, Map<String, dynamic> m) => RunRecord(
        runId: id,
        initiatedBy: m['initiated_by'] ?? '',
        inputBatch: m['input_batch'] ?? '',
        confidenceThreshold: (m['confidence_threshold'] ?? 0.65).toDouble(),
        dataSeparation: m['data_separation'] ?? '',
        status: m['status'] ?? '',
        startedAt: m['started_at']?.toDate(),
        completedAt: m['completed_at']?.toDate(),
        configSnapshot: Map<String, dynamic>.from(m['config_snapshot'] ?? {}),
        ocrVersionId: m['ocr_version_id'] ?? '',
        bertVersionId: m['bert_version_id'] ?? '',
      );

  Map<String, dynamic> toMap() => {
        'initiated_by': initiatedBy,
        'input_batch': inputBatch,
        'confidence_threshold': confidenceThreshold,
        'data_separation': dataSeparation,
        'status': status,
        'started_at': startedAt,
        'completed_at': completedAt,
        'config_snapshot': configSnapshot,
        'ocr_version_id': ocrVersionId,
        'bert_version_id': bertVersionId,
      };
}

/// Per-item result: predicted label + confidence + class probabilities,
/// stamped with the pinned version pair (Figure 3 sink).
class ResultRecord {
  final String resultId;
  final String runId;
  final String itemId;
  final String latexTranscription;
  final double ocrConfidence;
  final String predictedLabel;
  final Map<String, double> classProbabilities;
  final bool flagged;
  final String flagReason;

  const ResultRecord({
    required this.resultId,
    required this.runId,
    required this.itemId,
    required this.latexTranscription,
    required this.ocrConfidence,
    required this.predictedLabel,
    required this.classProbabilities,
    required this.flagged,
    required this.flagReason,
  });

  factory ResultRecord.fromMap(String id, Map<String, dynamic> m) =>
      ResultRecord(
        resultId: id,
        runId: m['run_id'] ?? '',
        itemId: m['item_id'] ?? '',
        latexTranscription: m['latex_transcription'] ?? '',
        ocrConfidence: (m['ocr_confidence'] ?? 0.0).toDouble(),
        predictedLabel: m['predicted_label'] ?? '',
        classProbabilities:
            Map<String, double>.from(m['class_probabilities'] ?? {}),
        flagged: m['flagged'] ?? false,
        flagReason: m['flag_reason'] ?? '',
      );

  Map<String, dynamic> toMap() => {
        'run_id': runId,
        'item_id': itemId,
        'latex_transcription': latexTranscription,
        'ocr_confidence': ocrConfidence,
        'predicted_label': predictedLabel,
        'class_probabilities': classProbabilities,
        'flagged': flagged,
        'flag_reason': flagReason,
      };
}

/// Independent, blind annotator label (Annotator x2 in Figure H-1).
class AnnotatorLabelRecord {
  final String labelId;
  final String itemId;
  final String annotatorId;
  final String label;
  final String note;
  final DateTime? labeledAt;
  final DateTime? revisedAt;

  const AnnotatorLabelRecord({
    required this.labelId,
    required this.itemId,
    required this.annotatorId,
    required this.label,
    required this.note,
    this.labeledAt,
    this.revisedAt,
  });

  factory AnnotatorLabelRecord.fromMap(String id, Map<String, dynamic> m) =>
      AnnotatorLabelRecord(
        labelId: id,
        itemId: m['item_id'] ?? '',
        annotatorId: m['annotator_id'] ?? '',
        label: m['label'] ?? '',
        note: m['note'] ?? '',
        labeledAt: m['labeled_at']?.toDate(),
        revisedAt: m['revised_at']?.toDate(),
      );

  Map<String, dynamic> toMap() => {
        'item_id': itemId,
        'annotator_id': annotatorId,
        'label': label,
        'note': note,
        'labeled_at': labeledAt,
        'revised_at': revisedAt,
      };
}

/// The adjudicated gold-standard label — one per item (1:1 with ItemRecord).
class GoldStandardLabelRecord {
  final String itemId; // PK == FK to item
  final String adjudicatedBy;
  final String finalLabel;
  final String resolutionSource; // e.g. 'agreement' | 'adjudication'
  final String rationale;
  final DateTime? resolvedAt;

  const GoldStandardLabelRecord({
    required this.itemId,
    required this.adjudicatedBy,
    required this.finalLabel,
    required this.resolutionSource,
    required this.rationale,
    this.resolvedAt,
  });

  factory GoldStandardLabelRecord.fromMap(
          String itemId, Map<String, dynamic> m) =>
      GoldStandardLabelRecord(
        itemId: itemId,
        adjudicatedBy: m['adjudicated_by'] ?? '',
        finalLabel: m['final_label'] ?? '',
        resolutionSource: m['resolution_source'] ?? '',
        rationale: m['rationale'] ?? '',
        resolvedAt: m['resolved_at']?.toDate(),
      );

  Map<String, dynamic> toMap() => {
        'adjudicated_by': adjudicatedBy,
        'final_label': finalLabel,
        'resolution_source': resolutionSource,
        'rationale': rationale,
        'resolved_at': resolvedAt,
      };
}

/// A registered, versioned model artifact (TrOCR or BERT).
class ModelVersionRecord {
  final String versionId;
  final String layer; // 'recognition' | 'classification'
  final String baseCheckpoint;
  final String adaptationMethod; // e.g. 'LoRA', 'domain-adaptive-MLM'
  final String trainingManifestId;
  final Map<String, dynamic> hyperparameters;
  final Map<String, dynamic> promotionMetrics;
  final String status; // 'candidate' | 'promoted' | 'rejected'
  final DateTime? registeredAt;
  final DateTime? promotedAt;

  const ModelVersionRecord({
    required this.versionId,
    required this.layer,
    required this.baseCheckpoint,
    required this.adaptationMethod,
    required this.trainingManifestId,
    required this.hyperparameters,
    required this.promotionMetrics,
    required this.status,
    this.registeredAt,
    this.promotedAt,
  });

  factory ModelVersionRecord.fromMap(String id, Map<String, dynamic> m) =>
      ModelVersionRecord(
        versionId: id,
        layer: m['layer'] ?? '',
        baseCheckpoint: m['base_checkpoint'] ?? '',
        adaptationMethod: m['adaptation_method'] ?? '',
        trainingManifestId: m['training_manifest_id'] ?? '',
        hyperparameters: Map<String, dynamic>.from(m['hyperparameters_json'] ?? {}),
        promotionMetrics: Map<String, dynamic>.from(m['promotion_metrics_json'] ?? {}),
        status: m['status'] ?? '',
        registeredAt: m['registered_at']?.toDate(),
        promotedAt: m['promoted_at']?.toDate(),
      );

  Map<String, dynamic> toMap() => {
        'layer': layer,
        'base_checkpoint': baseCheckpoint,
        'adaptation_method': adaptationMethod,
        'training_manifest_id': trainingManifestId,
        'hyperparameters_json': hyperparameters,
        'promotion_metrics_json': promotionMetrics,
        'status': status,
        'registered_at': registeredAt,
        'promoted_at': promotedAt,
      };
}

/// A generated evaluation report (Wilson CI, category frequency, PDF export).
class ReportRecord {
  final String reportId;
  final String runId;
  final String generatedBy;
  final double accuracy;
  final String confidenceInterval;
  final double macroF1;
  final double weightedF1;
  final double cohensKappa;
  final DateTime? generatedAt;
  final String filePath;

  const ReportRecord({
    required this.reportId,
    required this.runId,
    required this.generatedBy,
    required this.accuracy,
    required this.confidenceInterval,
    required this.macroF1,
    required this.weightedF1,
    required this.cohensKappa,
    this.generatedAt,
    required this.filePath,
  });

  factory ReportRecord.fromMap(String id, Map<String, dynamic> m) =>
      ReportRecord(
        reportId: id,
        runId: m['run_id'] ?? '',
        generatedBy: m['generated_by'] ?? '',
        accuracy: (m['accuracy'] ?? 0.0).toDouble(),
        confidenceInterval: m['confidence_interval'] ?? '',
        macroF1: (m['macro_f1'] ?? 0.0).toDouble(),
        weightedF1: (m['weighted_f1'] ?? 0.0).toDouble(),
        cohensKappa: (m['cohens_kappa'] ?? 0.0).toDouble(),
        generatedAt: m['generated_at']?.toDate(),
        filePath: m['file_path'] ?? '',
      );

  Map<String, dynamic> toMap() => {
        'run_id': runId,
        'generated_by': generatedBy,
        'accuracy': accuracy,
        'confidence_interval': confidenceInterval,
        'macro_f1': macroF1,
        'weighted_f1': weightedF1,
        'cohens_kappa': cohensKappa,
        'generated_at': generatedAt,
        'file_path': filePath,
      };
}

/// Retraining Trigger -> ... -> Promote/Reject Candidate (Figure 11).
class RetrainingCycleRecord {
  final String cycleId;
  final String triggerCondition; // 'label_accumulation' | 'accuracy_drift'
  final String authorizedBy;
  final String trainingManifestId;
  final String candidateVersionId;
  final String outcome; // 'promoted' | 'rejected' | 'pending'
  final DateTime? createdAt;

  const RetrainingCycleRecord({
    required this.cycleId,
    required this.triggerCondition,
    required this.authorizedBy,
    required this.trainingManifestId,
    required this.candidateVersionId,
    required this.outcome,
    this.createdAt,
  });

  factory RetrainingCycleRecord.fromMap(String id, Map<String, dynamic> m) =>
      RetrainingCycleRecord(
        cycleId: id,
        triggerCondition: m['trigger_condition'] ?? '',
        authorizedBy: m['authorized_by'] ?? '',
        trainingManifestId: m['training_manifest_id'] ?? '',
        candidateVersionId: m['candidate_version_id'] ?? '',
        outcome: m['outcome'] ?? '',
        createdAt: m['created_at']?.toDate(),
      );

  Map<String, dynamic> toMap() => {
        'trigger_condition': triggerCondition,
        'authorized_by': authorizedBy,
        'training_manifest_id': trainingManifestId,
        'candidate_version_id': candidateVersionId,
        'outcome': outcome,
        'created_at': createdAt,
      };
}
