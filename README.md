
# MP4 Thumbnailer for Windows Explorer

Powershell script to update MP4 file thumbnails for windows. The script embeds the videos midpoint frame as artwork, thus showing that as the new thumbnail for Windows Explorer. This is especially useful for videos that have the same first frame.

The run-embed.bat file launches the PowerShell script.
The script scans all MP4 files located in the same folder, measures the duration of each video, captures a single frame from the exact midpoint, and embeds that frame as the file’s album artwork (preview thumbnail).
Does not touch the original files. Creates a subfolder called "Thumbnailed" and moves the temp files into here after they finish without errors.



Tested on Windows 10 Pro (22H2).


## Installation

Download the [latest release](https://github.com/merket/MP4-Thumbnailer/releases), move it to a desired location where the mp4 files are. Then double click the "run_embed.bat".

Requires ffmpeg.exe and ffprobe.exe to work. You can download official builds from https://ffmpeg.org/download.html or a reliable Windows build at https://www.gyan.dev/ffmpeg/builds/.

After obtaining the executable files, right-click on embed_middle_cover.ps1 and choose “Edit”.
Update the example directory paths on lines 3 and 4 according to where the files are located on your system:


```bash
[string]$FFMPEG  = 'C:\Path\ffmpeg.exe',
[string]$FFPROBE = 'C:\Path\ffprobe.exe'
```
    
## Authors

- M. Erke Tiryakioğlu [@merket](https://github.com/merket)

