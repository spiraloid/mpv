# mpv portable config

A portable Windows mpv configuration for reviewing and curating numbered frame sequences — attempt variants, folder hopping, selects copying, and frame-group reordering.

## Quickstart

**Option A — winget (installed)**

```powershell
winget install -e --id shinchiro.mpv
git clone https://github.com/spiraloid/mpv.git "$env:USERPROFILE\mpv-config"
Copy-Item "$env:USERPROFILE\mpv-config\portable_config\*" "$env:APPDATA\mpv\" -Recurse -Force
```

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
| `LEFT` / `RIGHT` | Frame back / frame forward (video) |
| `Shift+LEFT` / `Shift+RIGHT` | Seek −5 s / +5 s |
| `WHEEL_UP` / `WHEEL_DOWN` | Frame back/forward (video) · prev/next item (image/audio) |
| `Alt+WHEEL_UP` / `Alt+WHEEL_DOWN` | Prev / next item of same media type only |
| `PGUP` / `PGDWN` | Previous / next playlist item |

### Fullscreen

| Key | Action |
|-----|--------|
| `f` | Toggle fullscreen |
| `ENTER` | Toggle fullscreen |
| `Alt+Enter` | Toggle fullscreen |
| `Middle mouse` | Toggle fullscreen |

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

## Scripts

| Script | Status | Purpose |
|--------|--------|---------|
| `copy_remove_attempt_suffix.lua` | Active | Core workflow: filtering, variant mode, navigation, rename, shift, snapshot, trash |
| `browse_to_next_folder.lua` | Active | Jump to next sibling folder |
| `send_to_selects.lua` | Active | Copy file to `../selects/` |
| `autoload.lua` | Disabled | Upstream autoload (replaced by `autoload-files` in `mpv.conf`) |
| `filename_display_navigation.lua` | Disabled | Superseded by `copy_remove_attempt_suffix.lua` |

## Tools

| File | Purpose |
|------|---------|
| `tools/copy_to_selects.ps1` | PowerShell helper called by `send_to_selects.lua` |
