import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:example/providers/editor_provider.dart';
import 'package:example/widgets/backdrop_container.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class EditorAppbar extends StatelessWidget {
  const EditorAppbar({super.key});

  @override
  Widget build(BuildContext context) {
    final searchMode = context.select(
      (EditorProvider p) => p.searchMode,
    );
    if (searchMode) return const _SearchAppBar();
    return const _EditingBar();
  }
}

/// Editing mode: back + undo/redo + search
class _EditingBar extends StatelessWidget {
  const _EditingBar();

  @override
  Widget build(BuildContext context) {
    final (canUndo, canRedo) = context.select(
      (EditorProvider p) => (p.canUndo, p.canRedo),
    );
    return Row(
      children: [
        StadiumButtonBar(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          buttons: [
            SizedBox(
              height: 40,
              width: 40,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_sharp),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          ],
        ),
        const Spacer(),
        StadiumButtonBar(
          buttons: [
            IconButton(
              icon: const Icon(Icons.undo),
              onPressed: canUndo ? context.read<EditorProvider>().undo : null,
            ),
            IconButton(
              icon: const Icon(Icons.redo),
              onPressed: canRedo ? context.read<EditorProvider>().redo : null,
            ),
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: context.read<EditorProvider>().enterSearch,
            ),
          ],
        ),
      ],
    );
  }
}

/// Search mode
class _SearchAppBar extends StatefulWidget {
  const _SearchAppBar();

  @override
  State<_SearchAppBar> createState() => _SearchAppBarState();
}

class _SearchAppBarState extends State<_SearchAppBar> {
  late final SearchServiceV3 _searchService;
  final _controller = TextEditingController();
  int _matchCount = 0;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    final editorState = context.read<EditorProvider>().editorState;
    _searchService = SearchServiceV3(editorState: editorState);
    _searchService.matchWrappers.addListener(_onMatchChanged);
    _searchService.currentSelectedIndex.addListener(_onIndexChanged);
  }

  @override
  void dispose() {
    _searchService.findAndHighlight('');
    _searchService.matchWrappers.removeListener(_onMatchChanged);
    _searchService.currentSelectedIndex.removeListener(_onIndexChanged);
    _searchService.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onMatchChanged() {
    setState(() => _matchCount = _searchService.matchWrappers.value.length);
  }

  void _onIndexChanged() {
    setState(() => _currentIndex = _searchService.currentSelectedIndex.value);
  }

  void _onSearch(String value) {
    _searchService.findAndHighlight(value);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        StadiumButtonBar(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          buttons: [
            SizedBox(
              width: 40,
              height: 40,
              child: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  _searchService.findAndHighlight('');
                  context.read<EditorProvider>().exitSearch();
                },
              ),
            ),
          ],
        ),
        const SizedBox(width: 4),
        Expanded(
          child: StadiumButtonBar(
            buttons: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                    ),
                    hintText: 'Search...',
                    suffixText: _matchCount > 0 ? '${_currentIndex + 1}/$_matchCount' : null,
                    suffixStyle: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                  style: const TextStyle(fontSize: 14),
                  onChanged: _onSearch,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_upward, size: 20),
                onPressed: _matchCount > 0 ? () => _searchService.navigateToMatch(moveUp: true) : null,
              ),
              IconButton(
                icon: const Icon(Icons.arrow_downward, size: 20),
                onPressed: _matchCount > 0 ? () => _searchService.navigateToMatch() : null,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
      ],
    );
  }
}
