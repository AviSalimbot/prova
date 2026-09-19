import 'package:flutter/material.dart';

import '../../../core/widgets/header_banner.dart';

// ===========================================================================
// SYSTEM & STORAGE PANEL
// ===========================================================================

/// The "System & Storage" tab of the Administration screen.
///
/// Static placeholder: the layout and copy match the intended design
/// (Figure H-1), but the four status cards are hardcoded — nothing here
/// is wired to a live Colab/Drive/Firebase/storage check yet.
class SystemStoragePanel extends StatelessWidget {
  const SystemStoragePanel({super.key});

  static const _cards = [
    _StatusCardData(
      kicker: 'COMPUTE',
      title: 'Colab T4 (free tier)',
      subtitle: 'Connected · session active',
    ),
    _StatusCardData(
      kicker: 'CHECKPOINT STORAGE',
      title: 'Google Drive',
      subtitle: '/PROVA/checkpoints/sem1',
    ),
    _StatusCardData(
      kicker: 'FIREBASE',
      title: 'Connected',
      subtitle: 'Realtime sync — annotation & adjudication state',
    ),
    _StatusCardData(
      kicker: 'STORAGE USED',
      title: '2.4 GB / 15 GB',
      subtitle: 'Scans, checkpoints, exports',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _StatusCard(data: _cards[0])),
              const SizedBox(width: 24),
              Expanded(child: _StatusCard(data: _cards[1])),
            ],
          ),

          const SizedBox(height: 24),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _StatusCard(data: _cards[2])),
              const SizedBox(width: 24),
              Expanded(child: _StatusCard(data: _cards[3])),
            ],
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// STATUS CARD
// ===========================================================================

class _StatusCardData {
  const _StatusCardData({
    required this.kicker,
    required this.title,
    required this.subtitle,
  });

  final String kicker;
  final String title;
  final String subtitle;
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.data});

  final _StatusCardData data;

  static const _kickerStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: ProvaColors.subtitleGray,
    letterSpacing: 0.5,
  );

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: ProvaColors.dividerGray),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(data.kicker, style: _kickerStyle),

            const SizedBox(height: 10),

            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: ProvaColors.green,
                    shape: BoxShape.circle,
                  ),
                ),

                const SizedBox(width: 8),

                Text(
                  data.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            Text(
              data.subtitle,
              style: const TextStyle(
                fontSize: 13,
                color: ProvaColors.subtitleGray,
              ),
            ),
          ],
        ),
      ),
    );
  }
}