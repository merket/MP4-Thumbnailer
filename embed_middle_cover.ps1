# embed_middle_cover.ps1
Param(
    [string]$FFMPEG = 'M:\000_YT-DLG\ffmpeg.exe',
    [string]$FFPROBE = 'M:\000_YT-DLG\ffprobe.exe'
)

# Basic checks
if (-not (Test-Path $FFMPEG)) {
    Write-Host "ERROR: ffmpeg not found at $FFMPEG" -ForegroundColor Red
    exit 1
}
if (-not (Test-Path $FFPROBE)) {
    Write-Host "ERROR: ffprobe not found at $FFPROBE" -ForegroundColor Red
    exit 1
}

Write-Host "Using ffmpeg: $FFMPEG"
Write-Host "Using ffprobe: $FFPROBE"
Write-Host "Scanning folder: $(Get-Location)"
Write-Host ""

$files = Get-ChildItem -Path . -Filter '*.mp4' -File -ErrorAction SilentlyContinue
if (-not $files) {
    Write-Host "No .mp4 files found in this folder." -ForegroundColor Yellow
    exit 0
}

foreach ($f in $files) {
    Write-Host "Processing: $($f.Name)"
    try {
        $durRaw = & "$FFPROBE" -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 -i "$($f.FullName)" 2>$null
        if (-not $durRaw) {
            Write-Warning "  Could not read duration, skipping."
            continue
        }

        $dur = [double]::Parse($durRaw.Trim(), [Globalization.CultureInfo]::InvariantCulture)
        # use 40% to avoid fade-in/out frames; change to 0.5 for exact middle
        $mid = [math]::Round($dur * 0.4, 3)

        Write-Host ("  Duration: {0} s  Midpoint: {1} s" -f $dur, $mid)

        $cover = Join-Path $f.DirectoryName ("__cover_{0}.jpg" -f ([guid]::NewGuid().ToString()))
        & "$FFMPEG" -hide_banner -loglevel error -ss $mid -i "$($f.FullName)" -frames:v 1 -q:v 2 -y "$cover"

        if (-not (Test-Path $cover)) {
            Write-Warning "  Frame extraction failed, skipping."
            continue
        }

        $temp = Join-Path $f.DirectoryName ("__temp_{0}.mp4" -f ([guid]::NewGuid().ToString()))
        & "$FFMPEG" -hide_banner -loglevel error -i "$($f.FullName)" -i "$cover" -map 0 -map 1 -c copy -c:v:1 mjpeg -disposition:v:1 attached_pic -y "$temp"

        if (Test-Path $temp) {
            Move-Item -Force "$temp" "$($f.FullName)"
            Remove-Item -Force "$cover"
            Write-Host "  Done." -ForegroundColor Green
        } else {
            Write-Warning "  Embedding cover failed."
            Remove-Item -ErrorAction SilentlyContinue "$cover"
        }
    } catch {
        Write-Warning ("  Error processing file: {0}" -f $_.Exception.Message)
        Remove-Item -ErrorAction SilentlyContinue "$cover"
    }
    Write-Host ""
}

Write-Host "All files processed." -ForegroundColor Cyan
