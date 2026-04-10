import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:example/widgets/code_block_component.dart';
import 'package:example/widgets/math_equation_block_component.dart';
import 'package:example/widgets/mermaid_block_component.dart';
import 'package:markdown/markdown.dart' as md;

/// Encoder: mermaid node → ```mermaid ... ```
class MermaidNodeParser extends NodeParser {
  const MermaidNodeParser();

  @override
  String get id => MermaidBlockKeys.type;

  @override
  String transform(Node node, DocumentMarkdownEncoder? encoder) {
    final content = node.attributes[MermaidBlockKeys.content] as String? ?? '';
    final suffix = node.next == null ? '' : '\n';
    return '```mermaid\n$content\n```$suffix';
  }
}

/// Encoder: math_equation node → $$formula$$
class MathEquationNodeParser extends NodeParser {
  const MathEquationNodeParser();

  @override
  String get id => MathEquationBlockKeys.type;

  @override
  String transform(Node node, DocumentMarkdownEncoder? encoder) {
    final formula =
        node.attributes[MathEquationBlockKeys.formula] as String? ?? '';
    final suffix = node.next == null ? '' : '\n';
    return '\$\$\n$formula\n\$\$$suffix';
  }
}

/// Decoder: fenced code blocks in markdown → code block nodes
class MarkdownCodeBlockParser extends CustomMarkdownParser {
  const MarkdownCodeBlockParser();

  @override
  List<Node> transform(
    md.Node element,
    List<CustomMarkdownParser> parsers, {
    MarkdownListType listType = MarkdownListType.unknown,
    int? startNumber,
  }) {
    if (element is! md.Element || element.tag != 'pre') {
      return [];
    }

    final codeElement = element.children
        ?.whereType<md.Element>()
        .where((e) => e.tag == 'code')
        .firstOrNull;
    if (codeElement == null) return [];

    // Extract language from class="language-xxx"
    final className = codeElement.attributes['class'] ?? '';
    final language = className.startsWith('language-')
        ? className.substring('language-'.length)
        : '';

    final code = codeElement.textContent;

    // Mermaid code blocks → mermaid node (not code block)
    if (language == 'mermaid') {
      return [
        Node(
          type: 'mermaid',
          attributes: {'content': code},
        ),
      ];
    }

    return [
      codeBlockNode(language: language, delta: Delta()..insert(code)),
    ];
  }
}

/// Decoder: $$formula$$ in markdown → math_equation node
///
/// The markdown package parses `$$..$$` as a <p> element.
/// This parser intercepts paragraphs whose text matches $$...$$ and
/// converts them to math_equation nodes.
class MarkdownMathEquationParser extends CustomMarkdownParser {
  const MarkdownMathEquationParser();

  @override
  List<Node> transform(
    md.Node element,
    List<CustomMarkdownParser> parsers, {
    MarkdownListType listType = MarkdownListType.unknown,
    int? startNumber,
  }) {
    if (element is! md.Element || element.tag != 'p') {
      return [];
    }

    final text = element.textContent.trim();

    // Match block math: starts and ends with $$
    if (text.startsWith('\$\$') && text.endsWith('\$\$') && text.length > 4) {
      final formula = text.substring(2, text.length - 2).trim();
      return [mathEquationNode(formula: formula)];
    }

    return [];
  }
}
