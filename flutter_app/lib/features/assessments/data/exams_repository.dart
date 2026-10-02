// lib/features/assessments/data/exams_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/firestore_paths.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/assessment.dart';

/// Firestore access for the exam/participant/page hierarchy defined in
/// the ERD (Figure H-5). This is the single source of truth the app
/// reads from during normal browsing — Drive is only touched at import
/// time (DriveImportService) and when downloading a specific page's
/// image bytes for preview.
///
/// Sorting is done client-side rather than via Firestore `orderBy`,
/// matching the pattern already used in AdminUsersRepository — an
/// equality `where` combined with `orderBy` on a different field would
/// otherwise require a composite index to be created per-query.
class ExamsRepository {
  ExamsRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _exams =>
      _firestore.collection(FirestorePaths.exams);

  CollectionReference<Map<String, dynamic>> get _participants =>
      _firestore.collection(FirestorePaths.participants);

  CollectionReference<Map<String, dynamic>> get _pages =>
      _firestore.collection(FirestorePaths.pages);

  Stream<List<Assessment>> watchExams() {
    return _exams.snapshots().map(
          (snapshot) => snapshot.docs
              .map((d) => Assessment.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  Stream<List<Participant>> watchParticipants(String examId) {
    return _participants
        .where('examId', isEqualTo: examId)
        .snapshots()
        .map((snapshot) {
      final participants = snapshot.docs
          .map((d) => Participant.fromMap(d.id, d.data()))
          .toList();
      participants.sort((a, b) => a.code.compareTo(b.code));
      return participants;
    });
  }

  Stream<List<AssessmentPage>> watchPages(String participantId) {
    return _pages
        .where('participantId', isEqualTo: participantId)
        .snapshots()
        .map((snapshot) {
      final pages = snapshot.docs
          .map((d) => AssessmentPage.fromMap(d.id, d.data()))
          .toList();
      pages.sort((a, b) => a.pageNumber.compareTo(b.pageNumber));
      return pages;
    });
  }

  Future<void> createExam({
    required String name,
    required AssessmentType type,
  }) {
    return _exams.add({
      'name': name,
      'type': type.name,
      'status': AssessmentStatus.incomplete.name,
      'participantCount': 0,
      'pageCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

final examsRepositoryProvider = Provider<ExamsRepository>(
  (ref) => ExamsRepository(ref.watch(firestoreProvider)),
);

/// autoDispose + watching authStateProvider is the actual fix here, not
/// a stylistic choice: a plain StreamProvider caches whatever
/// AsyncValue it last produced and never recreates its underlying
/// Firestore listener on its own. If that listener ever errors —
/// e.g. permission-denied because whoever was signed in at the moment
/// it was first created wasn't approved yet — Riverpod just keeps
/// replaying that SAME error forever, through any number of later
/// sign-outs and sign-ins, until something forces the provider itself
/// to be torn down and rebuilt (previously, only a full page reload
/// did that). Watching authStateProvider means every sign-in/sign-out
/// — including re-authenticating as the same person — creates a
/// brand-new listener with a clean slate instead of reusing a stale,
/// possibly-broken one. autoDispose additionally tears the listener
/// down once nothing is watching it, so it doesn't keep an old user's
/// Firestore subscription alive in the background after they sign out.
final examsStreamProvider = StreamProvider.autoDispose<List<Assessment>>(
  (ref) {
    ref.watch(authStateProvider);
    return ref.watch(examsRepositoryProvider).watchExams();
  },
);

final participantsStreamProvider =
    StreamProvider.autoDispose.family<List<Participant>, String>(
  (ref, examId) {
    ref.watch(authStateProvider);
    return ref.watch(examsRepositoryProvider).watchParticipants(examId);
  },
);

final pagesStreamProvider =
    StreamProvider.autoDispose.family<List<AssessmentPage>, String>(
  (ref, participantId) {
    ref.watch(authStateProvider);
    return ref.watch(examsRepositoryProvider).watchPages(participantId);
  },
);



// // lib/features/assessments/data/exams_repository.dart
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';

// import '../../../services/firestore_paths.dart';
// import '../../auth/data/auth_repository.dart';
// import '../domain/assessment.dart';

// /// Firestore access for the exam/participant/page hierarchy defined in
// /// the ERD (Figure H-5). This is the single source of truth the app
// /// reads from during normal browsing — Drive is only touched at import
// /// time (DriveImportService) and when downloading a specific page's
// /// image bytes for preview.
// ///
// /// Sorting is done client-side rather than via Firestore `orderBy`,
// /// matching the pattern already used in AdminUsersRepository — an
// /// equality `where` combined with `orderBy` on a different field would
// /// otherwise require a composite index to be created per-query.
// class ExamsRepository {
//   ExamsRepository(this._firestore);

//   final FirebaseFirestore _firestore;

//   CollectionReference<Map<String, dynamic>> get _exams =>
//       _firestore.collection(FirestorePaths.exams);

//   CollectionReference<Map<String, dynamic>> get _participants =>
//       _firestore.collection(FirestorePaths.participants);

//   CollectionReference<Map<String, dynamic>> get _pages =>
//       _firestore.collection(FirestorePaths.pages);

//   Stream<List<Assessment>> watchExams() {
//     return _exams.snapshots().map(
//           (snapshot) => snapshot.docs
//               .map((d) => Assessment.fromMap(d.id, d.data()))
//               .toList(),
//         );
//   }

//   Stream<List<Participant>> watchParticipants(String examId) {
//     return _participants
//         .where('examId', isEqualTo: examId)
//         .snapshots()
//         .map((snapshot) {
//       final participants = snapshot.docs
//           .map((d) => Participant.fromMap(d.id, d.data()))
//           .toList();
//       participants.sort((a, b) => a.code.compareTo(b.code));
//       return participants;
//     });
//   }

//   Stream<List<AssessmentPage>> watchPages(String participantId) {
//     return _pages
//         .where('participantId', isEqualTo: participantId)
//         .snapshots()
//         .map((snapshot) {
//       final pages = snapshot.docs
//           .map((d) => AssessmentPage.fromMap(d.id, d.data()))
//           .toList();
//       pages.sort((a, b) => a.pageNumber.compareTo(b.pageNumber));
//       return pages;
//     });
//   }

//   Stream<List<CroppedItem>> watchCroppedItems(String participantId) {
//     return _firestore
//         .collection(FirestorePaths.croppedItems)
//         .where('participantId', isEqualTo: participantId)
//         .snapshots()
//         .map((snapshot) {
//       final items = snapshot.docs
//           .map((d) => CroppedItem.fromMap(d.id, d.data()))
//           .toList();
//       items.sort((a, b) => a.item.compareTo(b.item));
//       return items;
//     });
//   }

//   Future<void> createExam({
//     required String name,
//     required AssessmentType type,
//   }) {
//     return _exams.add({
//       'name': name,
//       'type': type.name,
//       'status': AssessmentStatus.incomplete.name,
//       'participantCount': 0,
//       'pageCount': 0,
//       'createdAt': FieldValue.serverTimestamp(),
//       'updatedAt': FieldValue.serverTimestamp(),
//     });
//   }
// }

// final examsRepositoryProvider = Provider<ExamsRepository>(
//   (ref) => ExamsRepository(ref.watch(firestoreProvider)),
// );

// /// autoDispose + watching authStateProvider is the actual fix here, not
// /// a stylistic choice: a plain StreamProvider caches whatever
// /// AsyncValue it last produced and never recreates its underlying
// /// Firestore listener on its own. If that listener ever errors —
// /// e.g. permission-denied because whoever was signed in at the moment
// /// it was first created wasn't approved yet — Riverpod just keeps
// /// replaying that SAME error forever, through any number of later
// /// sign-outs and sign-ins, until something forces the provider itself
// /// to be torn down and rebuilt (previously, only a full page reload
// /// did that). Watching authStateProvider means every sign-in/sign-out
// /// — including re-authenticating as the same person — creates a
// /// brand-new listener with a clean slate instead of reusing a stale,
// /// possibly-broken one. autoDispose additionally tears the listener
// /// down once nothing is watching it, so it doesn't keep an old user's
// /// Firestore subscription alive in the background after they sign out.
// final examsStreamProvider = StreamProvider.autoDispose<List<Assessment>>(
//   (ref) {
//     ref.watch(authStateProvider);
//     return ref.watch(examsRepositoryProvider).watchExams();
//   },
// );

// final participantsStreamProvider =
//     StreamProvider.autoDispose.family<List<Participant>, String>(
//   (ref, examId) {
//     ref.watch(authStateProvider);
//     return ref.watch(examsRepositoryProvider).watchParticipants(examId);
//   },
// );

// final pagesStreamProvider =
//     StreamProvider.autoDispose.family<List<AssessmentPage>, String>(
//   (ref, participantId) {
//     ref.watch(authStateProvider);
//     return ref.watch(examsRepositoryProvider).watchPages(participantId);
//   },
// );

// final croppedItemsStreamProvider =
//     StreamProvider.autoDispose.family<List<CroppedItem>, String>(
//   (ref, participantId) {
//     ref.watch(authStateProvider);
//     return ref.watch(examsRepositoryProvider).watchCroppedItems(participantId);
//   },
// );
