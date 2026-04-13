#!/usr/bin/env python3
"""
wiki-lint scanner — canonical checks for LLM-maintained wikis.

Run from the wiki root:

    python .claude/skills/wiki-lint/scan.py              # full report
    python .claude/skills/wiki-lint/scan.py --check dead-links   # one check

Emits sectioned plain-text report to stdout. Exits 0 regardless of findings
(report tool, not a CI gate).

Preprocessing handles three historical false-positive classes before regex
extraction — these are the fixes that distinguish this scanner from the
earlier inline grep snippets:

  1. Code fences (``` ... ``` / ~~~ ... ~~~) and inline backtick spans are
     stripped. Obsidian does not render wikilinks inside code, so literal
     [[…]] examples in documentation prose (e.g., SCHEMA notes, log entries,
     lint reports) were creating false dead-link and bare-wikilink flags.
  2. HTML comments (<!-- … -->, multiline) are stripped, for the same reason.
  3. Markdown table-cell pipe escapes (\\|) are un-escaped to | BEFORE slug
     extraction, so [[paymentus\\|Paymentus]] in a table cell is correctly
     parsed as slug=paymentus instead of slug=paymentus\\.

The slug→file map also includes root-level *.md files (index.md, log.md),
so wikilinks like [[index|Index]] resolve correctly.

No external dependencies — Python stdlib only.
"""

from __future__ import annotations

import argparse
import collections
import glob
import os
import re
import sys
from typing import Iterable

# ---------------------------------------------------------------------------
# Preprocessing
# ---------------------------------------------------------------------------

# Fenced code blocks: ``` ... ``` or ~~~ ... ~~~ (multiline). CommonMark
# allows up to 3 spaces of leading indent on either fence — required for
# fenced blocks nested under bullet lists.
_FENCE_RE = re.compile(r"(?ms)^ {0,3}(`{3,}|~{3,}).*?^ {0,3}\1\s*$")
# Inline code spans: ` … `, `` … ``, ``` … ``` (single-line, balanced backticks)
_INLINE_CODE_RE = re.compile(r"(`+)(?:(?!\1).)+?\1")
# HTML comments: <!-- … --> (multiline)
_HTML_COMMENT_RE = re.compile(r"<!--.*?-->", re.DOTALL)


def _blank_same_lines(match: "re.Match[str]") -> str:
    """Replace a match with the same number of newlines, preserving line
    numbers downstream so reports can still cite accurate line numbers."""
    return "\n" * match.group(0).count("\n")


def preprocess(content: str) -> str:
    """Strip contexts in which Obsidian does NOT render wikilinks (or in
    which documentation prose discusses wiki syntax), and un-escape
    markdown table-cell pipe escapes so piped-wikilink regex captures
    the slug cleanly. Line numbers are preserved across stripped spans
    (stripped content is replaced with newlines, not removed outright)."""
    content = _FENCE_RE.sub(_blank_same_lines, content)
    content = _HTML_COMMENT_RE.sub(_blank_same_lines, content)
    content = _INLINE_CODE_RE.sub(_blank_same_lines, content)
    # Un-escape \| → | (markdown table-cell pipe escape). Obsidian does
    # this before parsing, so we mirror it here.
    content = content.replace(r"\|", "|")
    return content


# ---------------------------------------------------------------------------
# Extractors (run AFTER preprocess)
# ---------------------------------------------------------------------------

_PIPED_RE = re.compile(r"(?<!\!)\[\[([^\[\]\|]+)\|([^\[\]]+)\]\]")
# Bare wikilinks: [[text]] with no pipe, not preceded by ! (image embed).
_BARE_RE = re.compile(r"(?<!\!)\[\[([^\[\]\|]+)\]\]")
_IMAGE_RE = re.compile(r"!\[\[([^\[\]]+)\]\]")
_FRONTMATTER_RE = re.compile(r"\A---\n(.*?)\n---", re.DOTALL)


# ---------------------------------------------------------------------------
# File discovery
# ---------------------------------------------------------------------------

def discover_pages() -> list[str]:
    """All wiki markdown files: wiki/*.md + wiki/meta/*.md + root *.md.

    Root-level files (index.md, log.md, SCHEMA.md, page-templates.md) live
    alongside wiki/ in the Obsidian vault root, so their slugs need to be
    in the resolution map and they need to be scanned for wikilinks too.
    """
    pages: list[str] = []
    pages.extend(sorted(glob.glob("wiki/*.md")))
    pages.extend(sorted(glob.glob("wiki/meta/*.md")))
    pages.extend(sorted(f for f in glob.glob("*.md") if os.path.isfile(f)))
    return pages


def slug_of(path: str) -> str:
    return os.path.splitext(os.path.basename(path))[0]


# ---------------------------------------------------------------------------
# Scan — reads every file once, runs preprocess, gathers all data
# ---------------------------------------------------------------------------

class Scan:
    def __init__(self) -> None:
        self.pages = discover_pages()
        self.slug_to_file: dict[str, str] = {slug_of(p): p for p in self.pages}
        # Which pages does each slug get referenced from (piped wikilinks)?
        self.inbound: dict[str, set[str]] = collections.defaultdict(set)
        self.slug_ref_counts: collections.Counter[str] = collections.Counter()
        self.dead_links: list[tuple[str, str, str]] = []  # (file, slug, display)
        self.bare_links: list[tuple[str, str]] = []       # (file, text)
        self.image_refs: list[tuple[str, str, bool]] = [] # (file, ref, exists)
        self.contradictions: list[tuple[str, int, str]] = []
        # Per-page metadata (frontmatter-derived)
        self.title_alias_gaps: list[tuple[str, str, list[str]]] = []
        self.thin_pages: list[tuple[str, int]] = []
        self.tag_counts: collections.Counter[str] = collections.Counter()
        # Files for index-drift / orphan checks
        self._scan()

    # ------------------------------------------------------------------
    def _scan(self) -> None:
        for path in self.pages:
            with open(path, encoding="utf-8") as fh:
                raw = fh.read()
            self._scan_frontmatter(path, raw)
            processed = preprocess(raw)
            # Contradictions run on processed content (line-preserving) so
            # documentation prose discussing `[!warning]` syntax in code
            # spans or fences doesn't get flagged as a real callout. Use
            # the raw line for the report text so the original formatting
            # shows through.
            raw_lines = raw.splitlines()
            for i, line in enumerate(processed.splitlines(), 1):
                if "[!warning]" in line.lower():
                    original = raw_lines[i - 1] if i - 1 < len(raw_lines) else line
                    self.contradictions.append((path, i, original.strip()))
            self._scan_wikilinks(path, processed)
            self._scan_images(path, processed)
            self._scan_body_length(path, raw, processed)

    # ------------------------------------------------------------------
    def _scan_contradictions(self, path: str, raw: str) -> None:
        """Unused — contradictions are scanned inline in _scan() so line
        numbers can be reported against the raw file. Kept as a stub for
        backward compatibility if anything external calls it."""
        pass

    # ------------------------------------------------------------------
    def _scan_frontmatter(self, path: str, raw: str) -> None:
        m = _FRONTMATTER_RE.match(raw)
        if not m:
            return
        fm = m.group(1)
        # Title
        title_m = re.search(r'^title:\s*"?([^"\n]+?)"?\s*$', fm, re.MULTILINE)
        title = title_m.group(1).strip().strip('"') if title_m else None
        # Aliases block (YAML list)
        aliases: list[str] = []
        alias_block = re.search(
            r"^aliases:\s*\n((?:\s+-\s+.+\n)+)", fm, re.MULTILINE
        )
        if alias_block:
            for line in alias_block.group(1).splitlines():
                am = re.match(r'\s+-\s+"?([^"\n]+?)"?\s*$', line)
                if am:
                    aliases.append(am.group(1).strip().strip('"'))
        if title is not None and title not in aliases:
            self.title_alias_gaps.append((path, title, aliases))
        # Tags block (YAML list)
        tags_block = re.search(
            r"^tags:\s*\n((?:\s+-\s+.+\n)+)", fm, re.MULTILINE
        )
        if tags_block:
            for line in tags_block.group(1).splitlines():
                tm = re.match(r"\s+-\s+(.+)", line)
                if tm:
                    self.tag_counts[tm.group(1).strip().strip('"')] += 1

    # ------------------------------------------------------------------
    def _scan_wikilinks(self, path: str, processed: str) -> None:
        for m in _PIPED_RE.finditer(processed):
            slug, display = m.group(1), m.group(2)
            self.slug_ref_counts[slug] += 1
            if slug not in self.slug_to_file:
                self.dead_links.append((path, slug, display))
            else:
                self.inbound[slug].add(path)
        for m in _BARE_RE.finditer(processed):
            text = m.group(1)
            if "|" in text:
                continue
            self.bare_links.append((path, text))

    # ------------------------------------------------------------------
    def _scan_images(self, path: str, processed: str) -> None:
        for m in _IMAGE_RE.finditer(processed):
            ref = m.group(1)
            candidates = [
                os.path.join("raw/assets", ref),
                os.path.join("raw", ref),
                ref,
            ]
            exists = any(os.path.exists(c) for c in candidates)
            self.image_refs.append((path, ref, exists))

    # ------------------------------------------------------------------
    def _scan_body_length(self, path: str, raw: str, processed: str) -> None:
        # Skip meta pages — they're often short by design.
        if path.startswith("wiki/meta/") or not path.startswith("wiki/"):
            return
        m = _FRONTMATTER_RE.match(raw)
        body = raw[m.end():] if m else raw
        words = len(body.split())
        if words < 100:
            self.thin_pages.append((path, words))


# ---------------------------------------------------------------------------
# Report printers — each is independent so --check <name> works
# ---------------------------------------------------------------------------

def _section(name: str) -> None:
    bar = "=" * 60
    print(f"\n{bar}\n{name}\n{bar}")


def report_dead_links(s: Scan) -> None:
    _section("DEAD LINKS (piped wikilinks with no matching file)")
    if not s.dead_links:
        print("  None.")
        return
    by_slug: dict[str, list[tuple[str, str]]] = collections.defaultdict(list)
    for file_, slug, display in s.dead_links:
        by_slug[slug].append((file_, display))
    for slug, refs in sorted(by_slug.items()):
        print(f"  [[{slug}]]: {len(refs)} ref(s)")
        for f, d in refs:
            print(f"    - {f} (display: {d})")


def report_bare_wikilinks(s: Scan) -> None:
    _section("BARE WIKILINKS (no pipe; non-image)")
    if not s.bare_links:
        print("  None.")
        return
    for f, t in s.bare_links:
        print(f"  {f}: [[{t}]]")


def report_image_refs(s: Scan) -> None:
    _section("IMAGE REFS")
    if not s.image_refs:
        print("  None.")
        return
    for f, ref, exists in s.image_refs:
        print(f"  {f}: ![[{ref}]] {'OK' if exists else 'MISSING'}")


def report_orphans(s: Scan) -> None:
    _section("ORPHAN PAGES (zero inbound piped wikilinks)")
    found = False
    for path in s.pages:
        slug = slug_of(path)
        refs = s.inbound.get(slug, set()) - {path}
        if not refs:
            # Don't flag the wiki-root files as "orphans" — index/log/SCHEMA
            # are meant to live at the top level and aren't normally linked
            # to by other pages.
            if not path.startswith("wiki/"):
                continue
            found = True
            print(f"  {path} (slug: {slug})")
    if not found:
        print("  None.")


def report_shadow_files(s: Scan) -> None:
    _section("TITLE-CASE / SPACED FILES (likely Obsidian-stub shadows)")
    suspicious: list[tuple[str, int]] = []
    for p in glob.glob("wiki/*.md") + glob.glob("wiki/meta/*.md"):
        bn = os.path.basename(p)
        if re.match(r"^[A-Z]", bn) or " " in bn:
            suspicious.append((p, os.path.getsize(p)))
    if not suspicious:
        print("  None.")
        return
    for p, size in suspicious:
        print(f"  {p} ({size} bytes)")


def report_thin(s: Scan) -> None:
    _section("THIN PAGES (<100 words body, excluding meta)")
    if not s.thin_pages:
        print("  None.")
        return
    for p, w in s.thin_pages:
        print(f"  {p}: {w} words")


def report_stale_title_alias(s: Scan) -> None:
    _section("STALE TITLE ALIAS (frontmatter title not in aliases)")
    if not s.title_alias_gaps:
        print("  None.")
        return
    for p, t, aliases in s.title_alias_gaps:
        print(f"  {p}: title='{t}' not in aliases={aliases}")


def report_tags(s: Scan) -> None:
    _section("TAG INVENTORY (review for near-duplicates)")
    if not s.tag_counts:
        print("  None.")
        return
    for tag, cnt in sorted(s.tag_counts.items()):
        print(f"  {tag}: {cnt}")


def report_missing(s: Scan) -> None:
    _section("MISSING PAGES (slug referenced 2+ times, no file)")
    found = False
    for slug, n in s.slug_ref_counts.most_common():
        if slug not in s.slug_to_file and n >= 2:
            found = True
            print(f"  [[{slug}]]: {n} references")
    if not found:
        print("  None.")


def report_contradictions(s: Scan) -> None:
    _section("CONTRADICTIONS (unresolved [!warning] callouts)")
    if not s.contradictions:
        print("  None.")
        return
    for p, i, line in s.contradictions:
        print(f"  {p}:{i}: {line}")


def report_index_drift(s: Scan) -> None:
    _section("INDEX DRIFT (wiki/ files not referenced in index.md)")
    if not os.path.isfile("index.md"):
        print("  (no index.md at wiki root — skipping)")
        return
    with open("index.md", encoding="utf-8") as fh:
        idx = preprocess(fh.read())
    found = False
    for path in s.pages:
        if not path.startswith("wiki/"):
            continue
        # Meta pages are referenced from index.md but only some conventionally.
        # We're specifically looking for content pages missing from the index.
        if path.startswith("wiki/meta/"):
            continue
        slug = slug_of(path)
        if f"[[{slug}|" not in idx:
            found = True
            print(f"  {path} (slug={slug}) — not referenced in index.md")
    if not found:
        print("  None.")


def report_inbound(s: Scan) -> None:
    _section("TOP INBOUND (most-linked pages)")
    if not s.inbound:
        print("  None.")
        return
    for slug, refs in sorted(s.inbound.items(), key=lambda x: -len(x[1]))[:10]:
        print(f"  {slug}: {len(refs)} pages link in")


# ---------------------------------------------------------------------------
# Driver
# ---------------------------------------------------------------------------

REPORTS: dict[str, callable] = {
    "dead-links": report_dead_links,
    "bare-wikilinks": report_bare_wikilinks,
    "image-refs": report_image_refs,
    "orphans": report_orphans,
    "shadow-files": report_shadow_files,
    "thin": report_thin,
    "stale-title-alias": report_stale_title_alias,
    "tags": report_tags,
    "missing": report_missing,
    "contradictions": report_contradictions,
    "index-drift": report_index_drift,
    "inbound": report_inbound,
}


def main() -> int:
    parser = argparse.ArgumentParser(description="wiki-lint scanner")
    parser.add_argument(
        "--check",
        choices=sorted(REPORTS.keys()),
        help="Run a single check instead of the full report.",
    )
    args = parser.parse_args()

    s = Scan()
    print(f"Scanned {len(s.pages)} pages "
          f"({len(s.slug_to_file)} unique slugs).")
    to_run: Iterable[str] = [args.check] if args.check else REPORTS.keys()
    for name in to_run:
        REPORTS[name](s)
    return 0


if __name__ == "__main__":
    sys.exit(main())
