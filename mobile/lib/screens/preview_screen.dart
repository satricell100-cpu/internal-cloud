import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/file_viewer_service.dart';

// Layar preview, buka langsung, & download file
class PreviewScreen extends StatefulWidget {
  final String fileId;
  final String? initialFileName;
  final String? initialCategory;
  final bool autoOpen;

  const PreviewScreen({
    super.key,
    required this.fileId,
    this.initialFileName,
    this.initialCategory,
    this.autoOpen = false,
  });

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _file;
  bool _downloading = false;
  bool _hasAutoOpened = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final f = await ApiService.getFileInfo(widget.fileId);
      if (mounted) {
        setState(() {
          _file = f;
          _isLoading = false;
        });

        // Auto buka jika diminta dan bukan gambar
        if (widget.autoOpen && !_hasAutoOpened) {
          _hasAutoOpened = true;
          final category = f['category'] as String? ?? 'other';
          if (category != 'image') {
            final name = f['original_name'] as String? ?? 'file';
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                FileViewerService.openFile(
                  context,
                  fileId: widget.fileId,
                  fileName: name,
                  category: category,
                );
              }
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _download() async {
    setState(() => _downloading = true);
    try {
      final name = _file?['original_name'] as String? ?? 'file';
      final path = await ApiService.downloadFile(widget.fileId, name);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File tersimpan di: $path'),
            action: SnackBarAction(
              label: 'Buka',
              textColor: Colors.amber,
              onPressed: () => _openFileDirectly(),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengunduh: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  void _openFileDirectly() {
    final name = _file?['original_name'] as String? ?? 'file';
    final category = _file?['category'] as String? ?? 'other';
    FileViewerService.openFile(
      context,
      fileId: widget.fileId,
      fileName: name,
      category: category,
    );
  }

  void _share() {
    final name = _file?['original_name'] as String? ?? 'file';
    FileViewerService.shareFile(
      fileId: widget.fileId,
      fileName: name,
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = _file?['original_name'] as String? ?? widget.initialFileName ?? 'Preview File';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          name,
          style: const TextStyle(fontSize: 16),
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: const Color(0xFF128C7E),
        foregroundColor: Colors.white,
        actions: [
          if (_file != null) ...[
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'Bagikan',
              onPressed: _share,
            ),
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'Unduh',
              onPressed: _downloading ? null : _download,
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF128C7E)),
                  SizedBox(height: 16),
                  Text('Memuat informasi file...', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : _error != null
              ? _ErrorView(error: _error!, onRetry: _load)
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final f = _file!;
    final category = f['category'] as String? ?? 'other';
    final mime = f['mime'] as String? ?? '';
    final isImage = category == 'image' || mime.startsWith('image/');

    // Gambar: preview interaktif dengan zoom & pan
    if (isImage) {
      return Column(
        children: [
          Expanded(
            child: Container(
              color: Colors.black87,
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: Image.network(
                    ApiService.getRawImageUrl(widget.fileId),
                    headers: ApiService.getImageHeaders(),
                    fit: BoxFit.contain,
                    loadingBuilder: (ctx, child, progress) {
                      if (progress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: progress.expectedTotalBytes != null
                              ? progress.cumulativeBytesLoaded /
                                  (progress.expectedTotalBytes ?? 1)
                              : null,
                          color: Colors.white,
                        ),
                      );
                    },
                    errorBuilder: (_, __, ___) => const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image, size: 80, color: Colors.white54),
                        SizedBox(height: 12),
                        Text(
                          'Gagal menampilkan gambar',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.grey.shade900,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        f['original_name'] ?? 'gambar',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${_sizeLabel(f['size_bytes'] as int? ?? 0)} • ${f['date'] ?? ''}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.open_in_new, color: Colors.white),
                      tooltip: 'Buka di Galeri / Aplikasi Lain',
                      onPressed: _openFileDirectly,
                    ),
                    IconButton(
                      icon: _downloading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.download, color: Colors.white),
                      tooltip: 'Unduh',
                      onPressed: _downloading ? null : _download,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Dokumen (Word, Excel, PDF, dsb), Arsip, & File Lainnya
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            // Ikon badge dokumen
            _DocumentBadge(fileName: f['original_name'] ?? '', mime: mime, category: category),
            const SizedBox(height: 24),
            // Nama File
            Text(
              f['original_name'] ?? 'file',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            // Metadata info card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  _infoRow('Ukuran File', _sizeLabel(f['size_bytes'] as int? ?? 0)),
                  const Divider(height: 16),
                  _infoRow('Format / MIME', mime.isEmpty ? 'Unknown' : mime),
                  const Divider(height: 16),
                  _infoRow('Tanggal Upload', f['date'] ?? '-'),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Tombol Utama: Buka File Langsung
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.open_in_new, size: 22),
                label: Text(
                  _openButtonLabel(f['original_name'] ?? '', category),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF128C7E),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
                onPressed: _openFileDirectly,
              ),
            ),
            const SizedBox(height: 14),
            // Tombol Sekunder: Unduh & Bagikan
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: _downloading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF128C7E),
                            ),
                          )
                        : const Icon(Icons.download),
                    label: Text(_downloading ? 'Mengunduh...' : 'Unduh ke HP'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF128C7E),
                      side: const BorderSide(color: Color(0xFF128C7E)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    onPressed: _downloading ? null : _download,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.share),
                    label: const Text('Bagikan'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black87,
                      side: BorderSide(color: Colors.grey.shade400),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    onPressed: _share,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'File akan dibuka dengan aplikasi pembaca dokumen di perangkat Anda (Word, WPS Office, PDF Reader, dll).',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _openButtonLabel(String fileName, String category) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.doc') || lower.endsWith('.docx')) {
      return 'Buka Dokumen Word';
    } else if (lower.endsWith('.xls') || lower.endsWith('.xlsx')) {
      return 'Buka Lembar Kerja Excel';
    } else if (lower.endsWith('.ppt') || lower.endsWith('.pptx')) {
      return 'Buka Presentasi PowerPoint';
    } else if (lower.endsWith('.pdf')) {
      return 'Buka Dokumen PDF';
    } else if (lower.endsWith('.txt') || lower.endsWith('.md')) {
      return 'Buka Teks / Dokumen';
    }
    return 'Buka File';
  }

  String _sizeLabel(int b) {
    if (b < 1024) return '$b B';
    if (b < 1048576) return '${(b / 1024).toStringAsFixed(1)} KB';
    if (b < 1073741824) return '${(b / 1048576).toStringAsFixed(1)} MB';
    return '${(b / 1073741824).toStringAsFixed(1)} GB';
  }
}

class _DocumentBadge extends StatelessWidget {
  final String fileName;
  final String mime;
  final String category;

  const _DocumentBadge({
    required this.fileName,
    required this.mime,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    final lower = fileName.toLowerCase();
    Color bg = const Color(0xFF128C7E);
    IconData icon = Icons.description;
    String badge = 'FILE';

    if (lower.endsWith('.doc') || lower.endsWith('.docx') || mime.contains('word')) {
      bg = const Color(0xFF2B579A); // Microsoft Word Blue
      icon = Icons.description;
      badge = 'WORD';
    } else if (lower.endsWith('.xls') || lower.endsWith('.xlsx') || mime.contains('excel') || mime.contains('spreadsheet')) {
      bg = const Color(0xFF217346); // Microsoft Excel Green
      icon = Icons.table_chart;
      badge = 'EXCEL';
    } else if (lower.endsWith('.ppt') || lower.endsWith('.pptx') || mime.contains('presentation')) {
      bg = const Color(0xFFD24726); // Microsoft PPT Orange
      icon = Icons.slideshow;
      badge = 'PPT';
    } else if (lower.endsWith('.pdf') || mime == 'application/pdf') {
      bg = const Color(0xFFD32F2F); // Adobe Red
      icon = Icons.picture_as_pdf;
      badge = 'PDF';
    } else if (lower.endsWith('.zip') || lower.endsWith('.rar') || lower.endsWith('.7z') || lower.endsWith('.tar') || lower.endsWith('.gz') || category == 'archive') {
      bg = const Color(0xFFF57C00);
      icon = Icons.folder_zip;
      badge = 'ZIP';
    } else if (lower.endsWith('.txt') || lower.endsWith('.csv') || lower.endsWith('.json') || lower.endsWith('.md')) {
      bg = const Color(0xFF00796B);
      icon = Icons.article;
      badge = 'TEXT';
    }

    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: bg.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: bg.withOpacity(0.3), width: 1.5),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(icon, size: 54, color: bg),
          Positioned(
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                badge,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }
}
