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
5. Pause on a clip from `shots/I_candidates/`. Thumbs up / down buttons appear top-right. To try it safely, press thumbs down and then the undo arrow: the clip moves to `retired/` and comes straight back. Thumbs up copies the clip into `shots/K_final/` for real.
6. Middle click drops to a quarter-size window top-left; middle click again returns to fullscreen.
7. Press `h` for every key.

If something's off:
- **A console window flashes when you approve, reject or undo (Windows).** The file moves go through PowerShell, like Rename and Trash.
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
| `a` | Approve the clip on screen. On a rejected clip, undo the reject |
| `r` | Reject the clip on screen |
| `o` | Show / hide the shot label and buttons (outside an XML assembly: mpv's progress bar) |
| `,` / `.` | Frame back / forward (mpv defaults) |

`a`, `r` and `o` work while an FCP7 XML is playing as an assembly (see [Shot review](#shot-review) below).

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

### Approve, reject, undo

Pause on a clip and round buttons appear top-right of the picture. They hide again when playback resumes. Click them or use the keys:

| On a clip | Left button (`a`) | Right button (`r`) |
|-----------|-------------------|--------------------|
| Not yet reviewed | thumbs-up: approve | thumbs-down: reject |
| Approved | solid, filled thumb (done) | thumbs-down: reject |
| Rejected | rotate-ccw: undo the reject | grayed out |

**Approve** copies the clip to a finals folder (see the layout below). It refuses if that shot already has a final. The copy goes to a hidden `.NN.mp4.part` first and is renamed only when complete, so a half-copied file never shows up as a final.

**Reject** does three things:
- Moves the clip into a `retired/` folder.
- Marks its clipitem `<enabled>FALSE</enabled>` in the XML and points the clipitem's `pathurl` at the new location.
- Saves the XML's first version as `<name>.xml.bak`.

The slot stays in the edit as a dark gray clip with a large **REJECTED** across it, so everything after it keeps its timing. If the shot has a cleaned plate (`shots/B_cleaned_plates/NN.<ext>`, same number as the clip), the plate plays under the gray at 33% so you can still see what the shot is. With no plate, the slot is solid gray. `LEFT`/`RIGHT` still stop on it, so you can see it and undo it. The REJECTED card stays even with `o` off, since it stands in for the picture.

In the review layout, the folder decides what's rejected, not the XML that happens to be open. Any XML that uses a candidate now under `retired/` (another copy of the same edit, or an older one) plays it as REJECTED at full length, and undo works from there too. Undo in one copy also clears the reject in the others. A copy's file may still read `<enabled>FALSE</enabled>`, but once the clip is back in place it plays normally.

**Undo** (the rotate-ccw button, or `a` on a rejected clip) puts everything back as if the reject never happened:
- The clip moves back to its old folder, which is recreated if it was removed.
- The empty folders it left under `retired/` are removed.
- The XML gets its `pathurl` back and loses the `<enabled>FALSE</enabled>` line.
- The `.bak` is deleted if the XML now matches it again.

The XML is updated the moment you approve, reject or undo; there's nothing to save. If you quit right after pressing a key, the action is finished before mpv closes. A clip that's already rejected can't be approved. A clip used more than once in the edit (e.g. an opening shot repeated at the end) can't be rejected.

### Where approved and rejected clips go

**Review layout.** When clips live under a `shots/I_candidates/` folder:
- Only clips from `I_candidates` get buttons. Other clips (plates, the edit itself) don't.
- Approve copies `.../I_candidates/<any path>/NN.mp4` to `shots/K_final/NN.mp4`, where `NN` is the number the file name starts with.
- Reject moves the clip to `shots/I_candidates/retired/<same path>` and removes its folder if that leaves it empty. Clips with the same name from different folders never collide.

```
shots/
  I_candidates/
    v.000/11-22__1206/03.mp4      <- candidate
    retired/v.000/11-22__1300/07.mp4   <- rejected (r)
  K_final/
    03.mp4                         <- approved (a)
```

**Any other XML.** There's no Approve. Reject moves the clip to `retired/<its path relative to the XML>` beside the XML. A clip outside the XML's folder goes to `retired/<file name>`.

## Scripts

| Script | Status | Purpose |
|--------|--------|---------|
| `copy_remove_attempt_suffix.lua` | Active | Core workflow: filtering, variant mode, navigation, rename, shift, snapshot, trash |
| `browse_to_next_folder.lua` | Active | Jump to next sibling folder |
| `send_to_selects.lua` | Active | Copy file to `../selects/` |
| `shot_jump.lua` | Active | Shot review: shot jumps on `LEFT`/`RIGHT`, cut scan, FCP7 XML assemblies with shot labels, approve / reject / undo buttons |
| `autoload.lua` | Disabled | Upstream autoload (replaced by `autoload-files` in `mpv.conf`) |
| `filename_display_navigation.lua` | Disabled | Superseded by `copy_remove_attempt_suffix.lua` |

## Tools

| File | Purpose |
|------|---------|
| `tools/copy_to_selects.ps1` | PowerShell helper called by `send_to_selects.lua` |
