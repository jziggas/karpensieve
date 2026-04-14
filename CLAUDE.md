# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

This is **karpensieve** — a toolkit for creating LLM-maintained wikis, not a wiki itself. It contains templates, an init script, and skill definitions that get copied into new wiki instances. The toolkit lives in a shared location (e.g., `~/tools/karpensieve`) and generates self-contained wikis elsewhere.

Read `core-idea.md` for the philosophy: instead of RAG (re-derive knowledge on every query), the LLM compiles sources into a persistent, interlinked wiki. Three layers: raw sources (immutable), wiki (LLM-generated markdown), schema (conventions). Three operations: ingest, query, lint.

## Repository structure

- `scripts/init_wiki.sh` — Creates new wikis. The main entry point for users.
- `references/schema-template.md` — Full SCHEMA.md template with `{{placeholders}}` replaced by the init script.
- `references/page-templates.md` — Frontmatter and structure templates for each page type (source, entity, concept, analysis, meta).
- `references/comparison.md` — Product comparison with NotebookLM, ChatGPT, Claude Projects.
- `skills/wiki-ingest/SKILL.md`, `skills/wiki-query/SKILL.md`, `skills/wiki-lint/SKILL.md` — Claude Code skill definitions. These are templates with `{{qmd-collection}}` placeholders, not active skills.
- `SKILL.md` — Claude.ai skill trigger (not used in Claude Code).
- `README.md` — User-facing setup guide and reference.

## Key conventions

**Placeholders:** Templates use `{{qmd-collection}}`, `{{Wiki Name}}`, `{{description of wiki}}`, etc. The init script replaces these with actual values via `sed`. When editing templates, use the placeholder syntax — never hardcode wiki-specific values.

**qmd integration:** All qmd CLI commands in templates use `--index {{qmd-collection}}` for per-wiki isolated SQLite databases. The MCP server config (`.mcp.json`) uses the `INDEX_PATH` env var instead — workaround for [tobi/qmd#343](https://github.com/tobi/qmd/issues/343).

**Skill structure:** Each skill is a directory (`skills/<name>/SKILL.md`) with YAML frontmatter (`name`, `description`) for Claude Code to register as `/wiki-ingest`, `/wiki-query`, `/wiki-lint`.

**Naming conventions in generated wikis:** Filenames are lowercase-with-hyphens. Wikilinks always use Obsidian's pipe format `[[file-slug|Display Text]]` — bare `[[Display Text]]` does not resolve via aliases or titles in Obsidian, it only resolves by exact filename match (and creates an empty stub file when no match). Aliases populate Quick Switcher and autocomplete suggestions but do not affect link resolution.

**macOS compatibility:** Bash recipes must work with BSD grep/sed (no `grep -P`). Use `grep -oE` for extended regex.

## Testing the init script

```bash
# Create a test wiki (default: with skills)
bash scripts/init_wiki.sh /tmp/test-wiki "Test Wiki" "A test wiki"

# Create a test wiki without skills
bash scripts/init_wiki.sh --no-skills /tmp/test-wiki-minimal "Test Wiki" "A test wiki"

# Verify structure
ls -R /tmp/test-wiki
ls -R /tmp/test-wiki/.claude/skills/

# Clean up
rm -rf /tmp/test-wiki /tmp/test-wiki-minimal
```

## When editing templates

Changes to `references/schema-template.md` or `references/page-templates.md` affect all future wikis. Existing wikis must be regenerated manually — the init script doesn't update in place. When updating skill templates in `skills/*/SKILL.md`, remember they contain `{{qmd-collection}}` placeholders that get replaced during install.

The init script, schema template, skill files, README, and SKILL.md all reference qmd commands. When changing qmd command syntax, check all five locations.
