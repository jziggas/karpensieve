---
name: wiki-ingest
description: >
  Process source documents into the wiki. Run when the user adds files to raw/, asks to
  process or ingest sources, or at session start if unprocessed files are found. Handles
  single sources, batch ingest, and re-ingest of updated sources.
---

# Ingest

Process source documents into the wiki. Creates and updates wiki pages, cross-references, and search index.

## Trigger

User adds files to `raw/`, asks to process/ingest sources, or the session start checklist found unprocessed files. For sources that live in Atlassian rather than on disk (JIRA tickets, Confluence pages), see the **Atlassian fetch** section below — it writes snapshots into `raw/` which then flow through the normal pipeline.

## Atlassian fetch (JIRA, Confluence)

For sources that live in Atlassian rather than on disk. This step fetches via MCP and writes a markdown snapshot to `raw/`; the normal ingest flow processes that snapshot from Step 0 onward. Re-pulls hit Step 1's identifier duplicate check and route through the Re-ingest branch.

### Triggers

- **Explicit per-item** — user says "ingest JIRA PSEG-123" or "ingest confluence <url>". Fetch that one item.
- **Saved queries** — `raw/.atlassian-queries.yaml` holds named JQL/CQL queries. On "refresh atlassian", iterate each query, fetch matching items, write snapshots. Example:
  ```yaml
  jira:
    - name: open-pseg-blockers
      jql: "project = PSEG AND status = Open AND priority = Blocker"
    - name: my-tickets
      jql: "assignee = currentUser() AND resolution = Unresolved"
  confluence:
    - name: eng-space-recent
      cql: "space = ENG AND lastmodified > now('-7d')"
  ```
- **URL paste** — if the user drops a JIRA or Confluence URL into the conversation, offer to pull it.

### MCP tools

- `getJiraIssue` — ticket body, fields, assignee, status, labels. Comments live under `fields.comment.comments[]` when `fields=*all` is requested; otherwise call `fetchAtlassian` on `/rest/api/3/issue/<key>/comment`.
- `getJiraIssueRemoteIssueLinks` — external refs (linked Confluence pages, URLs).
- `searchJiraIssuesUsingJql` — batch discovery by JQL.
- `getConfluencePage` — page body. Confluence bodies come in storage/ADF format. Check the MCP response for an already-markdown representation (`body.atlas_doc_format`, `body.view`); if only ADF/storage is returned, convert to markdown (small Python converter is fine — the goal is readable prose, not perfect fidelity).
- `getConfluencePageFooterComments` + `getConfluencePageInlineComments` — comment threads.
- `getConfluencePageDescendants` — child pages (optional; useful for recursive pulls of a whole subtree).
- `searchConfluenceUsingCql` — batch discovery.
- `fetchAtlassian` — generic REST fallback for endpoints without a dedicated MCP tool, and for attachment binary download.

### Snapshot file layout

**JIRA — `raw/jira-<KEY>.md`:**

```markdown
---
jira_key: "PSEG-123"
url: "https://{{instance}}.atlassian.net/browse/PSEG-123"
jira_status: "In Progress"
assignee: "Jane Doe"
reporter: "John Smith"
priority: "High"
labels: [backend, auth]
created: 2026-03-01
updated: 2026-04-13        # JIRA's updated timestamp — re-ingest signal
fetched: 2026-04-13        # when this snapshot was pulled
---

# [PSEG-123] Ticket summary line

## Description
{{ticket body}}

## Comments

### [2026-03-05 14:22] Jane Doe
{{comment body}}

### [2026-04-10 09:15] John Smith
{{comment body}}

## Linked issues
- PSEG-122 (blocks)
- PSEG-130 (relates to)

## Attachments
- spec.pdf → raw/assets/jira-PSEG-123-attach1.pdf
- screenshot.png → raw/assets/jira-PSEG-123-attach2.png
```

**Confluence — `raw/confluence-<page-id>-<slug>.md`:**

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
{{comment body}}

## Footer comments

### [2026-04-01 10:00] John Smith
{{comment body}}

## Child pages
- [[confluence-789-deployment-plan|Deployment Plan]]
```

### Attachments

Same pattern as email attachments:

1. For each attachment on the ticket/page, download the binary to `raw/assets/jira-<KEY>-attach<n>.<ext>` (JIRA) or `raw/assets/confluence-<id>-attach<n>.<ext>` (Confluence). Use `fetchAtlassian` against `/rest/api/3/attachment/content/<id>` (JIRA) or `/download/attachments/<page-id>/<filename>` (Confluence). If `fetchAtlassian` can't return binary data, fall back to `curl` with the user's Atlassian auth token.
2. Reference each file in the snapshot's `assets:` frontmatter.
3. **Substantive attachments** (PDF, DOCX, XLSX, PPTX) get their own source page with `source_file` pointing at the extracted asset path, wikilinked from the ticket/page source page. This preserves the 1:1 `source_file → source page` mapping.
4. Inline images and screenshots stay as assets on the ticket/page source page — not promoted to their own pages.

### Re-ingest

Re-pulls of an Atlassian source hit Step 1's duplicate check via `url`, `jira_key`, or `confluence_page_id` and route through the Re-ingest branch. For Atlassian sources, frame the log diff around **new comments since last pull** and **status changes** — those are where the signal lives, not raw text diff. JIRA's `updated` timestamp bumps on any field change (including comment add/edit); Confluence's `version` bumps on page edits. Both are reliable "has anything changed" signals; comparing against the prior snapshot gives you the exact new-comment list.

### `source_type` values

Use `jira-issue` for JIRA ticket source pages and `confluence-page` for Confluence page source pages.

---

## Step 0 — Identify unprocessed files

Find files in `raw/` that don't have a corresponding wiki source page and aren't listed in `raw/.wikiignore`.

`.wikiignore` contains filenames (relative to `raw/`, one per line) that were intentionally removed from the wiki — e.g., during lint cleanup or page merges. These are excluded so they don't resurface as "new."

```bash
# List all files in raw/ (excluding hidden files and assets/ subdirectory)
find raw/ -maxdepth 1 -type f ! -name '.*'

# List all source_file values from existing wiki source pages
grep -rh "^source_file:" wiki/*.md 2>/dev/null | sed 's/source_file: *"//;s/"$//'

# Also check prior_versions for re-ingested files
grep -rh "raw/" wiki/*.md 2>/dev/null | grep -oE '"raw/[^"]*"' | tr -d '"' | sort -u

# Also exclude files listed in raw/.wikiignore (one per line, # comments, blank lines ignored)
grep -v '^\s*#' raw/.wikiignore 2>/dev/null | grep -v '^\s*$'
```

The unprocessed set is: files in `raw/` MINUS already-ingested files MINUS `.wikiignore` entries. Present to the user:

- **1 file:** "There's 1 unprocessed file in raw/: `new-article.md`. Process it?"
- **Multiple files:** "There are 4 unprocessed files in raw/: `file1.md`, `file2.pdf`, `data.csv`, `report.docx`. Process all, pick specific ones, or skip?"
- **None:** "All files in raw/ have been processed." Continue to query, lint, or explore.

If the user specifies a file directly ("process report.pdf"), skip the scan and go straight to that file.

---

## Single-source ingest

For one file, or when processing multiple files one at a time:

### 1. Check for URL duplicate

Extract a URL from the source:
- **Markdown:** check YAML frontmatter for `source`, `url`, or `link` (Web Clipper saves these)
- **HTML:** parse `<meta>` tags — `og:url`, `canonical`, `<link rel="canonical">`
- **PDF:** check PDF metadata (title, author) — less reliable
- **Email (.eml):** use the `Message-ID` header as the duplicate key. Fall back to `Subject` + `From` + `Date` composite if absent. Matched against `message_id` frontmatter, not `url`
- **Atlassian snapshots (`raw/jira-*.md`, `raw/confluence-*.md`):** match on `jira_key` or `confluence_page_id` frontmatter; fall back to `url`. Atlassian snapshots always have a stable identifier, so every re-pull reliably routes into Re-ingest
- **Other formats:** no URL expected

If a URL was found, search existing source pages for a match:
```bash
grep -rl "url:" wiki/*.md | xargs grep -l "<the-url>" 2>/dev/null
```

If a match exists → this is a **re-ingest**. Jump to the Re-ingest section below.

### 2. Read the source

Strategy by file type:

| Type | Method | Notes |
|------|--------|-------|
| `.md`, `.txt` | Read directly | If image refs exist (`![[]]`, `![]()`), read text first, then view referenced images in `raw/assets/` for visual context (charts, diagrams, screenshots). Also scan for embedded ```mermaid fences and apply the Mermaid treatment below to each |
| `raw/jira-*.md`, `raw/confluence-*.md` | Read directly as markdown | Snapshots produced by the Atlassian fetch step. Frontmatter carries `jira_key` / `confluence_page_id` / `url` for duplicate detection. Body is description (or page content) + comments thread + attachment refs. Treat comments as first-class content during summarization — they often carry more signal than the description |
| `.mmd`, `.mermaid` | Read directly as text | Parse nodes and edges from Mermaid syntax. Extract each named node as a candidate entity/concept page; each edge as a cross-reference with the edge label as the relationship semantic (e.g. "calls", "depends on", "triggers"). Embed the diagram verbatim inside a ```mermaid fence on the source page so Obsidian renders it natively. Per diagram type: `graph`/`flowchart` → process steps and directional links; `sequenceDiagram` → actors + messages (good for auth flows, API traces); `classDiagram` → classes with inheritance/composition; **`erDiagram` → each entity maps 1:1 to an entity page, cardinality becomes the connection semantic**; `stateDiagram` → states + transitions; `C4` → systems/containers/components at their level |
| `.html` | `BeautifulSoup` | Extract text, `<meta>` tags (author, date), image refs |
| `.csv`, `.tsv` | `csv.DictReader` | Note columns, row count, key patterns |
| `.xlsx` | `openpyxl` | Read all sheets — data sheets AND notes/methodology sheets |
| `.pptx` | `python-pptx` | Iterate `prs.slides` preserving slide order — decks are narratives. Per slide capture: title (`slide.shapes.title.text`), body text and bullets (`shape.text_frame.paragraphs` with indent level), tables (`shape.table.rows` → `cell.text`; wide tables >5 cols or >20 rows also save rows as CSV to `raw/assets/{{slug}}-slide{{n}}-tbl{{m}}.csv`), embedded images (picture shapes → `shape.image.blob` → `raw/assets/{{slug}}-slide{{n}}-fig{{m}}.{{ext}}`; view each, keep charts/diagrams, skip decorative), and **speaker notes** (`slide.notes_slide.notes_text_frame.text` — often the most valuable content on the slide). Structure the wiki source page with `### Slide N — Title` subsections under `## Details`, body, `**Speaker notes:**` line, and inline image embeds — preserves the deck flow rather than collapsing it to a wall of text. Google Slides: export via `File → Download → Microsoft PowerPoint (.pptx)`. Keynote: export to .pptx first. |
| `.docx` (text) | `python-docx` | Iterate `doc.paragraphs` for headings + body text and bullet lists. Note: this skips table cells — see next row |
| `.docx` (tables) | `python-docx` `doc.tables` | Iterate `table.rows` → `row.cells`. Emit as markdown tables in the source summary. For wide or data-dense tables (>5 cols or >20 rows), also save rows as CSV to `raw/assets/{{slug}}-tbl{{n}}.csv` and link via `assets` frontmatter (mirrors the pdfplumber pattern in the `.pdf` (tables) row). Watch for merged cells — python-docx repeats the same cell object across spans, producing duplicate text in adjacent cells |
| `.docx` (forms + images) | `docx.oxml` + `doc.part.related_parts` | Best-effort form-control scan: walk `doc.element.body.iter()` for `w:checkBox` (legacy, with `w:default`/`w:checked` state), `w:ffData`, and `w:sdt` (content controls — check descendants for local names `checkbox` or `dropDownList`). Capture nearest paragraph text as the control's label. For embedded images, iterate `doc.part.related_parts.values()` filtered on `content_type.startswith("image/")` and save substantive ones to `raw/assets/{{slug}}-fig{{n}}.{{ext}}`. If the doc visually contains form controls but oxml finds none (likely ActiveX OLE radio groups), fall back to `libreoffice --headless --convert-to pdf` and apply the `.pdf` (fillable form) row's rasterize approach |
| `.pdf` (text) | `pdfminer` | Extract text. If output is mostly whitespace or garbage, treat as scanned → next row |
| `.pdf` (scanned) | `pymupdf` (`fitz`) rasterize | Render each page to an image and read it visually |
| `.pdf` (fillable form) | `pymupdf.page.widgets()` | If `doc.is_form_pdf`, iterate widgets per page and capture `field_type_string`, `field_name`, `field_value`. Radios/checkboxes give checked/unchecked state; text fields give the filled value. If the PDF is flattened (no widgets but form visuals present), fall back to rasterization |
| `.pdf` (tables) | `pdfplumber.extract_tables()` | For structured tables, save rows as CSV to `raw/assets/{{slug}}-p{{page}}-tbl{{n}}.csv` and link from the source page's `assets` frontmatter. If `pdfplumber` is unavailable, rasterize the page and read the table visually |
| `.pdf` (images) | `pymupdf` (`fitz`) | Extract embedded images → `raw/assets/{{slug}}-p{{page}}-fig{{n}}.png`. View each, keep substantive ones (charts, diagrams), skip decorative (logos, headers) |

For short PDFs (≤20 pages), Claude Code's native `Read` with `pages:` is a quick alternative — it renders pages via poppler (`pdftoppm`) and captures visual state including drawn radio/checkbox marks. Use it when you want a fast visual read without shelling out to Python.
| `.png`, `.jpg` | View directly | Usually an asset for another source — link via `assets` frontmatter |
| `.eml` (headers + body) | `email.message_from_bytes()` (stdlib) | Parse MIME tree. Capture headers: `From`, `To`, `Cc`, `Date`, `Subject`, `Message-ID`, `In-Reply-To`, `References`. For body, iterate `msg.walk()` and prefer `text/plain`; if only `text/html`, strip tags via BeautifulSoup. Trim quoted reply chains (`>`-prefixed lines, `On ... wrote:` blocks) when they dominate — note the trimming in the summary |
| `.eml` (attachments) | `msg.walk()` + `get_content_disposition() == "attachment"` | Save each attachment to `raw/assets/{{slug}}-attach{{n}}.{{ext}}` using a sanitized `get_filename()`. Reference in `assets` frontmatter. **If the attachment is itself a substantive source (PDF, DOCX, XLSX, PPTX), create a separate source page for it** with `source_file` pointing to the extracted asset path, and wikilink it from the email's source page — this preserves the 1:1 `source_file → page` mapping |
| `.eml` (inline images) | `msg.walk()` + `get_content_disposition() == "inline"` (Content-ID parts) | Save to `raw/assets/{{slug}}-fig{{n}}.{{ext}}`. View each; keep substantive (screenshots, diagrams pasted into the body), skip decorative (signature logos). Reference in `assets` frontmatter |

### 3. Discuss key takeaways

Summarize 3-5 key takeaways. Ask:
- What to emphasize?
- Specific entities or concepts to focus on?
- Connections to existing content?

Skip if the user says batch mode, silent, or just process it.

### 4. Create the source summary page

Create `wiki/{{source-slug}}.md`. Read `page-templates.md` for the source page template. Critical frontmatter fields:
- `url` — **always include if available** — this is how re-clip detection works
- `message_id` — for email sources, mirrors `url`'s role in duplicate detection on re-ingest
- `source_file` — path to the raw file (this is how unprocessed file detection works)
- `assets` — list of associated images/files in `raw/assets/`

### 5. Create or update entity and concept pages

For each significant entity or concept:
- **Page exists?** Add new info, append source to `sources` list, update `updated` date
- **New?** Create using the template from `page-templates.md`. Frame as a starting point — it will grow

### 6. Find related pages with qmd

Extract 3-5 key claims, entities, or terms from the source.

**If qmd MCP is available:** use the `query` tool directly.

**CLI fallback:**
```bash
qmd --index {{qmd-collection}} search "term" --json -c {{qmd-collection}}                  # BM25 keyword search
qmd --index {{qmd-collection}} vsearch "broader concept" --json -c {{qmd-collection}}      # semantic vector search
qmd --index {{qmd-collection}} query "full question" --json -c {{qmd-collection}}           # hybrid + reranking, best quality
```

**If qmd is not installed:** read `index.md`, identify relevant pages by title and summary.

For each related page found: add wikilinks in both directions where meaningful. **Use Obsidian's pipe format `[[file-slug|Display Text]]`** — bare `[[Display Text]]` doesn't resolve via aliases and creates empty stub files when clicked. If new info updates or contradicts existing content, edit the existing page.

### 7. Check for contradictions

If the new source contradicts an existing claim:
```markdown
> [!warning] Contradiction
> [[source-a|Source A]] claims X, but [[source-b|Source B]] claims Y.
```
Never silently overwrite. Contradictions are signal.

### 8. Update index.md

Add rows for all new pages. Update summaries for substantially modified pages.

### 9. Update log.md

Every source gets its own log entry — even in batch mode. This is provenance. If a claim needs tracing later, you need to know exactly which source introduced it.

```markdown
## [YYYY-MM-DD] ingest | {{Source Title}}

- Source: `raw/{{filename}}`
- Pages created: [[page-a|Page A]], [[page-b|Page B]]
- Pages updated: [[page-c|Page C]], [[page-d|Page D]]
- Notes: {{what was notable}}
```

### 10. Update search index

```bash
qmd --index {{qmd-collection}} update && qmd --index {{qmd-collection}} embed
```
Skip if qmd is not installed. In batch mode, defer this to after the last source — run once at the end.

---

## Batch ingest

When processing multiple unprocessed files at once:

### Overview phase

1. Run step 0 to identify all unprocessed files
2. Read all of them (step 2 for each)
3. Present a **single batch overview** to the user: "Here are the 6 new sources. They cover X, Y, Z. Key themes: A, B, C. Any direction before I process?" This replaces step 3 (discuss) for individual files — the user gives high-level guidance once instead of per-file conversation
4. The user can give direction ("emphasize the policy angle", "skip the CSV for now") or say "go ahead"

### Processing phase

For each source, run steps 1, 4-9 sequentially. Each source gets:
- Its own source summary page
- Its own entity/concept page updates
- Its own cross-reference pass (later sources benefit from pages created by earlier ones)
- Its own index update
- **Its own log entry** — never batch these

### Finalize

After all sources are processed:
- Run `qmd --index {{qmd-collection}} update && qmd --index {{qmd-collection}} embed` once
- Check whether the batch meaningfully expanded the wiki's scope:
  ```bash
  qmd --index {{qmd-collection}} context list
  ```
  If the current context description no longer reflects the wiki's full coverage (e.g., the batch introduced a new topic area), propose an updated context string to the user. On approval:
  ```bash
  qmd --index {{qmd-collection}} context add qmd://{{qmd-collection}}/ "updated description"
  ```
- Optionally suggest a lint pass — batch ingests often surface new connections worth checking

---

## Re-ingest

When step 1 finds a URL match — the source has been updated since last ingest.

1. **Diff** the old and new raw files. Identify changed sections, updated claims, new data. For Atlassian snapshots, focus the diff narrative on **new comments since the last pull** and **status changes** — those are the useful signal, not raw text diff. JIRA's `updated` timestamp bumps on any field or comment change; Confluence's `version` bumps on page edits. Comparing old snapshot comments against new ones yields the exact new-comment list.
2. **Update** the existing source summary (don't create a duplicate). Add:
   ```markdown
   > [!info] Updated YYYY-MM-DD
   > Re-ingested from updated source. Changes: {{description}}.
   ```
   Update `source_file` to the new version. Add old file to `prior_versions`:
   ```yaml
   source_file: "raw/{{new-filename}}"
   prior_versions:
     - "raw/{{old-filename}}"
   ```
3. **Trace outward.** Which entity/concept pages cite claims from this source? For each:
   - If the cited claim changed → update the page
   - If a `[!warning] Contradiction` has been resolved → update or remove the callout
   - If new claims introduce new entities/concepts → create pages
4. **Log** with `re-ingest` prefix:
   ```markdown
   ## [YYYY-MM-DD] re-ingest | {{Source Title}} (updated)

   - Source: `raw/{{new-file}}` (prior: `raw/{{old-file}}`)
   - Changes: {{description}}
   - Pages updated: [[page-a|Page A]], [[page-b|Page B]]
   ```
5. Update index if page summaries changed.
6. Run `qmd --index {{qmd-collection}} update && qmd --index {{qmd-collection}} embed` (or defer if in batch mode).
