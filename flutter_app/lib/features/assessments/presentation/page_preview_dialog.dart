import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/drive_import_service.dart';
import '../data/exams_repository.dart';
import '../domain/assessment.dart';
import 'page_preview_dialog.dart';

/// The "Assessments / Activity 1.1 / P001" page-thumbnail grid. Each
/// tile now downloads and displays its own scan directly — see the
/// perf note below if participant page counts grow large, since this
/// means one authenticated Drive request per visible tile rather than
/// only on click.
class PagesGrid extends ConsumerWidget {
  const PagesGrid({
    super.key,
    required this.assessment,
    required this.participant,
    required this.variant,
  });

  final Assessment assessment;
  final Participant participant;
  final ScanVariant variant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pagesAsync = ref.watch(pagesStreamProvider(participant.id));

    return pagesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Failed to load pages: $e')),
      data: (pages) {
        if (pages.isEmpty) {
          return const Center(child: Text('No scanned pages found.'));
        }

        return GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            // Settled at 0.64 after tuning: 0.85 (near-square) let
            // BoxFit.cover crop tall pages, 0.72 was closer but still
            // cramped, 0.5 was too tall. 0.64 is width÷height, so
            // tiles are taller than they are wide, giving the scanned
            // page image the vertical room it needs without going
            // overboard.
            childAspectRatio: 0.64,
          ),
          itemCount: pages.length,
          itemBuilder: (context, i) {
            final page = pages[i];
            final isScannedOk = page.scanStatus == 'scanned_ok';

            return InkWell(
              onTap: () => showDialog(
                context: context,
                builder: (_) => PagePreviewDialog(
                  participantCode: participant.code,
                  page: page,
                  variant: variant,
                ),
              ),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          width: double.infinity,
                          color: Colors.grey.shade100,
                          child: _PageThumbnail(
                            fileId: page.fileIdFor(variant),
                            variant: variant,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Page ${page.pageNumber}'),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isScannedOk
                                ? Colors.green.shade50
                                : Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            isScannedOk ? 'Scanned OK' : page.scanStatus,
                            style: TextStyle(
                              fontSize: 10,
                              color: isScannedOk
                                  ? Colors.green.shade800
                                  : Colors.orange.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Downloads and renders the actual scan for a single tile. Kept as its
/// own widget (rather than inline in itemBuilder) so each tile's
/// pageBytesProvider watch is scoped independently — one tile's
/// loading/error state never affects its neighbors.
class _PageThumbnail extends ConsumerWidget {
  const _PageThumbnail({required this.fileId, required this.variant});

  final String? fileId;
  final ScanVariant variant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (fileId == null) {
      return Center(
        child: Text(
          'No ${variant.label} scan',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey, fontSize: 11),
        ),
      );
    }

    final bytesAsync = ref.watch(pageBytesProvider(fileId!));

    return bytesAsync.when(
      loading: () => const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (e, _) => const Center(
        child: Icon(Icons.broken_image_outlined, color: Colors.grey),
      ),
      data: (bytes) => Image.memory(
        Uint8List.fromList(bytes),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      ),
    );
  }
}

/// The full-size scan preview modal shown when a page thumbnail is
/// tapped. Only this dialog actually downloads image bytes from Drive —
/// and only for the single requested [variant].
///
/// Styling notes:
/// - Plain [Dialog] instead of [AlertDialog] so the header and footer
///   rows can be given their own tight padding instead of inheriting
///   AlertDialog's generous default title/actions insets.
/// - White background, explicit and taller [SizedBox] so the image has
///   real room instead of being squeezed into a 500x500 square.
/// - Title text is smaller; "Raw"/variant label is pulled out into its
///   own small gray chip rather than being part of the title string.
/// - Image sizing uses FittedBox(fit: BoxFit.contain) so the picture
///   keeps its natural width/height ratio and is never stretched or
///   cropped to fill a fixed box.
/// - Wrapped in InteractiveViewer so the person can pinch/scroll-zoom
///   and pan to read fine handwriting.
class PagePreviewDialog extends ConsumerWidget {
  const PagePreviewDialog({
    super.key,
    required this.participantCode,
    required this.page,
    required this.variant,
  });

  final String participantCode;
  final AssessmentPage page;
  final ScanVariant variant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fileId = page.fileIdFor(variant);
    final screenSize = MediaQuery.of(context).size;

    return Dialog(
      backgroundColor: Colors.white,
      child: SizedBox(
        width: 450,
        // Taller than the old fixed 500, and capped relative to the
        // viewport so it still fits on smaller screens.
        height: screenSize.height * 0.85,
        child: Column(
          children: [
            // Header row: kept short (tight vertical padding) instead
            // of AlertDialog's default title padding.
            Padding(
              padding: const EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: 10,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '$participantCode · page ${page.pageNumber}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // "Raw"/variant label as a small gray chip instead of
                  // being folded into the title text.
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      variant.label,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.white),
            Expanded(
              child: fileId == null
                  ? Center(
                      child: Text(
                        'No ${variant.label} scan available for this page.',
                      ),
                    )
                  : _PreviewImage(fileId: fileId),
            ),
            const Divider(height: 1, color: Colors.white),
            // Footer row: same tight-padding treatment as the header,
            // instead of AlertDialog's default actions insets.
            Padding(
              padding: const EdgeInsets.only(
                left: 12,
                right: 12,
                top: 4,
                bottom: 8,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Close',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewImage extends ConsumerWidget {
  const _PreviewImage({required this.fileId});

  final String fileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytesAsync = ref.watch(pageBytesProvider(fileId));

    return bytesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Failed to load image: $e')),
      data: (bytes) => InteractiveViewer(
        minScale: 0.5,
        maxScale: 5,
        child: FittedBox(
          // FittedBox scales its child to the available space while
          // preserving the child's own intrinsic aspect ratio — the
          // image is never stretched to fill a fixed square, its
          // displayed width and height stay proportional to the
          // source scan.
          fit: BoxFit.contain,
          child: Image.memory(Uint8List.fromList(bytes)),
        ),
      ),
    );
  }
}