# karpensieve

A persistent, LLM-maintained wiki built from raw source documents. The LLM reads your sources, builds interlinked markdown pages, maintains cross-references, flags contradictions, and keeps everything current. You curate the sources and ask the questions. The LLM does the bookkeeping.

Inspired by Andrej Karpathy's [LLM Wiki](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f) idea: instead of RAG (re-derive knowledge on every query), the LLM compiles sources into a persistent, interlinked wiki that compounds over time.

Compatible with Obsidian. Works with Claude Code, Claude.ai, or any LLM agent that can read/write files.

---

## How it works

You have three layers:

**Raw sources** — articles, papers, notes, transcripts, images. You drop them into `raw/`. The LLM reads them but never modifies them.

**The wiki** — a flat directory of LLM-generated markdown pages in `wiki/`. Source summaries, entity pages, concept pages, analyses. Typed by YAML frontmatter, not folder structure. Interlinked with Obsidian's pipe-format wikilinks `[[file-slug|Display Text]]`. The LLM creates and maintains everything here.

**The schema** — `SCHEMA.md` in the wiki root. Tells the LLM how the wiki is structured, what conventions to follow, and what workflows to run. You and the LLM evolve it together over time.

Three operations:

- **Ingest** — process a new source into the wiki. Creates/updates multiple pages per source.
- **Query** — ask questions answered from wiki content. Substantive answers get filed back as new pages.
- **Lint** — health-check for orphans, dead links, contradictions, stale content, gaps.

---

## Quick start

### Step 1: Install the toolkit

Download or clone `karpensieve` to a permanent location:

```bash
git clone <repo-url> ~/tools/karpensieve
```

Optionally, alias the init script:

```bash
# Add to your .bashrc / .zshrc
alias init-wiki="bash ~/tools/karpensieve/scripts/init_wiki.sh"
```

### Step 2: Create a wiki

```bash
bash ~/tools/karpensieve/scripts/init_wiki.sh ~/my-wiki "My Research Wiki" "Tracking AI safety papers and key debates"
```

This creates a ready-to-use wiki with skills — focused workflow files that give Claude structured, repeatable behavior for ingest, query, and lint. To create a wiki without skills (schema-only mode), pass `--no-skills`.

```
my-wiki/
├── CLAUDE.md              <- Claude Code reads this on session start
├── SCHEMA.md              <- conventions, workflows, formatting rules
├── page-templates.md      <- page format reference
├── index.md               <- page catalog
├── log.md                 <- operation history
├── raw/                   <- drop source files here (flat, any format)
│   ├── .wikiignore        <- raw files excluded from re-ingest
│   └── assets/            <- images, PDFs, data files
├── wiki/                  <- LLM-generated pages (flat, typed by frontmatter)
│   └── meta/              <- overview, open questions, lint reports
├── .claude/
│   └── skills/            <- omitted with --no-skills
│       ├── wiki-ingest/   <- process source documents (/wiki-ingest)
│       ├── wiki-query/    <- search and synthesize answers (/wiki-query)
│       └── wiki-lint/     <- interactive health check (/wiki-lint)
└── .obsidian/             <- pre-configured Obsidian settings
```

### Step 3: Start Claude Code

```bash
cd ~/my-wiki
claude
```

Claude reads `CLAUDE.md` automatically, which tells it to read `SCHEMA.md`. If skills are installed, `CLAUDE.md` also points to them. No further setup.

### Step 4: Open in Obsidian

Open the wiki folder as a vault in Obsidian (File -> Open vault -> Open folder as vault). The `.obsidian/` config is pre-set:

- Wikilinks enabled (not markdown links)
- Attachments save to `raw/assets/`
- New notes default to `wiki/`
- Graph view with color groups for meta pages
- Core plugins enabled: backlinks, graph, search, tags, outline

Install the **Dataview** community plugin (Settings -> Community plugins -> Browse -> "Dataview") for queries over frontmatter.

### Step 5: Add sources and go

Drop files into `raw/`. Any format: markdown, HTML, PDF, DOCX, XLSX, CSV, EML, images. No naming conventions. Just dump. For web articles, [Obsidian Web Clipper](https://obsidian.md/clipper) converts pages to markdown and saves them directly.

Tell Claude to process them:
- "Ingest the new file in raw"
- "Process everything in raw I haven't ingested yet"
- "What do the sources say about compute governance?"
- "Run a health check"

### Optional: Install qmd for search

```bash
npm install -g @tobilu/qmd
```

The agent sets up the search collection automatically the first time it needs it. At small scale (<50 pages), the agent uses `index.md` for navigation and qmd isn't needed.

---

## Prerequisites

Most formats Claude Code handles natively. PDFs benefit from a few optional tools — without them, ingest falls back to text-only or fails outright for scanned/form PDFs:

- **poppler** — provides `pdftoppm`, used by Claude Code's built-in `Read` to render PDF pages. macOS: `brew install poppler`. Debian/Ubuntu: `apt-get install poppler-utils`.
- **pdfminer.six** — text extraction: `pip install pdfminer.six`
- **pymupdf** — rasterization, image extraction, form widgets (radios, checkboxes, fillable fields): `pip install pymupdf`
- **pdfplumber** (optional) — structured table extraction to CSV: `pip install pdfplumber`

None of these are required to create a wiki or ingest plain-text sources.

---

## Supported file types

| Type | How the LLM reads it |
|------|---------------------|
| Markdown (.md) | Directly. Web Clipper output is this. |
| HTML (.html) | BeautifulSoup extracts text + metadata from `<meta>` tags |
| CSV / TSV | CSV parser. Columns, row counts, patterns |
| XLSX (.xlsx) | openpyxl reads all sheets including notes/methodology |
| DOCX (.docx) | python-docx extracts paragraph text + headings (`doc.paragraphs`); `doc.tables` iterated separately for table cells (emitted as markdown tables, large tables saved to CSV in `raw/assets/`); `docx.oxml` walk captures form-control state (`w:checkBox`, `w:sdt`); `doc.part.related_parts` extracts embedded images. ActiveX radio groups fall back to libreoffice-to-PDF + rasterize |
| PDF (.pdf) | pdfminer for text; pymupdf for rasterization, embedded images, and form widgets (`page.widgets()` captures radio/checkbox state and filled fields); pdfplumber (optional) for structured table extraction -> CSV in `raw/assets/`. Scanned PDFs rasterized and read visually |
| Email (.eml) | stdlib `email.message_from_bytes()` parses MIME tree. Headers -> frontmatter (`From`, `Date`, `Subject`, `Message-ID` as duplicate-detection key); body prefers `text/plain`, falls back to stripped `text/html`; attachments extracted to `raw/assets/` (substantive ones like PDFs get their own linked source page); inline images saved as figures |
| Images (.png, .jpg) | Viewed directly. Stored in `raw/assets/`, linked via `assets` frontmatter |

**Re-clipping:** If you clip a web page you've already ingested and the content has changed, the agent detects the URL match and runs a re-ingest — diffs old vs new, updates the existing source summary, traces outward to update entity/concept pages that cited changed claims.

---

## Obsidian workflow

Use Claude Code for ingest, query, and lint. Use Obsidian to browse pages, follow wikilinks, explore the graph view, and read updates as they happen.

**Graph view** (Ctrl+G) is pre-configured with color groups for meta pages. Hub pages (many inbound links) are your most important pages. Orphans need attention.

**Dataview** lets you run queries over page frontmatter:

```dataview
TABLE type, updated, tags FROM "wiki" SORT updated DESC LIMIT 20
```

---

## Version control

The wiki is just markdown files. Git works naturally:

```bash
cd ~/my-wiki
git init
git add -A
git commit -m "initial wiki structure"
```

The `.gitignore` is pre-configured. Commit after each ingest session. The wiki folder is self-contained — collaborators clone the repo, run `claude`, and open the folder as an Obsidian vault. If qmd is installed, they set up their own search index with `qmd --index <name> collection add wiki/ --name <name>`.

---

## Schema-only mode

By default, the init script installs skills — structured workflow files for ingest, query, and lint. Skills give Claude specific, repeatable steps for each operation and enable the lint skill's interactive guided resolution.

If you prefer Claude to derive workflows from natural language and `SCHEMA.md` alone, create the wiki without skills:

```bash
bash ~/tools/karpensieve/scripts/init_wiki.sh --no-skills ~/my-wiki "My Wiki" "Description"
```

To remove skills from an existing wiki, delete `.claude/skills/` and remove the Skills section from `CLAUDE.md`. To add skills to a wiki that doesn't have them:

```bash
cp -r ~/tools/karpensieve/skills/* ~/my-wiki/.claude/skills/
```

Then tell Claude: "I added skills to `.claude/skills/`, update CLAUDE.md to reference them."

---

## Multiple wikis

Each wiki is a self-contained directory. Run `init_wiki.sh` once per topic:

```bash
bash ~/tools/karpensieve/scripts/init_wiki.sh ~/wikis/ai-safety "AI Safety Research" "Tracking AI safety papers and key debates"
bash ~/tools/karpensieve/scripts/init_wiki.sh ~/wikis/health "Health Wiki" "Personal health, nutrition, and exercise tracking"
```

Each wiki gets its own schema, skills, index, search collection, and Obsidian vault. Nothing is shared between wikis. `cd` into whichever wiki you want to work on and run `claude`.

---

## qmd search

[qmd](https://github.com/tobi/qmd) is a local search engine for markdown files by Tobi Lutke. Hybrid BM25 + vector search with LLM re-ranking, all on-device.

```bash
npm install -g @tobilu/qmd
```

The agent handles everything else: collection setup, context, embeddings. Three search tiers, used automatically during ingest, query, and lint:

```bash
qmd --index <name> search "keyword" -c <name> --json          # fast BM25 keyword search
qmd --index <name> vsearch "conceptual question" -c <name> --json   # semantic vector search
qmd --index <name> query "full question" -c <name> --json      # hybrid + LLM reranking (best quality)
```

The `<name>` is the wiki's directory name. The init script sets this up automatically and bakes the name into `SCHEMA.md` and the skill files.

---

## Other LLM agents

**Claude.ai:** Upload or paste `SCHEMA.md` as context at the start of a session. Upload source documents when you want to ingest them. Copy generated wiki pages into your Obsidian vault manually.

**Other agents (Codex, Cursor, etc.):** Run the init script to create the wiki. The agent reads `CLAUDE.md` (or rename to `AGENTS.md`, `.cursorrules`, etc.). Set up qmd CLI if the agent can shell out, or MCP if supported.

---

## File manifest

The `karpensieve` package:

```
karpensieve/
├── README.md                          <- you are here
├── SKILL.md                           <- Claude.ai skill trigger (not needed for Claude Code)
├── scripts/
│   └── init_wiki.sh                   <- creates wiki (run with or without --no-skills)
├── skills/                            <- Claude Code skills (installed by default)
│   ├── wiki-ingest/SKILL.md            <- process source documents (/wiki-ingest)
│   ├── wiki-query/SKILL.md             <- search and synthesize answers (/wiki-query)
│   └── wiki-lint/SKILL.md              <- interactive health check (/wiki-lint)
└── references/
    ├── schema-template.md             <- full SCHEMA.md template
    └── page-templates.md              <- page format templates
```

---

## See also

[How karpensieve compares](references/comparison.md) to NotebookLM, ChatGPT, and Claude Projects.
