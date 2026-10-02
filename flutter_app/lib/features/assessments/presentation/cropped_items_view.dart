// lib/features/assessments/presentation/cropped_items_view.dart
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/drive_import_service.dart';
import '../data/exams_repository.dart';
import '../domain/assessment.dart';
import 'drive_connect.dart';

/// Cropped tree, level 3: "Assessments / Activity 1.1 / Cropped / P001".
/// Lists the participant's item folders (N001, N002, ...) the same way
/// the participants list shows P001, P002, ... Reads only Firestore, so
/// no Drive session is needed at this level.
class CroppedItemFolders extends ConsumerWidget {
  const CroppedItemFolders({
    super.key,
    required this.participant,
    required this.onOpen,
  });

  final Participant participant;
  final ValueChanged<CroppedItem> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(croppedItemsStreamProvider(participant.id));

    return itemsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Failed to load items: $e')),
      data: (items) {
        if (items.isEmpty) {
          return const Center(
            child: Text('No cropped items for this participant yet.'),
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
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final item = items[i];
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
                      item.label,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${item.imageCount} images',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
                onTap: () => onOpen(item),
              );
            },
          ),
        );
      },
    );
  }
}

/// Cropped tree, level 4: "... / P001 / N001". The item's solution crops
/// (Solution 1, Solution 2, ...) followed by its Final Answer crop.
/// Downloads each image from Drive, so — like PagesGrid — it confirms a
/// live Drive session before building any tile.
class CroppedItemImages extends ConsumerStatefulWidget {
  const CroppedItemImages({
    super.key,
    required this.participant,
    required this.item,
  });

  final Participant participant;
  final CroppedItem item;

  @override
  ConsumerState<CroppedItemImages> createState() => _CroppedItemImagesState();
}

class _CroppedItemImagesState extends ConsumerState<CroppedItemImages> {
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
            const Text('Connect Google Drive to view these crops.'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _checkConnection,
              child: const Text('Connect Google Drive'),
            ),
          ],
        ),
      );
    }

    final tiles = <({String title, String fileId})>[
      for (var i = 0; i < widget.item.solutionFileIds.length; i++)
        (title: 'Solution ${i + 1}', fileId: widget.item.solutionFileIds[i]),
      if (widget.item.answerFileId != null)
        (title: 'Final answer', fileId: widget.item.answerFileId!),
    ];

    if (tiles.isEmpty) {
      return const Center(child: Text('This item has no cropped images.'));
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 420,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: tiles.length,
      itemBuilder: (context, i) {
        final tile = tiles[i];
        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => showDialog(
            context: context,
            builder: (_) => _CropPreviewDialog(
              title:
                  '${widget.participant.code} · ${widget.item.label} · ${tile.title}',
              fileId: tile.fileId,
            ),
          ),
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
                      child: _CropImage(fileId: tile.fileId),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(tile.title),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// One downloaded crop. Scoped as its own widget so each tile's loading
/// or error state is independent of its neighbours.
class _CropImage extends ConsumerWidget {
  const _CropImage({required this.fileId});

  final String fileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytesAsync = ref.watch(pageBytesProvider(fileId));

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
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
      ),
    );
  }
}

class _CropPreviewDialog extends ConsumerWidget {
  const _CropPreviewDialog({required this.title, required this.fileId});

  final String title;
  final String fileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = MediaQuery.of(context).size;
    final bytesAsync = ref.watch(pageBytesProvider(fileId));

    return Dialog(
      backgroundColor: const Color(0xFFFAF9F4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: size.width * 0.6,
        height: size.height * 0.8,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      ScanVariant.cropped.label,
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
            Expanded(
              child: bytesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Failed to load image: $e')),
                data: (bytes) => InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 6,
                  child: Center(
                    child: Image.memory(
                      Uint8List.fromList(bytes),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 12, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Material(
                  color: const Color(0xFF1F2430),
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => Navigator.pop(context),
                    child: const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Text(
                        'Close',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
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
