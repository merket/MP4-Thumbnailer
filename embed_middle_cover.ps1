# embed_middle_cover.ps1
# Version : 2.0.0
# Finds the midpoint frame of each MP4, embeds it as a thumbnail,
# and saves the result into a "Thumbnailed" subfolder.
# ORIGINALS ARE NEVER MODIFIED OR DELETED.

Param(
    [string]$FFMPEG  = 'C:\Path\ffmpeg.exe',
    [string]$FFPROBE = 'C:\Path\ffprobe.exe'
)

$VERSION = "2.0.0"

Write-Host ""
Write-Host "embed_middle_cover.ps1  v$VERSION" -ForegroundColor Cyan
Write-Host "ORIGINALS WILL NOT BE MODIFIED." -ForegroundColor Cyan
Write-Host ""

# Locate the folder the BAT file launched us from
$workDir = $PSScriptRoot
if (-not $workDir) { $workDir = (Get-Location).Path }

# Tool checks
if (-not (Test-Path $FFMPEG)) {
    Write-Host "ERROR: ffmpeg not found at $FFMPEG" -ForegroundColor Red
    exit 1
}
if (-not (Test-Path $FFPROBE)) {
    Write-Host "ERROR: ffprobe not found at $FFPROBE" -ForegroundColor Red
    exit 1
}

# Output subfolder
$outDir = Join-Path $workDir 'Thumbnailed'
if (-not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    Write-Host "Created output folder: $outDir" -ForegroundColor Cyan
}

Write-Host "ffmpeg  : $FFMPEG"
Write-Host "ffprobe : $FFPROBE"
Write-Host "Source  : $workDir"
Write-Host "Output  : $outDir"
Write-Host ""

# Collect MP4s, excluding the Thumbnailed subfolder
$files = Get-ChildItem -Path $workDir -Filter '*.mp4' -File -ErrorAction SilentlyContinue |
         Where-Object { $_.DirectoryName -ne $outDir }

if (-not $files) {
    Write-Host "No .mp4 files found in $workDir" -ForegroundColor Yellow
    exit 0
}

$ok          = 0
$skip        = 0
$fail        = 0
$changedList = @()

foreach ($f in $files) {

    Write-Host "Processing : $($f.Name)"

    $guid    = [guid]::NewGuid().ToString()
    $cover   = Join-Path $workDir ("__cover_{0}.jpg" -f $guid)
    $temp    = Join-Path $workDir ("__temp_{0}.mp4"  -f $guid)
    $outFile = Join-Path $outDir $f.Name

    try {

        # 1. Read streams from source file
        $streamsRaw = & "$FFPROBE" -v error `
                        -show_entries stream=index,codec_type,codec_name,channels,sample_rate,codec_tag_string `
                        -of default=noprint_wrappers=0 `
                        -i "$($f.FullName)" 2>$null

        # Parse stream info into objects
        $streams     = @()
        $currentStream = $null
        foreach ($line in $streamsRaw -split "`n") {
            $line = $line.Trim()
            if ($line -eq '[STREAM]') {
                $currentStream = @{ index=''; codec_type=''; codec_name=''; channels=''; sample_rate=''; codec_tag_string='' }
            } elseif ($line -eq '[/STREAM]' -and $currentStream) {
                $streams += $currentStream
                $currentStream = $null
            } elseif ($currentStream -and $line -match '^(\w+)=(.*)$') {
                $key = $Matches[1]; $val = $Matches[2]
                if ($currentStream.ContainsKey($key)) { $currentStream[$key] = $val }
            }
        }

        $videoStreams = @($streams | Where-Object { $_['codec_type'] -eq 'video' -and $_['codec_tag_string'] -ne 'tmcd' })
        $audioStreams = @($streams | Where-Object { $_['codec_type'] -eq 'audio' })
        $dataStreams  = @($streams | Where-Object { $_['codec_type'] -eq 'data' })
        $totalStreams = $streams.Count

        $hasAudio    = $audioStreams.Count -gt 0
        $hasData     = $dataStreams.Count -gt 0

        # Display stream info
        Write-Host ("  Streams found  : {0}" -f $totalStreams)
        Write-Host ("  Has audio      : {0}" -f $(if ($hasAudio) { "Yes" } else { "No" }))
        foreach ($s in $streams) {
            $desc = "  [Stream {0}] Type: {1}  Codec: {2}" -f $s['index'], $s['codec_type'], $s['codec_name']
            if ($s['codec_type'] -eq 'audio') {
                $desc += ("  Channels: {0}  Sample rate: {1}" -f $s['channels'], $s['sample_rate'])
            }
            if ($s['codec_type'] -eq 'data') {
                $desc += ("  Tag: {0}  (will be excluded from output)" -f $s['codec_tag_string'])
            }
            Write-Host $desc
        }

        # 2. Read duration
        $durRaw = & "$FFPROBE" -v error `
                    -show_entries format=duration `
                    -of default=noprint_wrappers=1:nokey=1 `
                    -i "$($f.FullName)" 2>$null

        if (-not $durRaw -or $durRaw.Trim() -eq '') {
            Write-Warning "  Cannot read duration - skipping."
            $skip++; continue
        }

        $dur = [double]::Parse($durRaw.Trim(), [Globalization.CultureInfo]::InvariantCulture)
        if ($dur -le 0) {
            Write-Warning "  Duration is zero or negative - skipping."
            $skip++; continue
        }

        $mid = [math]::Round($dur * 0.4, 3)
        Write-Host ("  Duration       : {0:F3} s   Thumbnail at: {1:F3} s" -f $dur, $mid)

        # 3. Warn user if data streams will be dropped and ask confirmation
        if ($hasData) {
            Write-Host ""
            Write-Host "  WARNING: This file contains the following data track(s) that must be" -ForegroundColor Yellow
            Write-Host "  removed because the MP4 container does not support them:" -ForegroundColor Yellow
            foreach ($ds in $dataStreams) {
                Write-Host ("    - Stream {0}: {1} ({2})" -f $ds['index'], $ds['codec_name'], $ds['codec_tag_string']) -ForegroundColor Yellow
            }
            Write-Host "  All video and audio streams will be kept." -ForegroundColor Yellow
            Write-Host ""
            $answer = Read-Host "  Remove data track(s) and continue? (Y/N)"
            if ($answer.Trim().ToUpper() -ne 'Y') {
                Write-Host "  Skipped by user." -ForegroundColor DarkGray
                $skip++; continue
            }
            $changedList += $f.Name
        }

        # 4. Check for duplicate in Thumbnailed folder
        if (Test-Path $outFile) {
            Write-Host ""
            Write-Host ("  WARNING: '{0}' already exists in the Thumbnailed folder." -f $f.Name) -ForegroundColor Yellow
            $answer = Read-Host "  Overwrite existing file? (Y/N)"
            if ($answer.Trim().ToUpper() -ne 'Y') {
                Write-Host "  Skipped by user." -ForegroundColor DarkGray
                $skip++; continue
            }
        }

        # 5. Extract thumbnail frame
        & "$FFMPEG" -hide_banner -loglevel error `
            -ss $mid -i "$($f.FullName)" `
            -frames:v 1 -q:v 2 -y "$cover" 2>$null

        if (-not (Test-Path $cover) -or (Get-Item $cover).Length -eq 0) {
            Write-Warning "  Frame extraction failed - skipping."
            $skip++; continue
        }

        # 6. Embed thumbnail into temp file
        # -map 0      : copy all streams from source
        # -map -0:d   : subtract data-type streams (removes tmcd etc., keeps all audio and video)
        # -map 1      : add the thumbnail image as attached picture
        $ffmpegErr = & "$FFMPEG" -hide_banner -loglevel error `
            -i "$($f.FullName)" -i "$cover" `
            -map 0 -map -0:d -map 1 `
            -c copy -c:v:1 mjpeg `
            -disposition:v:1 attached_pic `
            -y "$temp" 2>&1

        # 7. Validate output file
        if (-not (Test-Path $temp)) {
            Write-Warning "  ffmpeg produced no output file - skipping."
            if ($ffmpegErr) { Write-Host "  ffmpeg says: $ffmpegErr" -ForegroundColor DarkYellow }
            $fail++; continue
        }

        $tempSize = (Get-Item $temp).Length
        $origSize = $f.Length

        if ($tempSize -eq 0) {
            Write-Warning "  Output is 0 bytes - skipping (original untouched)."
            if ($ffmpegErr) { Write-Host "  ffmpeg says: $ffmpegErr" -ForegroundColor DarkYellow }
            $fail++; continue
        }

        if ($origSize -gt 0 -and $tempSize -lt ($origSize * 0.5)) {
            Write-Warning ("  Output ({0} bytes) is less than 50% of original ({1} bytes) - skipping." -f $tempSize, $origSize)
            if ($ffmpegErr) { Write-Host "  ffmpeg says: $ffmpegErr" -ForegroundColor DarkYellow }
            $fail++; continue
        }

        # 8. Verify output streams match source (every audio stream must be present)
        $outStreamsRaw = & "$FFPROBE" -v error `
                            -show_entries stream=codec_type,codec_name,channels,sample_rate `
                            -of default=noprint_wrappers=0 `
                            -i "$temp" 2>$null

        $outStreams      = @()
        $currentStream   = $null
        foreach ($line in $outStreamsRaw -split "`n") {
            $line = $line.Trim()
            if ($line -eq '[STREAM]') {
                $currentStream = @{ codec_type=''; codec_name=''; channels=''; sample_rate='' }
            } elseif ($line -eq '[/STREAM]' -and $currentStream) {
                $outStreams += $currentStream
                $currentStream = $null
            } elseif ($currentStream -and $line -match '^(\w+)=(.*)$') {
                $key = $Matches[1]; $val = $Matches[2]
                if ($currentStream.ContainsKey($key)) { $currentStream[$key] = $val }
            }
        }

        $outAudioStreams = @($outStreams | Where-Object { $_['codec_type'] -eq 'audio' })

        if ($hasAudio -and $outAudioStreams.Count -eq 0) {
            Write-Warning "  CRITICAL: Source had audio but output has none - rejecting output (original untouched)."
            if ($ffmpegErr) { Write-Host "  ffmpeg says: $ffmpegErr" -ForegroundColor DarkYellow }
            $fail++; continue
        }

        if ($hasAudio -and ($outAudioStreams.Count -lt $audioStreams.Count)) {
            Write-Warning ("  CRITICAL: Source had {0} audio stream(s) but output has {1} - rejecting output (original untouched)." -f $audioStreams.Count, $outAudioStreams.Count)
            $fail++; continue
        }

        # 9. Copy validated file to Thumbnailed subfolder
        Copy-Item -Path $temp -Destination $outFile -Force
        if (-not (Test-Path $outFile) -or (Get-Item $outFile).Length -ne $tempSize) {
            Write-Warning "  Copy to output folder failed or size mismatch - skipping."
            $fail++; continue
        }

        Write-Host "  Saved to : $outFile" -ForegroundColor Green
        $ok++

    } catch {
        Write-Warning ("  Unexpected error: {0}" -f $_.Exception.Message)
        $fail++

    } finally {
        # Always clean up temp files
        if (Test-Path $cover) { Remove-Item -Force $cover -ErrorAction SilentlyContinue }
        if (Test-Path $temp)  { Remove-Item -Force $temp  -ErrorAction SilentlyContinue }
    }

    Write-Host ""
}

# Summary
Write-Host "--------------------------------" -ForegroundColor Cyan
Write-Host ("Completed  : {0}" -f $ok)   -ForegroundColor Green
Write-Host ("Skipped    : {0}" -f $skip) -ForegroundColor Yellow
Write-Host ("Failed     : {0}" -f $fail) -ForegroundColor $(if ($fail -gt 0) { 'Red' } else { 'Green' })
if ($changedList.Count -gt 0) {
    Write-Host ("Changed    : {0} - {1}" -f $changedList.Count, ($changedList -join ', ')) -ForegroundColor Yellow
}
Write-Host "Originals were never modified." -ForegroundColor Cyan
