param(
    [Parameter(Mandatory=$true)]
    [string]$SourceFile,
    
    [Parameter(Mandatory=$true)]
    [string]$DestinationDir
)

Write-Host ""
Write-Host "======================== POWERSHELL COPY DEBUG ========================" -ForegroundColor Cyan
Write-Host "Arguments received:" -ForegroundColor Yellow
Write-Host "  Source: $SourceFile" -ForegroundColor White
Write-Host "  Destination: $DestinationDir" -ForegroundColor White
Write-Host ""

# Check if source file exists
if (-not (Test-Path $SourceFile)) {
    Write-Host "ERROR: Source file does not exist: $SourceFile" -ForegroundColor Red
    Get-Item $SourceFile -ErrorAction SilentlyContinue
    exit 1
}

Write-Host "✓ Source file exists" -ForegroundColor Green
$sourceInfo = Get-Item $SourceFile
Write-Host "File info: $($sourceInfo.Name) ($($sourceInfo.Length) bytes)" -ForegroundColor Gray
Write-Host ""

# Check/create destination directory
if (-not (Test-Path $DestinationDir)) {
    Write-Host "Creating destination directory: $DestinationDir" -ForegroundColor Yellow
    try {
        New-Item -Path $DestinationDir -ItemType Directory -Force | Out-Null
        Write-Host "✓ Directory created successfully" -ForegroundColor Green
    }
    catch {
        Write-Host "ERROR: Failed to create directory: $_" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "✓ Destination directory exists" -ForegroundColor Green
}

# Perform the copy
$fileName = Split-Path $SourceFile -Leaf
$destinationPath = Join-Path $DestinationDir $fileName

Write-Host ""
Write-Host "Attempting copy operation..." -ForegroundColor Yellow
Write-Host "Command: Copy-Item '$SourceFile' to '$destinationPath'" -ForegroundColor Gray

try {
    # Try using Copy-Item with Force flag (better for Google Drive)
    Copy-Item -Path $SourceFile -Destination $destinationPath -Force
    
    # Verify the copy
    if (Test-Path $destinationPath) {
        $destInfo = Get-Item $destinationPath
        Write-Host "✓ Copy completed successfully" -ForegroundColor Green
        Write-Host "✓ File verified in destination: $($destInfo.Name) ($($destInfo.Length) bytes)" -ForegroundColor Green
        
        # Check if sizes match
        if ($sourceInfo.Length -eq $destInfo.Length) {
            Write-Host "✓ File sizes match" -ForegroundColor Green
        } else {
            Write-Host "⚠ WARNING: File sizes don't match!" -ForegroundColor Yellow
            Write-Host "  Source: $($sourceInfo.Length) bytes" -ForegroundColor Gray
            Write-Host "  Dest:   $($destInfo.Length) bytes" -ForegroundColor Gray
        }
        
        exit 0
    } else {
        Write-Host "✗ Copy failed - file not found in destination" -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-Host "✗ Copy failed with error: $_" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "========================================================" -ForegroundColor Cyan
    Write-Host ""
} 