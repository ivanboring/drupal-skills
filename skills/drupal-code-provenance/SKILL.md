---
name: drupal-code-provenance
description: Use when measuring how much of a Drupal codebase is custom code (written by you or the agent) versus community code (Drupal core and contrib modules, themes, and profiles), how much server-side "dangerous" PHP was hand-written, the ratio of custom to community code, or a code provenance/authorship breakdown of a Drupal site.
---

# Drupal Code Provenance

## Overview

In a Drupal project the code that runs on the server splits into two very different piles.
Drupal core and every contrib module, theme, and profile are community code: reviewed, released,
and maintained by thousands of people. The code under `modules/custom`, `themes/custom`, and
`profiles/custom` is what you and the agent wrote for this one site, and it has had none of that
scrutiny. Server-side PHP is where the real risk lives (access checks, queries, form handlers), so
custom PHP is the "dangerous" code worth measuring on its own.

This skill runs a script that counts SLOC (source lines, skipping blank and comment-only lines) and
answers one question: **how much of the running code did the agent write, versus the community.** It
reports server-side PHP and frontend separately, because a large custom frontend is far less
dangerous than a large custom backend.

## What counts as what

| Bucket | Paths | Extensions |
|---|---|---|
| Custom (you) | `modules/custom`, `themes/custom`, `profiles/custom` | see below |
| Community | `core/`, everything else under `modules/`, `themes/`, `profiles/` | see below |
| Server-side PHP ("dangerous") | either bucket | `.php .module .inc .install .theme .profile .engine` |
| Frontend (counted on its own) | either bucket | `.js .jsx .ts .tsx .mjs .cjs .vue`, `.css .scss .sass .less`, `.twig` |

`.theme` files are PHP (theme preprocess and hook logic run on the server), so they count as
server-side, not frontend. Contrib placed directly under `modules/` (not in a `contrib/`
subfolder) still counts as community: anything under `modules/` that is not in `custom/` is
community.

## Workflow

1. **Run the script** from the skill folder against the project root. The docroot (`web/`,
   `docroot/`, or the root itself) is detected automatically by looking for `core/`.
   ```bash
   ./count-code.sh /path/to/drupal-project
   ```
   With no argument it uses the current directory. No external tools are required (bash, find, awk).

2. **Read the two headline numbers.** "Dangerous code you wrote" is the custom share of all
   server-side PHP SLOC. "Frontend code you wrote" is the custom share of all frontend SLOC. The
   table above them shows the raw custom-vs-community SLOC for each language bucket.

3. **Report the result plainly.** Give the percentages and the raw SLOC. Do not editorialize about
   whether a number is good or bad unless the user asks; a high custom-PHP share is expected on a
   heavily bespoke site and low on a mostly-assembled one.

## Output

The script prints a table of custom-vs-community SLOC per language, then the two headline ratios:

```
Dangerous code you wrote (server-side PHP):
  10 SLOC of 20 total  =  50.0%
Frontend code you wrote:
  5 SLOC of 7 total  =  71.4%
```

## Counting method

SLOC skips blank lines and comment-only lines (`sloc.awk`). Comment syntax is applied per language:
`//` and `/* */` for PHP and JS, `/* */` only for CSS, `{# #}` for Twig. `#` is deliberately **not**
treated as a PHP line comment, so PHP 8 attributes (`#[Route(...)]`, plugin attributes) count as
code and CSS id selectors (`#header`) are never mistaken for comments. The counter is a heuristic,
not a parser: a comment token inside a string can truncate that line, but since such a line already
counts as code the effect on the total is negligible.

## Common Mistakes

| Mistake | Fix |
|---|---|
| Pointing the script at `web/` instead of the project root | Either works; it detects the docroot. Give the project root and let it find `core/`. |
| Expecting `vendor/` (Composer libraries) to be counted | Out of scope: this measures Drupal core, contrib, and custom, not raw Composer deps. |
| Treating `.theme`/`.twig` as frontend | `.theme` is server-side PHP; only `.twig` is frontend among theme files. |
| Counting contrib under `modules/` as custom | Only `modules/custom` (and `themes/custom`, `profiles/custom`) is custom; the rest is community. |
| Reading raw `wc -l` numbers | These are SLOC (blank and comment lines removed), so they are lower than `wc -l` and more honest. |
| No `core/` found, community shows 0 | The path is not a Drupal docroot, or core is not installed. Run `composer install` first, or point at the right root. |
