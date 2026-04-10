import 'package:example/models/app_document.dart';
import 'package:example/pages/editor_page.dart';
import 'package:example/pages/web_editor_page.dart';
import 'package:example/providers/document_list_provider.dart';
import 'package:example/providers/editor_provider.dart';
import 'package:example/providers/web_editor_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class DocumentListPage extends StatefulWidget {
  const DocumentListPage({super.key, this.initialFilePath});

  final String? initialFilePath;

  @override
  State<DocumentListPage> createState() => _DocumentListPageState();
}

class _DocumentListPageState extends State<DocumentListPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<DocumentListProvider>();
      await provider.load();
      if (widget.initialFilePath != null && mounted) {
        final doc = await provider.importFromPath(widget.initialFilePath!);
        if (doc != null && mounted) _navigateToEditor(doc);
      }
    });
  }

  void _navigateToEditor(AppDocument doc, {bool initialEditing = false}) {
    final listProvider = context.read<DocumentListProvider>();
    final useWebEditor = listProvider.useWebEditor;

    final Widget page;
    if (useWebEditor) {
      page = ChangeNotifierProvider(
        create: (_) => WebEditorProvider(
          repo: listProvider.repo,
          document: doc,
          initialEditing: initialEditing,
        ),
        child: const WebEditorPage(),
      );
    } else {
      page = ChangeNotifierProvider(
        create: (_) => EditorProvider(
          repo: listProvider.repo,
          document: doc,
          initialEditing: initialEditing,
        ),
        child: const EditorPage(),
      );
    }

    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => page))
        .then((_) {
      if (mounted) context.read<DocumentListProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DocumentListProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: provider.loading
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                slivers: [
                  // Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                      child: Text(
                        'Documents',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                  ),
                  // Editor mode switcher card
                  SliverToBoxAdapter(
                    child: _EditorModeSwitcher(
                      useWebEditor: provider.useWebEditor,
                      onToggle: provider.toggleEditorMode,
                    ),
                  ),
                  // Action row
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                      child: Row(
                        children: [
                          Text(
                            'Recent',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            icon: const Icon(Icons.folder_open, size: 18),
                            label: const Text('Open'),
                            onPressed: () async {
                              final doc = await provider.pickAndImport();
                              if (doc != null && mounted) _navigateToEditor(doc);
                            },
                          ),
                          const SizedBox(width: 4),
                          TextButton.icon(
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('New'),
                            onPressed: () async {
                              final doc = await provider.create();
                              if (mounted) {
                                _navigateToEditor(doc, initialEditing: true);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Document list or empty state
                  if (provider.documents.isEmpty)
                    SliverFillRemaining(child: _buildEmptyState())
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      sliver: SliverList.builder(
                        itemCount: provider.documents.length,
                        itemBuilder: (context, index) {
                          final doc = provider.documents[index];
                          return _DocumentCard(
                            document: doc,
                            onTap: () => _navigateToEditor(doc),
                            onDelete: () => _confirmDelete(context, provider, doc),
                          );
                        },
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.article_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No documents yet',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a new document or open a markdown file',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    DocumentListProvider provider,
    AppDocument doc,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Document'),
        content: Text('Delete "${doc.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await provider.delete(doc.id);
    }
  }
}

// ============================================================
// Editor Mode Switcher Card
// ============================================================

class _EditorModeSwitcher extends StatelessWidget {
  const _EditorModeSwitcher({
    required this.useWebEditor,
    required this.onToggle,
  });

  final bool useWebEditor;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            Expanded(
              child: _ModeOption(
                icon: Icons.flutter_dash,
                label: 'Flutter Editor',
                sublabel: 'Native rendering',
                selected: !useWebEditor,
                onTap: useWebEditor ? onToggle : null,
              ),
            ),
            Expanded(
              child: _ModeOption(
                icon: Icons.language,
                label: 'Web Editor',
                sublabel: 'Vditor + Mermaid',
                selected: useWebEditor,
                onTap: !useWebEditor ? onToggle : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeOption extends StatelessWidget {
  const _ModeOption({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String sublabel;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: selected
              ? (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: selected
                  ? (isDark ? Colors.white : Colors.black)
                  : (isDark ? Colors.grey[600] : Colors.grey[400]),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                      color: selected
                          ? null
                          : (isDark ? Colors.grey[500] : Colors.grey[500]),
                    ),
                  ),
                  Text(
                    sublabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey[600] : Colors.grey[500],
                    ),
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

// ============================================================
// Document Card
// ============================================================

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.document,
    required this.onTap,
    required this.onDelete,
  });

  final AppDocument document;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final preview = _contentPreview();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.description_outlined,
                      size: 18,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        document.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      _formatDate(document.updatedAt),
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
                if (preview.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: isDark ? Colors.grey[500] : Colors.grey[600],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    _Tag(
                      label: '${document.content.split('\n').length} lines',
                      color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: onDelete,
                      child: Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _contentPreview() {
    final lines = document.content.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      if (trimmed.startsWith('---') || trimmed.startsWith('```')) continue;
      return trimmed;
    }
    return '';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
      ),
    );
  }
}
