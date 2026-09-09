import 'package:flutter/material.dart';

import '../../../core/widgets/header_banner.dart';

/// Placeholder screen for the 'Configuration' nav item.
/// Replace the centered title with real content once this feature's
/// data/domain layers are built out.
class ConfigurationScreen extends StatelessWidget {
  const ConfigurationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const ProvaHeaderBanner(
              pageTitle: 'Configuration',
              stage: PipelineStage.configure,
            ),
            const Expanded(
              child: Center(
                child: Text(
                  'Configuration',
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
