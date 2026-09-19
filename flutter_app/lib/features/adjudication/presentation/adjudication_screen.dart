import 'package:flutter/material.dart';

import '../../../core/widgets/header_banner.dart';

/// 'Adjudication' screen — lets a course instructor resolve disagreements
/// between the two annotators' independent labels and set the final
/// gold-standard label for each conflicting item.
class AdjudicationScreen extends StatefulWidget {
  const AdjudicationScreen({super.key});

  @override
  State<AdjudicationScreen> createState() => _AdjudicationScreenState();
}

class _AdjudicationScreenState extends State<AdjudicationScreen> {
  // TODO: replace with real data from the adjudication repository/provider.
  static const int _adjudicatedCount = 5;
  static const int _totalDisagreements = 12;

  static const List<_Disagreement> _disagreements = [
    _Disagreement(
      item: 'P011 · item 4',
      annotator1Label: 'Conceptual',
      annotator2Label: 'Procedural',
      resolved: true,
    ),
    _Disagreement(
      item: 'P023 · item 7',
      annotator1Label: 'Procedural',
      annotator2Label: 'Notation',
      resolved: true,
    ),
    _Disagreement(
      item: 'P042 · item 3',
      annotator1Label: 'Conceptual',
      annotator2Label: 'Notation',
      resolved: true,
    ),
    _Disagreement(
      item: 'P058 · item 1',
      annotator1Label: 'No error',
      annotator2Label: 'Procedural',
      resolved: true,
    ),
  ];

  // Item currently open in the adjudication workspace below.
  static const String _activeItemHeader = 'P079 · ITEM 2 · DE-IDENTIFIED';
  static const String _problemText = 'Find the inverse of matrix A.';
  static const String _ocrLatex =
      r'A^{-1} = \begin{bmatrix} 3 & -1 \\ -2 & 1 \end{bmatrix}';
  static const String _annotator1Label = 'Procedural';
  static const String _annotator1Note = 'Row operation applied incorrectly in step 3.';
  static const String _annotator2Label = 'No error';
  static const String _annotator2Note = '';

  String? _finalLabel;
  final TextEditingController _rationaleController = TextEditingController();

  @override
  void dispose() {
    _rationaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double progress = _adjudicatedCount / _totalDisagreements;

    return Scaffold(
      backgroundColor: _Palette.background,
      body: SafeArea(
        child: Column(
          children: [
            const ProvaHeaderBanner(
              pageTitle: 'Adjudication',
              stage: PipelineStage.adjudicate,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InstructorProgressCard(
                      adjudicated: _adjudicatedCount,
                      total: _totalDisagreements,
                      progress: progress,
                    ),
                    const SizedBox(height: 20),
                    _DisagreementsCard(disagreements: _disagreements),
                    const SizedBox(height: 20),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final bool wide = constraints.maxWidth > 900;
                        final itemPanel = _ItemDetailPanel(
                          header: _activeItemHeader,
                          problemText: _problemText,
                          ocrLatex: _ocrLatex,
                        );
                        final conflictPanel = _ConflictResolutionPanel(
                          annotator1Label: _annotator1Label,
                          annotator1Note: _annotator1Note,
                          annotator2Label: _annotator2Label,
                          annotator2Note: _annotator2Note,
                          selectedLabel: _finalLabel,
                          onLabelSelected: (v) =>
                              setState(() => _finalLabel = v),
                          rationaleController: _rationaleController,
                          onConfirm: _finalLabel == null
                              ? null
                              : () {
                                  // TODO: persist final gold-standard label.
                                },
                          onNext: () {
                            // TODO: advance to the next disagreement.
                          },
                        );

                        if (wide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 3, child: itemPanel),
                              const SizedBox(width: 20),
                              Expanded(flex: 2, child: conflictPanel),
                            ],
                          );
                        }
                        return Column(
                          children: [
                            itemPanel,
                            const SizedBox(height: 20),
                            conflictPanel,
                          ],
                        );
                      },
                    ),
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
  static const Color inputFill = Color(0xFFFBFBFC);
}

// ---------------------------------------------------------------------------
// Course instructor progress card
// ---------------------------------------------------------------------------

class _InstructorProgressCard extends StatelessWidget {
  const _InstructorProgressCard({
    required this.adjudicated,
    required this.total,
    required this.progress,
  });

  final int adjudicated;
  final int total;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final int percent = (progress * 100).round();

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
              const _StatusBadge(label: 'Course Instructor'),
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      width: 220,
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
                  const SizedBox(width: 10),
                  Text(
                    '$percent%',
                    style: const TextStyle(
                      color: _Palette.mutedText,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '$adjudicated of $total adjudicated',
            style: const TextStyle(
              color: _Palette.titleBlack,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Cohen's Kappa was already computed on the two annotators' "
            'original independent labels. This step resolves disagreements '
            'only.',
            style: TextStyle(color: _Palette.mutedText, fontSize: 13.5),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
            label,
            style: const TextStyle(
              color: _Palette.accentGreen,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Disagreements list card
// ---------------------------------------------------------------------------

class _Disagreement {
  const _Disagreement({
    required this.item,
    required this.annotator1Label,
    required this.annotator2Label,
    required this.resolved,
  });

  final String item;
  final String annotator1Label;
  final String annotator2Label;
  final bool resolved;
}

class _DisagreementsCard extends StatelessWidget {
  const _DisagreementsCard({required this.disagreements});

  final List<_Disagreement> disagreements;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      decoration: BoxDecoration(
        color: _Palette.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _Palette.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DISAGREEMENTS',
            style: TextStyle(
              color: _Palette.mutedText,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: Scrollbar(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: disagreements.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: _Palette.divider),
                itemBuilder: (context, index) {
                  return _DisagreementRow(disagreement: disagreements[index]);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DisagreementRow extends StatelessWidget {
  const _DisagreementRow({required this.disagreement});

  final _Disagreement disagreement;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        // TODO: load this disagreement into the workspace below.
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            SizedBox(
              width: 140,
              child: Text(
                disagreement.item,
                style: const TextStyle(
                  color: _Palette.titleBlack,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            Expanded(
              child: Text(
                'A1: ${disagreement.annotator1Label} · '
                'A2: ${disagreement.annotator2Label}',
                style: const TextStyle(
                  color: _Palette.bodyText,
                  fontSize: 14,
                ),
              ),
            ),
            if (disagreement.resolved)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _Palette.accentGreenSoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Resolved',
                  style: TextStyle(
                    color: _Palette.accentGreen,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
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
// Left panel: item / problem / solution / OCR transcription
// ---------------------------------------------------------------------------

class _ItemDetailPanel extends StatelessWidget {
  const _ItemDetailPanel({
    required this.header,
    required this.problemText,
    required this.ocrLatex,
  });

  final String header;
  final String problemText;
  final String ocrLatex;

  static const TextStyle _labelStyle = TextStyle(
    color: _Palette.mutedText,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.6,
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _Palette.cardBackground,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _Palette.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(header, style: _labelStyle),
              const SizedBox(height: 18),
              const Text('PROBLEM', style: _labelStyle),
              const SizedBox(height: 10),
              Text(
                problemText,
                style: const TextStyle(
                  color: _Palette.titleBlack,
                  fontSize: 22,
                  fontStyle: FontStyle.italic,
                  fontFamily: 'cursive',
                ),
              ),
              const SizedBox(height: 16),
              const Divider(color: _Palette.divider),
              const SizedBox(height: 16),
              const Text('SOLUTION', style: _labelStyle),
              const SizedBox(height: 12),
              const _MatrixEquationPreview(),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _Palette.cardBackground,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _Palette.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('OCR TRANSCRIPTION (LATEX)', style: _labelStyle),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _Palette.inputFill,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _Palette.cardBorder),
                ),
                child: Text(
                  ocrLatex,
                  style: const TextStyle(
                    color: _Palette.bodyText,
                    fontSize: 13.5,
                    fontFamily: 'monospace',
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A lightweight visual stand-in for the student's handwritten matrix
/// equation (normally rendered from an uploaded solution image).
class _MatrixEquationPreview extends StatelessWidget {
  const _MatrixEquationPreview();

  static const TextStyle _bracket = TextStyle(
    fontSize: 64,
    fontWeight: FontWeight.w300,
    color: _Palette.titleBlack,
    height: 1,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text('[', style: _bracket),
          const SizedBox(width: 36),
          const Text(']', style: _bracket),
          const SizedBox(width: 12),
          const Text('[', style: _bracket),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text(
                'x1',
                style: TextStyle(color: _Palette.mutedText, fontSize: 14),
              ),
              SizedBox(height: 18),
              Text(
                'x2',
                style: TextStyle(color: _Palette.mutedText, fontSize: 14),
              ),
            ],
          ),
          const Text(']', style: _bracket),
          const SizedBox(width: 20),
          const Text(
            '=',
            style: TextStyle(
              fontSize: 28,
              color: _Palette.titleBlack,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(width: 20),
          const Text('[', style: _bracket),
          const SizedBox(width: 36),
          const Text(']', style: _bracket),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Right panel: conflicting labels + final label selection
// ---------------------------------------------------------------------------

class _ConflictResolutionPanel extends StatelessWidget {
  const _ConflictResolutionPanel({
    required this.annotator1Label,
    required this.annotator1Note,
    required this.annotator2Label,
    required this.annotator2Note,
    required this.selectedLabel,
    required this.onLabelSelected,
    required this.rationaleController,
    required this.onConfirm,
    required this.onNext,
  });

  final String annotator1Label;
  final String annotator1Note;
  final String annotator2Label;
  final String annotator2Note;
  final String? selectedLabel;
  final ValueChanged<String> onLabelSelected;
  final TextEditingController rationaleController;
  final VoidCallback? onConfirm;
  final VoidCallback onNext;

  static const List<String> _labelOptions = [
    'Conceptual',
    'Procedural',
    'Notation',
    'No error',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Conflicting labels',
          style: TextStyle(
            color: _Palette.titleBlack,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _AnnotatorLabelCard(
                title: 'ANNOTATOR 1',
                label: annotator1Label,
                note: annotator1Note,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _AnnotatorLabelCard(
                title: 'ANNOTATOR 2',
                label: annotator2Label,
                note: annotator2Note,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Text(
          'Final gold-standard label',
          style: TextStyle(
            color: _Palette.titleBlack,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final option in _labelOptions)
              SizedBox(
                width: 190,
                child: _LabelRadioTile(
                  label: option,
                  selected: selectedLabel == option,
                  onTap: () => onLabelSelected(option),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        const Text(
          'Adjudication rationale (optional)',
          style: TextStyle(
            color: _Palette.titleBlack,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: _Palette.inputFill,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _Palette.cardBorder),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: TextField(
            controller: rationaleController,
            maxLines: 3,
            style: const TextStyle(fontSize: 14),
            decoration: const InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              hintText: 'Why this label was chosen...',
              hintStyle: TextStyle(color: _Palette.mutedText),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            ElevatedButton(
              onPressed: onConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: _Palette.divider,
                foregroundColor: _Palette.mutedText,
                disabledBackgroundColor: _Palette.divider,
                disabledForegroundColor: _Palette.mutedText,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Confirm final label',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: onNext,
              style: OutlinedButton.styleFrom(
                foregroundColor: _Palette.titleBlack,
                side: const BorderSide(color: _Palette.cardBorder),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Next',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AnnotatorLabelCard extends StatelessWidget {
  const _AnnotatorLabelCard({
    required this.title,
    required this.label,
    required this.note,
  });

  final String title;
  final String label;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _Palette.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _Palette.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _Palette.mutedText,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: _Palette.titleBlack,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              note,
              style: const TextStyle(color: _Palette.mutedText, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

class _LabelRadioTile extends StatelessWidget {
  const _LabelRadioTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: _Palette.cardBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? _Palette.accentGreen : _Palette.cardBorder,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              size: 18,
              color: selected ? _Palette.accentGreen : _Palette.mutedText,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: _Palette.titleBlack,
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}