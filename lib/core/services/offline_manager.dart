import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../database/database_service.dart';
import '../models/saved_manga.dart';
import '../models/downloaded_chapter.dart';
import '../network/manga_source.dart';

final offlineManagerProvider = Provider<OfflineManager>((ref) {
  return OfflineManager(ref);
});

class OfflineManager {
  final Ref ref;

  OfflineManager(this.ref);

  Future<void> saveMangaToLibrary(Manga manga, {bool isFavorite = true}) async {
    final dbService = ref.read(databaseProvider);
    final db = await dbService.database;
    final savedManga = SavedManga(
      url: manga.url,
      title: manga.title,
      coverUrl: manga.coverUrl,
      source: manga.source ?? ref.read(mangaSourceProvider).name,
      isFavorite: isFavorite ? 1 : 0,
    );
    await db.insert(
      'saved_manga', 
      savedManga.toMap(),
      // Handle the case where they previously saved it and we are updating the favorite flag
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removeMangaFromLibrary(String mangaUrl) async {
    final dbService = ref.read(databaseProvider);
    final db = await dbService.database;
    await db.delete(
      'saved_manga',
      where: 'url = ?',
      whereArgs: [mangaUrl],
    );
  }

  Future<bool> isMangaSaved(String mangaUrl) async {
    final dbService = ref.read(databaseProvider);
    final db = await dbService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'saved_manga',
      where: 'url = ?',
      whereArgs: [mangaUrl],
    );
    return maps.isNotEmpty;
  }


  Future<void> downloadChapter(Manga manga, Chapter chapter, {MangaSource? source}) async {
    // 1. Ensure Manga is saved in the database
    await saveMangaToLibrary(manga, isFavorite: true);

    final MangaSource activeSource = source ?? ref.read(mangaSourceProvider);
    final pageUrls = await activeSource.fetchPageUrls(chapter.url);
    if (pageUrls.isEmpty) return;

    // 2. Prepare local directory
    final appDir = await getApplicationDocumentsDirectory();
    final mangaDirName = manga.title.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final chapterDirName = chapter.title.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final chapterDirPath = p.join(appDir.path, 'manga', mangaDirName, chapterDirName);
    
    final dir = Directory(chapterDirPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    // 3. Download Images
    for (int i = 0; i < pageUrls.length; i++) {
        final imgUrl = pageUrls[i];
        try {
           final response = await http.get(Uri.parse(imgUrl));
           if (response.statusCode == 200) {
              final ext = p.extension(imgUrl).isEmpty ? '.jpg' : p.extension(imgUrl);
              // Pad to ensure correct ordering (001.jpg, 002.jpg)
              final pageName = "${(i + 1).toString().padLeft(3, '0')}$ext";
              final file = File(p.join(chapterDirPath, pageName));
              await file.writeAsBytes(response.bodyBytes);
           }
        } catch (e) {
           print('Error downloading image $imgUrl: $e');
        }
    }

    // 4. Record to Database
    final dbService = ref.read(databaseProvider);
    final db = await dbService.database;
    final downloadedChapter = DownloadedChapter(
      chapterUrl: chapter.url,
      mangaUrl: manga.url,
      chapterTitle: chapter.title,
      localFolderPath: chapterDirPath,
      pageCount: pageUrls.length,
      downloadedAt: DateTime.now().millisecondsSinceEpoch,
    );

    await db.insert('downloaded_chapters', downloadedChapter.toMap());
  }

  Future<List<Manga>> getLibraryMangas() async {
    final dbService = ref.read(databaseProvider);
    final db = await dbService.database;
    final List<Map<String, dynamic>> maps = await db.query('saved_manga');
    return List.generate(maps.length, (i) => Manga(
      title: maps[i]['title'],
      url: maps[i]['url'],
      coverUrl: maps[i]['cover_url'],
      source: maps[i]['source'],
    ));
  }

  Future<void> clearDownloadedManga() async {
    final dbService = ref.read(databaseProvider);
    final db = await dbService.database;
    
    // Clear the database table
    await db.delete('downloaded_chapters');

    // Delete the local files
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final mangaDir = Directory(p.join(appDir.path, 'manga'));
      if (await mangaDir.exists()) {
        await mangaDir.delete(recursive: true);
      }
    } catch (e) {
      print('Error clearing downloaded manga files: $e');
    }
  }
}
