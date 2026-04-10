/**
 * VditorBridge - Flutter <-> Vditor communication layer.
 *
 * Exposed as `window.VditorBridge` after init.
 * Uses `window.flutter_inappwebview.callHandler()` to send events to Flutter.
 */
type FormatState = Record<string, boolean>;
declare function notifyFormatState(): void;
declare const bridge: {
    init(vditor: IVditor): void;
    getContent(): string;
    setContent(md: string): void;
    insertMarkdown(md: string): void;
    focus(): void;
    blur(): void;
    setReadOnly(readOnly: boolean): void;
    setTheme(isDark: boolean): void;
    setInsets(top: number, bottom: number, keyboardHeight: number): void;
    undo(): void;
    redo(): void;
    formatBold(): void;
    formatItalic(): void;
    formatStrikethrough(): void;
    formatInlineCode(): void;
    formatLink(): void;
    formatQuote(): void;
    formatCode(): void;
    formatList(): void;
    formatOrderedList(): void;
    formatCheck(): void;
    formatIndent(): void;
    formatOutdent(): void;
    formatTable(): void;
    formatLine(): void;
    formatHeadings(): void;
    insertHeading(level: number): void;
    insertMathBlock(): void;
    insertMermaid(): void;
    insertImage(url: string): void;
    getSelection(): string;
    getCursorPosition(): {
        left: number;
        top: number;
    };
    getFormatState(): FormatState;
    notifyFormatState: typeof notifyFormatState;
    searchFind(query: string): void;
    searchNext(): void;
    searchPrev(): void;
    searchClear(): void;
};
export declare function bridgeNotifyInput(markdown: string): void;
export declare function bridgeNotifyFocus(): void;
export declare function bridgeNotifyBlur(): void;
export declare function bridgeNotifySelect(text: string): void;
export declare function bridgeNotifyUnselect(): void;
export declare function bridgeNotifyKeydown(event: KeyboardEvent): void;
export default bridge;
