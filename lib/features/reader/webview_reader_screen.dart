import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import '../../core/providers/fullscreen_provider.dart';
import 'dart:ui' as ui;
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;
import 'native_image_reader_screen.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/database/database_service.dart';
import '../../core/models/saved_manga.dart';
import '../../core/network/manga_source.dart';
import '../../core/services/streak_service.dart';
import '../manga/manga_detail_screen.dart';
import 'translation_bottom_sheet.dart';

/// Full-screen WebView for browsing arbitrary manga sites.
class WebviewReaderScreen extends ConsumerStatefulWidget {
  final String url;
  final String title;
  final bool showBackButton;

  const WebviewReaderScreen({super.key, required this.url, this.title = 'Manga', this.showBackButton = true});

  @override
  ConsumerState<WebviewReaderScreen> createState() => _WebviewReaderScreenState();
}

class _WebviewReaderScreenState extends ConsumerState<WebviewReaderScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String _currentUrl = '';
  final GlobalKey _globalKey = GlobalKey();

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
  void initState() {
    super.initState();
    _currentUrl = widget.url;

    // Ensure URL always has a scheme so WebView doesn't crash on plain IDs
    String initialUrl = widget.url;
    if (!initialUrl.contains('://')) {
      initialUrl = 'https://$initialUrl';
    }
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'VocabChannel',
        onMessageReceived: (JavaScriptMessage message) {
          final data = message.message.split('|||');
          if (data.length >= 2) {
            final word = data[0];
            final position = data[1];
            _showTranslation(word, position);
          }
        },
      )
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (NavigationRequest request) {
          final urlStr = request.url.toLowerCase();
          // Block known popup/ad domains
          if (urlStr.contains('youtube.com') ||
              urlStr.contains('youtu.be') ||
              urlStr.contains('adserver') ||
              urlStr.contains('doubleclick') ||
              urlStr.contains('popunder')) {
            return NavigationDecision.prevent;
          }
          // Intercept RawKuma manga detail pages → open native detail screen
          // Pattern: rawkuma.net/manga/SLUG/ (NOT chapter URLs, NOT /manga/?page=)
          if (_isRawKumaMangaDetailUrl(request.url)) {
            _openRawKumaMangaDetail(request.url);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
        onPageStarted: (_) => setState(() => _isLoading = true),
        onPageFinished: (url) async {
          setState(() {
            _isLoading = false;
            _currentUrl = url;
          });
          _injectAdBlocker();
          _injectVocabClicker();

          // Record Recent Activity
          final streakNotifier = ref.read(recentActivityProvider.notifier);
          streakNotifier.record(RecentActivity(
            id: 'manga_${widget.title}',
            type: 'manga',
            title: widget.title,
            subtitle: 'Weiterlesen',
            metadata: {
              'url': url,
              'title': widget.title,
            },
            timestamp: DateTime.now().millisecondsSinceEpoch,
          ));
        },
        onWebResourceError: (error) => setState(() => _isLoading = false),
      ))
      ..loadRequest(Uri.parse(initialUrl));
  }

  void _injectAdBlocker() {
    // Hide common ad selectors and stop window.open
    const script = '''
      var style = document.createElement('style');
      style.innerHTML = 'iframe, .ad, .ads, .ad-container, [id*="ad"], [class*="ad-"], .pop-under { display: none !important; pointer-events: none !important; }';
      document.head.appendChild(style);

      window.open = function() { console.log("Blocked window.open"); return null; };

      setInterval(function() {
        var elements = document.querySelectorAll('div, a');
        for (var i = 0; i < elements.length; i++) {
            var el = elements[i];
            var style = window.getComputedStyle(el);
            if (style.zIndex > 9000 && style.position === 'absolute' && el.innerText.trim() === '') {
                el.style.display = 'none';
            }
        }
      }, 2000);
    ''';
    _controller.runJavaScript(script);
  }

  void _injectVocabClicker() {
    // Wrap Japanese text in clickable spans with high z-index and preventDefault
    const script = r'''
      function wrapJapaneseText(node) {
        if (node.nodeType === 3) {
          var text = node.nodeValue;
          var regex = /([\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FAF]+)/g;
          if (regex.test(text)) {
            var wrapper = document.createElement('span');
            wrapper.innerHTML = text.replace(regex, '<span class="ja-vocab" style="cursor:pointer; position:relative; z-index:99999;" onclick="event.preventDefault(); event.stopPropagation(); VocabChannel.postMessage(this.innerText + \'|||\' + window.scrollY); return false;">$1</span>');
            node.parentNode.replaceChild(wrapper, node);
          }
        } else if (node.nodeType === 1 && node.nodeName !== 'SCRIPT' && node.nodeName !== 'STYLE' && !node.classList.contains('ja-vocab')) {
          for (var i = 0; i < node.childNodes.length; i++) {
            wrapJapaneseText(node.childNodes[i]);
          }
        }
      }
      wrapJapaneseText(document.body);
    ''';
    _controller.runJavaScript(script);
  }

  /// Check if URL is a RawKuma manga detail page (not chapter, not listing).
  bool _isRawKumaMangaDetailUrl(String url) {
    // Must contain rawkuma.net/manga/SLUG/
    // Must NOT be a chapter URL (contains /chapter-)
    // Must NOT be a listing page (/manga/ or /manga/?page=)
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    if (!uri.host.contains('rawkuma')) return false;
    final path = uri.path;
    // Match /manga/some-slug/ but not /manga/ alone or /manga/some-slug/chapter-*
    final match = RegExp(r'^/manga/([a-zA-Z0-9][a-zA-Z0-9\-]+[a-zA-Z0-9])/?$').hasMatch(path);
    return match;
  }

  /// Fetch manga title + cover from RawKuma page and open native detail screen.
  Future<void> _openRawKumaMangaDetail(String url) async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse(url), headers: {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/120.0.0.0 Mobile Safari/537.36',
      });
      String title = 'Manga';
      String coverUrl = '';
      if (response.statusCode == 200) {
        final document = parse(response.body);
        title = document.querySelector('.entry-title')?.text.trim()
            ?? document.querySelector('h1')?.text.trim()
            ?? url.split('/').where((s) => s.isNotEmpty).last;
        // Use og:image meta tag — most reliable for RawKuma covers
        final ogImage = document.querySelector('meta[property="og:image"]');
        coverUrl = ogImage?.attributes['content'] ?? '';
        // Fallback to thumbnail img
        if (coverUrl.isEmpty) {
          final imgEl = document.querySelector('.thumb img, .infomanga img, .spe img');
          coverUrl = imgEl?.attributes['data-src']
              ?? imgEl?.attributes['data-lazy-src']
              ?? imgEl?.attributes['src']
              ?? '';
        }
      }
      if (!mounted) return;
      setState(() => _isLoading = false);

      final manga = Manga(title: title, url: url, coverUrl: coverUrl, source: 'Raw Kuma');
      final rawkumaSource = ref.read(rawkumaSourceProvider);
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => MangaDetailScreen(manga: manga, source: rawkumaSource),
      ));
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
  }

  void _showTranslation(String text, String position) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TranslationBottomSheet(
        text: text,
        mangaTitle: widget.title,
        sourceUrl: _currentUrl,
        pagePosition: position,
      ),
    );
  }

  Future<void> _bookmarkCurrentPage() async {
    // If we're on a RawKuma chapter, bookmark the manga parent URL instead of the chapter URL
    String urlToSave = _currentUrl;
    if (urlToSave.contains('rawkuma.net')) {
      final reg = RegExp(r'rawkuma\.com/([a-zA-Z0-9\-]+)-chapter-\d+');
      final match = reg.firstMatch(urlToSave);
      if (match != null) {
        urlToSave = 'https://rawkuma.net/manga/${match.group(1)}/';
      }
    }

    // Try to get a meta title or use generic
    String safeTitle = await _controller.getTitle() ?? widget.title;
    if (safeTitle.isEmpty || safeTitle == 'Raw Kuma' || safeTitle == 'Eigene URL') {
       safeTitle = urlToSave;
    }

    String coverUrl = '';
    try {
      final boundary = _globalKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null) {
        final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
        final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          final Uint8List pngBytes = byteData.buffer.asUint8List();
          final directory = await getApplicationDocumentsDirectory();
          final fileName = 'thumb_${DateTime.now().millisecondsSinceEpoch}.png';
          final imagePath = '${directory.path}/$fileName';
          final file = File(imagePath);
          await file.writeAsBytes(pngBytes);
          coverUrl = imagePath;
        }
      }
    } catch (_) {
      // Ignore errors for thumbnail generation
    }

    final dbService = ref.read(databaseProvider);
    final db = await dbService.database;

    final mangaInfo = SavedManga(
      url: urlToSave,
      title: safeTitle,
      coverUrl: coverUrl,
      source: widget.title == 'Raw Kuma' ? 'Raw Kuma' : 'Custom URL',
      isFavorite: 0,
    );

    await db.insert(
      'saved_manga',
      mangaInfo.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lesezeichen gespeichert!')),
      );
    }
  }

  Future<void> _captureAndOcr() async {
    try {
      final script = r'''
        (function() {
          var urls = [];
          var imgs = document.querySelectorAll('img');
          for (var i = 0; i < imgs.length; i++) {
             var src = imgs[i].getAttribute('data-src') || imgs[i].getAttribute('data-lazy-src') || imgs[i].src;
             if (src && src.startsWith('http')) urls.push(src);
          }
          return urls.join('|||');
        })();
      ''';

      final result = await _controller.runJavaScriptReturningResult(script);
      final String resStr = result.toString().replaceAll('"', '');
      if (resStr.isEmpty || resStr == 'null') {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Keine Bilder auf der Seite gefunden.')));
        }
        return;
      }
      
      final urls = resStr.split('|||').where((u) => u.startsWith('http')).toList();
      if (urls.isEmpty) return;

      if (mounted) {
        Navigator.push(context, MaterialPageRoute(
          builder: (context) => NativeImageReaderScreen(
            imageUrls: urls,
            mangaTitle: widget.title,
          ),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Extrahieren der Bilder: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFullscreen = ref.watch(fullscreenProvider);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: widget.showBackButton,
        title: Text(widget.title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: Icon(isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen),
            tooltip: 'Vollbild umschalten',
            onPressed: _toggleFullscreen,
          ),
          IconButton(
            icon: const Icon(Icons.image_search),
            tooltip: 'Bilder im nativen Reader oeffnen (OCR)',
            onPressed: _captureAndOcr,
          ),
          IconButton(
            icon: const Icon(Icons.bookmark_add),
            tooltip: 'Lesezeichen setzen',
            onPressed: _bookmarkCurrentPage,
          ),
          IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            tooltip: 'Zurueck',
            onPressed: () async {
              if (await _controller.canGoBack()) _controller.goBack();
            },
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios),
            tooltip: 'Vorwaerts',
            onPressed: () async {
              if (await _controller.canGoForward()) _controller.goForward();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Neu laden',
            onPressed: () => _controller.reload(),
          ),
        ],
      ),
      body: Stack(
        children: [
          RepaintBoundary(
            key: _globalKey,
            child: WebViewWidget(
              controller: _controller,
              gestureRecognizers: {
                Factory<EagerGestureRecognizer>(() => EagerGestureRecognizer()),
              },
            ),
          ),
          if (_isLoading)
            const LinearProgressIndicator(),
        ],
      ),
    );
  }
}
