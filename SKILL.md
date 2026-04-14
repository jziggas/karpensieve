---
name: karpensieve
description: >
  Build and maintain a persistent, LLM-maintained wiki from raw source documents using Obsidian-compatible markdown.
  Use this skill whenever the user wants to: create a new knowledge wiki or knowledge base from documents,
  ingest/process source documents into an existing wiki, query or search a wiki, lint or health-check a wiki,
  set up a "second brain" or personal knowledge management system backed by markdown files,
  or any task involving structured knowledge accumulation from sources over time.
  Also trigger when the user mentions "wiki", "knowledge base", "ingest documents", "process sources",
  "Obsidian wiki", "research wiki", "karpensieve", or references the pattern of LLMs maintaining a wiki.
  Do NOT use for one-off document summaries, simple file reading, or generic markdown editing unrelated to wiki maintenance.
---

# karpensieve Skill

An LLM-maintained, Obsidian-compatible wiki that compiles knowledge from raw sources into a persistent, interlinked collection of markdown pages. Flat structure, minimal ceremony, typed by frontmatter not folders.

## Quick orientation

| Task | When | What to read |
|------|------|-------------|
| **Init** | User wants a new wiki | Run `scripts/init_wiki.sh`, then customize the generated `SCHEMA.md` using `references/schema-template.md` as the full reference |
| **Ingest** | User adds source documents | Follow the wiki's `SCHEMA.md` ingest workflow + `references/page-templates.md` for page formats |
| **Query** | User asks a question | Follow the wiki's `SCHEMA.md` query workflow |
| **Lint** | User wants a health check | Follow the wiki's `SCHEMA.md` lint workflow |

---

## 1. Init — Create a new wiki

1. Ask what domain this wiki covers (research topic, personal, book, business, etc.)
2. Ask where it should live (default: current working directory)
3. Run the init script:
   ```bash
   bash /path/to/karpensieve/scripts/init_wiki.sh "<wiki_path>" "<wiki_name>" "<domain_description>"
   ```
4. Read `references/schema-template.md` and customize the generated `SCHEMA.md` for the user's domain.
5. Walk the user through the result.
6. If sources are ready, proceed to Ingest.

---

## 2. Ingest — Process source documents

**Always read the wiki's `SCHEMA.md` first.** It contains the authoritative workflow.

Standard flow:
0. **Identify unprocessed files** — compare files in `raw/` against `source_file` values in wiki pages. Report new files to the user.
1. **Check for URL duplicates** — if the source has a URL, check for an existing match. If found → **re-ingest** (update existing pages, don't duplicate).
2. **Read the source** — strategy depends on file type (markdown, HTML, CSV, XLSX, DOCX, PDF, images — see schema for details).
3. **Discuss** key takeaways with the user. For multiple files: present a single batch overview, then process.
4. **Create** source summary page in `wiki/` — `source_file` in frontmatter is how unprocessed detection works.
5. **Create or update** entity and concept pages in `wiki/`
6. **Search** with qmd for related pages, update cross-references
7. **Flag** contradictions — never silently overwrite
8. **Update** `index.md`
9. **Log** — every source gets its own entry, even in batch mode
10. **Run** `qmd --index <collection> update && qmd --index <collection> embed` (once at end of batch)

### Search during ingest

Use qmd to find pages that should be cross-referenced with new content. qmd uses collections — the wiki directory should be registered as a collection during init (see README).

**MCP (preferred — Claude Code or MCP-compatible agents):**
qmd runs as an MCP server via `qmd mcp` (stdio). The LLM calls its `query` tool directly — structured input/output, no parsing. Install as a Claude Code plugin: `claude plugin marketplace add tobi/qmd`.

**CLI (fallback):**
```bash
qmd --index <collection> search "key concept from new source" --json -c <collection>
qmd --index <collection> query "broader semantic concept" --json -c <collection>    # hybrid + reranking, best quality
```

Extract 3-5 key claims or entities from the new source. Search for each. Read the top results. Update cross-references on both the new and existing pages.

---

## 3. Query — Answer questions from the wiki

1. Search the wiki with qmd for relevant pages
2. Read top results
3. Synthesize an answer with pipe-format wikilink citations: `[[file-slug|Display Text]]` (bare `[[Display Text]]` doesn't resolve via aliases in Obsidian and creates empty stub files when clicked)
4. If the answer is substantive, offer to file it as a new wiki page

At small scale (<50 pages), reading `index.md` to find relevant pages works fine as a fallback.

---

## 4. Lint — Health-check the wiki

Search the wiki systematically. Report on:
- **Orphan pages**: search for each page's title — if nothing references it, flag it
- **Dead links**: piped wikilinks `[[file-slug|Display]]` whose `file-slug` doesn't exist as a real `.md` file
- **Bare wikilinks**: any `[[...]]` (not image embeds) lacking the pipe (`|`) — these don't resolve and create empty stubs in Obsidian; rewrite to `[[file-slug|Display Text]]`
- **Title-case shadow files**: empty stub `.md` files in `wiki/` with title-case names (typically auto-created by Obsidian from broken bare wikilinks); delete after rewriting inbound bare wikilinks
- **Stale content**: pages not updated since newer sources arrived on the same topic
- **Missing pages**: entities/concepts mentioned 2+ times but lacking their own page
- **Contradictions**: unresolved `[!warning]` callouts
- **Thin pages**: pages under ~100 words
- **Under-connected pages**: search for a page's key terms — if related pages exist but don't link to each other, suggest cross-references

---

## File references

| File | Purpose | When to read |
|------|---------|-------------|
| `scripts/init_wiki.sh` | Creates wiki directory structure and starter files | Init |
| `references/schema-template.md` | Full SCHEMA.md template with all conventions and workflows | Init (to customize), Ingest (to follow) |
| `references/page-templates.md` | Frontmatter and structure templates for each page type | Ingest |
| `README.md` | Setup guide, Obsidian config, qmd install, full how-to | Init or when user asks about setup |
