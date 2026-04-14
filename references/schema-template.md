# SCHEMA.md Template

> Copy into the root of a new wiki and customize sections marked with `{{placeholders}}`.
> This is the governing document. The LLM reads it at the start of every session.

---

# {{Wiki Name}}

## Purpose

{{One paragraph: what this wiki covers and what the goal is.}}

**Domain:** {{e.g., "AI safety research", "personal health", "competitive analysis"}}
**Owner:** {{your name or team}}
**Started:** {{date}}

---

## Directory structure

```
{{wiki-root}}/
├── SCHEMA.md       ← conventions and workflows (you are here)
├── index.md        ← catalog of all wiki pages
├── log.md          ← chronological record of all operations
├── raw/            ← source documents — flat, dump anything here
│   ├── .wikiignore ← raw files excluded from unprocessed file scan
│   └── assets/     ← images, PDFs, data files referenced by sources
└── wiki/           ← LLM-generated pages — flat, typed by frontmatter
    └── meta/       ← overview, open questions, lint reports
```

### Rules

- **`raw/`** is immutable. The LLM reads but never creates, modifies, or deletes files here (except `raw/.wikiignore`, which the LLM maintains).
- **`wiki/`** is LLM-owned. The LLM creates and updates all files. The human reads and browses.
- **`SCHEMA.md`** is co-owned. Human and LLM evolve it together.
- **`index.md`** and **`log.md`** live at the root, maintained by the LLM.
- **No subfolders** in `raw/` or `wiki/` (except `raw/assets/` and `wiki/meta/`). Page type is tracked in frontmatter, not directory path.

---

## Page types

Every page has a `type` field in its frontmatter. Types are:

| Type | What it covers |
|------|---------------|
| `source` | One page per ingested source document. Structured summary, key claims, links. |
| `entity` | A concrete thing: person, org, product, place, dataset, tool. |
| `concept` | An abstract idea: theory, method, framework, phenomenon, debate. |
| `analysis` | Synthesis across multiple sources. Comparisons, filed query results. |
| `meta` | Pages about the wiki: overview, open questions, lint reports. |

If something doesn't fit a type cleanly, use the closest match or `analysis` as a catch-all. Don't agonize — the type is metadata for filtering, not a constraint on content.

{{Add domain-specific types here if needed. E.g., a book wiki might add `chapter`, `character`, `theme`.}}

---

## Naming conventions

- **Filenames:** lowercase, hyphens for spaces. `reward-hacking.md`, not `Reward Hacking.md`
- **Wikilinks:** always use Obsidian's pipe format `[[file-slug|Display Text]]` — e.g. `[[reward-hacking|Reward Hacking]]`. The slug part is the kebab-case filename (without `.md`); the display part is what readers see. **Bare `[[Display Text]]` does NOT work** — Obsidian resolves wikilinks by exact filename match only, not by aliases or titles. A bare wikilink whose text doesn't match a filename will silently create an empty stub file when clicked. The pipe format is what Obsidian's own autocomplete generates.
- **Aliases:** populate Quick Switcher and `[[autocomplete]]` suggestions. Include the page title and any abbreviations or alternate names so they surface when users search (`aliases: ["Reward Hacking", RLHF]` on `reward-hacking.md`). Aliases do NOT affect how clicked wikilinks resolve — that's the filename's job.

---

## Frontmatter standard

Every wiki page gets YAML frontmatter. Required fields:

```yaml
---
title: "Page Title"
type: source | entity | concept | analysis | meta
created: YYYY-MM-DD
updated: YYYY-MM-DD
tags:
  - tag-one
  - tag-two
---
```

### Additional fields by type

**Source pages:**
```yaml
source_type: article | paper | transcript | book | report | note | data | email | jira-issue | confluence-page | other
author: "Author Name"
date: YYYY-MM-DD                # publication date
url: "https://..."              # original URL — critical for duplicate detection on re-clip
message_id: "<unique-id@domain>" # for email sources — duplicate detection on re-ingest (mirrors `url`'s role)
jira_key: "PROJ-123"            # for JIRA sources — stable duplicate-detection key; include jira_status at snapshot time
jira_status: "In Progress"      # JIRA status at snapshot time
confluence_page_id: "123456"    # for Confluence sources — stable duplicate-detection key
confluence_version: 42          # Confluence page version at snapshot time — bumps on every edit
confluence_space: "ENG"         # Confluence space key
source_file: "raw/filename.md"  # path to raw source
prior_versions:                 # previous versions of this source (populated on re-ingest)
  - "raw/old-filename.md"
assets:                         # images/files associated with this source
  - "raw/assets/diagram.png"
  - "raw/assets/table-data.csv"
aliases:                        # for Quick Switcher and autocomplete; does NOT affect wikilink resolution. Include the title plus abbreviations/alternate names
  - "Source Title"
```

**Entity pages:**
```yaml
entity_type: person | organization | product | place | dataset | tool
aliases:                        # for Quick Switcher and autocomplete; does NOT affect wikilink resolution. Include the title plus abbreviations/alternate names
  - "Entity Name"
  - Alternate Name
sources:
  - "[[source-page-one|Source Page One]]"
```

**Concept pages:**
```yaml
aliases:                        # for Quick Switcher and autocomplete; does NOT affect wikilink resolution. Include the title plus abbreviations/alternate names
  - "Concept Name"
  - Alternate Name
confidence: high | medium | low | speculative
sources:
  - "[[source-page-one|Source Page One]]"
```

**Analysis pages:**
```yaml
aliases:                        # for Quick Switcher and autocomplete; does NOT affect wikilink resolution. Include the title plus abbreviations/alternate names
  - "Analysis Title"
sources:
  - "[[source-page-one|Source Page One]]"
  - "[[source-page-two|Source Page Two]]"
```

---

## Ingest workflow

When the human asks to ingest, or when the session start checklist finds unprocessed files. For sources that live in Atlassian rather than on disk (JIRA tickets, Confluence pages), see the **Atlassian fetch** section below — it writes snapshots into `raw/` and then the normal pipeline runs.

### Atlassian fetch (JIRA, Confluence)

For sources that live in Atlassian rather than on disk. Fetches via MCP and writes a markdown snapshot to `raw/`; the normal ingest flow processes it from Step 0 onward. Re-pulls hit Step 1's identifier duplicate check and route through Re-ingest.

**Triggers:**
- **Explicit per-item** — user says "ingest JIRA PROJ-123" or "ingest confluence <url>"
- **Saved queries** — `raw/.atlassian-queries.yaml` holds named JQL/CQL queries (example below); on "refresh atlassian", iterate each query and snapshot matching items
- **URL paste** — if the user drops a JIRA/Confluence URL in the conversation, offer to pull it

```yaml
# raw/.atlassian-queries.yaml
jira:
  - name: open-blockers
    jql: "project = PROJ AND status = Open AND priority = Blocker"
confluence:
  - name: eng-space-recent
    cql: "space = ENG AND lastmodified > now('-7d')"
```

**MCP tools to use:**
- `getJiraIssue` — ticket body, fields; `fields.comment.comments[]` when `fields=*all`, else `fetchAtlassian` on `/rest/api/3/issue/<key>/comment`
- `getJiraIssueRemoteIssueLinks` — linked issues / external refs
- `searchJiraIssuesUsingJql` — batch discovery
- `getConfluencePage` — page body (storage/ADF — convert to markdown; use `body.atlas_doc_format` or `body.view` if returned)
- `getConfluencePageFooterComments` + `getConfluencePageInlineComments` — comment threads
- `getConfluencePageDescendants` — child pages (optional)
- `searchConfluenceUsingCql` — batch discovery
- `fetchAtlassian` — generic REST fallback; use for attachment binary downloads

**Snapshot format — JIRA (`raw/jira-<KEY>.md`):**

```markdown
---
jira_key: "PROJ-123"
url: "https://{{instance}}.atlassian.net/browse/PROJ-123"
jira_status: "In Progress"
assignee: "Jane Doe"
reporter: "John Smith"
priority: "High"
labels: [backend, auth]
created: 2026-03-01
updated: 2026-04-13        # JIRA's updated timestamp — re-ingest signal
fetched: 2026-04-13
---

# [PROJ-123] Ticket summary line

## Description
{{ticket body}}

## Comments

### [2026-03-05 14:22] Jane Doe
{{comment}}

## Linked issues
- PROJ-122 (blocks)

## Attachments
- spec.pdf → raw/assets/jira-PROJ-123-attach1.pdf
```

**Snapshot format — Confluence (`raw/confluence-<page-id>-<slug>.md`):**

```markdown
---
confluence_page_id: "123456"
confluence_space: "ENG"
confluence_version: 42
url: "https://{{instance}}.atlassian.net/wiki/spaces/ENG/pages/123456/Page+Title"
author: "Jane Doe"
created: 2025-11-01
updated: 2026-04-12
fetched: 2026-04-13
---

# Page Title

{{page body, converted from ADF/storage to markdown}}

## Inline comments
### [2026-03-20] Jane Doe on "quoted text fragment"
{{comment}}

## Footer comments
### [2026-04-01 10:00] John Smith
{{comment}}

## Child pages
- [[confluence-789-deployment-plan|Deployment Plan]]
```

**Attachments:** reuse the email-attachment pattern. Download each attachment binary to `raw/assets/jira-<KEY>-attach<n>.<ext>` (or `confluence-<id>-attach<n>.<ext>`) via `fetchAtlassian` against `/rest/api/3/attachment/content/<id>` (JIRA) or `/download/attachments/<page-id>/<filename>` (Confluence); fall back to `curl` with the user's Atlassian token if binary fetch fails. Reference in `assets:` frontmatter. **Substantive attachments** (PDF, DOCX, XLSX, PPTX) become their own source page with `source_file` pointing at the extracted asset path, wikilinked from the ticket/page source page. Inline images and screenshots stay as assets, not promoted.

Use `source_type: jira-issue` for JIRA tickets and `source_type: confluence-page` for Confluence pages.

### Step 0 — Identify unprocessed files

Find files in `raw/` that don't have a corresponding wiki source page and aren't listed in `raw/.wikiignore`:

```bash
_tmp=$(mktemp -d)
# Files in raw/ (excluding hidden files and assets/)
find raw/ -maxdepth 1 -type f ! -name '.*' | sort > "$_tmp/raw.txt"
# Files already ingested (source_file values + prior_versions)
grep -rh "raw/" wiki/*.md 2>/dev/null | grep -oE '"raw/[^"]*"' | tr -d '"' | sort -u > "$_tmp/ingested.txt"
# Files excluded via .wikiignore (one per line, # comments, blank lines ignored)
grep -v '^\s*#' raw/.wikiignore 2>/dev/null | grep -v '^\s*$' | sed 's|^|raw/|' | sort > "$_tmp/ignored.txt"
# Unprocessed = raw files minus ingested minus ignored
comm -23 "$_tmp/raw.txt" "$_tmp/ingested.txt" | comm -23 - "$_tmp/ignored.txt"
rm -rf "$_tmp"
```

Present findings to the user:
- **1 file:** "There's 1 unprocessed file: `raw/new-article.md`. Process it?"
- **Multiple:** "There are N unprocessed files. Process all, pick specific ones, or skip?"
- **None:** "All files in raw/ have been processed."

If the user specifies a file directly, skip the scan.

For multiple files, see the **Batch ingest** section at the end of this workflow.

### Step 1 — Check for prior versions (URL duplicate detection)

Before reading the source, check whether it's an update to something already ingested.

**Extract a URL or identifier from the new file:**
- Markdown (web clips): check YAML frontmatter for `source`, `url`, or `link` fields — Obsidian Web Clipper saves the URL here
- HTML: check `<meta>` tags (`og:url`, `canonical`), or `<link rel="canonical">`
- PDF: check PDF metadata (title, author, creation date) — less reliable than URLs
- Email (.eml): read the `Message-ID` header. If absent, fall back to a composite of `Subject` + `From` + `Date`. Match against `message_id` frontmatter on existing source pages.
- Atlassian snapshots (`raw/jira-*.md`, `raw/confluence-*.md`): match on `jira_key` or `confluence_page_id` frontmatter; fall back to `url`. Every re-pull reliably routes into Re-ingest because the identifier is stable.
- Other formats: filename similarity as a weak signal

**Search existing source pages** for a matching `url` frontmatter field. If there's a match, this is a **re-ingest** — jump to the Re-ingest branch below.

If no match, this is a new source. Continue to Step 2.

### Step 2 — Read the source

**Reading strategy depends on file type:**

**Markdown / text:** Read directly. If the source contains image references (`![[image.png]]` or `![alt](url)`), read the text first, then view the referenced images in `raw/assets/` to pick up visual context — charts, diagrams, and screenshots often carry information not in the text. Also scan the body for embedded ```mermaid fences and apply the Mermaid handling below to each.

**Mermaid (`.mmd`, `.mermaid`, or embedded ```mermaid blocks):** Read directly as text — the Mermaid syntax itself is the content. Parse nodes and edges: each named node is a candidate entity or concept page; each edge is a cross-reference where the edge label is the relationship semantic (`calls`, `depends on`, `extends`, `triggers`, etc.). Embed the diagram verbatim in a ```mermaid fence on the source page so Obsidian renders it (no plugin required). Per diagram type:
- `graph` / `flowchart` — process steps as concept/entity pages; edges as directional links
- `sequenceDiagram` — actors as entities; messages as interactions (auth flows, API traces)
- `classDiagram` — classes as entities; inheritance and composition as relationships
- `erDiagram` — **1:1 mapping** — each entity in the diagram becomes an entity page; cardinality + role labels become the connection semantic
- `stateDiagram` — states as concept pages; transitions as connections
- `C4` — systems / containers / components as entities at the matching level

**HTML:** Extract text content, metadata (author, date from `<meta>` tags), and note any image references.

**CSV / TSV:** Read with a CSV parser. Note column names, row count, and key patterns in the data.

**XLSX:** Read all sheets. Note headers, data ranges, and any notes/methodology sheets.

**PPTX (presentations):** Read with `python-pptx`. Iterate `prs.slides` preserving slide order — decks are narratives.

1. Per slide, capture:
   - Title: `slide.shapes.title.text` (if a title shape exists)
   - Body text and bullets: iterate `shape.text_frame.paragraphs` and preserve indent level
   - Tables: `shape.has_table` → `shape.table.rows` → `cell.text`; emit as markdown tables. Wide/data-dense tables (>5 cols or >20 rows) also save rows as CSV to `raw/assets/{{source-slug}}-slide{{n}}-tbl{{m}}.csv` and link via `assets` frontmatter.
   - Embedded images: iterate picture shapes and write `shape.image.blob` to `raw/assets/{{source-slug}}-slide{{n}}-fig{{m}}.{{ext}}`. View each; keep charts/diagrams/screenshots, skip decorative logos.
   - **Speaker notes:** `slide.notes_slide.notes_text_frame.text` — often the most valuable content on the slide, since slides show keywords and notes hold the actual explanation.
2. Structure the wiki source page with `### Slide N — Title` subsections under `## Details`, followed by body, a `**Speaker notes:**` line, and inline image embeds (`![[...]]`). This preserves the deck flow rather than collapsing it to a wall of text.
3. Google Slides: export via `File → Download → Microsoft PowerPoint (.pptx)`, then drop into `raw/`. Keynote: export to .pptx first.

**DOCX:**
1. Extract paragraph text and headings via `python-docx` (`doc.paragraphs`).
2. Iterate `doc.tables` separately — table cell text is NOT in `doc.paragraphs`. Emit as markdown tables in the source summary; for wide/data-dense tables (>5 cols or >20 rows) also save rows as CSV to `raw/assets/{{source-slug}}-tbl{{n}}.csv` and reference in `assets` frontmatter. Merged cells repeat the same cell object across spans — dedupe if needed.
3. For form controls, walk `doc.element.body.iter()` looking for `w:checkBox` (legacy form fields, with `w:default`/`w:checked` state), `w:ffData`, and `w:sdt` (content controls — `checkbox`, `dropDownList`). Capture the nearest paragraph as the control's label. ActiveX OLE radio groups are not reachable via oxml — fall back to converting the docx to PDF (`libreoffice --headless --convert-to pdf`) and rasterizing per the PDF flow.
4. Extract embedded images via `doc.part.related_parts` filtered on `content_type` starting with `image/`. Save substantive ones (charts, diagrams) to `raw/assets/{{source-slug}}-fig{{n}}.{{ext}}`; skip decorative.

**PDF (requires extra steps):**
1. Extract text via pdfminer. Check whether meaningful text was returned — if mostly garbage or empty, the PDF is likely scanned.
2. For scanned PDFs: rasterize pages to images (via pymupdf) and read them visually.
3. For fillable forms (`doc.is_form_pdf == True`): enumerate `page.widgets()` per page and record each widget's `field_type_string`, `field_name`, and `field_value` in the source summary — this is how you capture radio/checkbox state and filled text fields. If the form has been flattened (no widgets, but form visuals remain), fall back to rasterization.
4. For structured tables: use `pdfplumber.extract_tables()` and save each table as CSV to `raw/assets/{{source-slug}}-p{{page}}-tbl{{n}}.csv`. Link from the source page's `assets` frontmatter. If `pdfplumber` is unavailable, rasterize the page and read the table visually.
5. Extract embedded images via pymupdf (`fitz`). Save substantive images (charts, diagrams — skip logos, decorative elements) to `raw/assets/` with names derived from the source: `{{source-slug}}-p{{page}}-fig{{n}}.png`
6. View extracted images to pick up information not in the text — data from charts, relationships from diagrams, details from screenshots.

For short PDFs (≤20 pages), Claude Code's native `Read` with `pages:` is a faster alternative to shelling out — it renders pages via poppler and captures visual state including drawn radio/checkbox marks.

**Email (.eml):**
1. Parse with stdlib: `msg = email.message_from_bytes(path.read_bytes())`.
2. Capture headers into frontmatter: `From → author`, `Date → date`, `Subject → subject`, `Message-ID → message_id`. Keep `To`, `Cc`, `In-Reply-To`, `References` in the body for thread context.
3. Walk `msg.walk()` for body content. Prefer `text/plain` parts; fall back to stripped `text/html` via BeautifulSoup. If quoted reply chains dominate (>50% of body), trim them and note the trim in the summary.
4. Extract attachments (`get_content_disposition() == "attachment"`) to `raw/assets/{{source-slug}}-attach{{n}}.{{ext}}` using sanitized `get_filename()`. Reference in `assets` frontmatter. If an attachment is itself a substantive source (PDF/DOCX/XLSX/PPTX), create a separate source page for it, wikilinked from the email page, with `source_file` pointing to the extracted path.
5. Extract inline images (`get_content_disposition() == "inline"`) to `raw/assets/{{source-slug}}-fig{{n}}.{{ext}}`. View each; keep substantive, skip decorative signatures/logos.

**Images (PNG, JPG, etc.):** View the image directly. Images are typically assets associated with another source — record the association in that source's `assets` frontmatter. If the image is a standalone source (e.g., a photographed whiteboard), create a source summary from the visual content.

After reading, note any image references. Record associated asset paths in the source summary's `assets` frontmatter field.

### Step 3 — Discuss (interactive mode)

Summarize 3-5 key takeaways and share with the human. Ask:
- What to emphasize?
- Specific entities or concepts to focus on?
- Connections to existing wiki content?

Skip if the human requested batch/silent mode.

### Step 4 — Create the source summary page

Create `wiki/{{source-slug}}.md` with type `source`. Include:
- Structured summary (sections, not a wall of text)
- Key claims with wikilinks to entity/concept pages
- `source_file` and `assets` in frontmatter linking back to raw files
- `url` in frontmatter if the source has one (critical for duplicate detection on re-clip)
- For PDFs: embed extracted images where they add context, using `![[image.png]]`

### Step 5 — Create or update entity and concept pages

For each significant entity or concept in the source:
- **Exists?** Add new info, add source to `sources` list, update `updated` date.
- **New?** Create the page. Include everything known from this source, framed as a starting point.

### Step 6 — Find related pages with qmd

Extract 3-5 key claims, entities, or terms from the new source. Search for each:

```bash
# Fast keyword search (BM25, exact terms)
qmd --index {{qmd-collection}} search "term" --json -c {{qmd-collection}}

# Semantic vector search (meaning-based, fuzzy matches)
qmd --index {{qmd-collection}} vsearch "broader concept" --json -c {{qmd-collection}}

# Hybrid search + LLM reranking (best quality, slower)
qmd --index {{qmd-collection}} query "full question about the concept" --json -c {{qmd-collection}}
```

Read the top results. For each related page:
- Add `[[wikilinks]]` in both directions if the connection is meaningful
- If new information updates or contradicts an existing page, edit it

If qmd is available as an MCP tool, use the `query` tool directly instead of CLI.

### Step 7 — Check for contradictions

If the new source contradicts an existing claim:
- Add a callout on the relevant page:
  ```markdown
  > [!warning] Contradiction
  > [[source-a|Source A]] claims X, but [[source-b|Source B]] claims Y.
  ```
- Do not silently overwrite. Contradictions are signal.

### Step 8 — Update index.md

Add entries for all new pages. Update summaries for substantially modified pages.

### Step 9 — Update log.md

Append:
```markdown
## [YYYY-MM-DD] ingest | {{Source Title}}

- Source: `raw/{{filename}}`
- Pages created: [[page-a|Page A]], [[page-b|Page B]]
- Pages updated: [[page-c|Page C]], [[page-d|Page D]]
- Notes: {{what was notable}}
```

### Step 10 — Update search index (if using qmd)

Run `qmd --index {{qmd-collection}} update && qmd --index {{qmd-collection}} embed` to re-index changed files and update vector embeddings for new and modified pages. Keyword search (`qmd --index {{qmd-collection}} search`) works immediately without this step, but semantic search (`qmd --index {{qmd-collection}} vsearch`) and hybrid search (`qmd --index {{qmd-collection}} query`) require current embeddings. In batch mode, defer this to after the last source — run once at the end.

**Note on logging:** Every source gets its own log entry, even when processing multiple files. This is provenance. If a claim needs tracing later, you need to know exactly which source introduced it.

---

## Batch ingest

When Step 0 identifies multiple unprocessed files:

1. **Read all** unprocessed files (Step 2 for each)
2. **Present a batch overview** to the human: "Here are the N new sources. They cover X, Y, Z. Key themes: A, B, C. Any direction before I process?" The human gives high-level guidance once instead of per-file discussion
3. **Process each source** through Steps 1, 4-9 sequentially. Each source gets its own pages, its own cross-reference pass, its own index update, and its own log entry. Later sources benefit from pages created by earlier ones
4. **Run `qmd --index {{qmd-collection}} update && qmd --index {{qmd-collection}} embed` once** at the end
5. **Optionally suggest a lint pass** — batch ingests often surface new connections worth checking

---

## Re-ingest workflow

When Step 0 detects a URL match against an existing source page, the source has been updated since it was last ingested.

### Step R1 — Diff old and new versions

Read both the old and new raw files. Identify what changed:
- New sections or removed content
- Updated claims or data
- Changed dates, numbers, or status

For Atlassian snapshots, frame the diff around **new comments since the last pull** and **status changes** — those are the signal, not raw text diff. JIRA's `updated` timestamp bumps on any field or comment change; Confluence's `version` bumps on page edits. Comparing comment lists between snapshots gives you the exact new-comment set.

### Step R2 — Update the source summary page

Update the existing source summary (do not create a duplicate). Change the `updated` date. Revise the summary to reflect the current version. Note what changed:

```markdown
> [!info] Updated YYYY-MM-DD
> Re-ingested from updated source. Changes: {{brief description of changes}}.
```

Update `source_file` to point to the newer version. Keep the old file noted:
```yaml
source_file: "raw/{{new-filename}}"
prior_versions:
  - "raw/{{old-filename}}"
```

### Step R3 — Trace outward and update

Which entity/concept pages cite claims from this source? For each:
- If the cited claim has changed, update the page
- If a claim that was flagged as a `[!warning] Contradiction` has been resolved by the update, update or remove the callout
- If new claims introduce new entities or concepts, create pages as in Step 4

### Step R4 — Log the re-ingest

```markdown
## [YYYY-MM-DD] re-ingest | {{Source Title}} (updated)

- Source: `raw/{{new-filename}}` (prior: `raw/{{old-filename}}`)
- Changes: {{brief description}}
- Pages updated: [[source-summary|Source Summary]], [[page-a|Page A]], [[page-b|Page B]]
- Notes: {{what was notable about the changes}}
```

### Step R5 — Update index.md

If any page summaries changed during the re-ingest, update their entries in `index.md`.

### Step R6 — Update search index (if using qmd)

Run `qmd --index {{qmd-collection}} update && qmd --index {{qmd-collection}} embed`.

---

## Query workflow

1. **Search** the wiki with qmd (`qmd --index {{qmd-collection}} query "question" --json -c {{qmd-collection}}` or via MCP). At small scale (<50 pages), reading `index.md` is fine as a fallback.
2. **Read** the top results
3. **Synthesize** an answer grounded in wiki content, citing pages with `[[wikilinks]]`
4. If the answer reveals a **gap**, say so — suggest sources to find or questions to investigate
5. If the answer is **substantive** (comparison, synthesis, analysis), offer to file it as a new page in `wiki/` with type `analysis`

---

## Lint workflow

Periodic health check. Scan the wiki and report:

| Check | Method |
|-------|--------|
| Orphan pages | For each page, search its title with qmd — if nothing references it, flag |
| Dead links | Parse all `[[file-slug\|Display]]` wikilinks; check each `file-slug` resolves to an existing file in `wiki/` or `wiki/meta/` |
| Bare wikilink format | Flag any `[[...]]` (excluding image embeds `![[...]]`) that lacks the pipe (`\|`); these don't resolve via aliases in Obsidian and create empty stub files when clicked. Rewrite to `[[file-slug\|Display Text]]`. |
| Title-case shadow files | Scan `wiki/` for any file whose name doesn't match the kebab-case convention (capital letter at start, spaces in name); these are typically empty stubs auto-created by Obsidian from broken bare wikilinks. Delete after confirming inbound bare wikilinks have been rewritten. |
| Stale pages | Compare each page's `updated` date against newer sources on the same topic |
| Missing pages | Find entities/concepts mentioned 2+ times across pages but lacking their own page |
| Contradictions | Search for unresolved `[!warning]` callouts |
| Thin pages | Pages under ~100 words of content |
| Under-connected | Search each page's key terms — if semantically related pages don't link to each other, suggest it |
| Index drift | Diff files on disk against entries in `index.md` |
| Tag inconsistency | Collect all tags, flag variant spellings or near-duplicates |

File as `wiki/meta/lint-report-YYYY-MM-DD.md` and log it. If any pages were deleted or merged during lint, run `qmd --index {{qmd-collection}} update && qmd --index {{qmd-collection}} cleanup && qmd --index {{qmd-collection}} embed` instead of the standard `qmd --index {{qmd-collection}} update && qmd --index {{qmd-collection}} embed`. `cleanup` removes ghost entries from the vector index for files that no longer exist on disk. The standard ingest command does not need `cleanup` because ingest only adds or modifies pages.

---

## Page restructuring (merge and split)

When merging or splitting pages, **inbound wikilinks must be rewritten** because Obsidian resolves wikilinks by exact filename match. The old page's filename (slug) no longer exists, so any `[[old-slug|Display]]` wikilink elsewhere in the wiki is now broken. Use a script or grep to find every `[[old-slug|...]]` and rewrite the slug part to point at the merge target. Also add the old page's title to the target's `aliases:` list so Quick Switcher and autocomplete still surface it.

When splitting a page into two, designate one as the "primary" — it inherits the old slug (rename in Obsidian via right-click → rename, which auto-updates all `[[old-slug|Display]]` references) and absorbs most inbound links. Only links that semantically belong on the secondary page need manual updating to point at the new slug.

Source pages should not be merged with each other. The 1:1 mapping between a source page and its `source_file` raw path is how provenance works. A thin source page can be merged into an entity or concept page if a separate summary isn't warranted — note the `source_file` in the target so the raw file remains traceable.

Log restructuring like other operations: `## [YYYY-MM-DD] merge | [[old-page|Old Page]] → [[target|Target]]` or `## [YYYY-MM-DD] split | [[old-page|Old Page]] → [[page-a|Page A]] + [[page-b|Page B]]`.

---

## Formatting conventions

### Callouts (Obsidian-native)

```markdown
> [!info] Key finding
> Summary of an important finding.

> [!warning] Contradiction
> Source A claims X, but Source B claims Y. See [[Source A]], [[Source B]].

> [!question] Open question
> Something worth investigating further.

> [!tip] Connection
> This relates to [[Other Page]] because...
```

### Page structure

Use a consistent heading hierarchy:
```
# Page Title (matches frontmatter title)
## Overview (2-3 sentences — always first)
## (Content sections — vary by type)
## Connections (wikilinks to related pages — always second-to-last)
## Sources (source page wikilinks — always last)
```

### Tables

Use markdown tables for structured comparisons. Keep narrow enough for Obsidian's editor view.

---

## Domain-specific conventions

{{Customize for your domain. Delete these examples and add your own:}}

{{For a research wiki:}}
{{- How to handle conflicting findings between papers}}
{{- Methodology tracking conventions}}
{{- How to maintain an evolving thesis page}}

{{For a personal wiki:}}
{{- Journal vs. structured knowledge boundaries}}
{{- Privacy conventions}}
{{- Goal and progress tracking}}

---

## Scaling notes

At small scale (<50 pages), `index.md` is sufficient for navigation — the LLM reads it and finds relevant pages by title and summary. At moderate scale (50-200 pages), use qmd for search during ingest and query, but `index.md` is still readable. At large scale (200+ pages), `index.md` becomes too long to read in full — use qmd for all page discovery and treat `index.md` as a human-browsable catalog that the LLM maintains but no longer reads end-to-end. The session start checklist can also be trimmed at scale: skip reading the full index and go straight to qmd.

`log.md` grows indefinitely but only the recent entries matter for session context — reading the last 5-10 entries is always sufficient regardless of wiki size.

---

## Session start checklist

At the start of every session:

1. Read this `SCHEMA.md`
2. Read `index.md` to see current wiki state
3. Read the last 5-10 entries in `log.md` for recent activity
4. Check for unprocessed files in `raw/`:
   ```bash
   _tmp=$(mktemp -d)
   # Files in raw/ (excluding hidden files and assets/)
   find raw/ -maxdepth 1 -type f ! -name '.*' | sort > "$_tmp/raw.txt"
   # Files already ingested (source_file values + prior_versions)
   grep -rh "raw/" wiki/*.md 2>/dev/null | grep -oE '"raw/[^"]*"' | tr -d '"' | sort -u > "$_tmp/ingested.txt"
   # Files excluded via .wikiignore (one per line, # comments, blank lines ignored)
   grep -v '^\s*#' raw/.wikiignore 2>/dev/null | grep -v '^\s*$' | sed 's|^|raw/|' | sort > "$_tmp/ignored.txt"
   # Unprocessed = raw files minus ingested minus ignored
   comm -23 "$_tmp/raw.txt" "$_tmp/ingested.txt" | comm -23 - "$_tmp/ignored.txt"
   rm -rf "$_tmp"
   ```
   If unprocessed files exist, tell the user: "There are N unprocessed files in raw/. Want to ingest them?"
5. If qmd is installed, ensure the collection and context are configured (both commands are idempotent):
   ```bash
   qmd --index {{qmd-collection}} collection add wiki/ --name {{qmd-collection}}
   qmd --index {{qmd-collection}} context add qmd://{{qmd-collection}}/ "{{description of wiki}}"
   ```
6. Ask the human: ingest, query, lint, or explore?
