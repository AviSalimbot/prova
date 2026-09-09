import 'package:flutter/material.dart';

import '../../../core/widgets/header_banner.dart';

/// Placeholder screen for the 'Evaluation' nav item.
/// Replace the centered title with real content once this feature's
/// data/domain layers are built out.
class EvaluationScreen extends StatelessWidget {
  const EvaluationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const ProvaHeaderBanner(
              pageTitle: 'Evaluation',
              stage: PipelineStage.evaluate,
            ),
            const Expanded(
              child: Center(
                child: Text(
                  'Evaluation',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: ProvaColors.titleBlack,
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
