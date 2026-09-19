import 'package:flutter/material.dart';

import '../../../core/widgets/header_banner.dart';

/// 'Dashboard' screen — live monitor for a batch classification run.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  static const _borderColor = Color(0xFFE2E5E1);
  static const _mutedText = Color(0xFF6B7370);
  static const _green = Color(0xFF3E7A55);
  static const _greenLight = Color(0xFFEAF4EC);
  static const _pageBg = Color(0xFFF5F6F5);
  static const _flagRed = Color(0xFFB3492E);

  // Placeholder data — replace once the domain/data layers exist.
  static const _runName = 'run_2026_sem1_batch01';
  static const _startedLabel = 'Started 15 Jul 2026, 10:12 AM';
  static const _updatedLabel = 'Last updated 10:41 AM';
  static const _runId = 'R-015';
  static const _pinnedVersions = 'ocr-v1, clf-v1';

  static const _status = 'Complete';
  static const _processedDone = 728;
  static const _processedTotal = 728;
  static const _flagged = 68;
  static const _meanConfidence = '84%';
  static const _pipelinePercent = '100%';
  static const _elapsed = '29 min elapsed';

  static const _categoryFrequency = [
    _CategoryBar(label: 'Conceptual', count: 362, max: 728),
    _CategoryBar(label: 'Procedural', count: 291, max: 728),
    _CategoryBar(label: 'Notation', count: 191, max: 728),
  ];

  static const _confusionLabels = ['Conceptual', 'Procedural', 'Notation'];
  static const _confusionMatrix = [
    [77, 15, 4],
    [12, 76, 10],
    [2, 8, 48],
  ];

  static const _activityLog = [
    _LogEntry('10:38', 'OCR', 'P084 item 1 — transcribed OK'),
    _LogEntry('10:39', 'SYSTEM', 'checkpoint persisted (676/728)'),
    _LogEntry('10:39', 'OCR', 'P086 item 5 — transcribed OK'),
    _LogEntry('10:40', 'OCR', 'P087 item 6 — transcribed OK'),
    _LogEntry('10:40', 'OCR', 'P089 item 2 — transcribed OK'),
    _LogEntry('10:41', 'OCR', 'P090 item 6 — low OCR confidence, flagged for review',
        flagged: true),
    _LogEntry('10:41', 'OCR', 'P091 item 8 — low OCR confidence, flagged for review',
        flagged: true),
    _LogEntry('10:41', 'SYSTEM', 'run complete — 728 items processed'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      body: SafeArea(
        child: Column(
          children: [
            const ProvaHeaderBanner(
              pageTitle: 'Dashboard',
              stage: PipelineStage.monitor,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _RunHeader(
                      runName: _runName,
                      startedLabel: _startedLabel,
                      updatedLabel: _updatedLabel,
                      runId: _runId,
                      pinnedVersions: _pinnedVersions,
                      borderColor: _borderColor,
                      mutedText: _mutedText,
                    ),
                    const SizedBox(height: 20),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 900;
                        final cards = [
                          _StatCard(
                            label: 'STATUS',
                            child: const Text(
                              _status,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: _green,
                              ),
                            ),
                          ),
                          _StatCard(
                            label: 'PROCESSED',
                            child: Text.rich(
                              TextSpan(
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                                children: [
                                  const TextSpan(text: '$_processedDone'),
                                  const TextSpan(
                                    text: '  /  ',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w400,
                                        color: _mutedText),
                                  ),
                                  const TextSpan(text: '$_processedTotal'),
                                ],
                              ),
                            ),
                          ),
                          _StatCard(
                            label: 'FLAGGED (LOW CONFIDENCE)',
                            child: const Text(
                              '$_flagged',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: _flagRed,
                              ),
                            ),
                          ),
                          _StatCard(
                            label: 'MEAN OCR CONFIDENCE',
                            child: const Text(
                              _meanConfidence,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ];
                        if (isWide) {
                          return Row(
                            children: [
                              for (var i = 0; i < cards.length; i++) ...[
                                if (i != 0) const SizedBox(width: 16),
                                Expanded(child: cards[i]),
                              ],
                            ],
                          );
                        }
                        return Column(
                          children: [
                            for (var i = 0; i < cards.length; i++) ...[
                              if (i != 0) const SizedBox(height: 16),
                              cards[i],
                            ],
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    _PipelineProgressCard(
                      percentLabel: _pipelinePercent,
                      elapsedLabel: _elapsed,
                      progress: 1.0,
                      borderColor: _borderColor,
                      mutedText: _mutedText,
                      green: _green,
                    ),
                    const SizedBox(height: 20),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 900;
                        final freqCard = _PredictedCategoryFrequencyCard(
                          bars: _categoryFrequency,
                          borderColor: _borderColor,
                          green: _green,
                        );
                        final confusionCard = _ConfusionMatrixCard(
                          labels: _confusionLabels,
                          matrix: _confusionMatrix,
                          borderColor: _borderColor,
                          green: _green,
                          greenLight: _greenLight,
                          mutedText: _mutedText,
                        );
                        if (isWide) {
                          return IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(child: freqCard),
                                const SizedBox(width: 20),
                                Expanded(child: confusionCard),
                              ],
                            ),
                          );
                        }
                        return Column(
                          children: [
                            freqCard,
                            const SizedBox(height: 20),
                            confusionCard,
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    _ActivityLogCard(
                      entries: _activityLog,
                      borderColor: _borderColor,
                      mutedText: _mutedText,
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

class _RunHeader extends StatelessWidget {
  const _RunHeader({
    required this.runName,
    required this.startedLabel,
    required this.updatedLabel,
    required this.runId,
    required this.pinnedVersions,
    required this.borderColor,
    required this.mutedText,
  });

  final String runName;
  final String startedLabel;
  final String updatedLabel;
  final String runId;
  final String pinnedVersions;
  final Color borderColor;
  final Color mutedText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          runName,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            fontFamily: 'monospace',
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        Text.rich(
          TextSpan(
            style: TextStyle(fontSize: 14, color: mutedText),
            children: [
              TextSpan(text: startedLabel),
              const TextSpan(text: '  ·  '),
              TextSpan(text: updatedLabel),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F1EF),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: borderColor),
              ),
              child: Text(
                runId,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text('pinned versions',
                style: TextStyle(fontSize: 13, color: mutedText)),
            const SizedBox(width: 6),
            Text(
              pinnedVersions,
              style: const TextStyle(
                fontSize: 13,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DashboardScreen._borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: DashboardScreen._mutedText,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _PipelineProgressCard extends StatelessWidget {
  const _PipelineProgressCard({
    required this.percentLabel,
    required this.elapsedLabel,
    required this.progress,
    required this.borderColor,
    required this.mutedText,
    required this.green,
  });

  final String percentLabel;
  final String elapsedLabel;
  final double progress;
  final Color borderColor;
  final Color mutedText;
  final Color green;

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Pipeline progress',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              Text.rich(
                TextSpan(
                  style: TextStyle(fontSize: 13, color: mutedText),
                  children: [
                    TextSpan(
                      text: percentLabel,
                      style: const TextStyle(
                          color: Colors.black87, fontWeight: FontWeight.w600),
                    ),
                    const TextSpan(text: '  ·  '),
                    TextSpan(text: elapsedLabel),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: const Color(0xFFE7E9E6),
              valueColor: AlwaysStoppedAnimation(green),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryBar {
  const _CategoryBar({
    required this.label,
    required this.count,
    required this.max,
  });
  final String label;
  final int count;
  final int max;
}

class _PredictedCategoryFrequencyCard extends StatelessWidget {
  const _PredictedCategoryFrequencyCard({
    required this.bars,
    required this.borderColor,
    required this.green,
  });

  final List<_CategoryBar> bars;
  final Color borderColor;
  final Color green;

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
          const Text(
            'Predicted Category Frequency',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 24),
          for (var i = 0; i < bars.length; i++) ...[
            if (i != 0) const SizedBox(height: 20),
            Row(
              children: [
                SizedBox(
                  width: 90,
                  child: Text(bars[i].label,
                      style: const TextStyle(fontSize: 14)),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: bars[i].count / bars[i].max,
                      minHeight: 22,
                      backgroundColor: const Color(0xFFEFF1EE),
                      valueColor: AlwaysStoppedAnimation(green),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 40,
                  child: Text(
                    '${bars[i].count}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ConfusionMatrixCard extends StatelessWidget {
  const _ConfusionMatrixCard({
    required this.labels,
    required this.matrix,
    required this.borderColor,
    required this.green,
    required this.greenLight,
    required this.mutedText,
  });

  final List<String> labels;
  final List<List<int>> matrix;
  final Color borderColor;
  final Color green;
  final Color greenLight;
  final Color mutedText;

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
          const Text(
            'Confusion Matrix — Predicted vs. True',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const SizedBox(width: 90),
              for (final label in labels)
                Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: mutedText),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          for (var r = 0; r < matrix.length; r++) ...[
            if (r != 0) const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(
                  width: 90,
                  child: Text(
                    labels[r],
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                for (var c = 0; c < matrix[r].length; c++) ...[
                  if (c != 0) const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: r == c ? green : const Color(0xFFEFF1EE),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${matrix[r][c]}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: r == c ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _LogEntry {
  const _LogEntry(this.time, this.tag, this.message, {this.flagged = false});
  final String time;
  final String tag;
  final String message;
  final bool flagged;
}

class _ActivityLogCard extends StatelessWidget {
  const _ActivityLogCard({
    required this.entries,
    required this.borderColor,
    required this.mutedText,
  });

  final List<_LogEntry> entries;
  final Color borderColor;
  final Color mutedText;

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
          const Text(
            'Activity Log',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Container(
            constraints: const BoxConstraints(maxHeight: 260),
            decoration: BoxDecoration(
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Scrollbar(
              thumbVisibility: true,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final e = entries[index];
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: e.flagged
                          ? const Color(0xFFFBF1E4)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text.rich(
                      TextSpan(
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'monospace',
                          color: e.flagged
                              ? const Color(0xFF8A5A17)
                              : Colors.black87,
                        ),
                        children: [
                          TextSpan(
                            text: '[${e.time}] ',
                            style: TextStyle(color: mutedText),
                          ),
                          TextSpan(
                            text: '[${e.tag}] ',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(text: e.message),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}