---
name: drupal-tutorial-video
description: Use when recording a narrated screencast or video tutorial that shows how to set up or configure a Drupal module, capturing a ddev site in the browser at 1920x1080 with a visible mouse cursor, typed form input, ElevenLabs voice-over, and a caption bar, then muxing and concatenating the scenes into one MP4.
---

# Drupal Tutorial Video

## Overview

Records a narrated 1920x1080 MP4 that shows how to set up a Drupal module. The skill reads
the module to learn the real setup, writes a storyboard for approval, records the browser
performing each step with a visible cursor and character-by-character typing, generates
ElevenLabs narration, overlays a caption bar, and concatenates the scenes into one video.

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
- **agent-browser** installed (host). See https://github.com/vercel-labs/agent-browser.
- **elevenlabs-cli** (the Rust crate `cargo install elevenlabs-cli`, NOT `@elevenlabs/cli`,
  which has no text-to-speech) with an API key configured.
- ffmpeg, Xvfb, xdotool, chromium in the web container (preflight installs these).
- Montserrat TTF for the caption bar (preflight downloads it if missing).

Run `preflight.sh` first; it checks and sets up all of the above.

## Helper scripts

Run every script **from the ddev project root**, with `export TUT_SLUG=<tutorial-slug>` set
(a short kebab-case name for this tutorial, e.g. `commerce-checkout`). Scripts read
`lib.sh` for shared paths and settings.

| Script | Runs on | Purpose |
|---|---|---|
| `preflight.sh` | host | Check + set up ddev, container packages, agent-browser, elevenlabs-cli, Montserrat; create the build dir |
| `session.sh start\|stop [url]` | host | Bring up Xvfb `:99`, kiosk Chromium with remote debugging, wait for CDP; stop tears it down |
| `record-scene.sh start\|stop <NN>` | host | Start/stop the x11grab capture for scene `NN` |
| `hands.sh move\|click\|type\|key\|hover ...` | container | The visible cursor and typing (called via `ddev exec`) |
| `make-card.sh <NN> <seconds> <command-text>` | host | Render a command card into `scenes/NN.mp4` |
| `finish-scene.sh <NN>` | host | Pad video to the narration, add lead/tail silence, mux audio, draw the caption bar |
| `concat.sh` | host | Concatenate `final/scene-*.mp4` into `final/tutorial.mp4` |

## Build directory

Everything lives under the ddev mount so host and container share one filesystem:

```
<project>/.tutorial-build/<slug>/
  storyboard.md
  hands.sh                 # copied here by preflight so the container can run it
  assets/Montserrat-*.ttf
  scenes/NN.mp4            # raw silent capture (or command card)
  audio/NN.mp3            # narration from elevenlabs-cli
  final/NN.caption.txt    # caption bar text for scene NN (one line)
  final/scene-NN.mp4      # padded + muxed + captioned
  final/tutorial.mp4      # concatenated result
```

Nothing is deleted at the end. The user may ask for changes.

## Scene taxonomy

| Type | Shows | Produced by |
|---|---|---|
| `intro` | The module's drupal.org project page (`drupal.org/project/<machine_name>`), narration on why it matters / marketing. Only if the user opts in. | browser-record |
| `module-page` | The module page as reference | browser-record |
| `browser-action` | A real setup step in the ddev site, visible cursor and typing | agent-browser + hands.sh + record-scene.sh |
| `command-card` | A terminal command that cannot be shown in-browser | make-card.sh |
| `outro` | Recap / call to action | browser-record or command-card |

## Workflow

Create a todo per step.

1. **Preflight.** `export TUT_SLUG=<slug>` then `./skills/.../preflight.sh`. Confirm the
   ddev URL, username, and password with the user.

2. **Ask the intro question.** Ask whether the video should open with a why-this-matters /
   marketing intro over the module's drupal.org page, or go straight to the steps.

3. **Read the module first.** Read `<machine_name>.info.yml`, README, config forms,
   permissions, routing, and services to derive the *actual* setup steps from the code, not
   from assumptions. Same "read first" discipline as `drupal-module-documentation`.

4. **Write the storyboard.** Write `.tutorial-build/<slug>/storyboard.md`: an ordered list
   of scenes, each with `type`, the on-screen actions, the narration text, and the one-line
   caption. **Get the user's approval before recording.**

5. **Pick a voice.** Run `elevenlabs-cli voice list`, present the options with their names
   and ids, and ask the user which voice to use. Remember the chosen voice id.

6. **Start the session.** `./session.sh start "<site-url>"`. This opens the kiosk browser on
   `:99` inside the container.

7. **Record scene by scene.** For each scene, in order:
   - Write the caption to `final/NN.caption.txt` (one line, plain).
   - **browser-action / intro / module-page:**
     1. `./record-scene.sh start NN`
     2. Drive the browser: `agent-browser --cdp http://127.0.0.1:9222 open <url>`,
        `snapshot -i`, `wait` as needed. To click or type an element, get its center in
        viewport pixels (which equal screen pixels in kiosk):
        ```
        agent-browser --cdp http://127.0.0.1:9222 eval \
          "(()=>{const r=document.querySelector('SEL').getBoundingClientRect();return Math.round(r.x+r.width/2)+' '+Math.round(r.y+r.height/2)})()"
        ```
        then move, click, and type with the hands:
        ```
        ddev exec DISPLAY=:99 bash /var/www/html/.tutorial-build/<slug>/hands.sh move CX CY
        ddev exec DISPLAY=:99 bash /var/www/html/.tutorial-build/<slug>/hands.sh click
        ddev exec DISPLAY=:99 bash /var/www/html/.tutorial-build/<slug>/hands.sh type "value to type"
        ```
        Pace the actions like a human: move, small pause, click, then type. Leave the target
        on screen for a beat before stopping.
     3. `./record-scene.sh stop NN`
   - **command-card:** `./make-card.sh NN 4 "composer require drupal/<name>"`.

8. **Generate narration.** For each scene, generate the voice-over:
   ```
   elevenlabs-cli tts "<narration text>" --voice <voice-id> \
     --output .tutorial-build/<slug>/audio/NN.mp3
   ```

9. **Finish each scene.** `./finish-scene.sh NN` for every scene. It reads the scene video
   and its narration, adds ~1s lead and ~1s tail silence (so there is a 1-2s gap between
   scenes), freeze-pads the video so it never ends before the narration, muxes the audio,
   and draws the caption bar.

10. **Concatenate and present.** `./concat.sh`, then show the user
    `.tutorial-build/<slug>/final/tutorial.mp4`. **Do not clean up.** Wait for change
    requests; re-record or re-finish only the affected scenes and re-run `concat.sh`.

## Caption bar

`finish-scene.sh` draws a full-width bar across the bottom ~9% of the frame:
`drawbox` filled `black@0.85`, then centered white Montserrat text from
`final/NN.caption.txt`. Keep captions to one short line. An empty caption file means no bar
for that scene.

## Narration writing style

The spoken narration and captions use the same voice as the other skills in this repo:
plain, direct, terse, active voice. No em dashes or en dashes. No marketing hype or
subjective qualifiers in the step narration (the opt-in intro may say why the module
matters, but still in verifiable terms). No emojis.

## Known tuning points (verify on the first live run)

- **CDP reach from host.** After preflight's `ddev restart`, the host should reach
  `http://127.0.0.1:9222/json/version`. If agent-browser cannot attach over CDP, install
  agent-browser in the container and run it there against localhost:
  `ddev exec agent-browser --cdp http://127.0.0.1:9222 ...`.
- **Cursor alignment.** `get box` returns viewport coordinates. Kiosk Chromium at 0,0 with
  `--force-device-scale-factor=1` makes viewport pixels equal screen pixels, but a small
  fixed offset may be needed. Take a screenshot mid-scene and adjust if the click misses.
- **Window focus for typing.** `xdotool type` goes to the focused window. session.sh
  activates the Chromium window; if typing lands nowhere, re-activate it before typing.

## Common mistakes

| Mistake | Fix |
|---|---|
| Using `@elevenlabs/cli` for narration | It has no TTS. Use the Rust `elevenlabs-cli` crate. |
| agent-browser doing the click | CDP clicks are invisible in the recording. Click with `hands.sh`; use agent-browser only to find the element. |
| Recording a terminal | Terminal commands are command cards, not screen recordings. |
| Intro on the generic drupal.org site | The intro shows the module's own project page, `drupal.org/project/<machine_name>`. |
| Ephemeral container packages | Installs are lost on `ddev restart` unless in `.ddev/config.tutorial-video.yaml` (preflight writes this). |
| Cleaning up before approval | Leave the build dir intact until the user approves. |
| Narration and video out of sync | `finish-scene.sh` pads the video to the audio; never trim the audio to fit the video. |
