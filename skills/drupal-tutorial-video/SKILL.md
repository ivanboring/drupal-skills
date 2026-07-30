---
name: drupal-tutorial-video
description: Use when recording a narrated screencast or video tutorial that shows how to set up or configure a Drupal module, capturing a ddev site in the browser at 1920x1080 with a visible mouse cursor, typed form input, ElevenLabs voice-over, and a caption bar, then muxing and concatenating the scenes into one MP4.
---

# Drupal Tutorial Video

## Overview

Records a narrated 1920x1080 MP4 that shows how to set up a Drupal module. The skill reads
the module to learn the real setup, writes a storyboard for approval, then records each step
as a **beat** (one narration sentence + its action) with a visible cursor and
character-by-character typing, generates ElevenLabs narration per beat, length-fits each beat
so the words stay in sync with the picture, overlays a caption bar, and concatenates the
beats into one video.

The recording happens inside the ddev **web container** on a virtual X display (`:99`) at
1920x1080. Two tools split the work:

- **agent-browser** (the brain): navigate, read the accessibility tree, locate an element,
  return its on-screen box, wait for page state. Its CDP input is synthetic and invisible,
  so it never does the visible clicking.
- **xdotool** (the hands): move the real X11 pointer to that box in small steps for smooth
  motion, click, and type with a per-key delay. Because the pointer on `:99` is real,
  `ffmpeg -f x11grab` captures it natively. What moves is exactly what clicks.

Terminal commands that cannot be shown in the browser (`composer require`, `drush en`,
`ddev ...`) are rendered as still **command cards**, never as a recorded terminal.

## Requirements (hard)

- A running **ddev** project. You need its site URL, an admin username, and a password.
- **agent-browser** in the web container (preflight installs it there with `npm`; it drives
  Chromium over CDP on the container's localhost). See
  https://github.com/vercel-labs/agent-browser.
- **awaz** (`npm i -g awaz`, https://github.com/ahmadawais/awaz), an ElevenLabs TTS wrapper.
  Needs `ELEVENLABS_API_KEY` in the environment (NOT `@elevenlabs/cli`, which has no TTS).
  The key must have the **Text to Speech** and **Voices (read)** permissions. TTS lives behind
  the `speak` subcommand: `awaz speak --voice-id <id> --no-play -o out.mp3 "text"`. The
  top-level `-v` is `--version` (it prints the version, exits 0, and writes **no file**, a
  silent failure that only surfaces at `finish-beat.sh`), and `--no-play` is required headless
  or awaz tries to open a speaker device and fails. Store the key somewhere like
  `~/.config/elevenlabs/key` and export it before recording; nothing sets it for you.
- ffmpeg, Xvfb, xdotool, chromium in the web container (preflight installs these).
- Montserrat TTF for the caption bar (preflight downloads it if missing).

Run `preflight.sh` first; it checks and sets up all of the above.

**Contrib modules installed from a git source can block every `composer require`.** If a contrib
module sits on a local branch with unpushed commits, composer refuses *any* require (not just ones
touching that package) because it wants to restore the locked ref:
`Source directory .../contrib/<name> has unpushed changes on the current branch`. Non-destructive
workaround, after confirming the commit is genuinely local-only (`git -C <dir> branch -r --contains
<sha>` returns nothing) and taking a safety bundle:

```
git -C web/modules/contrib/<name> bundle create /backup/<name>.bundle --all
git -C web/modules/contrib/<name> checkout <locked ref from composer.lock>
```

The branch still exists on disk and can be checked out again afterwards.

## Helper scripts

Run every script **from the ddev project root**, with `export TUT_SLUG=<tutorial-slug>` set
(a short kebab-case name for this tutorial, e.g. `commerce-checkout`). Scripts read
`lib.sh` for shared paths and settings.

| Script | Runs on | Purpose |
|---|---|---|
| `preflight.sh` | host | Check + set up ddev, container packages, agent-browser, awaz, Montserrat; create the build dir and copy the container helpers |
| `session.sh start\|stop [url]` | host | Bring up Xvfb `:99`, kiosk Chromium with remote debugging, wait for CDP; stop tears it down |
| `record-beat.sh start\|stop <NN>` | host | Start/stop the x11grab capture for beat `NN` |
| `record-slide.sh <NN> [secs]` | host | Record a concept/intro **slide** beat (local HTML at `TUT_SLIDES_URL`), short capture |
| `ui.sh <verb> ...` | host | The browser-action driver: find an element (`name`/`nth`/`link`/`any`/`sel`/`text`), scroll it into view, move + click with the visible cursor, type, paste |
| `hands.sh move\|click\|type64\|key\|hover ...` | container | The raw cursor and typing (called by `ui.sh` via `ddev exec`); `type64` = base64 in, decoded in-container so metacharacters survive |
| `make-card.sh <NN> <seconds> <command-text>` | host | Render a command card into `beats/NN.mp4` |
| `trim.sh <NN> head\|tail <secs>` | host | Trim an over-long capture, keeping `beats/NN.orig.mp4` |
| `check-beat.sh <NN>` | host | Sanity-check one beat: duration, a still frame, stub/overlong flags |
| `audit.sh` | container | Audit the whole set at once: flag `AUDIO-TIGHT` and `DEAD-AIR` beats |
| `fade-audio.sh` | container | Fade the abrupt tail of every narration file and pad real silence (before finishing) |
| `deadair.sh dry\|apply\|restore` | container | Cut trailing frozen tails (`freezedetect -75dB`), verify each trim, revert bad ones |
| `finish-beat.sh <NN>` | host | Pad video to the narration, add lead/tail silence, mux audio, draw the caption bar |
| `finish-all.sh` | host | Run `finish-beat.sh` over every beat; scene-final beats get a longer tail (derived, not hardcoded) |
| `concat.sh` | host | Concatenate `final/beat-*.mp4` into `final/tutorial.mp4` |

Container helpers (`hands.sh`, `audit.sh`, `fade-audio.sh`, `deadair.sh`) are copied into the build
dir by preflight and run inside the container, e.g.
`ddev exec bash /var/www/html/.tutorial-build/<slug>/audit.sh` (this container path is `$CDIR` in
`lib.sh`, used as shorthand below). They loop over 90+ files in a
single script file on purpose: an inline `ddev exec bash -lc "for ...; do"` loop breaks, because the
host shell expands `$var` before the container ever sees it (see "Getting commands past `ddev exec`").

## Build directory

Everything lives under the ddev mount so host and container share one filesystem:

```
<project>/.tutorial-build/<slug>/
  storyboard.md
  scene-final.txt          # optional: beat numbers that end a scene (finish-all.sh reads it)
  hands.sh                 # container helpers, copied here by preflight so the container can run them
  audit.sh  fade-audio.sh  deadair.sh
  assets/Montserrat-*.ttf
  slides/NN.html           # local concept/intro slides (served to the kiosk browser)
  beats/NN.mp4             # raw silent capture for beat NN (or command card)
  beats/NN.orig.mp4        # untouched capture kept by trim.sh
  beats/NN.pretrim.mp4     # untouched capture kept by deadair.sh
  audio/NN.mp3             # narration for beat NN, from awaz (faded)
  audio/NN.orig.mp3        # untouched narration kept by fade-audio.sh
  final/NN.caption.txt     # caption bar text for beat NN (one line)
  final/beat-NN.mp4        # padded + muxed + captioned
  final/tutorial.mp4       # concatenated result
```

Nothing is deleted at the end. The user may ask for changes. The `.orig`/`.pretrim` copies mean any
trim or fade can be redone without re-recording.

## Scenes and beats

A **beat** is the atomic unit: one narration sentence and the single action it describes,
recorded as its own clip. A **scene** is just a storyboard grouping of consecutive beats
(a heading like "Configure the provider"); it has no separate file.

Beats are the reason narration stays in sync with the picture. Each beat's video and its
narration are the same clip, so the words cannot drift from the action: `finish-beat.sh`
length-fits each beat to `max(action, speech)`, and the beats concatenate in order. Do not
record a whole scene as one take with one long narration; that is what makes audio and video
drift.

Beats are numbered globally, `01`, `02`, `03`, ... in play order. The scene grouping lives
only in `storyboard.md` for human organization.

**The beat number is the edit timeline; leave gaps.** `concat.sh` orders by a plain filename sort
of `final/beat-*.mp4`, so the number *is* the play order. Two consequences:

- **There is no room to insert.** Adding a beat between 89 and 90 means renumbering, and a
  `beat-89b` scheme is unsafe (plain `sort` is locale-collated and may ignore punctuation).
  Reordering requests arrive *after* everything is recorded, so **number in steps of 10**
  (`010`, `020`, `030`, ...) from the start; insertion then costs nothing. When a late edit needs a
  new beat mid-sequence and you did not leave gaps, the cheap move is to **swap two adjacent beats**
  whose content can trade places (two slides, say).
- **Removing beats is free.** Gaps concatenate fine; cut a beat's file and nothing else changes.

**Derive the scene-final list, never hardcode it.** `finish-all.sh` gives the last beat of each
scene a longer tail. Feed it the list from `scene-final.txt` (or a `beats.json` with
`scene_final: true`), produced from the storyboard, so reordering cannot silently leave the pause on
the wrong beat.

## Beat taxonomy

| Type | Shows | Produced by |
|---|---|---|
| `intro` | The module's drupal.org project page (`drupal.org/project/<machine_name>`), narration on why it matters / marketing. Only if the user opts in. | browser-record |
| `module-page` | The module page as reference | browser-record |
| `browser-action` | A real setup step in the ddev site, visible cursor and typing | agent-browser + hands.sh + record-beat.sh |
| `command-card` | A terminal command that cannot be shown in-browser | make-card.sh |
| `outro` | Recap / call to action | browser-record or command-card |

**Intro caveat:** the kiosk Chromium is served **HTTP 406** by `drupal.org` (looks like TLS or
client-hint fingerprinting: `curl` from the same container with Chrome-like headers gets 200, the
browser with a normal `Chrome/*` UA does not, and UA / `Accept*` / `--lang` flags do not fix it).
So the `intro` and `module-page` types that open `drupal.org/project/<machine_name>` may not be
recordable here. If `agent-browser open` fails with `ERR_HTTP_RESPONSE_CODE_FAILURE`, fall back to
a locally rendered slide (`record-slide.sh`) that lists the project and why it matters, keep the
project URL in the caption, and tell the user why.

Slides are cheap: machine-generated HTML slides beat screenshots for concept beats (regenerating all
34 after a "3 lanes -> 5 lanes" content change was one script run). Text-to-image is fine for
**backdrops** (a hero image at `opacity:.42` behind real HTML type) but useless for text - render the
type as HTML, and leave the bottom ~15% empty for the caption bar.

## Getting commands past `ddev exec`

Almost every hard bug in this skill traces to one fact: `ddev exec` (and the `cexec` helper)
re-parse their arguments through an extra shell before the container sees them. Anything with
quotes, braces, backslashes, `$(...)`, `$var`, or commas is mangled, and it almost always fails
**silently** rather than erroring. Real failures from one run:

- A wait loop with `$(seq ...)` inside `cexec` killed the container shell before its `pkill` ran,
  so captures never stopped and later beats came out as 48-byte stubs.
- Typing the regex `/[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}/i` produced `...+.[a-z]2/i` on screen:
  brace expansion ate `{2,}` and `\.` lost its backslash. The beat looked fine but the pattern
  could not match an email, so the guardrail being demonstrated would not have worked.
- `agent-browser eval "location.hash='pre'"` lost the quotes, evaluated `location.hash=pre`
  (named-element access to `<div id="pre">`), and silently set the hash to garbage. Three beats
  recorded the wrong state; the only tell was byte-identical `.mp4` files.

Rules:

- Keep each container command to a **single simple statement**. Do all control flow (loops, waits,
  retries) on the host, one plain `cexec` per iteration.
- Type through `hands.sh type64`: base64 on the host (`printf %s 'text' | base64 -w0`), decode past
  the boundary in the container. Never use the plain `type` path for anything but bare ASCII words.
- For `agent-browser eval`, wrap the whole call in `bash -lc` with escaped double quotes and use
  **single quotes only** inside the JS expression, or avoid `eval` and navigate with a hash URL.
- **Loops break even inside `bash -lc`.** `ddev exec bash -lc "for t in 1 2 3; do ffmpeg -ss $t ...; done"`
  fails with `t: unbound variable` because the host shell expands `$t` to empty first. Either loop on
  the host (one `ddev exec` per iteration) or put the loop in a **script file** and run
  `ddev exec bash /var/www/html/.../script.sh` (much faster for 90+ iterations; this is why the
  container helpers are files, not inline loops).
- **`drush ev` with non-trivial quoting silently produces nothing.** A one-liner iterating plugin
  definitions returned empty output at exit 0; the same code as a file via `drush php:script foo.php`
  worked. Prefer `php:script` for anything beyond a bare expression.

## Workflow

Create a todo per step.

1. **Preflight.** `export TUT_SLUG=<slug>` then `./skills/.../preflight.sh`. Confirm the
   ddev URL, username, and password with the user.

2. **Ask the intro question.** Ask whether the video should open with a why-this-matters /
   marketing intro over the module's drupal.org page, or go straight to the steps.

3. **Read the module first, and map the whole followable path.** Read `<machine_name>.info.yml`,
   README, config forms, permissions, routing, and services to derive the *actual* setup steps from
   the code, not from assumptions. Same "read first" discipline as `drupal-module-documentation`.
   Two things a "technically correct" tutorial still gets wrong:
   - **Module-set completeness.** A tutorial you cannot follow is a defect. List every route the
     later scenes depend on and check each resolves *with the set you install*. Admin UIs often live
     in a separate submodule (ECA needs `eca_ui` for `/admin/config/workflow/eca`; installing
     `eca` + `eca_content` + `eca_tool` alone leaves the viewer with no way in). One module filter
     can sometimes cover a whole set when the descriptions cross-reference each other.
   - **Confirm a "missing" feature from a second angle before acting on it.** A throwaway probe once
     reported zero action plugins and nearly got a working module written off; they existed the
     whole time. In plugin-land, `getDefinition('<known-bad-id>')` is a cheap oracle: its exception
     enumerates every valid id.

4. **Write the storyboard.** Write `.tutorial-build/<slug>/storyboard.md` as scenes (headings)
   broken into **beats**. Each beat is one narration sentence and the single action it
   describes, and carries: the global beat number, `type`, the on-screen action(s), the
   narration sentence, and the one-line caption. For any beat that navigates to or acts on a
   route, put the admin path or link in that caption (see Caption bar). Keep beats to one
   sentence + one action so the narration cannot drift. **Get the user's approval before
   recording.**

5. **Pick a voice.** Run `awaz voices`, present the options with their names and ids, and
   ask the user which voice to use. Remember the chosen **voice id** for `--voice-id`.

6. **Start the session.** `./session.sh start "<site-url>"`. This opens the kiosk browser on
   `:99` inside the container.

7. **Record beat by beat.** For each beat, in order:
   - Write the caption to `final/NN.caption.txt` (one line, plain).
   - **browser-action:**
     1. `./record-beat.sh start NN`
     2. Drive the browser with **`ui.sh`**, which resolves the element, scrolls it into the safe
        viewport band, and moves + clicks with the visible cursor (all the `ddev exec` quoting lives
        in one place; see "Finding and clicking elements"):
        ```
        ./ui.sh open  "<url>"
        ./ui.sh click name "modules[<machine_name>][enable]"   # find -> scroll into view -> move + click
        ./ui.sh type  "a value to type"                        # metacharacter-safe (type64)
        ./ui.sh click nth  "op:1"                              # the 2nd name="op" button, e.g. Save
        ```
        Pick the matcher for the target: `name` for form fields, `nth` for same-named submit
        buttons, `link`/`any` for admin links and React rows. Each beat is one action, so keep it
        short. Before typing into a field that may already hold text (search/filter fields keep
        their value across reloads), clear it first (`./ui.sh key ctrl+a` then `type`). Pace it like
        a human. Leave the result on screen for a moment before stopping.
     3. `./record-beat.sh stop NN`
   - **slide (concept / intro / outro):** `TUT_SLIDES_URL=<base> ./record-slide.sh NN`. Local HTML
     is the practical answer for concept beats and for anything that would open `drupal.org` (which
     406s the kiosk browser). Keep the project URL in the caption. Leave the bottom ~15% of each
     slide empty for the caption bar.
   - **command-card:** `./make-card.sh NN 4 "composer require drupal/<name>"`.

   **Beats that share one page load must be recorded as one continuous sequence.** If beats 33-35
   depend on checkbox state persisting across a client-side filter change, re-recording one in
   isolation loses that state.

8. **Generate narration.** For each beat, generate its one-sentence voice-over with the `speak`
   subcommand (the top-level `-v` is `--version` and writes no file; `--no-play` is required
   headless):
   ```
   awaz speak --voice-id <voice-id> --no-play -o .tutorial-build/<slug>/audio/NN.mp3 "<beat narration sentence>"
   ```
   Optional flags: `--speed 0.5-2.0`, `--stability 0-1`, `--style 0-1`, `--model-id <id>`.

9. **Post-production on the raw material (before finishing).** Two passes must run before
   `finish-beat.sh` muxes and pads (see "Post-production: dead air and audio"):
   - **Fade narration tails:** `ddev exec bash $CDIR/fade-audio.sh`. ElevenLabs ends each line
     mid-sound, so unfaded audio clips audibly against the padded silence.
   - **Trim trailing dead air:** `ddev exec bash $CDIR/audit.sh` to see which beats run long, then
     `ddev exec bash $CDIR/deadair.sh dry` and `... apply` (it verifies each cut and reverts bad
     ones). Use `./trim.sh NN head|tail <secs>` for beats deadair leaves alone (a blinking cursor
     never reads as frozen).

10. **Finish the beats.** `./finish-all.sh` runs `finish-beat.sh` over every beat and gives
    scene-final beats a longer tail (from `scene-final.txt`). Per beat it length-fits to
    `max(action, speech)`, adds lead/tail silence, freeze-pads the video so it never ends before the
    narration, muxes the audio, and draws the caption bar. (One beat: `./finish-beat.sh NN`, or
    `TUT_TAIL=1.5 ./finish-beat.sh NN` for a scene-final pause.)

11. **Verify the whole set, not just that files exist.** Five separate failures in one run left beat
    files that existed at non-zero size but showed the wrong state. Run `./check-beat.sh NN` on
    anything suspect (duration + a still frame + stub/overlong flags) and `audit.sh` for a one-pass
    pacing sweep. Identical file size to the previous beat usually means nothing changed on screen.
    And **after any form-submit beat, read the state back** instead of eyeballing the video:
    `drush config:get <id>` for config (prefer specific keys over scanning YAML), `drush pml` for
    module state, `drush sqlq` for content. This is the strongest check that the on-camera action
    landed.

12. **Concatenate and present.** `./concat.sh` (the final encode of a long tutorial takes several
    minutes; it refuses to start if a prior encode is still running in the container), then show the
    user `.tutorial-build/<slug>/final/tutorial.mp4`. **Do not clean up.** Wait for change requests;
    re-record or re-finish only the affected beats and re-run `concat.sh`.

## Caption bar

`finish-beat.sh` draws a full-width bar across the bottom ~9% of the frame:
`drawbox` filled `black@0.94`, then centered white Montserrat text from
`final/NN.caption.txt` with `expansion=none`. Keep captions to one short line. An empty caption
file means no bar for that beat. Two things learned the hard way: at `black@0.85` the page text
showed through and fought the caption (hence `0.94`), and without `expansion=none` `drawtext`
parses `%{...}` and backslashes even from a `textfile`, so a caption containing a path, `%`, or a
regex rendered as an **empty black bar** with no error.

**Show the path or link in the caption.** When a beat navigates somewhere or acts on a
specific route, put the admin path (or URL) in the caption so a viewer can follow along
without pausing. Use the route the user actually types or clicks, not the narration
restated:

- Navigating to a config page: `Configuration > System > Site information (/admin/config/system/site-information)`
- Clicking a menu link or tab: `Manage > Extend (/admin/modules)`
- A command-card beat: show the command itself, e.g. `composer require drupal/<name>`.

Keep it to one line: if the breadcrumb plus path is too long, show just the path
(`/admin/config/system/site-information`). Paths are literal, so they are exempt from the
prose style rules (a real path may contain characters the style section otherwise avoids).

## Narration writing style

The spoken narration and captions use the same voice as the other skills in this repo:
plain, direct, terse, active voice. No em dashes or en dashes. No marketing hype or
subjective qualifiers in the step narration (the opt-in intro may say why the module
matters, but still in verifiable terms). No emojis.

## Finding and clicking elements (`ui.sh`)

`ui.sh` is the browser-action driver. It resolves an element to a screen coordinate, scrolls it into
the safe band, refuses hidden/zero-size boxes, then moves and clicks with the visible cursor.
Everything below was a real failure that produced a valid-looking `.mp4` of the wrong state.

**Off-viewport clicks fail silently.** A click below **y≈1000** or above **y≈80** lands outside the
1080 kiosk viewport. `xdotool` reports success, the beat records normally, and the form simply never
submits (a Save button at y=1099, "below the fold"). `ui.sh` scrolls the target to mid-screen and
**re-measures** before clicking. agent-browser has no negative scroll, so a target above the fold
needs `scroll up N`.

**Four matcher kinds, not one:**

| Kind | Use for |
|---|---|
| `name` | Form fields (the default). Survives `#ajax` id regeneration. |
| `nth`  | Same-named buttons: **every Drupal submit is `name="op"`**, so "Test Connection" and "Save" collide. `op:0`, `op:1`. DOM order is **not** visual order. |
| `link` | Anchors by **exact** text. Beats hidden sidebar `<button>Edit</button>` controls that a text search grabs first. |
| `any`  | **React UIs**: clickable rows are plain `<div>`s a curated tag list never sees. Exact text, **smallest visible** match, so you get the row, not its container. |

Plus `sel` (raw CSS) and `text` (substring over curated tags). **Substring matching is dangerous**
on admin pages: `text "Lock"` matched **"Blocks"** in the sidebar and threw the cursor across the
screen. Prefer `link`/`any`/exact for short words, or scope the search to a container.

**Reject invisible and zero-size elements.** `#states`-hidden fields (an Authorization-prefix that
only appears once a key is chosen) return a box of `0,0`; moving there parks the cursor in the
top-left corner on camera. `ui.sh` refuses `0,0` and filters matchers on
`getBoundingClientRect().width > 0` so hidden duplicate controls do not win.

**Field names worth remembering:**

- Node form title: `title[0][value]` (not `title`)
- Module enable checkbox: `modules[<machine_name>][enable]`
- Module filter: `text`

**Verify with `check-beat.sh`, not a post-hoc screenshot.** An open `<select>` dropdown, a hover
state, or a tooltip is gone by the time a screenshot runs; the recorded frame is the truth.

## Shadow DOM, tokens, and React fields

- **Shadow DOM is invisible to selectors but not to the screen.** A Modeler component panel put its
  `channel_id`/`text` fields in a shadow root; `document.querySelectorAll('input,textarea')`
  returned 3 for the whole page while two more were plainly visible. `xdotool` needs only screen
  coordinates (from a screenshot), so click and type at raw coordinates, then verify by reading the
  saved config afterwards.
- **Native `<select>` dropdowns DO record.** They are invisible to the **DOM**, not to the
  **screen** - `x11grab` captures the open dropdown and every option fine. Drive them by type-ahead
  (click the select, `type64` the option's visible label, press Return, which fires `change` so
  `#ajax` runs), and open the dropdown on camera when the options themselves are the point of the
  beat.
- **Typing `[` opens a token browser** that eats the rest of the line: `Node [node:nid]...` leaves
  `Node [` in the field and the remainder in an "INSERT A TOKEN" popup. Insert via the clipboard,
  which fires no per-keystroke handlers:
  ```
  agent-browser --cdp $CDP clipboard write "Node [node:nid] with [node:title] got updated."
  ./ui.sh key ctrl+v
  ```
- **React controlled inputs ignore `.value =`.** The `ui.sh paste` trick (`.value` + `input` event)
  works for Drupal core forms but not React; for a React field set through the **native setter** and
  dispatch, or the component state never updates.

## Post-production: dead air and audio

Run these once after all beats are recorded and narrated, before `finish-all.sh`. Both fixed
user-visible defects on the first cut.

**Audit the whole set first.** `ddev exec bash $CDIR/audit.sh` compares video/speech/final duration
across every beat in one pass (a single run surfaced 27 pacing problems). It flags `AUDIO-TIGHT` (too
little breath after narration) and `DEAD-AIR` (video running well past speech).

**Fade every narration tail.** ElevenLabs gives no trailing decay - the last 150ms of every file
sits at -16..-29 dB, audibly clipped against the padded silence. `ddev exec bash $CDIR/fade-audio.sh`
fades the last 120ms and appends real silence, always deriving from an untouched `.orig` so a re-run
cannot double-fade. Do this **before** `finish-beat.sh` muxes the audio. Verify with `volumedetect`
over the final 150ms: it should read about -91 dB.

**Trim trailing dead air, then verify the trim.** Beats routinely ran 5-19s past the last on-screen
change because the capture slept waiting for a page. `ddev exec bash $CDIR/deadair.sh apply` cuts the
frozen tail. Two tunings were hard-won:

- `freezedetect=n=-75dB:d=0.7`, **not** the `-58dB` default: at `-58dB` a checkbox tick counts as
  "frozen" and the trim silently cuts the click, ending the beat in the pre-click state. (A
  `select='gt(scene,...)'` approach was also tried and reported no changes at all - do not use it.)
- After each cut it compares the trimmed clip's last frame against the original's (`psnr`, revert if
  < ~38 dB). A beat ending in the wrong state is worse than a slow beat.

Blind spot: a **blinking text cursor** in a focused input never registers as frozen, so those beats
need a manual head-trim and a human look at the end frame. Static slides shorter than ~6.5s are left
alone (`finish-beat.sh` freeze-pads them back anyway).

**Head vs tail when trimming manually (`trim.sh`):** keep the **tail** when the payoff is the result
(install confirmation, saved message, JSON response); keep the **head** when the action is the content
(ticking boxes, typing, opening a picker). `trim.sh` keeps `NN.orig.mp4` so any cut can be redone.

## Recording gotchas

General lessons for recording a Drupal admin UI in a headless browser:

- **Clear text inputs before typing.** GET filter and search fields keep their value across
  reloads, so typing again appends ("Powered byPowered by") and the filter breaks. Clear
  first with `hands.sh key ctrl+a` then type, or use `agent-browser fill`.
- **Pre-seed AJAX-dependent forms.** Forms that rebuild dependent fields via Drupal AJAX (a
  provider select that repopulates a model select, etc.) are unreliable to drive live. Set
  the value first with `drush config:set` so the form loads already settled, then only
  demonstrate the final selection on camera.
- **Avoid batch operations on camera.** Actions that trigger a batch (some imports, adding a
  language with interface translation) rely on a meta-refresh that stalls in the headless
  browser. Disable or pre-run the batch with `drush` before recording so the page redirects
  instantly.
- **Target fields by name, not id.** Drupal `#ajax` rebuilds regenerate element ids, so a
  selector grabbed before the rebuild goes stale. Use `getElementsByName('...')[0]`.
- **Drive native `<select>` by type-ahead** (click, `type64` the visible label, Return). The
  dropdown is invisible to the DOM so clicking options directly fails, but it **does record** on
  screen - open it on camera when the options are the point. See "Shadow DOM, tokens, and React
  fields".
- **Paste long text, don't type it.** A ~1800-char field typed key-by-key is a >2-minute beat.
  Set `.value` via `eval` (base64 in, `atob` in the page), dispatch `input`+`change`, and narrate
  it as "paste in...".
- **Never put control flow or `$(...)` in a container command.** See "Getting commands past
  `ddev exec`": keep each `cexec` to one simple statement, and type through `type64`.

## Known tuning points (verify on the first live run)

- **CDP: use the container.** Host CDP does not work: ddev maps the exposed port to a dynamic
  host port, and Chromium's DevTools rejects the forwarded connection because the Host-header
  port no longer matches its listening port (DNS-rebinding protection; `--remote-allow-origins=*`
  only covers Origin, not Host). Always drive agent-browser inside the container against
  localhost: `ddev exec agent-browser --cdp http://127.0.0.1:9222 ...`.
- **Cursor alignment.** `get box` returns viewport coordinates. Kiosk Chromium at 0,0 with
  `--force-device-scale-factor=1` makes viewport pixels equal screen pixels, but a small
  fixed offset may be needed. Take a screenshot mid-beat and adjust if the click misses.
- **Window focus for typing.** `xdotool type` goes to the focused window. session.sh
  activates the Chromium window; if typing lands nowhere, re-activate it before typing.
- **Non-Latin languages need CJK fonts.** Preflight installs `fonts-noto-cjk` so Japanese,
  Chinese, and Korean render instead of tofu boxes. Chromium caches fonts at startup, so if
  you install fonts after a session is running, restart it (`session.sh stop && start`); a
  page reload is not enough.
- **drupal.org serves the kiosk browser HTTP 406.** Looks like TLS or client-hint fingerprinting:
  `curl` from the same container with Chrome-like headers gets 200, the browser (a normal
  `Chrome/*` UA) does not, and UA / `Accept*` / `--lang` flags do not fix it. Treat `intro` and
  `module-page` beats that open `drupal.org` as possibly unrecordable, and have a local-slide
  fallback ready (see the intro caveat under Beat taxonomy).

## Common mistakes

| Mistake | Fix |
|---|---|
| Using `@elevenlabs/cli` for narration | It has no TTS. Use `awaz` (`npm i -g awaz`). |
| agent-browser doing the click | CDP clicks are invisible in the recording. Click with `hands.sh`; use agent-browser only to find the element. |
| Recording a terminal | Terminal commands are command cards, not screen recordings. |
| Intro on the generic drupal.org site | The intro shows the module's own project page, `drupal.org/project/<machine_name>`. |
| Ephemeral container packages | Installs are lost on `ddev restart` unless in `.ddev/config.tutorial-video.yaml` (preflight writes this). |
| Cleaning up before approval | Leave the build dir intact until the user approves. |
| Narration and video out of sync | Author one sentence + one action per beat; `finish-beat.sh` length-fits each beat. Never record a whole scene as one long take. |
| Driving agent-browser from the host | Host CDP is blocked; run it in the container: `ddev exec agent-browser --cdp http://127.0.0.1:9222 ...`. |
| Typing into a field that still holds text | Clear it first (`hands.sh key ctrl+a` then type, or `agent-browser fill`). |
| Recording an AJAX select or batch page live | Pre-seed with `drush config:set` and record the settled state. |
| Caption omits where the step happens | For any navigation or route action, show the admin path or link in the caption (e.g. `/admin/modules`). |
| Wrong `awaz` invocation | Use `awaz speak --voice-id <id> --no-play -o file.mp3 "text"`. Top-level `-v` is `--version` and writes nothing; `--no-play` is required headless. |
| Loops or `$(...)` inside `ddev exec` | The container shell mangles them before running. Keep container commands to one simple statement; loop on the host. |
| `hands.sh type` for text with metacharacters | Braces, backslashes, and quotes get mangled by `ddev exec`. Always `type64` (base64 in, decoded in-container). |
| Selecting by element id after an AJAX rebuild | Ids regenerate. Target by name (`getElementsByName`). |
| Typing a long prompt key-by-key | Minutes-long beat. Paste via `eval` (base64/`atob`) and narrate as "paste in...". |
| Numbers with comma decimals reaching ffmpeg | A comma-decimal locale breaks the filtergraph. Scripts export `LC_ALL=C LC_NUMERIC=C`; keep that when editing them. |
| Re-running `concat.sh` after killing it | The old container ffmpeg keeps writing; a second racing encode corrupts `tutorial.mp4`. Clear it (`ddev exec pkill -x ffmpeg`) first; the script now guards against it. |
| Trusting "file exists" as done | Verify with `check-beat.sh`, and for form beats read back the saved state (`drush config:get` / `pml` / `sqlq`). A valid-length `.mp4` of the wrong state is the common failure. |
| Off-viewport click that silently no-ops | Below y≈1000 / above y≈80 misses the 1080 viewport and never submits. `ui.sh` scrolls into view and re-measures. |
| `getElementsByName('op')[0]` for a submit | Every Drupal submit is `name="op"`; DOM order ≠ visual order. Use `nth` (`op:0`, `op:1`) and confirm which is which. |
| Substring text match on an admin page | "Lock" matches "Blocks". Use `link`/`any`/exact for short words. |
| Believing a `<select>` can't be recorded | It records fine; it is invisible to the DOM, not the screen. Drive by type-ahead. |
| Installing a module set with no admin UI | List the routes later scenes need and check each resolves; the UI may be a separate submodule (e.g. `eca_ui`). |
| `composer require` fails on a git-checkout contrib | The package has unpushed local commits. Bundle it, check out the locked ref, then require. |
| Narration tail sounds clipped | ElevenLabs has no decay; run `fade-audio.sh` before finishing. |
| Trimming dead air without verifying | `freezedetect -58dB` cuts clicks. Use `-75dB` and psnr-verify the end frame (`deadair.sh`). |
| Numbering beats 1,2,3 with no gaps | Reorders arrive after recording and there is no room to insert. Number in 10s, or swap adjacent beats. |
| Hardcoding the scene-final beat list | Reordering leaves the pause on the wrong beat. Derive it (`scene-final.txt` / `beats.json`). |
