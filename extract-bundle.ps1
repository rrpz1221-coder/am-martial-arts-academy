$ErrorActionPreference = 'Stop'

$src = 'C:\Users\Rahil\Desktop\AM Martial Arts Academy - Standalone.html'
$outDir = 'C:\Users\Rahil\Desktop\am-martial-arts-academy'
$assetsDir = Join-Path $outDir 'assets'

if (-not (Test-Path $assetsDir)) { New-Item -ItemType Directory -Path $assetsDir | Out-Null }

$content = [System.IO.File]::ReadAllText($src)

$mfStart = '<script type="__bundler/manifest">'
$tmStart = '<script type="__bundler/template">'
$scriptEnd = '</script>'

$mfIdx = $content.IndexOf($mfStart)
if ($mfIdx -lt 0) { throw 'manifest script tag not found' }
$mfBodyStart = $mfIdx + $mfStart.Length
$mfBodyEnd = $content.IndexOf($scriptEnd, $mfBodyStart)
$mfJson = $content.Substring($mfBodyStart, $mfBodyEnd - $mfBodyStart).Trim()

$tmIdx = $content.IndexOf($tmStart)
if ($tmIdx -lt 0) { throw 'template script tag not found' }
$tmBodyStart = $tmIdx + $tmStart.Length
$tmBodyEnd = $content.IndexOf($scriptEnd, $tmBodyStart)
$tmJson = $content.Substring($tmBodyStart, $tmBodyEnd - $tmBodyStart).Trim()

$manifest = $mfJson | ConvertFrom-Json
$template = $tmJson | ConvertFrom-Json

$mimeToExt = @{
  'image/jpeg' = 'jpg'
  'image/jpg' = 'jpg'
  'image/png' = 'png'
  'image/gif' = 'gif'
  'image/webp' = 'webp'
  'image/svg+xml' = 'svg'
  'image/x-icon' = 'ico'
  'image/vnd.microsoft.icon' = 'ico'
  'font/woff2' = 'woff2'
  'font/woff' = 'woff'
  'font/ttf' = 'ttf'
  'font/otf' = 'otf'
  'application/font-woff2' = 'woff2'
  'application/font-woff' = 'woff'
  'application/x-font-woff2' = 'woff2'
  'application/vnd.ms-fontobject' = 'eot'
  'text/css' = 'css'
  'text/html' = 'html'
  'text/plain' = 'txt'
  'application/javascript' = 'js'
  'text/javascript' = 'js'
  'application/json' = 'json'
  'video/mp4' = 'mp4'
  'video/webm' = 'webm'
  'audio/mpeg' = 'mp3'
}

$rewriteMap = @{}
$counts = @{}

foreach ($prop in $manifest.PSObject.Properties) {
  $uuid = $prop.Name
  $entry = $prop.Value
  $mime = $entry.mime
  $ext = $mimeToExt[$mime]
  if (-not $ext) { $ext = 'bin' }

  if (-not $counts.ContainsKey($ext)) { $counts[$ext] = 0 }
  $counts[$ext]++

  $relPath = "assets/$uuid.$ext"
  $absPath = Join-Path $outDir $relPath

  $bytes = [System.Convert]::FromBase64String($entry.data)

  if ($entry.compressed -eq $true) {
    $ms = New-Object System.IO.MemoryStream(,$bytes)
    $gz = New-Object System.IO.Compression.GZipStream($ms, [System.IO.Compression.CompressionMode]::Decompress)
    $out = New-Object System.IO.MemoryStream
    $gz.CopyTo($out)
    $gz.Dispose()
    $ms.Dispose()
    $bytes = $out.ToArray()
    $out.Dispose()
  }

  [System.IO.File]::WriteAllBytes($absPath, $bytes)
  $rewriteMap[$uuid] = $relPath
}

$html = $template
foreach ($uuid in $rewriteMap.Keys) {
  $html = $html.Replace($uuid, $rewriteMap[$uuid])
}

$indexPath = Join-Path $outDir 'index.html'
[System.IO.File]::WriteAllText($indexPath, $html, (New-Object System.Text.UTF8Encoding($false)))

Write-Host "Extracted $($rewriteMap.Count) assets:"
foreach ($k in ($counts.Keys | Sort-Object)) {
  Write-Host ("  {0,-6} {1}" -f $k, $counts[$k])
}
Write-Host ""
Write-Host "Wrote: $indexPath"
$indexSize = (Get-Item $indexPath).Length
Write-Host ("index.html size: {0:N0} bytes" -f $indexSize)
