import 'package:flutter/material.dart';

import '../../../core/widgets/header_banner.dart';

/// 'Evaluation' screen — shows locked run metrics, per-class performance,
/// the confusion matrix, category frequency, classifier variant
/// comparison, and the regression-slice baseline for a completed run.
class EvaluationScreen extends StatefulWidget {
  const EvaluationScreen({super.key});

  @override
  State<EvaluationScreen> createState() => _EvaluationScreenState();
}

class _EvaluationScreenState extends State<EvaluationScreen> {
  bool _variantComparisonExpanded = true;

  // TODO: replace with real data from the evaluation repository/provider.
  static const String _runId = 'R-014';
  static const String _pinnedVersions = 'ocr-v1, clf-v1';
  static const String _metricsLockedDate = '14 Oct';

  static const double _accuracy = 0.805;
  static const String _accuracyCi = 'Wilson 95% CI [72.4–86.6%]';
  static const double _macroF1 = 0.80;
  static const double _weightedF1 = 0.81;
  static const double _cohensKappa = 0.70;

  static const List<_ClassMetric> _classMetrics = [
    _ClassMetric(
      category: 'Conceptual',
      precision: 0.87,
      recall: 0.82,
      f1: 0.85,
      support: 50,
    ),
    _ClassMetric(
      category: 'Procedural',
      precision: 0.73,
      recall: 0.86,
      f1: 0.79,
      support: 42,
    ),
    _ClassMetric(
      category: 'Notation',
      precision: 0.82,
      recall: 0.69,
      f1: 0.75,
      support: 26,
      flagged: true,
    ),
  ];

  static const List<String> _confusionLabels = ['Conc.', 'Proc.', 'Notat.'];
  static const List<String> _confusionRowLabels = [
    'Conceptual',
    'Procedural',
    'Notation',
  ];
  static const List<List<int>> _confusionMatrix = [
    [41, 7, 2],
    [4, 36, 2],
    [2, 6, 18],
  ];

  static const List<_CategoryFrequency> _categoryFrequency = [
    _CategoryFrequency('Conceptual', 0.42),
    _CategoryFrequency('Procedural', 0.36),
    _CategoryFrequency('Notation', 0.22),
  ];

  static const List<_VariantResult> _variantResults = [
    _VariantResult('clf-da0', 0.712),
    _VariantResult('clf-da3', 0.756),
    _VariantResult('clf-v1', 0.784),
    _VariantResult('clf-da20', 0.779),
  ];

  static const double _regressionSliceAccuracy = 0.768;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Palette.background,
      body: SafeArea(
        child: Column(
          children: [
            const ProvaHeaderBanner(
              pageTitle: 'Evaluation',
              stage: PipelineStage.evaluate,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _EvaluationHeader(
                      runId: _runId,
                      pinnedVersions: _pinnedVersions,
                      metricsLockedDate: _metricsLockedDate,
                      onExport: () {
                        // TODO: export the evaluation report.
                      },
                    ),
                    const SizedBox(height: 20),
                    _TopMetricsRow(
                      accuracy: _accuracy,
                      accuracyCi: _accuracyCi,
                      macroF1: _macroF1,
                      weightedF1: _weightedF1,
                      cohensKappa: _cohensKappa,
                    ),
                    const SizedBox(height: 20),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final bool wide = constraints.maxWidth > 900;
                        final perClass = _PerClassMetricsCard(
                          metrics: _classMetrics,
                        );
                        final confusion = _ConfusionMatrixCard(
                          columnLabels: _confusionLabels,
                          rowLabels: _confusionRowLabels,
                          matrix: _confusionMatrix,
                        );
                        if (wide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: perClass),
                              const SizedBox(width: 20),
                              Expanded(child: confusion),
                            ],
                          );
                        }
                        return Column(
                          children: [
                            perClass,
                            const SizedBox(height: 20),
                            confusion,
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    _CategoryFrequencyCard(frequencies: _categoryFrequency),
                    const SizedBox(height: 20),
                    _VariantComparisonCard(
                      expanded: _variantComparisonExpanded,
                      onToggle: () => setState(
                        () => _variantComparisonExpanded =
                            !_variantComparisonExpanded,
                      ),
                      results: _variantResults,
                    ),
                    const SizedBox(height: 20),
                    _RegressionSliceCard(accuracy: _regressionSliceAccuracy),
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
  static const Color accentGreenMid = Color(0xFFBFE0D1);
  static const Color titleBlack = Color(0xFF1B1E22);
  static const Color bodyText = Color(0xFF2B2E33);
  static const Color mutedText = Color(0xFF8A8F98);
  static const Color divider = Color(0xFFEDEEF0);
  static const Color flagAmber = Color(0xFFC98A1B);
  static const Color flagAmberBg = Color(0xFFFBF3E4);
}

TextStyle _monoNumber({double size = 15, FontWeight weight = FontWeight.w600}) {
  return TextStyle(
    fontFamily: 'monospace',
    fontSize: size,
    fontWeight: weight,
    color: _Palette.bodyText,
  );
}

// ---------------------------------------------------------------------------
// Header: title, run metadata, export button
// ---------------------------------------------------------------------------

class _EvaluationHeader extends StatelessWidget {
  const _EvaluationHeader({
    required this.runId,
    required this.pinnedVersions,
    required this.metricsLockedDate,
    required this.onExport,
  });

  final String runId;
  final String pinnedVersions;
  final String metricsLockedDate;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Evaluation',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: _Palette.titleBlack,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Run $runId · pinned versions $pinnedVersions · '
                'metrics locked $metricsLockedDate',
                style: const TextStyle(
                  color: _Palette.mutedText,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        ElevatedButton(
          onPressed: onExport,
          style: ElevatedButton.styleFrom(
            backgroundColor: _Palette.accentGreen,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            'Export report',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Top metrics row
// ---------------------------------------------------------------------------

class _TopMetricsRow extends StatelessWidget {
  const _TopMetricsRow({
    required this.accuracy,
    required this.accuracyCi,
    required this.macroF1,
    required this.weightedF1,
    required this.cohensKappa,
  });

  final double accuracy;
  final String accuracyCi;
  final double macroF1;
  final double weightedF1;
  final double cohensKappa;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            title: 'ACCURACY',
            value: '${(accuracy * 100).toStringAsFixed(1)}%',
            footer: _Pill(text: accuracyCi),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _MetricCard(
            title: 'MACRO-F1',
            value: macroF1.toStringAsFixed(2),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _MetricCard(
            title: 'WEIGHTED-F1',
            value: weightedF1.toStringAsFixed(2),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _MetricCard(
            title: "COHEN'S KAPPA",
            value: cohensKappa.toStringAsFixed(2),
            footerText: 'computed on original annotator labels, '
                'before adjudication',
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    this.footer,
    this.footerText,
  });

  final String title;
  final String value;
  final Widget? footer;
  final String? footerText;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
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
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(value, style: _monoNumber(size: 26, weight: FontWeight.w700)),
          if (footer != null) ...[const SizedBox(height: 10), footer!],
          if (footerText != null) ...[
            const SizedBox(height: 10),
            Text(
              footerText!,
              style: const TextStyle(
                color: _Palette.mutedText,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _Palette.accentGreenSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: _Palette.accentGreen,
          fontWeight: FontWeight.w600,
          fontSize: 12,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Per-class metrics table
// ---------------------------------------------------------------------------

class _ClassMetric {
  const _ClassMetric({
    required this.category,
    required this.precision,
    required this.recall,
    required this.f1,
    required this.support,
    this.flagged = false,
  });

  final String category;
  final double precision;
  final double recall;
  final double f1;
  final int support;
  final bool flagged;
}

class _PerClassMetricsCard extends StatelessWidget {
  const _PerClassMetricsCard({required this.metrics});

  final List<_ClassMetric> metrics;

  static const TextStyle _headerStyle = TextStyle(
    color: _Palette.mutedText,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.4,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      decoration: BoxDecoration(
        color: _Palette.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _Palette.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Per-Class Metrics',
            style: TextStyle(
              color: _Palette.titleBlack,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text('CATEGORY', style: _headerStyle)),
                Expanded(
                  flex: 2,
                  child: Text(
                    'PRECISION',
                    textAlign: TextAlign.right,
                    style: _headerStyle,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'RECALL',
                    textAlign: TextAlign.right,
                    style: _headerStyle,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'F1',
                    textAlign: TextAlign.right,
                    style: _headerStyle,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'SUPPORT',
                    textAlign: TextAlign.right,
                    style: _headerStyle,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _Palette.divider),
          for (final m in metrics) _ClassMetricRow(metric: m),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ClassMetricRow extends StatelessWidget {
  const _ClassMetricRow({required this.metric});

  final _ClassMetric metric;

  @override
  Widget build(BuildContext context) {
    final f1Style = _monoNumber(
      weight: FontWeight.w700,
    ).copyWith(color: metric.flagged ? _Palette.flagAmber : _Palette.bodyText);

    return Container(
      decoration: BoxDecoration(
        color: metric.flagged ? _Palette.flagAmberBg : Colors.transparent,
        border: metric.flagged
            ? const Border(
                left: BorderSide(color: _Palette.flagAmber, width: 3),
              )
            : null,
      ),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      margin: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Padding(
              padding: EdgeInsets.only(left: metric.flagged ? 10 : 0),
              child: Text(
                metric.category,
                style: const TextStyle(
                  color: _Palette.titleBlack,
                  fontWeight: FontWeight.w600,
                  fontSize: 14.5,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              metric.precision.toStringAsFixed(2),
              textAlign: TextAlign.right,
              style: _monoNumber(),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              metric.recall.toStringAsFixed(2),
              textAlign: TextAlign.right,
              style: _monoNumber(),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              metric.f1.toStringAsFixed(2),
              textAlign: TextAlign.right,
              style: f1Style,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${metric.support}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: _Palette.mutedText,
                fontSize: 14.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Confusion matrix
// ---------------------------------------------------------------------------

class _ConfusionMatrixCard extends StatelessWidget {
  const _ConfusionMatrixCard({
    required this.columnLabels,
    required this.rowLabels,
    required this.matrix,
  });

  final List<String> columnLabels;
  final List<String> rowLabels;
  final List<List<int>> matrix;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _Palette.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _Palette.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Confusion Matrix — Predicted vs. True',
            style: TextStyle(
              color: _Palette.titleBlack,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const SizedBox(
                width: 90,
                child: Text(
                  'TRUE \\ PRED',
                  style: TextStyle(
                    color: _Palette.mutedText,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              for (final label in columnLabels)
                Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: _Palette.mutedText,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          for (int r = 0; r < rowLabels.length; r++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 90,
                  child: Text(
                    rowLabels[r],
                    style: const TextStyle(
                      color: _Palette.titleBlack,
                      fontWeight: FontWeight.w600,
                      fontSize: 14.5,
                    ),
                  ),
                ),
                for (int c = 0; c < columnLabels.length; c++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: _ConfusionCell(
                        value: matrix[r][c],
                        isDiagonal: r == c,
                      ),
                    ),
                  ),
              ],
            ),
            if (r != rowLabels.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _ConfusionCell extends StatelessWidget {
  const _ConfusionCell({required this.value, required this.isDiagonal});

  final int value;
  final bool isDiagonal;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isDiagonal ? _Palette.accentGreen : _Palette.accentGreenSoft,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$value',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: isDiagonal ? Colors.white : _Palette.bodyText,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Category frequency summary
// ---------------------------------------------------------------------------

class _CategoryFrequency {
  const _CategoryFrequency(this.category, this.fraction);

  final String category;
  final double fraction;
}

class _CategoryFrequencyCard extends StatelessWidget {
  const _CategoryFrequencyCard({required this.frequencies});

  final List<_CategoryFrequency> frequencies;

  @override
  Widget build(BuildContext context) {
    return Container(
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
          const Text(
            'Category Frequency Summary',
            style: TextStyle(
              color: _Palette.titleBlack,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          for (int i = 0; i < frequencies.length; i++) ...[
            _CategoryFrequencyRow(frequency: frequencies[i]),
            if (i != frequencies.length - 1) const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

class _CategoryFrequencyRow extends StatelessWidget {
  const _CategoryFrequencyRow({required this.frequency});

  final _CategoryFrequency frequency;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            frequency.category,
            style: const TextStyle(
              color: _Palette.titleBlack,
              fontWeight: FontWeight.w600,
              fontSize: 14.5,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 20,
              child: LinearProgressIndicator(
                value: frequency.fraction,
                backgroundColor: _Palette.divider,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  _Palette.accentGreen,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        SizedBox(
          width: 44,
          child: Text(
            '${(frequency.fraction * 100).round()}%',
            textAlign: TextAlign.right,
            style: const TextStyle(color: _Palette.mutedText, fontSize: 14),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Variant comparison (collapsible)
// ---------------------------------------------------------------------------

class _VariantResult {
  const _VariantResult(this.variant, this.accuracy);

  final String variant;
  final double accuracy;
}

class _VariantComparisonCard extends StatelessWidget {
  const _VariantComparisonCard({
    required this.expanded,
    required this.onToggle,
    required this.results,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final List<_VariantResult> results;

  @override
  Widget build(BuildContext context) {
    return Container(
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
          InkWell(
            onTap: onToggle,
            child: Row(
              children: [
                Icon(
                  expanded ? Icons.arrow_drop_down : Icons.arrow_right,
                  color: _Palette.titleBlack,
                ),
                const SizedBox(width: 4),
                const Text(
                  'Variant comparison',
                  style: TextStyle(
                    color: _Palette.titleBlack,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (expanded) ...[
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'CLASSIFIER VARIANT',
                      style: TextStyle(
                        color: _Palette.mutedText,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  Text(
                    'HELD-OUT CORPUS ACCURACY',
                    style: TextStyle(
                      color: _Palette.mutedText,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: _Palette.divider),
            for (final r in results)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        r.variant,
                        style: const TextStyle(
                          color: _Palette.bodyText,
                          fontSize: 14.5,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    Text(
                      '${(r.accuracy * 100).toStringAsFixed(1)}%',
                      style: _monoNumber(),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            const Text(
              'Selection was made on constructed corpus data only.',
              style: TextStyle(color: _Palette.mutedText, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Regression slice
// ---------------------------------------------------------------------------

class _RegressionSliceCard extends StatelessWidget {
  const _RegressionSliceCard({required this.accuracy});

  final double accuracy;

  @override
  Widget build(BuildContext context) {
    return Container(
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
          const Text(
            'Regression slice',
            style: TextStyle(
              color: _Palette.titleBlack,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${(accuracy * 100).toStringAsFixed(1)}%',
            style: _monoNumber(size: 28, weight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          const Text(
            'Baseline for future version comparison. Not included in the '
            'reported figures above.',
            style: TextStyle(color: _Palette.mutedText, fontSize: 13.5),
          ),
        ],
      ),
    );
  }
}