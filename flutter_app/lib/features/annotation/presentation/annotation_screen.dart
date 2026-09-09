import 'package:flutter/material.dart';

import '../../../core/widgets/header_banner.dart';

/// Placeholder screen for the 'Annotation' nav item.
/// Replace the centered title with real content once this feature's
/// data/domain layers are built out.
class AnnotationScreen extends StatelessWidget {
  const AnnotationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const ProvaHeaderBanner(
              pageTitle: 'Annotation',
              stage: PipelineStage.annotate,
            ),
            const Expanded(
              child: Center(
                child: Text(
                  'Annotation',
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
