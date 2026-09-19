import 'package:flutter/material.dart';

import '../../../core/widgets/header_banner.dart';

/// 'Item Detail' screen — shows a single scanned item end-to-end: the raw
/// scan and preprocessed crop, the OCR transcription, the model's
/// prediction distribution, both annotators' labels, the final
/// gold-standard label, and how the model compares against it.
class ItemDetailScreen extends StatelessWidget {
  const ItemDetailScreen({super.key});

  // TODO: replace with real data from the item repository/provider.
  static const String _itemId = 'P079 · Item 2';
  static const String _ocrLatex =
      r'A\vec{x} = \begin{bmatrix} 2 & 1 \\ 0 & 3 \end{bmatrix} '
      r'\begin{bmatrix} x_1 \\ x_2 \end{bmatrix} = '
      r'\begin{bmatrix} 5 \\ 6 \end{bmatrix}';
  static const double _ocrConfidence = 0.97;
  static const String _preprocessingCaption =
      'Cropped · Deskewed · Binarized · Resized 384×384';

  static const String _modelPrediction = 'Notation';
  static const List<_PredictionShare> _predictionShares = [
    _PredictionShare('Conceptual', 0.04),
    _PredictionShare('Procedural', 0.35),
    _PredictionShare('Notation', 0.61),
  ];

  static const String _annotator1Label = 'Notation';
  static const String _annotator2Label = 'Notation';

  static const String _finalLabel = 'Notation';
  static const String _finalLabelBadge = 'Agreed by both annotators';

  static const String _modelVsGold = 'Match';
  static const bool _isMatch = true;

  static const String _provenance = 'Produced by ocr-v1 and clf-v1 in run R-014';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Palette.background,
      body: SafeArea(
        child: Column(
          children: [
            const ProvaHeaderBanner(
              pageTitle: 'Item Detail',
              stage: PipelineStage.notApplicable,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ItemSelectorRow(itemId: _itemId),
                    const SizedBox(height: 20),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final bool wide = constraints.maxWidth > 900;

                        final leftColumn = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _ImagePanel(
                              title: 'AS SCANNED',
                              placeholderLabel: 'full page scan',
                            ),
                            const SizedBox(height: 20),
                            const _ImagePanel(
                              title: 'AFTER PREPROCESSING CROP',
                              placeholderLabel: 'cropped answer box',
                              caption: _preprocessingCaption,
                            ),
                          ],
                        );

                        final rightColumn = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _OcrTranscriptionPanel(
                              latex: _ocrLatex,
                              confidence: _ocrConfidence,
                            ),
                            const SizedBox(height: 20),
                            _ModelPredictionPanel(
                              prediction: _modelPrediction,
                              shares: _predictionShares,
                            ),
                            const SizedBox(height: 20),
                            _AnnotatorLabelsPanel(
                              annotator1Label: _annotator1Label,
                              annotator2Label: _annotator2Label,
                            ),
                            const SizedBox(height: 20),
                            _FinalGoldLabelPanel(
                              label: _finalLabel,
                              badge: _finalLabelBadge,
                            ),
                            const SizedBox(height: 20),
                            _ModelVsGoldPanel(
                              result: _modelVsGold,
                              isMatch: _isMatch,
                            ),
                          ],
                        );

                        if (wide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: leftColumn),
                              const SizedBox(width: 20),
                              Expanded(child: rightColumn),
                            ],
                          );
                        }
                        return Column(
                          children: [
                            leftColumn,
                            const SizedBox(height: 20),
                            rightColumn,
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        _provenance,
                        style: const TextStyle(
                          color: _Palette.mutedText,
                          fontSize: 13,
                          fontFamily: 'monospace',
                        ),
                      ),
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
  static const Color imagePlaceholder = Color(0xFFFAFAF7);
}

const TextStyle _sectionLabelStyle = TextStyle(
  color: _Palette.mutedText,
  fontSize: 12,
  fontWeight: FontWeight.w600,
  letterSpacing: 0.6,
);

// ---------------------------------------------------------------------------
// Item selector (prev/next + id) — top of the page, above the fold in the
// reference screenshot.
// ---------------------------------------------------------------------------

class _ItemSelectorRow extends StatelessWidget {
  const _ItemSelectorRow({required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          itemId,
          style: const TextStyle(
            color: _Palette.titleBlack,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        Row(
          children: [
            _NavIconButton(icon: Icons.chevron_left, onPressed: () {}),
            const SizedBox(width: 8),
            _NavIconButton(icon: Icons.chevron_right, onPressed: () {}),
          ],
        ),
      ],
    );
  }
}

class _NavIconButton extends StatelessWidget {
  const _NavIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: _Palette.cardBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _Palette.cardBorder),
        ),
        child: Icon(icon, size: 20, color: _Palette.titleBlack),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Image panel (AS SCANNED / AFTER PREPROCESSING CROP)
// ---------------------------------------------------------------------------

class _ImagePanel extends StatelessWidget {
  const _ImagePanel({
    required this.title,
    required this.placeholderLabel,
    this.caption,
  });

  final String title;
  final String placeholderLabel;
  final String? caption;

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
          Text(title, style: _sectionLabelStyle),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Container(
              decoration: BoxDecoration(
                color: _Palette.imagePlaceholder,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _Palette.cardBorder),
              ),
              alignment: Alignment.center,
              child: Text(
                placeholderLabel,
                style: const TextStyle(
                  color: _Palette.mutedText,
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                  fontFamily: 'cursive',
                ),
              ),
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: 12),
            Text(
              caption!,
              style: const TextStyle(color: _Palette.mutedText, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// OCR transcription panel
// ---------------------------------------------------------------------------

class _OcrTranscriptionPanel extends StatelessWidget {
  const _OcrTranscriptionPanel({
    required this.latex,
    required this.confidence,
  });

  final String latex;
  final double confidence;

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
          const Text('OCR TRANSCRIPTION (LATEX)', style: _sectionLabelStyle),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _Palette.inputFill,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _Palette.cardBorder),
            ),
            child: Text(
              latex,
              style: const TextStyle(
                color: _Palette.bodyText,
                fontSize: 13.5,
                fontFamily: 'monospace',
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 12),
          RichText(
            text: TextSpan(
              style: const TextStyle(color: _Palette.bodyText, fontSize: 14),
              children: [
                const TextSpan(text: 'OCR confidence: '),
                TextSpan(
                  text: '${(confidence * 100).round()}%',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Model prediction panel
// ---------------------------------------------------------------------------

class _PredictionShare {
  const _PredictionShare(this.category, this.fraction);

  final String category;
  final double fraction;
}

class _ModelPredictionPanel extends StatelessWidget {
  const _ModelPredictionPanel({
    required this.prediction,
    required this.shares,
  });

  final String prediction;
  final List<_PredictionShare> shares;

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
          const Text('MODEL PREDICTION', style: _sectionLabelStyle),
          const SizedBox(height: 10),
          Text(
            prediction,
            style: const TextStyle(
              color: _Palette.titleBlack,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          for (int i = 0; i < shares.length; i++) ...[
            _PredictionShareRow(share: shares[i]),
            if (i != shares.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _PredictionShareRow extends StatelessWidget {
  const _PredictionShareRow({required this.share});

  final _PredictionShare share;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            share.category,
            style: const TextStyle(color: _Palette.bodyText, fontSize: 14),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 14,
              child: LinearProgressIndicator(
                value: share.fraction,
                backgroundColor: _Palette.divider,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  _Palette.accentGreen,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 38,
          child: Text(
            '${(share.fraction * 100).round()}%',
            textAlign: TextAlign.right,
            style: const TextStyle(color: _Palette.mutedText, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Annotator labels panel
// ---------------------------------------------------------------------------

class _AnnotatorLabelsPanel extends StatelessWidget {
  const _AnnotatorLabelsPanel({
    required this.annotator1Label,
    required this.annotator2Label,
  });

  final String annotator1Label;
  final String annotator2Label;

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
          const Text('ANNOTATOR LABELS', style: _sectionLabelStyle),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _AnnotatorLabelChip(
                  title: 'ANNOTATOR 1',
                  label: annotator1Label,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _AnnotatorLabelChip(
                  title: 'ANNOTATOR 2',
                  label: annotator2Label,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AnnotatorLabelChip extends StatelessWidget {
  const _AnnotatorLabelChip({required this.title, required this.label});

  final String title;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _Palette.inputFill,
        borderRadius: BorderRadius.circular(8),
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
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Final gold-standard label panel
// ---------------------------------------------------------------------------

class _FinalGoldLabelPanel extends StatelessWidget {
  const _FinalGoldLabelPanel({required this.label, required this.badge});

  final String label;
  final String badge;

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
          const Text('FINAL GOLD-STANDARD LABEL', style: _sectionLabelStyle),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: _Palette.titleBlack,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _Palette.accentGreenSoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    color: _Palette.accentGreen,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
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

// ---------------------------------------------------------------------------
// Model vs. gold standard panel
// ---------------------------------------------------------------------------

class _ModelVsGoldPanel extends StatelessWidget {
  const _ModelVsGoldPanel({required this.result, required this.isMatch});

  final String result;
  final bool isMatch;

  @override
  Widget build(BuildContext context) {
    final Color badgeColor = isMatch ? _Palette.accentGreen : Colors.red;
    final Color badgeBg = isMatch
        ? _Palette.accentGreenSoft
        : const Color(0xFFFBE9E9);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: _Palette.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _Palette.cardBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Model vs. gold standard',
            style: TextStyle(
              color: _Palette.titleBlack,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              result,
              style: TextStyle(
                color: badgeColor,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}