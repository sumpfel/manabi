class DownloadedChapter {
  final String chapterUrl; // Primary Key
  final String mangaUrl; // Foreign Key to SavedManga
  final String chapterTitle;
  final String localFolderPath; // Path where images are saved
  final int pageCount;
  final int downloadedAt;

  DownloadedChapter({
    required this.chapterUrl,
    required this.mangaUrl,
    required this.chapterTitle,
    required this.localFolderPath,
    required this.pageCount,
    required this.downloadedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'chapter_url': chapterUrl,
      'manga_url': mangaUrl,
      'chapter_title': chapterTitle,
      'local_folder_path': localFolderPath,
      'page_count': pageCount,
      'downloaded_at': downloadedAt,
    };
  }

  factory DownloadedChapter.fromMap(Map<String, dynamic> map) {
    return DownloadedChapter(
      chapterUrl: map['chapter_url'],
      mangaUrl: map['manga_url'],
      chapterTitle: map['chapter_title'],
      localFolderPath: map['local_folder_path'],
      pageCount: map['page_count'] ?? 0,
      downloadedAt: map['downloaded_at'],
    );
  }
}
