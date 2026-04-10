import 'package:markdown/markdown.dart' as md;

class HighlightInlineSyntax extends md.InlineSyntax {
  HighlightInlineSyntax() : super(r'==([\s\S]+?)==');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final text = match.group(1) ?? '';
    List<md.Node> nestedNodes = md.InlineParser(text, parser.document).parse();
    parser.addNode(md.Element('mark', nestedNodes));

    return true;
  }
}
