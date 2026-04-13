---
name: wiki-query
description: >
  Answer questions from the wiki. Search for relevant pages, synthesize an answer with
  citations, and optionally file the result as a new wiki page. Run when the user asks a
  question about the wiki's domain or asks to search, find, or look up something.
---

# Query

Answer questions from the wiki. Search for relevant pages, synthesize an answer with citations, and optionally file the result as a new wiki page.

## Trigger

User asks a question about the wiki's domain, or asks to search/find/look up something.

## Workflow

### 1. Search for relevant pages

**If qmd MCP is available:** use the `query` tool with the user's question. This gives hybrid BM25 + vector + reranking — best quality results.

**CLI fallback:**
```bash
# Start with hybrid search for best results
qmd --index {{qmd-collection}} query "user's question" --json -c {{qmd-collection}} -n 10

# If results are sparse, try semantic vector search or keyword search with different terms
qmd --index {{qmd-collection}} vsearch "conceptual rephrasing" --json -c {{qmd-collection}}
qmd --index {{qmd-collection}} search "key term" --json -c {{qmd-collection}}

# Retrieve full content of promising results
qmd --index {{qmd-collection}} get "wiki/page-name.md"
```

**If qmd is not installed:** read `index.md`. Scan the page titles and summaries for relevance. Read promising pages directly.

### 2. Read and synthesize

Read the top results. Synthesize an answer that:
- **Cites wiki pages** with pipe-format wikilinks throughout — not just at the end. Format: `[[file-slug|Display Text]]` (e.g. `[[service-level-metrics|Service Level Metrics]]`). Bare `[[Display Text]]` doesn't resolve and creates empty stubs.
- **Follows the evidence** — don't generalize beyond what the sources say
- **Notes confidence** — if the answer draws on high-confidence pages, say so; if it's speculative, flag it
- **Notes gaps** — if the wiki doesn't have enough to fully answer, say what's missing and what sources might fill the gap

### 3. Suggest follow-ups

After answering, consider:
- Are there related questions the user might want to explore?
- Did the search reveal under-connected pages that should be cross-referenced?
- Are there open questions on the [[open-questions|Open Questions]] page that this answer informs?

### 4. Offer to file the result

If the answer is substantive — a comparison, analysis, synthesis, or anything the user might want to reference later — offer to file it as a wiki page:

"This comparison might be worth keeping. Want me to file it as a wiki page?"

If yes:
- Create `wiki/{{analysis-slug}}.md` with type `analysis`
- Use the analysis template from `page-templates.md`
- Add to `index.md` under Analyses
- Log it:
  ```markdown
  ## [YYYY-MM-DD] query | {{Title}}

  - Query: "{{user's question}}"
  - Pages read: [[page-a|Page A]], [[page-b|Page B]], [[page-c|Page C]]
  - Filed as: [[analysis-slug|Analysis Title]]
  ```
- Run `qmd --index {{qmd-collection}} update && qmd --index {{qmd-collection}} embed` if qmd is available

### Output formats

Most answers should be conversational text with wikilinks. But depending on the question, other formats may be more useful:
- **Comparison questions** → markdown table
- **Timeline questions** → chronological list
- **"Show me everything about X"** → suggest reading the entity/concept page directly
- **Data-heavy questions** → offer to generate a chart or extract a CSV
