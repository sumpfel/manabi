import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'mangadex_source.dart';
import 'rawsakura_source.dart';
import 'rawkuma_source.dart';

class Manga {
  final String title;
  final String url;
  final String coverUrl;
  final String? source;

  Manga({required this.title, required this.url, required this.coverUrl, this.source});
}

class Chapter {
  final String title;
  final String url;

  Chapter({required this.title, required this.url});
}

abstract class MangaSource {
  String get name;
  String get baseUrl;

  Future<List<Manga>> fetchPopularManga(int page);
  Future<List<Manga>> searchManga(String query);
  Future<List<Chapter>> fetchChapters(String mangaUrl);
  Future<List<String>> fetchPageUrls(String chapterUrl);
}

final mangaSourceProvider = Provider<MangaSource>((ref) {
  return MangaDexSource(); // We might not even need this globally anymore if we explicitly provide it to specific tabs
});

final rawkumaSourceProvider = Provider<MangaSource>((ref) {
  return RawKumaNetSource();
});

// A dummy source for initial UI testing before relying on a scraper directly
class DummyMangaSource extends MangaSource {
  @override
  String get name => 'Dummy Source';

  @override
  String get baseUrl => 'https://dummy.com';

  @override
  Future<List<Manga>> fetchPopularManga(int page) async {
    await Future.delayed(const Duration(seconds: 1));
    return List.generate(10, (index) => Manga(
      title: 'Dummy Manga ${page * 10 + index}',
      url: '/manga/dummy-${page * 10 + index}',
      coverUrl: 'https://via.placeholder.com/150x200',
    ));
  }

  @override
  Future<List<Manga>> searchManga(String query) async {
    await Future.delayed(const Duration(seconds: 1));
    return List.generate(3, (index) => Manga(
      title: 'Found: $query $index',
      url: '/manga/search/$index',
      coverUrl: 'https://via.placeholder.com/150x200',
    ));
  }

  @override
  Future<List<Chapter>> fetchChapters(String mangaUrl) async {
    await Future.delayed(const Duration(seconds: 1));
    return List.generate(5, (index) => Chapter(
      title: 'Chapter ${index + 1}',
      url: '$mangaUrl/chapter-${index + 1}',
    ));
  }

  @override
  Future<List<String>> fetchPageUrls(String chapterUrl) async {
    await Future.delayed(const Duration(seconds: 1));
    return [
      'https://via.placeholder.com/800x1200?text=Page+1',
      'https://via.placeholder.com/800x1200?text=Page+2',
      'https://via.placeholder.com/800x1200?text=Page+3',
    ];
  }
}
