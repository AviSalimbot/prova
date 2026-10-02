import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/exams_repository.dart';
import '../domain/assessment.dart';

/// The "Assessments / Activity 1.1" participant-folder list.
class ParticipantsList extends ConsumerWidget {
  const ParticipantsList({
    super.key,
    required this.assessment,
    required this.onOpen,
  });

  final Assessment assessment;
  final ValueChanged<Participant> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final participantsAsync =
        ref.watch(participantsStreamProvider(assessment.id));

    return participantsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Failed to load participants: $e')),
      data: (participants) {
        if (participants.isEmpty) {
          return const Center(
            child: Text(
              'No participants yet — use "Import assessment" to pull them '
              'in from Drive.',
            ),
          );
        }

        return Container(
          margin: const EdgeInsets.only(top: 4),
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
          clipBehavior: Clip.antiAlias,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
            itemCount: participants.length,
            separatorBuilder: (_, __) => const SizedBox.shrink(),
            itemBuilder: (context, i) {
              final p = participants[i];
              final isComplete = p.status == AssessmentStatus.complete;

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(),
                leading: SvgPicture.asset(
                  'assets/images/folder.svg',
                  width: 28,
                  height: 28,
                ),
                title: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      p.code,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${p.pageCount} pages',
                      style:
                          const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isComplete
                        ? Colors.green.shade50
                        : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    p.status.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isComplete
                          ? Colors.green.shade800
                          : Colors.orange.shade800,
                    ),
                  ),
                ),
                onTap: () => onOpen(p),
              );
            },
          ),
        );
      },
    );
  }
}














// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:flutter_svg/flutter_svg.dart';

// import '../data/exams_repository.dart';
// import '../domain/assessment.dart';

// /// The "Assessments / Activity 1.1" participant-folder list.
// class ParticipantsList extends ConsumerWidget {
//   const ParticipantsList({
//     super.key,
//     required this.assessment,
//     required this.onOpen,
//     this.variant = ScanVariant.raw,
//   });

//   final Assessment assessment;
//   final ValueChanged<Participant> onOpen;

//   /// In the Cropped tree a participant folder holds item folders (N001,
//   /// N002, ...) instead of pages, so the count label changes.
//   final ScanVariant variant;

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     final participantsAsync =
//         ref.watch(participantsStreamProvider(assessment.id));

//     return participantsAsync.when(
//       loading: () => const Center(child: CircularProgressIndicator()),
//       error: (e, _) => Center(child: Text('Failed to load participants: $e')),
//       data: (participants) {
//         if (participants.isEmpty) {
//           return const Center(
//             child: Text(
//               'No participants yet — use "Import assessment" to pull them '
//               'in from Drive.',
//             ),
//           );
//         }

//         return Container(
//           margin: const EdgeInsets.only(top: 4),
//           decoration: BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.circular(12),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black.withOpacity(0.06),
//                 blurRadius: 8,
//                 offset: const Offset(0, 2),
//               ),
//             ],
//           ),
//           clipBehavior: Clip.antiAlias,
//           child: ListView.separated(
//             padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
//             itemCount: participants.length,
//             separatorBuilder: (_, __) => const SizedBox.shrink(),
//             itemBuilder: (context, i) {
//               final p = participants[i];
//               final isComplete = p.status == AssessmentStatus.complete;

//               return ListTile(
//                 contentPadding: const EdgeInsets.symmetric(),
//                 leading: SvgPicture.asset(
//                   'assets/images/folder.svg',
//                   width: 28,
//                   height: 28,
//                 ),
//                 title: Row(
//                   crossAxisAlignment: CrossAxisAlignment.baseline,
//                   textBaseline: TextBaseline.alphabetic,
//                   children: [
//                     Text(
//                       p.code,
//                       style: const TextStyle(fontWeight: FontWeight.bold),
//                     ),
//                     const SizedBox(width: 10),
//                     Text(
//                       variant == ScanVariant.cropped
//                           ? '${p.croppedItemCount} items'
//                           : '${p.pageCount} pages',
//                       style:
//                           const TextStyle(fontSize: 13, color: Colors.grey),
//                     ),
//                   ],
//                 ),
//                 trailing: Container(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 10,
//                     vertical: 4,
//                   ),
//                   decoration: BoxDecoration(
//                     color: isComplete
//                         ? Colors.green.shade50
//                         : Colors.orange.shade50,
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                   child: Text(
//                     p.status.label,
//                     style: TextStyle(
//                       fontSize: 12,
//                       fontWeight: FontWeight.bold,
//                       color: isComplete
//                           ? Colors.green.shade800
//                           : Colors.orange.shade800,
//                     ),
//                   ),
//                 ),
//                 onTap: () => onOpen(p),
//               );
//             },
//           ),
//         );
//       },
//     );
//   }
// }