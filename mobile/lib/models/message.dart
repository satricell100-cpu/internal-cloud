import 'file_item.dart';

// Model untuk pesan chat (bisa berisi teks dan/atau file)
class Message {
  final String id;
  final String? body; // teks pesan (bisa null kalau hanya file)
  final int ts;
  final String? date;
  final int fileCount;
  final List<FileItem> files; // file terikat ke pesan ini

  Message({
    required this.id,
    this.body,
    required this.ts,
    this.date,
    this.fileCount = 0,
    this.files = const [],
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String? ?? '',
      body: json['body'] as String?,
      ts: (json['ts'] as num?)?.toInt() ?? 0,
      date: json['date'] as String?,
      fileCount: (json['file_count'] as num?)?.toInt() ?? 0,
      files: (json['files'] as List? ?? [])
          .map((f) => FileItem.fromJson(f as Map<String, dynamic>))
          .toList(),
    );
  }
}
