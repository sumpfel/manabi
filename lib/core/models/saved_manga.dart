class SavedManga {
  final String url; // Acts as primary key in DB
  final String title;
  final String coverUrl;
  final String source; // e.g., 'rawsakura'
  final int isFavorite; // 1 for true, 0 for false

  SavedManga({
    required this.url,
    required this.title,
    required this.coverUrl,
    required this.source,
    this.isFavorite = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'title': title,
      'cover_url': coverUrl,
      'source': source,
      'is_favorite': isFavorite,
    };
  }

  factory SavedManga.fromMap(Map<String, dynamic> map) {
    return SavedManga(
      url: map['url'],
      title: map['title'],
      coverUrl: map['cover_url'],
      source: map['source'],
      isFavorite: map['is_favorite'] ?? 0,
    );
  }
}
