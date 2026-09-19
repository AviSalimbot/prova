import 'package:flutter/material.dart';

import '../../../core/widgets/header_banner.dart';

/// 'Runs' screen — lists the pipeline run history so a researcher can
/// inspect a run's pinned OCR/classifier versions and compare it against
/// the previous run.
class RunsScreen extends StatelessWidget {
  const RunsScreen({super.key});

  // TODO: replace with real data from the runs repository/provider.
  static const List<_RunRecord> _runs = [
    _RunRecord(
      name: 'run_2026_sem1_batch01',
      status: _RunStatus.running,
      itemsLabel: '694/728 items',
      accuracyLabel: null,
      ocrVersion: 'ocr-v1',
      ocrTag: _VersionTag.current,
      classifierVersion: 'clf-v1',
      classifierTag: _VersionTag.current,
      promotedNote: false,
      date: '15 Jul 2026, 10:12',
      runId: 'run_a83f2c1',
    ),
    _RunRecord(
      name: 'run_2026_sem1_batch01',
      status: _RunStatus.complete,
      itemsLabel: '728 items',
      accuracyLabel: '78.4%',
      ocrVersion: 'ocr-v1',
      ocrTag: _VersionTag.current,
      classifierVersion: 'clf-v1',
      classifierTag: _VersionTag.current,
      promotedNote: true,
      date: '14 Jul 2026, 09:40',
      runId: 'run_7e1d940',
    ),
    _RunRecord(
      name: 'run_2026_sem1_pilot',
      status: _RunStatus.complete,
      itemsLabel: '240 items',
      accuracyLabel: '74.1%',
      ocrVersion: 'ocr-v1',
      ocrTag: _VersionTag.current,
      classifierVersion: 'clf-da3',
      classifierTag: _VersionTag.superseded,
      promotedNote: false,
      date: '2 Jul 2026, 14:05',
      runId: 'run_5c209ab',
    ),
    _RunRecord(
      name: 'run_2026_sem1_baseline',
      status: _RunStatus.complete,
      itemsLabel: '320 items',
      accuracyLabel: '71.6%',
      ocrVersion: 'ocr-v1',
      ocrTag: _VersionTag.current,
      classifierVersion: 'clf-da3',
      classifierTag: _VersionTag.superseded,
      promotedNote: true,
      date: '24 Jun 2026, 11:22',
      runId: 'run_2a71ffe',
    ),
    _RunRecord(
      name: 'run_2026_sem1_smoke',
      status: _RunStatus.failed,
      itemsLabel: '12/80 items',
      accuracyLabel: null,
      ocrVersion: 'ocr-v1',
      ocrTag: _VersionTag.current,
      classifierVersion: 'clf-da0',
      classifierTag: _VersionTag.superseded,
      promotedNote: false,
      date: '18 Jun 2026, 16:03',
      runId: 'run_09f13cc',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Palette.background,
      body: SafeArea(
        child: Column(
          children: [
            const ProvaHeaderBanner(
              pageTitle: 'Runs',
              stage: PipelineStage.notApplicable,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
                child: _RunHistoryCard(runs: _runs),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Palette
// ---------------------------------------------------------------------------

class _Palette {
  static const Color background = Color(0xFFF7F8F9);
  static const Color cardBackground = Colors.white;
  static const Color cardBorder = Color(0xFFE7E9EC);
  static const Color accentGreen = Color(0xFF1E7D5C);
  static const Color accentGreenSoft = Color(0xFFE4F3EC);
  static const Color titleBlack = Color(0xFF1B1E22);
  static const Color bodyText = Color(0xFF2B2E33);
  static const Color mutedText = Color(0xFF8A8F98);
  static const Color divider = Color(0xFFEDEEF0);
  static const Color tagGray = Color(0xFFEEF0F2);
  static const Color tagGrayText = Color(0xFF6B7078);
  static const Color amberBg = Color(0xFFFBF0DA);
  static const Color amberText = Color(0xFFB4791F);
  static const Color redBg = Color(0xFFFBE9E9);
  static const Color redText = Color(0xFFC23838);
  static const Color promotedNoteText = Color(0xFF9A7A16);
}

// ---------------------------------------------------------------------------
// Data model
// ---------------------------------------------------------------------------

enum _RunStatus { running, complete, failed }

enum _VersionTag { current, superseded }

class _RunRecord {
  const _RunRecord({
    required this.name,
    required this.status,
    required this.itemsLabel,
    required this.accuracyLabel,
    required this.ocrVersion,
    required this.ocrTag,
    required this.classifierVersion,
    required this.classifierTag,
    required this.promotedNote,
    required this.date,
    required this.runId,
  });

  final String name;
  final _RunStatus status;
  final String itemsLabel;
  final String? accuracyLabel;
  final String ocrVersion;
  final _VersionTag ocrTag;
  final String classifierVersion;
  final _VersionTag classifierTag;
  final bool promotedNote;
  final String date;
  final String runId;
}

// ---------------------------------------------------------------------------
// Run history card
// ---------------------------------------------------------------------------

class _RunHistoryCard extends StatelessWidget {
  const _RunHistoryCard({required this.runs});

  final List<_RunRecord> runs;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _Palette.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _Palette.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Run History',
                style: TextStyle(
                  color: _Palette.titleBlack,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${runs.length} runs',
                style: const TextStyle(
                  color: _Palette.mutedText,
                  fontSize: 14,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Click a run to inspect its configuration and compare with '
            'the previous run.',
            style: TextStyle(color: _Palette.mutedText, fontSize: 14.5),
          ),
          const SizedBox(height: 20),
          for (int i = 0; i < runs.length; i++) ...[
            _RunCard(run: runs[i]),
            if (i != runs.length - 1) const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

class _RunCard extends StatelessWidget {
  const _RunCard({required this.run});

  final _RunRecord run;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        // TODO: navigate to the run's configuration / comparison view.
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _Palette.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.arrow_right,
                  size: 20,
                  color: _Palette.mutedText,
                ),
                const SizedBox(width: 2),
                Text(
                  run.name,
                  style: const TextStyle(
                    color: _Palette.titleBlack,
                    fontWeight: FontWeight.w700,
                    fontSize: 15.5,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(width: 10),
                _StatusPill(status: run.status),
                const Spacer(),
                Text(
                  run.itemsLabel,
                  style: const TextStyle(
                    color: _Palette.bodyText,
                    fontSize: 14,
                    fontFamily: 'monospace',
                  ),
                ),
                if (run.accuracyLabel != null) ...[
                  const SizedBox(width: 12),
                  Text(
                    run.accuracyLabel!,
                    style: const TextStyle(
                      color: _Palette.titleBlack,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      fontFamily: 'monospace',
                    ),
                  ),
                ] else ...[
                  const SizedBox(width: 12),
                  const Text(
                    '–',
                    style: TextStyle(color: _Palette.mutedText, fontSize: 14),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                _VersionField(
                  label: 'OCR',
                  version: run.ocrVersion,
                  tag: run.ocrTag,
                ),
                const SizedBox(width: 8),
                _VersionField(
                  label: 'Classifier',
                  version: run.classifierVersion,
                  tag: run.classifierTag,
                ),
                if (run.promotedNote) ...[
                  const SizedBox(width: 4),
                  const Text(
                    'version promoted between runs',
                    style: TextStyle(
                      color: _Palette.promotedNoteText,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: _Palette.divider),
            const SizedBox(height: 12),
            Text(
              '${run.date} · started by researcher · ${run.runId}',
              style: const TextStyle(
                color: _Palette.mutedText,
                fontSize: 13.5,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final _RunStatus status;

  @override
  Widget build(BuildContext context) {
    late final Color bg;
    late final Color fg;
    late final String label;

    switch (status) {
      case _RunStatus.running:
        bg = _Palette.amberBg;
        fg = _Palette.amberText;
        label = 'RUNNING';
        break;
      case _RunStatus.complete:
        bg = _Palette.accentGreenSoft;
        fg = _Palette.accentGreen;
        label = 'COMPLETE';
        break;
      case _RunStatus.failed:
        bg = _Palette.redBg;
        fg = _Palette.redText;
        label = 'FAILED';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w700,
          fontSize: 11.5,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _VersionField extends StatelessWidget {
  const _VersionField({
    required this.label,
    required this.version,
    required this.tag,
  });

  final String label;
  final String version;
  final _VersionTag tag;

  @override
  Widget build(BuildContext context) {
    final bool current = tag == _VersionTag.current;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: const TextStyle(color: _Palette.mutedText, fontSize: 14),
        ),
        Text(
          version,
          style: const TextStyle(
            color: _Palette.titleBlack,
            fontWeight: FontWeight.w700,
            fontSize: 14,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            color: current ? _Palette.accentGreenSoft : _Palette.tagGray,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            current ? 'CURRENT' : 'SUPERSEDED',
            style: TextStyle(
              color: current ? _Palette.accentGreen : _Palette.tagGrayText,
              fontWeight: FontWeight.w700,
              fontSize: 10.5,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );
  }
}