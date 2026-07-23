# drupal-tutorial-video design

A skill that records narrated 1920x1080 MP4 tutorials showing how to set up a Drupal
module. The skill reads the module to learn the real setup, writes a storyboard for
approval, records the browser performing the steps with a visible cursor and typing,
generates ElevenLabs narration, and muxes it into a captioned, concatenated video.

## Goal

Given one or more modules and a "how to set up X" goal, produce a finished tutorial video
where a visible cursor moves and clicks, form fields are typed character by character, a
narrator explains each step, and a caption bar at the bottom describes what is happening.
Terminal commands that cannot be shown in the browser are rendered as still command cards.

## Decisions (locked)

- **Recording location:** inside the ddev web container, on an Xvfb display `:99` at
  1920x1080. Chosen for reproducibility and to match the "install ffmpeg on the web
  container" intent.
- **TTS:** `awaz` (`npm i -g awaz`, https://github.com/ahmadawais/awaz), an ElevenLabs
  wrapper, run on the host. Chosen over the Rust `elevenlabs-cli` for a lighter install
  (Node/npm instead of a Rust toolchain). It lists voices (`awaz voices`) and generates
  audio (`awaz -v <voice> -o out.mp3 "text"`), authenticating with `ELEVENLABS_API_KEY`.
  The official `github.com/elevenlabs/cli` (`@elevenlabs/cli`) was rejected because it
  manages conversational AI agents and has no text-to-speech, voice listing, or audio output.
- **Visible cursor:** the real X11 pointer on `:99`, driven by `xdotool`, captured natively
  by `ffmpeg x11grab`. Not a JavaScript/DOM injected cursor (a DOM cursor cannot cover
  browser chrome or native widgets, does not correspond to the real click point, and
  vanishes on navigation).
- **Caption bar:** slim black bar pinned to the bottom ~9% of the frame, white Montserrat
  text, produced with ffmpeg `drawtext box=1`.
- **Intro:** when the user opts into a why-this-matters / marketing opening, the intro
  scene shows the module's own drupal.org project page (`drupal.org/project/<machine_name>`),
  not the generic drupal.org site.
- **Terminal commands:** commands that cannot be shown in the browser (`composer require`,
  `drush en`, `ddev ...`) are shown as still command cards with narration, never as a
  recorded terminal.
- **Beat-based recording (added 2026-07-23):** the atomic recorded unit is a **beat**, one
  narration sentence plus the single action it describes, recorded as its own clip. A scene is
  only a storyboard grouping of beats. Narration stays in sync with the picture because each
  beat's video and audio are the same clip; `finish-beat.sh` length-fits each beat to
  `max(action, speech)`, and beats concatenate in order. This replaced recording whole scenes
  as one take with one long narration, which drifted out of sync. Per-beat lead/tail silence
  is short (~0.5s); the last beat of a scene takes a longer tail (`TUT_TAIL=1.5`) for the
  1-2s inter-scene pause. No vision pass is needed: the skill drives the actions, so it
  already knows their timing.

## Architecture

```
ddev web container            :99 = Xvfb (1920x1080)
  |- Chromium  --kiosk --window-size=1920,1080  (DISPLAY=:99, remote-debug port)
  |- xdotool   -> visible cursor move / click / type --delay   (DISPLAY=:99)
  |- ffmpeg    -f x11grab -i :99   -> beats/NN.mp4              (DISPLAY=:99)
  |- agent-browser --cdp http://127.0.0.1:9222  -> navigate / snapshot / get box / wait

HOST
  |- awaz -o audio/NN.mp3  -> narration   (written into the ddev-mounted build dir)
```

agent-browser runs **inside the container** (installed via npm by preflight): host CDP does
not work because ddev maps the debug port to a dynamic host port and Chromium's DevTools
rejects the forwarded connection on a Host-header mismatch (DNS-rebinding protection). From
inside the container the Host is `127.0.0.1:9222` and matches.

Division of responsibility:

- **agent-browser** (the brain): `open <url>`, `snapshot -i` to read the accessibility tree,
  `get box <ref>` to return an element's on-screen coordinates, and `wait` for page state.
  It never performs the visible click, because CDP input is synthetic and invisible.
- **xdotool** (the hands): `mousemove` to the target box center in small stepped increments
  for smooth motion, `click 1` for a real click at that point, and `type --delay 60` for
  character-by-character typing into the focused field. Because the pointer on `:99` is
  real, the thing that moves is exactly the thing that clicks.
- **ffmpeg x11grab** captures the whole `:99` display, including the real cursor.

Chromium runs in `--kiosk` at position 0,0 so the viewport coordinates returned by
`get box` map directly to screen coordinates for xdotool. A small fixed calibration offset
may be needed; this is the main place iteration is expected during the build.

The kiosk coordinate mapping (aligning `get box` viewport coordinates to xdotool screen
coordinates) is the main fiddly part of the implementation and the known technical risk.

## Preflight (run first, in order)

1. **ddev** project exists and is running; abort with guidance if not. Ask for and confirm
   the site **URL, username, and password**.
2. **Container packages** (`ffmpeg`, `xvfb`, `xdotool`, `chromium`, `x11-utils`,
   `fonts-dejavu-core`, `fonts-noto-cjk`): installed persistently via a ddev config drop-in
   (`.ddev/config.tutorial-video.yaml` with `webimage_extra_packages`) plus one `ddev restart`.
   `fonts-noto-cjk` so non-Latin target languages render instead of tofu.
3. **agent-browser** in the container: installed with `npm install -g agent-browser` (a
   post-start hook re-installs it if missing). It has to run in the container because CDP
   only works from there.
4. **awaz** on the host: if missing, offer `npm i -g awaz` (needs Node/npm). Ensure
   `ELEVENLABS_API_KEY` is set (needs Text to Speech and Voices-read scopes); help if not.
5. **Montserrat**: if the ttf is not present, download the Montserrat variable font from
   Google Fonts to `/tmp` and copy it into the build dir as `Montserrat-Regular.ttf`.

## Working directory

Everything lives under the ddev mount so host and container share one filesystem:

```
<ddev-project>/.tutorial-build/<slug>/
  storyboard.md
  beats/NN.mp4         # raw silent screen capture per beat
  audio/NN.mp3         # narration per beat
  cards/NN.cmd.txt     # command-card text
  final/NN.caption.txt # caption bar text per beat
  final/beat-NN.mp4    # padded + muxed + captioned per beat
  final/tutorial.mp4   # concatenated result
```

Nothing is deleted at the end; the user may ask for changes.

## Beat taxonomy

| Type | What it shows | How it is produced |
|---|---|---|
| `intro` | The module's drupal.org project page, narration on why it matters / marketing (only if the user opts in) | browser-record |
| `module-page` | The module page as reference | browser-record |
| `browser-action` | A real setup step in the ddev site, with visible cursor and typing | agent-browser + xdotool + x11grab |
| `command-card` | A terminal command that cannot be shown in-browser | still card: black bg, white monospace command, narration over it |
| `outro` | Recap / call to action | browser-record or card |

## Workflow

1. **Gather** the module(s) and the setup to demonstrate. Ask the intro question: open with
   why-this-matters / marketing, or go straight to the steps.
2. **Read the module** first: `.info.yml`, README, config and permissions, routing, forms,
   services. Derive the actual setup steps from the code, not from assumptions.
3. **Storyboard**: write `storyboard.md` as scenes (headings) broken into beats, each beat
   carrying its number, `type`, the single action, one narration sentence, and the caption.
   Get user approval before recording.
4. **Voice**: run `awaz voices`, present the options, ask which voice.
5. **Record beat by beat**: a persistent agent-browser/Chrome session; per beat, start
   ffmpeg x11grab, run the single action (agent-browser locates, xdotool moves / clicks /
   types), then stop. Command cards render a still instead of recording.
6. **Narrate**: `awaz -v <voice> -o audio/NN.mp3 "..."` per beat, one sentence each.
7. **Fit**: for each beat, `final_dur = max(video_dur, lead + audio_dur + tail)`; freeze-pad
   the video (ffmpeg `tpad=stop_mode=clone`) so it never ends before the narration finishes.
   Short lead/tail per beat; longer tail on the last beat of a scene.
8. **Mux**: lay each beat's audio over its padded video.
9. **Caption**: `drawtext` bottom bar with `fontfile=Montserrat-Regular.ttf`,
   `fontcolor=white`, `box=1:boxcolor=black@0.85`, pinned to the bottom ~9% of the frame
   with padding.
10. **Concat**: join `final/beat-*.mp4` into `final/tutorial.mp4`, present it, and do not
    clean up.

## Helper scripts in the skill folder

Consistent with how the other skills in this repo ship scripts:

- `preflight.sh` — all of the preflight section.
- `record-beat.sh` — start and stop x11grab around a beat's single action.
- `make-card.sh` — render a command-card still into a short clip.
- `finish-beat.sh` — pad, mux, and drawtext one beat.
- `concat.sh` — concat beats into the final video.

`SKILL.md` orchestrates these scripts and holds the narration writing-style rules (plain,
direct voice, no em dashes, no marketing hype in the narration itself), matching the other
skills in this repo.

## Writing style for narration

The spoken narration and on-screen captions follow the same voice as the other skills:
plain, direct, terse, active voice, no em dashes or en dashes, no marketing hype or
subjective qualifiers (the opt-in intro may frame why the module matters, but still in
verifiable terms).

## Known risks

- **CDP is container-only.** agent-browser must run inside the container against
  `127.0.0.1:9222`; host CDP is blocked by the Host-header check on ddev's dynamic port.
- **Kiosk coordinate mapping**: aligning `get box` viewport coordinates to xdotool screen
  coordinates; may need a calibration offset.
- **Ephemeral container packages**: apt-get installs in the web container are lost on
  restart unless made persistent via `webimage_extra_packages`.
