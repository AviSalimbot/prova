/// Collection names mirror the entities in Figure H-5 (ERD) 1:1 so the
/// Flutter app, the Python backend, and firestore.rules all agree on schema.
class FirestorePaths {
  FirestorePaths._();

  static const users = 'users';
  static const exams = 'exams';
  static const pages = 'pages';
  static const items = 'items';
  static const runs = 'runs';
  static const results = 'results';
  static const logs = 'logs';
  static const annotatorLabels = 'annotator_labels';
  static const goldStandardLabels = 'gold_standard_labels';
  static const reports = 'reports';
  static const modelVersions = 'model_versions';
  static const retrainingCycles = 'retraining_cycles';
  static const participants = 'participants';
  static const croppedItems = 'croppedItems';
}