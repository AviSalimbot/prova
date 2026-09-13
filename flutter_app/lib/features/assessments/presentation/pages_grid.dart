// lib/features/assessments/presentation/pages_grid.dart
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/drive_import_service.dart';
import '../data/exams_repository.dart';
import '../domain/assessment.dart';
import 'drive_connect.dart';
import 'page_preview_dialog.dart';

/// The "Assessments / Activity 1.1 / P001" page-thumbnail grid. Each
/// tile downloads and displays its own scan directly, so before any
/// tile is built this widget confirms a live Drive session itself —
/// it can't assume the import flow already ran this session (e.g.
/// after a hot restart, or when the assessment being viewed was
/// imported in an earlier session entirely).
class PagesGrid extends ConsumerStatefulWidget {
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
  ConsumerState<PagesGrid> createState() => _PagesGridState();
}

class _PagesGridState extends ConsumerState<PagesGrid> {
  /// null = still checking, true = confirmed connected, false = needs
  /// the person to connect.
  bool? _connected;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkConnection());
  }

  Future<void> _checkConnection() async {
    final ok = await ensureDriveConnected(context, ref);
    if (mounted) setState(() => _connected = ok);
  }

  @override
  Widget build(BuildContext context) {
    if (_connected == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_connected == false) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Connect Google Drive to view these scans.'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _checkConnection,
              child: const Text('Connect Google Drive'),
            ),
          ],
        ),
      );
    }

    final pagesAsync = ref.watch(pagesStreamProvider(widget.participant.id));

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
            // Was 0.85 (near-square), which is why BoxFit.cover had to
            // crop tall scanned pages to fill the tile. A4/Letter pages
            // run roughly 0.7–0.78 (width÷height), so the tile itself
            // is shaped closer to the real page now, and combined with
            // BoxFit.contain below, the full page shows uncropped with
            // its natural proportions — height genuinely follows width
            // rather than being forced to match a fixed box.
            // Lowered further (0.72 -> 0.5) to make each tile taller,
            // giving the scanned page image more vertical room since
            // childAspectRatio is width÷height: a smaller value means
            // a taller tile for the same column width.
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
                  participantCode: widget.participant.code,
                  page: page,
                  variant: widget.variant,
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
                            fileId: page.fileIdFor(widget.variant),
                            variant: widget.variant,
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
                              fontWeight: FontWeight.bold,
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
/// loading/error state never affects its neighbors. By the time this
/// is built, PagesGrid has already confirmed a live Drive session, so
/// pageBytesProvider won't hit the "not signed in" StateError here.
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
        // CHANGED from BoxFit.cover: cover crops the image to fill the
        // tile edge-to-edge, cutting off content on pages whose
        // proportions don't exactly match the tile. contain scales the
        // whole page down to fit within the tile with nothing cropped
        // — its displayed height is always proportional to its width,
        // it just may not fill every pixel of the tile (letterboxing
        // on the shorter axis), which is preferable to losing content.
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
      ),
    );
  }
}