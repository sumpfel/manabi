import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/network/manga_source.dart';
import '../../core/i18n/app_strings.dart';
import '../../core/services/settings_service.dart';
import '../../core/services/streak_service.dart';
import '../reader/webview_reader_screen.dart';
import 'manga_detail_screen.dart';
import 'dart:async';

import '../../core/services/offline_manager.dart';
import '../../core/providers/fullscreen_provider.dart';

int _savedMangaTabIndex = 0;

class MangaReaderScreen extends ConsumerStatefulWidget {
  const MangaReaderScreen({super.key});

  @override
  ConsumerState<MangaReaderScreen> createState() => _MangaReaderScreenState();
}

class _MangaReaderScreenState extends ConsumerState<MangaReaderScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  late TabController _tabController;
  Timer? _debounce;
  String _searchQuery = '';

  // Pagination state MangaDex
  Future<List<Manga>>? _exploreFuture;
  final List<Manga> _loadedMangaDex = [];
  int _currentPageMangaDex = 1;
  bool _isLoadingMoreMangaDex = false;
  bool _hasMoreMangaDex = true;

  // Library refresh key — incremented to force FutureBuilder rebuild
  int _libraryRefreshKey = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: _savedMangaTabIndex.clamp(0, 3));
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _savedMangaTabIndex = _tabController.index;
        // Refresh library when switching to bookmarks tab
        if (_tabController.index == 3) {
          setState(() => _libraryRefreshKey++);
        }
      }
    });
    _refreshExplore();
  }

  void _refreshExplore() {
    final mangaSource = ref.read(mangaSourceProvider);
    setState(() {
      _exploreFuture = _searchQuery.isEmpty ? mangaSource.fetchPopularManga(1) : mangaSource.searchManga(_searchQuery);
    });
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _searchQuery = query;
        // Reset pagination on new search
        _loadedMangaDex.clear();
        _currentPageMangaDex = 1;
        _hasMoreMangaDex = true;
        _refreshExplore();
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _urlController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMore(MangaSource source) async {
    if (_isLoadingMoreMangaDex || !_hasMoreMangaDex) return;
    setState(() => _isLoadingMoreMangaDex = true);
    try {
      final result = await source.fetchPopularManga(_currentPageMangaDex);
      setState(() {
        _loadedMangaDex.addAll(result);
        _currentPageMangaDex++;
        _hasMoreMangaDex = result.length >= 20;
        _isLoadingMoreMangaDex = false;
      });
    } catch (e) {
      setState(() => _isLoadingMoreMangaDex = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mangaSource = ref.watch(mangaSourceProvider);
    final offlineManager = ref.watch(offlineManagerProvider);
    final s = AppStrings(ref.watch(settingsProvider).appLanguage);
    final isFullscreen = ref.watch(fullscreenProvider);

    return Scaffold(
        appBar: isFullscreen ? null : AppBar(
          title: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: s.searchManga,
              border: InputBorder.none,
              icon: const Icon(Icons.search),
            ),
            onChanged: _onSearchChanged,
          ),
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'MangaDex'),
              const Tab(text: 'Raw Kuma'),
              Tab(text: 'Eigene URL'),
              Tab(text: 'Lesezeichen'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            // TAB 1: EXPLORE (MangaDex) with pagination
            FutureBuilder<List<Manga>>(
              future: _exploreFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && _loadedMangaDex.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError && _loadedMangaDex.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.cloud_off, size: 64, color: Colors.redAccent),
                          const SizedBox(height: 16),
                          Text(s.noMangaFound, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text('Fehler: ${snapshot.error}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _refreshExplore,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Erneut versuchen'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // Seed initial data
                if (snapshot.hasData && _loadedMangaDex.isEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_loadedMangaDex.isEmpty) {
                      setState(() {
                        _loadedMangaDex.addAll(snapshot.data!);
                        _currentPageMangaDex = 2;
                        _hasMoreMangaDex = snapshot.data!.length >= 20;
                      });
                    }
                  });
                  return _buildMangaGridWithLoadMore(_loadedMangaDex, s, mangaSource, _isLoadingMoreMangaDex, _hasMoreMangaDex);
                }

                if (_loadedMangaDex.isEmpty) {
                  return Center(child: Text(s.noMangaFound));
                }

                return _buildMangaGridWithLoadMore(_loadedMangaDex, s, mangaSource, _isLoadingMoreMangaDex, _hasMoreMangaDex);
              },
            ),
            // TAB 2: RAW KUMA
            const WebviewReaderScreen(url: 'https://rawkuma.net', title: 'Raw Kuma', showBackButton: false),
            // TAB 3: EIGENE URL
            _buildCustomUrlTab(context, s),
            // TAB 4: LESEZEICHEN
            _buildLibraryTab(context, s, offlineManager),
          ],
      ),
    );
  }

  Widget _buildLibraryTab(BuildContext context, AppStrings s, OfflineManager offlineManager) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Meine Bibliothek', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          FutureBuilder<List<Manga>>(
            key: ValueKey('library_$_libraryRefreshKey'),
            future: offlineManager.getLibraryMangas(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text('Fehler: ${snapshot.error}'));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(child: Text(s.libraryEmpty));
              }

              final filtered = snapshot.data!.where((m) => m.title.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
              if (filtered.isEmpty) {
                return Center(child: Text(s.noMangaFound));
              }
              return GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.7,
                ),
                itemCount: filtered.length,
                itemBuilder: (context, index) => _buildMangaCard(context, filtered[index], null),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCustomUrlTab(BuildContext context, AppStrings s) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Eigene URL', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            s.enterUrlHint,
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _urlController,
            decoration: InputDecoration(
              labelText: s.mangaUrl,
              hintText: 'z.B. https://rawkuma.net',
              prefixIcon: const Icon(Icons.link),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.open_in_browser),
            label: Text(s.openInBrowser),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            onPressed: () async {
              final url = _urlController.text.trim();
              if (url.isEmpty) return;
              final finalUrl = url.startsWith('http') ? url : 'https://$url';
              await Navigator.push(context, MaterialPageRoute(
                builder: (_) => WebviewReaderScreen(url: finalUrl, title: 'Eigene URL'),
              ));
              setState(() => _libraryRefreshKey++);
            },
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),
          const Text('Schnellzugriff', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: [
              _quickLink(context, 'Raw Kuma', 'https://rawkuma.net', s),
              _quickLink(context, 'Manga Raw', 'https://mangaraw.org', s),
              _quickLink(context, 'Syosetu', 'https://syosetu.com', s),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _quickLink(BuildContext context, String name, String url, AppStrings s) {
    return ActionChip(
      avatar: const Icon(Icons.open_in_new, size: 16),
      label: Text(name),
      onPressed: () async {
        await Navigator.push(context, MaterialPageRoute(
          builder: (_) => WebviewReaderScreen(url: url, title: name),
        ));
        setState(() => _libraryRefreshKey++);
      },
    );
  }

  Widget _buildMangaGridWithLoadMore(
    List<Manga> mangas,
    AppStrings s,
    MangaSource source,
    bool isLoadingMore,
    bool hasMore,
  ) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(8),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.7,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildMangaCard(context, mangas[index], source),
              childCount: mangas.length,
            ),
          ),
        ),
        if (hasMore && _searchQuery.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: isLoadingMore
                  ? const CircularProgressIndicator()
                  : ElevatedButton.icon(
                      icon: const Icon(Icons.add),
                      label: Text(s.loadMore),
                      onPressed: () => _loadMore(source),
                    ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMangaCard(BuildContext context, Manga manga, MangaSource? source) {
    return GestureDetector(
      onLongPress: source == null ? () {
         showDialog(
           context: context,
           builder: (dialogContext) => AlertDialog(
             title: const Text('Lesezeichen entfernen?'),
             content: Text('Möchtest du "${manga.title}" aus deinen Lesezeichen entfernen?'),
             actions: [
               TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Abbrechen')),
               TextButton(
                 onPressed: () async {
                   final offlineManager = ref.read(offlineManagerProvider);
                   await offlineManager.removeMangaFromLibrary(manga.url);
                   if (dialogContext.mounted) Navigator.pop(dialogContext);
                   setState(() => _libraryRefreshKey++); // Triggers a rebuild of the library
                 },
                 child: const Text('Entfernen', style: TextStyle(color: Colors.red)),
               ),
             ],
           )
         );
      } : null,
      onTap: () async {
        if (manga.source == 'Custom URL') {
           await Navigator.push(context, MaterialPageRoute(
             builder: (context) => WebviewReaderScreen(url: manga.url, title: manga.title),
           ));
        } else if (manga.source == 'Raw Kuma') {
           final rawkumaSource = ref.read(rawkumaSourceProvider);
           await Navigator.push(context, MaterialPageRoute(
             builder: (context) => MangaDetailScreen(manga: manga, source: rawkumaSource),
           ));
        } else {
           await Navigator.push(context, MaterialPageRoute(
             builder: (context) => MangaDetailScreen(manga: manga, source: source),
           ));
        }
        // Refresh library when returning from any manga screen
        setState(() => _libraryRefreshKey++);
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: manga.coverUrl.isEmpty
                ? const Icon(Icons.image_not_supported, size: 50)
                : Image.network(
                    manga.coverUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_not_supported),
                  ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                manga.title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
