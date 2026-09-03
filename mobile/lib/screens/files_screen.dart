import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/file_item.dart';
import '../services/api_service.dart';
import '../services/app_state.dart';
import '../services/file_viewer_service.dart';
import 'preview_screen.dart';
import 'search_screen.dart';

// Layar daftar file tersimpan (3 tab: Gambar / Dokumen / Arsip)
class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('File Tersimpan'),
          backgroundColor: const Color(0xFF128C7E),
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Cari file & pesan',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Muat ulang',
              onPressed: () => context.read<AppState>().refreshFiles(),
            ),
          ],
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.image), text: 'Gambar'),
              Tab(icon: Icon(Icons.description), text: 'Dokumen'),
              Tab(icon: Icon(Icons.folder_zip), text: 'Arsip'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _FileGrid(files: appState.images, emptyIcon: Icons.image_outlined),
            _FileList(files: appState.documents, emptyIcon: Icons.description_outlined),
            _FileList(files: appState.archives, emptyIcon: Icons.folder_zip_outlined),
          ],
        ),
      ),
    );
  }
}

// Grid untuk gambar (thumbnail besar)
class _FileGrid extends StatelessWidget {
  final List<FileItem> files;
  final IconData emptyIcon;

  const _FileGrid({required this.files, required this.emptyIcon});

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) return _Empty(msg: 'Belum ada gambar', icon: emptyIcon);
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: files.length,
      itemBuilder: (ctx, i) {
        final f = files[i];
        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PreviewScreen(
                fileId: f.id,
                initialFileName: f.originalName,
                initialCategory: f.category,
                autoOpen: false,
              ),
            ),
          ),
          child: Hero(
            tag: 'img-${f.id}',
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: Colors.black12,
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.network(
                ApiService.getRawImageUrl(f.id),
                headers: ApiService.getImageHeaders(),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.image,
                    color: Colors.grey),
              ),
            ),
          ),
        );
      },
    );
  }
}

// List untuk dokumen & arsip
class _FileList extends StatelessWidget {
  final List<FileItem> files;
  final IconData emptyIcon;

  const _FileList({required this.files, required this.emptyIcon});

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) return _Empty(msg: 'Belum ada file', icon: emptyIcon);
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      itemCount: files.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (ctx, i) {
        final f = files[i];
        return ListTile(
          leading: _FileLeadingIcon(file: f),
          title: Text(
            f.originalName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: Text(
            '${f.sizeLabel} • ${f.category == 'archive' ? 'Arsip' : 'Dokumen'}',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.open_in_new, color: Color(0xFF128C7E), size: 20),
            tooltip: 'Buka File Langsung',
            onPressed: () => FileViewerService.openFile(
              context,
              fileId: f.id,
              fileName: f.originalName,
              category: f.category,
            ),
          ),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PreviewScreen(
                fileId: f.id,
                initialFileName: f.originalName,
                initialCategory: f.category,
                autoOpen: true,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FileLeadingIcon extends StatelessWidget {
  final FileItem file;
  const _FileLeadingIcon({required this.file});

  @override
  Widget build(BuildContext context) {
    final lower = file.originalName.toLowerCase();
    Color color = const Color(0xFF128C7E);
    IconData icon = Icons.description;
    String badge = 'DOC';

    if (lower.endsWith('.doc') || lower.endsWith('.docx') || file.mime.contains('word')) {
      color = const Color(0xFF2B579A);
      icon = Icons.description;
      badge = 'WORD';
    } else if (lower.endsWith('.xls') || lower.endsWith('.xlsx') || file.mime.contains('excel')) {
      color = const Color(0xFF217346);
      icon = Icons.table_chart;
      badge = 'EXCEL';
    } else if (lower.endsWith('.ppt') || lower.endsWith('.pptx') || file.mime.contains('presentation')) {
      color = const Color(0xFFD24726);
      icon = Icons.slideshow;
      badge = 'PPT';
    } else if (lower.endsWith('.pdf') || file.mime == 'application/pdf') {
      color = const Color(0xFFD32F2F);
      icon = Icons.picture_as_pdf;
      badge = 'PDF';
    } else if (lower.endsWith('.zip') || lower.endsWith('.rar') || lower.endsWith('.7z') || file.category == 'archive') {
      color = const Color(0xFFF57C00);
      icon = Icons.folder_zip;
      badge = 'ZIP';
    } else if (lower.endsWith('.txt') || lower.endsWith('.md')) {
      color = const Color(0xFF00796B);
      icon = Icons.article;
      badge = 'TXT';
    }

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
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

class _Empty extends StatelessWidget {
  final String msg;
  final IconData icon;
  const _Empty({required this.msg, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: Colors.grey),
          const SizedBox(height: 10),
          Text(msg, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
