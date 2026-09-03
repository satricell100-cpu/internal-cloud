// Model untuk user dan hasil pencarian
class User {
  final String id;
  final String username;
  final String displayName;

  User({
    required this.id,
    required this.username,
    required this.displayName,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
    );
  }
}

// Hasil pencarian (bisa pesan atau file)
class SearchResult {
  final String type; // 'message' | 'file'
  final String? id;
  final String? messageId;
  final String? name; // nama file
  final String? body; // isi pesan
  final String? category;
  final String? mime;
  final int ts;
  final String? downloadUrl;

  SearchResult({
    required this.type,
    this.id,
    this.messageId,
    this.name,
    this.body,
    this.category,
    this.mime,
    required this.ts,
    this.downloadUrl,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      type: json['type'] as String? ?? 'message',
      id: json['file_id'] as String?,
      messageId: json['message_id'] as String?,
      name: json['name'] as String?,
      body: json['body'] as String?,
      category: json['category'] as String?,
      mime: json['mime'] as String?,
      ts: (json['ts'] as num?)?.toInt() ?? 0,
      downloadUrl: json['download_url'] as String?,
    );
  }
}
