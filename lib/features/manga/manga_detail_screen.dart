import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/manga_source.dart';
import '../../core/services/offline_manager.dart';
import '../../core/services/streak_service.dart';
import '../reader/reader_screen.dart';

class MangaDetailScreen extends ConsumerStatefulWidget {
  final Manga manga;
  final MangaSource? source;

  const MangaDetailScreen({super.key, required this.manga, this.source});

  @override
  ConsumerState<MangaDetailScreen> createState() => _MangaDetailScreenState();
}

class _MangaDetailScreenState extends ConsumerState<MangaDetailScreen> {
  final Set<String> _downloadingChapters = {};
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    _checkSavedState();
  }

  Future<void> _checkSavedState() async {
    final isSaved = await ref.read(offlineManagerProvider).isMangaSaved(widget.manga.url);
    if (mounted) {
      setState(() => _isSaved = isSaved);
    }
  }

  Future<void> _readChapter(Chapter chapter, List<Chapter> chapters, MangaSource source) async {
    // Record activity
    ref.read(recentActivityProvider.notifier).record(RecentActivity(
      id: 'manga_${widget.manga.title}',
      type: 'manga',
      title: widget.manga.title,
      subtitle: 'Kapitel: ${chapter.title}',
      imageUrl: widget.manga.coverUrl,
      metadata: {
        'url': widget.manga.url,
        'chapterUrl': chapter.url,
        'title': widget.manga.title,
      },
      timestamp: DateTime.now().millisecondsSinceEpoch,
    ));

    if (!context.mounted) return;
    // Open ReaderScreen with chapter navigation and OCR (via MangaPageWidget)
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ReaderScreen(
        initialChapter: chapter,
        chapters: chapters,
        mangaTitle: widget.manga.title,
        source: source,
      ),
    ));
  }

  Future<void> _download(Chapter chapter) async {
    setState(() => _downloadingChapters.add(chapter.url));
    try {
      final activeSource = widget.source ?? ref.read(mangaSourceProvider);
      await ref.read(offlineManagerProvider).downloadChapter(widget.manga, chapter, source: activeSource);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${chapter.title} heruntergeladen')));
        _checkSavedState(); // Downloading also saves it
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _downloadingChapters.remove(chapter.url));
      }
    }
  }

  Future<void> _toggleFavorite() async {
    try {
      if (_isSaved) {
        await ref.read(offlineManagerProvider).removeMangaFromLibrary(widget.manga.url);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aus Bibliothek entfernt')));
        }
      } else {
         await ref.read(offlineManagerProvider).saveMangaToLibrary(widget.manga);
         if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Zur Bibliothek hinzugefügt')));
         }
      }
      _checkSavedState();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mangaSource = ref.watch(mangaSourceProvider);
    final activeSource = widget.source ?? mangaSource;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.manga.title),
        actions: [
          IconButton(
            icon: Icon(_isSaved ? Icons.favorite : Icons.favorite_border),
            color: _isSaved ? Colors.red : null,
            onPressed: _toggleFavorite,
            tooltip: _isSaved ? 'Aus Bibliothek entfernen' : 'Zur Bibliothek hinzufügen',
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.network(
                  widget.manga.coverUrl,
                  height: 150,
                  width: 100,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_not_supported, size: 100),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.manga.title, style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      // Add more metadata here (author, genres, etc.)
                    ],
                  ),
                )
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: FutureBuilder<List<Chapter>>(
              future: activeSource.fetchChapters(widget.manga.url),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Fehler: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('Keine Kapitel gefunden'));
                }

                final chapters = snapshot.data!;
                return ListView.builder(
                  itemCount: chapters.length,
                  itemBuilder: (context, index) {
                    final chapter = chapters[index];
                    final isDownloading = _downloadingChapters.contains(chapter.url);
                    
                    return ListTile(
                      title: Text(chapter.title),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isDownloading)
                            const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                          else
                            IconButton(icon: const Icon(Icons.download), onPressed: () => _download(chapter)),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                      onTap: () => _readChapter(chapter, chapters, activeSource),
                    );
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
