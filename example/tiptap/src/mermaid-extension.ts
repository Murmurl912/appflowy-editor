import { Node } from '@tiptap/core';

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
    }, `\`\`\`mermaid\n${HTMLAttributes.code}\n\`\`\``];
  },

  addCommands() {
    return {
      setMermaidBlock: (attrs) => ({ commands }) => {
        return commands.insertContent({
          type: this.name,
          attrs,
        });
      },
    };
  },

  addNodeView() {
    return ({ node, getPos, editor }) => {
      const dom = document.createElement('div');
      dom.classList.add('mermaid-block');
      dom.setAttribute('data-type', 'mermaid-block');
      dom.setAttribute('data-code', node.attrs.code);
      dom.contentEditable = 'false';

      const renderDiagram = (code: string) => {
        // Try to use mermaid.js if loaded
        try {
          const mermaid = (window as any).mermaid;
          if (mermaid) {
            const id = 'mermaid-' + Math.random().toString(36).substr(2, 9);
            mermaid.render(id, code).then((result: any) => {
              dom.innerHTML = result.svg;
            }).catch(() => {
              dom.innerHTML = `<pre class="mermaid-source">${code}</pre>`;
            });
          } else {
            dom.innerHTML = `<pre class="mermaid-source">${code}</pre>`;
          }
        } catch {
          dom.innerHTML = `<pre class="mermaid-source">${code}</pre>`;
        }
      };

      renderDiagram(node.attrs.code);

      // Click to edit
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
          dom.setAttribute('data-code', updatedNode.attrs.code);
          renderDiagram(updatedNode.attrs.code);
          return true;
        },
      };
    };
  },
});
