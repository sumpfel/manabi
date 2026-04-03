import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;
import 'manga_source.dart';

class RawsakuraSource extends MangaSource {
  @override
  String get name => 'Rawsakura';

  @override
  String get baseUrl => 'https://rawsakura.org';

  @override
  Future<List<Manga>> fetchPopularManga(int page) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/latest?page=$page'));
      if (response.statusCode != 200) throw Exception('Rawsakura fetch error: ${response.statusCode}');

      final document = parse(response.body);
      final items = document.querySelectorAll('.m-item');
      final List<Manga> mangas = [];

      for (var item in items) {
        final a = item.querySelector('.m-title a') ?? item.querySelector('a');
        if (a == null) continue;
        final title = a.attributes['title'] ?? a.text.trim();
        final url = a.attributes['href'] ?? '';
        
        final img = item.querySelector('.m-img img');
        var coverUrl = img?.attributes['data-src'] ?? img?.attributes['src'] ?? '';
        
        if (url.isNotEmpty) {
           mangas.add(Manga(title: title, url: url, coverUrl: coverUrl));
        }
      }
      return mangas;
    } catch (e) {
       throw Exception('Rawsakura fetch.popular error: $e');
    }
  }

  @override
  Future<List<Manga>> searchManga(String query) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/search?query=${Uri.encodeComponent(query)}'));
      if (response.statusCode != 200) throw Exception('Rawsakura search error: ${response.statusCode}');

      final document = parse(response.body);
      final items = document.querySelectorAll('.m-item');
      final List<Manga> mangas = [];

      for (var item in items) {
        final a = item.querySelector('.m-title a') ?? item.querySelector('a');
        if (a == null) continue;
        final title = a.attributes['title'] ?? a.text.trim();
        final url = a.attributes['href'] ?? '';
        
        final img = item.querySelector('.m-img img');
        var coverUrl = img?.attributes['data-src'] ?? img?.attributes['src'] ?? '';
        
        if (url.isNotEmpty) {
           mangas.add(Manga(title: title, url: url, coverUrl: coverUrl));
        }
      }
      return mangas;
    } catch (e) {
      throw Exception('Rawsakura search error: $e');
    }
  }

  @override
  Future<List<Chapter>> fetchChapters(String mangaUrl) async {
    try {
      final targetUrl = mangaUrl.startsWith('http') ? mangaUrl : '$baseUrl$mangaUrl';
      final response = await http.get(Uri.parse(targetUrl));
      if (response.statusCode != 200) throw Exception('Rawsakura chapters error: ${response.statusCode}');

      final document = parse(response.body);
      final chapters = <Chapter>[];
      
      var chapterNodes = document.querySelectorAll('a[href^="/reader/"]');

      final Set<String> seenUrls = {};
      for (var node in chapterNodes) {
        var title = node.text.trim();
        final url = node.attributes['href'] ?? '';
        
        // Clean up title if it contains "Read" or "Latest" due to top buttons
        if (title.contains('Read Chapter') || title == 'Latest Chapter' || title == '') {
            title = node.attributes['title'] ?? title;
        }
        
        if (url.isNotEmpty && title.isNotEmpty && !seenUrls.contains(url)) {
          seenUrls.add(url);
          chapters.add(Chapter(title: title.trim(), url: url));
        }
      }
      return chapters;
    } catch (e) {
      throw Exception('Rawsakura fetch.chapters error: $e');
    }
  }

  @override
  Future<List<String>> fetchPageUrls(String chapterUrl) async {
    try {
      final targetUrl = chapterUrl.startsWith('http') ? chapterUrl : '$baseUrl$chapterUrl';
      final response = await http.get(Uri.parse(targetUrl));
      if (response.statusCode != 200) throw Exception('Rawsakura pages error: ${response.statusCode}');

      final document = parse(response.body);
      final List<String> pageUrls = [];
      
      var images = document.querySelectorAll('.r-content img.lazy');
      if (images.isEmpty) images = document.querySelectorAll('.reading-content img');
      if (images.isEmpty) images = document.querySelectorAll('.page-break img');
      if (images.isEmpty) images = document.querySelectorAll('#readerarea img');
      if (images.isEmpty) images = document.querySelectorAll('.container img.lazy'); // Fallbacks

      for (var img in images) {
        var src = img.attributes['data-src'] ?? img.attributes['src'] ?? '';
        src = src.trim();
        if (src.isNotEmpty && !pageUrls.contains(src) && !src.contains('logo') && !src.contains('icon') && !src.contains('banner')) {
           pageUrls.add(src);
        }
      }

      return pageUrls;
    } catch (e) {
       throw Exception('Rawsakura fetch.pages error: $e');
    }
  }
}
