---
name: wiki-lint
description: >
  Interactive health check of the wiki. Scans for dead links, orphan pages, thin pages,
  contradictions, stale content, and other issues, then walks through each finding with the
  user to decide how to resolve it. Run when the user asks to lint, health-check, clean up,
  or maintain the wiki.
---

# Lint

Interactive health check of the wiki. Scans for issues, then walks through each finding with the user to decide how to resolve it.

## Trigger

User asks to lint, health-check, clean up, or maintain the wiki.

## Workflow

### 1. Run all checks

From the wiki root, run the canonical scanner:

```bash
python .claude/skills/wiki-lint/scan.py
```

To re-run a single category after a fix:

```bash
python .claude/skills/wiki-lint/scan.py --check dead-links
# available: dead-links, bare-wikilinks, image-refs, orphans, shadow-files,
# thin, stale-title-alias, tags, missing, contradictions, index-drift, inbound
```

The script emits one `=== SECTION ===` per check to stdout and always exits 0 (it's a report tool, not a CI gate). Parse the sections to populate the Step 2 summary table.

#### Preprocessing rules the scanner applies

These fix three false-positive classes that an earlier grep-based scanner produced. Preserve them if you ever rewrite the scanner:

- **Code fences (` ``` … ``` `, `~~~ … ~~~`) and inline backtick spans are stripped** before regex extraction. Obsidian does not render wikilinks inside code, so literal `[[…]]` examples in documentation prose should not be flagged.
- **HTML comments (`<!-- … -->`, multiline) are stripped** for the same reason.
- **Markdown table-cell pipe escapes (`\|`) are un-escaped to `|`** before extracting the slug from `[[slug|Display]]`. A table cell with `[[paymentus\|Paymentus]]` renders as a piped wikilink to `paymentus` in Obsidian — not a dead link to `paymentus\`.
- **The slug resolution map includes root-level `*.md` files** (`index.md`, `log.md`, `SCHEMA.md`, `page-templates.md`), so wikilinks like `[[index|Index]]` resolve correctly.

#### Checks performed

**Dead links** — piped wikilinks `[[slug|Display]]` whose `slug` has no matching file in `wiki/`, `wiki/meta/`, or the wiki root.

**Bare wikilink format** — `[[Text]]` without a pipe (excluding image embeds `![[...]]`). These don't resolve via aliases in Obsidian — clicking them creates an empty stub file. Each should be rewritten to `[[file-slug|Display Text]]`.

**Title-case shadow files** — files in `wiki/` whose names start with a capital letter or contain spaces. These are typically empty stubs auto-created by Obsidian from bare wikilinks. Verify they're 0 bytes (or short and unintentional), then delete after the inbound bare wikilinks have been rewritten to pipe format.

**Missing pages** — count wikilink slug targets across all pages. Any slug mentioned 2+ times without a corresponding file is a candidate for new page creation.

**Orphan pages** — for each wiki page, search for its slug across all other pages. Pages with zero inbound links (no `[[their-slug|...]]` references) are orphans. (Root-level files like `index.md`/`log.md` are not expected to have inbound wikilinks and are skipped.)

**Dead image refs** — check `![[image.png]]` references. Verify each image exists in `raw/assets/`, `raw/`, or the referenced path.

**Thin pages** — pages in `wiki/` (excluding `wiki/meta/`) with fewer than ~100 words of body content (excluding frontmatter).

**Stale pages** — compare each page's `updated` date against the dates of sources that mention the same entities or concepts. If newer sources exist but the page hasn't been updated, it's stale. *(Not automated by the scanner — inspect `updated` dates against source dates manually when needed.)*

**Unresolved contradictions** — lines containing `[!warning]` callouts across all pages.

**Under-connected pages** — if qmd is available, search for each page's key terms. If semantically related pages exist but don't link to each other, flag the missing connection. *(Not automated by the scanner — use qmd manually for this check.)*

**Index drift** — content files in `wiki/` (non-meta) not referenced by a piped wikilink in `index.md`.

**Tag inconsistency** — collect all tags into an inventory (sorted, with counts). Review the list for near-duplicates (e.g., `ai-safety` vs `ai_safety` vs `safety`).

**Stale title alias** — for each page, check whether the `title` frontmatter value appears in the `aliases` list. Helpful for Quick Switcher and autocomplete (so users typing `[[Title` get the suggestion), but **not** required for wikilink resolution — that is handled by the pipe format `[[file-slug|Display]]` and exact filename match.

### 2. Present summary

Show the user a summary table:

| Check | Found | Status |
|-------|-------|--------|
| Dead links | 3 | ⚠ |
| Missing pages | 2 | ⚠ |
| Orphans | 0 | ✓ |
| Thin pages | 5 | △ |
| Contradictions | 1 | ⚠ |
| ... | ... | ... |

### 3. Walk through findings interactively

Go through each category with findings. For each issue, present it and offer resolution options. **Do not batch-fix everything silently.** The user decides.

#### Dead links

For each broken slug in a piped wikilink:
- "[[deepmind|DeepMind]] is linked from 3 pages but `wiki/deepmind.md` doesn't exist. Should I **create** a stub page from what the sources mention, **remove** the wikilinks, or **skip** for now?"

#### Bare wikilinks

For each `[[Display Text]]` without a pipe:
- "Found 4 bare wikilinks like `[[Service Level Metrics]]` in `pseg-caused-delays-and-relief.md`. These will create empty stub files when clicked. Should I **rewrite** them all to `[[file-slug|Display Text]]` (auto-detecting the slug from the title→filename map), **list** them so you can review, or **skip**?"

#### Title-case shadow files

For empty title-case files in `wiki/`:
- "Found `wiki/Service Level Metrics.md` (0 bytes), likely an Obsidian-created stub from a broken bare wikilink. Should I **delete** it (after confirming inbound bare wikilinks have been rewritten) or **skip**?"

#### Missing pages

For entities/concepts mentioned frequently without a page:
- "The term 'frontier models' appears in 7 pages but has no dedicated page. Should I **create** one by pulling together what the sources say, or **skip**?"

#### Orphan pages

For pages with no inbound links:
- "[[old-analysis-page|Old Analysis Page]] has no pages linking to it. Should I **search** for pages that should link here, **merge** its content into a related page, or **skip**?"

#### Thin pages

For pages under ~100 words:
- "[[yuntao-bai|Yuntao Bai]] has 38 words from one source. Should I **search** for more information to expand it, **merge** it into the [[anthropic|Anthropic]] page, or **leave** it to grow naturally?"

#### Stale pages

For pages not updated despite newer sources on the same topic:
- "[[alignment-tax|Alignment Tax]] was last updated 2026-04-12 but [[post-rlhf-alignment-rodriguez-2026|Post-RLHF Alignment (Rodriguez 2026)]] has newer info. Should I **update** the page with the new evidence, or **skip**?"

#### Contradictions

For unresolved `[!warning]` callouts:
- "The contradiction on [[debate|Debate]] (Irving vs Leike on debate effectiveness) has been open since April. Should I **search** for newer sources that might resolve it, **leave** it as unresolved, or **note** it on [[open-questions|Open Questions]]?"

#### Under-connected pages

For pages that should cross-reference but don't:
- "[[process-reward-models|Process Reward Models]] and [[reward-hacking|Reward Hacking]] both discuss reward model robustness but don't link to each other. Should I **add cross-references** in both directions?"

#### Index drift

For files not in the index or index entries without files:
- "[[new-page|New Page]] exists on disk but isn't in index.md. Should I **add** it?"

#### Tag inconsistency

For near-duplicate tags:
- "Found tags `ai-safety` (4 pages) and `safety` (3 pages). Should I **merge** them under one name?"

#### Stale title alias

For pages where the title is not in the aliases list:
- "`project-milestones-and-schedule.md` has title 'Project Milestones and Schedule' but it's not in aliases — Quick Switcher and `[[autocomplete]]` won't surface it from the title. Should I **add** it?"

### 4. Apply fixes

After walking through all findings, apply the user's decisions:
- Create/update/merge pages as directed
- When a wiki source page is **deleted** (not merged — merged pages retain the `source_file` reference), append the associated raw filename to `raw/.wikiignore` to prevent the raw file from resurfacing as unprocessed:
  ```bash
  echo "filename.md" >> raw/.wikiignore
  ```
  This applies during orphan resolution, thin page cleanup, or any other action that removes a source page.
- Update `index.md` with any changes
- Run `qmd --index {{qmd-collection}} update && qmd --index {{qmd-collection}} embed` if pages were modified
- If any pages were **deleted or merged**, run `qmd --index {{qmd-collection}} update && qmd --index {{qmd-collection}} cleanup && qmd --index {{qmd-collection}} embed` instead — `cleanup` removes ghost entries from the vector index for files that no longer exist on disk. This is not needed during ingest, which only adds or modifies pages.

### 5. File the report and log

Create `wiki/meta/lint-report-YYYY-MM-DD.md` summarizing what was found and what was fixed.

Log it:
```markdown
## [YYYY-MM-DD] lint | Health check

- Issues found: {{count}}
- Fixed: {{count}}
- Deferred: {{count}}
- Pages created: [[page-a|Page A]]
- Pages updated: [[page-b|Page B]], [[page-c|Page C]]
- Notes: {{summary of what was resolved}}
```

### 6. Suggest next actions

After lint, suggest:
- Sources to look for (to fill gaps found during lint)
- Questions to investigate (from open questions or contradictions)
- Pages to revisit (stale or thin pages that need more sources)
