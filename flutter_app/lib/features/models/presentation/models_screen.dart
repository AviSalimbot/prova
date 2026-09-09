import 'package:flutter/material.dart';

import '../../../core/widgets/header_banner.dart';

/// Placeholder screen for the 'Models' nav item.
/// Replace the centered title with real content once this feature's
/// data/domain layers are built out.
class ModelsScreen extends StatelessWidget {
  const ModelsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const ProvaHeaderBanner(
              pageTitle: 'Models',
              stage: PipelineStage.notApplicable,
            ),
            const Expanded(
              child: Center(
                child: Text(
                  'Models',
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
