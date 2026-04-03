import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import "manga_page_widget.dart";
import '../../core/network/manga_source.dart';
import '../../core/providers/fullscreen_provider.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  final Chapter initialChapter;
  final List<Chapter> chapters;
  final String mangaTitle;
  final MangaSource? source;

  const ReaderScreen({
    super.key, 
    required this.initialChapter, 
    required this.chapters, 
    this.mangaTitle = 'Unknown Manga',
    this.source,
  });

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  late Chapter currentChapter;
  late int currentIndex;
  final ScrollController _scrollController = ScrollController();

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
  void initState() {
    super.initState();
    currentChapter = widget.initialChapter;
    currentIndex = widget.chapters.indexWhere((c) => c.url == currentChapter.url);
    if (currentIndex == -1) currentIndex = 0; // Fallback
  }

  void _goToChapter(int index) {
      if (index < 0 || index >= widget.chapters.length) return;
      setState(() {
          currentIndex = index;
          currentChapter = widget.chapters[index];
      });
      // Scroll to top when changing chapter
      if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
      }
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(fullscreenProvider.notifier).state = false;
    });
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mangaSource = ref.watch(mangaSourceProvider);
    final activeSource = widget.source ?? mangaSource;
    final isFullscreen = ref.watch(fullscreenProvider);
    
    final hasNext = currentIndex > 0; // Chapters are in descending order (0 is latest)
    final hasPrev = currentIndex < widget.chapters.length - 1;

    return Scaffold(
      backgroundColor: Colors.black, // Dark background for reader
      appBar: AppBar(
        title: DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            value: currentIndex,
            dropdownColor: Colors.black87,
            icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
            style: const TextStyle(color: Colors.white, fontSize: 18),
            isExpanded: true,
            onChanged: (int? newIndex) {
              if (newIndex != null) _goToChapter(newIndex);
            },
            items: List.generate(widget.chapters.length, (index) {
              return DropdownMenuItem<int>(
                value: index,
                child: Text(
                  widget.chapters[index].title,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }),
          ),
        ),
        backgroundColor: Colors.black.withAlpha(200), // Less transparent to see dropdown better
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen),
            color: Colors.white,
            tooltip: 'Vollbild umschalten',
            onPressed: _toggleFullscreen,
          ),
          IconButton(
            icon: const Icon(Icons.skip_previous),
            color: hasPrev ? Colors.white : Colors.white30,
            tooltip: 'Previous Chapter',
            onPressed: hasPrev ? () => _goToChapter(currentIndex + 1) : null, // +1 because array is descending
          ),
          IconButton(
            icon: const Icon(Icons.skip_next),
            color: hasNext ? Colors.white : Colors.white30,
            tooltip: 'Next Chapter',
            onPressed: hasNext ? () => _goToChapter(currentIndex - 1) : null,
          ),
        ],
      ),
      // Removed extendBodyBehindAppBar so top controls aren't covered by image
      body: Stack(
        children: [
          FutureBuilder<List<String>>(
        future: activeSource.fetchPageUrls(currentChapter.url),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No pages found', style: TextStyle(color: Colors.white)));
          }

          final pages = snapshot.data!;

          return InteractiveViewer(
             minScale: 1.0,
             maxScale: 4.0,
             child: ListView.builder(
              controller: _scrollController,
              itemCount: pages.length + 1, // +1 for the bottom navigation buttons
              itemBuilder: (context, index) {
                if (index == pages.length) {
                   // Bottom navigation area
                   return Container(
                     padding: const EdgeInsets.all(24.0),
                     color: Colors.black,
                     child: Row(
                       mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                       children: [
                         ElevatedButton.icon(
                           onPressed: hasPrev ? () => _goToChapter(currentIndex + 1) : null,
                           icon: const Icon(Icons.skip_previous),
                           label: const Text('Previous Chapter'),
                           style: ElevatedButton.styleFrom(
                             backgroundColor: Colors.grey[800],
                             foregroundColor: Colors.white,
                           ),
                         ),
                         ElevatedButton.icon(
                           onPressed: hasNext ? () => _goToChapter(currentIndex - 1) : null,
                           icon: const Icon(Icons.skip_next),
                           label: const Text('Next Chapter'),
                           style: ElevatedButton.styleFrom(
                             backgroundColor: Theme.of(context).primaryColor,
                             foregroundColor: Colors.white,
                           ),
                         ),
                       ],
                     ),
                   );
                }
                return MangaPageWidget(imageUrl: pages[index], mangaTitle: widget.mangaTitle);
              },
            ),
          );
        },
      ),
      ],
    ),
    );
  }
}
