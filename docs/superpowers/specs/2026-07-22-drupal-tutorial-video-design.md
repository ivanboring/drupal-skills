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
- **TTS:** the third-party Rust `elevenlabs-cli` (`cargo install elevenlabs-cli`), run on
  the host. The official `github.com/elevenlabs/cli` (`@elevenlabs/cli`) was rejected as a
  backend because it manages conversational AI agents and has no text-to-speech, voice
  listing, or audio output.
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

## Architecture

```
ddev web container            :99 = Xvfb (1920x1080)
  |- Chromium  --kiosk --window-size=1920,1080  (DISPLAY=:99, remote-debug port)
  |- xdotool   -> visible cursor move / click / type --delay   (DISPLAY=:99)
  |- ffmpeg    -f x11grab -i :99   -> scenes/NN.mp4             (DISPLAY=:99)

HOST
  |- agent-browser --cdp <forwarded debug port>  -> navigate / snapshot / get box / wait
  |- elevenlabs-cli tts  -> audio/NN.mp3   (written into the ddev-mounted build dir)
```

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

CDP port forwarding from host to container and the kiosk coordinate mapping are the two
fiddly parts of the implementation and are called out as the known technical risk.

## Preflight (run first, in order)

1. **ddev** project exists and is running; abort with guidance if not. Ask for and confirm
   the site **URL, username, and password**.
2. **Container packages** (`ffmpeg`, `xvfb`, `xdotool`, `chromium`): check with
   `ddev exec`. If missing, install with apt-get. Offer the persistent route
   (`webimage_extra_packages` in `.ddev/config.yaml`) versus a quick ephemeral
   `ddev exec` install, and note the ephemeral one is lost on `ddev restart`.
3. **agent-browser** on the host (`agent-browser --version`); abort if absent (hard
   requirement).
4. **elevenlabs-cli** on the host: if missing, offer `cargo install elevenlabs-cli` and
   note it needs a Rust toolchain. Ensure the API key is configured; help set it if not.
5. **Montserrat**: if the ttf is not already available, download
   `https://www.1001freefonts.com/d/5711/montserrat.zip` to `/tmp`, unzip, and use
   `Montserrat-Regular.ttf` (and `-Bold` for titles).

## Working directory

Everything lives under the ddev mount so host and container share one filesystem:

```
<ddev-project>/.tutorial-build/<slug>/
  storyboard.md
  scenes/NN.mp4        # raw silent screen capture per scene
  audio/NN.mp3         # narration per scene, with 1-2s silence padding
  cards/NN.png         # rendered command-card stills
  final/scene-NN.mp4   # padded + muxed + captioned per scene
  final/tutorial.mp4   # concatenated result
```

Nothing is deleted at the end; the user may ask for changes.

## Scene taxonomy

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
3. **Storyboard**: write `storyboard.md` with ordered scenes, each carrying `type`, the
   on-screen actions, the narration text, and the bottom-bar caption text. Get user
   approval before recording.
4. **Voice**: run `elevenlabs-cli voice list`, present the options, ask which voice.
5. **Record scene by scene**: a persistent agent-browser/Chrome session; per scene, start
   ffmpeg x11grab, run the action sequence (agent-browser locates, xdotool moves / clicks /
   types), then stop. Command cards render a still instead of recording.
6. **Narrate**: `elevenlabs-cli tts` per scene to `audio/NN.mp3`; prepend and append 1-2s
   of silence.
7. **Fit**: for each scene, `final_dur = max(video_dur, audio_dur)`; freeze-pad the video
   (ffmpeg `tpad=stop_mode=clone`) so it never ends before the narration finishes.
8. **Mux**: lay each scene's audio over its padded video.
9. **Caption**: `drawtext` bottom bar with `fontfile=Montserrat-Regular.ttf`,
   `fontcolor=white`, `box=1:boxcolor=black@0.85`, pinned to the bottom ~9% of the frame
   with padding.
10. **Concat**: join `final/scene-*.mp4` into `final/tutorial.mp4`, present it, and do not
    clean up.

## Helper scripts in the skill folder

Consistent with how the other skills in this repo ship scripts:

- `preflight.sh` — all of the preflight section.
- `record-scene.sh` — start and stop x11grab around a scene's action list.
- `make-card.sh` — render a command-card still into a short clip.
- `finish-scene.sh` — pad, mux, and drawtext one scene.
- `concat.sh` — concat scenes into the final video.

`SKILL.md` orchestrates these scripts and holds the narration writing-style rules (plain,
direct voice, no em dashes, no marketing hype in the narration itself), matching the other
skills in this repo.

## Writing style for narration

The spoken narration and on-screen captions follow the same voice as the other skills:
plain, direct, terse, active voice, no em dashes or en dashes, no marketing hype or
subjective qualifiers (the opt-in intro may frame why the module matters, but still in
verifiable terms).

## Known risks

- **CDP port forwarding** from host agent-browser to the in-container Chromium.
- **Kiosk coordinate mapping**: aligning `get box` viewport coordinates to xdotool screen
  coordinates; may need a calibration offset.
- **Ephemeral container packages**: apt-get installs in the web container are lost on
  restart unless made persistent via `webimage_extra_packages`.
