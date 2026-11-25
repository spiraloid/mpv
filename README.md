# mpv portable config

A portable mpv configuration for Windows and macOS. It's built for reviewing and curating numbered frame sequences (attempt variants, folder hopping, selects copying, frame-group reordering) and for reviewing edits shot by shot. That covers jumping between shots, playing an FCP7 XML as an assembly, and approving or rejecting clips from the player.

## Quickstart

**Option A — winget (installed)**

Needs `git` and `winget`. Run in PowerShell:

```powershell
winget install -e --id shinchiro.mpv
git clone https://github.com/spiraloid/mpv.git "$env:USERPROFILE\mpv-config"
Copy-Item "$env:USERPROFILE\mpv-config\portable_config\*" "$env:APPDATA\mpv\" -Recurse -Force
```

If `mpv` isn't found afterwards, open a new PowerShell window so it picks up the new PATH.

To update later, run:
```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\mpv-config\update.ps1"
```

**Option B — portable (extracted)**

Set `$drive` to wherever you want mpv installed, then:

```powershell
$drive = "C:"
Invoke-WebRequest "https://sourceforge.net/projects/mpv-player-windows/files/latest/download" -OutFile "$drive\mpv.zip"
Expand-Archive "$drive\mpv.zip" -DestinationPath "$drive\mpv"
git clone https://github.com/spiraloid/mpv.git "$drive\mpv\portable_config"
```

Then open a folder of frames by dragging it onto `mpv.exe`, or:
```powershell
& "$drive\mpv\mpv.exe" "C:\path\to\frames"
```

### Set mpv as default (Open With)

Do this once per file type for `.jpg`, `.jpeg`, `.png`, `.mp4`, `.mp3`, `.wav`:

1. Right-click any file of that type in Explorer
2. **Open with** → **Choose another app**
3. Scroll down and click **More apps** if mpv isn't listed
4. Click **Look for another app on this PC** and browse to `mpv.exe`
5. Check **Always use this app to open `.ext` files** → **OK**

> For Option B (portable), `mpv.exe` is at `$drive\mpv\mpv.exe`. For Option A (winget), find it with:
> ```powershell
> (Get-Command mpv).Source
> ```

### Check it works

1. `mpv --version` runs, and `mpv --vf=help` lists `scdet` (the scene-cut filter the shot scan uses).
2. The config is in place: `shot_jump.lua` is in `%APPDATA%\mpv\scripts\` (winget) or `portable_config\scripts\` (portable).
3. Open a video with a few cuts. Within a few seconds an `.xml` with the same name appears beside it, and `LEFT` / `RIGHT` jump cut to cut.
4. Open an FCP7 `.xml` (drag it onto mpv). It plays as one edit with shot labels bottom-right. Arrows and the mouse wheel step shot to shot.
5. Open a review XML in a folder of rung folders and pause on a shot. A row of shot states appears across the top. To try it safely, press `UP` to step to an older version and click one, then quit with `Esc` and answer **No** at the Save changes? prompt: nothing was written.
6. Middle click drops to a quarter-size window top-left; middle click again returns to fullscreen.
7. Press `h` for every key.

If something's off:
- **A console window flashes when you reject or restore a clip in a plain XML (Windows).** The file moves go through PowerShell, like Rename and Trash.
- **A button doesn't take a click.** On the Mac, mpv only learns where the pointer is from pointer-move events, and right after a reload or a prompt opening it can miss them, so its idea of the pointer lags. A click on a prompt or the state row therefore asks macOS where the pointer really is (about a tenth of a second). Every click on a prompt (Save changes?, the save card) is written to `mpv-prompt-clicks.log` in your temp folder (`$TMPDIR` on macOS, `%TEMP%` on Windows), the last 40: where the pointer was, where mpv thought it was, what it hit, and where the buttons were drawn. Send that file along with what you clicked.
- **"uv not found" or "could not start uv" on opening or saving a review.** Install [uv](https://docs.astral.sh/uv/). mpv started from the Finder, the Dock or the Start menu doesn't get your shell's PATH, so it also looks in the usual install folders (`~/.local/bin`, `~/.cargo/bin`, `/opt/homebrew/bin`, `/usr/local/bin`; on Windows `%USERPROFILE%\.local\bin`, `%USERPROFILE%\.cargo\bin`, WinGet's `Links`, scoop's `shims`). If uv lives elsewhere, set `review_runner=<full path to uv>` in `script-opts/shot_jump.conf`. The choices file is saved either way; save again once uv starts.
- **No cuts found, or no `.xml` written.** Check step 1 for `scdet`. A clip with no cuts gets no `.xml`, by design.
- **Leftover `mpv_shots_*.log` files in `%TEMP%` (or `$TMPDIR` on macOS) after quitting.** These are scan logs that should have been cleaned up.

## Workflow

Files are expected to follow a naming convention like:

```
frame_001.png
frame_001_attempt_01.png
frame_001_attempt_02.png
frame_002.png
```

The playlist auto-filters to the same media type as the starting file (video / image / audio). **Variant mode** controls whether `_attempt_##` files are visible.

**One mpv at a time.** Opening a file while mpv is already running (a double-click, a shortcut app, a terminal) hands the file to the mpv that's open, brings it to the front, and the new launch quits; the same file just comes forward, on the frame it was on. If a review open there has unsaved choices, it doesn't switch: it asks you to save or quit first. This keeps two players from holding two states of the same review. Renders and anything driven over `--input-ipc-server` are left alone; `--script-opts=single_instance-enabled=no` turns it off for one launch.

## Shortcuts

Press `h` in mpv for the same list on screen.

### Playback & files

| Key | Action |
|-----|--------|
| `SPACE` | Images: next image · video / audio: pause / play |
| `UP` / `DOWN` | Previous / next file in the playlist (in an XML: the shot's history, see below) |
| `PGUP` / `PGDWN` | Previous / next file in the playlist |
| `WHEEL_UP` / `WHEEL_DOWN` | Video: pause and step a frame · images / audio: previous / next file · XML: previous / next shot |
| `Alt+WHEEL_UP` / `Alt+WHEEL_DOWN` | Previous / next file of the same media type only |
| `Shift+LEFT` / `Shift+RIGHT` | Seek −5 s / +5 s |
| `,` / `.` | Frame back / forward (mpv defaults) |
| `s` (`Alt+s`) | Select: copy the file without its `_attempt_##` suffix |
| `\` | Variant mode: show / hide `_attempt_##` files |
| `Ctrl+LEFT` / `Ctrl+RIGHT` | Shift a media group backward / forward |
| `DEL` / `F2` | Move the file to the trash / rename it |
| `Ctrl+S` | Numbered snapshot (in an XML, see below) |
| `Ctrl+C` | Copy the frame to the clipboard |
| `Ctrl+R` | Rebuild the playlist |
| `Ctrl+N` | Jump to the next sibling folder |
| `ENTER` / `F` / `Alt+ENTER` | Fullscreen |
| Middle click | Fullscreen ↔ quarter-size window |
| `Esc` / `Q` | Quit (asks first if an XML has unsaved changes) |

### Shots and review

| Key | Action |
|-----|--------|
| `LEFT` / `RIGHT` | Previous / next shot, on its first frame. An XML pauses there. Frame step when the file has no known cuts |
| `WHEEL_UP` / `WHEEL_DOWN` | Previous / next shot, one per notch (XML) |
| `UP` / `DOWN` | XML in rung folders: the shot's history. `UP` older (to the cleaned plate), `DOWN` newer (to the final). Pauses on the shot if it was playing |
| `o` | Show / hide the shot label and buttons (outside an XML: mpv's progress bar) |
| `r` / `c` / `a` | Review: shot state **re-roll** / **re-circulate** / **final**. The same key again clears it. Or click the row across the top (shown while paused). Setting re-roll or re-circulate opens the note box |
| `m` | Review: the **comp** switch, on or off beside the state |
| `i` | Review: import the next notes file from a recorded review |
| `Tab` / `Shift+Tab` | Review: step to the next / previous imported note (`Enter` accepts, `x` skips, `Esc` stops) |
| `n` | Review: edit the shot's note (one line; Enter keeps it, Esc leaves it as it was) |
| `x` | Review: clear the shot's choice, note included |
| `Ctrl+Shift+S` (`Cmd+S`) | Review: save the choices file, then run the project's scripts |
| `Ctrl+S` | XML in rung folders: on a shot's first / last frame, save `NN_start.png` / `NN_end.png`. Any other frame: numbered snapshot |
| `r` / `u` | Plain XML (no rung folders): reject the clip on screen / restore it |

The review keys work only while the review XML is open (see [Shot review](#shot-review) below); elsewhere `r` / `c` / `m` / `a` / `x` keep their usual jobs (`m` is mute).

## Shot review

### Jumping between shots

`LEFT` / `RIGHT` jump to the first frame of the previous / next shot. Holding them repeats, and they wrap from the last shot to the first. The shot starts come from the first of these that applies:

1. **You opened an FCP7 `.xml` (xmeml).** It plays as an assembly (below), and each clip is a shot.
2. **The video has an XML beside it with the same name** (`clip.mp4` + `clip.xml`). Each clipitem's `<start>` is a shot start. If the XML's sequence length doesn't match the video, it's ignored.
3. **Neither.** A background scan looks for picture cuts as soon as the video loads, and the keys work while it runs. When it finds cuts, it writes `clip.xml` beside the video so the next open is instant. A clip with no cuts gets no XML, and the arrows keep stepping one frame.

The scan is a second, hidden mpv running ffmpeg's `scdet` filter. Nothing extra needs installing. It finds hard cuts; dissolves and fades mostly slip past it.

### Playing an XML as an assembly

Drag an FCP7 `.xml` onto mpv (or open it like any file):
- **Picture:** the first video track plays as one continuous edit of its source clips, one chapter per clip.
- **Sound:** the first audio track plays as the soundtrack.
- **Paths:** `pathurl`s can be relative to the XML's folder or `file://` URLs.
- **Missing sources:** a source that's missing keeps its slot as a dark gray **MISSING** clip, and the OSD counts it on load. Nothing after it shifts.
- **Short sources:** a source shorter than its slot holds its slot, so the soundtrack stays in sync.

**Shot labels.** Each clip's `<comments><mastercomment1>` is drawn bottom-right of the picture, scaled with it. While playing only the shot number shows (and the new-versions badge); the rest of the label and the line over it appear on pause:
- The first word (the shot number) is full size and the rest half size, e.g. `03 candidate 00`.
- `<mastercomment2>orange</mastercomment2>` draws the label orange.
- A label ending in `EDIT` (e.g. `22 EDIT`) draws gray.
- A label ending in `MISSING PLATE` draws the number plus a large centred card over a red wash.
- A clip with no `<comments>` gets no label.
- A slot playing a version other than the one the XML names (an `UP` / `DOWN` choice, or a fallback because the named file is gone) is labelled for what it actually shows.
- When a rung holds more than one version of the shot (live or retired), a small line above the label says which one is on screen: the file's date and its place among them, lowest pass first, e.g. `11-21 18:50 · 2 of 3`. In a review the same line says where copies of the file sit (the shot's state is in the row across the top). The label itself keeps the `NN stage PP` format.

### Group review: one choices file

When the clips sit in a shots folder made of lettered **rungs**, the assembly becomes the review tool for that pipeline. The group steps through each shot's versions, picks the best state, says what should happen to it, and saves. mpv writes **one small file** and nothing else: it never moves, copies or renames a shot file, and it never edits the XML.

```
review.xml                         <- what the group opens (rebuilt by the project's scripts)
shots/
  A_cropped_plates/07.mp4          <- bottom rung
  B_cleaned_plates/07.mp4
  C_frame_candidates/v.001/07_start.png
  ...
  F_runs/v.012/07.mp4              <- one pass per v.NNN folder
  F_runs/v.013/07.mp4
  ...
  I_candidates/v.012/07.mp4
  K_final/07.mp4                   <- top rung
  selects.json                     <- the review's choices: the one file mpv saves
```

A shot's file is one named for its shot number: `07.mp4` or `07_v4.mp4`, anywhere inside a rung, in any video format. Empty stub files are ignored.

**A shot's history: `UP` / `DOWN`.** `LEFT` / `RIGHT` move between shots; `UP` / `DOWN` move through every version of the shot you're on. `DOWN` all the way is the final, `UP` all the way is the cleaned plate, and the ends stop. In an XML assembly `LEFT` / `RIGHT` pause on the shot's first frame, and `UP` / `DOWN` pressed during playback pause there too, so a swap always lands on the shot on screen. In between, every run, run candidate, driver candidate and candidate (live or `retired/`) comes in the order it was made, by file time, so a driver sits right after the take it was made from and the rolls it led to follow it: `DOWN` walks the shot's progression forward. The cropped plate under the cleaned one is left out unless it is all the shot has. A file that is only a copy of a lower one (a final copied from a candidate, a pick copied from a run) isn't listed twice: the original is shown, and the small line over the label says where copies of it sit (`in final`).

Each press swaps that version into the slot, on the same frame (pressed during playback, it pauses on the shot's first frame), and a note shows where you are (`07 run 12 · 4 / 9`). The swap is held in memory: nothing is written until you save.

**Shot state.** Pause on a shot and a row of text buttons appears across the top of the picture: three states, a divider, then the comp switch. One state per shot, on the version showing: click one (or press its key) to set it, click the set one again to clear it. A set state is drawn in its colour with a bar under it; the others are gray.

| Button | Key | Means |
|--------|-----|-------|
| re-roll | `r` | **Mark for re-roll**: make a new run of the shot |
| re-circulate | `c` | **Mark for re-circulation**: make a new driver from this take, then re-roll |
| ★ final | `a` | **Mark as final**: the star fills yellow |

**The comp switch** (`m`, or click it) sits after the divider with a box before its name: ticked when on. It is on or off whatever the state, and setting or clearing a state leaves it alone.

| With | Comp on means |
|------|------|
| no state | Make a candidate from this take |
| re-roll | Roll, then comp the new take |
| re-circulate | Refine, roll, then comp the new take |
| ★ final | Nothing: the switch is greyed and takes no click, and keeps what it was |

`x` clears the state and the switch, and so does stepping the shot to another version. Switching comp on with no state opens the note box.

Setting re-roll or re-circulate opens a box under the row (a final has no notes: the star doesn't open the box, and it clears the note the shot had), **Notes for NN**, filled with the shot's current note: type what the room said and press `Enter`, or `Esc` to leave the note as it was. Long text wraps, and the box grows a line at a time. `n` opens the same box without changing the state. While it's open every key types or edits:

| Key | In the note box |
|---|---|
| `LEFT` / `RIGHT` | Move a character |
| `Ctrl+LEFT` / `Ctrl+RIGHT` | Move a word (`Alt` works too: macOS can keep `Ctrl`+arrows for switching desktops) |
| `UP` / `DOWN` | First / last character (also `Home` / `End`); they don't change the version |
| `Shift` + any of those | Select from the cursor to there |
| A click | Put the cursor there |
| A drag | Select from where the button went down |
| A double click | Select the word |
| `Ctrl+A` / `Cmd+A`, or a triple click | Select the whole note |
| `Backspace` / `Delete` | Delete a character, or the selection. `Ctrl+U` empties the box |
| `Ctrl+C` / `Cmd+C`, `Ctrl+X` / `Cmd+X` | Copy / cut the selection, or the whole note when nothing is selected |
| `Ctrl+V` / `Cmd+V` | Paste (over the selection) |

Typing replaces a selection. Copy and paste move a note between shots: copy it in one shot's box, `n` on the other shot, paste.

The note shows under the row and is saved in the shot's `note`. The state and note belong to the version they were set on: step the shot to another version (`UP` / `DOWN`) and both clear, and stepping back doesn't bring them back.

The project's scripts act on these on save and print the next step for each marked shot (`to reroll: …`); the save card always shows those lines.

A shot can also have a chosen version with no state. `x` clears a shot's choice altogether: its entry leaves the file on save and the project's own rule decides what plays.

**Save: `Ctrl+Shift+S`** (`Cmd+S`), or Yes when you quit. mpv then:
1. Reads `shots/selects.json` again, changes only the shots this session touched, and writes it in place.
2. Runs the project's scripts (set in `script-opts/shot_jump.conf`), which apply the choices to the folders and rebuild the XML.
3. Reloads the rebuilt XML and shows a card with the scripts' last lines, so the group sees what changed.

If a script is missing or fails, the card says so, word for word, and the choices file stays saved.

```json
{
 "saved": "2026-11-24T02:47:10Z",
 "by": "name",
 "shots": {
  "07": {"file": "shots/F_runs/v.012/07.mp4", "mark": "reroll", "note": ""},
  "12": {"file": "shots/F_runs/v.012/12.mp4", "mark": "reroll", "comp": true, "note": "warmer"},
  "21": {"file": "shots/I_candidates/v.009/21.mp4", "mark": null, "note": "keep the blink"}
 }
}
```

`file` is relative to the XML's folder and always names an original, never a copy. `mark` is the shot state: `reroll`, `recirculate`, `final` or `null` (a `candidate` from an older save is kept as it is). `comp` is the comp switch: `true` when on, left out when off. An older save's `"mark": "comp"` reads as the switch on with no state, and is written back that way. Only shots with a choice or a note are listed. `note` is the shot's one-line note from the box; a note nobody edited this session is kept as it was. `by` is who set the state or note: whoever is logged in, lowercased, or the name it maps to in the reviewers file (`review_reviewers` in `script-opts/shot_jump.conf`, `{"logins": {"login": "name"}}`). It is written when someone sets a state, flips the comp switch or edits a note, dropped when the state, the switch and the note are gone, and an entry nobody touched keeps its saved `by`. The set state shows the name beside it.

**Opening.** The review XML is the one named by `review_xml` (default `review.xml`). Before it loads, mpv runs the project's build script so the XML matches the folders and the saved choices; every shot starts on its chosen version, with its state lit. If the script can't run, mpv says why and plays the XML as it is.

**Any other XML in the same folders** (a dated daily, say) is browse-only: `UP` / `DOWN` work, nothing is saved, and the note says to open the review XML to choose.

**New, unseen versions: the green bell.** A version counts as seen the moment `UP` / `DOWN` steps onto it (even with the key held down), or once it has been on screen for about a quarter second in a review. The editor's mpv records that in `shots/seen.json` (`{"since", "files": {path: {"at", "by"}}}`, written a few seconds later and on quit; a preview doesn't record). A shot with versions nobody has seen yet (runs, run candidates, driver candidates, candidates and the final; not plates, nothing retired) shows a green bell over its label with *N new*; step through them with `DOWN` and the count drops as each one shows, then the bell goes away. Everything made before the day `seen.json` was started (the first review that opened it) counts as seen, and so does every version the choices file names (it was picked in a review), so only generations made since then and not yet looked at show up as new.

**Notes from a recorded review: `i`, then `Tab`.** The project can turn a recording of someone talking over a daily into a notes file per recording, in `review_notes_dir` (set in `script-opts/shot_jump.conf`): `{"reviewer", "source", "shots": {"07": {"file", "label", "note", "mark"}}, "general": [...]}`. In the review, `i` imports the newest file not imported yet (`i` again takes the next older), and a card says whose it is, how many notes went straight in and how many wait, and shows its general notes. A note goes straight in, as if typed, when its shot still plays the version it was made on and has no note or state of its own. The rest wait. `Tab` / `Shift+Tab` step through the imported notes: mpv jumps to the shot, pauses, and shows the note in a panel under the state row (`imported 3 of 11`), with the saved note under it if the shot has one, or *note was for run 55* if a newer version has landed since. `Enter` accepts it onto the version showing and moves on, `n` edits the text first, `r` / `c` / `m` / `a` choose its state, `x` skips it (taking back one that went straight in), `Esc` stops stepping. Accepted notes are saved as yours (`by`), like any note. Save records the file in `selects.json` under `"imported"`, so it isn't offered again; nothing writes the notes files.

**Someone else has it open: preview.** Opening the review writes `review.xml.lock` beside it (your name, your computer, a heartbeat every minute) and quitting removes it. Anyone who opens the review while that lock is fresh, on any computer that shares the folder, gets a **preview**: a yellow line where the state row would be says who has it open and since when, and they can look and step through versions, but can't set states, write notes or save, and the project's build script isn't run for them. When the editor quits, the preview says so; quit and open again to make changes. A lock whose heartbeat is ten minutes old (a crash, a laptop that went to sleep) is free again. If two people open it within the same minute, the next heartbeat leaves one of them as the editor and switches the other to preview; Save checks the lock again first, so a stale state is never written over the choices.

**Quitting** with unsaved choices asks **Save changes?** Yes saves as above and then quits, No forgets the session's choices (nothing was written, so nothing needs undoing), Cancel carries on. Tick **Also save an .mp4 of the review** (click it or press `V`; off by default) and Yes also renders the rebuilt review XML to an `.mp4` beside it (`review.xml` → `review.mp4`) behind a **SAVING…** card, then quits; pressing quit again skips the video. It renders only when the save went through, so the video never shows an XML the scripts failed to rebuild. Its sound is the approved edit's: the XML's audio clip named by `export_audio_clip` in `script-opts/shot_jump.conf` (kept disabled in the XML, so an editor importing it doesn't hear it under the voice), in its own channels. Without that clip the video carries the first audio track, as mpv plays it.

**Start and end frames: `Ctrl+S`.** On the first frame of a shot it saves `NN_start.png`, on the last frame `NN_end.png`: the clean video frame of the version showing, with no label or buttons. They go in the frames rung (the `C_` folder), in one new pass per mpv session, opened on the first save. A file that is already there is never replaced. On any other frame `Ctrl+S` takes the usual numbered snapshot.

**Setting it up.** `script-opts/shot_jump.conf` names the review XML and the project's scripts, each as a path under the XML's folder plus arguments. They are run as `uv run --directory <xml folder> --script <path> <arguments>`, so the project needs [uv](https://docs.astral.sh/uv/) installed (`review_runner` takes its full path when mpv can't find it). Leave the commands empty to save the choices file and nothing more.

### Plain XMLs: reject and restore

An XML whose clips aren't in a rung layout has no versions and no marks. Pause on a clip and a thumbs-down button appears top-right; while the pointer is near it, mpv's own on-screen controls stay hidden so they don't take the click.

| Button | Key | Does |
|--------|-----|------|
| thumbs-down | `r` | Reject: move the clip to `retired/<its path relative to the XML>` beside the XML and mark it disabled in the XML. Its slot plays as a dark gray **REJECTED** clip, so nothing after it shifts |
| rotate-ccw (gray) | `u` | Restore: put the clip back where it was and enable it again |

`LEFT`/`RIGHT` stop on every slot, rejected ones included. A clip used more than once in the edit can't be rejected. The first time the XML changes, the original is kept beside it as `<name>.xml.bak`.

### Quitting a plain XML: Save changes? Yes / No / Cancel

Rejects and restores happen on disk right away, so you see the result as you go. Quit (`Esc`, `q`, window close, Cmd+Q) after changing anything and a full-frame prompt asks **Save changes?**

| Choice | Key | What happens |
|--------|-----|--------------|
| **Yes** | `Y` | Keep everything. If the edit changed, render a fresh video of it (below), then quit. |
| **No** (default) | `N` or `Enter` | Put everything back as it was when the XML was opened: every moved file returns and the XML is restored exactly (a `.bak` made this session is removed). |
| **Cancel** | `C` or `Esc` | Close the prompt and carry on, right where you were. |

The arrow keys and `Tab` move the highlight, and `Enter` takes it. You can also click a button. A quit that never shows the prompt (a crash aside) counts as **No**, so nothing is overwritten by accident.

**The video (Yes only).** mpv renders the whole edit beside the XML with the XML's name (`cut.xml` → `cut.mp4`), replacing the old one, and quits once that's done. A full-frame **SAVING…** card covers the picture meanwhile, with the file name and a seconds counter.
- **Encode:** H.264 High at CRF 18 with bt709 colour tags, every clip converted to the edit's size and 8-bit 4:2:0 (so a 10-bit take in the cut doesn't stop the render), at the edit's frame rate with every frame present (a short source holds its last frame), plus AAC at 48 kHz with the soundtrack's channels.
- **Burned in:** the shot labels and any REJECTED / MISSING cards, positioned as on screen.
- **Writing:** the render goes to a hidden temp file and is renamed over the old video only when it's complete. If it fails, the old video stays and the message says why.
- **Skipping:** quit again while it renders to skip the video and leave the old one untouched.

A review never renders a video; the project's own tools make its dailies.

## Scripts

| Script | Status | Purpose |
|--------|--------|---------|
| `copy_remove_attempt_suffix.lua` | Active | Core workflow: filtering, variant mode, navigation, rename, shift, snapshot, trash |
| `browse_to_next_folder.lua` | Active | Jump to next sibling folder |
| `send_to_selects.lua` | Active | Copy file to `../selects/` |
| `single_instance.lua` | Active | One mpv at a time: a second launch hands its file to the running one, which comes to the front |
| `shot_jump.lua` | Active | Shot review: shot jumps on `LEFT`/`RIGHT`, cut scan, FCP7 XML assemblies with shot labels, a shot's history on `UP`/`DOWN`, group review (shot states saved to one choices file), start / end frames |
| `autoload.lua` | Disabled | Upstream autoload (replaced by `autoload-files` in `mpv.conf`) |
| `filename_display_navigation.lua` | Disabled | Superseded by `copy_remove_attempt_suffix.lua` |

## Tools

| File | Purpose |
|------|---------|
| `tools/copy_to_selects.ps1` | PowerShell helper called by `send_to_selects.lua` |
