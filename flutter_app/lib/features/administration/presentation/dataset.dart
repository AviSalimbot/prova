import 'package:flutter/material.dart';

import '../../../core/widgets/header_banner.dart';

// ===========================================================================
// DATASET REGISTRY PANEL
// ===========================================================================

/// The "Dataset Registry" tab of the Administration screen.
///
/// Static placeholder: the layout, copy, and sample rows match the
/// intended design (Figure H-1), but nothing here is wired to a
/// repository/provider yet — the registry table, the two collected-
/// student-solutions slice cards, and the participant records table are
/// all hardcoded.
class DatasetRegistryPanel extends StatelessWidget {
  const DatasetRegistryPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _DatasetRegistryCard(),

          SizedBox(height: 32),

          Text(
            'Collected student solutions',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),

          SizedBox(height: 12),

          _CollectedStudentSolutionsRow(),

          SizedBox(height: 32),

          Text(
            'Participant records',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),

          SizedBox(height: 12),

          _ParticipantRecordsCard(),
        ],
      ),
    );
  }
}

// ===========================================================================
// DATASET REGISTRY TABLE
// ===========================================================================

class _DatasetRow {
  const _DatasetRow({
    required this.source,
    required this.licence,
    required this.size,
    required this.pipelineRole,
  });

  final String source;
  final String licence;
  final String size;
  final String pipelineRole;
}

class _DatasetRegistryCard extends StatelessWidget {
  const _DatasetRegistryCard();

  static const _rows = [
    _DatasetRow(
      source: 'MathWriting',
      licence: 'CC BY-NC-SA 4.0',
      size: '10,000 samples',
      pipelineRole: 'Layer 1 — OCR fine-tuning',
    ),
    _DatasetRow(
      source: 'AMPS (linear algebra subset)',
      licence: 'MIT',
      size: '~5M problems (LA subset)',
      pipelineRole: 'Layer 2 — domain adaptation',
    ),
    _DatasetRow(
      source: 'Linear Algebra Error Corpus',
      licence: 'Expert-specified error patterns',
      size: '6,142 labeled instances',
      pipelineRole: 'Layer 2 — classification fine-tuning',
    ),
    _DatasetRow(
      source: 'Collected Student Solutions',
      licence: 'IRB-governed, local',
      size: '288 participants · 2,304 items',
      pipelineRole: 'Validation & regression only',
    ),
  ];

  static const _headerStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: ProvaColors.subtitleGray,
    letterSpacing: 0.5,
  );

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: ProvaColors.dividerGray),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dataset registry',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 4),

            const Text(
              'Data sources used across the pipeline.',
              style: TextStyle(
                fontSize: 13,
                color: ProvaColors.subtitleGray,
              ),
            ),

            const SizedBox(height: 20),

            // Header row.
            const Row(
              children: [
                Expanded(flex: 3, child: Text('SOURCE', style: _headerStyle)),
                Expanded(
                  flex: 3,
                  child: Text('LICENCE', style: _headerStyle),
                ),
                Expanded(flex: 3, child: Text('SIZE', style: _headerStyle)),
                Expanded(
                  flex: 3,
                  child: Text('PIPELINE ROLE', style: _headerStyle),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1, color: ProvaColors.dividerGray),

            for (final row in _rows) ...[
              _DatasetTableRow(row: row),
              const Divider(height: 1, color: ProvaColors.dividerGray),
            ],
          ],
        ),
      ),
    );
  }
}

class _DatasetTableRow extends StatelessWidget {
  const _DatasetTableRow({required this.row});

  final _DatasetRow row;

  static const _monoStyle = TextStyle(
    fontFamily: 'monospace',
    fontSize: 13,
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              row.source,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          Expanded(
            flex: 3,
            child: Text(
              row.licence,
              style: const TextStyle(
                fontSize: 13,
                color: ProvaColors.subtitleGray,
              ),
            ),
          ),

          Expanded(
            flex: 3,
            child: Text(row.size, style: _monoStyle),
          ),

          Expanded(
            flex: 3,
            child: Text(
              row.pipelineRole,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// COLLECTED STUDENT SOLUTIONS — SLICE CARDS
// ===========================================================================

class _CollectedStudentSolutionsRow extends StatelessWidget {
  const _CollectedStudentSolutionsRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _ValidationSliceCard()),
        SizedBox(width: 24),
        Expanded(child: _RegressionSliceCard()),
      ],
    );
  }
}

class _SliceCardShell extends StatelessWidget {
  const _SliceCardShell({
    required this.kicker,
    required this.badge,
    required this.children,
  });

  final String kicker;
  final Widget badge;
  final List<Widget> children;

  static const _kickerStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: ProvaColors.subtitleGray,
    letterSpacing: 0.5,
  );

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: ProvaColors.dividerGray),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(kicker, style: _kickerStyle),
                badge,
              ],
            ),

            const SizedBox(height: 16),

            ...children,
          ],
        ),
      ),
    );
  }
}

class _SliceBadge extends StatelessWidget {
  const _SliceBadge({
    required this.label,
    required this.foreground,
    required this.background,
  });

  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: foreground,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _ValidationSliceCard extends StatelessWidget {
  const _ValidationSliceCard();

  @override
  Widget build(BuildContext context) {
    return _SliceCardShell(
      kicker: 'VALIDATION SLICE',
      badge: const _SliceBadge(
        label: 'NOT RELEASED',
        foreground: ProvaColors.subtitleGray,
        background: Color(0xFFEDEDED),
      ),
      children: [
        const Text(
          '96 participants',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),

        const SizedBox(height: 2),

        const Text(
          '768 items',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),

        const SizedBox(height: 16),

        SizedBox(
          width: double.infinity,
          child: FilledButton(
            // Disabled: gated on run R-014's metrics being locked.
            onPressed: null,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE0E0E0),
              disabledBackgroundColor: const Color(0xFFE0E0E0),
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.white,
              textStyle: const TextStyle(fontSize: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text('Release for retraining'),
          ),
        ),

        const SizedBox(height: 10),

        const Text(
          'Available once the metrics of run R-014 are locked.',
          style: TextStyle(fontSize: 12, color: ProvaColors.subtitleGray),
        ),
      ],
    );
  }
}

class _RegressionSliceCard extends StatelessWidget {
  const _RegressionSliceCard();

  @override
  Widget build(BuildContext context) {
    return _SliceCardShell(
      kicker: 'REGRESSION SLICE',
      badge: _SliceBadge(
        label: 'PERMANENTLY WITHHELD',
        foreground: Colors.red.shade700,
        background: Colors.red.shade50,
      ),
      children: const [
        Text(
          '24 participants',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),

        SizedBox(height: 2),

        Text(
          '192 items',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),

        SizedBox(height: 16),

        Text(
          'This slice is never released for retraining.',
          style: TextStyle(fontSize: 13),
        ),
      ],
    );
  }
}

// ===========================================================================
// PARTICIPANT RECORDS TABLE
// ===========================================================================

class _ParticipantRow {
  const _ParticipantRow({
    required this.participant,
    required this.slice,
    required this.assigned,
  });

  final String participant;
  final String slice;
  final String assigned;
}

class _ParticipantRecordsCard extends StatelessWidget {
  const _ParticipantRecordsCard();

  static const _rows = [
    _ParticipantRow(
      participant: 'P003',
      slice: 'Validation',
      assigned: '2 Jun 2026',
    ),
    _ParticipantRow(
      participant: 'P015',
      slice: 'Regression',
      assigned: '2 Jun 2026',
    ),
    _ParticipantRow(
      participant: 'P028',
      slice: 'Validation',
      assigned: '2 Jun 2026',
    ),
    _ParticipantRow(
      participant: 'P041',
      slice: 'Validation',
      assigned: '9 Jun 2026',
    ),
    _ParticipantRow(
      participant: 'P057',
      slice: 'Regression',
      assigned: '9 Jun 2026',
    ),
    _ParticipantRow(
      participant: 'P073',
      slice: 'Validation',
      assigned: '9 Jun 2026',
    ),
    _ParticipantRow(
      participant: 'P089',
      slice: 'Regression',
      assigned: '16 Jun 2026',
    ),
    _ParticipantRow(
      participant: 'P104',
      slice: 'Validation',
      assigned: '16 Jun 2026',
    ),
  ];

  static const _headerStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: ProvaColors.subtitleGray,
    letterSpacing: 0.5,
  );

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: ProvaColors.dividerGray),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text('PARTICIPANT', style: _headerStyle),
                ),
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      Text('SLICE', style: _headerStyle),
                      SizedBox(width: 4),
                      Icon(
                        Icons.lock_outline,
                        size: 12,
                        color: ProvaColors.subtitleGray,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text('ASSIGNED', style: _headerStyle),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1, color: ProvaColors.dividerGray),

            for (final row in _rows) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        row.participant,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    Expanded(
                      flex: 3,
                      child: Text(
                        row.slice,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),

                    Expanded(
                      flex: 3,
                      child: Text(
                        row.assigned,
                        style: const TextStyle(
                          fontSize: 13,
                          color: ProvaColors.subtitleGray,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: ProvaColors.dividerGray),
            ],
          ],
        ),
      ),
    );
  }
}