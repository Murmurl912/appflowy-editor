# Vditor Flutter Bridge Design

## Architecture

```
┌─────────────────────────────────────────────┐
│  Flutter UI Layer                            │
│  ┌─────────┐ ┌──────────┐ ┌──────────────┐  │
│  │ AppBar  │ │ Toolbar  │ │ Search Bar   │  │
│  └────┬────┘ └────┬─────┘ └──────┬───────┘  │
│       │           │              │           │
│  ┌────▼───────────▼──────────────▼────────┐  │
│  │       WebEditorProvider                │  │
│  │  (state, commands, callbacks)          │  │
│  └────────────────┬───────────────────────┘  │
│                   │                          │
├───────────────────┼──────────────────────────┤
│  JS Bridge Layer  │                          │
│  ┌────────────────▼───────────────────────┐  │
│  │  VditorBridge (src/ts/bridge.ts)       │  │
│  │  - Exposes clean API methods           │  │
│  │  - Fires events to Flutter             │  │
│  │  - Manages format state observer       │  │
│  └────────────────┬───────────────────────┘  │
│                   │                          │
│  ┌────────────────▼───────────────────────┐  │
│  │  Vditor Core (IR Mode)                 │  │
│  │  - contenteditable <pre>               │  │
│  │  - Lute markdown parser                │  │
│  │  - Undo/Redo with diff-match-patch     │  │
│  └────────────────────────────────────────┘  │
│                                              │
│  InAppWebView (Hybrid Composition)           │
└─────────────────────────────────────────────┘
```

## JS Bridge Module: `src/ts/bridge.ts`

New file to add to Vditor source, compiled with the bundle.

### Flutter → JS (Commands)

| Method | Params | Description |
|--------|--------|-------------|
| `init(config)` | `{content, dark, lang, topInset, bottomInset}` | Initialize editor |
| `setContent(md)` | markdown string | Replace all content |
| `getContent()` | - | Returns markdown |
| `insertMarkdown(md)` | markdown string | Insert at cursor |
| `focus()` / `blur()` | - | Focus control |
| `setReadOnly(bool)` | boolean | Toggle editable |
| `setTheme(dark)` | boolean | Toggle theme |
| `setInsets(top, bottom, keyboard)` | numbers | Update safe area |
| `undo()` / `redo()` | - | History navigation |
| `formatBold()` | - | Toggle bold |
| `formatItalic()` | - | Toggle italic |
| `formatStrikethrough()` | - | Toggle strikethrough |
| `formatInlineCode()` | - | Toggle inline code |
| `formatLink()` | - | Insert/toggle link |
| `formatQuote()` | - | Toggle blockquote |
| `formatCodeBlock()` | - | Insert code block |
| `formatList()` | - | Toggle bullet list |
| `formatOrderedList()` | - | Toggle numbered list |
| `formatCheckList()` | - | Toggle task list |
| `formatIndent()` | - | Increase indent |
| `formatOutdent()` | - | Decrease indent |
| `formatTable()` | - | Insert table |
| `formatDivider()` | - | Insert horizontal rule |
| `formatHeading(level)` | 1-6 | Set heading level |
| `insertMathBlock()` | - | Insert $$ block |
| `insertMermaid()` | - | Insert mermaid block |
| `insertImage(url)` | url string | Insert image |
| `showSearch()` / `hideSearch()` | - | Toggle search UI |
| `searchFind(query)` | string | Find text |
| `searchNext()` / `searchPrev()` | - | Navigate matches |

### JS → Flutter (Events)

| Event | Data | Description |
|-------|------|-------------|
| `onReady` | - | Editor initialized, Lute loaded |
| `onContentChanged` | `{markdown}` | Content changed (debounced) |
| `onSelectionChanged` | `{text, hasSelection}` | Selection changed |
| `onFormatStateChanged` | `{bold, italic, strike, code, link, quote, list, orderedList, check, heading, headingLevel}` | Active format state |
| `onFocus` | - | Editor focused |
| `onBlur` | - | Editor blurred |
| `onKeydown` | `{key, ctrl, shift, alt, meta}` | Key pressed |
| `onScroll` | `{scrollTop}` | Content scrolled |
| `onSearchResult` | `{total, current}` | Search match count |

## Implementation Plan

### Phase 1: Bridge Module
1. Create `src/ts/bridge.ts` in Vditor source
2. Import and wire to Vditor internals
3. Use MutationObserver for format state
4. Use `window.flutter_inappwebview.callHandler()` for events
5. Expose `window.VditorBridge` for commands

### Phase 2: Build Pipeline
1. Add bridge to webpack entry
2. Build custom Vditor bundle with bridge
3. Output to `assets/web/dist/`

### Phase 3: Flutter Integration
1. WebEditorProvider reads events, exposes state
2. Custom scheme handler serves assets
3. Flutter toolbar reads `formatState` from provider
4. Flutter toolbar calls `provider.formatXxx()` which calls JS

### Phase 4: UI Polish
1. Search bar (Web-rendered, same style)
2. Toolbar animations and state transitions
3. Keyboard inset handling
4. Dark/light theme sync
