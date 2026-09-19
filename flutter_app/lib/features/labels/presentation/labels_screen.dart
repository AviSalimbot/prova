import 'package:flutter/material.dart';

import '../../../core/widgets/header_banner.dart';

/// 'My Labels' screen — shows the current annotator's own labeling
/// progress and history for the active assessment.
class LabelsScreen extends StatefulWidget {
  const LabelsScreen({super.key});

  @override
  State<LabelsScreen> createState() => _LabelsScreenState();
}

class _LabelsScreenState extends State<LabelsScreen> {
  String _problemFilter = 'all';
  String _labelFilter = 'all';
  final TextEditingController _searchController = TextEditingController();

  // TODO: replace with real data from the annotation repository/provider.
  static const int _annotatorIndex = 1;
  static const int _annotatorCount = 2;
  static const int _labeledCount = 342;
  static const int _totalCount = 960;

  static const List<_LabelStat> _stats = [
    _LabelStat('CONCEPTUAL', 79, _LabelKind.conceptual),
    _LabelStat('PROCEDURAL', 85, _LabelKind.procedural),
    _LabelStat('NOTATION', 86, _LabelKind.notation),
    _LabelStat('NO ERROR', 92, _LabelKind.noError),
  ];

  static const List<_LabeledItem> _items = [
    _LabeledItem(
      item: 'P043 · item 6',
      problem: 'Solve the system using Gauss-Jordan eliminati...',
      label: _LabelKind.conceptual,
      note: '—',
      labeledAt: '15 Jul 2026, 16:57',
    ),
    _LabeledItem(
      item: 'P043 · item 5',
      problem: 'Add matrices A and B.',
      label: _LabelKind.notation,
      note: '—',
      labeledAt: '15 Jul 2026, 16:56',
    ),
    _LabeledItem(
      item: 'P043 · item 4',
      problem: 'Row-reduce matrix A to echelon form.',
      label: _LabelKind.conceptual,
      note: 'Misidentifies rank vs. dimension.',
      labeledAt: '15 Jul 2026, 16:55',
    ),
    _LabeledItem(
      item: 'P043 · item 3',
      problem: 'Find the inverse of matrix A.',
      label: _LabelKind.procedural,
      note: 'Row operation applied out of order.',
      labeledAt: '15 Jul 2026, 16:53',
    ),
    _LabeledItem(
      item: 'P043 · item 2',
      problem: 'Multiply matrices A and B.',
      label: _LabelKind.noError,
      note: '—',
      labeledAt: '15 Jul 2026, 16:52',
    ),
    _LabeledItem(
      item: 'P043 · item 1',
      problem: 'Solve Ax = b for x.',
      label: _LabelKind.procedural,
      note: '—',
      labeledAt: '15 Jul 2026, 16:50',
    ),
    _LabeledItem(
      item: 'P042 · item 8',
      problem: 'Solve the system using Gauss-Jordan eliminati...',
      label: _LabelKind.conceptual,
      note: '—',
      labeledAt: '15 Jul 2026, 16:49',
    ),
    _LabeledItem(
      item: 'P042 · item 7',
      problem: 'Add matrices A and B.',
      label: _LabelKind.notation,
      note: 'Matrix brackets dropped mid-solution.',
      labeledAt: '15 Jul 2026, 16:48',
    ),
    _LabeledItem(
      item: 'P042 · item 6',
      problem: 'Row-reduce matrix A to echelon form.',
      label: _LabelKind.procedural,
      note: 'Arithmetic slip in back-substitution.',
      labeledAt: '15 Jul 2026, 16:46',
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Palette.background,
      body: SafeArea(
        child: Column(
          children: [
            const ProvaHeaderBanner(
              pageTitle: 'My Labels',
              stage: PipelineStage.annotate,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _AnnotatorCard(
                      annotatorIndex: _annotatorIndex,
                      annotatorCount: _annotatorCount,
                      labeled: _labeledCount,
                      total: _totalCount,
                    ),
                    const SizedBox(height: 20),
                    _FiltersRow(
                      problemFilter: _problemFilter,
                      labelFilter: _labelFilter,
                      searchController: _searchController,
                      onProblemChanged: (v) =>
                          setState(() => _problemFilter = v),
                      onLabelChanged: (v) => setState(() => _labelFilter = v),
                    ),
                    const SizedBox(height: 20),
                    _StatsRow(stats: _stats),
                    const SizedBox(height: 20),
                    _LabelsTable(items: _items),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Palette (falls back to local constants where ProvaColors doesn't define
// a token used by this screen).
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
  static const Color rowAlt = Color(0xFFF9FAFB);
  static const Color divider = Color(0xFFEDEEF0);
}

// ---------------------------------------------------------------------------
// Annotator progress card
// ---------------------------------------------------------------------------

class _AnnotatorCard extends StatelessWidget {
  const _AnnotatorCard({
    required this.annotatorIndex,
    required this.annotatorCount,
    required this.labeled,
    required this.total,
  });

  final int annotatorIndex;
  final int annotatorCount;
  final int labeled;
  final int total;

  @override
  Widget build(BuildContext context) {
    final double progress = total == 0 ? 0 : labeled / total;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
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
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _Palette.accentGreenSoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: _Palette.accentGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Annotator $annotatorIndex of $annotatorCount',
                      style: const TextStyle(
                        color: _Palette.accentGreen,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Text(
                    '$labeled of $total labeled',
                    style: const TextStyle(
                      color: _Palette.bodyText,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      width: 160,
                      height: 8,
                      child: LinearProgressIndicator(
                        value: progress.clamp(0, 1),
                        backgroundColor: _Palette.divider,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          _Palette.accentGreen,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            "Your own labels only. Other annotators' labels and model "
            'predictions are not shown.',
            style: TextStyle(color: _Palette.mutedText, fontSize: 13.5),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filters row (problem filter, label filter, search)
// ---------------------------------------------------------------------------

class _FiltersRow extends StatelessWidget {
  const _FiltersRow({
    required this.problemFilter,
    required this.labelFilter,
    required this.searchController,
    required this.onProblemChanged,
    required this.onLabelChanged,
  });

  final String problemFilter;
  final String labelFilter;
  final TextEditingController searchController;
  final ValueChanged<String> onProblemChanged;
  final ValueChanged<String> onLabelChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _FilterDropdown(value: problemFilter, onChanged: onProblemChanged),
        const SizedBox(width: 12),
        _FilterDropdown(value: labelFilter, onChanged: onLabelChanged),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: _Palette.cardBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _Palette.cardBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, size: 18, color: _Palette.mutedText),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: searchController,
                    style: const TextStyle(fontSize: 14),
                    decoration: const InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: 'Search by student code...',
                      hintStyle: TextStyle(color: _Palette.mutedText),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: _Palette.cardBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _Palette.cardBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          icon: const Icon(Icons.unfold_more, size: 16),
          items: const [
            DropdownMenuItem(value: 'all', child: Text('all')),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stat cards row
// ---------------------------------------------------------------------------

enum _LabelKind { conceptual, procedural, notation, noError }

extension on _LabelKind {
  String get display {
    switch (this) {
      case _LabelKind.conceptual:
        return 'Conceptual';
      case _LabelKind.procedural:
        return 'Procedural';
      case _LabelKind.notation:
        return 'Notation';
      case _LabelKind.noError:
        return 'No error';
    }
  }
}

class _LabelStat {
  const _LabelStat(this.title, this.count, this.kind);

  final String title;
  final int count;
  final _LabelKind kind;
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});

  final List<_LabelStat> stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < stats.length; i++) ...[
          if (i > 0) const SizedBox(width: 16),
          Expanded(child: _StatCard(stat: stats[i])),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.stat});

  final _LabelStat stat;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: _Palette.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _Palette.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            stat.title,
            style: const TextStyle(
              color: _Palette.mutedText,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${stat.count}',
            style: const TextStyle(
              color: _Palette.titleBlack,
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Labels table
// ---------------------------------------------------------------------------

class _LabeledItem {
  const _LabeledItem({
    required this.item,
    required this.problem,
    required this.label,
    required this.note,
    required this.labeledAt,
  });

  final String item;
  final String problem;
  final _LabelKind label;
  final String note;
  final String labeledAt;
}

class _LabelsTable extends StatelessWidget {
  const _LabelsTable({required this.items});

  final List<_LabeledItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _Palette.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _Palette.cardBorder),
      ),
      child: Column(
        children: [
          const _TableHeaderRow(),
          const Divider(height: 1, color: _Palette.divider),
          for (int i = 0; i < items.length; i++)
            _TableDataRow(item: items[i], alt: i.isOdd),
        ],
      ),
    );
  }
}

class _TableHeaderRow extends StatelessWidget {
  const _TableHeaderRow();

  static const TextStyle _style = TextStyle(
    color: _Palette.mutedText,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.4,
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: const [
          Expanded(flex: 2, child: Text('ITEM', style: _style)),
          Expanded(flex: 4, child: Text('PROBLEM', style: _style)),
          Expanded(flex: 2, child: Text('MY LABEL', style: _style)),
          Expanded(flex: 3, child: Text('NOTE', style: _style)),
          Expanded(flex: 2, child: Text('LABELED', style: _style)),
          SizedBox(width: 70),
        ],
      ),
    );
  }
}

class _TableDataRow extends StatelessWidget {
  const _TableDataRow({required this.item, required this.alt});

  final _LabeledItem item;
  final bool alt;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: alt ? _Palette.rowAlt : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              item.item,
              style: const TextStyle(
                color: _Palette.titleBlack,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              item.problem,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _Palette.bodyText, fontSize: 14),
            ),
          ),
          Expanded(flex: 2, child: _LabelChip(kind: item.label)),
          Expanded(
            flex: 3,
            child: Text(
              item.note,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _Palette.bodyText, fontSize: 14),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              item.labeledAt,
              style: const TextStyle(color: _Palette.mutedText, fontSize: 13),
            ),
          ),
          SizedBox(
            width: 70,
            child: TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () {
                // TODO: navigate to Item Detail for `item.item`.
              },
              child: const Text(
                'Review',
                style: TextStyle(
                  color: _Palette.accentGreen,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LabelChip extends StatelessWidget {
  const _LabelChip({required this.kind});

  final _LabelKind kind;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _Palette.accentGreenSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        kind.display,
        style: const TextStyle(
          color: _Palette.accentGreen,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}