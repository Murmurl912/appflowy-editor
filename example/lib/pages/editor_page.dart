import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:example/providers/editor_provider.dart';
import 'package:example/widgets/editor_appbar.dart';
import 'package:example/widgets/editor_toolbar.dart';
import 'package:example/widgets/code_block_component.dart';
import 'package:example/widgets/custom_block_components.dart';
import 'package:example/widgets/math_equation_block_component.dart';
import 'package:example/widgets/mermaid_block_component.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class EditorPage extends StatelessWidget {
  const EditorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Stack(
        children: [
          Builder(
            builder: (context) {
              final provider = context.watch<EditorProvider>();
              final editorFocus = provider.editorFocus;
              final scrollController = provider.scrollController;
              return Positioned.fill(
                child: EditorToolbar(
                  child: AppFlowyEditor(
                    editorState: provider.editorState,
                    focusNode: editorFocus,
                    editorScrollController: scrollController,
                    editorStyle: _buildEditorStyle(context),
                    editable: provider.editing,
                    disableKeyboardService: !provider.editing,
                    blockComponentBuilders: {
                      ...standardBlockComponentBuilderMap,
                      CodeBlockKeys.type: CodeBlockComponentBuilder(),
                      MermaidBlockKeys.type: MermaidBlockComponentBuilder(),
                      MathEquationBlockKeys.type: MathEquationBlockComponentBuilder(),
                      CalloutBlockKeys.type: CalloutBlockComponentBuilder(),
                      ToggleListBlockKeys.type: ToggleListBlockComponentBuilder(),
                      VideoBlockKeys.type: VideoBlockComponentBuilder(),
                      PdfBlockKeys.type: PdfBlockComponentBuilder(),
                    },
                    characterShortcutEvents: standardCharacterShortcutEvents,
                    enableMarkdownPaste: true,
                    shrinkWrap: false,
                    autoFocus: false,
                    header: SizedBox(height: MediaQuery.paddingOf(context).top + 56),
                    footer: SizedBox(
                      height: 56 + MediaQuery.paddingOf(context).bottom  + 32,
                    ),
                  ),
                ),
              );
            },
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top,
            left: 0,
            right: 0,
            child: const EditorAppbar(),
          ),
        ],
      ),
    );
  }

  EditorStyle _buildEditorStyle(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return EditorStyle.mobile(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      cursorColor: theme.colorScheme.primary,
      selectionColor: theme.colorScheme.primary.withValues(alpha: 0.3),
      dragHandleColor: theme.colorScheme.primary,
      textStyleConfiguration: TextStyleConfiguration(
        text: TextStyle(fontSize: 16, color: textColor),
      ),
    );
  }
}
