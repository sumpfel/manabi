import 'dart:convert';
import 'package:http/http.dart' as http;
import 'manga_source.dart';

class MangaDexSource extends MangaSource {
  @override
  String get name => 'MangaDex';

  @override
  String get baseUrl => 'https://mangadex.org';

  final String _apiUrl = 'https://api.mangadex.org';

  @override
  Future<List<Manga>> fetchPopularManga(int page) async {
    try {
      final offset = (page - 1) * 100;
      
      // Step 1: Fetch recently updated, non-external Japanese chapters to guarantee readable content
      final chapUri = Uri.parse('$_apiUrl/chapter?limit=100&offset=$offset&translatedLanguage[]=ja&includeExternalUrl=0&order[updatedAt]=desc&includes[]=manga');
      final chapResponse = await http.get(chapUri);
      
      if (chapResponse.statusCode != 200) throw Exception('MangaDex API chapter error: ${chapResponse.statusCode}');
      
      final chapData = jsonDecode(chapResponse.body);
      final List<dynamic> chapters = chapData['data'] ?? [];
      
      final Set<String> uniqueMangaIds = {};
      for (var c in chapters) {
        final rels = c['relationships'] as List<dynamic>? ?? [];
        for (var r in rels) {
           if (r['type'] == 'manga') {
              uniqueMangaIds.add(r['id']);
              break;
           }
        }
        if (uniqueMangaIds.length >= 20) break; // We only need 20 for a page
      }
      
      if (uniqueMangaIds.isEmpty) return [];

      // Step 2: Fetch the actual Manga objects and their Cover Art using the guaranteed IDs
      final idsQuery = uniqueMangaIds.map((id) => 'ids[]=$id').join('&');
      final mangaUri = Uri.parse('$_apiUrl/manga?limit=20&$idsQuery&includes[]=cover_art');
      final mangaResponse = await http.get(mangaUri);
      
      if (mangaResponse.statusCode != 200) throw Exception('MangaDex API error: ${mangaResponse.statusCode}');

      final data = jsonDecode(mangaResponse.body);
      final List<dynamic> mangaDocs = data['data'] ?? [];
      final List<Manga> mangas = [];

      for (var item in mangaDocs) {
         final attributes = item['attributes'];
         // MangaDex titles are localized objects, usually 'en' or 'ja'
         String title = 'Unknown Title';
         if (attributes != null && attributes['title'] != null) {
            final titleMap = attributes['title'];
            if (titleMap is Map && titleMap.isNotEmpty) {
               title = titleMap['ja-ro'] ?? titleMap['en'] ?? titleMap['ja'] ?? titleMap.values.first ?? 'Unknown';
            }
         }

         final id = item['id'];
         
         // Extract cover art from relationships
         String coverUrl = '';
         final List<dynamic> relationships = item['relationships'] ?? [];
         for (var rel in relationships) {
           if (rel['type'] == 'cover_art' && rel['attributes'] != null) {
              final fileName = rel['attributes']['fileName'];
              // MangaDex covers are hosted at https://uploads.mangadex.org/covers/{manga_id}/{cover_filename}
              if (fileName != null) {
                coverUrl = 'https://uploads.mangadex.org/covers/$id/$fileName.256.jpg';
              }
           }
         }

         mangas.add(Manga(title: title, url: id, coverUrl: coverUrl));
      }
      return mangas;
    } catch (e) {
      throw Exception('MangaDex fetch.popular error: $e');
    }
  }

  @override
  Future<List<Manga>> searchManga(String query) async {
    try {
      // Search Japanese raw manga and ensure they have Japanese chapters
      final uri = Uri.parse('$_apiUrl/manga?limit=20&title=$query&includes[]=cover_art&order[relevance]=desc&originalLanguage[]=ja&availableTranslatedLanguage[]=ja&hasAvailableChapters=true');
      final response = await http.get(uri);
      
      if (response.statusCode != 200) throw Exception('MangaDex Search error: ${response.statusCode}');

      final data = jsonDecode(response.body);
      final List<dynamic> mangaDocs = data['data'] ?? [];
      final List<Manga> mangas = [];

      for (var item in mangaDocs) {
         final attributes = item['attributes'];
         String title = 'Unknown Title';
         if (attributes != null && attributes['title'] != null) {
            final titleMap = attributes['title'];
            if (titleMap is Map && titleMap.isNotEmpty) {
               title = titleMap['ja-ro'] ?? titleMap['en'] ?? titleMap['ja'] ?? titleMap.values.first ?? 'Unknown';
            }
         }

         final id = item['id'];
         String coverUrl = '';
         final List<dynamic> relationships = item['relationships'] ?? [];
         for (var rel in relationships) {
           if (rel['type'] == 'cover_art' && rel['attributes'] != null) {
              final fileName = rel['attributes']['fileName'];
              if (fileName != null) {
                coverUrl = 'https://uploads.mangadex.org/covers/$id/$fileName.256.jpg';
              }
           }
         }

         mangas.add(Manga(title: title, url: id, coverUrl: coverUrl));
      }
      return mangas;
    } catch (e) {
      throw Exception('MangaDex search error: $e');
    }
  }

  @override
  Future<List<Chapter>> fetchChapters(String mangaId) async {
    try {
      // Fetch Japanese chapters for the manga (500 limit to get all at once if possible)
      final uri = Uri.parse('$_apiUrl/manga/$mangaId/feed?limit=500&translatedLanguage[]=ja&order[chapter]=desc&includeExternalUrl=0&includeFuturePublishAt=0');
      final response = await http.get(uri);
      
      if (response.statusCode != 200) throw Exception('MangaDex Chapters error: ${response.statusCode}');

      final data = jsonDecode(response.body);
      final List<dynamic> chapterDocs = data['data'] ?? [];
      final List<Chapter> chapters = [];
      final Set<String> seenChapters = {};

      for (var c in chapterDocs) {
        final attributes = c['attributes'];
        
        // Skip external links or empty chapters without hosted image pages
        if (attributes['externalUrl'] != null || attributes['pages'] == 0) continue;
        
        final chapterNum = attributes['chapter']?.toString() ?? '';
        if (chapterNum.isNotEmpty) {
           if (seenChapters.contains(chapterNum)) continue; // Deduplicate by chapter number
           seenChapters.add(chapterNum);
        }

        // Provide fallback if chapter title is empty
        String title = attributes['title'] != null && attributes['title'].toString().isNotEmpty 
          ? attributes['title'].toString() 
          : "Chapter $chapterNum";
        
        // Some chapters have no title but a chapter number
        if (title.trim() == 'Chapter ?' || title.isEmpty || title.trim() == 'Chapter') {
            title = "Chapter $chapterNum";
        }

        final id = c['id'];
        chapters.add(Chapter(title: title, url: id));
      }
      return chapters; // Already ordered descending from API
    } catch (e) {
      // If translatedLanguage[]=ja yields nothing, fallback to translatedLanguage[]=en (some scanlations mislabel)
      throw Exception('MangaDex fetch.chapters error: $e');
    }
  }

  @override
  Future<List<String>> fetchPageUrls(String chapterId) async {
    try {
      // 1. Get the at-home server URL for the chapter
      final response = await http.get(Uri.parse('$_apiUrl/at-home/server/$chapterId'));
      if (response.statusCode != 200) throw Exception('MangaDex Pages error: ${response.statusCode}');

      final data = jsonDecode(response.body);
      final baseUrl = data['baseUrl'];
      final chapterData = data['chapter'];
      if (baseUrl == null || chapterData == null) return [];

      final hash = chapterData['hash'];
      final List<dynamic> images = chapterData['data'] ?? []; // data contains high-quality filenames
      final List<String> pageUrls = [];

      for (var img in images) {
        // Construct the full URL: {baseUrl}/data/{hash}/{filename}
        pageUrls.add('$baseUrl/data/$hash/$img');
      }
      return pageUrls;
    } catch (e) {
      throw Exception('MangaDex fetch.pages error: $e');
    }
  }
}
