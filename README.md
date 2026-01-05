# MP4-Thumbnailer
Powershell script to update MP4 file thumbnails for windows. The script embeds the videos midpoint frame as artwork, thus showing that as the new thumbnail for Windows Explorer. This is especially useful for videos that have the same first frame.

The run-embed.bat file launches the PowerShell script.
The script scans all MP4 files located in the same folder, measures the duration of each video, captures a single frame from the exact midpoint, and embeds that frame as the file’s album artwork (preview thumbnail).
Tested on Windows 10 Pro (22H2).
