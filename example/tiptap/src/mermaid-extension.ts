import { Node } from '@tiptap/core';
import mermaid from 'mermaid';

let mermaidInitialized = false;

function ensureMermaidInit(isDark: boolean = false) {
  if (mermaidInitialized) return;
  mermaid.initialize({
    startOnLoad: false,
    theme: isDark ? 'dark' : 'default',
    securityLevel: 'loose',
  });
  mermaidInitialized = true;
}

async function renderMermaidSvg(code: string, container: HTMLElement) {
  const isDark = document.body.classList.contains('dark');
  ensureMermaidInit(isDark);
  try {
    const id = 'mermaid-' + Math.random().toString(36).substring(2, 11);
    const { svg } = await mermaid.render(id, code);
    container.innerHTML = svg;
  } catch {
    container.innerHTML = `<pre class="mermaid-source">${escapeHtml(code)}</pre>`;
  }
}

function escapeHtml(s: string) {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

declare module '@tiptap/core' {
  interface Commands<ReturnType> {
    mermaidBlock: {
      setMermaidBlock: (attrs: { code: string }) => ReturnType;
    };
  }
}

export const MermaidExtension = Node.create({
  name: 'mermaidBlock',
  group: 'block',
  atom: true,

  addAttributes() {
    return {
      code: { default: '' },
    };
  },

  parseHTML() {
    return [{ tag: 'div[data-type="mermaid-block"]' }];
  },

  renderHTML({ HTMLAttributes }) {
    return ['div', {
      'data-type': 'mermaid-block',
      class: 'mermaid-block',
      'data-code': HTMLAttributes.code || '',
      contenteditable: 'false',
    }, HTMLAttributes.code || ''];
  },

  addCommands() {
    return {
      setMermaidBlock: (attrs) => ({ commands }) => {
        return commands.insertContent({ type: this.name, attrs });
      },
    };
  },

  addNodeView() {
    return ({ node, getPos, editor }) => {
      const dom = document.createElement('div');
      dom.classList.add('mermaid-block');
      dom.setAttribute('data-type', 'mermaid-block');
      dom.contentEditable = 'false';

      const render = (code: string) => {
        dom.setAttribute('data-code', code);
        if (!code) {
          dom.innerHTML = '<span class="mermaid-source">Click to add diagram</span>';
          return;
        }
        renderMermaidSvg(code, dom);
      };

      render(node.attrs.code);

      dom.addEventListener('click', () => {
        if (!editor.isEditable) return;
        const newCode = prompt('Edit Mermaid diagram:', node.attrs.code);
        if (newCode !== null && typeof getPos === 'function') {
          editor.chain().focus().command(({ tr }) => {
            tr.setNodeMarkup(getPos(), undefined, { code: newCode });
            return true;
          }).run();
        }
      });

      return {
        dom,
        update(updatedNode) {
          if (updatedNode.type.name !== 'mermaidBlock') return false;
          render(updatedNode.attrs.code);
          return true;
        },
      };
    };
  },
});
