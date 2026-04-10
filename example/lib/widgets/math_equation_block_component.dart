import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:provider/provider.dart';

class MathEquationBlockKeys {
  const MathEquationBlockKeys._();

  static const String type = 'math_equation';
  static const String formula = 'formula';
}

Node mathEquationNode({String formula = ''}) {
  return Node(
    type: MathEquationBlockKeys.type,
    attributes: {MathEquationBlockKeys.formula: formula},
  );
}

class MathEquationBlockComponentBuilder extends BlockComponentBuilder {
  MathEquationBlockComponentBuilder({super.configuration});

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    return MathEquationBlockComponentWidget(
      key: blockComponentContext.node.key,
      node: blockComponentContext.node,
      configuration: configuration,
    );
  }

  @override
  BlockComponentValidate get validate => (node) =>
      node.children.isEmpty &&
      node.attributes[MathEquationBlockKeys.formula] is String;
}

class MathEquationBlockComponentWidget extends BlockComponentStatefulWidget {
  const MathEquationBlockComponentWidget({
    super.key,
    required super.node,
    required super.configuration,
  });

  @override
  State<MathEquationBlockComponentWidget> createState() =>
      _MathEquationBlockComponentState();
}

class _MathEquationBlockComponentState
    extends State<MathEquationBlockComponentWidget>
    with BlockComponentConfigurable {
  @override
  BlockComponentConfiguration get configuration => widget.configuration;

  @override
  Node get node => widget.node;

  String get formula =>
      node.attributes[MathEquationBlockKeys.formula] as String? ?? '';

  late final editorState = context.read<EditorState>();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Padding(
      padding: padding,
      child: GestureDetector(
        onTap: () => _showEditDialog(context),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[900] : Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
            ),
          ),
          child: formula.isEmpty
              ? Text(
                  'Tap to add formula',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                )
              : Center(
                  child: Math.tex(
                    formula,
                    textStyle: TextStyle(fontSize: 18, color: textColor),
                    onErrorFallback: (error) => Text(
                      'Invalid formula: $formula',
                      style: TextStyle(color: Colors.red[400], fontSize: 14),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    if (!editorState.editable) return;

    final controller = TextEditingController(text: formula);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Math Equation'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: null,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'E = mc^2',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _updateFormula(controller.text);
              Navigator.pop(ctx);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _updateFormula(String newFormula) {
    if (newFormula == formula) return;
    final transaction = editorState.transaction
      ..updateNode(node, {MathEquationBlockKeys.formula: newFormula});
    editorState.apply(transaction);
  }
}
