---
name: drupal-project-description
description: Use when creating or editing a project page/description on drupal.org (the module or theme body at drupal.org/project/<name>), generating a PROJECT_DESCRIPTION.html file, or formatting a Drupal.org project page with headings, note boxes, tip boxes, action buttons, grids, and side-by-side link listings.
---

# Drupal.org Project Description

## Overview

Drupal.org project pages (`drupal.org/project/<name>`) render a restricted subset of HTML.
This skill generates or edits that body HTML — saved as an `.html` file the maintainer pastes
into the project's description field — and knows the special CSS classes drupal.org ships that
make a page pop (checkered note boxes, tip boxes, green buttons, grids, side-by-side listings).

**Core rules**
- The **first element is always one `<p>`** describing what the project does — this becomes the
  preview text in module listings and search results. No heading before it.
- Only use the allowed HTML (below). Anything else is stripped on save.
- Enhance with the special classes, but don't overdo it — they highlight *focused* content.

## Workflow

1. **Ask where the file goes.** Default is the project's module folder as
   `PROJECT_DESCRIPTION.html` (e.g. `web/modules/contrib/<name>/PROJECT_DESCRIPTION.html`, or
   the module root). Always confirm the path before writing — don't assume.

2. **Editing an existing page?** Read the live page first. The data name is the last URL segment
   (`drupal.org/project/ai` → `ai`):
   ```bash
   curl -sL "https://www.drupal.org/project/<dataname>" -o page.html
   ```
   The description body is the rendered content region. Preserve the maintainer's existing
   structure and voice; make the requested edits rather than rewriting wholesale.

3. **New project?** Include these headings (as `<h2>`), in this order, skipping any that don't apply:
   - **Features**
   - **Installation**
   - **Related Modules** — only if any exist; search drupal.org to find them
   - **Requirements/Dependencies** — only if any exist. Do **not** list Drupal core or PHP version
     unless the requirement is unusual (e.g. a specific PHP extension, a non-obvious version constraint).

4. **Write the HTML** to the confirmed path using the elements and components below.

5. **Screenshots (optional).** If the module is installed on a site you can reach *and* you have
   agent browser access, take a few screenshots of the feature in action to embed as `<img>`.
   Skip silently if either isn't available — don't fabricate image URLs.

## Allowed HTML

Headings `<h2>`–`<h4>`, `<p>`, `<strong>`, `<em>`, `<i>` (cursive), `<code>`, `<blockquote>`,
`<img>`, `<a>`, `<ul>`/`<ol>`/`<li>`, `<table>`, `<del>` (strikethrough), `<hr>`.

## Special Components

Copy these patterns exactly — the classes are what trigger the styling.

### Note / version box — checkered paper background, for focused callouts
```html
<div class="note-version">
<h2>For Marketers, Business Owners and Decision Makers</h2>
<p>One focused paragraph. Use <strong>bold</strong> for the key phrases.</p>
</div>
```

### Tip box — grey background with a light-bulb icon on the left
```html
<div class="note-tip">
<h3>Discover the benefits</h3>
<p>Short explanation of the tip or next step.</p>
<p><a href="https://example.com" class="action-button" rel="nofollow">Learn more</a></p>
</div>
```

### Action button — green call-to-action button (an `<a>`, usually wrapped in a `<p>`)
```html
<p><a href="https://example.com" class="action-button" rel="nofollow">Get the Module</a></p>
```

### Grid — half (50%) or third (33%) columns, each cell a grey `note` box
```html
<table class="view-view-grid">
<tbody>
<tr>
<td width="50%"><div class="note"><h3>Column one</h3><p>Text.</p></div></td>
<td width="50%"><div class="note"><h3>Column two</h3><p>Text.</p></div></td>
</tr>
</tbody>
</table>
```
Use `width="33%"` across three `<td>` cells for a three-column row.

### Book listing — heading + intro, a rule, then side-by-side (50%) links
Each `<li>` in `ul.guide-contents` renders at half width, so links/items sit two per row.
```html
<div class="note view-book-listings">
<h4>Providers</h4>
<p>Supported integrations, side by side.</p>
<hr>
<ul class="guide-contents">
<li><a href="https://www.drupal.org/project/provider_a" rel="nofollow">Provider A</a></li>
<li><a href="https://www.drupal.org/project/provider_b" rel="nofollow">Provider B</a></li>
</ul>
</div>
```

## Structure Tips

- Separate major sections with `<hr>`.
- Lead each `note-version` / `note-tip` with its own `<h2>`/`<h3>` so the box has a clear title.
- External links should carry `rel="nofollow"`.
- A complete skeleton for a new project lives in `example.html` — adapt it, don't ship it verbatim.

## Common Mistakes

| Mistake | Fix |
|---|---|
| Starting with a heading | First element must be one `<p>` preview paragraph. |
| Listing Drupal core / PHP under Requirements/Dependencies | Omit unless the constraint is unusual. |
| Using unsupported tags (`<span>`, `<div style>`, classes not listed) | Stripped on save — stick to the allowed set and named classes. |
| Overusing note boxes | They highlight focus; a page that's all boxes highlights nothing. |
| Guessing image URLs | Only embed images you actually captured or that already exist. |
| Writing the file without asking where | Confirm the output path first (default `PROJECT_DESCRIPTION.html` in the module folder). |
