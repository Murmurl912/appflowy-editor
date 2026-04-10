import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

// ============================================================
// Callout Block
// ============================================================

class CalloutBlockKeys {
  const CalloutBlockKeys._();
  static const String type = 'callout';
  static const String icon = 'icon';
}

Node calloutNode({String icon = 'bulb', Delta? delta}) {
  return Node(
    type: CalloutBlockKeys.type,
    attributes: {
      CalloutBlockKeys.icon: icon,
      'delta': (delta ?? (Delta()..insert(''))).toJson(),
    },
  );
}

class CalloutBlockComponentBuilder extends BlockComponentBuilder {
  CalloutBlockComponentBuilder({super.configuration});

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    return CalloutBlockWidget(
      key: blockComponentContext.node.key,
      node: blockComponentContext.node,
      configuration: configuration,
    );
  }
}

class CalloutBlockWidget extends BlockComponentStatefulWidget {
  const CalloutBlockWidget({
    super.key,
    required super.node,
    required super.configuration,
  });

  @override
  State<CalloutBlockWidget> createState() => _CalloutBlockState();
}

class _CalloutBlockState extends State<CalloutBlockWidget>
    with
        SelectableMixin,
        DefaultSelectableMixin,
        BlockComponentConfigurable,
        BlockComponentTextDirectionMixin,
        BlockComponentBackgroundColorMixin {
  @override
  BlockComponentConfiguration get configuration => widget.configuration;
  @override
  Node get node => widget.node;
  @override
  final forwardKey = GlobalKey(debugLabel: 'callout_rich_text');
  @override
  GlobalKey<State<StatefulWidget>> blockComponentKey = GlobalKey(debugLabel: 'callout');
  @override
  GlobalKey<State<StatefulWidget>> get containerKey => node.key;
  @override
  late final editorState = context.read<EditorState>();

  static const _iconMap = {
    'bulb': Icons.lightbulb_outline,
    'warning': Icons.warning_amber,
    'info': Icons.info_outline,
    'star': Icons.star_outline,
    'check': Icons.check_circle_outline,
  };

  String get _icon => node.attributes[CalloutBlockKeys.icon] as String? ?? 'bulb';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: padding,
      child: Container(
        key: blockComponentKey,
        width: double.infinity,
        decoration: BoxDecoration(
          color: isDark ? Colors.blueGrey.withValues(alpha: 0.15) : Colors.blue.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? Colors.blueGrey.withValues(alpha: 0.3) : Colors.blue.withValues(alpha: 0.1),
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: editorState.editable ? _cycleIcon : null,
              child: Padding(
                padding: const EdgeInsets.only(right: 10, top: 1),
                child: Icon(
                  _iconMap[_icon] ?? Icons.lightbulb_outline,
                  size: 20,
                  color: isDark ? Colors.blueGrey[300] : Colors.blue[700],
                ),
              ),
            ),
            Expanded(
              child: AppFlowyRichText(
                key: forwardKey,
                delegate: this,
                node: node,
                editorState: editorState,
                placeholderText: 'Type something...',
                textDirection: textDirection(),
                cursorHeight: 18,
                lineHeight: 1.5,
                cursorColor: editorState.editorStyle.cursorColor,
                selectionColor: editorState.editorStyle.selectionColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _cycleIcon() {
    final icons = _iconMap.keys.toList();
    final current = icons.indexOf(_icon);
    final next = icons[(current + 1) % icons.length];
    final transaction = editorState.transaction..updateNode(node, {CalloutBlockKeys.icon: next});
    editorState.apply(transaction);
  }
}

// ============================================================
// Toggle List Block (inline editing, collapsible children)
// ============================================================

class ToggleListBlockKeys {
  const ToggleListBlockKeys._();
  static const String type = 'toggle_list';
  static const String collapsed = 'collapsed';
  static const String level = 'level';
}

Node toggleListNode({
  bool collapsed = false,
  Delta? delta,
  Iterable<Node> children = const [],
  int? level,
}) {
  return Node(
    type: ToggleListBlockKeys.type,
    attributes: {
      ToggleListBlockKeys.collapsed: collapsed,
      if (level != null) ToggleListBlockKeys.level: level,
      'delta': (delta ?? (Delta()..insert(''))).toJson(),
    },
    children: children,
  );
}

class ToggleListBlockComponentBuilder extends BlockComponentBuilder {
  ToggleListBlockComponentBuilder({super.configuration});

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    return ToggleListBlockWidget(
      key: blockComponentContext.node.key,
      node: blockComponentContext.node,
      configuration: configuration,
    );
  }

  @override
  BlockComponentValidate get validate => (node) => node.delta != null;
}

class ToggleListBlockWidget extends BlockComponentStatefulWidget {
  const ToggleListBlockWidget({
    super.key,
    required super.node,
    required super.configuration,
  });

  @override
  State<ToggleListBlockWidget> createState() => _ToggleListBlockState();
}

class _ToggleListBlockState extends State<ToggleListBlockWidget>
    with
        SelectableMixin,
        DefaultSelectableMixin,
        BlockComponentConfigurable,
        BlockComponentTextDirectionMixin,
        BlockComponentBackgroundColorMixin {
  @override
  BlockComponentConfiguration get configuration => widget.configuration;
  @override
  Node get node => widget.node;
  @override
  final forwardKey = GlobalKey(debugLabel: 'toggle_rich_text');
  @override
  GlobalKey<State<StatefulWidget>> blockComponentKey = GlobalKey(debugLabel: 'toggle');
  @override
  GlobalKey<State<StatefulWidget>> get containerKey => node.key;
  @override
  late final editorState = context.read<EditorState>();

  bool get _collapsed => node.attributes[ToggleListBlockKeys.collapsed] as bool? ?? false;
  int? get _level => node.attributes[ToggleListBlockKeys.level] as int?;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Container(
        key: blockComponentKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Toggle header with inline editable text
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildExpandIcon(),
                Expanded(child: _buildRichText()),
              ],
            ),
            // Children (when expanded)
            if (!_collapsed && node.children.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: editorState.renderer
                      .buildList(context, node.children),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandIcon() {
    return GestureDetector(
      onTap: _onToggle,
      child: Container(
        constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
        alignment: Alignment.center,
        child: AnimatedRotation(
          turns: _collapsed ? 0 : 0.25,
          duration: const Duration(milliseconds: 200),
          child: const Icon(Icons.arrow_right, size: 18),
        ),
      ),
    );
  }

  Widget _buildRichText() {
    final level = _level;
    return AppFlowyRichText(
      key: forwardKey,
      delegate: this,
      node: node,
      editorState: editorState,
      placeholderText: 'Toggle heading',
      textDirection: textDirection(),
      lineHeight: 1.5,
      textSpanDecorator: (textSpan) {
        if (level != null) {
          final fontSize = switch (level) {
            1 => 24.0,
            2 => 20.0,
            3 => 18.0,
            _ => 16.0,
          };
          return textSpan.updateTextStyle(
            TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600),
          );
        }
        return textSpan;
      },
      cursorColor: editorState.editorStyle.cursorColor,
      selectionColor: editorState.editorStyle.selectionColor,
    );
  }

  void _onToggle() {
    final transaction = editorState.transaction
      ..updateNode(node, {ToggleListBlockKeys.collapsed: !_collapsed});
    transaction.afterSelection = editorState.selection;
    editorState.apply(transaction);
  }
}

// ============================================================
// Video Block
// ============================================================

class VideoBlockKeys {
  const VideoBlockKeys._();
  static const String type = 'video';
  static const String url = 'url';
}

Node videoNode({String url = ''}) {
  return Node(type: VideoBlockKeys.type, attributes: {VideoBlockKeys.url: url});
}

class VideoBlockComponentBuilder extends BlockComponentBuilder {
  VideoBlockComponentBuilder({super.configuration});

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    return VideoBlockWidget(
      key: blockComponentContext.node.key,
      node: blockComponentContext.node,
      configuration: configuration,
    );
  }

  @override
  BlockComponentValidate get validate =>
      (node) => node.attributes[VideoBlockKeys.url] is String;
}

class VideoBlockWidget extends BlockComponentStatefulWidget {
  const VideoBlockWidget({super.key, required super.node, required super.configuration});

  @override
  State<VideoBlockWidget> createState() => _VideoBlockState();
}

class _VideoBlockState extends State<VideoBlockWidget> with BlockComponentConfigurable {
  @override
  BlockComponentConfiguration get configuration => widget.configuration;
  @override
  Node get node => widget.node;
  late final editorState = context.read<EditorState>();
  String get _url => node.attributes[VideoBlockKeys.url] as String? ?? '';
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  void _initPlayer() {
    if (_url.isEmpty) return;
    final uri = Uri.tryParse(_url);
    if (uri == null) return;
    _controller = VideoPlayerController.networkUrl(uri)
      ..initialize().then((_) { if (mounted) setState(() {}); });
  }

  @override
  void dispose() { _controller?.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_url.isEmpty) {
      return Padding(
        padding: padding,
        child: GestureDetector(
          onTap: editorState.editable ? () => _showUrlDialog(context) : null,
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
            ),
            child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.videocam_outlined, size: 32, color: Colors.grey[500]),
              const SizedBox(height: 8),
              Text('Tap to add video URL', style: TextStyle(color: Colors.grey[500])),
            ])),
          ),
        ),
      );
    }
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) {
      return Padding(padding: padding, child: Container(height: 200, decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8)), child: const Center(child: CircularProgressIndicator())));
    }
    return Padding(
      padding: padding,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: AspectRatio(
          aspectRatio: ctrl.value.aspectRatio,
          child: Stack(alignment: Alignment.center, children: [
            VideoPlayer(ctrl),
            GestureDetector(
              onTap: () => setState(() { ctrl.value.isPlaying ? ctrl.pause() : ctrl.play(); }),
              child: AnimatedOpacity(
                opacity: ctrl.value.isPlaying ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Container(decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle), padding: const EdgeInsets.all(12), child: const Icon(Icons.play_arrow, color: Colors.white, size: 32)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _showUrlDialog(BuildContext context) {
    final controller = TextEditingController(text: _url);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Video URL'),
      content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'https://example.com/video.mp4')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        TextButton(onPressed: () { final url = controller.text.trim(); if (url.isNotEmpty) { editorState.transaction..updateNode(node, {VideoBlockKeys.url: url}); } Navigator.pop(ctx); }, child: const Text('Done')),
      ],
    ));
  }
}

// ============================================================
// PDF Block
// ============================================================

class PdfBlockKeys {
  const PdfBlockKeys._();
  static const String type = 'pdf';
  static const String url = 'url';
  static const String name = 'name';
}

Node pdfNode({String url = '', String name = ''}) {
  return Node(type: PdfBlockKeys.type, attributes: {PdfBlockKeys.url: url, PdfBlockKeys.name: name});
}

class PdfBlockComponentBuilder extends BlockComponentBuilder {
  PdfBlockComponentBuilder({super.configuration});

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    return PdfBlockWidget(key: blockComponentContext.node.key, node: blockComponentContext.node, configuration: configuration);
  }

  @override
  BlockComponentValidate get validate => (node) => node.attributes[PdfBlockKeys.url] is String;
}

class PdfBlockWidget extends BlockComponentStatefulWidget {
  const PdfBlockWidget({super.key, required super.node, required super.configuration});

  @override
  State<PdfBlockWidget> createState() => _PdfBlockState();
}

class _PdfBlockState extends State<PdfBlockWidget> with BlockComponentConfigurable {
  @override
  BlockComponentConfiguration get configuration => widget.configuration;
  @override
  Node get node => widget.node;
  late final editorState = context.read<EditorState>();
  String get _url => node.attributes[PdfBlockKeys.url] as String? ?? '';
  String get _name => node.attributes[PdfBlockKeys.name] as String? ?? '';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_url.isEmpty) {
      return Padding(padding: padding, child: GestureDetector(
        onTap: editorState.editable ? () => _showUrlDialog(context) : null,
        child: Container(height: 80, decoration: BoxDecoration(color: isDark ? Colors.grey[900] : Colors.grey[100], borderRadius: BorderRadius.circular(8), border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[300]!)),
          child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.picture_as_pdf, size: 28, color: Colors.red[400]), const SizedBox(width: 8), Text('Tap to add PDF', style: TextStyle(color: Colors.grey[500]))]))),
      ));
    }
    final displayName = _name.isNotEmpty ? _name : Uri.tryParse(_url)?.pathSegments.lastOrNull ?? _url;
    return Padding(padding: padding, child: Container(
      decoration: BoxDecoration(color: isDark ? Colors.grey[900] : Colors.grey[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Icon(Icons.picture_as_pdf, size: 32, color: Colors.red[400]),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(displayName, style: const TextStyle(fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text('PDF Document', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        ])),
        if (editorState.editable) IconButton(icon: const Icon(Icons.edit_outlined, size: 18), onPressed: () => _showUrlDialog(context)),
      ]),
    ));
  }

  void _showUrlDialog(BuildContext context) {
    final urlCtrl = TextEditingController(text: _url);
    final nameCtrl = TextEditingController(text: _name);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('PDF Document'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameCtrl, decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Name', hintText: 'Document name')),
        const SizedBox(height: 12),
        TextField(controller: urlCtrl, decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'URL', hintText: 'https://example.com/file.pdf')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        TextButton(onPressed: () { editorState.transaction..updateNode(node, {PdfBlockKeys.url: urlCtrl.text.trim(), PdfBlockKeys.name: nameCtrl.text.trim()}); Navigator.pop(ctx); }, child: const Text('Done')),
      ],
    ));
  }
}
