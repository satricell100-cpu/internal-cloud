// Model untuk entitas file di backend
class FileItem {
  final String id;
  final String? messageId;
  final String originalName;
  final String mime;
  final String category; // document | image | archive | other
  final int sizeBytes;
  final int ts;
  final String? downloadUrl;
  final String? previewUrl;

  FileItem({
    required this.id,
    this.messageId,
    required this.originalName,
    required this.mime,
    required this.category,
    required this.sizeBytes,
    required this.ts,
    this.downloadUrl,
    this.previewUrl,
  });

  factory FileItem.fromJson(Map<String, dynamic> json) {
    return FileItem(
      id: json['id'] as String? ?? '',
      messageId: json['message_id'] as String?,
      originalName: json['original_name'] as String? ?? 'file',
      mime: json['mime'] as String? ?? 'application/octet-stream',
      category: json['category'] as String? ?? 'other',
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      ts: (json['ts'] as num?)?.toInt() ?? 0,
      downloadUrl: json['download_url'] as String?,
      previewUrl: json['preview_url'] as String?,
    );
  }

  bool get isImage => category == 'image';

  // Format ukuran file jadi human-readable
  String get sizeLabel {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    if (sizeBytes < 1024 * 1024 * 1024) return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
