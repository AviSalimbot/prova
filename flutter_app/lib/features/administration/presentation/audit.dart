import 'package:flutter/material.dart';

import '../../../core/widgets/header_banner.dart';

// ===========================================================================
// EXPORT & AUDIT PANEL
// ===========================================================================

/// The "Export & Audit" tab of the Administration screen.
///
/// Static placeholder: the layout, copy, and sample audit lines match the
/// intended design (Figure H-1) but nothing here is wired to a repository
/// or provider yet. Wiring up real exports and a live audit stream is
/// tracked separately.
class ExportAuditPanel extends StatelessWidget {
  const ExportAuditPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Expanded(
            flex: 4,
            child: _ExportCard(),
          ),

          SizedBox(width: 24),

          Expanded(
            flex: 5,
            child: _AuditLogCard(),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// EXPORT CARD
// ===========================================================================

class _ExportCard extends StatelessWidget {
  const _ExportCard();

  static const _rows = [
    _ExportRowData(
      label: 'Evaluation report (PDF)',
    ),
    _ExportRowData(
      label: 'Per-item records (CSV)',
    ),
    _ExportRowData(
      label: 'Annotator labels (CSV)',
    ),
  ];

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
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Export',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            for (var i = 0; i < _rows.length; i++) ...[
              _ExportRow(data: _rows[i]),

              if (i != _rows.length - 1)
                const Divider(height: 1, color: ProvaColors.dividerGray),
            ],

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _ExportRowData {
  const _ExportRowData({required this.label});

  final String label;
}

class _ExportRow extends StatelessWidget {
  const _ExportRow({required this.data});

  final _ExportRowData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            data.label,
            style: const TextStyle(fontSize: 13),
          ),

          OutlinedButton(
            // TODO: wire up export flow.
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.black87,
              side: const BorderSide(color: ProvaColors.dividerGray),
              textStyle: const TextStyle(fontSize: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
            ),
            child: const Text('Export'),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// AUDIT LOG CARD
// ===========================================================================

class _AuditLogCard extends StatelessWidget {
  const _AuditLogCard();

  // Static sample lines standing in for a live audit stream.
  static const _lines = [
    '[09:40] researcher · started run_2026_sem1_batch01',
    '[10:12] researcher · started run_2026_sem1_batch02',
    '[10:39] system · flagged P117 item7 — low OCR confidence',
    '[10:41] system · flagged P118 item6 — illegible',
    '[11:02] annotator1 · labeled P058 item1 → Procedural',
    '[11:05] annotator2 · labeled P058 item1 → Procedural',
    '[11:20] instructor · adjudicated P079 item2 → Procedural',
    '[11:24] instructor · adjudicated P084 item6 → Conceptual',
    '[11:41] researcher · exported evaluation report '
        '(run_2026_sem1_batch01)',
    '[13:02] researcher · added user Course Instructor (active)',
    '[14:05] researcher · started run_2026_sem1_pilot',
    '[16:03] system · run_2026_sem1_smoke failed — OCR service timeout',
  ];

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
        padding: const EdgeInsets.fromLTRB(20, 20, 8, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Text(
                'Audit Log',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              height: 420,
              child: Scrollbar(
                thumbVisibility: true,
                child: ListView.separated(
                  padding: const EdgeInsets.only(right: 12),
                  itemCount: _lines.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => Text(
                    _lines[index],
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Colors.black87,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}