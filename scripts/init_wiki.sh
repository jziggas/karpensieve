#!/usr/bin/env bash
# init_wiki.sh — Initialize an LLM-maintained wiki with Obsidian-compatible structure
#
# Usage: bash init_wiki.sh [--skills] <wiki_path> <wiki_name> [domain_description]
#
# Arguments:
#   --skills             — (optional) install Claude Code skills for ingest, query, lint
#   wiki_path            — where to create the wiki (e.g., ~/my-research-wiki)
#   wiki_name            — display name (e.g., "AI Safety Research")
#   domain_description   — optional one-liner describing the domain

set -euo pipefail

# --- Parse --skills flag ---
INSTALL_SKILLS=false
if [ "${1:-}" = "--skills" ]; then
    INSTALL_SKILLS=true
    shift
fi

WIKI_PATH="${1:?Usage: bash init_wiki.sh [--skills] <wiki_path> <wiki_name> [domain_description]}"
WIKI_NAME="${2:?Usage: bash init_wiki.sh [--skills] <wiki_path> <wiki_name> [domain_description]}"
DOMAIN_DESC="${3:-A knowledge wiki maintained by an LLM.}"
TODAY=$(date +%Y-%m-%d)
WIKI_BASENAME="$(basename "$WIKI_PATH")"

# Escape sed-special characters in replacement strings
sed_escape() { printf '%s\n' "$1" | sed -e 's/[\/&]/\\&/g'; }

if [ -d "$WIKI_PATH" ] && [ "$(ls -A "$WIKI_PATH" 2>/dev/null)" ]; then
    echo "ERROR: $WIKI_PATH already exists and is not empty."
    echo "       Choose a different path or remove the existing directory."
    exit 1
fi

echo "Creating wiki: $WIKI_NAME"
echo "Location:      $WIKI_PATH"
echo "Domain:        $DOMAIN_DESC"
echo ""

# --- Directory structure (flat) ---
mkdir -p "$WIKI_PATH"/{raw/assets,wiki/meta,.obsidian}

# --- raw/.wikiignore (exclude raw files from unprocessed file scan) ---
cat > "$WIKI_PATH/raw/.wikiignore" << 'EOF'
# Files listed here are excluded from the unprocessed file scan.
# Add one filename per line (relative to raw/), e.g.:
# old-article.md
# outdated-report.pdf
EOF

# --- Resolve script directory to find bundled references ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

# --- Install skills if requested ---
if [ "$INSTALL_SKILLS" = true ]; then
    if [ -d "$SKILL_DIR/skills" ]; then
        for skill_dir in "$SKILL_DIR/skills"/*/; do
            skill_name="$(basename "$skill_dir")"
            if [ -f "$skill_dir/SKILL.md" ]; then
                mkdir -p "$WIKI_PATH/.claude/skills/$skill_name"
                sed "s/{{qmd-collection}}/${WIKI_BASENAME}/g" "$skill_dir/SKILL.md" > "$WIKI_PATH/.claude/skills/$skill_name/SKILL.md"
            fi
        done
        echo "Skills installed: $(ls "$WIKI_PATH/.claude/skills/" | tr '\n' ' ')"
    else
        echo "WARNING: Skills directory not found at $SKILL_DIR/skills/"
        echo "         Run from the llm-wiki package directory, or copy skills manually."
        INSTALL_SKILLS=false
    fi
fi

# --- CLAUDE.md (for Claude Code) ---
cat > "$WIKI_PATH/CLAUDE.md" << EOF
# ${WIKI_NAME}

This project is an LLM-maintained wiki. You are the wiki maintainer.

## Session start

1. Read \`SCHEMA.md\` for conventions and workflows
2. Read \`index.md\` to see current wiki state
3. Read the last 5-10 entries in \`log.md\` for recent activity
4. Check for unprocessed files in \`raw/\` — compare files on disk against \`source_file\` values in wiki pages and entries in \`raw/.wikiignore\`. Report any new files to the user.
5. If qmd is installed but the wiki collection isn't set up, run: \`qmd --index ${WIKI_BASENAME} collection add wiki/ --name ${WIKI_BASENAME}\`
6. Ask: ingest, query, lint, or explore?

## Key references

- \`SCHEMA.md\` — all conventions, workflows, and formatting rules
- \`page-templates.md\` — frontmatter and structure templates for each page type
- \`index.md\` — catalog of all wiki pages
- \`log.md\` — chronological record of operations

## Rules

- **\`raw/\`** is immutable. Read from it, never write to it (except \`raw/.wikiignore\`, which you maintain).
- **\`wiki/\`** is yours. Create and update all pages here.
- Always use \`[[wikilinks]]\` for internal links.
- Always add YAML frontmatter to every page.
- Flag contradictions with \`> [!warning]\` callouts — never silently overwrite.
EOF

# --- Append skills section to CLAUDE.md if skills are installed ---
if [ "$INSTALL_SKILLS" = true ]; then
    cat >> "$WIKI_PATH/CLAUDE.md" << 'EOF'

## Skills

Skills are installed in `.claude/skills/`. Each skill handles one wiki operation with a specific, repeatable workflow. When the user asks to ingest, query, or lint, read the corresponding skill file and follow its workflow.

- `.claude/skills/wiki-ingest/SKILL.md` — process source documents into wiki pages (`/wiki-ingest`)
- `.claude/skills/wiki-query/SKILL.md` — search the wiki and synthesize answers (`/wiki-query`)
- `.claude/skills/wiki-lint/SKILL.md` — interactive health check with guided resolution (`/wiki-lint`)

The skills reference `SCHEMA.md` for conventions and `page-templates.md` for page formats. They do not replace these files — they provide focused operational workflows on top of them.
EOF
fi

# --- SCHEMA.md (generated from references/schema-template.md) ---
TEMPLATE_FILE="$SKILL_DIR/references/schema-template.md"
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "ERROR: Schema template not found at $TEMPLATE_FILE"
    echo "       Run from the llm-wiki package directory."
    exit 1
fi

ESC_NAME="$(sed_escape "$WIKI_NAME")"
ESC_DESC="$(sed_escape "$DOMAIN_DESC")"

sed -n '/^# {{Wiki Name}}/,$p' "$TEMPLATE_FILE" | sed \
    -e "s/{{Wiki Name}}/${ESC_NAME}/g" \
    -e "s/{{One paragraph: what this wiki covers and what the goal is\.}}/${ESC_DESC}/" \
    -e "s/{{e\.g\., \"AI safety research\", \"personal health\", \"competitive analysis\"}}/${ESC_DESC}/" \
    -e "s/{{your name or team}}/(your name)/" \
    -e "s/{{date}}/${TODAY}/" \
    -e "s/{{wiki-root}}/${WIKI_BASENAME}/" \
    -e "s/{{qmd-collection}}/${WIKI_BASENAME}/g" \
    -e "s/{{description of wiki}}/${ESC_DESC}/" \
    -e 's/^{{Add domain-specific types.*}}/<!-- Add domain-specific types here if needed. -->/' \
    -e 's/^{{Customize for your domain.*}}/<!-- Customize for your domain: -->/' \
    -e 's/^{{For a research wiki:}}/<!-- For a research wiki: -->/' \
    -e 's/^{{For a personal wiki:}}/<!-- For a personal wiki: -->/' \
    -e '/^{{- /{s/^{{/<!-- /;s/}}$/ -->/;}' \
    > "$WIKI_PATH/SCHEMA.md"

# --- index.md ---
cat > "$WIKI_PATH/index.md" << EOF
---
title: "Index"
type: meta
updated: ${TODAY}
---

# ${WIKI_NAME} — Index

## Sources

| Page | Summary | Date |
|------|---------|------|
| *(none yet)* | | |

## Entities

| Page | Entity type | Summary |
|------|-------------|---------|
| *(none yet)* | | |

## Concepts

| Page | Summary | Confidence |
|------|---------|------------|
| *(none yet)* | | |

## Analyses

| Page | Summary | Date |
|------|---------|------|
| *(none yet)* | | |

## Meta

| Page | Summary |
|------|---------|
| [[Wiki Overview]] | High-level overview and evolving thesis |
| [[Open Questions]] | Tracked questions and gaps |
EOF

# --- log.md ---
cat > "$WIKI_PATH/log.md" << EOF
---
title: "Log"
type: meta
---

# ${WIKI_NAME} — Log

Chronological record. Newest entries at bottom.
Format: \`## [YYYY-MM-DD] operation | title\`

<!-- Append new entries below this line -->
## [${TODAY}] init | Wiki created

- Schema: \`SCHEMA.md\`
- Structure initialized
- Domain: ${DOMAIN_DESC}
EOF

# --- wiki/meta/overview.md ---
cat > "$WIKI_PATH/wiki/meta/overview.md" << EOF
---
title: "Wiki Overview"
type: meta
created: ${TODAY}
updated: ${TODAY}
tags:
  - meta
---

# ${WIKI_NAME} — Overview

## Purpose

${DOMAIN_DESC}

## Current state

- **Sources ingested:** 0
- **Wiki pages:** 2 (this overview + open questions)
- **Last updated:** ${TODAY}

## Key findings so far

*(No sources ingested yet.)*

## Evolving thesis

*(Will emerge as sources are ingested.)*

## Open questions

See [[Open Questions]].

## Reading list

- *(Add sources to investigate here)*
EOF

# --- wiki/meta/open-questions.md ---
cat > "$WIKI_PATH/wiki/meta/open-questions.md" << EOF
---
title: "Open Questions"
type: meta
created: ${TODAY}
updated: ${TODAY}
tags:
  - meta
  - questions
---

# Open Questions

Updated during ingest and lint passes.

## High priority

*(None yet — will populate as sources are ingested.)*

## Medium priority

*(None yet.)*

## Resolved

*(None yet.)*
EOF

# --- .obsidian/app.json ---
cat > "$WIKI_PATH/.obsidian/app.json" << 'EOF'
{
  "attachmentFolderPath": "raw/assets",
  "newFileLocation": "folder",
  "newFileFolderPath": "wiki",
  "useMarkdownLinks": false,
  "showFrontmatter": true,
  "readableLineLength": true,
  "foldHeading": true,
  "foldIndent": true,
  "showLineNumber": false,
  "strictLineBreaks": false,
  "alwaysUpdateLinks": true
}
EOF

# --- .obsidian/appearance.json ---
cat > "$WIKI_PATH/.obsidian/appearance.json" << 'EOF'
{
  "accentColor": ""
}
EOF

# --- .obsidian/graph.json (color groups by page type) ---
cat > "$WIKI_PATH/.obsidian/graph.json" << 'EOF'
{
  "collapse-filter": false,
  "search": "",
  "showTags": false,
  "showAttachments": false,
  "hideUnresolved": false,
  "showOrphans": true,
  "collapse-color-groups": false,
  "colorGroups": [
    {
      "query": "path:wiki/meta",
      "color": {
        "a": 1,
        "rgb": 8553090
      }
    },
    {
      "query": "path:raw",
      "color": {
        "a": 1,
        "rgb": 6724095
      }
    }
  ],
  "collapse-display": false,
  "showArrow": true,
  "textFadeMultiplier": 0,
  "nodeSizeMultiplier": 1,
  "lineSizeMultiplier": 1,
  "collapse-forces": true,
  "centerStrength": 0.5,
  "repelStrength": 10,
  "linkStrength": 1,
  "linkDistance": 250,
  "scale": 1,
  "close": false
}
EOF

# --- .obsidian/core-plugins.json ---
cat > "$WIKI_PATH/.obsidian/core-plugins.json" << 'EOF'
[
  "file-explorer",
  "global-search",
  "graph",
  "backlink",
  "outgoing-link",
  "tag-pane",
  "page-preview",
  "command-palette",
  "editor-status",
  "starred",
  "outline",
  "file-recovery"
]
EOF

# --- .obsidian/community-plugins.json (recommended, user must install) ---
cat > "$WIKI_PATH/.obsidian/community-plugins.json" << 'EOF'
[
  "dataview"
]
EOF

# --- .obsidian/hotkeys.json ---
cat > "$WIKI_PATH/.obsidian/hotkeys.json" << 'EOF'
{}
EOF

# --- .gitignore ---
cat > "$WIKI_PATH/.gitignore" << 'EOF'
.obsidian/workspace.json
.obsidian/workspace-mobile.json
.obsidian/cache
.claude/*
!.claude/skills/
.trash/
.DS_Store
Thumbs.db
EOF

# --- Copy page-templates.md from skill package if available ---
if [ -f "$SKILL_DIR/references/page-templates.md" ]; then
    cp "$SKILL_DIR/references/page-templates.md" "$WIKI_PATH/page-templates.md"
else
    # Minimal inline fallback if running script standalone
    cat > "$WIKI_PATH/page-templates.md" << 'TMPLEOF'
# Page Templates

See the full llm-wiki skill package for comprehensive templates.
Each wiki page should have YAML frontmatter with at minimum:

```yaml
---
title: "Page Title"
type: source | entity | concept | analysis | meta
created: YYYY-MM-DD
updated: YYYY-MM-DD
tags:
  - tag
---
```

Source pages also need: source_type, author, date, url, source_file, assets
Entity pages also need: entity_type, aliases, sources
Concept pages also need: confidence, aliases, sources

Page structure: # Title → ## Overview → ## (content) → ## Connections → ## Sources
TMPLEOF
fi

# --- Summary ---
echo ""
echo "Wiki initialized!"
echo ""
echo "Structure:"
find "$WIKI_PATH" -not -path '*/\.*' -type f | sort | sed "s|$WIKI_PATH/|  |"
if [ "$INSTALL_SKILLS" = true ]; then
    echo ""
    echo "Skills:"
    find "$WIKI_PATH/.claude" -type f | sort | sed "s|$WIKI_PATH/|  |"
fi
echo ""
echo "Hidden config:"
find "$WIKI_PATH/.obsidian" -type f | sort | sed "s|$WIKI_PATH/|  |"
echo ""

# --- .mcp.json (project-scoped MCP config for qmd) ---
# Uses INDEX_PATH env var to point MCP server at a per-wiki SQLite database.
# Workaround for https://github.com/tobi/qmd/issues/343 (--index flag ignored by MCP server).
# Once that issue is resolved, this can be simplified to: "args": ["--index", "<name>", "mcp"]
QMD_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/qmd"
cat > "$WIKI_PATH/.mcp.json" << MCPEOF
{
  "mcpServers": {
    "qmd": {
      "type": "stdio",
      "command": "qmd",
      "args": ["mcp"],
      "env": {
        "INDEX_PATH": "${QMD_CACHE_DIR}/${WIKI_BASENAME}.sqlite"
      }
    }
  }
}
MCPEOF

# --- qmd setup (automatic if installed) ---
if command -v qmd >/dev/null 2>&1; then
    echo "qmd detected — setting up search collection..."
    qmd --index "$WIKI_BASENAME" collection add "$WIKI_PATH/wiki" --name "$WIKI_BASENAME" 2>/dev/null && \
        echo "  ✓ Collection '$WIKI_BASENAME' registered: $WIKI_PATH/wiki (index: $WIKI_BASENAME)"
    qmd --index "$WIKI_BASENAME" context add "qmd://$WIKI_BASENAME" "${WIKI_NAME} wiki pages" 2>/dev/null && \
        echo "  ✓ Context added for collection '$WIKI_BASENAME'"
    echo "  (Run 'qmd --index $WIKI_BASENAME update && qmd --index $WIKI_BASENAME embed' after ingesting sources)"
    echo ""
else
    echo "qmd not found (optional, recommended for large wikis)."
    echo "Install it and the agent will set up the collection automatically:"
    echo "  npm install -g @tobilu/qmd"
    echo ""
fi

# --- PDF tooling check (warn only) ---
missing_pdf_tools=()
command -v pdftoppm >/dev/null 2>&1 || missing_pdf_tools+=("poppler (pdftoppm)")
python3 -c "import pdfminer" 2>/dev/null || missing_pdf_tools+=("pdfminer.six")
python3 -c "import fitz" 2>/dev/null || missing_pdf_tools+=("pymupdf")
if [ ${#missing_pdf_tools[@]} -gt 0 ]; then
    echo "Note: PDF ingest tooling not fully installed."
    echo "Missing: ${missing_pdf_tools[*]}"
    echo "Install for full PDF support (see README → Prerequisites):"
    echo "  brew install poppler"
    echo "  pip install pdfminer.six pymupdf pdfplumber"
    echo ""
fi

# --- DOCX / PPTX tooling check (warn only) ---
missing_office_tools=()
python3 -c "import docx" 2>/dev/null || missing_office_tools+=("python-docx")
python3 -c "import pptx" 2>/dev/null || missing_office_tools+=("python-pptx")
if [ ${#missing_office_tools[@]} -gt 0 ]; then
    echo "Note: Office ingest tooling not fully installed."
    echo "Missing: ${missing_office_tools[*]}"
    echo "Install for full DOCX / PPTX support (tables, form controls, images, speaker notes):"
    echo "  pip install python-docx python-pptx"
    echo ""
fi

echo "Next steps:"
echo "  1. cd $WIKI_PATH && claude    ← start Claude Code"
echo "  2. Open $WIKI_PATH as a vault in Obsidian"
echo "  3. Review and customize SCHEMA.md for your domain"
echo "  4. Drop source documents into raw/"
echo "  5. Tell the LLM to ingest them"
if [ "$INSTALL_SKILLS" = false ]; then
    echo ""
    echo "To add skills (optional, makes operations more consistent):"
    echo "  bash $(realpath "$0") --skills can be re-run, or copy skills manually:"
    echo "  cp -r $SKILL_DIR/skills $WIKI_PATH/.claude/skills"
fi
