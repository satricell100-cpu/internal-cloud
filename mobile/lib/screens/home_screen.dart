import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/file_item.dart';
import '../models/message.dart';
import '../services/app_state.dart';
import '../services/auth_provider.dart';
import 'chat_screen.dart';
import 'files_screen.dart';
import 'profil_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final index = appState.activeTabIndex;
    final screens = [
      const ChatScreen(),
      const FilesScreen(),
      const ProfilScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: index, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => context.read<AppState>().setActiveTab(i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder),
            label: 'File',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// DASHBOARD - ditampilkan sebagai bagian dari ChatScreen
// Bisa diakses dari tombol home/di dalam chat
// ═══════════════════════════════════════════════════════════════

class DashboardView extends StatelessWidget {
  final VoidCallback? onSeeAllChat;
  final VoidCallback? onSeeAllFiles;
  final VoidCallback? onChatTap;
  final VoidCallback? onFilesTap;
  final Function(FileItem)? onFileTap;

  const DashboardView({
    super.key,
    this.onSeeAllChat,
    this.onSeeAllFiles,
    this.onChatTap,
    this.onFilesTap,
    this.onFileTap,
  });

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final auth = context.watch<AuthProvider>();
    final messages = appState.messages;
    final recentMessages = messages.take(3).toList();
    final imageCount = appState.images.length;
    final docCount = appState.documents.length;
    final archiveCount = appState.archives.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Internal Cloud'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          // Status online
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: appState.isOnline ? Colors.green : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  appState.isOnline ? 'Online' : 'Offline',
                  style: TextStyle(
                    color: appState.isOnline ? Colors.green : Colors.grey,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Cari file & pesan',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SearchScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {},
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => appState.loadAll(),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 20),
          children: [
            // ═══ Chat Terbaru ═══
            _SectionHeader(
              title: 'Chat Terbaru',
              trailing: onSeeAllChat != null
                  ? TextButton(
                      onPressed: onSeeAllChat,
                      child: const Text('Lihat Semua'),
                    )
                  : null,
            ),
            if (recentMessages.isEmpty)
              const _EmptyCard(
                icon: Icons.chat_bubble_outline,
                message: 'Belum ada pesan',
              )
            else
              ...recentMessages.map((m) => _ChatPreviewCard(
                    message: m,
                    onTap: () => onChatTap?.call(),
                  )),

            const SizedBox(height: 8),

            // ═══ File Tersimpan ═══
            _SectionHeader(
              title: 'File Tersimpan',
              trailing: onSeeAllFiles != null
                  ? TextButton(
                      onPressed: onSeeAllFiles,
                      child: const Text('Lihat Semua'),
                    )
                  : null,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _CategoryCard(
                    icon: Icons.image,
                    label: 'Gambar',
                    count: imageCount,
                    onTap: onFilesTap,
                  ),
                  const SizedBox(width: 10),
                  _CategoryCard(
                    icon: Icons.description,
                    label: 'Dokumen',
                    count: docCount,
                    onTap: onFilesTap,
                  ),
                  const SizedBox(width: 10),
                  _CategoryCard(
                    icon: Icons.folder_zip,
                    label: 'Arsip',
                    count: archiveCount,
                    onTap: onFilesTap,
                  ),
                  const SizedBox(width: 10),
                  _CategoryCard(
                    icon: Icons.star,
                    label: 'Favorit',
                    count: 0,
                    onTap: onFilesTap,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ═══ Penyimpanan ═══
            _SectionHeader(title: 'Penyimpanan'),
            _StorageCard(
              usedBytes: _estimateUsedBytes(appState),
              totalBytes: 10 * 1024 * 1024 * 1024, // 10 GB
              segments: [
                _StorageSegment('Dokumen', docCount * 1024 * 1024 * 12, const Color(0xFF1B5E4B)),
                _StorageSegment('Gambar', imageCount * 1024 * 1024 * 5, const Color(0xFF2E9E7E)),
                _StorageSegment('Arsip', archiveCount * 1024 * 1024 * 6, const Color(0xFF6FCF97)),
                _StorageSegment('Lainnya', 200 * 1024 * 1024, const Color(0xFFB0BEC5)),
              ],
            ),

            const SizedBox(height: 8),

            // ═══ Akun Saya ═══
            _SectionHeader(title: 'Akun Saya'),
            _AccountCard(
              name: auth.user?.displayName ?? 'Pengguna',
              email: '${auth.user?.username ?? 'user'}@internal.cloud',
              onTap: () => context.read<AppState>().setActiveTab(2),
            ),
          ],
        ),
      ),
    );
  }

  int _estimateUsedBytes(AppState s) {
    int total = 0;
    for (final f in s.allFiles) {
      total += f.sizeBytes;
    }
    if (total == 0) total = 2400 * 1024 * 1024; // demo: 2.4 GB
    return total;
  }
}

// ── Komponen kecil ────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const _SectionHeader({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyCard({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 36, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(message, style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }
}

// Preview chat card sesuai screenshot
class _ChatPreviewCard extends StatelessWidget {
  final Message message;
  final VoidCallback? onTap;

  const _ChatPreviewCard({required this.message, this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasFiles = message.files.isNotEmpty;
    final file = hasFiles ? message.files.first : null;
    final dt = DateTime.fromMillisecondsSinceEpoch(message.ts);
    final timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFDCF8C6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Jika ada file, tampilkan chip file
            if (hasFiles && file != null) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _FileTypeIcon(category: file.category),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            file.originalName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            file.sizeLabel,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (message.body != null && message.body!.isNotEmpty)
                const SizedBox(height: 6),
            ],
            // Teks pesan
            if (message.body != null && message.body!.isNotEmpty)
              Text(
                message.body!,
                style: const TextStyle(fontSize: 15),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            // Waktu + centang
            Align(
              alignment: Alignment.bottomRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    timeStr,
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.done_all, size: 16, color: Colors.blue),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FileTypeIcon extends StatelessWidget {
  final String category;
  const _FileTypeIcon({required this.category});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;
    switch (category) {
      case 'image':
        icon = Icons.image;
        color = Colors.teal;
        break;
      case 'document':
        icon = Icons.description;
        color = Colors.blue;
        break;
      case 'archive':
        icon = Icons.folder_zip;
        color = Colors.orange;
        break;
      default:
        icon = Icons.insert_drive_file;
        color = Colors.grey;
    }
    return Icon(icon, color: color, size: 28);
  }
}

class _CategoryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final VoidCallback? onTap;

  const _CategoryCard({
    required this.icon,
    required this.label,
    required this.count,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon, size: 28, color: Colors.grey.shade600),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$count file',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Storage Card (Donut chart) ────────────────────────────────

class _StorageSegment {
  final String label;
  final int bytes;
  final Color color;
  _StorageSegment(this.label, this.bytes, this.color);
}

class _StorageCard extends StatelessWidget {
  final int usedBytes;
  final int totalBytes;
  final List<_StorageSegment> segments;

  const _StorageCard({
    required this.usedBytes,
    required this.totalBytes,
    required this.segments,
  });

  @override
  Widget build(BuildContext context) {
    final usedGB = usedBytes / (1024 * 1024 * 1024);
    final totalGB = totalBytes / (1024 * 1024 * 1024);
    final percent = (usedBytes / totalBytes * 100).clamp(0, 100);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          // Donut chart
          SizedBox(
            width: 120,
            height: 120,
            child: CustomPaint(
              painter: _DonutPainter(segments: segments, totalBytes: totalBytes),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${usedGB.toStringAsFixed(1)} GB',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '/ ${totalGB.toStringAsFixed(0)} GB',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Detail
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${percent.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF128C7E),
                  ),
                ),
                Text(
                  'digunakan',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                // Linear progress
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percent / 100,
                    minHeight: 6,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF128C7E)),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${usedGB.toStringAsFixed(1)} GB dari ${totalGB.toStringAsFixed(0)} GB',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 8),
                // Legend
                ...segments.map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: s.color,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              s.label,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<_StorageSegment> segments;
  final int totalBytes;

  _DonutPainter({required this.segments, required this.totalBytes});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const strokeWidth = 16.0;

    double startAngle = -pi / 2;
    for (final seg in segments) {
      final sweep = (seg.bytes / totalBytes) * 2 * pi;
      final paint = Paint()
        ..color = seg.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        false,
        paint,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Account Card ──────────────────────────────────────────────

class _AccountCard extends StatelessWidget {
  final String name;
  final String email;
  final VoidCallback? onTap;

  const _AccountCard({required this.name, required this.email, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ListTile(
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: Colors.grey.shade300,
          child: const Icon(Icons.person, color: Colors.white, size: 28),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          email,
          style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
        ),
        trailing: const Icon(Icons.chevron_right),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: Colors.grey.shade50,
        onTap: onTap,
      ),
    );
  }
}
