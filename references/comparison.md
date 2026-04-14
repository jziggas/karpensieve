# How karpensieve compares

Most AI-powered knowledge tools use RAG (retrieval-augmented generation): you upload documents, the AI retrieves relevant chunks at query time, and generates an answer. This works for quick Q&A but nothing is built up between queries. karpensieve takes a different approach — the LLM **compiles** your sources into a persistent, interlinked wiki that accumulates knowledge over time. Search (via qmd) retrieves from these compiled pages rather than raw document chunks, so you get structured, cross-referenced results instead of isolated fragments.

Here's how it compares to the tools people most often ask about.

---

## At a glance

| | NotebookLM | ChatGPT | Claude Projects | karpensieve |
|---|---|---|---|---|
| **Approach** | RAG over raw docs | RAG over raw docs | RAG + memory | Compilation + retrieval over compiled pages |
| **Knowledge persists** | No — re-derived each query | Fragile — memory wipes have occurred | Partially — memory summaries, capped | Yes — markdown files on disk |
| **Browsable output** | No — query-only | No — locked in chat history | No — chat + memory summary | Yes — Obsidian vault with graph view |
| **Cross-referencing** | No | No | No | Explicit wikilinks, maintained by LLM |
| **Contradictions** | Hidden — depends on which chunk is retrieved | Hidden | Hidden | Flagged with `[!warning]` callouts |
| **Portable / exportable** | No — locked in Google | No — locked in OpenAI | No — locked in Anthropic | Yes — git repo of markdown files |
| **Source limits** | 50–600 per notebook | 20 files per GPT, 10GB/user | ~200k tokens per project | No limit — local files |
| **Cross-project linking** | No — notebooks are isolated silos | No — projects are isolated | No — projects are isolated | Separate wikis, all open markdown |
| **Collaboration** | Basic sharing, no roles | Shared GPTs | Team plans | Git — push, pull, merge |
| **Effort required** | Low — upload and ask | Low — upload and ask | Low — add to project and ask | Higher — you curate sources and guide ingest |
| **Best for** | Quick Q&A over a document set | Chat with files | Maintaining project context | Long-term knowledge accumulation |

---

## NotebookLM

[NotebookLM](https://notebooklm.google/) is Google's AI research tool. You upload sources into a notebook and ask questions — it retrieves relevant passages and generates answers grounded in your documents.

**What it does well:**
- Zero-effort setup. Upload PDFs, Google Docs, Slides, URLs, YouTube links, or audio files and start asking questions immediately.
- Audio Overview generates podcast-style summaries of your sources — a unique feature no other tool offers.
- Inline citations point back to specific passages in your sources.
- Supports up to 500,000 words per source.

**Where it falls short for knowledge building:**
- **Nothing accumulates.** Ask a subtle question that requires synthesizing five documents, and NotebookLM re-derives the answer from raw chunks every time. There's no persistent synthesis.
- **No organizational structure.** No linking between concepts, no graph view, no cross-references. Connections exist only in the moment of a query, not as persistent artifacts you can browse.
- **Notebooks are isolated silos.** Your AI safety notebook can't reference your policy notebook. Researchers either duplicate sources (wasting the 50-source cap) or accept disconnected knowledge.
- **Limited export.** No structured export of notebooks, conversations, or the connections the AI found. Getting work out requires manual copy-paste.
- **No API.** Can't automate source uploads, queries, or integrate into research workflows.
- **Source type gaps.** Doesn't support spreadsheets, CSVs, code repositories, EPUBs, or images as first-class sources.

**Source limits by tier:**

| Tier | Price | Sources/notebook | Notebooks |
|------|-------|-----------------|-----------|
| Free | $0 | 50 | 100 |
| Plus | $9.99/mo | 300 | 500 |
| Ultra | $249.99/mo | 600 | 1,000 |

**Bottom line:** NotebookLM is the best tool for quick, low-effort Q&A over a bounded set of documents. If you need to rapidly understand a collection of papers or reports and don't need the understanding to persist or grow, it's excellent. But it's not a knowledge management system — it's a document analysis tool.

---

## ChatGPT (Projects, file uploads, Custom GPTs)

OpenAI's ChatGPT lets you upload files to conversations, organize work into Projects, and build Custom GPTs with knowledge files.

**What it does well:**
- Broad file support — PDFs, code, images, spreadsheets, and more.
- Projects provide some organizational structure and context persistence.
- Custom GPTs can be shared and used by others.
- Large per-file limits: 512MB per file, 20 files per GPT.

**Where it falls short for knowledge building:**
- **RAG under the hood.** File uploads are chunked and retrieved at query time. The AI doesn't build a persistent understanding — it re-searches your files on every question.
- **Memory is fragile.** ChatGPT's memory system is small and has been wiped multiple times (documented incidents in 2025 where users lost months of accumulated context overnight with no recovery).
- **Context drifts.** In long conversations, earlier context fades. Projects help but don't solve this.
- **Projects are isolated.** No cross-referencing between projects. Knowledge built in one project is invisible to others.
- **No browsable output.** Everything stays locked in chat history. You can't browse, search, or navigate the knowledge ChatGPT has built from your files.
- **No contradiction detection.** If two uploaded documents disagree, ChatGPT will confidently cite whichever chunk it retrieves — no flagging, no awareness of the conflict.

**Bottom line:** ChatGPT is a powerful conversational AI with good file handling, but it's designed for chat, not for knowledge accumulation. What it learns from your files doesn't compound, isn't browsable, and has proven unreliable for long-term persistence.

---

## Claude Projects

Anthropic's Claude offers Projects — workspaces where you add files and instructions as persistent context for conversations.

**What it does well:**
- Project knowledge persists across conversations within the project.
- Memory summaries auto-synthesize roughly every 24 hours, capturing key facts and decisions.
- Clean separation between projects keeps contexts focused.
- Strong instruction-following makes Claude effective for specialized workflows.

**Where it falls short for knowledge building:**
- **Still fundamentally RAG.** For larger collections, Claude switches to retrieval-augmented generation — searching your project files for relevant chunks rather than having compiled understanding.
- **Memory is capped.** Project memory summaries are limited to ~200k tokens. Beyond that, older context is compressed or lost.
- **Projects are isolated.** A research project can't reference a related project. No cross-project knowledge graph.
- **No browsable structured output.** The "knowledge" exists as Claude's internal memory summary and chat history — not as files you can browse, search, or share.
- **No contradiction tracking.** If project documents disagree, Claude won't systematically flag it.

**Bottom line:** Claude Projects is the best of the three for maintaining working context within a focused project. But the knowledge lives inside Claude's memory, not as an artifact you own. You can't browse it in a graph view, version it with git, or hand it to a colleague as a structured wiki.

---

## When to use what

**Use NotebookLM when** you have a bounded set of documents (a stack of papers, a set of reports) and need quick answers with citations. You don't need the understanding to persist or grow — you need it now.

**Use ChatGPT when** you're working conversationally with files — debugging code, analyzing data, drafting content. The interaction is the point, not the accumulated knowledge.

**Use Claude Projects when** you have an ongoing project that benefits from maintained context — a codebase, a client engagement, a research thread. You want Claude to remember decisions and context within that project.

**Use karpensieve when** you're accumulating knowledge over weeks or months from many sources and want it organized, browsable, interlinked, and compounding. You're willing to invest more effort — curating sources, guiding ingest, asking the right questions — in exchange for a persistent knowledge base that you own, can browse in Obsidian, version with git, and share with collaborators. The wiki gets richer with every source you add. Nothing is re-derived, nothing is locked in a platform, nothing disappears.

---

## They're complementary

These tools aren't mutually exclusive. You might use NotebookLM for rapid document triage, then ingest the important sources into your karpensieve wiki for long-term synthesis. You might use Claude Projects for day-to-day project work and periodically file key findings back into a wiki. The wiki is the long-term store; the other tools are working surfaces.
