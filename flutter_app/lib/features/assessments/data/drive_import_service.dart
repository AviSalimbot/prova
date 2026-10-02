import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:googleapis/drive/v3.dart' as drive;

import '../../../services/firestore_paths.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/assessment.dart';
import 'drive_auth_service.dart';

const _folderMimeType = 'application/vnd.google-apps.folder';

/// TODO: replace with your real Drive folder IDs (from each folder's
/// URL: drive.google.com/drive/folders/THIS_PART). All three must
/// contain the same {examName}/{participantCode}/{page}.jpg tree.
const Map<ScanVariant, String> _rootFolderIds = {
  ScanVariant.raw: '1ylUs0CO615F0XaM4C2Kp91r117xZ3PhC',
  ScanVariant.cleaned: '14gWHkrzUUhTU2eR_00P3f9k1Zghl6W0X',
  ScanVariant.cropped: '15vsMICDGFpvxH9sGDBvdXhcuioBYBeJO',
};

/// Walks the three Drive variant trees for a single exam's folder name,
/// and writes matching `participants`/`pages` documents into Firestore.
/// This is the ONLY place the app lists Drive folder contents live —
/// everyday browsing reads Firestore via ExamsRepository instead.
///
/// Re-running the import for the same exam is safe: participant and
/// page document IDs are derived deterministically from
/// (examId, code) / (participantId, pageNumber), so re-import overwrites
/// rather than duplicating.
class DriveImportService {
  DriveImportService(this._authService, this._firestore);

  final DriveAuthService _authService;
  final FirebaseFirestore _firestore;

  Future<drive.DriveApi> _api() async {
    final client = await _authService.getAuthenticatedClient();
    return drive.DriveApi(client);
  }

  Future<drive.File?> _findChildFolder(
    drive.DriveApi api,
    String parentId,
    String name,
  ) async {
    final escaped = name.replaceAll("'", "\\'");

    final result = await api.files.list(
      q: "'$parentId' in parents "
          "and name = '$escaped' "
          "and mimeType = '$_folderMimeType' "
          "and trashed = false",
      $fields: 'files(id, name)',
      pageSize: 1,
    );

    return result.files?.isNotEmpty == true ? result.files!.first : null;
  }

  Future<List<drive.File>> _listChildFolders(
    drive.DriveApi api,
    String parentId,
  ) async {
    final result = await api.files.list(
      q: "'$parentId' in parents "
          "and mimeType = '$_folderMimeType' "
          "and trashed = false",
      $fields: 'files(id, name)',
      orderBy: 'name',
      pageSize: 1000,
    );
    return result.files ?? <drive.File>[];
  }

  Future<List<drive.File>> _listChildFiles(
    drive.DriveApi api,
    String parentId,
  ) async {
    final result = await api.files.list(
      q: "'$parentId' in parents and trashed = false",
      $fields: 'files(id, name)',
      pageSize: 1000,
    );
    return result.files ?? <drive.File>[];
  }

  int? _parsePageNumber(String fileName) {
    final match = RegExp(r'^(\d+)\.\w+$').firstMatch(fileName);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  String _sanitizeForId(String value) =>
      value.replaceAll(RegExp(r'[/\\]'), '_');

  /// Walks all three variant trees for [examName] and writes/overwrites
  /// the corresponding participants/pages docs under [examId]. Returns
  /// the number of participants imported, for a simple success message.
  ///
  /// Live progress is reported by writing importStatus/importedPageCount/
  /// importTotalPages directly onto the exam doc as the import runs —
  /// see Assessment.importing/importProgress — rather than through a
  /// callback, so any screen watching examsStreamProvider (not just
  /// whichever widget happens to have called this method) can show a
  /// live "N/total pages" indicator, and that indicator keeps working
  /// even if the person closes the import dialog or navigates away
  /// partway through.
  ///
  /// Two phases are reported:
  ///  1. Drive scan — importStatus is 'processing' from the very first
  ///     moment, with importTotalPages == 0 (the total isn't known yet).
  ///     importScanned counts participant folders walked so far, so the
  ///     popup can show "Scanning Drive… N folders" instead of looking
  ///     frozen. This is the slow phase (many sequential Drive API
  ///     calls), which is why the status must flip to 'processing'
  ///     BEFORE it starts rather than after.
  ///  2. Firestore write — importTotalPages becomes known and
  ///     importedPageCount advances once per participant.
  Future<int> importExam(String examId, String examName) async {
    final examRef = _firestore.collection(FirestorePaths.exams).doc(examId);

    try {
      // Flip to 'processing' immediately so the progress popup appears
      // for the entire Drive scan, not only for the (fast) write phase.
      // importError is cleared explicitly so a retry after a previously
      // failed import doesn't leave a stale error message on the doc.
      await examRef.update({
        'importStatus': 'processing',
        'importedPageCount': 0,
        'importTotalPages': 0,
        'importScanned': 0,
        'importError': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final api = await _api();

      // variant -> { participantCode -> { pageNumber -> fileId } }
      final byVariant = <ScanVariant, Map<String, Map<int, String>>>{};

      // Folders walked across all three variants so far; written to
      // Firestore every few folders (not every one) to keep the scan
      // from being slowed down by its own progress reporting.
      var scannedFolders = 0;

      for (final variant in ScanVariant.values) {
        final rootId = _rootFolderIds[variant]!;
        final examFolder = await _findChildFolder(api, rootId, examName);

        if (examFolder?.id == null) {
          byVariant[variant] = {};
          continue;
        }

        final participantFolders =
            await _listChildFolders(api, examFolder!.id!);
        final perParticipant = <String, Map<int, String>>{};

        for (final folder in participantFolders) {
          if (folder.id == null || folder.name == null) continue;

          final files = await _listChildFiles(api, folder.id!);
          final perPage = <int, String>{};

          for (final file in files) {
            if (file.id == null || file.name == null) continue;
            final pageNumber = _parsePageNumber(file.name!);
            if (pageNumber == null) continue;
            perPage[pageNumber] = file.id!;
          }

          perParticipant[folder.name!] = perPage;

          scannedFolders++;
          if (scannedFolders % 3 == 0) {
            await examRef.update({'importScanned': scannedFolders});
          }
        }

        byVariant[variant] = perParticipant;
      }

      // Final scan count so the last value shown isn't a few folders
      // behind.
      await examRef.update({'importScanned': scannedFolders});

      // Union of participant codes seen across all three variants, in
      // case one tree is missing a folder the others have.
      final allCodes = <String>{
        for (final map in byVariant.values) ...map.keys,
      };

      // Computed once, up front, for two reasons: it's what lets us
      // report importTotalPages before any page doc is written, and it
      // means the write loop below doesn't recompute the same page-number
      // union twice (once for progress, once for the actual writes).
      final pageNumbersByCode = <String, Set<int>>{
        for (final code in allCodes)
          code: {
            for (final variant in ScanVariant.values)
              ...?byVariant[variant]?[code]?.keys,
          },
      };
      final totalPages = pageNumbersByCode.values
          .fold<int>(0, (sum, pages) => sum + pages.length);

      // Drive scan is done and the real total is known — this switches
      // the popup from the indeterminate "Scanning Drive…" state to the
      // determinate "N / total pages" bar.
      await examRef.update({
        'importTotalPages': totalPages,
        'importedPageCount': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      var batch = _firestore.batch();
      var writesInBatch = 0;
      var participantCount = 0;
      var importedSoFar = 0;

      Future<void> commitIfNeeded() async {
        // Firestore batches cap at 500 writes; flush proactively at a
        // safe margin below that since a batch mixes participant docs and
        // an unpredictable number of page docs.
        if (writesInBatch >= 400) {
          await batch.commit();
          batch = _firestore.batch();
          writesInBatch = 0;
        }
      }

      for (final code in allCodes) {
        final participantId = _sanitizeForId('${examId}__$code');
        final participantRef = _firestore
            .collection(FirestorePaths.participants)
            .doc(participantId);

        final allPageNumbers = pageNumbersByCode[code]!;

        batch.set(participantRef, {
          'examId': examId,
          'code': code,
          'pageCount': allPageNumbers.length,
          'status': AssessmentStatus.complete.name,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        writesInBatch++;
        await commitIfNeeded();

        for (final pageNumber in allPageNumbers) {
          final pageId = '${participantId}__$pageNumber';
          final pageRef =
              _firestore.collection(FirestorePaths.pages).doc(pageId);

          batch.set(pageRef, {
            'participantId': participantId,
            'examId': examId,
            'pageNumber': pageNumber,
            'rawFileId': byVariant[ScanVariant.raw]?[code]?[pageNumber],
            'cleanedFileId': byVariant[ScanVariant.cleaned]?[code]?[pageNumber],
            'croppedFileId': byVariant[ScanVariant.cropped]?[code]?[pageNumber],
            'scanStatus': 'scanned_ok',
            'updatedAt': FieldValue.serverTimestamp(),
          });
          writesInBatch++;
          await commitIfNeeded();
        }

        participantCount++;
        importedSoFar += allPageNumbers.length;

        // Reported once per participant rather than once per page —
        // a participant is usually only a handful of pages, so this
        // still updates several times a second without turning every
        // single page into its own Firestore write. Awaited (not
        // fire-and-forget) so these land in order; an out-of-order
        // write could otherwise briefly show the counter jump backward.
        await examRef.update({
          'importedPageCount': importedSoFar,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (writesInBatch > 0) {
        await batch.commit();
      }

      await examRef.update({
        'participantCount': participantCount,
        'pageCount': importedSoFar,
        'status': participantCount > 0
            ? AssessmentStatus.complete.name
            : AssessmentStatus.incomplete.name,
        'importStatus': 'ready',
        'importedPageCount': importedSoFar,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return participantCount;
    } catch (e) {
      // Best-effort — if the exam doc itself is what's unreachable
      // (e.g. deleted mid-import), don't let this secondary write mask
      // the original error with a new one.
      try {
        await examRef.update({
          'importStatus': 'failed',
          'importError': e.toString(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {
        // Swallowed deliberately — see comment above.
      }
      rethrow;
    }
  }

  /// Downloads the raw bytes of a single page image for a given Drive
  /// file ID, for Image.memory. Drive files aren't reachable by a plain
  /// public URL even when owned by the signed-in account, so this
  /// always goes through an authenticated request rather than
  /// Image.network.
  Future<List<int>> downloadPageBytes(String fileId) async {
    final api = await _api();

    final media = await api.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final chunks = <int>[];
    await for (final chunk in media.stream) {
      chunks.addAll(chunk);
    }
    return chunks;
  }
}

final driveImportServiceProvider = Provider<DriveImportService>(
  (ref) => DriveImportService(
    ref.watch(driveAuthServiceProvider),
    ref.watch(firestoreProvider),
  ),
);

final pageBytesProvider = FutureProvider.family<List<int>, String>(
  (ref, fileId) =>
      ref.watch(driveImportServiceProvider).downloadPageBytes(fileId),
);