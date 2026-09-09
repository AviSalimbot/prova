import 'package:flutter/material.dart';

import '../../../core/widgets/header_banner.dart';

/// Placeholder screen for the 'Adjudication' nav item.
/// Replace the centered title with real content once this feature's
/// data/domain layers are built out.
class AdjudicationScreen extends StatelessWidget {
  const AdjudicationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const ProvaHeaderBanner(
              pageTitle: 'Adjudication',
              stage: PipelineStage.adjudicate,
            ),
            const Expanded(
              child: Center(
                child: Text(
                  'Adjudication',
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
