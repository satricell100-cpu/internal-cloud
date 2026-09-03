import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/file_item.dart';
import '../services/app_state.dart';
import '../widgets/message_bubble.dart';
import 'home_screen.dart';
import 'preview_screen.dart';
import 'search_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final Map<String, GlobalKey> _messageKeys = {};
  String? _lastJumpedMessageId;
  bool _isUploading = false;
  bool _showDashboard = true;
  bool _saveToDrive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().loadAll();
    });
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndUpload() async {
    final result =
        await FilePicker.platform.pickFiles(withData: true, allowMultiple: false);
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final caption = await _showCaptionDialog();
    if (caption == null) return;
    final saveToDrive = _saveToDrive;

    final appState = context.read<AppState>();
    setState(() => _isUploading = true);
    try {
      if (kIsWeb) {
        if (file.bytes == null) throw Exception('Browser tidak memberi bytes file');
        await appState.uploadFileBytes(
          file.bytes!,
          file.name,
          caption,
          saveToDrive: saveToDrive,
        );
      } else {
        if (file.path == null) throw Exception('File path kosong');
        await appState.uploadFile(
          File(file.path!),
          file.name,
          caption,
          saveToDrive: saveToDrive,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(saveToDrive
                ? 'File berhasil diupload & disimpan ke Google Drive'
                : 'File berhasil diupload'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Gagal upload: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<String?> _showCaptionDialog() async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Caption / pesan'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Contoh: laporan mingguan',
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Simpan juga ke Google Drive'),
                subtitle: const Text('Perlu terhubung di menu Profil'),
                value: _saveToDrive,
                activeColor: const Color(0xFF128C7E),
                onChanged: (v) =>
                    setDialogState(() => _saveToDrive = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Kirim'),
            ),
          ],
        ),
      ),
    );
    return result;
  }

  Future<void> _sendText() async {
    final body = _textCtrl.text.trim();
    if (body.isEmpty) return;
    _textCtrl.clear();
    try {
      await context.read<AppState>().sendTextMessage(body);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal kirim: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final all = [...appState.messages];

    _jumpToSelectedMessage(appState.selectedMessageId);

    // Jika di dashboard mode
    if (_showDashboard) {
      return DashboardView(
        onSeeAllChat: () => setState(() => _showDashboard = false),
        onSeeAllFiles: () => context.read<AppState>().setActiveTab(1),
        onChatTap: () => setState(() => _showDashboard = false),
        onFilesTap: () => context.read<AppState>().setActiveTab(1),
      );
    }

    // Mode chat penuh
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // AppBar
            Container(
              color: const Color(0xFF128C7E),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => setState(() => _showDashboard = true),
                  ),
                  const CircleAvatar(
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.cloud, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Internal Cloud',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 17)),
                        Row(
                          children: [
                            Icon(
                              appState.isOnline
                                  ? Icons.cloud_done
                                  : Icons.cloud_off,
                              color: Colors.white70,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              appState.isOnline
                                  ? 'Online'
                                  : (appState.pendingCount > 0
                                      ? 'Offline • ${appState.pendingCount} antrian'
                                      : 'Offline'),
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.search, color: Colors.white),
                    tooltip: 'Cari pesan & file',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SearchScreen()),
                    ),
                  ),
                  if (appState.pendingCount > 0 && appState.isOnline)
                    IconButton(
                      icon: const Icon(Icons.sync, color: Colors.white),
                      tooltip: 'Sinkronkan ${appState.pendingCount} antrian',
                      onPressed: () async {
                        await context.read<AppState>().syncPending();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Sinkronisasi selesai')),
                          );
                        }
                      },
                    ),
                ],
              ),
            ),

            // Chat list
            Expanded(
              child: appState.isLoading && appState.messages.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : appState.messages.isEmpty
                      ? const _EmptyState()
                      : ListView.builder(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: all.length,
                          itemBuilder: (ctx, i) {
                            final m = all[i];
                            final key = _messageKeys.putIfAbsent(
                                m.id, () => GlobalKey());
                            return MessageBubble(
                              key: key,
                              message: m,
                              highlight:
                                  appState.highlightMessageId == m.id,
                              onFileTap: (f) => _openSpecificFile(f),
                            );
                          },
                        ),
            ),
            if (_isUploading)
              const LinearProgressIndicator(minHeight: 3),

            // Input bar
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.white,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.attach_file),
                    color: const Color(0xFF128C7E),
                    onPressed: _isUploading ? null : _pickAndUpload,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _textCtrl,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Ketik pesan...',
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _sendText(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    icon: const Icon(Icons.send, color: Colors.white),
                    style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF128C7E)),
                    onPressed: _sendText,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openSpecificFile(FileItem f) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PreviewScreen(
          fileId: f.id,
          initialFileName: f.originalName,
          initialCategory: f.category,
          autoOpen: !f.isImage,
        ),
      ),
    );
  }

  void _jumpToSelectedMessage(String? messageId) {
    if (messageId == null || messageId == _lastJumpedMessageId) return;
    _lastJumpedMessageId = messageId;
    _showDashboard = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _messageKeys[messageId]?.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.15,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      if (mounted) {
        context.read<AppState>().clearChatTarget();
      }
    });
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.forum_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 12),
          Text('Belum ada pesan',
              style: TextStyle(fontSize: 18, color: Colors.grey)),
          SizedBox(height: 4),
          Text('Tekan tombol attach untuk upload file',
              style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
