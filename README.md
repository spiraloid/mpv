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
5. Pause on a clip from a rung folder (e.g. `shots/I_candidates/`). Thumbs up / down buttons appear top-right. To try it safely, press thumbs down: the slot drops to the next file down the rungs. Then press the un-retire arrow: the clip comes straight back. Thumbs up copies the clip into `shots/K_final/` for real. Quitting after a reject renders a fresh `<xml name>.mp4`, so try this on a copy of the edit if the current video matters.
6. Middle click drops to a quarter-size window top-left; middle click again returns to fullscreen.
7. Press `h` for every key.

If something's off:
- **A console window flashes when you approve, reject or un-retire (Windows).** The file moves go through PowerShell, like Rename and Trash.
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

### Playback & Navigation

| Key | Action |
|-----|--------|
| `SPACE` | Next image · toggle pause (video/audio) |
| `UP` / `DOWN` | Previous / next playlist item |
| `Shift+LEFT` / `Shift+RIGHT` | Seek −5 s / +5 s |
| `WHEEL_UP` / `WHEEL_DOWN` | Frame back/forward (video) · prev/next item (image/audio) · prev/next shot (XML assembly) |
| `Alt+WHEEL_UP` / `Alt+WHEEL_DOWN` | Prev / next item of same media type only |
| `PGUP` / `PGDWN` | Previous / next playlist item |

### Shot Review Keys

| Key | Action |
|-----|--------|
| `LEFT` / `RIGHT` | Previous / next shot, landing on its first frame. Frame step when the file has no known cuts |
| `WHEEL_UP` / `WHEEL_DOWN` | Previous / next shot, one per notch (XML assembly) |
| `a` | Approve the clip on screen. On a REJECTED slot, un-retire |
| `r` | Reject the clip on screen. In a rung layout the slot falls back to the next file down |
| `u` | Un-retire: bring back the shot's next newer retired version |
| `o` | Show / hide the shot label and buttons (outside an XML assembly: mpv's progress bar) |
| `,` / `.` | Frame back / forward (mpv defaults) |

`a`, `r`, `u` and `o` work while an FCP7 XML is playing as an assembly (see [Shot review](#shot-review) below). Quitting after a change saves the XML and renders a fresh video of the edit first.

### Fullscreen

| Key | Action |
|-----|--------|
| `f` | Toggle fullscreen |
| `ENTER` | Toggle fullscreen |
| `Alt+Enter` | Toggle fullscreen |
| `Middle mouse` | Fullscreen → a window a quarter of the screen (half width × half height) in the top-left corner · click again → fullscreen |

### Frame Workflow

| Key | Action |
|-----|--------|
| `s` / `Alt+s` | Copy file to same folder, stripping `_attempt_##` suffix |
| `\` | Toggle variant mode — show/hide `_attempt_##` files |
| `Ctrl+RIGHT` | Shift current frame group forward (swap with next group) |
| `Ctrl+LEFT` | Shift current frame group backward (swap with previous group) |
| `DEL` | Move current file to Recycle Bin |
| `F2` | Rename current file |

### Capture & Clipboard

| Key | Action |
|-----|--------|
| `Ctrl+s` | Save numbered PNG snapshot (`basename_001.png`, auto-increments) |
| `Ctrl+c` | Copy current video frame to clipboard |

### Folder & Selects

| Key | Action |
|-----|--------|
| `Ctrl+n` | Jump to next sibling folder and load all its media |
| `Ctrl+Enter` | Copy current file to `../selects/` |

### Misc

| Key | Action |
|-----|--------|
| `h` | Show / hide in-player help overlay |
| `Ctrl+r` | Force playlist rebuild |
| `ESC` | Quit |

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
- A slot playing a fallback after a reject is labelled for what it actually shows (see below).

### Approve, reject, un-retire

Pause on a clip and round buttons appear top-right of the picture. They hide again when playback resumes. While the pointer is near them, mpv's own on-screen controls (including the minimize / maximize / close buttons a borderless window shows in that corner) stay hidden, so the click always reaches them. Click them or use the keys:

| Button | Key | Does |
|--------|-----|------|
| rotate-ccw | `u` | Un-retire: bring back the next newer retired version. Shown only when there is one |
| thumbs-up | `a` | Approve: copy the clip to the finals. Solid with a filled thumb once the shot has a final |
| thumbs-down | `r` | Reject: move the clip into a `retired/` folder. Grayed out when nothing is left to reject |

Approve copies to a hidden `.NN.mp4.part` first and renames it only when complete, so a half-copied file never shows up as a final. `LEFT`/`RIGHT` stop on every slot, rejected ones included. A clip used more than once in the edit (e.g. an opening shot repeated at the end) can't be rejected outside a rung layout.

### Hierarchical review: clearing out the rungs

When the clips sit in a shots folder made of lettered **rungs**, the assembly becomes a review tool for that whole pipeline. You work your way down each shot's history from the player, and every reject clears a file out of the way. Rungs are subfolders named `<letter>_<stage>`: plates at the bottom, then everything built from them (frames, prompts, audio, runs, drivers, candidates, comps), up to finals at the top:

```
shots/
  A_cropped_plates/07.mp4                 <- bottom rung
  B_cleaned_plates/07.mp4
  ...
  F_runs/v.000/11-22__0701/07.mp4
  F_runs/v.000/11-22__1242/07.mp4         <- newer run
  ...
  I_candidates/v.000/11-22__1300/07.mp4   <- what the XML plays
  ...
  K_final/                                <- top rung: approved shots
```

A shot's file is one named for its shot number: `07.mp4` or `07_v4.mp4`, anywhere inside a rung, in any video format. Drivers (`07_driver.mp4`), comp layers (`07_character.mov`), frames, prompts, audio and the masters in an `uncompressed/` folder don't count.

**Reject walks down.** Reject moves the file on screen to `<its rung>/retired/<same path>`, and the slot plays the next file down:
1. The newest remaining file for that shot (by modified date) in the same rung.
2. When that rung has none left, the newest one in the next rung down.
3. And so on, down to `A_`.

Keep pressing `r` and you step back through the shot's history, from candidate, to the latest run, to the older run, to the cleaned plate, to the cropped plate. The label follows: it reads `07 run 00` while a run plays and `07 cleaned plate` on the plate, with the pass number taken from the `v.NNN` folder. Only when nothing at all is left is the slot the dark gray **REJECTED** clip.

**Un-retire walks back up, like a playhead.** Think of a shot's versions as a tape, ordered by rung and then by date: `A_` plates at the start, the newest file in the highest rung at the end. What the slot shows is the playhead. Reject rewinds it. Un-retire (the rotate-ccw button or `u`) moves it forward: it takes the retired version of that shot just *above* what's showing, from any rung's `retired/` folder, moves it back to its old folder (recreated if needed), and plays it.

So you can reject your way down to see every version of a shot, every run and every plate, then press un-retire on repeat. It brings them back earliest first and ends on the latest. Nothing is logged; the folders are the tape:
- **Any retired file counts,** whether mpv retired it, another tool did, or you moved it by hand.
- **A retired file below the playhead waits.** It comes back in order once you've rewound past it.
- **A file whose old place is taken is skipped.**
- **Undo everything** and the folders, the XML and its `.bak` are exactly as they started.

**Approve** copies the file on screen, from whatever rung it's in, to the finals rung as `K_final/NN.<ext>` (named after the shot number). It refuses if that shot already has a final. Rejecting a final moves it to `K_final/retired/` and the slot drops to the rung below.

**Every copy of the edit agrees.** The folders decide what plays, not the XML that happens to be open. Another copy of the same edit, or an older one, plays the same fallback the moment it's opened. A copy whose file still names a rejected clip walks down from that clip's rung.

**Other XMLs.** Clips that aren't in a rung layout have no Approve and no walk. Reject moves the clip to `retired/<its path relative to the XML>` beside the XML (or `retired/<file name>` from outside its folder), and the slot plays as REJECTED until you un-retire it.

### Saving: the XML, then a fresh video

Every approve, reject and un-retire is written to the XML straight away. Rejects and un-retires point its clipitem's `pathurl` at the file now playing, and give the label (`<mastercomment1>`) the stage of that file. The first change also saves the XML's original as `<name>.xml.bak`.

When you quit after changing an assembly, mpv first finishes any action still in flight and saves the XML. Then it renders a new video of the whole edit beside it, with the XML's name (`daily.xml` → `daily.mp4`), replacing the old one, and only quits once that's done. A full-frame **SAVING…** card covers the picture while it renders, with the file name and a seconds counter.
- **Encode:** H.264 High at CRF 18 with bt709 colour tags, at the edit's frame rate with every frame present (a short source holds its last frame), plus AAC at 48 kHz with the soundtrack's channels.
- **Burned in:** the shot labels and any REJECTED / MISSING cards, positioned as on screen.
- **Writing:** the render goes to a hidden temp file and is renamed over the old video only when it's complete.
- **Skipping:** quit again while it renders to skip the video and leave the old one untouched.
- **Quitting another way** (menu, window close on some systems) still renders it, in the background after mpv has gone.

Quitting without having changed anything just quits.

## Scripts

| Script | Status | Purpose |
|--------|--------|---------|
| `copy_remove_attempt_suffix.lua` | Active | Core workflow: filtering, variant mode, navigation, rename, shift, snapshot, trash |
| `browse_to_next_folder.lua` | Active | Jump to next sibling folder |
| `send_to_selects.lua` | Active | Copy file to `../selects/` |
| `shot_jump.lua` | Active | Shot review: shot jumps on `LEFT`/`RIGHT`, cut scan, FCP7 XML assemblies with shot labels, approve / reject / un-retire buttons |
| `autoload.lua` | Disabled | Upstream autoload (replaced by `autoload-files` in `mpv.conf`) |
| `filename_display_navigation.lua` | Disabled | Superseded by `copy_remove_attempt_suffix.lua` |

## Tools

| File | Purpose |
|------|---------|
| `tools/copy_to_selects.ps1` | PowerShell helper called by `send_to_selects.lua` |
