// lib/features/assessments/presentation/job_progress_popup.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/exams_repository.dart';
import '../domain/assessment.dart';

enum _JobKind { importing, cleaning, cropping }

/// One running job (import / clean / crop) for one assessment, reduced
/// to what the popup needs to draw.
class _JobSnapshot {
  const _JobSnapshot({
    required this.key,
    required this.kind,
    required this.title,
    required this.color,
    required this.indeterminate,
    required this.progress,
    required this.countLabel,
    this.remaining,
  });

  final String key;
  final _JobKind kind;
  final String title;
  final Color color;
  final bool indeterminate;
  final double progress;
  final String countLabel;
  final Duration? remaining;
}

const _importColor = Color(0xFF2E7D4F);
const _cleanColor = Color(0xFF2E5E3E);
const _cropColor = Color(0xFF2E4E8E);

List<_JobSnapshot> _jobsFrom(List<Assessment> assessments) {
  final jobs = <_JobSnapshot>[];

  for (final a in assessments) {
    if (a.importing) {
      final scanning = a.importTotalPages == 0;
      jobs.add(_JobSnapshot(
        key: '${a.id}:import',
        kind: _JobKind.importing,
        title: 'Importing "${a.name}"',
        color: _importColor,
        indeterminate: scanning,
        progress: a.importProgress,
        countLabel: scanning
            ? (a.importScanned > 0
                ? 'Scanning Drive… ${a.importScanned} folders'
                : 'Scanning Drive…')
            : '${a.importedPageCount} / ${a.importTotalPages} pages',
      ));
    }

    if (a.cleaning) {
      jobs.add(_JobSnapshot(
        key: '${a.id}:clean',
        kind: _JobKind.cleaning,
        title: 'Cleaning "${a.name}"',
        color: _cleanColor,
        // Before the first page finishes there is nothing to show yet.
        indeterminate: a.cleanedPageCount == 0,
        progress: a.cleanProgress,
        countLabel: a.cleanedPageCount == 0
            ? 'Starting…'
            : '${a.cleanedPageCount} / ${a.pageCount} pages',
        remaining: a.estimatedCleanRemaining(),
      ));
    }

    if (a.cropping) {
      jobs.add(_JobSnapshot(
        key: '${a.id}:crop',
        kind: _JobKind.cropping,
        title: 'Cropping "${a.name}"',
        color: _cropColor,
        indeterminate: a.croppedPageCount == 0,
        progress: a.cropProgress,
        countLabel: a.croppedPageCount == 0
            ? 'Starting…'
            : '${a.croppedPageCount} / ${a.pageCount} pages',
        remaining: a.estimatedCropRemaining(),
      ));
    }
  }

  return jobs;
}

/// Bottom-right stack of progress cards for every import / clean / crop
/// job currently 'processing'. Reads only from Firestore state via
/// examsStreamProvider, so it is correct regardless of which screen
/// started the job, and survives navigation or a page reload.
///
/// Drop it once, inside a Stack, on the Assessments screen:
///   Stack(children: [ ...content..., const JobProgressPopup() ])
class JobProgressPopup extends ConsumerWidget {
  const JobProgressPopup({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assessments =
        ref.watch(examsStreamProvider).valueOrNull ?? const <Assessment>[];
    final jobs = _jobsFrom(assessments);

    if (jobs.isEmpty) return const SizedBox.shrink();

    return Positioned(
      right: 16,
      bottom: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final job in jobs) ...[
            _JobProgressCard(key: ValueKey(job.key), job: job),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _JobProgressCard extends StatelessWidget {
  const _JobProgressCard({super.key, required this.job});

  final _JobSnapshot job;

  String _formatRemaining(Duration d) {
    final minutes = (d.inSeconds / 60).ceil();
    if (minutes <= 0) return '< 1 min left';
    if (minutes == 1) return '~1 min left';
    return '~$minutes min left';
  }

  @override
  Widget build(BuildContext context) {
    final percent = (job.progress * 100).round();

    return Container(
      width: 300,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(job.color),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  job.title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: job.indeterminate
                ? LinearProgressIndicator(
                    minHeight: 6,
                    backgroundColor: const Color(0xFFE6E9ED),
                    valueColor: AlwaysStoppedAnimation<Color>(job.color),
                  )
                : TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: job.progress),
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                    builder: (context, value, _) => LinearProgressIndicator(
                      value: value,
                      minHeight: 6,
                      backgroundColor: const Color(0xFFE6E9ED),
                      valueColor: AlwaysStoppedAnimation<Color>(job.color),
                    ),
                  ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  job.countLabel,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
              if (!job.indeterminate)
                Text(
                  job.remaining != null
                      ? '$percent% · ${_formatRemaining(job.remaining!)}'
                      : '$percent%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: job.color,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}