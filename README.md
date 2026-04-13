# LLM Wiki

A persistent, LLM-maintained wiki built from raw source documents. The LLM reads your sources, builds interlinked markdown pages, maintains cross-references, flags contradictions, and keeps everything current. You curate the sources and ask the questions. The LLM does the bookkeeping.

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

**How does this compare to NotebookLM, ChatGPT, or Claude Projects?** See [references/comparison.md](references/comparison.md) for a detailed breakdown.

---

## Prerequisites

Most formats Claude Code handles natively. PDFs benefit from a few optional tools — without them, ingest falls back to text-only or fails outright for scanned/form PDFs:

- **poppler** — provides `pdftoppm`, used by Claude Code's built-in `Read` to render PDF pages. macOS: `brew install poppler`. Debian/Ubuntu: `apt-get install poppler-utils`.
- **pdfminer.six** — text extraction: `pip install pdfminer.six`
- **pymupdf** — rasterization, image extraction, form widgets (radios, checkboxes, fillable fields): `pip install pymupdf`
- **pdfplumber** (optional) — structured table extraction to CSV: `pip install pdfplumber`

None of these are required to create a wiki or ingest plain-text sources. The init script checks for them and prints a warning if they're missing.

---

## Installation

Download or clone the `llm-wiki` package to a permanent location on your machine:

```bash
# Wherever you keep tools — these are just examples
cp -r llm-wiki ~/tools/llm-wiki
# or
git clone <repo-url> ~/tools/llm-wiki
```

Optionally, alias the init script so you can call it from anywhere:

```bash
# Add to your .bashrc / .zshrc
alias init-wiki="bash ~/tools/llm-wiki/scripts/init_wiki.sh"
```

---

## Quick start

### Step 1: Create a wiki

Run `scripts/init_wiki.sh` from the package (or the `init-wiki` alias if you set one up):

```bash
bash ~/tools/llm-wiki/scripts/init_wiki.sh ~/my-wiki "My Research Wiki" "Tracking AI safety papers and key debates"
```

This creates a ready-to-use wiki with all conventions baked in. To also install **skills** — focused workflow files that give Claude more structured, repeatable behavior for ingest, query, and lint — add the `--skills` flag:

```bash
bash ~/tools/llm-wiki/scripts/init_wiki.sh --skills ~/my-wiki "My Research Wiki" "Tracking AI safety papers and key debates"
```

Skills are optional. Without them (Mode A), Claude reads `SCHEMA.md` and figures out the right workflow from your natural language. With them (Mode B), Claude follows specific step-by-step workflows for each operation. Both produce the same wiki. You can start without skills and add them later — see [Adding skills to an existing wiki](#adding-skills-to-an-existing-wiki).

Both produce:
```
my-wiki/
├── CLAUDE.md              ← Claude Code reads this on session start
├── SCHEMA.md              ← conventions, workflows, formatting rules
├── page-templates.md      ← page format reference
├── index.md               ← page catalog
├── log.md                 ← operation history
├── raw/                   ← drop source files here (flat, any format)
│   ├── .wikiignore        ← raw files excluded from re-ingest
│   └── assets/            ← images, PDFs, data files
├── wiki/                  ← LLM-generated pages (flat, typed by frontmatter)
│   └── meta/              ← overview, open questions, lint reports
└── .obsidian/             ← pre-configured Obsidian settings
```

With `--skills`, you also get:
```
├── .claude/
│   └── skills/
│       ├── wiki-ingest/SKILL.md    ← process source documents (/wiki-ingest)
│       ├── wiki-query/SKILL.md     ← search and synthesize answers (/wiki-query)
│       └── wiki-lint/SKILL.md      ← interactive health check (/wiki-lint)
```

### Step 2: Start Claude Code

```bash
cd ~/my-wiki
claude
```

Claude reads `CLAUDE.md` automatically, which tells it to read `SCHEMA.md`. If skills are installed, `CLAUDE.md` also points to them. Claude knows it's a wiki maintainer. No further setup.

### Step 3: (Optional) Install qmd for search

```bash
npm install -g @tobilu/qmd
```

The agent sets up the collection automatically the first time it needs search. You just install the package. For tighter integration, install the Claude Code plugin:

```bash
claude plugin marketplace add tobi/qmd
claude plugin install qmd@qmd
```

At small scale (<50 pages), the agent uses `index.md` for navigation and qmd isn't needed.

### Step 4: Open in Obsidian

Open the wiki folder as a vault in Obsidian. The `.obsidian/` config is pre-set:

- Wikilinks enabled (not markdown links)
- Attachments save to `raw/assets/`
- New notes default to `wiki/`
- Graph view with color groups for meta pages
- Core plugins enabled: backlinks, graph, search, tags, outline

Install the **Dataview** community plugin (Settings → Community plugins → Browse → "Dataview"). This lets you run queries over frontmatter. Example:

```dataview
TABLE type, updated, tags FROM "wiki" SORT updated DESC LIMIT 20
```

### Step 5: Add sources and go

Drop files into `raw/`. Any format: markdown, HTML, PDF, DOCX, XLSX, CSV, EML, images. No naming conventions. Just dump.

For web articles, [Obsidian Web Clipper](https://obsidian.md/clipper) converts pages to markdown and saves them directly. The clipper preserves the source URL in frontmatter for duplicate detection on re-clip.

Tell Claude to process them:
- "Ingest the new file in raw"
- "Process everything in raw I haven't ingested yet"
- "What do the sources say about compute governance?"
- "Run a health check"

---

## Mode A vs. Mode B

You can use the wiki in two ways. Both produce the same wiki — the difference is how Claude operates on it.

**Mode A: Schema only (simpler, flexible).** Claude reads `SCHEMA.md` and figures out the right workflow from your natural language. You say "process the new file in raw" and Claude derives the ingest steps from the schema. No extra files needed. Best for getting started, small wikis, exploratory use, users who prefer natural conversation over rigid workflows.

**Mode B: Schema + Skills (more consistent, interactive).** Three focused skill files (`.claude/skills/ingest/`, `query/`, `lint/`) give Claude specific, repeatable workflows for each operation. The skills reference the schema for conventions but encode the operational patterns — file type detection, qmd search patterns, the interactive lint walkthrough. Best for larger wikis, frequent use, users who want consistent behavior across sessions, anyone who wants the lint skill's interactive guided resolution.

Both modes use the same `SCHEMA.md`, `page-templates.md`, index, and log. You can start with Mode A and add skills later, or remove skills and go back to Mode A. Nothing breaks either way.

---

## Adding skills to an existing wiki

If you started with Mode A and want to add skills later:

```bash
mkdir -p ~/my-wiki/.claude
cp -r ~/tools/llm-wiki/skills/* ~/my-wiki/.claude/skills/
```

Then add the skills section to your `CLAUDE.md`:

```markdown
## Skills

Skills are installed in `.claude/skills/`. When the user asks to ingest, query, or lint,
read the corresponding skill file and follow its workflow.

- `.claude/skills/wiki-ingest/SKILL.md` — process source documents into wiki pages (`/wiki-ingest`)
- `.claude/skills/wiki-query/SKILL.md` — search the wiki and synthesize answers (`/wiki-query`)
- `.claude/skills/wiki-lint/SKILL.md` — interactive health check with guided resolution (`/wiki-lint`)
```

Or just tell Claude: "I added skills to `.claude/skills/`, update CLAUDE.md to reference them."

---

## Multiple wikis

Each wiki is a self-contained directory. Run `init_wiki.sh` once per topic:

```bash
bash ~/tools/llm-wiki/scripts/init_wiki.sh ~/wikis/ai-safety "AI Safety Research" "Tracking AI safety papers and key debates"
bash ~/tools/llm-wiki/scripts/init_wiki.sh --skills ~/wikis/health "Health Wiki" "Personal health, nutrition, and exercise tracking"
```

Each wiki gets its own `SCHEMA.md`, `index.md`, `raw/`, `wiki/`, and (if `--skills` is used) its own `.claude/skills/`. Nothing is shared between wikis — skills, schema, and configuration are all project-specific.

**Obsidian:** Each wiki is a separate vault. Open each one via File → Open vault → Open folder as vault. Use the vault switcher (bottom-left corner) to jump between them. Each vault has its own graph, search, and settings.

**Claude Code:** `cd` into whichever wiki you want to work on and run `claude`. Claude reads that wiki's `CLAUDE.md` and operates on that wiki only.

**qmd:** Each wiki registers its own search collection. The init script handles this automatically if qmd is installed. Collections are independent — searching one wiki doesn't return results from another.

---

## Supported file types

| Type | How the LLM reads it |
|------|---------------------|
| Markdown (.md) | Directly. Web Clipper output is this. |
| HTML (.html) | BeautifulSoup extracts text + metadata from `<meta>` tags |
| CSV / TSV | CSV parser. Columns, row counts, patterns |
| XLSX (.xlsx) | openpyxl reads all sheets including notes/methodology |
| DOCX (.docx) | python-docx extracts paragraph text + headings (`doc.paragraphs`); `doc.tables` iterated separately for table cells (emitted as markdown tables, large tables saved to CSV in `raw/assets/`); `docx.oxml` walk captures form-control state (`w:checkBox`, `w:sdt`); `doc.part.related_parts` extracts embedded images. ActiveX radio groups fall back to libreoffice-to-PDF + rasterize |
| PDF (.pdf) | pdfminer for text; pymupdf for rasterization, embedded images, and form widgets (`page.widgets()` captures radio/checkbox state and filled fields); pdfplumber (optional) for structured table extraction → CSV in `raw/assets/`. Scanned PDFs rasterized and read visually |
| Email (.eml) | stdlib `email.message_from_bytes()` parses MIME tree. Headers → frontmatter (`From`, `Date`, `Subject`, `Message-ID` as duplicate-detection key); body prefers `text/plain`, falls back to stripped `text/html`; attachments extracted to `raw/assets/` (substantive ones like PDFs get their own linked source page); inline images saved as figures |
| Images (.png, .jpg) | Viewed directly. Stored in `raw/assets/`, linked via `assets` frontmatter |

**Re-clipping:** If you clip a web page you've already ingested and the content has changed, the agent detects the URL match and runs a re-ingest — diffs old vs new, updates the existing source summary, traces outward to update entity/concept pages that cited changed claims.

---

## Setting up qmd

[qmd](https://github.com/tobi/qmd) is a local search engine for markdown files by Tobi Lütke. Hybrid BM25 + vector search with LLM re-ranking, all on-device.

### Install (the one thing you do yourself)

```bash
npm install -g @tobilu/qmd
# or
bun install -g @tobilu/qmd
```

The agent handles everything else: collection setup, context, embeddings.

### How the agent uses qmd

Three search tiers, used automatically during ingest, query, and lint:

```bash
qmd --index <name> search "keyword" -c <name> --json          # fast BM25 keyword search
qmd --index <name> vsearch "conceptual question" -c <name> --json   # semantic vector search
qmd --index <name> query "full question" -c <name> --json      # hybrid + LLM reranking (best quality)
qmd --index <name> get "wiki/page.md"                          # retrieve full page content
```

The `<name>` is the wiki's directory name — e.g., `pseg` for a wiki at `~/wikis/pseg`. `--index` gives each wiki its own SQLite database (`~/.cache/qmd/<name>.sqlite`), and `-c` filters by collection within that index. The init script sets this up automatically and bakes the name into `SCHEMA.md` and the skill files.

Index maintenance (run by the agent automatically):

```bash
qmd --index <name> update                     # re-index changed files (BM25)
qmd --index <name> embed                      # update vector embeddings
qmd --index <name> cleanup                    # remove ghost entries for deleted files from vector index
```

### MCP server (Claude Code)

The init script generates a `.mcp.json` in each wiki that configures the qmd MCP server to use that wiki's dedicated index. This uses the `INDEX_PATH` environment variable as a workaround for [tobi/qmd#343](https://github.com/tobi/qmd/issues/343) (`--index` flag is ignored by the MCP server). Once that issue is resolved, this can be simplified.

You can also install the qmd plugin globally (useful as a fallback, but `.mcp.json` takes priority):
```bash
claude plugin marketplace add tobi/qmd
claude plugin install qmd@qmd
```

---

## Using with other LLM agents

### Claude.ai

1. Upload or paste `SCHEMA.md` as context at the start of a session
2. Upload source documents when you want to ingest them
3. Copy the generated wiki pages into your Obsidian vault manually

If using Claude.ai skills, place the `llm-wiki/` package in your skills folder — the `SKILL.md` handles triggering.

### Other agents (Codex, Cursor, etc.)

1. Run the init script to create the wiki
2. The agent reads `CLAUDE.md` (or rename to `AGENTS.md`, `.cursorrules`, etc.)
3. Set up qmd CLI if the agent can shell out, or MCP if supported

---

## Obsidian workflow

### Recommended layout

```
┌─────────────────────────┬──────────────────────────┐
│                         │                          │
│   Claude Code           │   Obsidian               │
│   (terminal)            │   (wiki vault open)      │
│                         │                          │
│   - Ingest sources      │   - Browse pages         │
│   - Answer queries      │   - Graph view           │
│   - Run lint            │   - Follow [[links]]     │
│                         │   - Read updates live     │
│                         │                          │
└─────────────────────────┴──────────────────────────┘
```

### Graph view

Open with Ctrl+G. Pre-configured with color groups for meta pages. Hub pages (many inbound links) are your most important pages. Orphans need attention.

### Useful hotkeys

| Action | Default |
|--------|---------|
| Graph view | Ctrl+G |
| Search | Ctrl+Shift+F |
| Quick switcher | Ctrl+O |
| Back | Ctrl+Alt+← |

### Dataview queries

**Recent activity:**
```dataview
TABLE type, updated FROM "wiki" SORT updated DESC LIMIT 10
```

**All sources by date:**
```dataview
TABLE author, date, source_type FROM "wiki" WHERE type = "source" SORT date DESC
```

**Open contradictions:**
```dataview
LIST FROM "wiki" WHERE contains(file.content, "[!warning]")
```

---

## Version control and collaboration

The wiki is just markdown files. Git works naturally:

```bash
cd ~/my-wiki
git init
git add -A
git commit -m "initial wiki structure"
```

The `.gitignore` is pre-configured. Commit after each ingest session.

### Sharing a wiki with a collaborator

The wiki folder is self-contained — your collaborator doesn't need the `llm-wiki` toolkit, just the wiki itself. Push it to a shared repo:

```bash
cd ~/my-wiki
git remote add origin <repo-url>
git push -u origin main
```

Your collaborator clones and sets up:

```bash
# 1. Clone the wiki
git clone <repo-url> ~/my-wiki
cd ~/my-wiki

# 2. Install qmd and build the search index (directory name = index name)
npm install -g @tobilu/qmd
qmd --index my-wiki collection add wiki/ --name my-wiki
qmd --index my-wiki update && qmd --index my-wiki embed

# 3. Optional: install the global qmd plugin (the wiki's .mcp.json handles per-wiki config)
claude plugin marketplace add tobi/qmd
claude plugin install qmd@qmd

# 4. Start working
claude
```

Open the folder as an Obsidian vault (File → Open vault → Open folder as vault) and they're fully set up — skills, schema, config, and Obsidian settings are all in the repo.

**Ongoing workflow:** both people commit and push/pull. The wiki is markdown — git merge works naturally. Coordinate ingest sessions to avoid conflicting edits to `index.md` and `log.md`.

If your collaborator also wants to create new wikis, they should clone the `llm-wiki` toolkit separately and set up the `init-wiki` alias.

---

## File manifest

The `llm-wiki` package:

```
llm-wiki/
├── README.md                          ← you are here
├── SKILL.md                           ← Claude.ai skill trigger (not needed for Claude Code)
├── scripts/
│   └── init_wiki.sh                   ← creates wiki (run with or without --skills)
├── skills/                            ← optional Claude Code skills
│   ├── wiki-ingest/SKILL.md            ← process source documents (/wiki-ingest)
│   ├── wiki-query/SKILL.md             ← search and synthesize answers (/wiki-query)
│   └── wiki-lint/SKILL.md              ← interactive health check (/wiki-lint)
└── references/
    ├── schema-template.md             ← full SCHEMA.md template
    └── page-templates.md              ← page format templates
```

What the init script produces:

```
my-wiki/
├── CLAUDE.md                          ← Claude Code entry point
├── SCHEMA.md                          ← conventions and workflows
├── page-templates.md                  ← page format reference
├── index.md                           ← page catalog
├── log.md                             ← operation history
├── raw/                               ← source documents (flat)
│   ├── .wikiignore                    ← raw files excluded from re-ingest
│   └── assets/                        ← images, data files
├── wiki/                              ← LLM pages (flat, typed by frontmatter)
│   └── meta/                          ← overview, open questions, lint reports
├── .obsidian/                         ← Obsidian config (6 files)
└── .claude/skills/ (if --skills)      ← wiki-ingest/, wiki-query/, wiki-lint/
```
