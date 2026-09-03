import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../services/file_viewer_service.dart';
import 'preview_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String val) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) context.read<AppState>().search(val);
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final results = appState.searchResults;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cari File & Pesan'),
        backgroundColor: const Color(0xFF128C7E),
        foregroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              onChanged: _onChanged,
              decoration: InputDecoration(
                hintText: 'Ketik untuk mencari...',
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _ctrl.clear();
                    context.read<AppState>().clearSearch();
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: _ctrl.text.isEmpty && results.isEmpty
          ? const _EmptySearch()
          : results.isEmpty && _ctrl.text.isNotEmpty
              ? const _NoResults()
              : ListView.separated(
                  itemCount: results.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final r = results[i];
                    final isFile = r.type == 'file';

                    return ListTile(
                      leading: _SearchResultIcon(result: r),
                      title: Text(
                        isFile ? (r.name ?? 'file') : (r.body ?? ''),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        isFile
                            ? '${r.category ?? 'file'} • ${r.mime ?? ''}'
                            : 'Pesan chat',
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                      trailing: isFile
                          ? IconButton(
                              icon: const Icon(Icons.open_in_new, size: 20, color: Color(0xFF128C7E)),
                              tooltip: 'Buka File',
                              onPressed: () {
                                final id = r.id;
                                if (id == null) return;
                                FileViewerService.openFile(
                                  context,
                                  fileId: id,
                                  fileName: r.name ?? 'file',
                                  category: r.category,
                                );
                              },
                            )
                          : const Icon(Icons.chevron_right, color: Colors.grey),
                      onTap: () {
                        if (isFile) {
                          final id = r.id;
                          if (id == null) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PreviewScreen(
                                fileId: id,
                                initialFileName: r.name,
                                initialCategory: r.category,
                                autoOpen: r.category != 'image',
                              ),
                            ),
                          );
                        } else {
                          context.read<AppState>().openSearchResult(r);
                          Navigator.pop(context);
                        }
                      },
                    );
                  },
                ),
    );
  }
}

class _SearchResultIcon extends StatelessWidget {
  final dynamic result;
  const _SearchResultIcon({required this.result});

  @override
  Widget build(BuildContext context) {
    if (result.type != 'file') {
      return Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFF128C7E).withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.chat_bubble_outline, color: Color(0xFF128C7E), size: 20),
      );
    }

    final name = (result.name as String? ?? '').toLowerCase();
    Color color = const Color(0xFF128C7E);
    IconData icon = Icons.description;
    String badge = 'FILE';

    if (name.endsWith('.doc') || name.endsWith('.docx')) {
      color = const Color(0xFF2B579A);
      icon = Icons.description;
      badge = 'WORD';
    } else if (name.endsWith('.xls') || name.endsWith('.xlsx')) {
      color = const Color(0xFF217346);
      icon = Icons.table_chart;
      badge = 'EXCEL';
    } else if (name.endsWith('.ppt') || name.endsWith('.pptx')) {
      color = const Color(0xFFD24726);
      icon = Icons.slideshow;
      badge = 'PPT';
    } else if (name.endsWith('.pdf')) {
      color = const Color(0xFFD32F2F);
      icon = Icons.picture_as_pdf;
      badge = 'PDF';
    } else if (result.category == 'image') {
      color = Colors.teal;
      icon = Icons.image;
      badge = 'IMG';
    } else if (result.category == 'archive') {
      color = const Color(0xFFF57C00);
      icon = Icons.folder_zip;
      badge = 'ZIP';
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

class _EmptySearch extends StatelessWidget {
  const _EmptySearch();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 64, color: Colors.grey),
          SizedBox(height: 12),
          Text('Cari file atau pesan', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey),
          SizedBox(height: 12),
          Text('Tidak ada hasil', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
