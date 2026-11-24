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
| `r` / `c` / `m` / `a` | Review: shot state **re-roll** / **re-circulate** / **comp** / **final**. The same key again clears it. Or click the row across the top (shown while paused) |
| `x` | Review: clear the shot's choice |
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

**Shot labels.** Each clip's `<comments><mastercomment1>` is drawn bottom-right of the picture, scaled with it:
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

**A shot's history: `UP` / `DOWN`.** `LEFT` / `RIGHT` move between shots; `UP` / `DOWN` move through every version of the shot you're on. `DOWN` all the way is the final, `UP` all the way is the cleaned plate, and the ends stop. In an XML assembly `LEFT` / `RIGHT` pause on the shot's first frame, and `UP` / `DOWN` pressed during playback pause there too, so a swap always lands on the shot on screen. In between, from the bottom: candidates, driver candidates, run candidates, runs. Within a rung the newest pass comes first (`v.002` is newer than `v.001`), with that rung's `retired/` takes under its live ones. The cropped plate under the cleaned one is left out unless it is all the shot has. A file that is only a copy of a lower one (a final copied from a candidate, a pick copied from a run) isn't listed twice: the original is shown, and the small line over the label says where copies of it sit (`in final`).

Each press swaps that version into the slot, on the same frame (pressed during playback, it pauses on the shot's first frame), and a note shows where you are (`07 run 12 · 4 / 9`). The swap is held in memory: nothing is written until you save.

**Shot state.** Pause on a shot and a row of four text buttons appears across the top of the picture. One state per shot, on the version showing: click one (or press its key) to set it, click the set one again to clear it. A set state is drawn in its colour with a bar under it; the others are gray.

| Button | Key | Means |
|--------|-----|-------|
| re-roll | `r` | **Mark for re-roll**: make a new run of the shot |
| re-circulate | `c` | **Mark for re-circulation**: make a new driver from this take, then re-roll |
| comp | `m` | **Mark for comp**: make a candidate from it |
| ★ final | `a` | **Mark as final**: the star fills yellow |

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
  "21": {"file": "shots/I_candidates/v.009/21.mp4", "mark": null, "note": "keep the blink"}
 }
}
```

`file` is relative to the XML's folder and always names an original, never a copy. `mark` is the shot state: `reroll`, `recirculate`, `comp`, `final` or `null` (a `candidate` from an older save is kept as it is). Only shots with a choice are listed, and a `note` already in the file is kept.

**Opening.** The review XML is the one named by `review_xml` (default `review.xml`). Before it loads, mpv runs the project's build script so the XML matches the folders and the saved choices; every shot starts on its chosen version, with its state lit. If the script can't run, mpv says why and plays the XML as it is.

**Any other XML in the same folders** (a dated daily, say) is browse-only: `UP` / `DOWN` work, nothing is saved, and the note says to open the review XML to choose.

**Quitting** with unsaved choices asks **Save changes?** Yes saves as above and then quits, No forgets the session's choices (nothing was written, so nothing needs undoing), Cancel carries on.

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
| `shot_jump.lua` | Active | Shot review: shot jumps on `LEFT`/`RIGHT`, cut scan, FCP7 XML assemblies with shot labels, a shot's history on `UP`/`DOWN`, group review (shot states saved to one choices file), start / end frames |
| `autoload.lua` | Disabled | Upstream autoload (replaced by `autoload-files` in `mpv.conf`) |
| `filename_display_navigation.lua` | Disabled | Superseded by `copy_remove_attempt_suffix.lua` |

## Tools

| File | Purpose |
|------|---------|
| `tools/copy_to_selects.ps1` | PowerShell helper called by `send_to_selects.lua` |
