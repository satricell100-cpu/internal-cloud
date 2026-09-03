import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'api_service.dart';

/// Layanan untuk membuka, mem-preview, mengunduh, dan membagikan file.
class FileViewerService {
  /// Mengunduh atau mengambil file dari direktori temp lokal
  static Future<File> getOrDownloadFile(String fileId, String fileName) async {
    final tempDir = await getTemporaryDirectory();
    final localPath = '${tempDir.path}/$fileName';
    final file = File(localPath);

    if (await file.exists() && await file.length() > 0) {
      return file;
    }

    final downloadedPath = await ApiService.downloadFile(fileId, fileName);
    return File(downloadedPath);
  }

  /// Membuka file secara langsung menggunakan aplikasi default sistem (Word, Excel, PDF Reader, dll)
  static Future<void> openFile(
    BuildContext context, {
    required String fileId,
    required String fileName,
    String? category,
  }) async {
    // Tampilkan loading indicator snackbar
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Mempersiapkan "$fileName"...',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 30),
      ),
    );

    try {
      final file = await getOrDownloadFile(fileId, fileName);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      final result = await OpenFilex.open(file.path);

      if (!context.mounted) return;

      switch (result.type) {
        case ResultType.done:
          // Berhasil dibuka
          break;
        case ResultType.noAppToOpen:
          _showNoAppDialog(context, fileName, file.path);
          break;
        case ResultType.fileNotFound:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File tidak ditemukan di penyimpanan lokal')),
          );
          break;
        case ResultType.permissionDenied:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Izin akses penyimpanan ditolak')),
          );
          break;
        case ResultType.error:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal membuka file: ${result.message}')),
          );
          break;
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengambil file: $e')),
      );
    }
  }

  /// Bagikan file ke aplikasi lain (WhatsApp, Email, dll)
  static Future<void> shareFile({
    required String fileId,
    required String fileName,
  }) async {
    try {
      final file = await getOrDownloadFile(fileId, fileName);
      await Share.shareXFiles([XFile(file.path)], text: fileName);
    } catch (_) {
      // Fallback kirim link jika gagal share binary
      final url = '${ApiService.baseUrl}/api/files/$fileId/download';
      await Share.share('File: $fileName\n$url');
    }
  }

  /// Dialog bantuan jika tidak ada aplikasi pendukung di perangkat
  static void _showNoAppDialog(BuildContext context, String fileName, String localPath) {
    final ext = fileName.contains('.') ? fileName.split('.').last.toUpperCase() : 'file';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.info_outline, color: Color(0xFF128C7E)),
            const SizedBox(width: 8),
            const Text('Aplikasi Tidak Ditemukan'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tidak ada aplikasi di perangkat untuk membuka file .$ext ($fileName).'),
            const SizedBox(height: 12),
            const Text(
              'Silakan instal aplikasi seperti Microsoft 365 (Word/Excel), WPS Office, atau PDF Viewer dari Google Play Store.',
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            Text(
              'File sudah tersimpan di:\n$localPath',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.share, size: 16),
            label: const Text('Bagikan'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF128C7E),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Share.shareXFiles([XFile(localPath)], text: fileName);
            },
          ),
        ],
      ),
    );
  }
}
