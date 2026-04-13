import { Editor } from '@tiptap/core';
import { DOMSerializer } from '@tiptap/pm/model';
import StarterKit from '@tiptap/starter-kit';
import Underline from '@tiptap/extension-underline';
import Highlight from '@tiptap/extension-highlight';
import TaskList from '@tiptap/extension-task-list';
import TaskItem from '@tiptap/extension-task-item';
import Table from '@tiptap/extension-table';
import TableRow from '@tiptap/extension-table-row';
import TableCell from '@tiptap/extension-table-cell';
import TableHeader from '@tiptap/extension-table-header';
import Image from '@tiptap/extension-image';
import Placeholder from '@tiptap/extension-placeholder';
import TextAlign from '@tiptap/extension-text-align';
import Link from '@tiptap/extension-link';
import Subscript from '@tiptap/extension-subscript';
import Superscript from '@tiptap/extension-superscript';
import CodeBlockLowlight from '@tiptap/extension-code-block-lowlight';
import { common, createLowlight } from 'lowlight';
import TurndownService from 'turndown';
import { marked } from 'marked';
import { MathExtension } from './math-extension';
import { MermaidExtension } from './mermaid-extension';
import { ClipboardExtension } from './clipboard-extension';

// ============================================================
// Markdown conversion
// ============================================================

const turndown = new TurndownService({
  headingStyle: 'atx',
  codeBlockStyle: 'fenced',
  bulletListMarker: '-',
  hr: '---',
});

// Task list turndown rules
turndown.addRule('taskListItem', {
  filter: (node) => {
    return node.nodeName === 'LI' && node.querySelector('input[type="checkbox"]') !== null;
  },
  replacement: (content, node) => {
    const checkbox = (node as HTMLElement).querySelector('input[type="checkbox"]');
    const checked = checkbox?.hasAttribute('checked') ?? false;
    const text = content.replace(/^\s*\[[ x]\]\s*/, '').trim();
    return `${checked ? '- [x]' : '- [ ]'} ${text}\n`;
  },
});

// Table turndown rules
turndown.addRule('table', {
  filter: 'table',
  replacement: (_content, node) => {
    const table = node as HTMLTableElement;
    const rows = Array.from(table.rows);
    if (rows.length === 0) return '';

    const toMarkdownRow = (cells: HTMLCollectionOf<HTMLTableCellElement>) => {
      return '| ' + Array.from(cells).map(c => c.textContent?.trim() ?? '').join(' | ') + ' |';
    };

    const headerRow = toMarkdownRow(rows[0].cells);
    const separator = '| ' + Array.from(rows[0].cells).map(() => '---').join(' | ') + ' |';
    const bodyRows = rows.slice(1).map(r => toMarkdownRow(r.cells));

    return '\n' + [headerRow, separator, ...bodyRows].join('\n') + '\n\n';
  },
});

// Code block with language
turndown.addRule('codeBlock', {
  filter: (node) => {
    return node.nodeName === 'PRE' && node.querySelector('code') !== null;
  },
  replacement: (_content, node) => {
    const code = (node as HTMLElement).querySelector('code');
    const lang = code?.className?.replace('language-', '') ?? '';
    const text = code?.textContent ?? '';
    return `\n\`\`\`${lang}\n${text}\n\`\`\`\n\n`;
  },
});

// Math block
turndown.addRule('mathBlock', {
  filter: (node) => {
    return (node as HTMLElement).classList?.contains('math-block') ?? false;
  },
  replacement: (_content, node) => {
    const formula = (node as HTMLElement).getAttribute('data-formula') ?? '';
    return `\n$$\n${formula}\n$$\n\n`;
  },
});

// Mermaid block
turndown.addRule('mermaidBlock', {
  filter: (node) => {
    return (node as HTMLElement).classList?.contains('mermaid-block') ?? false;
  },
  replacement: (_content, node) => {
    const code = (node as HTMLElement).getAttribute('data-code') ?? '';
    return `\n\`\`\`mermaid\n${code}\n\`\`\`\n\n`;
  },
});

function htmlToMarkdown(html: string): string {
  return turndown.turndown(html);
}

// Custom marked extensions: $$math$$ blocks and ```mermaid code fences
const mathBlockExtension: marked.TokenizerAndRendererExtensions = {
  extensions: [{
    name: 'mathBlock',
    level: 'block',
    start(src: string) { return src.indexOf('$$'); },
    tokenizer(src: string) {
      const match = src.match(/^\$\$\s*\n([\s\S]*?)\n\$\$\s*(?:\n|$)/);
      if (match) {
        return { type: 'mathBlock', raw: match[0], formula: match[1].trim() };
      }
      // Inline $$...$$ on a single line
      const inlineMatch = src.match(/^\$\$([^\n]+?)\$\$\s*(?:\n|$)/);
      if (inlineMatch) {
        return { type: 'mathBlock', raw: inlineMatch[0], formula: inlineMatch[1].trim() };
      }
      return undefined;
    },
    renderer(token: any) {
      return `<div data-type="math-block" class="math-block" data-formula="${escapeAttr(token.formula)}">${escapeHtml(token.formula)}</div>\n`;
    },
  }],
};

function escapeAttr(s: string): string {
  return s.replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

function escapeHtml(s: string): string {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

marked.use(mathBlockExtension);

// Override code fence renderer to detect mermaid
const defaultRenderer = new marked.Renderer();
const origCode = defaultRenderer.code;
marked.use({
  renderer: {
    code(this: any, token: { text: string; lang?: string }) {
      if (token.lang === 'mermaid') {
        return `<div data-type="mermaid-block" class="mermaid-block" data-code="${escapeAttr(token.text)}">${escapeHtml(token.text)}</div>\n`;
      }
      return origCode.call(this, token);
    },
  },
});

async function markdownToHtml(md: string): Promise<string> {
  return await marked.parse(md);
}

// ============================================================
// Flutter Bridge
// ============================================================

function send(event: string, data?: any) {
  try {
    (window as any).flutter_inappwebview?.callHandler(event, data);
  } catch (e) {
    console.warn('[TiptapBridge] send failed:', event, e);
  }
}

// ============================================================
// Editor setup
// ============================================================

let editor: Editor | null = null;

function getFormatState(): Record<string, any> {
  if (!editor) return {};

  const { from, to, empty } = editor.state.selection;
  const hasSelection = !empty;

  // Determine the active block node type
  const resolvedPos = editor.state.doc.resolve(from);
  let nodeType = 'paragraph';
  for (let d = resolvedPos.depth; d >= 0; d--) {
    const n = resolvedPos.node(d);
    if (['heading', 'codeBlock', 'blockquote', 'bulletList', 'orderedList',
         'taskList', 'table', 'mathBlock', 'mermaidBlock', 'image',
         'horizontalRule'].includes(n.type.name)) {
      nodeType = n.type.name;
      break;
    }
    if (n.type.name === 'listItem' || n.type.name === 'taskItem') {
      nodeType = n.type.name;
      break;
    }
  }

  // Text alignment
  let textAlign = 'left';
  try {
    const node = editor.state.doc.resolve(from).parent;
    textAlign = node.attrs.textAlign || 'left';
  } catch {}

  return {
    // Selection context
    hasSelection,
    nodeType,
    textAlign,

    // Inline marks
    bold: editor.isActive('bold'),
    italic: editor.isActive('italic'),
    underline: editor.isActive('underline'),
    strike: editor.isActive('strike'),
    'inline-code': editor.isActive('code'),
    link: editor.isActive('link'),
    highlight: editor.isActive('highlight'),
    subscript: editor.isActive('subscript'),
    superscript: editor.isActive('superscript'),

    // Block types
    list: editor.isActive('bulletList'),
    'ordered-list': editor.isActive('orderedList'),
    check: editor.isActive('taskList'),
    quote: editor.isActive('blockquote'),
    code: editor.isActive('codeBlock'),
    headings: editor.isActive('heading'),
    headingLevel: (() => {
      for (let i = 1; i <= 6; i++) {
        if (editor!.isActive('heading', { level: i })) return i;
      }
      return 0;
    })(),
    table: editor.isActive('table'),
    image: editor.isActive('image'),

    // History
    canUndo: editor.can().undo(),
    canRedo: editor.can().redo(),
  };
}

function notifyFormatState() {
  send('onFormatStateChanged', JSON.stringify(getFormatState()));
}

// ============================================================
// TiptapBridge (exposed to Flutter via window.VditorBridge for compatibility)
// ============================================================

const bridge = {
  focus() { editor?.commands.focus(); },
  blur() { editor?.commands.blur(); },

  setReadOnly(v: boolean) {
    editor?.setEditable(!v);
  },

  setTheme(isDark: boolean) {
    if (isDark) {
      document.body.classList.add('dark');
    } else {
      document.body.classList.remove('dark');
    }
  },

  undo() { editor?.commands.undo(); notifyFormatState(); },
  redo() { editor?.commands.redo(); notifyFormatState(); },

  getContent(): string {
    if (!editor) return '';
    return htmlToMarkdown(editor.getHTML());
  },

  setContent(md: string) {
    if (!editor) return;
    markdownToHtml(md).then(html => {
      editor!.commands.setContent(html);
    });
  },

  // Format commands (matching Vditor bridge interface)
  formatBold() { editor?.chain().focus().toggleBold().run(); },
  formatItalic() { editor?.chain().focus().toggleItalic().run(); },
  formatStrikethrough() { editor?.chain().focus().toggleStrike().run(); },
  formatInlineCode() { editor?.chain().focus().toggleCode().run(); },
  formatUnderline() { editor?.chain().focus().toggleUnderline().run(); },
  formatHighlight() { editor?.chain().focus().toggleHighlight().run(); },
  formatSubscript() { editor?.chain().focus().toggleSubscript().run(); },
  formatSuperscript() { editor?.chain().focus().toggleSuperscript().run(); },

  formatLink() {
    if (editor?.isActive('link')) {
      editor.chain().focus().unsetLink().run();
    } else {
      const url = prompt('Enter URL:');
      if (url) {
        editor?.chain().focus().setLink({ href: url }).run();
      }
    }
  },

  formatQuote() { editor?.chain().focus().toggleBlockquote().run(); },
  formatCode() { editor?.chain().focus().toggleCodeBlock().run(); },
  formatList() { editor?.chain().focus().toggleBulletList().run(); },
  formatOrderedList() { editor?.chain().focus().toggleOrderedList().run(); },
  formatCheck() { editor?.chain().focus().toggleTaskList().run(); },
  formatHeadings() { editor?.chain().focus().toggleHeading({ level: 2 }).run(); },

  insertHeading(level: number) {
    editor?.chain().focus().toggleHeading({ level: level as 1|2|3|4|5|6 }).run();
  },

  formatIndent() {
    editor?.chain().focus().sinkListItem('listItem').run() ||
    editor?.chain().focus().sinkListItem('taskItem').run();
  },
  formatOutdent() {
    editor?.chain().focus().liftListItem('listItem').run() ||
    editor?.chain().focus().liftListItem('taskItem').run();
  },

  formatTable() {
    editor?.chain().focus().insertTable({ rows: 3, cols: 3, withHeaderRow: true }).run();
  },
  formatLine() {
    editor?.chain().focus().setHorizontalRule().run();
  },

  // Table operations
  tableAddRowBefore() { editor?.chain().focus().addRowBefore().run(); },
  tableAddRowAfter() { editor?.chain().focus().addRowAfter().run(); },
  tableAddColBefore() { editor?.chain().focus().addColumnBefore().run(); },
  tableAddColAfter() { editor?.chain().focus().addColumnAfter().run(); },
  tableDeleteRow() { editor?.chain().focus().deleteRow().run(); },
  tableDeleteCol() { editor?.chain().focus().deleteColumn().run(); },
  tableDeleteTable() { editor?.chain().focus().deleteTable().run(); },
  tableToggleHeader() { editor?.chain().focus().toggleHeaderRow().run(); },

  // Alignment
  alignLeft() { editor?.chain().focus().setTextAlign('left').run(); },
  alignCenter() { editor?.chain().focus().setTextAlign('center').run(); },
  alignRight() { editor?.chain().focus().setTextAlign('right').run(); },

  insertImage(url: string) {
    editor?.chain().focus().setImage({ src: url }).run();
  },

  insertMathBlock() {
    editor?.chain().focus().insertContent({
      type: 'mathBlock',
      attrs: { formula: 'E = mc^2' },
    }).run();
  },

  insertMermaid() {
    editor?.chain().focus().insertContent({
      type: 'mermaidBlock',
      attrs: { code: 'graph TD\n  A-->B' },
    }).run();
  },

  // Insets
  setInsets(top: number, bottom: number, _keyboardHeight: number) {
    const el = document.querySelector('.ProseMirror') as HTMLElement;
    if (el) {
      el.style.paddingTop = `${top}px`;
      el.style.paddingBottom = `${bottom}px`;
    }
  },

  // Search
  searchFind(query: string) {
    if (!query) { bridge.searchClear(); return; }
    // Use window.find for basic search
    const found = (window as any).find(query, false, false, true);
    send('onSearchResult', JSON.stringify({
      total: found ? 1 : 0,
      current: found ? 1 : 0,
    }));
  },
  searchNext() {
    (window as any).find(undefined, false, false, true);
  },
  searchPrev() {
    (window as any).find(undefined, false, true, true);
  },
  searchClear() {
    (window as any).getSelection()?.removeAllRanges();
    send('onSearchResult', JSON.stringify({ total: 0, current: 0 }));
  },
};

// Expose as VditorBridge for compatibility with existing WebEditorProvider
(window as any).VditorBridge = bridge;

// ============================================================
// Init
// ============================================================

const lowlight = createLowlight(common);

(window as any).initEditor = async function(configStr: string) {
  const config = JSON.parse(configStr);
  const isDark = config.dark ?? false;
  const content = config.content ?? '';
  const topInset = config.topInset ?? 0;
  const bottomInset = config.bottomInset ?? 0;

  if (isDark) document.body.classList.add('dark');

  // Convert markdown to HTML
  const html = await markdownToHtml(content);

  editor = new Editor({
    element: document.getElementById('editor')!,
    extensions: [
      StarterKit.configure({
        codeBlock: false, // use lowlight version
        heading: { levels: [1, 2, 3, 4, 5, 6] },
      }),
      Underline,
      Highlight.configure({ multicolor: true }),
      TaskList,
      TaskItem.configure({ nested: true }),
      Table.configure({ resizable: true }),
      TableRow,
      TableCell,
      TableHeader,
      Image.configure({ inline: false, allowBase64: true }),
      Placeholder.configure({ placeholder: 'Start writing...' }),
      TextAlign.configure({ types: ['heading', 'paragraph'] }),
      Link.configure({ openOnClick: false }),
      Subscript,
      Superscript,
      CodeBlockLowlight.configure({ lowlight }),
      MathExtension,
      MermaidExtension,
      ClipboardExtension,
    ],
    content: html,
    autofocus: false,
    editable: true,

    onUpdate: ({ editor }) => {
      const md = htmlToMarkdown(editor.getHTML());
      send('onContentChanged', md);
      notifyFormatState();
    },

    onSelectionUpdate: () => {
      notifyFormatState();
      const sel = window.getSelection();
      send('onSelectionChanged', sel?.toString() ?? '');
    },

    onFocus: () => {
      send('onFocus');
    },

    onBlur: () => {
      send('onBlur');
    },
  });

  // Expose serializer and turndown for clipboard extension
  (window as any).__tiptapDOMSerializer = DOMSerializer.fromSchema(editor.schema);
  (window as any).__tiptapTurndown = turndown;

  // Apply initial insets
  setTimeout(() => {
    bridge.setInsets(topInset, bottomInset, 0);
    send('onReady');
  }, 100);
};
