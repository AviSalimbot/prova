import 'package:flutter/material.dart';

import '../../../core/widgets/header_banner.dart';

/// 'Models' screen — the model registry. Lists every OCR/classifier
/// version with its training recipe, key metrics, checkpoint, and
/// lifecycle status, and surfaces when a new retraining cycle is
/// available.
class ModelsScreen extends StatelessWidget {
  const ModelsScreen({super.key});

  // TODO: replace with real data from the model registry repository/provider.
  static const int _newLabelsSinceLastTrain = 214;
  static const String _baselineVersion = 'clf-v1';

  static const List<_ModelRecord> _models = [
    _ModelRecord(
      version: 'ocr-v1',
      layer: 'OCR',
      recipe: 'trocr-base · MathWriting · LoRA r=16',
      metrics: 'CER 4.2% · EM 71.3%',
      checkpoint: 'ocr-v1.ckpt',
      status: _ModelStatus.current,
    ),
    _ModelRecord(
      version: 'clf-da0',
      layer: 'Classifier',
      recipe: 'bert-mult-cased · LA Corpus · DA-MLM 0ep',
      metrics: 'Acc 71.2% · F1 0.62',
      checkpoint: 'clf-da0.ckpt',
      status: _ModelStatus.superseded,
    ),
    _ModelRecord(
      version: 'clf-da3',
      layer: 'Classifier',
      recipe: 'bert-mult-cased · LA Corpus · DA-MLM 3ep',
      metrics: 'Acc 75.6% · F1 0.68',
      checkpoint: 'clf-da3.ckpt',
      status: _ModelStatus.superseded,
    ),
    _ModelRecord(
      version: 'clf-v1',
      layer: 'Classifier',
      recipe: 'bert-mult-cased · LA Corpus · DA-MLM 10ep',
      metrics: 'Acc 78.4% · F1 0.71',
      checkpoint: 'clf-v1.ckpt',
      status: _ModelStatus.current,
    ),
    _ModelRecord(
      version: 'clf-da20',
      layer: 'Classifier',
      recipe: 'bert-mult-cased · LA Corpus · DA-MLM 20ep',
      metrics: 'Acc 77.9% · F1 0.70',
      checkpoint: 'clf-da20.ckpt',
      status: _ModelStatus.superseded,
    ),
    _ModelRecord(
      version: 'clf-v2',
      layer: 'Classifier',
      recipe: 'bert-mult-cased · LA Corpus +214 · Continued FT',
      metrics: 'Acc 79.1% · F1 0.72',
      checkpoint: 'clf-v2-cand.ckpt',
      status: _ModelStatus.candidate,
    ),
    _ModelRecord(
      version: 'clf-v0',
      layer: 'Classifier',
      recipe: 'bert-uncased · LA Corpus (early) · Single-stage FT',
      metrics: 'Acc 68.4% · F1 0.55',
      checkpoint: 'clf-v0.ckpt',
      status: _ModelStatus.rejected,
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
              pageTitle: 'Models',
              stage: PipelineStage.notApplicable,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Model registry',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: _Palette.titleBlack,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _RetrainingBanner(
                      newLabels: _newLabelsSinceLastTrain,
                      baselineVersion: _baselineVersion,
                      onStartRetraining: () {
                        // TODO: kick off a new retraining cycle.
                      },
                    ),
                    const SizedBox(height: 20),
                    _ModelRegistryTable(models: _models),
                    const SizedBox(height: 12),
                    const Text(
                      'Rejected candidates are retained in the registry '
                      'with their recorded metrics.',
                      style: TextStyle(
                        color: _Palette.mutedText,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const _RetrainingHistoryCard(),
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
  static const Color tagGray = Color(0xFFEEF0F2);
  static const Color tagGrayText = Color(0xFF6B7078);
  static const Color amberBg = Color(0xFFFBF0DA);
  static const Color amberBorder = Color(0xFFEFD8A0);
  static const Color amberText = Color(0xFFB4791F);
  static const Color redBg = Color(0xFFFBE9E9);
  static const Color redText = Color(0xFFC23838);
}

// ---------------------------------------------------------------------------
// Retraining banner
// ---------------------------------------------------------------------------

class _RetrainingBanner extends StatelessWidget {
  const _RetrainingBanner({
    required this.newLabels,
    required this.baselineVersion,
    required this.onStartRetraining,
  });

  final int newLabels;
  final String baselineVersion;
  final VoidCallback onStartRetraining;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: _Palette.amberBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _Palette.amberBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Retraining available — $newLabels new adjudicated labels '
              'since $baselineVersion',
              style: const TextStyle(
                color: _Palette.amberText,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: onStartRetraining,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: _Palette.titleBlack,
              elevation: 0,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 14,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: _Palette.cardBorder),
              ),
            ),
            child: const Text(
              'Start retraining cycle',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Model registry table
// ---------------------------------------------------------------------------

enum _ModelStatus { current, superseded, candidate, rejected }

class _ModelRecord {
  const _ModelRecord({
    required this.version,
    required this.layer,
    required this.recipe,
    required this.metrics,
    required this.checkpoint,
    required this.status,
  });

  final String version;
  final String layer;
  final String recipe;
  final String metrics;
  final String checkpoint;
  final _ModelStatus status;
}

class _ModelRegistryTable extends StatelessWidget {
  const _ModelRegistryTable({required this.models});

  final List<_ModelRecord> models;

  static const TextStyle _headerStyle = TextStyle(
    color: _Palette.mutedText,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.4,
  );

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
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Expanded(flex: 2, child: Text('VERSION', style: _headerStyle)),
                Expanded(flex: 2, child: Text('LAYER', style: _headerStyle)),
                Expanded(
                  flex: 5,
                  child: Text(
                    'BASE MODEL / DATA / METHOD',
                    style: _headerStyle,
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text('KEY METRICS', style: _headerStyle),
                ),
                Expanded(
                  flex: 2,
                  child: Text('CHECKPOINT', style: _headerStyle),
                ),
                Expanded(flex: 2, child: Text('STATUS', style: _headerStyle)),
              ],
            ),
          ),
          const Divider(height: 1, color: _Palette.divider),
          for (int i = 0; i < models.length; i++) ...[
            _ModelRow(model: models[i]),
            if (i != models.length - 1)
              const Divider(height: 1, color: _Palette.divider),
          ],
        ],
      ),
    );
  }
}

class _ModelRow extends StatelessWidget {
  const _ModelRow({required this.model});

  final _ModelRecord model;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              model.version,
              style: const TextStyle(
                color: _Palette.titleBlack,
                fontWeight: FontWeight.w700,
                fontSize: 14.5,
                fontFamily: 'monospace',
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              model.layer,
              style: const TextStyle(color: _Palette.bodyText, fontSize: 14),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              model.recipe,
              style: const TextStyle(
                color: _Palette.bodyText,
                fontSize: 13.5,
                fontFamily: 'monospace',
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              model.metrics,
              style: const TextStyle(color: _Palette.bodyText, fontSize: 14),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              model.checkpoint,
              style: const TextStyle(
                color: _Palette.mutedText,
                fontSize: 13,
                fontFamily: 'monospace',
              ),
            ),
          ),
          Expanded(flex: 2, child: _StatusPill(status: model.status)),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final _ModelStatus status;

  @override
  Widget build(BuildContext context) {
    late final Color bg;
    late final Color fg;
    late final String label;

    switch (status) {
      case _ModelStatus.current:
        bg = _Palette.accentGreenSoft;
        fg = _Palette.accentGreen;
        label = 'CURRENT';
        break;
      case _ModelStatus.superseded:
        bg = _Palette.tagGray;
        fg = _Palette.tagGrayText;
        label = 'SUPERSEDED';
        break;
      case _ModelStatus.candidate:
        bg = _Palette.amberBg;
        fg = _Palette.amberText;
        label = 'CANDIDATE';
        break;
      case _ModelStatus.rejected:
        bg = _Palette.redBg;
        fg = _Palette.redText;
        label = 'REJECTED';
        break;
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.w700,
            fontSize: 11,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Retraining history (collapsible)
// ---------------------------------------------------------------------------

class _RetrainingHistoryCard extends StatefulWidget {
  const _RetrainingHistoryCard();

  @override
  State<_RetrainingHistoryCard> createState() =>
      _RetrainingHistoryCardState();
}

class _RetrainingHistoryCardState extends State<_RetrainingHistoryCard> {
  bool _expanded = false;

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
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                Icon(
                  _expanded ? Icons.arrow_drop_down : Icons.arrow_right,
                  color: _Palette.titleBlack,
                ),
                const SizedBox(width: 4),
                const Text(
                  'Retraining history',
                  style: TextStyle(
                    color: _Palette.titleBlack,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 14),
            const Text(
              // TODO: replace with the real retraining-cycle history.
              'No retraining cycles recorded yet.',
              style: TextStyle(color: _Palette.mutedText, fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }
}