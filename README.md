# 📝 Docsa / Persian Markdown Doc Builder

A blazing-fast, Dockerized documentation generator explicitly designed to handle **Bidirectional (BiDi) text and English/Persian (Farsi) mixed content flawlessly.**

If you are a software engineer who has tried using tools like MkDocs, Sphinx, or Docusaurus for Persian documentation, you know the pain: **mixed LTR/RTL lines break**, **parentheses face the wrong way**, and formatting becomes unreadable. 

This project solves all of those issues natively. By utilizing a highly-tuned **Pandoc** configuration alongside an **AWK preprocessor** and custom CSS, it produces perfectly readable, beautifully styled HTML documentation.

---

## ✨ Why this project? (Features)

*   🇮🇷 **Native Persian & BiDi Support**: Custom styling using the `Vazirmatn` font for Persian ranges, and `Times New Roman` for English. Parentheses, mixed code terms, and punctuations render exactly as you type them.
*   🔄 **Automatic Language Toggling**: Simply place `doc.md` and `doc_fa.md` side-by-side. The builder automatically links them and injects floating `فارسی` / `English` switch buttons on both pages!
*   🔢 **Persian Numeral List Support**: An embedded AWK script automatically parses Persian numerals (`۱.`, `۲.`, `۳.`) so the Markdown engine recognizes them as native numbered lists.
*   📊 **High-Res Mermaid Diagrams**: Native support for `mermaid` blocks, rendered at 3x resolution via headless Chromium/Puppeteer so they look crisp on modern displays.
*   ⚡ **Multi-Core Parallel Builds**: Generates HTML concurrently across all available CPU cores using `xargs -P`.
*   🐳 **Zero Host Dependencies**: Everything runs inside a lightweight, multi-stage Docker container. No need to install Pandoc, Node, or Chromium on your local machine.

---

## 📂 Project Structure & Naming Convention

Place your Markdown (`.md`), YAML (`.yml`), JSON (`.json`), or CSV (`.csv`) files in a `docs/` folder at the root of the project. 

To utilize the **Automatic Language Toggle**, follow this naming convention:

```text
├── docs/
│   ├── overview.md       # LTR (English) version
│   ├── overview_fa.md    # RTL (Persian) version (or overview-fa.md)
│   ├── api.md            # Will render as English only
│   └── setup_fa.md       # Will render as Persian only
├── doc-builder/
│   ├── build.sh
│   ├── Dockerfile
│   └── nginx.conf
└── compose.yml
```

The script will automatically generate an `index.html` landing page containing links to all your documents and their available translations.

---

## 🚀 Quick Start

Ensure you have **Docker** and **Docker Compose** installed.

1. **Clone the repository** and place your documentation in the `/docs` folder.
2. **Spin up the container**:
   ```bash
   docker compose up -d --build
   ```
3. **View your documentation**:
   Open your browser and navigate to:
   👉 **http://localhost:3001**

*Note: The container builds the static HTML during the startup process. If you have hundreds of files, it might take a few seconds before the site is live. If you update your markdown files, simply run `docker compose build docs && docker compose up -d` to regenerate the HTML.*

---

## 🛠️ Under the Hood

How does it manage to perfectly format BiDi text where other tools fail? 

1. **AWK Preprocessor**: Before Pandoc even touches the files, an AWK script parses the Markdown. It injects safe empty lines before tables and lists (preventing Markdown formatting breaks) and maps Persian list markers to Western Arabic numbers temporarily so the AST parser doesn't get confused.
2. **Pandoc Standalone HTML**: We use Pandoc with `markdown+hard_line_breaks` to respect how engineers actually write text, without forcing double-spaces at the ends of lines.
3. **Explicit Scope Styling**: English output is wrapped in a strict LTR stylesheet, and Persian output (`*_fa.md`) is wrapped in an RTL stylesheet. Inline code snippets (`<pre>` and `<code>`) are strictly forced to LTR, preventing English variable names from scattering across a Persian paragraph.
4. **Nginx Delivery**: The final output is served securely via an Alpine-based Nginx server with correct MIME-type bindings for static files.

---

## 🎨 Styling Details

*   **Persian Text**: Rendered right-to-left, justified, using `Vazirmatn-Regular`.
*   **English Text**: Rendered left-to-right, justified, using `Times New Roman`.
*   **Code Blocks**: Strict LTR, rendered in monospace. Housed in `#f6f8fa` blocks with rounded corners.
*   **Tables**: Auto-formatting collapse tables with alternating zebra-stripes (`#fbfbfb` and `#f6f8fa`) and light borders. 

---

## 🔒 Security

*   Puppeteer is safely configured to run in Docker using headless Chromium without `setuid` sandbox constraints, preventing build-time crashes.
