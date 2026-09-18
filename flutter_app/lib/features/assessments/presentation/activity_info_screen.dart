// // import 'package:flutter/material.dart';
// // import 'package:flutter_riverpod/flutter_riverpod.dart';

// // import '../data/clean_job_service.dart';
// // import '../data/exams_repository.dart';
// // import '../domain/assessment.dart';

// // class ActivityInfoScreen extends ConsumerStatefulWidget {
// //   const ActivityInfoScreen({
// //     super.key,
// //     required this.assessment,
// //     required this.onOpenVariant,
// //   });

// //   final Assessment assessment;
// //   final ValueChanged<ScanVariant> onOpenVariant;

// //   @override
// //   ConsumerState<ActivityInfoScreen> createState() =>
// //       _ActivityInfoScreenState();
// // }

// // class _ActivityInfoScreenState extends ConsumerState<ActivityInfoScreen> {
// //   bool _triggering = false;
// //   String? _triggerError;

// //   Future<void> _runClean(Assessment assessment) async {
// //     setState(() {
// //       _triggering = true;
// //       _triggerError = null;
// //     });
// //     try {
// //       await ref
// //           .read(cleanJobServiceProvider)
// //           .triggerClean(assessment.id, assessment.name);
// //       // cleanStatus flips to 'processing' server-side almost
// //       // immediately; examsStreamProvider will pick that up on its own.
// //     } catch (e) {
// //       if (mounted) setState(() => _triggerError = e.toString());
// //     } finally {
// //       if (mounted) setState(() => _triggering = false);
// //     }
// //   }

// //   @override
// //   Widget build(BuildContext context) {
// //     // Watch the live exam doc (via the list stream) so cleanStatus
// //     // updates reactively while the backend job runs in the background
// //     // — this widget doesn't need its own Firestore listener.
// //     final assessmentsAsync = ref.watch(examsStreamProvider);
// //     final live = assessmentsAsync.maybeWhen(
// //       data: (list) => list.firstWhere(
// //         (a) => a.id == widget.assessment.id,
// //         orElse: () => widget.assessment,
// //       ),
// //       orElse: () => widget.assessment,
// //     );

// //     final perParticipantPages = live.participantCount > 0
// //         ? (live.pageCount / live.participantCount).round()
// //         : 0;

// //     return SingleChildScrollView(
// //       child: Column(
// //         crossAxisAlignment: CrossAxisAlignment.start,
// //         children: [
// //           Container(
// //             padding: const EdgeInsets.all(20),
// //             decoration: BoxDecoration(
// //               color: Colors.white,
// //               borderRadius: BorderRadius.circular(12),
// //               boxShadow: [
// //                 BoxShadow(
// //                   color: Colors.black.withOpacity(0.06),
// //                   blurRadius: 8,
// //                   offset: const Offset(0, 2),
// //                 ),
// //               ],
// //             ),
// //             child: Column(
// //               crossAxisAlignment: CrossAxisAlignment.start,
// //               children: [
// //                 Text(
// //                   live.name,
// //                   style: const TextStyle(
// //                       fontSize: 20, fontWeight: FontWeight.bold),
// //                 ),
// //                 const SizedBox(height: 12),
// //                 Wrap(
// //                   spacing: 24,
// //                   runSpacing: 8,
// //                   children: [
// //                     _statChip('Participants', '${live.participantCount}'),
// //                     _statChip('Pages / participant', '$perParticipantPages'),
// //                     _statChip('Total pages', '${live.pageCount}'),
// //                   ],
// //                 ),
// //               ],
// //             ),
// //           ),
// //           const SizedBox(height: 24),
// //           const Text(
// //             'Scan variants',
// //             style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
// //           ),
// //           const SizedBox(height: 12),
// //           Row(
// //             crossAxisAlignment: CrossAxisAlignment.start,
// //             children: [
// //               Expanded(
// //                 child: _VariantTile(
// //                   variant: ScanVariant.raw,
// //                   enabled: true,
// //                   onTap: () => widget.onOpenVariant(ScanVariant.raw),
// //                 ),
// //               ),
// //               const SizedBox(width: 16),
// //               Expanded(
// //                 child: _VariantTile(
// //                   variant: ScanVariant.cleaned,
// //                   enabled: live.cleanedReady,
// //                   processing: live.cleaning,
// //                   onTap: live.cleanedReady
// //                       ? () => widget.onOpenVariant(ScanVariant.cleaned)
// //                       : null,
// //                 ),
// //               ),
// //               const SizedBox(width: 16),
// //               Expanded(
// //                 child: _VariantTile(
// //                   variant: ScanVariant.cropped,
// //                   enabled: false,
// //                   onTap: null,
// //                 ),
// //               ),
// //             ],
// //           ),
// //           const SizedBox(height: 24),
// //           if (!live.cleanedReady) ...[
// //             SizedBox(
// //               width: 260,
// //               child: ElevatedButton.icon(
// //                 onPressed: (_triggering || live.cleaning)
// //                     ? null
// //                     : () => _runClean(live),
// //                 icon: (_triggering || live.cleaning)
// //                     ? const SizedBox(
// //                         width: 16,
// //                         height: 16,
// //                         child: CircularProgressIndicator(strokeWidth: 2),
// //                       )
// //                     : const Icon(Icons.auto_fix_high),
// //                 label: Text(
// //                   live.cleaning
// //                       ? 'Cleaning…'
// //                       : (_triggering ? 'Starting…' : 'Clean & upload'),
// //                 ),
// //                 style: ElevatedButton.styleFrom(
// //                   backgroundColor: const Color(0xFF2E5E3E),
// //                   foregroundColor: Colors.white,
// //                   padding: const EdgeInsets.symmetric(vertical: 14),
// //                 ),
// //               ),
// //             ),
// //             if (_triggerError != null) ...[
// //               const SizedBox(height: 8),
// //               Text(_triggerError!,
// //                   style: const TextStyle(color: Colors.red, fontSize: 12)),
// //             ],
// //             if (live.cleanStatus == 'failed' && live.cleanError != null) ...[
// //               const SizedBox(height: 8),
// //               Text('Last attempt failed: ${live.cleanError}',
// //                   style: const TextStyle(color: Colors.red, fontSize: 12)),
// //             ],
// //           ],
// //         ],
// //       ),
// //     );
// //   }

// //   Widget _statChip(String label, String value) {
// //     return Column(
// //       crossAxisAlignment: CrossAxisAlignment.start,
// //       children: [
// //         Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
// //         Text(value,
// //             style:
// //                 const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
// //       ],
// //     );
// //   }
// // }

// // class _VariantTile extends StatelessWidget {
// //   const _VariantTile({
// //     required this.variant,
// //     required this.enabled,
// //     required this.onTap,
// //     this.processing = false,
// //   });

// //   final ScanVariant variant;
// //   final bool enabled;
// //   final bool processing;
// //   final VoidCallback? onTap;

// //   @override
// //   Widget build(BuildContext context) {
// //     return InkWell(
// //       onTap: onTap,
// //       borderRadius: BorderRadius.circular(12),
// //       child: Opacity(
// //         opacity: enabled ? 1.0 : 0.45,
// //         child: Container(
// //           padding: const EdgeInsets.all(20),
// //           decoration: BoxDecoration(
// //             color: Colors.white,
// //             borderRadius: BorderRadius.circular(12),
// //             border: Border.all(color: Colors.grey.shade300),
// //           ),
// //           child: Column(
// //             children: [
// //               Icon(
// //                 Icons.folder,
// //                 size: 40,
// //                 color: enabled ? const Color(0xFFB5651D) : Colors.grey,
// //               ),
// //               const SizedBox(height: 10),
// //               Text(variant.label,
// //                   style: const TextStyle(fontWeight: FontWeight.bold)),
// //               if (processing) ...[
// //                 const SizedBox(height: 6),
// //                 const Text('Processing…',
// //                     style: TextStyle(fontSize: 11, color: Colors.grey)),
// //               ] else if (!enabled) ...[
// //                 const SizedBox(height: 6),
// //                 const Text('Not available yet',
// //                     style: TextStyle(fontSize: 11, color: Colors.grey)),
// //               ],
// //             ],
// //           ),
// //         ),
// //       ),
// //     );
// //   }
// // }


// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';

// import '../data/clean_job_service.dart';
// import '../data/crop_job_service.dart';
// import '../data/exams_repository.dart';
// import '../domain/assessment.dart';

// class ActivityInfoScreen extends ConsumerStatefulWidget {
//   const ActivityInfoScreen({
//     super.key,
//     required this.assessment,
//     required this.onOpenVariant,
//   });

//   final Assessment assessment;
//   final ValueChanged<ScanVariant> onOpenVariant;

//   @override
//   ConsumerState<ActivityInfoScreen> createState() =>
//       _ActivityInfoScreenState();
// }

// class _ActivityInfoScreenState extends ConsumerState<ActivityInfoScreen> {
//   bool _triggeringClean = false;
//   String? _cleanTriggerError;

//   bool _triggeringCrop = false;
//   String? _cropTriggerError;

//   Future<void> _runClean(Assessment assessment) async {
//     setState(() {
//       _triggeringClean = true;
//       _cleanTriggerError = null;
//     });
//     try {
//       await ref
//           .read(cleanJobServiceProvider)
//           .triggerClean(assessment.id, assessment.name);
//       // cleanStatus flips to 'processing' server-side almost
//       // immediately; examsStreamProvider will pick that up on its own.
//     } catch (e) {
//       if (mounted) setState(() => _cleanTriggerError = e.toString());
//     } finally {
//       if (mounted) setState(() => _triggeringClean = false);
//     }
//   }

//   Future<void> _runCrop(Assessment assessment) async {
//     setState(() {
//       _triggeringCrop = true;
//       _cropTriggerError = null;
//     });
//     try {
//       await ref
//           .read(cropJobServiceProvider)
//           .triggerCrop(assessment.id, assessment.name);
//       // cropStatus flips to 'processing' server-side almost
//       // immediately; examsStreamProvider will pick that up on its own.
//     } catch (e) {
//       if (mounted) setState(() => _cropTriggerError = e.toString());
//     } finally {
//       if (mounted) setState(() => _triggeringCrop = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     // Watch the live exam doc (via the list stream) so cleanStatus /
//     // cropStatus update reactively while the backend jobs run in the
//     // background — this widget doesn't need its own Firestore listener.
//     final assessmentsAsync = ref.watch(examsStreamProvider);
//     final live = assessmentsAsync.maybeWhen(
//       data: (list) => list.firstWhere(
//         (a) => a.id == widget.assessment.id,
//         orElse: () => widget.assessment,
//       ),
//       orElse: () => widget.assessment,
//     );

//     final perParticipantPages = live.participantCount > 0
//         ? (live.pageCount / live.participantCount).round()
//         : 0;

//     return SingleChildScrollView(
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Container(
//             padding: const EdgeInsets.all(20),
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(12),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withOpacity(0.06),
//                   blurRadius: 8,
//                   offset: const Offset(0, 2),
//                 ),
//               ],
//             ),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   live.name,
//                   style: const TextStyle(
//                       fontSize: 20, fontWeight: FontWeight.bold),
//                 ),
//                 const SizedBox(height: 12),
//                 Wrap(
//                   spacing: 24,
//                   runSpacing: 8,
//                   children: [
//                     _statChip('Participants', '${live.participantCount}'),
//                     _statChip('Pages / participant', '$perParticipantPages'),
//                     _statChip('Total pages', '${live.pageCount}'),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//           const SizedBox(height: 24),
//           const Text(
//             'Scan variants',
//             style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//           ),
//           const SizedBox(height: 12),
//           Row(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Expanded(
//                 child: _VariantTile(
//                   variant: ScanVariant.raw,
//                   enabled: true,
//                   onTap: () => widget.onOpenVariant(ScanVariant.raw),
//                 ),
//               ),
//               const SizedBox(width: 16),
//               Expanded(
//                 child: _VariantTile(
//                   variant: ScanVariant.cleaned,
//                   enabled: live.cleanedReady,
//                   processing: live.cleaning,
//                   onTap: live.cleanedReady
//                       ? () => widget.onOpenVariant(ScanVariant.cleaned)
//                       : null,
//                 ),
//               ),
//               const SizedBox(width: 16),
//               Expanded(
//                 child: _VariantTile(
//                   variant: ScanVariant.cropped,
//                   enabled: live.croppedReady,
//                   processing: live.cropping,
//                   onTap: live.croppedReady
//                       ? () => widget.onOpenVariant(ScanVariant.cropped)
//                       : null,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 24),
//           // "Clean & upload" is the first step and only makes sense
//           // before cleanedReady flips true.
//           if (!live.cleanedReady) ...[
//             SizedBox(
//               width: 260,
//               child: ElevatedButton.icon(
//                 onPressed: (_triggeringClean || live.cleaning)
//                     ? null
//                     : () => _runClean(live),
//                 icon: (_triggeringClean || live.cleaning)
//                     ? const SizedBox(
//                         width: 16,
//                         height: 16,
//                         child: CircularProgressIndicator(strokeWidth: 2),
//                       )
//                     : const Icon(Icons.auto_fix_high),
//                 label: Text(
//                   live.cleaning
//                       ? 'Cleaning…'
//                       : (_triggeringClean ? 'Starting…' : 'Clean & upload'),
//                 ),
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: const Color(0xFF2E5E3E),
//                   foregroundColor: Colors.white,
//                   padding: const EdgeInsets.symmetric(vertical: 14),
//                 ),
//               ),
//             ),
//             if (_cleanTriggerError != null) ...[
//               const SizedBox(height: 8),
//               Text(_cleanTriggerError!,
//                   style: const TextStyle(color: Colors.red, fontSize: 12)),
//             ],
//             if (live.cleanStatus == 'failed' && live.cleanError != null) ...[
//               const SizedBox(height: 8),
//               Text('Last attempt failed: ${live.cleanError}',
//                   style: const TextStyle(color: Colors.red, fontSize: 12)),
//             ],
//           ],
//           // "Crop" only becomes available once cleaning has finished,
//           // and only until croppedReady flips true.
//           if (live.cleanedReady && !live.croppedReady) ...[
//             SizedBox(
//               width: 260,
//               child: ElevatedButton.icon(
//                 onPressed: (_triggeringCrop || live.cropping)
//                     ? null
//                     : () => _runCrop(live),
//                 icon: (_triggeringCrop || live.cropping)
//                     ? const SizedBox(
//                         width: 16,
//                         height: 16,
//                         child: CircularProgressIndicator(strokeWidth: 2),
//                       )
//                     : const Icon(Icons.crop),
//                 label: Text(
//                   live.cropping
//                       ? 'Cropping…'
//                       : (_triggeringCrop ? 'Starting…' : 'Crop'),
//                 ),
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: const Color(0xFF2E4E8E),
//                   foregroundColor: Colors.white,
//                   padding: const EdgeInsets.symmetric(vertical: 14),
//                 ),
//               ),
//             ),
//             if (_cropTriggerError != null) ...[
//               const SizedBox(height: 8),
//               Text(_cropTriggerError!,
//                   style: const TextStyle(color: Colors.red, fontSize: 12)),
//             ],
//             if (live.cropStatus == 'failed' && live.cropError != null) ...[
//               const SizedBox(height: 8),
//               Text('Last attempt failed: ${live.cropError}',
//                   style: const TextStyle(color: Colors.red, fontSize: 12)),
//             ],
//           ],
//         ],
//       ),
//     );
//   }

//   Widget _statChip(String label, String value) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
//         Text(value,
//             style:
//                 const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
//       ],
//     );
//   }
// }

// class _VariantTile extends StatelessWidget {
//   const _VariantTile({
//     required this.variant,
//     required this.enabled,
//     required this.onTap,
//     this.processing = false,
//   });

//   final ScanVariant variant;
//   final bool enabled;
//   final bool processing;
//   final VoidCallback? onTap;

//   @override
//   Widget build(BuildContext context) {
//     return InkWell(
//       onTap: onTap,
//       borderRadius: BorderRadius.circular(12),
//       child: Opacity(
//         opacity: enabled ? 1.0 : 0.45,
//         child: Container(
//           padding: const EdgeInsets.all(20),
//           decoration: BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.circular(12),
//             border: Border.all(color: Colors.grey.shade300),
//           ),
//           child: Column(
//             children: [
//               Icon(
//                 Icons.folder,
//                 size: 40,
//                 color: enabled ? const Color(0xFFB5651D) : Colors.grey,
//               ),
//               const SizedBox(height: 10),
//               Text(variant.label,
//                   style: const TextStyle(fontWeight: FontWeight.bold)),
//               if (processing) ...[
//                 const SizedBox(height: 6),
//                 const Text('Processing…',
//                     style: TextStyle(fontSize: 11, color: Colors.grey)),
//               ] else if (!enabled) ...[
//                 const SizedBox(height: 6),
//                 const Text('Not available yet',
//                     style: TextStyle(fontSize: 11, color: Colors.grey)),
//               ],
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }


import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/clean_job_service.dart';
import '../data/crop_job_service.dart';
import '../data/exams_repository.dart';
import '../domain/assessment.dart';

class ActivityInfoScreen extends ConsumerStatefulWidget {
  const ActivityInfoScreen({
    super.key,
    required this.assessment,
    required this.onOpenVariant,
  });

  final Assessment assessment;
  final ValueChanged<ScanVariant> onOpenVariant;

  @override
  ConsumerState<ActivityInfoScreen> createState() =>
      _ActivityInfoScreenState();
}

class _ActivityInfoScreenState extends ConsumerState<ActivityInfoScreen> {
  bool _triggeringClean = false;
  String? _cleanTriggerError;

  bool _triggeringCrop = false;
  String? _cropTriggerError;

  // Which layout cropper to run. Defaults to the only implemented one.
  CropTemplate _selectedCropTemplate = CropTemplate.activityV1;

  Future<void> _runClean(Assessment assessment) async {
    setState(() {
      _triggeringClean = true;
      _cleanTriggerError = null;
    });
    try {
      await ref
          .read(cleanJobServiceProvider)
          .triggerClean(assessment.id, assessment.name);
      // cleanStatus flips to 'processing' server-side almost
      // immediately; examsStreamProvider will pick that up on its own.
    } catch (e) {
      if (mounted) setState(() => _cleanTriggerError = e.toString());
    } finally {
      if (mounted) setState(() => _triggeringClean = false);
    }
  }

  Future<void> _runCrop(Assessment assessment) async {
    setState(() {
      _triggeringCrop = true;
      _cropTriggerError = null;
    });
    try {
      await ref
          .read(cropJobServiceProvider)
          .triggerCrop(assessment.id, assessment.name, _selectedCropTemplate);
      // cropStatus flips to 'processing' server-side almost
      // immediately; examsStreamProvider will pick that up on its own.
    } catch (e) {
      if (mounted) setState(() => _cropTriggerError = e.toString());
    } finally {
      if (mounted) setState(() => _triggeringCrop = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch the live exam doc (via the list stream) so cleanStatus /
    // cropStatus update reactively while the backend jobs run in the
    // background — this widget doesn't need its own Firestore listener.
    final assessmentsAsync = ref.watch(examsStreamProvider);
    final live = assessmentsAsync.maybeWhen(
      data: (list) => list.firstWhere(
        (a) => a.id == widget.assessment.id,
        orElse: () => widget.assessment,
      ),
      orElse: () => widget.assessment,
    );

    final perParticipantPages = live.participantCount > 0
        ? (live.pageCount / live.participantCount).round()
        : 0;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
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
                Text(
                  live.name,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 24,
                  runSpacing: 8,
                  children: [
                    _statChip('Participants', '${live.participantCount}'),
                    _statChip('Pages / participant', '$perParticipantPages'),
                    _statChip('Total pages', '${live.pageCount}'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Scan variants',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _VariantTile(
                  variant: ScanVariant.raw,
                  enabled: true,
                  onTap: () => widget.onOpenVariant(ScanVariant.raw),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _VariantTile(
                  variant: ScanVariant.cleaned,
                  enabled: live.cleanedReady,
                  processing: live.cleaning,
                  onTap: live.cleanedReady
                      ? () => widget.onOpenVariant(ScanVariant.cleaned)
                      : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _VariantTile(
                  variant: ScanVariant.cropped,
                  enabled: live.croppedReady,
                  processing: live.cropping,
                  onTap: live.croppedReady
                      ? () => widget.onOpenVariant(ScanVariant.cropped)
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ---- Clean job progress + trigger ----
          if (live.cleaning) ...[
            _JobProgress(
              label: 'Cleaning',
              progress: live.cleanProgress,
              done: live.cleanedPageCount,
              total: live.pageCount,
              remaining: live.estimatedCleanRemaining(),
              color: const Color(0xFF2E5E3E),
            ),
            const SizedBox(height: 16),
          ],
          if (!live.cleanedReady && !live.cleaning) ...[
            SizedBox(
              width: 260,
              child: ElevatedButton.icon(
                onPressed: _triggeringClean ? null : () => _runClean(live),
                icon: _triggeringClean
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_fix_high),
                label: Text(_triggeringClean ? 'Starting…' : 'Clean & upload'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E5E3E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            if (_cleanTriggerError != null) ...[
              const SizedBox(height: 8),
              Text(_cleanTriggerError!,
                  style: const TextStyle(color: Colors.red, fontSize: 12)),
            ],
            if (live.cleanStatus == 'failed' && live.cleanError != null) ...[
              const SizedBox(height: 8),
              Text('Last attempt failed: ${live.cleanError}',
                  style: const TextStyle(color: Colors.red, fontSize: 12)),
            ],
          ],

          // ---- Crop job progress + template picker + trigger ----
          if (live.cropping) ...[
            _JobProgress(
              label: 'Cropping',
              progress: live.cropProgress,
              done: live.croppedPageCount,
              total: live.pageCount,
              remaining: live.estimatedCropRemaining(),
              color: const Color(0xFF2E4E8E),
            ),
            const SizedBox(height: 16),
          ],
          if (live.cleanedReady && !live.croppedReady && !live.cropping) ...[
            const Text(
              'Cropping template',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            DropdownButton<CropTemplate>(
              value: _selectedCropTemplate,
              items: CropTemplate.values.map((template) {
                return DropdownMenuItem<CropTemplate>(
                  value: template,
                  enabled: template.isImplemented,
                  child: Text(
                    template.isImplemented
                        ? template.label
                        : '${template.label} (coming soon)',
                    style: TextStyle(
                      color:
                          template.isImplemented ? Colors.black : Colors.grey,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (template) {
                if (template == null) return;
                setState(() => _selectedCropTemplate = template);
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 260,
              child: ElevatedButton.icon(
                onPressed: _triggeringCrop ? null : () => _runCrop(live),
                icon: _triggeringCrop
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.crop),
                label: Text(_triggeringCrop ? 'Starting…' : 'Crop'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E4E8E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            if (_cropTriggerError != null) ...[
              const SizedBox(height: 8),
              Text(_cropTriggerError!,
                  style: const TextStyle(color: Colors.red, fontSize: 12)),
            ],
            if (live.cropStatus == 'failed' && live.cropError != null) ...[
              const SizedBox(height: 8),
              Text('Last attempt failed: ${live.cropError}',
                  style: const TextStyle(color: Colors.red, fontSize: 12)),
            ],
          ],
        ],
      ),
    );
  }

  Widget _statChip(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(value,
            style:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

/// Shared progress row for both the clean and crop jobs: "N / total
/// pages" label, a linear progress bar, and an ETA once one can be
/// computed.
class _JobProgress extends StatelessWidget {
  const _JobProgress({
    required this.label,
    required this.progress,
    required this.done,
    required this.total,
    required this.remaining,
    required this.color,
  });

  final String label;
  final double progress;
  final int done;
  final int total;
  final Duration? remaining;
  final Color color;

  String _formatRemaining(Duration d) {
    final minutes = (d.inSeconds / 60).ceil();
    if (minutes <= 0) return 'less than a minute left';
    if (minutes == 1) return '~1 min left';
    return '~$minutes min left';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$label… $done / $total pages',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            if (remaining != null)
              Text(_formatRemaining(remaining!),
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _VariantTile extends StatelessWidget {
  const _VariantTile({
    required this.variant,
    required this.enabled,
    required this.onTap,
    this.processing = false,
  });

  final ScanVariant variant;
  final bool enabled;
  final bool processing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Opacity(
        opacity: enabled ? 1.0 : 0.45,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            children: [
              Icon(
                Icons.folder,
                size: 40,
                color: enabled ? const Color(0xFFB5651D) : Colors.grey,
              ),
              const SizedBox(height: 10),
              Text(variant.label,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              if (processing) ...[
                const SizedBox(height: 6),
                const Text('Processing…',
                    style: TextStyle(fontSize: 11, color: Colors.grey)),
              ] else if (!enabled) ...[
                const SizedBox(height: 6),
                const Text('Not available yet',
                    style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}