// Bookmarks with folders.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/surah_metadata.dart';
import '../data/models.dart';
import '../services/providers.dart';
import '../widgets/ayat_card.dart';

class BookmarksScreen extends ConsumerStatefulWidget {
  const BookmarksScreen({super.key});
  @override
  ConsumerState<BookmarksScreen> createState() => _BmState();
}

class _BmState extends ConsumerState<BookmarksScreen> {
  List<BookmarkFolder> _folders = [];
  List<Bookmark> _items = [];
  int? _folderId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = ref.read(progressRepoProvider);
    final folders = await p.folders();
    _folderId ??= folders.first.id;
    final items = await p.bookmarks(folderId: null);
    if (!mounted) return;
    setState(() {
      _folders = folders;
      _items = items;
      _loading = false;
    });
  }

  List<Bookmark> get _filtered => _folderId == null
      ? _items
      : _items.where((b) => b.folderId == _folderId).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved'),
        actions: [
          IconButton(
            icon: const Icon(Icons.create_new_folder_outlined),
            onPressed: _newFolder,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      ChoiceChip(
                        label: const Text('All'),
                        selected: _folderId == null,
                        onSelected: (_) => setState(() => _folderId = null),
                      ),
                      const SizedBox(width: 8),
                      for (final f in _folders)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(f.name),
                            selected: _folderId == f.id,
                            onSelected: (_) => setState(() => _folderId = f.id),
                          ),
                        ),
                    ],
                  ),
                ),
                if (_folderId != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        TextButton.icon(
                          onPressed: _renameFolder,
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('Rename'),
                        ),
                        TextButton.icon(
                          onPressed: _deleteFolder,
                          icon: const Icon(Icons.delete_outline, size: 16),
                          label: const Text('Delete'),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: _filtered.isEmpty
                      ? const EmptyState(
                          icon: Icons.bookmark_outline,
                          message: 'No bookmarks yet.\nOpen the daily ayat and tap Save.')
                      : ListView.builder(
                          itemCount: _filtered.length,
                          itemBuilder: (c, i) {
                            final b = _filtered[i];
                            return Dismissible(
                              key: ValueKey(b.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                color: Colors.red,
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                child: const Icon(Icons.delete, color: Colors.white),
                              ),
                              onDismissed: (_) async {
                                await ref.read(progressRepoProvider).toggleBookmark(b.surah, b.ayah);
                                await _load();
                              },
                              child: ListTile(
                                leading: const Icon(Icons.bookmark),
                                title: Text('QS. ${kSurahs[b.surah - 1].latin} : ${b.ayah}'),
                                subtitle: Text('Juz ${juzFor(b.surah, b.ayah)}'),
                                trailing: PopupMenuButton<int?>(
                                  onSelected: (fid) async {
                                    await ref.read(progressRepoProvider).moveBookmark(b.id!, fid);
                                    await _load();
                                  },
                                  itemBuilder: (c) => [
                                    for (final f in _folders)
                                      PopupMenuItem(value: f.id, child: Text('Move to ${f.name}')),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Future<void> _newFolder() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('New folder'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'Folder name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Create')),
        ],
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      await ref.read(progressRepoProvider).createFolder(ctrl.text);
      await _load();
    }
  }

  Future<void> _renameFolder() async {
    final f = _folders.firstWhere((e) => e.id == _folderId);
    final ctrl = TextEditingController(text: f.name);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Rename folder'),
        content: TextField(controller: ctrl),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      await ref.read(progressRepoProvider).renameFolder(f.id!, ctrl.text);
      await _load();
    }
  }

  Future<void> _deleteFolder() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete folder?'),
        content: const Text('Bookmarks in this folder will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(progressRepoProvider).deleteFolder(_folderId!);
      setState(() => _folderId = null);
      await _load();
    }
  }
}
