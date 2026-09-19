import 'package:flutter/material.dart';

import '../../../core/widgets/header_banner.dart';

/// 'Configuration' screen — lets a researcher define a batch
/// classification run over de-identified student submissions.
class ConfigurationScreen extends StatefulWidget {
  const ConfigurationScreen({super.key});

  @override
  State<ConfigurationScreen> createState() => _ConfigurationScreenState();
}

class _ConfigurationScreenState extends State<ConfigurationScreen> {
  final _runNameController =
      TextEditingController(text: 'run_2026_sem1_batch01');

  String _selectedBatch = 'P001–P120 (full set) — 728 items';
  double _confidenceThreshold = 0.65;
  bool _checkpointPersistence = true;
  bool _dataSeparationEnforcement = true;

  static const _borderColor = Color(0xFFE2E5E1);
  static const _mutedText = Color(0xFF6B7370);
  static const _green = Color(0xFF3E7A55);
  static const _greenLight = Color(0xFFEAF4EC);
  static const _panelBg = Colors.white;

  @override
  void dispose() {
    _runNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F5),
      body: SafeArea(
        child: Column(
          children: [
            const ProvaHeaderBanner(
              pageTitle: 'Configuration',
              stage: PipelineStage.configure,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 900;
                    final formCard = _ConfigureRunCard(
                      runNameController: _runNameController,
                      selectedBatch: _selectedBatch,
                      onBatchChanged: (v) =>
                          setState(() => _selectedBatch = v ?? _selectedBatch),
                      confidenceThreshold: _confidenceThreshold,
                      onConfidenceChanged: (v) =>
                          setState(() => _confidenceThreshold = v),
                      checkpointPersistence: _checkpointPersistence,
                      onCheckpointChanged: (v) =>
                          setState(() => _checkpointPersistence = v),
                      dataSeparationEnforcement: _dataSeparationEnforcement,
                      onDataSeparationChanged: (v) =>
                          setState(() => _dataSeparationEnforcement = v),
                      onStartRun: () {
                        // TODO: wire up to run-creation use case.
                      },
                      borderColor: _borderColor,
                      mutedText: _mutedText,
                      green: _green,
                      greenLight: _greenLight,
                    );

                    const summaryCard = _RunSummaryCard(
                      itemsQueued: 728,
                      studentCount: 91,
                      gpu: 'Colab T4 (free tier)',
                      mode: 'Batch / Offline',
                      borderColor: _borderColor,
                      mutedText: _mutedText,
                      panelBg: _panelBg,
                    );

                    if (isWide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 7, child: formCard),
                          const SizedBox(width: 24),
                          Expanded(flex: 3, child: summaryCard),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        formCard,
                        const SizedBox(height: 24),
                        summaryCard,
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfigureRunCard extends StatelessWidget {
  const _ConfigureRunCard({
    required this.runNameController,
    required this.selectedBatch,
    required this.onBatchChanged,
    required this.confidenceThreshold,
    required this.onConfidenceChanged,
    required this.checkpointPersistence,
    required this.onCheckpointChanged,
    required this.dataSeparationEnforcement,
    required this.onDataSeparationChanged,
    required this.onStartRun,
    required this.borderColor,
    required this.mutedText,
    required this.green,
    required this.greenLight,
  });

  final TextEditingController runNameController;
  final String selectedBatch;
  final ValueChanged<String?> onBatchChanged;
  final double confidenceThreshold;
  final ValueChanged<double> onConfidenceChanged;
  final bool checkpointPersistence;
  final ValueChanged<bool> onCheckpointChanged;
  final bool dataSeparationEnforcement;
  final ValueChanged<bool> onDataSeparationChanged;
  final VoidCallback onStartRun;
  final Color borderColor;
  final Color mutedText;
  final Color green;
  final Color greenLight;

  static const _batchOptions = [
    'P001–P120 (full set) — 728 items',
    'P001–P060 — 364 items',
    'P061–P120 — 364 items',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Configure run',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Define a batch classification run over de-identified student submissions.',
            style: TextStyle(fontSize: 14, color: mutedText),
          ),
          const SizedBox(height: 24),

          _FieldLabel('Run name'),
          const SizedBox(height: 8),
          TextField(
            controller: runNameController,
            decoration: _fieldDecoration(borderColor),
          ),
          const SizedBox(height: 20),

          _FieldLabel('Input batch'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: selectedBatch,
            decoration: _fieldDecoration(borderColor),
            icon: const Icon(Icons.keyboard_arrow_down),
            items: _batchOptions
                .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                .toList(),
            onChanged: onBatchChanged,
          ),
          const SizedBox(height: 20),

          // Pinned versions panel.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFBFA),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PINNED FOR THIS RUN',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: mutedText,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _PinnedVersion(
                        label: 'OCR version',
                        value: 'ocr-v1',
                        green: green,
                        greenLight: greenLight,
                      ),
                    ),
                    Expanded(
                      child: _PinnedVersion(
                        label: 'Classifier version',
                        value: 'clf-v1',
                        green: green,
                        greenLight: greenLight,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Resolved automatically from the registry. Both are read-only for the life of the run.',
                  style: TextStyle(fontSize: 13, color: mutedText),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          _FieldLabel('Confidence threshold'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: green,
                    inactiveTrackColor: borderColor,
                    thumbColor: Colors.white,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 10),
                    overlayColor: green.withValues(alpha: 0.15),
                    trackHeight: 4,
                  ),
                  child: Slider(
                    value: confidenceThreshold,
                    min: 0,
                    max: 1,
                    onChanged: onConfidenceChanged,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 68,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: borderColor),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  confidenceThreshold.toStringAsFixed(2),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Divider(color: borderColor),
          const SizedBox(height: 12),

          _ToggleRow(
            title: 'Checkpoint persistence',
            subtitle: 'Persists intermediate model state for this run.',
            value: checkpointPersistence,
            onChanged: onCheckpointChanged,
            green: green,
            mutedText: mutedText,
          ),
          const SizedBox(height: 20),
          _ToggleRow(
            title: 'Data-separation enforcement',
            subtitle: 'Local student data cannot enter training while this run is open.',
            value: dataSeparationEnforcement,
            onChanged: onDataSeparationChanged,
            green: green,
            mutedText: mutedText,
            locked: true,
          ),
          const SizedBox(height: 32),

          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: onStartRun,
              style: ElevatedButton.styleFrom(
                backgroundColor: green,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Start run',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration(Color borderColor) {
    return InputDecoration(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _ConfigurationScreenState._green),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    );
  }
}

class _PinnedVersion extends StatelessWidget {
  const _PinnedVersion({
    required this.label,
    required this.value,
    required this.green,
    required this.greenLight,
  });

  final String label;
  final String value;
  final Color green;
  final Color greenLight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.black54)),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: greenLight,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'CURRENT',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: green,
            ),
          ),
        ),
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.green,
    required this.mutedText,
    this.locked = false,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color green;
  final Color mutedText;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  if (locked) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.lock_outline, size: 15, color: mutedText),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(fontSize: 13, color: mutedText)),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: locked ? null : onChanged,
          activeThumbColor: Colors.white,
          activeTrackColor: green,
        ),
      ],
    );
  }
}

class _RunSummaryCard extends StatelessWidget {
  const _RunSummaryCard({
    required this.itemsQueued,
    required this.studentCount,
    required this.gpu,
    required this.mode,
    required this.borderColor,
    required this.mutedText,
    required this.panelBg,
  });

  final int itemsQueued;
  final int studentCount;
  final String gpu;
  final String mode;
  final Color borderColor;
  final Color mutedText;
  final Color panelBg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: panelBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'RUN SUMMARY',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 20),
          _SummaryRow(label: 'Items queued', value: '$itemsQueued'),
          const SizedBox(height: 14),
          _SummaryRow(label: 'Student count', value: '$studentCount'),
          const SizedBox(height: 14),
          _SummaryRow(label: 'GPU', value: gpu),
          const SizedBox(height: 14),
          _SummaryRow(label: 'Mode', value: mode),
          const SizedBox(height: 20),
          Divider(color: borderColor),
          const SizedBox(height: 16),
          Text(
            'Every result is traced to a student code and item number for full auditability.',
            style: TextStyle(fontSize: 13, color: mutedText, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.black54)),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}