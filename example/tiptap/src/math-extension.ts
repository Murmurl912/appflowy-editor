import { Node, mergeAttributes } from '@tiptap/core';

declare module '@tiptap/core' {
  interface Commands<ReturnType> {
    mathBlock: {
      setMathBlock: (attrs: { formula: string }) => ReturnType;
    };
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
    const formula = HTMLAttributes.formula || '';
    const wrapper = document.createElement('div');
    wrapper.setAttribute('data-type', 'math-block');
    wrapper.classList.add('math-block');
    wrapper.setAttribute('data-formula', formula);
    wrapper.contentEditable = 'false';

    // Try to render with KaTeX if available
    try {
      const katex = (window as any).katex;
      if (katex) {
        katex.render(formula, wrapper, {
          displayMode: true,
          throwOnError: false,
        });
      } else {
        wrapper.innerHTML = `<pre class="math-fallback">$$${formula}$$</pre>`;
      }
    } catch {
      wrapper.innerHTML = `<pre class="math-fallback">$$${formula}$$</pre>`;
    }

    return wrapper;
  },

  addCommands() {
    return {
      setMathBlock: (attrs) => ({ commands }) => {
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
      dom.classList.add('math-block');
      dom.setAttribute('data-type', 'math-block');
      dom.setAttribute('data-formula', node.attrs.formula);
      dom.contentEditable = 'false';

      const renderMath = (formula: string) => {
        try {
          const katex = (window as any).katex;
          if (katex) {
            katex.render(formula, dom, {
              displayMode: true,
              throwOnError: false,
            });
          } else {
            dom.innerHTML = `<pre class="math-fallback">$$${formula}$$</pre>`;
          }
        } catch {
          dom.innerHTML = `<pre class="math-fallback">$$${formula}$$</pre>`;
        }
      };

      renderMath(node.attrs.formula);

      // Click to edit
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
          dom.setAttribute('data-formula', updatedNode.attrs.formula);
          renderMath(updatedNode.attrs.formula);
          return true;
        },
      };
    };
  },
});
