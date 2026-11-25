# reviewapp.ps1 — one-click shortcut that opens a review XML in mpv (the Windows twin of reviewapp.sh)
# Usage: powershell -ExecutionPolicy Bypass -File reviewapp.ps1 "D:\path\to\review.xml" ["App Name"] [-Mpv "C:\path\to\mpv.exe"] [-Preview]
#
# Puts the shortcut in the Start menu (right-click it there: Pin to taskbar) and on the Desktop.
# mpv.exe: -Mpv, else the one beside this script (portable, with portable_config beside it),
# else the one on PATH (winget). The paths are written into the shortcut, so each PC makes its own.
# -Preview: the shortcut opens it look only (step through versions; no states, notes or Save,
# and no XML or video written). Run it again without -Preview to undo; it replaces the shortcut.

param(
    [Parameter(Mandatory = $true, Position = 0)][string]$Xml,
    [Parameter(Position = 1)][string]$Name,
    [string]$Mpv,
    [switch]$Preview
)
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $Xml -PathType Leaf)) { Write-Host "Error: '$Xml' not found" -ForegroundColor Red; exit 1 }
$Xml = (Resolve-Path -LiteralPath $Xml).ProviderPath

if (-not $Mpv) {
    $beside = Join-Path $PSScriptRoot "mpv.exe"
    if (Test-Path -LiteralPath $beside) { $Mpv = $beside }
    else {
        $cmd = Get-Command mpv -ErrorAction SilentlyContinue
        if ($cmd) { $Mpv = $cmd.Source }
    }
}
if (-not $Mpv -or -not (Test-Path -LiteralPath $Mpv)) {
    Write-Host "Error: mpv.exe not found. Pass -Mpv `"C:\path\to\mpv.exe`"." -ForegroundColor Red; exit 1
}
$Mpv = (Resolve-Path -LiteralPath $Mpv).ProviderPath

if (-not $Name) {
    $folder = Split-Path -Leaf (Split-Path -Parent $Xml)
    $Name = $folder.Substring(0, 1).ToUpper() + $folder.Substring(1) + " Review"
}
$file = ($Name -replace '[\\/:*?"<>|]', '-') + ".lnk"

$shell = New-Object -ComObject WScript.Shell
$places = @([Environment]::GetFolderPath("Programs"), [Environment]::GetFolderPath("Desktop"))
foreach ($dir in $places) {
    $lnk = $shell.CreateShortcut((Join-Path $dir $file))
    $lnk.TargetPath = $Mpv
    $lnk.Arguments = $(if ($Preview) { '--script-opts-append=shot_jump-preview=yes ' } else { '' }) + '"' + $Xml + '"'
    $lnk.WorkingDirectory = Split-Path -Parent $Xml
    $lnk.IconLocation = "$Mpv,0"
    $lnk.Description = "Open $Name in mpv"
    $lnk.Save()
    Write-Host "Made $(Join-Path $dir $file)"
}
Write-Host ("Opens: $Xml" + $(if ($Preview) { "  (look only)" } else { "" }))
Write-Host "To pin it: Start menu, right-click '$Name', Pin to taskbar." -ForegroundColor Green
