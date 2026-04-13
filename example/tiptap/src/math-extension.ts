import { Node } from '@tiptap/core';
import katex from 'katex';

declare module '@tiptap/core' {
  interface Commands<ReturnType> {
    mathBlock: {
      setMathBlock: (attrs: { formula: string }) => ReturnType;
    };
  }
}

function renderKatex(formula: string, container: HTMLElement) {
  try {
    katex.render(formula, container, {
      displayMode: true,
      throwOnError: false,
      output: 'html',
    });
  } catch {
    container.innerHTML = `<pre class="math-fallback">$$${formula}$$</pre>`;
  }
}

export const MathExtension = Node.create({
  name: 'mathBlock',
  group: 'block',
  atom: true,

  addAttributes() {
    return {
      formula: { default: '' },
    };
  },

  parseHTML() {
    return [{ tag: 'div[data-type="math-block"]' }];
  },

  renderHTML({ HTMLAttributes }) {
    return ['div', {
      'data-type': 'math-block',
      class: 'math-block',
      'data-formula': HTMLAttributes.formula || '',
      contenteditable: 'false',
    }, HTMLAttributes.formula || ''];
  },

  addCommands() {
    return {
      setMathBlock: (attrs) => ({ commands }) => {
        return commands.insertContent({ type: this.name, attrs });
      },
    };
  },

  addNodeView() {
    return ({ node, getPos, editor }) => {
      const dom = document.createElement('div');
      dom.classList.add('math-block');
      dom.setAttribute('data-type', 'math-block');
      dom.contentEditable = 'false';

      const render = (formula: string) => {
        dom.setAttribute('data-formula', formula);
        if (!formula) {
          dom.innerHTML = '<span class="math-fallback">Click to add formula</span>';
          return;
        }
        renderKatex(formula, dom);
      };

      render(node.attrs.formula);

      dom.addEventListener('click', () => {
        if (!editor.isEditable) return;
        const newFormula = prompt('Edit LaTeX formula:', node.attrs.formula);
        if (newFormula !== null && typeof getPos === 'function') {
          editor.chain().focus().command(({ tr }) => {
            tr.setNodeMarkup(getPos(), undefined, { formula: newFormula });
            return true;
          }).run();
        }
      });

      return {
        dom,
        update(updatedNode) {
          if (updatedNode.type.name !== 'mathBlock') return false;
          render(updatedNode.attrs.formula);
          return true;
        },
      };
    };
  },
});
