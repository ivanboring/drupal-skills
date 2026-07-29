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

## Helper scripts

Run every script **from the ddev project root**, with `export TUT_SLUG=<tutorial-slug>` set
(a short kebab-case name for this tutorial, e.g. `commerce-checkout`). Scripts read
`lib.sh` for shared paths and settings.

| Script | Runs on | Purpose |
|---|---|---|
| `preflight.sh` | host | Check + set up ddev, container packages, agent-browser, awaz, Montserrat; create the build dir |
| `session.sh start\|stop [url]` | host | Bring up Xvfb `:99`, kiosk Chromium with remote debugging, wait for CDP; stop tears it down |
| `record-beat.sh start\|stop <NN>` | host | Start/stop the x11grab capture for beat `NN` |
| `hands.sh move\|click\|type64\|key\|hover ...` | container | The visible cursor and typing (called via `ddev exec`); type with `type64` (base64 in, decoded in-container) so metacharacters survive |
| `make-card.sh <NN> <seconds> <command-text>` | host | Render a command card into `beats/NN.mp4` |
| `finish-beat.sh <NN>` | host | Pad video to the narration, add lead/tail silence, mux audio, draw the caption bar |
| `check-beat.sh <NN>` | host | Sanity-check a beat: report duration, extract a still frame, flag stub/overlong captures |
| `concat.sh` | host | Concatenate `final/beat-*.mp4` into `final/tutorial.mp4` |

## Build directory

Everything lives under the ddev mount so host and container share one filesystem:

```
<project>/.tutorial-build/<slug>/
  storyboard.md
  hands.sh                 # copied here by preflight so the container can run it
  assets/Montserrat-*.ttf
  beats/NN.mp4            # raw silent capture for beat NN (or command card)
  audio/NN.mp3           # narration for beat NN, from awaz
  final/NN.caption.txt   # caption bar text for beat NN (one line)
  final/beat-NN.mp4      # padded + muxed + captioned
  final/tutorial.mp4     # concatenated result
```

Nothing is deleted at the end. The user may ask for changes.

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
a locally rendered slide (a command card or a static page) that lists the project and why it
matters, and tell the user why.

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

## Workflow

Create a todo per step.

1. **Preflight.** `export TUT_SLUG=<slug>` then `./skills/.../preflight.sh`. Confirm the
   ddev URL, username, and password with the user.

2. **Ask the intro question.** Ask whether the video should open with a why-this-matters /
   marketing intro over the module's drupal.org page, or go straight to the steps.

3. **Read the module first.** Read `<machine_name>.info.yml`, README, config forms,
   permissions, routing, and services to derive the *actual* setup steps from the code, not
   from assumptions. Same "read first" discipline as `drupal-module-documentation`.

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
   - **browser-action / intro / module-page:**
     1. `./record-beat.sh start NN`
     2. Drive the browser **inside the container** (host CDP is blocked, see Known tuning
        points): `ddev exec agent-browser --cdp http://127.0.0.1:9222 open <url>`,
        `snapshot -i`, `wait` as needed. To click or type an element, get its center in
        viewport pixels (which equal screen pixels in kiosk):
        ```
        ddev exec bash -lc "agent-browser --cdp http://127.0.0.1:9222 eval \
          \"(()=>{const el=document.getElementsByName('NAME')[0]||document.querySelector('SEL');const r=el.getBoundingClientRect();return Math.round(r.x+r.width/2)+' '+Math.round(r.y+r.height/2)})()\""
        ```
        Target form fields **by name** (`getElementsByName`), not by id: Drupal `#ajax` rebuilds
        regenerate element ids (`edit-key-provider` becomes `edit-key-provider--CBOP6vfGC3k`), so
        every id selector captured before a rebuild goes stale. Then move, click, and type with
        the hands, passing text as base64 so metacharacters survive `ddev exec`:
        ```
        ddev exec DISPLAY=:99 bash /var/www/html/.tutorial-build/<slug>/hands.sh move CX CY
        ddev exec DISPLAY=:99 bash /var/www/html/.tutorial-build/<slug>/hands.sh click
        B64="$(printf %s 'value to type' | base64 -w0)"
        ddev exec DISPLAY=:99 bash /var/www/html/.tutorial-build/<slug>/hands.sh type64 "$B64"
        ```
        Each beat is one action, so keep it short. Before typing into a field that may already
        hold text (search/filter fields keep their value across reloads), clear it first:
        `hands.sh key ctrl+a` then `type64`, or use `agent-browser fill` (which clears). Pace it
        like a human: move, small pause, click, then type. Leave the result on screen for a
        moment before stopping.

        **Native `<select>`:** its dropdown is an OS-level overlay invisible to the DOM, so
        clicking options directly does not work. Click the select, `type64` the option's
        **visible label** (type-ahead matches the option text, not the value, and fires `change`,
        so Drupal `#ajax` runs), then `hands.sh key Return`. Confirmed for provider, model, and
        plugin selects.

        **Long text (a prompt, a template):** per-key typing is slow, a ~1800-character field at
        60ms/key is a 135-second beat. Paste it instead: set the field's `.value` via `eval` (pass
        the text as base64 and `atob` it in the page), then dispatch `input` and `change`. Write
        the narration as "paste in..." rather than pretending it was typed.
     3. `./record-beat.sh stop NN`
   - **command-card:** `./make-card.sh NN 4 "composer require drupal/<name>"`.

8. **Generate narration.** For each beat, generate its one-sentence voice-over with the `speak`
   subcommand (the top-level `-v` is `--version` and writes no file; `--no-play` is required
   headless):
   ```
   awaz speak --voice-id <voice-id> --no-play -o .tutorial-build/<slug>/audio/NN.mp3 "<beat narration sentence>"
   ```
   Optional flags: `--speed 0.5-2.0`, `--stability 0-1`, `--style 0-1`, `--model-id <id>`.

9. **Finish each beat.** `./finish-beat.sh NN` for every beat. It length-fits the beat to
   `max(action, speech)`, adds a short lead/tail of silence, freeze-pads the video so it never
   ends before the narration, muxes the audio, and draws the caption bar. For the **last beat
   of a scene**, give a longer tail so there is a 1-2s pause before the next scene:
   `TUT_TAIL=1.5 ./finish-beat.sh NN`.

10. **Verify each beat, not just that the file exists.** Five separate failures in one run left
    beat files that existed at non-zero size but were wrong. Run `./check-beat.sh NN` (duration +
    a still frame + stub/overlong flags). Also: identical file size to the previous beat usually
    means nothing changed on screen, and **after a form-submit beat, read back the config the form
    was supposed to write** (`drush config:get ...`) - the strongest check that the on-camera
    typing actually landed correctly.

11. **Concatenate and present.** `./concat.sh` (the final encode of a long tutorial takes several
    minutes; it refuses to start if a prior encode is still running in the container), then show
    the user `.tutorial-build/<slug>/final/tutorial.mp4`. **Do not clean up.** Wait for change
    requests; re-record or re-finish only the affected beats and re-run `concat.sh`.

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
- **Drive native `<select>` by type-ahead.** Click it, `type64` the option's visible label,
  press Return. The dropdown overlay is invisible to the DOM, so clicking options directly fails.
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
| Trusting "file exists" as done | Verify with `check-beat.sh`, and for form beats read back the saved config (`drush config:get`). |
