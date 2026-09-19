import 'package:flutter/material.dart';

import '../../../core/widgets/header_banner.dart';

/// 'Annotation' screen — lets an annotator assign a gold-standard
/// cognitive-error label to a de-identified student item.
class AnnotationScreen extends StatefulWidget {
  const AnnotationScreen({super.key});

  @override
  State<AnnotationScreen> createState() => _AnnotationScreenState();
}

enum _GoldLabel { conceptual, procedural, notation, noError }

class _AnnotationScreenState extends State<AnnotationScreen> {
  static const _borderColor = Color(0xFFE2E5E1);
  static const _mutedText = Color(0xFF6B7370);
  static const _green = Color(0xFF3E7A55);
  static const _greenLight = Color(0xFFEAF4EC);
  static const _pageBg = Color(0xFFF5F6F5);
  static const _panelBg = Color(0xFFFAFAF7);

  final _notesController = TextEditingController();

  // Placeholder data — replace once the domain/data layers exist.
  String _studentCode = 'P042';
  int _itemNumber = 8;
  final int _annotatorIndex = 1;
  final int _annotatorTotal = 2;
  final int _labeledCount = 342;
  final int _labeledTotal = 960;

  static const _problemText = 'Solve the system using Gauss-Jordan elimination.';
  static const _ocrLatex =
      '\\begin{bmatrix}2 & 3 & | & 12\\\\1 & -1 & | & 1\\end{bmatrix}'
      '\\Rightarrow x=3,\\;y=2';

  _GoldLabel? _selectedLabel;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  double get _progress => _labeledTotal == 0 ? 0 : _labeledCount / _labeledTotal;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      body: SafeArea(
        child: Column(
          children: [
            const ProvaHeaderBanner(
              pageTitle: 'Annotation',
              stage: PipelineStage.annotate,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _NavigatorBar(
                      studentCode: _studentCode,
                      itemNumber: _itemNumber,
                      annotatorIndex: _annotatorIndex,
                      annotatorTotal: _annotatorTotal,
                      labeledCount: _labeledCount,
                      labeledTotal: _labeledTotal,
                      progress: _progress,
                      onPrevStudent: () {},
                      onNextStudent: () {},
                      onPrevItem: () {
                        setState(() {
                          if (_itemNumber > 1) _itemNumber--;
                        });
                      },
                      onNextItem: () {
                        setState(() => _itemNumber++);
                      },
                      borderColor: _borderColor,
                      mutedText: _mutedText,
                      green: _green,
                      greenLight: _greenLight,
                    ),
                    const SizedBox(height: 20),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 1000;
                        final problemCard = _ProblemSolutionCard(
                          studentCode: _studentCode,
                          itemNumber: _itemNumber,
                          problemText: _problemText,
                          borderColor: _borderColor,
                          mutedText: _mutedText,
                        );
                        final sidePanel = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _OcrTranscriptionCard(
                              latex: _ocrLatex,
                              borderColor: _borderColor,
                              mutedText: _mutedText,
                              panelBg: _panelBg,
                            ),
                            const SizedBox(height: 24),
                            _GoldLabelSection(
                              selected: _selectedLabel,
                              onChanged: (v) =>
                                  setState(() => _selectedLabel = v),
                              borderColor: _borderColor,
                              green: _green,
                              greenLight: _greenLight,
                            ),
                            const SizedBox(height: 24),
                            _NotesField(
                              controller: _notesController,
                              borderColor: _borderColor,
                            ),
                            const SizedBox(height: 20),
                            _ActionButtons(
                              enabled: _selectedLabel != null,
                              green: _green,
                              onSave: () {
                                // TODO: wire up to save-label use case.
                              },
                              onSkip: () {
                                setState(() {
                                  _itemNumber++;
                                  _selectedLabel = null;
                                  _notesController.clear();
                                });
                              },
                            ),
                          ],
                        );

                        if (isWide) {
                          return IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(flex: 6, child: problemCard),
                                const SizedBox(width: 20),
                                Expanded(flex: 5, child: sidePanel),
                              ],
                            ),
                          );
                        }
                        return Column(
                          children: [
                            problemCard,
                            const SizedBox(height: 20),
                            sidePanel,
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

class _NavigatorBar extends StatelessWidget {
  const _NavigatorBar({
    required this.studentCode,
    required this.itemNumber,
    required this.annotatorIndex,
    required this.annotatorTotal,
    required this.labeledCount,
    required this.labeledTotal,
    required this.progress,
    required this.onPrevStudent,
    required this.onNextStudent,
    required this.onPrevItem,
    required this.onNextItem,
    required this.borderColor,
    required this.mutedText,
    required this.green,
    required this.greenLight,
  });

  final String studentCode;
  final int itemNumber;
  final int annotatorIndex;
  final int annotatorTotal;
  final int labeledCount;
  final int labeledTotal;
  final double progress;
  final VoidCallback onPrevStudent;
  final VoidCallback onNextStudent;
  final VoidCallback onPrevItem;
  final VoidCallback onNextItem;
  final Color borderColor;
  final Color mutedText;
  final Color green;
  final Color greenLight;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        runSpacing: 12,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Student', style: TextStyle(fontSize: 14, color: mutedText)),
              const SizedBox(width: 12),
              _StepperField(
                value: studentCode,
                onPrev: onPrevStudent,
                onNext: onNextStudent,
                borderColor: borderColor,
              ),
              const SizedBox(width: 24),
              Text('Item', style: TextStyle(fontSize: 14, color: mutedText)),
              const SizedBox(width: 12),
              _StepperField(
                value: '$itemNumber',
                onPrev: onPrevItem,
                onNext: onNextItem,
                borderColor: borderColor,
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: greenLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Annotator $annotatorIndex of $annotatorTotal',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: green,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Text(
                '$labeledCount of $labeledTotal labeled',
                style: TextStyle(fontSize: 14, color: mutedText),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 160,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: const Color(0xFFE7E9E6),
                    valueColor: AlwaysStoppedAnimation(green),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepperField extends StatelessWidget {
  const _StepperField({
    required this.value,
    required this.onPrev,
    required this.onNext,
    required this.borderColor,
  });

  final String value;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SquareIconButton(icon: Icons.chevron_left, onTap: onPrev, borderColor: borderColor),
        Container(
          constraints: const BoxConstraints(minWidth: 56),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: borderColor),
              bottom: BorderSide(color: borderColor),
            ),
          ),
          child: Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        _SquareIconButton(icon: Icons.chevron_right, onTap: onNext, borderColor: borderColor),
      ],
    );
  }
}

class _SquareIconButton extends StatelessWidget {
  const _SquareIconButton({
    required this.icon,
    required this.onTap,
    required this.borderColor,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(border: Border.all(color: borderColor)),
        child: Icon(icon, size: 18),
      ),
    );
  }
}

class _ProblemSolutionCard extends StatelessWidget {
  const _ProblemSolutionCard({
    required this.studentCode,
    required this.itemNumber,
    required this.problemText,
    required this.borderColor,
    required this.mutedText,
  });

  final String studentCode;
  final int itemNumber;
  final String problemText;
  final Color borderColor;
  final Color mutedText;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$studentCode · ITEM $itemNumber · DE-IDENTIFIED',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: mutedText,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'PROBLEM',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: mutedText,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            problemText,
            style: const TextStyle(
              fontSize: 20,
              fontStyle: FontStyle.italic,
              fontFamily: 'cursive',
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          Divider(color: borderColor),
          const SizedBox(height: 20),
          Text(
            'SOLUTION',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: mutedText,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Center(
              child: _HandwrittenMatrixSystem(),
            ),
          ),
        ],
      ),
    );
  }
}

/// A rough visual placeholder for a scanned/handwritten matrix-equation
/// image. Swap for the actual de-identified item image once available.
class _HandwrittenMatrixSystem extends StatelessWidget {
  const _HandwrittenMatrixSystem();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontSize: 34,
      fontStyle: FontStyle.italic,
      fontFamily: 'cursive',
      color: Colors.black87,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Bracket(isLeft: true),
        const SizedBox(width: 60),
        _Bracket(isLeft: false),
        const SizedBox(width: 20),
        _Bracket(isLeft: true),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text('x1', style: style),
            SizedBox(height: 32),
            Text('x2', style: style),
          ],
        ),
        _Bracket(isLeft: false),
        const SizedBox(width: 20),
        const Text('=', style: style),
        const SizedBox(width: 20),
        _Bracket(isLeft: true),
        const SizedBox(width: 60),
        _Bracket(isLeft: false),
      ],
    );
  }
}

class _Bracket extends StatelessWidget {
  const _Bracket({required this.isLeft});
  final bool isLeft;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(18, 130),
      painter: _BracketPainter(isLeft: isLeft),
    );
  }
}

class _BracketPainter extends CustomPainter {
  _BracketPainter({required this.isLeft});
  final bool isLeft;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    final path = Path();
    final x = isLeft ? size.width : 0.0;
    final xTip = isLeft ? 0.0 : size.width;
    path.moveTo(x, 0);
    path.lineTo(xTip, 0);
    path.lineTo(xTip, size.height);
    path.lineTo(x, size.height);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BracketPainter oldDelegate) => false;
}

class _OcrTranscriptionCard extends StatelessWidget {
  const _OcrTranscriptionCard({
    required this.latex,
    required this.borderColor,
    required this.mutedText,
    required this.panelBg,
  });

  final String latex;
  final Color borderColor;
  final Color mutedText;
  final Color panelBg;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'OCR TRANSCRIPTION (LATEX)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: mutedText,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: panelBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor),
            ),
            child: Text(
              latex,
              style: const TextStyle(
                fontSize: 14,
                fontFamily: 'monospace',
                height: 1.5,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoldLabelSection extends StatelessWidget {
  const _GoldLabelSection({
    required this.selected,
    required this.onChanged,
    required this.borderColor,
    required this.green,
    required this.greenLight,
  });

  final _GoldLabel? selected;
  final ValueChanged<_GoldLabel> onChanged;
  final Color borderColor;
  final Color green;
  final Color greenLight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Gold-standard label',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _LabelOption(
                label: 'Conceptual',
                selected: selected == _GoldLabel.conceptual,
                onTap: () => onChanged(_GoldLabel.conceptual),
                borderColor: borderColor,
                green: green,
                greenLight: greenLight,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _LabelOption(
                label: 'Procedural',
                selected: selected == _GoldLabel.procedural,
                onTap: () => onChanged(_GoldLabel.procedural),
                borderColor: borderColor,
                green: green,
                greenLight: greenLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _LabelOption(
                label: 'Notation',
                selected: selected == _GoldLabel.notation,
                onTap: () => onChanged(_GoldLabel.notation),
                borderColor: borderColor,
                green: green,
                greenLight: greenLight,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _LabelOption(
                label: 'No error',
                selected: selected == _GoldLabel.noError,
                onTap: () => onChanged(_GoldLabel.noError),
                borderColor: borderColor,
                green: green,
                greenLight: greenLight,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LabelOption extends StatelessWidget {
  const _LabelOption({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.borderColor,
    required this.green,
    required this.greenLight,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color borderColor;
  final Color green;
  final Color greenLight;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: selected ? greenLight : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? green : borderColor,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Radio<bool>(
              value: true,
              groupValue: selected ? true : null,
              onChanged: (_) => onTap(),
              activeColor: green,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotesField extends StatelessWidget {
  const _NotesField({required this.controller, required this.borderColor});

  final TextEditingController controller;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Notes (optional)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Any context for this labeling decision...',
            contentPadding: const EdgeInsets.all(14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: borderColor),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.enabled,
    required this.green,
    required this.onSave,
    required this.onSkip,
  });

  final bool enabled;
  final Color green;
  final VoidCallback onSave;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ElevatedButton(
          onPressed: enabled ? onSave : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: enabled ? green : const Color(0xFFDDE3DE),
            foregroundColor: enabled ? Colors.white : const Color(0xFF9AA39C),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Save label',
              style: TextStyle(fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 12),
        OutlinedButton(
          onPressed: onSkip,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.black87,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            side: const BorderSide(color: Color(0xFFE2E5E1)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Skip'),
        ),
      ],
    );
  }
}