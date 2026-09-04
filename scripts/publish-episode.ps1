# Future CFO_DP — One-command publish to GitHub (Windows PowerShell)
# Prerequisites: GitHub CLI installed + logged in  (winget install GitHub.cli  then  gh auth login)
#
# Usage:
#   1. Download today's email attachments into a folder, e.g. D:\Downloads\FUTURE_CFO_TODAY
#   2. Open PowerShell in that folder OR pass the folder path
#   3. Run:
#        .\publish-episode.ps1 -SourceDir "D:\Downloads\FUTURE_CFO_TODAY" -EpisodeFolder "2026-09-04-when-operating-profit-changes-meaning"
#
# The EpisodeFolder is the name under episodes/YYYY/MM/ on GitHub (from the morning email).

param(
  [Parameter(Mandatory = $true)][string]$SourceDir,
  [Parameter(Mandatory = $true)][string]$EpisodeFolder,
  [string]$Year = (Get-Date -Format "yyyy"),
  [string]$Month = (Get-Date -Format "MM"),
  [string]$Repo = "viralgyandk-lang/future-cfo-2035",
  [string]$Branch = "main"
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
  Write-Host "GitHub CLI (gh) not found. Install: winget install GitHub.cli" -ForegroundColor Red
  Write-Host "Then run: gh auth login" -ForegroundColor Yellow
  exit 1
}

$SourceDir = (Resolve-Path $SourceDir).Path
$remotePath = "episodes/$Year/$Month/$EpisodeFolder"

Write-Host "Source:  $SourceDir" -ForegroundColor Cyan
Write-Host "Target:  $Repo/$remotePath" -ForegroundColor Cyan

$patterns = @(
  "Future_CFO_DP_Daily_*.pptx",
  "Future_CFO_DP_Daily_*.pdf",
  "Future_CFO_DP_Daily_*_Indian_English.mp3",
  "Future_CFO_DP_Daily_*_Synced.mp4",
  "Future_CFO_Daily_*.pptx",
  "Future_CFO_Daily_*.pdf",
  "Future_CFO_Daily_*_Indian_English.mp3",
  "Future_CFO_Daily_*_Synced.mp4"
)

$files = @()
foreach ($p in $patterns) {
  $files += Get-ChildItem -Path $SourceDir -Filter $p -File -ErrorAction SilentlyContinue
}
$files = $files | Sort-Object FullName -Unique

if ($files.Count -eq 0) {
  Write-Host "No episode media files found in $SourceDir" -ForegroundColor Red
  exit 1
}

Write-Host "Found $($files.Count) file(s) to upload:" -ForegroundColor Green
$files | ForEach-Object { Write-Host "  - $($_.Name)" }

# Clone sparse or use gh api to upload each file via Contents API
# Using a temp clone is most reliable for large binaries
$tmp = Join-Path $env:TEMP ("fcfo-publish-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tmp | Out-Null
try {
  Write-Host "Cloning repo (sparse)..." -ForegroundColor Yellow
  gh repo clone $Repo $tmp -- --depth 1 --branch $Branch
  $dest = Join-Path $tmp $remotePath
  New-Item -ItemType Directory -Path $dest -Force | Out-Null

  foreach ($f in $files) {
    Copy-Item $f.FullName -Destination (Join-Path $dest $f.Name) -Force
    Write-Host "Staged $($f.Name)" -ForegroundColor Green
  }

  Push-Location $tmp
  git config user.email "publisher@future-cfo-dp.local"
  git config user.name "Future CFO_DP Publisher"
  git add $remotePath
  $status = git status --porcelain
  if (-not $status) {
    Write-Host "Nothing new to commit (files may already be on GitHub)." -ForegroundColor Yellow
  } else {
    git commit -m "Publish media for $EpisodeFolder"
    git push origin $Branch
    Write-Host "PUSHED. GitHub Action will refresh the website index in 1-2 minutes." -ForegroundColor Green
    Write-Host "Site: https://viralgyandk-lang.github.io/future-cfo-2035/" -ForegroundColor Cyan
  }
  Pop-Location
}
finally {
  if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue }
}
