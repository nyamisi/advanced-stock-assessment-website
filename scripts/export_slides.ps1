# Export every lecture deck as (1) a full multi-page PDF and (2) a ZIP bundle.
# Run AFTER `quarto render`:   powershell -ExecutionPolicy Bypass -File scripts/export_slides.ps1
# Outputs go to downloads/ (copied into docs/ on the next `quarto render`, and also copied now).

$root   = Split-Path $PSScriptRoot -Parent
$site   = Join-Path $root 'docs\lectures'
$out    = Join-Path $root 'downloads'
$chrome = @('C:\Program Files\Google\Chrome\Application\chrome.exe',
            'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe') |
          Where-Object { Test-Path $_ } | Select-Object -First 1

# Rendered deck  ->  friendly download name (add new lectures here)
$decks = [ordered]@{
  '1_intro.html'         = 'AF603_L1_Course_Introduction'
  '2_popl_dynamics.html' = 'AF603_L2_Fish_Population_Dynamics'
  '3_data_used.html'     = 'AF603_L3_Data_Used_in_Stock_Assessment'
}

New-Item -ItemType Directory -Force -Path $out | Out-Null
$profileDir = Join-Path $env:TEMP 'af603_chrome_profile'

foreach ($deck in $decks.Keys) {
  $html = Join-Path $site $deck
  if (-not (Test-Path $html)) { Write-Warning "Missing $html - run quarto render first"; continue }
  $name = $decks[$deck]
  $pdf  = Join-Path $out "$name.pdf"

  # ?print-pdf makes reveal.js lay out ALL slides, one per page
  # (do not add --virtual-time-budget / --timeout: they make headless Chrome print a blank PDF)
  $url = 'file:///' + ($html -replace '\\', '/') + '?print-pdf'
  $tmp = Join-Path $env:TEMP "$name.pdf"

  # Headless Chrome occasionally prints before the deck has loaded (blank ~1.5 KB PDF): retry
  for ($try = 1; $try -le 4; $try++) {
    if (Test-Path $tmp) { Remove-Item $tmp -Force }
    Start-Process -FilePath $chrome -Wait -NoNewWindow -ArgumentList @(
      '--headless=new', '--disable-gpu', '--no-pdf-header-footer',
      "--user-data-dir=$profileDir-$try",
      "--print-to-pdf=$tmp", $url)
    if ((Test-Path $tmp) -and (Get-Item $tmp).Length -gt 20KB) { break }
    Write-Warning "$name : blank PDF on attempt $try, retrying..."
    Start-Sleep -Seconds 2
  }

  try   { Copy-Item $tmp $pdf -Force -ErrorAction Stop }
  catch { Write-Warning "Could not overwrite $pdf (close it in any PDF viewer and re-run)" }

  Copy-Item $html (Join-Path $out "$name.html") -Force
  Write-Host "Exported $name (.pdf + .html)"
}

# One ZIP with every lecture (PDF + offline HTML)
$zip = Join-Path $out 'AF603_All_Lecture_Slides.zip'
if (Test-Path $zip) { Remove-Item $zip }
Compress-Archive -Path (Join-Path $out 'AF603_L*') -DestinationPath $zip
Write-Host "Created $zip"

# Make the files available on the already-rendered site immediately
$siteDownloads = Join-Path $root 'docs\downloads'
New-Item -ItemType Directory -Force -Path $siteDownloads | Out-Null
Get-ChildItem $out | ForEach-Object {
  try   { Copy-Item $_.FullName $siteDownloads -Force -ErrorAction Stop }
  catch { Write-Warning "Could not copy $($_.Name) to docs/downloads (file open elsewhere?)" }
}
