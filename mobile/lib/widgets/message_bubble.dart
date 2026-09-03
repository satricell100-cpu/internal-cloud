import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/file_item.dart';
import '../models/message.dart';
import '../services/api_service.dart';
import '../services/file_viewer_service.dart';
import '../screens/preview_screen.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final void Function(FileItem)? onFileTap;
  final bool highlight;

  const MessageBubble({
    super.key,
    required this.message,
    this.onFileTap,
    this.highlight = false,
  });

  void _handleDefaultFileTap(BuildContext context, FileItem file) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PreviewScreen(
          fileId: file.id,
          initialFileName: file.originalName,
          initialCategory: file.category,
          autoOpen: !file.isImage,
        ),
      ),
    );
  }

  String get _timeLabel {
    final dt = DateTime.fromMillisecondsSinceEpoch(message.ts);
    return DateFormat('HH:mm').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        decoration: BoxDecoration(
          color: highlight
              ? const Color(0xFFFFF3B0)
              : const Color(0xFFDCF8C6),
          borderRadius: BorderRadius.circular(12),
          border: highlight
              ? Border.all(color: const Color(0xFFFFC107), width: 1.5)
              : null,
          boxShadow: highlight
              ? [
                  BoxShadow(
                    color: const Color(0xFFFFC107).withOpacity(0.18),
                    blurRadius: 10,
                    spreadRadius: 1,
                  )
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // File chips
            if (message.files.isNotEmpty)
              ...message.files.map(
                (f) => _FileChip(
                  file: f,
                  onTap: () => onFileTap != null
                      ? onFileTap!(f)
                      : _handleDefaultFileTap(context, f),
                  onShare: () => FileViewerService.shareFile(
                    fileId: f.id,
                    fileName: f.originalName,
                  ),
                ),
              ),
            if (message.files.isNotEmpty && message.body != null && message.body!.isNotEmpty)
              const SizedBox(height: 4),
            // Teks pesan
            if (message.body != null && message.body!.isNotEmpty)
              Text(
                message.body!,
                style: const TextStyle(fontSize: 15),
              ),
            // Waktu + centang ganda
            Align(
              alignment: Alignment.bottomRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _timeLabel,
                    style:
                        const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.done_all,
                    size: 16,
                    color: Colors.blue,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── File Chip ─────────────────────────────────────────────────

class _FileChip extends StatelessWidget {
  final FileItem file;
  final VoidCallback? onTap;
  final VoidCallback? onShare;

  const _FileChip({required this.file, this.onTap, this.onShare});

  @override
  Widget build(BuildContext context) {
    // Gambar: thumbnail interaktif
    if (file.isImage) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.black12,
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Image.network(
                  ApiService.getRawImageUrl(file.id),
                  headers: ApiService.getImageHeaders(),
                  width: 200,
                  height: 150,
                  fit: BoxFit.cover,
                  loadingBuilder: (ctx, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      width: 200,
                      height: 150,
                      color: Colors.black12,
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) => Container(
                    width: 200,
                    height: 150,
                    color: Colors.black12,
                    child: const Icon(Icons.broken_image, color: Colors.grey),
                  ),
                ),
                // Share button overlay
                Positioned(
                  top: 6,
                  right: 6,
                  child: InkWell(
                    onTap: onShare,
                    child: const CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.black54,
                      child:
                          Icon(Icons.share, size: 14, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // File Dokumen (Word, PDF, Excel, dll) & Arsip: chip dengan info jelas & ikon tipe
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ikon tipe file dengan badge (Word/PDF/Excel/dsb)
              _FileTypeIcon(category: file.category, mime: file.mime, fileName: file.originalName),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      file.originalName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          file.sizeLabel,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.teal.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Klik untuk buka',
                            style: TextStyle(
                              fontSize: 9,
                              color: Color(0xFF128C7E),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: onShare,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.share, size: 18, color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Ikon tipe file ────────────────────────────────────────────

class _FileTypeIcon extends StatelessWidget {
  final String category;
  final String mime;
  final String fileName;

  const _FileTypeIcon({
    required this.category,
    required this.mime,
    required this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    final lower = fileName.toLowerCase();
    Color color = Colors.blue.shade700;
    IconData icon = Icons.description;
    String badge = 'DOC';

    if (lower.endsWith('.doc') || lower.endsWith('.docx') || mime.contains('word')) {
      color = const Color(0xFF2B579A); // Microsoft Word Blue
      icon = Icons.description;
      badge = 'DOCX';
    } else if (lower.endsWith('.xls') || lower.endsWith('.xlsx') || mime.contains('excel') || mime.contains('spreadsheet')) {
      color = const Color(0xFF217346); // Microsoft Excel Green
      icon = Icons.table_chart;
      badge = 'XLSX';
    } else if (lower.endsWith('.ppt') || lower.endsWith('.pptx') || mime.contains('presentation')) {
      color = const Color(0xFFD24726); // Microsoft PPT Orange
      icon = Icons.slideshow;
      badge = 'PPTX';
    } else if (lower.endsWith('.pdf') || mime == 'application/pdf') {
      color = const Color(0xFFD32F2F); // Adobe Red
      icon = Icons.picture_as_pdf;
      badge = 'PDF';
    } else if (lower.endsWith('.zip') || lower.endsWith('.rar') || lower.endsWith('.7z') || category == 'archive') {
      color = const Color(0xFFF57C00); // Amber
      icon = Icons.folder_zip;
      badge = 'ZIP';
    } else if (lower.endsWith('.txt') || lower.endsWith('.md')) {
      color = const Color(0xFF00796B);
      icon = Icons.article;
      badge = 'TXT';
    }

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 18),
          Text(
            badge,
            style: TextStyle(
              fontSize: 7.5,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
