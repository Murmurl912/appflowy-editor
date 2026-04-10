const kMarkdownSample1 = r"""# Markdown Complete Syntax Guide

This document is a **complete reference** for all Markdown syntax. Each section explains the syntax and provides examples you can edit directly.

---

## 1. Headings

Use `#` to create headings. More `#` means a smaller heading.

# Heading 1 -- used for document titles

## Heading 2 -- used for major sections

### Heading 3 -- used for sub-sections

---

## 2. Paragraphs and Line Breaks

Paragraphs are separated by a blank line. This is the first paragraph, and it can contain multiple sentences. Markdown will wrap text automatically based on the screen width.

This is the second paragraph. Simply leave a blank line between blocks of text to create separate paragraphs.

---

## 3. Text Formatting

### Bold

Use double asterisks for **bold text**. You can make a **single word** bold or **an entire phrase** bold.

### Italic

Use single asterisks for *italic text*. Works on *one word* or *multiple words together*.

### Bold and Italic

Combine three asterisks for ***bold and italic*** at the same time.

### Strikethrough

Use double tildes for ~~deleted text~~. For example: ~~old price $99~~ new price **$49**.

### Inline Code

Use backticks for `inline code`. For example: the `main()` function, the `String` type, or a shell command like `flutter run`.

---

## 4. Links

Create a link with `[display text](URL)`:

- [Flutter official site](https://flutter.dev)
- [Dart documentation](https://dart.dev)
- [GitHub](https://github.com)

---

## 5. Images

Images use the same syntax as links, with a `!` prefix:

![Flutter Logo](https://storage.googleapis.com/cms-storage-bucket/6e19fee6b47b36ca613f.png)

---

## 6. Blockquotes

### Simple Blockquote

> Simplicity is the ultimate sophistication. -- Leonardo da Vinci

### Multi-paragraph Blockquote

> The first paragraph of a blockquote. You can write as much as you want here and the quote style will continue.
>
> The second paragraph within the same blockquote. Use `>` followed by a blank `>` line to create paragraph breaks inside quotes.

### Nested Blockquotes

> This is the outer quote.
>
> > This is a nested quote inside the outer one.
> >
> > > And this is a third level of nesting.
>
> Back to the outer quote level.

### Blockquote with Formatted Content

> **Important:** You can use *any* Markdown formatting inside blockquotes:
>
> - Bulleted lists work
> - **Bold** and *italic* work
> - `inline code` works too
>
> Even numbered lists:
>
> 1. First point
> 2. Second point

---

## 7. Unordered Lists

### Simple List

- Apple
- Banana
- Cherry

### List with Formatted Items

- **Bold item** with extra description
- *Italic item* for emphasis
- Item with `inline code`
- Item with a [link](https://example.com)

### Nested Unordered List

- Fruits
  - Tropical
    - Mango
    - Pineapple
    - Papaya
  - Temperate
    - Apple
    - Pear
- Vegetables
  - Leafy Greens
    - Spinach
    - Kale
  - Root Vegetables
    - Carrot
    - Potato

### List Items with Body Text

- **First item**

  This is the body text of the first item. It provides additional details and explanation that goes beyond the brief title. You can write as many paragraphs as needed.

  You can even have a second paragraph under the same list item.

- **Second item**

  Body text for the second item. Each item can have its own detailed explanation.

- **Third item**

  And the third item also has body text with `code`, **bold**, and *italic* formatting.

---

## 8. Ordered Lists

### Simple Numbered List

1. First step
2. Second step
3. Third step

### Nested Ordered List

1. Chapter One: Getting Started
   1. Installing the tools
   2. Creating your first project
   3. Running the app
2. Chapter Two: Core Concepts
   1. Understanding widgets
   2. State management
   3. Navigation and routing
3. Chapter Three: Advanced Topics
   1. Custom painting
   2. Platform channels
   3. Performance optimization

### Ordered List with Body Text

1. **Clone the repository**

   Open your terminal and run the following command to clone the project:

   `git clone https://github.com/user/repo.git`

2. **Install dependencies**

   Navigate to the project directory and install all required packages:

   `flutter pub get`

3. **Run the application**

   Launch the app on your connected device or emulator:

   `flutter run`

### Mixed Nested Lists

1. Frontend Technologies
   - HTML and CSS
   - JavaScript
   - React or Vue
2. Backend Technologies
   - Node.js
   - Python with Django
   - Go
3. Mobile Development
   - **Flutter** (recommended)
     1. Learn Dart first
     2. Understand widget tree
     3. Build your first app
   - React Native
   - Native (Swift / Kotlin)

---

## 9. Task Lists

### Project Checklist

- [x] Set up the development environment
- [x] Create the project structure
- [x] Implement the data layer
- [ ] Build the UI components
- [ ] Write unit tests
- [ ] Deploy to production

### Nested Task List

- [x] Phase 1: Design
  - [x] Define requirements
  - [x] Create wireframes
  - [x] Design mockups
- [ ] Phase 2: Development
  - [x] Set up repository
  - [ ] Implement core features
  - [ ] Code review
- [ ] Phase 3: Launch
  - [ ] Beta testing
  - [ ] Fix bugs
  - [ ] Public release

---

## 10. Horizontal Rules

Use three dashes `---`, three asterisks `***`, or three underscores `___` to create a horizontal rule:

---

They are useful for visually separating sections of a document.

---

## 11. Code Blocks

### Dart

```dart
class MarkdownEditor extends StatefulWidget {
  const MarkdownEditor({super.key});

  @override
  State<MarkdownEditor> createState() => _MarkdownEditorState();
}

class _MarkdownEditorState extends State<MarkdownEditor> {
  late final EditorState _editorState;

  @override
  void initState() {
    super.initState();
    _editorState = EditorState.blank();
  }

  @override
  Widget build(BuildContext context) {
    return AppFlowyEditor(editorState: _editorState);
  }
}
```

### Python

```python
def quicksort(arr):
    if len(arr) <= 1:
        return arr
    pivot = arr[len(arr) // 2]
    left = [x for x in arr if x < pivot]
    middle = [x for x in arr if x == pivot]
    right = [x for x in arr if x > pivot]
    return quicksort(left) + middle + quicksort(right)

print(quicksort([3, 6, 8, 10, 1, 2, 1]))
```

### JSON

```json
{
  "editor": {
    "name": "Markdown Editor",
    "version": "1.0.0",
    "features": [
      "rich text editing",
      "markdown import/export",
      "math equations",
      "image support"
    ]
  }
}
```

### Shell

```bash
# Create a new Flutter project
flutter create my_app
cd my_app

# Run on a connected device
flutter run --release
```

---

## 12. Mermaid Diagrams

Mermaid lets you create diagrams using text-based syntax.

### Flowchart

```mermaid
flowchart LR
    A[Start] --> B{Decision}
    B -->|Yes| C[OK]
    B -->|No| D[Cancel]
    C --> E[End]
    D --> E
```

### Sequence Diagram

```mermaid
sequenceDiagram
    participant Client
    participant Server
    participant Database
    Client->>Server: HTTP Request
    Server->>Database: Query
    Database-->>Server: Result
    Server-->>Client: Response
```

### Class Diagram

```mermaid
classDiagram
    class Animal {
        +String name
        +int age
        +makeSound()
    }
    class Dog {
        +fetch()
    }
    class Cat {
        +purr()
    }
    Animal <|-- Dog
    Animal <|-- Cat
```

### Pie Chart

```mermaid
pie title Language Usage
    "Dart" : 40
    "Rust" : 25
    "TypeScript" : 20
    "Python" : 15
```

### State Diagram

```mermaid
stateDiagram-v2
    [*] --> Idle
    Idle --> Loading : fetch
    Loading --> Success : resolve
    Loading --> Error : reject
    Success --> Idle : reset
    Error --> Loading : retry
```

---

## 13. Tables

### Basic Table

| Name | Role | Language |
|---|---|---|
| Alice | Frontend | Dart |
| Bob | Backend | Python |
| Carol | DevOps | Go |

### Table with Formatted Content

| Feature | Syntax | Rendered |
|---|---|---|
| Bold | `**text**` | **text** |
| Italic | `*text*` | *text* |
| Strikethrough | `~~text~~` | ~~text~~ |
| Code | `` `code` `` | `code` |
| Link | `[title](url)` | [title](url) |

### Comparison Table

| Aspect | Markdown | Rich Text Editor |
|---|---|---|
| Learning curve | Low | Very Low |
| Portability | Excellent | Poor |
| Version control | Easy (plain text) | Difficult (binary) |
| Formatting power | Moderate | High |
| File size | Small | Large |

---

## 14. Math Equations

### Inline Math

The Pythagorean theorem states that $a^2 + b^2 = c^2$.

Einstein's famous equation: $E = mc^2$.

The quadratic formula is $x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}$.

### Block Math

The Gaussian integral:

$$\int_{-\infty}^{\infty} e^{-x^2}\, dx = \sqrt{\pi}$$

Euler's identity:

$$e^{i\pi} + 1 = 0$$

The binomial theorem:

$$\sum_{k=0}^{n} \binom{n}{k} x^k y^{n-k} = (x + y)^n$$

---

## 15. Combining Everything

Here's an example that combines multiple syntax elements together:

> ### Recipe: Chocolate Cake
>
> A **simple** and *delicious* chocolate cake recipe.
>
> **Ingredients:**
>
> - 2 cups flour
> - 1 cup sugar
> - 3/4 cup `cocoa powder`
> - 2 eggs
>
> **Steps:**
>
> 1. **Preheat** oven to 350F
> 2. Mix *dry* ingredients
> 3. Add **wet** ingredients
> 4. Bake for ~~40~~ 35 minutes
>
> For the full recipe, see [Chocolate Cake Guide](https://example.com).

---

## 16. Extended Block Types

Beyond standard Markdown, this editor supports rich block types that can be inserted from the toolbar:

### Callout

A highlighted information box with an icon. Use it for tips, warnings, or important notes. Tap the icon to cycle through styles (bulb, warning, info, star, check).

### Toggle List

A collapsible section that can contain child content. Tap the arrow to expand or collapse. Great for FAQs, detailed explanations, or optional content.

### Video Embed

Embed a video by providing a URL to an MP4 file. The video player supports play/pause controls directly in the editor.

### PDF Embed

Attach a PDF document by providing a URL and optional name. Displays as a card with the PDF icon and file name.

### Math Equation

Write LaTeX formulas. Inline: $E = mc^2$. Or as a block:

$$\nabla \times \mathbf{E} = -\frac{\partial \mathbf{B}}{\partial t}$$

**Try it:** Use the toolbar buttons to insert these blocks into your document!

---

## Summary

| Category | Elements |
|---|---|
| Headings | `#` H1, `##` H2, `###` H3 |
| Inline | **Bold**, *Italic*, ~~Strikethrough~~, `Code` |
| Links | `[text](url)` and `![alt](image-url)` |
| Lists | Unordered `-`, Ordered `1.`, Tasks `- [x]` |
| Blocks | Blockquotes `>`, Code Fences, Tables |
| Extended | Math `$...$`, Dividers `---` |

**That's it!** You now have a complete reference for Markdown syntax. Happy writing!
""";
