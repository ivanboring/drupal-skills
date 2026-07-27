---
name: drupal-manual-video-testing
description: Use when manually testing a drupal.org issue or merge request against a running ddev site by following the issue's test instructions, reproducing the current behaviour, then recording a screencast (no audio, no mouse) that shows the before/after, storing ddev snapshots between states, and optionally writing a FunctionalJavascript test.
---

# Drupal Manual Video Testing

## Overview

Manually verifies a drupal.org issue or MR on a running **ddev** site by following the issue's
own testing instructions. It records the current behaviour, snapshots the database, resets,
records the missing pieces, and concatenates the parts into one silent MP4 with a text
overlay describing each step. There is **no narration and no mouse cursor**: the browser is
driven over CDP / JavaScript events, which is faster than moving a visible pointer.

The recording happens inside the ddev **web container** on a virtual X display (`:99`) at
1920x1080. **agent-browser** drives Chromium over CDP (navigate, read the accessibility
tree, click, fill, dispatch JS events); `ffmpeg -f x11grab` captures the screen. Because we
do not teach a human to click, the invisible CDP input is exactly what we want.

Work in **parts**: record a chunk of the flow, pause, change site state or restore a
snapshot, record the next chunk. Parts are numbered `01`, `02`, ... in play order and
concatenated at the end.

## Video or screenshots

Video is not always warranted. If the issue can be shown with **screenshots** (a static
before/after, a rendered page, an error message), skip recording and save the time. Capture
them with agent-browser instead:
`ddev exec agent-browser --cdp http://127.0.0.1:9222 screenshot final/NN.png`, store them in
the same output folder, and still write `result.md`. Use video only when the behaviour is
motion or a multi-step flow that a still cannot convey. When you use screenshots, skip the
recording, finish, and concat chapters.

## Requirements (hard) — DDEV only

This skill **only runs under DDEV**. If there is no ddev project, stop.

Before doing anything else, confirm you have all four. If any is missing, **ask the user
where to find it**. If the user cannot provide it, **do not run the skill**.

1. **Where the website is** — the ddev project directory and its site URL.
2. **Browser automation** — agent-browser in the web container (preflight installs it).
3. **A login** — this skill logs in with a one-time link from `drush uli`, so it never
   handles a password. If `drush uli` is unavailable, ask the user for an admin login method.
4. **drush access** — a working `drush` in the container.

If no suitable site exists yet, recommend the one-line installer as a testing bed:
https://www.drupal.org/project/one_line_installer/ (spin up a fresh Drupal in ddev, then
re-run preflight).

Run `preflight.sh` first; it checks and sets up DDEV, the container browser stack,
agent-browser, drush, login, and the overlay font.

## Secrets

If the test needs API keys or other secrets, they must **already** exist as environment
variables or be configured in the site. **Never ask for, read, echo, or store a
credential's value.** To check presence only: `ddev exec 'test -n "$OPENAI_API_KEY"'`
(or the relevant module setting via `drush config:get`, checking that it is set, not its
value). If a required secret is missing, **abort** and tell the user which variable to set
and how (e.g. add it to `.ddev/config.*.yaml` `web_environment`, or `ddev exec` env), then
stop.

## Helper scripts

Run every script **from the ddev project root**, with `export MT_MODULE=<machine_name>` and
`export MT_MR=<issue_or_mr_id>` set. Scripts read `lib.sh` for shared paths and settings.

| Script | Runs on | Purpose |
|---|---|---|
| `preflight.sh` | host | Check + set up ddev, container packages, agent-browser, drush, login, font; create the build dir |
| `session.sh start\|stop [url]` | host | Bring up Xvfb `:99`, kiosk Chromium with remote debugging, wait for CDP; stop tears it down |
| `snapshot.sh save\|restore\|list <label>` | host | Save/restore a ddev **database** snapshot between recorded states |
| `record-part.sh start\|stop <NN>` | host | Start/stop the x11grab capture for part `NN` |
| `finish-part.sh <NN>` | host | Freeze-pad a trailing pause and draw the text-overlay bar (no audio) |
| `concat.sh` | host | Concatenate `final/part-*.mp4` into `final/recording.mp4` |

## Build directory

Everything lives under the site's **public files** directory so the result stays with the
site and host + container share one filesystem. The skill resolves `public://` via drush.

```
<files>/ai-manual-testing/<module>-<mr>/
  result.md               # PASS/FAIL verdict + a couple of sentences why
  assets/Montserrat-Regular.ttf
  parts/NN.mp4            # raw silent capture for part NN
  final/NN.caption.txt    # overlay text for part NN (one line)
  final/part-NN.mp4       # padded + overlaid
  final/recording.mp4     # concatenated result
```

`<files>` is usually `sites/default/files`. Nothing is deleted at the end.

## Workflow

Create a todo per chapter.

### Chapter 1 — Prerequisites and gating

1. Confirm the four hard requirements above with the user. Then
   `export MT_MODULE=<machine_name>`, `export MT_MR=<id>`, and run
   `./skills/.../preflight.sh`. Confirm the site URL.

### Chapter 2 — Read the issue and decide go / no-go

2. **Fetch the issue and MR.** Read the drupal.org issue
   (`drupal.org/project/<module>/issues/<id>` or `drupal.org/node/<id>`) and its merge
   request. Look for explicit **testing instructions** ("Steps to reproduce", "Test
   instructions", "How to test", "Remaining tasks"). Do not invent steps: use the issue's.

3. **Multiple instruction sets → ask.** If the issue or its comments contain more than one
   set of testing instructions (e.g. different comments, or issue vs MR), ask the user which
   set to use before proceeding.

4. **Version gate (abort).** Compare what the instructions target to what is installed:
   - Drupal core: `ddev exec 'drush status --field=drupal-version'`.
   - The module and any required module: `ddev exec 'drush pm:list --format=json'` (or
     `ddev exec 'composer show drupal/<name>'`).
   If the instructions require a **specific Drupal version** and the installed version
   differs, **abort**. If they require a module at a version different from what is
   installed, **abort**. Report the mismatch and stop; do not "make it work" on the wrong
   version.

5. **Secret gate (abort).** If the instructions need secrets, verify presence only (see
   Secrets above). Missing → abort with setup guidance.

**Getting the module code.** If the module under test is not installed but exists in contrib,
you do not need Composer to add it. Clone it into `modules/custom/<machine_name>` and enable
it there (`ddev exec drush en <machine_name>`); Drupal uses a custom-placed module the same
as a contrib one. Cloning into `modules/custom` keeps it out of Composer's `modules/contrib`,
so you can freely `git fetch` / `git checkout` the MR branch to get the issue's code. This is
also the easy way to pull an MR onto an already-installed module.

### Chapter 3 — Record the current state and reproduce the issue

6. `./session.sh start "<site-url>"`, then log in with a one-time link:
   ```
   ddev exec 'drush uli --uri=<site-url>'
   ddev exec agent-browser --cdp http://127.0.0.1:9222 open "<the uli link>"
   ```
7. Record the current behaviour following the testing instructions. For each part:
   - Write the overlay text to `final/NN.caption.txt` (one short line describing the step).
   - `./record-part.sh start NN`
   - Drive the browser **inside the container** (host CDP is blocked, see Known tuning
     points). Prefer JS events over simulated input; they are faster and deterministic:
     ```
     ddev exec agent-browser --cdp http://127.0.0.1:9222 open <url>
     ddev exec agent-browser --cdp http://127.0.0.1:9222 fill "#edit-title" "value"
     ddev exec agent-browser --cdp http://127.0.0.1:9222 click "#edit-submit"
     # or trigger events directly:
     ddev exec bash -lc "agent-browser --cdp http://127.0.0.1:9222 eval \
       \"document.querySelector('#edit-submit').click()\""
     ```
     Leave the result on screen for a moment so it is visible.
   - `./record-part.sh stop NN`
8. **Snapshot at state changes.** Whenever the site state changes between what you record
   next (e.g. after reproducing the bug, before applying the fix), save a ddev snapshot:
   `./snapshot.sh save baseline`. Snapshot before any point you will need to return to.

### Chapter 4 — Reset and record the missing pieces

9. Restore the snapshot to record from the same starting point:
   `./snapshot.sh restore baseline`. Apply the code/config the instructions call for (e.g.
   check out the MR, `drush cr`), then record the remaining parts exactly as in Chapter 3
   (new part numbers). Snapshot again if you branch into further states.

### Chapter 5 — Finish, concatenate, present

10. `./finish-part.sh NN` for every part (adds a trailing pause and the overlay bar). For a
    longer pause after a key moment: `MT_TAIL=1.5 ./finish-part.sh NN`.
11. `./concat.sh`, then show the user `<files>/ai-manual-testing/<module>-<mr>/final/recording.mp4`.
    Do not clean up; wait for change requests and re-record only the affected parts.
12. **Write the verdict.** Write `<files>/ai-manual-testing/<module>-<mr>/result.md`: the
    first line is `PASS` or `FAIL`, followed by a couple of sentences on why (what the
    instructions asked for and what you observed). Keep it compact; no narrative.
13. **Offer to push the result (only if the `drupal-gitlab` skill is installed).** If that
    skill is available, ask the user whether to post the result to the issue instead of just
    storing it locally. If they agree, use the `drupal-gitlab` skill to post the `result.md`
    verdict as a comment. Do not upload or push anything without asking first. Every such
    comment must end with this exact line:
    ```
    <em>This testing was done by AI and the video should be viewed for possible errors</em>
    ```

### Chapter 6 — (Optional) FunctionalJavascript test

Only if the user asks for it. Write a real-browser test for what you just did. Reference and
research: https://www.drupal.org/docs/develop/automated-testing/phpunit-in-drupal/creating-functionaljavascript-tests-real-browser

- Extend `Drupal\FunctionalJavascriptTests\WebDriverTestBase`. Namespace
  `Drupal\Tests\<module>\FunctionalJavascript`, file in
  `<module>/tests/src/FunctionalJavascript/`. Set `protected $defaultTheme = 'stark';` and a
  `@group <module>`.
- Get the page with `$this->getSession()->getPage()`; navigate with `$this->drupalGet()`;
  click with `$element->click()` (runs attached JS).
- **No `sleep()` / no fixed waits.** Synchronise on state only: `waitForElement()`,
  `waitForElementVisible()`, `waitForField()`, `waitForButton()`,
  `$this->assertSession()->assertWaitOnAjaxRequest()`, or `assertJsCondition()`.
- Run it under ddev against chromedriver (a `chromedriver`/`selenium` service and
  `MINK_DRIVER_ARGS_WEBDRIVER`), e.g. `ddev exec phpunit web/modules/.../MyTest.php`.

## Recording style

Overlay text uses the repo voice: plain, direct, terse, active voice. No em/en dashes, no
hype, no emojis. One short line per overlay. You may pause (freeze-pad) to make a step easy
to follow. Do not add narration or ask about voice/TTS unless the user requests it.

## Known tuning points (verify on the first live run)

- **CDP: use the container.** Host CDP does not work (ddev maps the port dynamically;
  Chromium's DNS-rebinding protection rejects the forwarded Host). Always drive agent-browser
  inside the container against localhost: `ddev exec agent-browser --cdp http://127.0.0.1:9222 ...`.
- **Pre-seed AJAX-dependent forms.** Forms that rebuild dependent fields via Drupal AJAX are
  unreliable to drive live. Set the value first with `drush config:set` so the form loads
  settled, then record the final selection.
- **Snapshots are database-only.** `ddev snapshot` does not capture the files directory. If a
  test changes uploaded files, restore will not revert them.
- **Non-Latin text needs CJK fonts.** Preflight installs `fonts-noto-cjk`. Chromium caches
  fonts at startup; if you install fonts after a session is running, restart it.

## Common mistakes

| Mistake | Fix |
|---|---|
| Running outside DDEV | This skill is DDEV-only. If there is no ddev project, stop. |
| Inventing test steps | Follow the issue's own testing instructions. Multiple sets → ask which. |
| Testing on the wrong version | Abort if the required Drupal or module version differs from installed. |
| Asking for or reading a secret's value | Only check a secret is present. Abort + guide if missing. |
| Adding narration or a mouse cursor | Neither is used. Drive over CDP / JS events; overlay text instead. |
| Recording one long take across state changes | Split into parts; snapshot at each state change; reset before the next. |
| Expecting file changes to revert on restore | Snapshots are database-only. |
| `sleep()` in the JS test | Use `waitForElement`/`assertWaitOnAjaxRequest`; never a fixed wait. |
| Driving agent-browser from the host | Host CDP is blocked; run it in the container. |
| Cleaning up before approval | Leave the build dir intact until the user approves. |
