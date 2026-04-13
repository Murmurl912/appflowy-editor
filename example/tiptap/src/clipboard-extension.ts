import { Extension } from '@tiptap/core';
import { Plugin, PluginKey } from '@tiptap/pm/state';
import { Slice, Fragment, Node as PmNode } from '@tiptap/pm/model';
import { marked } from 'marked';

/**
 * Detect if text looks like markdown (has markdown-specific syntax).
 */
function looksLikeMarkdown(text: string): boolean {
  const lines = text.split('\n');
  let mdSignals = 0;

  for (const line of lines) {
    const trimmed = line.trim();
    // Headings
    if (/^#{1,6}\s/.test(trimmed)) { mdSignals += 2; continue; }
    // Lists
    if (/^[-*+]\s/.test(trimmed)) { mdSignals++; continue; }
    if (/^\d+\.\s/.test(trimmed)) { mdSignals++; continue; }
    // Task lists
    if (/^[-*]\s\[[ x]\]/.test(trimmed)) { mdSignals += 2; continue; }
    // Code fences
    if (/^```/.test(trimmed)) { mdSignals += 2; continue; }
    // Blockquotes
    if (/^>/.test(trimmed)) { mdSignals++; continue; }
    // Tables
    if (/^\|.*\|/.test(trimmed)) { mdSignals++; continue; }
    // Horizontal rules
    if (/^(---|\*\*\*|___)$/.test(trimmed)) { mdSignals++; continue; }
    // Bold/italic
    if (/\*\*.+\*\*/.test(trimmed) || /__.+__/.test(trimmed)) { mdSignals++; continue; }
    // Links
    if (/\[.+\]\(.+\)/.test(trimmed)) { mdSignals++; continue; }
    // Images
    if (/!\[.*\]\(.+\)/.test(trimmed)) { mdSignals++; continue; }
    // Math blocks
    if (/^\$\$/.test(trimmed)) { mdSignals += 2; continue; }
  }

  // If at least ~20% of lines have markdown syntax, treat as markdown
  return lines.length > 0 && mdSignals >= Math.max(1, lines.length * 0.15);
}

/**
 * Smart clipboard extension for TipTap:
 * - On paste: if no HTML but text looks like markdown, convert markdown → HTML → ProseMirror
 * - On copy: write both HTML and markdown text to clipboard
 */
export const ClipboardExtension = Extension.create({
  name: 'smartClipboard',

  addProseMirrorPlugins() {
    const editor = this.editor;

    return [
      new Plugin({
        key: new PluginKey('smartClipboard'),
        props: {
          // Handle paste
          handlePaste(view, event, slice) {
            const clipboardData = event.clipboardData;
            if (!clipboardData) return false;

            const html = clipboardData.getData('text/html');
            const text = clipboardData.getData('text/plain');

            // If there's HTML, let ProseMirror handle it natively (rich paste)
            if (html && html.trim().length > 0) {
              return false; // default ProseMirror HTML paste
            }

            // If plain text looks like markdown, convert and insert
            if (text && looksLikeMarkdown(text)) {
              event.preventDefault();

              // Use marked to convert markdown → HTML, then insert via editor
              (async () => {
                try {
                  const convertedHtml = await marked.parse(text);
                  editor.commands.insertContent(convertedHtml, {
                    parseOptions: { preserveWhitespace: false },
                  });
                } catch {
                  // Fallback: insert as plain text
                  editor.commands.insertContent(text);
                }
              })();

              return true;
            }

            // Plain text without markdown: let ProseMirror handle normally
            return false;
          },

          // Handle copy — add markdown to clipboard alongside HTML
          clipboardTextSerializer(slice) {
            // Serialize the slice to HTML first, then convert to markdown
            const div = document.createElement('div');
            const fragment = slice.content;

            // Build HTML from ProseMirror fragment
            const serializer = (window as any).__tiptapDOMSerializer;
            if (serializer) {
              const dom = serializer.serializeFragment(fragment);
              div.appendChild(dom);
            } else {
              // Fallback: get text content
              let text = '';
              fragment.forEach((node: PmNode) => {
                text += node.textContent + '\n';
              });
              return text;
            }

            // Convert HTML to markdown using turndown
            const turndownService = (window as any).__tiptapTurndown;
            if (turndownService) {
              try {
                return turndownService.turndown(div.innerHTML);
              } catch {
                return div.textContent || '';
              }
            }

            return div.textContent || '';
          },
        },
      }),
    ];
  },
});
