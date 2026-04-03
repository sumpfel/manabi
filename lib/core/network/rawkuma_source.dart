import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;
import 'manga_source.dart';

/// Scrapes rawkuma.net for manga chapters and page images.
class RawKumaNetSource extends MangaSource {
  @override
  String get name => 'Raw Kuma';

  @override
  String get baseUrl => 'https://rawkuma.net';

  @override
  Future<List<Manga>> fetchPopularManga(int page) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/manga/?page=$page&order=popular'),
        headers: _headers,
      );
      if (response.statusCode != 200) {
        throw Exception('RawKuma fetch error: ${response.statusCode}');
      }
      return _parseMangaList(response.body);
    } catch (e) {
      if (e.toString().contains('SocketException')) {
        throw Exception('Netzwerkfehler: rawkuma.net nicht erreichbar.');
      }
      throw Exception('RawKuma popular error: $e');
    }
  }

  @override
  Future<List<Manga>> searchManga(String query) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/?s=${Uri.encodeComponent(query)}'),
        headers: _headers,
      );
      if (response.statusCode != 200) {
        throw Exception('RawKuma search error: ${response.statusCode}');
      }
      return _parseMangaList(response.body);
    } catch (e) {
      throw Exception('RawKuma search error: $e');
    }
  }

  @override
  Future<List<Chapter>> fetchChapters(String mangaUrl) async {
    try {
      final targetUrl = mangaUrl.startsWith('http') ? mangaUrl : '$baseUrl$mangaUrl';

      // 1. Fetch the manga page to extract manga_id
      final pageResponse = await http.get(Uri.parse(targetUrl), headers: _headers);
      if (pageResponse.statusCode != 200) {
        throw Exception('RawKuma chapters error: ${pageResponse.statusCode}');
      }

      // 2. Extract manga_id from the page HTML
      final mangaIdMatch = RegExp(r'manga_id=(\d+)').firstMatch(pageResponse.body);
      if (mangaIdMatch == null) {
        throw Exception('manga_id nicht gefunden');
      }
      final mangaId = mangaIdMatch.group(1)!;

      // 3. Fetch chapters via HTMX AJAX endpoint
      final ajaxUrl = '$baseUrl/wp-admin/admin-ajax.php?manga_id=$mangaId&page=1&action=chapter_list';
      final ajaxResponse = await http.get(Uri.parse(ajaxUrl), headers: {
        ..._headers,
        'HX-Request': 'true',
        'Referer': targetUrl,
      });
      if (ajaxResponse.statusCode != 200) {
        throw Exception('RawKuma AJAX error: ${ajaxResponse.statusCode}');
      }

      // 4. Parse chapter list from AJAX response
      final document = parse(ajaxResponse.body);
      final chapters = <Chapter>[];
      final Set<String> seenUrls = {};

      // Each chapter is in <div data-chapter-number="N"> with <a href="...">
      final chapterDivs = document.querySelectorAll('div[data-chapter-number]');
      for (var div in chapterDivs) {
        final link = div.querySelector('a[href*="chapter"]');
        if (link == null) continue;
        final href = link.attributes['href'] ?? '';
        if (href.isEmpty || seenUrls.contains(href)) continue;
        seenUrls.add(href);

        final chapterNum = div.attributes['data-chapter-number'] ?? '';
        final spanTitle = div.querySelector('span')?.text.trim();
        final title = spanTitle ?? 'Chapter $chapterNum';

        chapters.add(Chapter(title: title, url: href));
      }

      // Fallback: try parsing <a> links directly if div approach fails
      if (chapters.isEmpty) {
        final links = document.querySelectorAll('a[href*="chapter"]');
        for (var link in links) {
          final href = link.attributes['href'] ?? '';
          if (href.isEmpty || seenUrls.contains(href) || href.contains('drive.google')) continue;
          seenUrls.add(href);
          String title = link.text.replaceAll(RegExp(r'\s+'), ' ').trim();
          if (title.isEmpty) title = href.split('/').where((s) => s.isNotEmpty).last;
          chapters.add(Chapter(title: title, url: href));
        }
      }

      return chapters;
    } catch (e) {
      throw Exception('RawKuma fetch.chapters error: $e');
    }
  }

  @override
  Future<List<String>> fetchPageUrls(String chapterUrl) async {
    try {
      final targetUrl = chapterUrl.startsWith('http') ? chapterUrl : '$baseUrl$chapterUrl';
      final response = await http.get(Uri.parse(targetUrl), headers: _headers);
      if (response.statusCode != 200) {
        throw Exception('RawKuma pages error: ${response.statusCode}');
      }

      final document = parse(response.body);
      final List<String> pageUrls = [];

      // RawKuma reader page: try known containers first, then all img tags
      var images = document.querySelectorAll('#readerarea img, .reading-content img, .entry-content img');
      if (images.isEmpty) {
        // On RawKuma, chapter images come from CDN (rcdn.kyut.dev) — filter to avoid picking up site UI images
        images = document.querySelectorAll('img');
      }
      for (var img in images) {
        final src = img.attributes['data-src'] ??
            img.attributes['data-lazy-src'] ??
            img.attributes['src'] ??
            '';
        if (src.isNotEmpty && src.startsWith('http') && _isImageUrl(src)) {
          // Skip small thumbnails (e.g. 96x137 cover images)
          final width = int.tryParse(img.attributes['width'] ?? '') ?? 0;
          if (width > 0 && width < 200) continue;
          pageUrls.add(src.trim());
        }
      }

      // Fallback: try to find image URLs in a JS array (some themes use ts_reader.run({images:[...]}))
      if (pageUrls.isEmpty) {
        final body = response.body;
        final regex = RegExp(r'"images"\s*:\s*\[(.*?)\]', dotAll: true);
        final match = regex.firstMatch(body);
        if (match != null) {
          final arrayContent = match.group(1) ?? '';
          final urls = arrayContent
              .replaceAll('"', '')
              .replaceAll("'", '')
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.startsWith('http'))
              .toList();
          pageUrls.addAll(urls);
        }
      }

      return pageUrls;
    } catch (e) {
      throw Exception('RawKuma fetch.pages error: $e');
    }
  }

  /// Parse manga list from HTML (works for both popular and search results).
  List<Manga> _parseMangaList(String html) {
    final document = parse(html);
    final List<Manga> mangas = [];

    // RawKuma uses .bsx or .bs elements for manga entries
    final items = document.querySelectorAll('.bsx a, .bs .bsx a, .listupd .bs .bsx a');

    if (items.isNotEmpty) {
      final Set<String> seenUrls = {};
      for (var item in items) {
        final href = item.attributes['href'] ?? '';
        if (href.isEmpty || seenUrls.contains(href)) continue;
        seenUrls.add(href);

        final titleEl = item.querySelector('.tt, .bigor .tt');
        final imgEl = item.querySelector('img');
        final title = titleEl?.text.trim() ?? item.attributes['title']?.trim() ?? '';
        final coverUrl = imgEl?.attributes['data-src'] ??
            imgEl?.attributes['data-lazy-src'] ??
            imgEl?.attributes['src'] ??
            '';

        if (title.isNotEmpty) {
          mangas.add(Manga(title: title, url: href, coverUrl: coverUrl, source: 'Raw Kuma'));
        }
      }
    }

    // Fallback: try broader selectors
    if (mangas.isEmpty) {
      final fallbackItems = document.querySelectorAll('.listupd a[href*="/manga/"]');
      final Set<String> seenUrls = {};
      for (var item in fallbackItems) {
        final href = item.attributes['href'] ?? '';
        if (href.isEmpty || seenUrls.contains(href)) continue;
        seenUrls.add(href);
        final imgEl = item.querySelector('img');
        final title = item.attributes['title']?.trim() ??
            imgEl?.attributes['alt']?.trim() ??
            href.split('/').where((s) => s.isNotEmpty).last;
        final coverUrl = imgEl?.attributes['data-src'] ??
            imgEl?.attributes['src'] ??
            '';
        mangas.add(Manga(title: title, url: href, coverUrl: coverUrl, source: 'Raw Kuma'));
      }
    }

    return mangas;
  }

  bool _isImageUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('.jpg') ||
        lower.contains('.jpeg') ||
        lower.contains('.png') ||
        lower.contains('.webp') ||
        lower.contains('.gif') ||
        lower.contains('wp-content') ||
        lower.contains('cdn');
  }

  Map<String, String> get _headers => {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'ja,en;q=0.5',
      };
}
