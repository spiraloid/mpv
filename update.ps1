# update.ps1 — pull latest config and sync to mpv's config folder (Option A / winget install)
# Run from anywhere: powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\mpv-config\update.ps1"

$repoDir = "$env:USERPROFILE\mpv-config"
$configDir = "$env:APPDATA\mpv"

Write-Host "Pulling latest config..."
git -C $repoDir pull

if ($LASTEXITCODE -ne 0) {
    Write-Host "git pull failed." -ForegroundColor Red
    exit 1
}

Write-Host "Copying config to $configDir ..."
Copy-Item "$repoDir\portable_config\*" $configDir -Recurse -Force

Write-Host "Done." -ForegroundColor Green
