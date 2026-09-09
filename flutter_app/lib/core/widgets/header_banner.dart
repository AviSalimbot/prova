import 'package:flutter/material.dart';

/// The five stages of the PROVA pipeline, in order.
/// Pages that don't belong to the pipeline (Assessments, Labels, Item Detail,
/// Runs, Models, Admin) should pass [PipelineStage.notApplicable] — this
/// renders the whole tracker in a neutral gray with no highlighted step.
enum PipelineStage { configure, monitor, annotate, adjudicate, evaluate, notApplicable }

class _StageDef {
  final PipelineStage stage;
  final String label;
  const _StageDef(this.stage, this.label);
}

const List<_StageDef> _pipeline = [
  _StageDef(PipelineStage.configure, 'Configure'),
  _StageDef(PipelineStage.monitor, 'Monitor'),
  _StageDef(PipelineStage.annotate, 'Annotate'),
  _StageDef(PipelineStage.adjudicate, 'Adjudicate'),
  _StageDef(PipelineStage.evaluate, 'Evaluate'),
];

/// Centralized palette so the banner's look stays consistent everywhere
/// it's used. Tweak these to match your exact brand hex values.
class ProvaColors {
  ProvaColors._();

  static const green = Color(0xFF2E7D4F);
  static const greenPillBg = Color(0xFFE6F2E9);
  static const gray = Color(0xFFA0A6AC);
  static const grayLine = Color(0xFFDCE0E3);
  static const dividerGray = Color(0xFFE4E7E9);
  static const titleBlack = Color(0xFF1B1F22);
  static const subtitleGray = Color(0xFF8A9096);
}

/// The universal PROVA page header: title row, thick green rule, pipeline
/// stepper, thin gray rule. Drop it at the top of any page's body (it is
/// NOT an AppBar — it's meant to sit inside the Scaffold body so it can
/// live above tab bars, filters, etc. the same way it does in the mockups).
///
/// Usage:
/// ```dart
/// Scaffold(
///   body: Column(
///     children: [
///       ProvaHeaderBanner(pageTitle: 'Dashboard', stage: PipelineStage.monitor),
///       Expanded(child: ...page content...),
///     ],
///   ),
/// )
/// ```
class ProvaHeaderBanner extends StatelessWidget {
  const ProvaHeaderBanner({
    super.key,
    required this.pageTitle,
    this.stage = PipelineStage.notApplicable,
  });

  /// Shown as "PROVA — {pageTitle}".
  final String pageTitle;

  /// Which pipeline step (if any) this page represents.
  final PipelineStage stage;

  /// Horizontal inset applied to the title and stepper text. The two rule
  /// lines deliberately sit OUTSIDE this padding so they run full-bleed
  /// edge-to-edge across the page, matching the mockups.
  static const double _sideInset = 24;

  /// Fixed row heights. Kept as explicit heights (rather than derived from
  /// font size + padding) so that tweaking font sizes later never shifts
  /// the banner's overall height.
  static const double _titleRowHeight = 56;
  static const double _stepperRowHeight = 44;

  @override
  Widget build(BuildContext context) {
    final currentIndex = _pipeline.indexWhere((s) => s.stage == stage);

    return Container(
      width: double.infinity,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: _titleRowHeight,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: _sideInset),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: ProvaColors.titleBlack,
                ),
                children: [
                  const TextSpan(text: 'PROVA'),
                  TextSpan(text: ' — $pageTitle'),
                ],
              ),
            ),
          ),
          // Thick green divider — full bleed, no side padding.
          Container(height: 3, width: double.infinity, color: ProvaColors.green),
          Container(
            height: _stepperRowHeight,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: _sideInset),
            child: _PipelineStepper(currentIndex: currentIndex),
          ),
          // Thin gray divider — full bleed, no side padding.
          Container(height: 1, width: double.infinity, color: ProvaColors.dividerGray),
        ],
      ),
    );
  }
}

enum _StepStatus { na, completed, current, upcoming }

class _PipelineStepper extends StatelessWidget {
  const _PipelineStepper({required this.currentIndex});

  /// -1 means N/A (no pipeline step applies to this page).
  final int currentIndex;

  _StepStatus _statusFor(int index) {
    if (currentIndex < 0) return _StepStatus.na;
    if (index == currentIndex) return _StepStatus.current;
    if (index < currentIndex) return _StepStatus.completed;
    return _StepStatus.upcoming;
  }

  bool _lineCompletedAfter(int index) {
    if (currentIndex < 0) return false;
    return index < currentIndex;
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < _pipeline.length; i++) {
      children.add(_StepItem(label: _pipeline[i].label, status: _statusFor(i)));
      if (i != _pipeline.length - 1) {
        children.add(_StepLine(completed: _lineCompletedAfter(i)));
      }
    }
    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }
}

class _StepItem extends StatelessWidget {
  const _StepItem({required this.label, required this.status});

  final String label;
  final _StepStatus status;

  @override
  Widget build(BuildContext context) {
    late final Color dotColor;
    late final Color textColor;
    var weight = FontWeight.w500;

    switch (status) {
      case _StepStatus.na:
        dotColor = ProvaColors.gray;
        textColor = ProvaColors.gray;
        break;
      case _StepStatus.completed:
        // "Left side" of the current step: green dot, black text.
        dotColor = ProvaColors.green;
        textColor = ProvaColors.titleBlack;
        break;
      case _StepStatus.current:
        dotColor = ProvaColors.green;
        textColor = ProvaColors.green;
        weight = FontWeight.w700;
        break;
      case _StepStatus.upcoming:
        // "Right side" of the current step: gray dot, gray text.
        dotColor = ProvaColors.gray;
        textColor = ProvaColors.gray;
        break;
    }

    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: textColor, fontWeight: weight, fontSize: 12)),
      ],
    );

    // Same padding for every status — only the current step gets a
    // background + corner radius. This way highlighting a step never
    // shifts the layout or pushes the other steps further apart.
    // The current step gets a touch more padding than the others so the
    // highlight box reads with a bit of breathing room around the text.
    // The connecting lines' margin is pulled in slightly to offset the
    // extra width/height this box now takes, so the stepper's overall
    // footprint (and the fixed _stepperRowHeight it sits inside) doesn't
    // grow or need to shrink to compensate.
    final padding = status == _StepStatus.current
        ? const EdgeInsets.symmetric(horizontal: 8, vertical: 8)
        : const EdgeInsets.symmetric(horizontal: 6, vertical: 5);

    return Container(
      padding: padding,
      decoration: status == _StepStatus.current
          ? BoxDecoration(
              color: ProvaColors.greenPillBg,
              borderRadius: BorderRadius.circular(6),
            )
          : null,
      child: row,
    );
  }
}

class _StepLine extends StatelessWidget {
  const _StepLine({required this.completed});

  // Kept for API compatibility with _PipelineStepper, but the line no
  // longer changes color based on progress — only the dots and labels do.
  // ignore: unused_field
  final bool completed;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      width: 20,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: ProvaColors.grayLine,
    );
  }
}