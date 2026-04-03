import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'manga_page_widget.dart';
import '../../core/providers/fullscreen_provider.dart';

class NativeImageReaderScreen extends ConsumerStatefulWidget {
  final List<String> imageUrls;
  final String mangaTitle;

  const NativeImageReaderScreen({
    super.key,
    required this.imageUrls,
    this.mangaTitle = 'Bilder lesen',
  });

  @override
  ConsumerState<NativeImageReaderScreen> createState() => _NativeImageReaderScreenState();
}

class _NativeImageReaderScreenState extends ConsumerState<NativeImageReaderScreen> {

  void _toggleFullscreen() {
      final isFull = ref.read(fullscreenProvider);
      ref.read(fullscreenProvider.notifier).state = !isFull;
      if (!isFull) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(fullscreenProvider.notifier).state = false;
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isFullscreen = ref.watch(fullscreenProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
              title: Text(widget.mangaTitle, style: const TextStyle(color: Colors.white)),
              backgroundColor: Colors.black.withAlpha(200),
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.white),
              actions: [
                IconButton(
                  icon: Icon(isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen),
                  onPressed: _toggleFullscreen,
                  tooltip: 'Vollbild',
                ),
              ],
            ),
      body: Stack(
        children: [
          InteractiveViewer(
            minScale: 1.0,
            maxScale: 4.0,
            child: ListView.builder(
              itemCount: widget.imageUrls.length,
              itemBuilder: (context, index) {
                return MangaPageWidget(
                  imageUrl: widget.imageUrls[index],
                  mangaTitle: widget.mangaTitle,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
