// lib/features/assessments/presentation/assessments_grid.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../services/firestore_paths.dart';
import '../data/drive_import_service.dart';
import '../data/exams_repository.dart';
import '../domain/assessment.dart';
import 'assessments_screen.dart' show AssessmentFilter;
import 'drive_connect.dart';

/// Top-level grid of assessment cards.
class AssessmentsGrid extends ConsumerWidget {
  const AssessmentsGrid({
    super.key,
    required this.filter,
    required this.onFilterChanged,
    required this.onOpen,
  });

  final AssessmentFilter filter;
  final ValueChanged<AssessmentFilter> onFilterChanged;
  final ValueChanged<Assessment> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assessmentsAsync = ref.watch(examsStreamProvider);

    return assessmentsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Failed to load assessments: $e')),
      data: (assessments) {
        final filtered = assessments.where((a) {
          switch (filter) {
            case AssessmentFilter.all:
              return true;
            case AssessmentFilter.exams:
              return a.type == AssessmentType.exam;
            case AssessmentFilter.activities:
              return a.type == AssessmentType.activity;
          }
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _FilterChips(value: filter, onChanged: onFilterChanged),
                const Spacer(),
                ElevatedButton(
                  onPressed: () => _startImportFlow(context, ref),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E5E3E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Import assessment',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('No assessments yet.'))
                  : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 1.65,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final assessment = filtered[i];
                        return _AssessmentCard(
                          assessment: assessment,
                          onTap: () => onOpen(assessment),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  /// Entry point for the whole import flow. Delegates the "is there a
  /// live Drive session" check to [ensureDriveConnected] — the same
  /// gate PagesGrid uses — so returning users who already granted
  /// access skip straight to the assessment name/type dialog.
  Future<void> _startImportFlow(BuildContext context, WidgetRef ref) async {
    if (!await ensureDriveConnected(context, ref)) return;
    if (!context.mounted) return;

    await _showImportDialog(context, ref);
  }

  Future<void> _showImportDialog(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    var type = AssessmentType.activity;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          // Explicit white background — AlertDialog otherwise falls
          // back to the theme's dialogBackgroundColor.
          backgroundColor: Colors.white,
          title: const Text('Import assessment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                // Smaller input text/hint than the default (which
                // inherits the theme's larger bodyLarge size).
                style: const TextStyle(fontSize: 14),
                decoration: const InputDecoration(
                  labelText: 'Assessment name',
                  labelStyle: TextStyle(fontSize: 13),
                  hintText: 'Must match the Drive folder name exactly',
                  hintStyle: TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(height: 16),
              // Wrapped in a Theme override so the popup menu's item
              // hover/highlight uses a much softer, lower-opacity tint
              // instead of the default (fairly strong) Material
              // hover/splash color.
              Theme(
                data: Theme.of(ctx).copyWith(
                  // PopupMenuItem's hover tint — neutral gray, and
                  // unlike DropdownButton, PopupMenuButton has no
                  // concept of a "currently selected" row, so nothing
                  // stays highlighted once the mouse moves away.
                  hoverColor: Colors.black.withOpacity(0.04),
                  highlightColor: Colors.black.withOpacity(0.08),
                  splashColor: Colors.black.withOpacity(0.08),
                ),
                child: PopupMenuButton<AssessmentType>(
                  initialValue: type,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  // Menu width is now independent of the field's width
                  // — narrower than the dialog instead of stretching
                  // edge to edge.
                  constraints: const BoxConstraints(minWidth: 260, maxWidth: 260),
                  onSelected: (v) => setState(() => type = v),
                  itemBuilder: (context) => AssessmentType.values
                      .map(
                        (t) => PopupMenuItem(
                          value: t,
                          child: Text(
                            t.label,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      )
                      .toList(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade400),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            type.label,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        const Icon(
                          Icons.arrow_drop_down,
                          color: Colors.black54,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Import'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || nameController.text.trim().isEmpty) return;
    if (!context.mounted) return;

    final name = nameController.text.trim();

    final examRef =
        await FirebaseFirestore.instance.collection(FirestorePaths.exams).add({
      'name': name,
      'type': type.name,
      'status': AssessmentStatus.incomplete.name,
      'participantCount': 0,
      'pageCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Importing from Drive… this can take a moment.'),
      ),
    );

    try {
      final count =
          await ref.read(driveImportServiceProvider).importExam(examRef.id, name);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported $count participant(s) for "$name".')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Import failed: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.value, required this.onChanged});

  final AssessmentFilter value;
  final ValueChanged<AssessmentFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _chip('All', AssessmentFilter.all),
        const SizedBox(width: 8),
        _chip('Exams', AssessmentFilter.exams),
        const SizedBox(width: 8),
        _chip('Activities', AssessmentFilter.activities),
      ],
    );
  }

  Widget _chip(String label, AssessmentFilter filter) {
    final selected = value == filter;
    return InkWell(
      onTap: () => onChanged(filter),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE6F4EA) : Colors.white,
          border: Border.all(
            color: selected ? const Color(0xFF2E7D4F) : Colors.grey.shade300,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? const Color(0xFF2E7D4F) : Colors.black87,
          ),
        ),
      ),
    );
  }
}

class _AssessmentCard extends StatelessWidget {
  const _AssessmentCard({required this.assessment, required this.onTap});

  final Assessment assessment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SvgPicture.asset(
                  'assets/images/folders.svg',
                  width: 38,
                  height: 38,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDEFF5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    assessment.type.label.toUpperCase(),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              assessment.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '${assessment.participantCount} participants · '
              '${assessment.pageCount} pages',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: assessment.status == AssessmentStatus.complete
                    ? const Color(0xFFE6F4EA)
                    : const Color(0xFFFCEFDC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                assessment.status.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: assessment.status == AssessmentStatus.complete
                      ? const Color(0xFF2E7D4F)
                      : const Color(0xFFB5651D),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}