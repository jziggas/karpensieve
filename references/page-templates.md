# Page Templates

Templates for each wiki page type. All pages live in `wiki/` (flat) except meta pages in `wiki/meta/`.
Adapt as needed — these are defaults. The wiki's `SCHEMA.md` takes priority.

> **Wikilink format:** Always use Obsidian's pipe format `[[file-slug|Display Text]]`. Bare `[[Display Text]]` does not resolve via aliases; it creates an empty stub file when clicked. The `file-slug` is the kebab-case filename (without `.md`).

---

## Source page

File: `wiki/{{source-slug}}.md`

```markdown
---
title: "{{Source Title}}"
type: source
source_type: {{article | paper | transcript | book | report | note | data | other}}
author: "{{Author Name}}"
date: {{YYYY-MM-DD}}
url: "{{URL if applicable — critical for re-clip detection}}"
source_file: "raw/{{filename}}"
prior_versions: []              # populated on re-ingest: ["raw/old-filename.md"]
assets:                         # images extracted from or associated with this source
  - "raw/assets/{{image-or-file}}"
aliases:                        # for Quick Switcher and autocomplete; does NOT affect wikilink resolution. Include the title plus abbreviations/alternate names
  - "{{Source Title}}"
created: {{YYYY-MM-DD}}
updated: {{YYYY-MM-DD}}
tags:
  - {{tag}}
---

# {{Source Title}}

## Overview

{{2-3 sentence summary of what this source is and why it matters.}}

## Key claims

- {{Claim 1}} → relates to [[concept-page|Concept Page]] and [[entity-page|Entity Page]]
- {{Claim 2}} → updates understanding of [[another-page|Another Page]]
- {{Claim 3}}

## Details

{{Structured summary. Not a wall of text — use subsections if the source is long.
Focus on what's novel, actionable, or relevant to the wiki's domain.}}

## Entities mentioned

- [[entity-a|Entity A]] — {{brief context}}
- [[entity-b|Entity B]] — {{brief context}}

## Connections

- Supports: [[page-that-this-strengthens|Page that this strengthens]]
- Challenges: [[page-that-this-complicates|Page that this complicates]]
- Related: [[page-with-tangential-connection|Page with tangential connection]]
```

---

## Source page — JIRA ticket

File: `wiki/jira-{{key-lower}}.md` (where `{{key-lower}}` is e.g. `proj-123`). Raw snapshot lives at `raw/jira-{{KEY}}.md` and carries the same identifier.

```markdown
---
title: "[{{KEY}}] {{Ticket Summary}}"
type: source
source_type: jira-issue
jira_key: "{{KEY}}"
jira_status: "{{current status at snapshot time}}"
author: "{{Reporter}}"
date: {{YYYY-MM-DD}}            # ticket creation date
url: "https://{{instance}}.atlassian.net/browse/{{KEY}}"
source_file: "raw/jira-{{KEY}}.md"
prior_versions: []              # populated on re-ingest
assets:
  - "raw/assets/jira-{{KEY}}-attach1.pdf"
aliases:
  - "{{KEY}}"
  - "{{Ticket Summary}}"
created: {{YYYY-MM-DD}}
updated: {{YYYY-MM-DD}}         # when this wiki page was last updated
tags:
  - jira
  - {{project-tag}}
---

# [{{KEY}}] {{Ticket Summary}}

## Overview

{{2-3 sentences: what this ticket is about and what's currently happening.}}

## Current status

- **Status:** {{In Progress / Done / Blocked / etc.}}
- **Assignee:** {{name}}
- **Priority:** {{High / Medium / Low}}
- **Latest activity:** {{summary of most recent comment or status change}}

## Key claims from description and comments

- {{Claim from description}} → relates to [[concept-page|Concept Page]]
- {{Claim or decision from a comment}} ({{author, date}})
- {{Blocker or scope change surfaced in comments}}

## Thread summary

{{Narrative walk through the comment timeline — who said what, when, what was decided.}}

## Linked tickets

- [[jira-proj-122|PROJ-122]] — blocks
- [[jira-proj-130|PROJ-130]] — relates to

## Attached substantive sources

- [[{{filename-slug}}|{{Attachment Title}}]] — {{brief context, e.g. "design spec referenced in ticket"}}

## Connections

- Entities: [[entity-a|Entity A]]
- Concepts: [[concept-a|Concept A]]

## Sources

- Raw snapshot: `raw/jira-{{KEY}}.md`
```

---

## Source page — Confluence page

File: `wiki/confluence-{{page-id}}-{{slug}}.md`. Raw snapshot lives at `raw/confluence-{{page-id}}-{{slug}}.md`.

```markdown
---
title: "{{Page Title}}"
type: source
source_type: confluence-page
confluence_page_id: "{{id}}"
confluence_space: "{{SPACE}}"
confluence_version: {{n}}
author: "{{Author}}"
date: {{YYYY-MM-DD}}            # page creation date
url: "https://{{instance}}.atlassian.net/wiki/spaces/{{SPACE}}/pages/{{id}}/{{Page+Title}}"
source_file: "raw/confluence-{{id}}-{{slug}}.md"
prior_versions: []
assets:
  - "raw/assets/confluence-{{id}}-attach1.png"
aliases:
  - "{{Page Title}}"
created: {{YYYY-MM-DD}}
updated: {{YYYY-MM-DD}}
tags:
  - confluence
  - {{space-tag}}
---

# {{Page Title}}

## Overview

{{2-3 sentences: what this page documents and why it matters.}}

## Key claims

- {{Claim from page body}} → [[concept-a|Concept A]]
- {{Decision or clarification from inline/footer comments}} ({{commenter, date}})

## Details

{{Structured summary of the page content, referencing any diagrams in `assets/`.}}

## Comment thread summary

{{Narrative of inline + footer comments — what was questioned, answered, decided.}}

## Child / related pages

- [[confluence-789-deployment-plan|Deployment Plan]]

## Connections

- Entities: [[entity-a|Entity A]]
- Concepts: [[concept-a|Concept A]]

## Sources

- Raw snapshot: `raw/confluence-{{id}}-{{slug}}.md`
```

---

## Entity page

File: `wiki/{{entity-slug}}.md`

```markdown
---
title: "{{Entity Name}}"
type: entity
entity_type: {{person | organization | product | place | dataset | tool}}
created: {{YYYY-MM-DD}}
updated: {{YYYY-MM-DD}}
aliases:                        # for Quick Switcher and autocomplete; does NOT affect wikilink resolution. Include the title plus abbreviations/alternate names
  - "{{Entity Name}}"
  - {{Alternate name}}
tags:
  - {{tag}}
sources:
  - "[[source-page-one|Source Page One]]"
---

# {{Entity Name}}

## Overview

{{2-3 sentences: what this entity is and why it matters to the wiki.}}

## Key facts

- {{Fact 1}} ([[source-a|Source A]])
- {{Fact 2}} ([[source-b|Source B]])

## Role in the domain

{{How this entity connects to the wiki's central topic.}}

## Connections

- Related entities: [[entity-x|Entity X]], [[entity-y|Entity Y]]
- Related concepts: [[concept-a|Concept A]], [[concept-b|Concept B]]

## Sources

- [[source-page-one|Source Page One]]
- [[source-page-two|Source Page Two]]
```

---

## Concept page

File: `wiki/{{concept-slug}}.md`

```markdown
---
title: "{{Concept Name}}"
type: concept
created: {{YYYY-MM-DD}}
updated: {{YYYY-MM-DD}}
aliases:                        # for Quick Switcher and autocomplete; does NOT affect wikilink resolution. Include the title plus abbreviations/alternate names
  - "{{Concept Name}}"
  - {{Alternate name}}
confidence: {{high | medium | low | speculative}}
tags:
  - {{tag}}
sources:
  - "[[source-page-one|Source Page One]]"
---

# {{Concept Name}}

## Overview

{{2-3 sentence definition. What is this and why does it matter?}}

## Details

{{Deeper explanation. Use ### subsections for distinct aspects.}}

## Evidence and perspectives

{{What do sources say? Where do they agree or disagree?}}

> [!warning] Contradiction
> {{If applicable: Source A claims X, but Source B claims Y.}}

## Open questions

> [!question] Open question
> {{Something not yet resolved by the sources.}}

## Connections

- Related concepts: [[concept-x|Concept X]], [[concept-y|Concept Y]]
- Key entities: [[entity-a|Entity A]], [[entity-b|Entity B]]

## Sources

- [[source-page-one|Source Page One]]
```

---

## Analysis page

File: `wiki/{{analysis-slug}}.md`

```markdown
---
title: "{{Analysis Title}}"
type: analysis
created: {{YYYY-MM-DD}}
updated: {{YYYY-MM-DD}}
aliases:                        # for Quick Switcher and autocomplete; does NOT affect wikilink resolution. Include the title plus abbreviations/alternate names
  - "{{Analysis Title}}"
tags:
  - {{tag}}
sources:
  - "[[source-page-one|Source Page One]]"
  - "[[source-page-two|Source Page Two]]"
---

# {{Analysis Title}}

## Question

{{What prompted this analysis?}}

## Summary

{{2-3 sentence answer.}}

## Analysis

{{The full analysis. Cite wiki pages with `[[file-slug|Display Text]]` wikilinks throughout.}}

## Conclusions

{{What was learned? What to investigate next?}}

## Connections

- Draws on: [[page-a|Page A]], [[page-b|Page B]]
- Implications for: [[page-c|Page C]], [[page-d|Page D]]
```

---

## Meta: Overview

File: `wiki/meta/overview.md`

```markdown
---
title: "Wiki Overview"
type: meta
created: {{YYYY-MM-DD}}
updated: {{YYYY-MM-DD}}
aliases:                        # for Quick Switcher and autocomplete; does NOT affect wikilink resolution. Include the title plus abbreviations/alternate names
  - "Wiki Overview"
  - "{{Wiki Name}} — Overview"
tags:
  - meta
---

# {{Wiki Name}} — Overview

## Purpose

{{What is this wiki about?}}

## Current state

- **Sources ingested:** {{count}}
- **Wiki pages:** {{count}}
- **Last updated:** {{date}}

## Key findings so far

1. {{Finding}} — see [[some-page|Some Page]]

## Evolving thesis

{{The emerging picture. Revised as new sources arrive.}}

## Open questions

See [[open-questions|Open Questions]].

## Reading list

- {{Source to acquire}}
```

---

## Meta: Open Questions

File: `wiki/meta/open-questions.md`

```markdown
---
title: "Open Questions"
type: meta
created: {{YYYY-MM-DD}}
updated: {{YYYY-MM-DD}}
aliases:                        # for Quick Switcher and autocomplete; does NOT affect wikilink resolution. Include the title plus abbreviations/alternate names
  - "Open Questions"
tags:
  - meta
  - questions
---

# Open Questions

Updated during ingest and lint passes.

## High priority

- [ ] {{Question}} — context: [[some-page|Some Page]]

## Medium priority

- [ ] {{Question}}

## Resolved

- [x] {{Question}} — answered by [[source-page|Source Page]] on {{date}}
```

---

## Index

File: `index.md` (wiki root)

```markdown
---
title: "Index"
type: meta
updated: {{YYYY-MM-DD}}
---

# {{Wiki Name}} — Index

## Sources

| Page | Summary | Date |
|------|---------|------|

## Entities

| Page | Entity type | Summary |
|------|-------------|---------|

## Concepts

| Page | Summary | Confidence |
|------|---------|------------|

## Analyses

| Page | Summary | Date |
|------|---------|------|

## Meta

| Page | Summary |
|------|---------|
| [[overview|Wiki Overview]] | High-level overview and evolving thesis |
| [[open-questions|Open Questions]] | Tracked questions and gaps |
```

---

## Log

File: `log.md` (wiki root)

```markdown
---
title: "Log"
type: meta
---

# {{Wiki Name}} — Log

Chronological record. Newest at bottom.
Format: `## [YYYY-MM-DD] operation | title`

<!-- Append new entries below this line -->
```

---

## Notes

- **Always adapt.** Templates are starting points. Reshape as needed.
- **Progressive enrichment.** Thin pages are fine — they grow as more sources arrive.
- **Links are king.** The Connections section is the most valuable part of any page. Always write wikilinks in pipe format `[[file-slug|Display Text]]` so they resolve correctly in Obsidian.
- **Frontmatter is queryable.** Consistent YAML = powerful Dataview queries.
