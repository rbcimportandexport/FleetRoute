param(
  [Parameter(Mandatory = $true)][string]$RamaZip,
  [Parameter(Mandatory = $true)][string]$RbcZip,
  [Parameter(Mandatory = $true)][string]$OutputRoot
)

Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = 'Stop'
$catalog = [System.Collections.Generic.List[object]]::new()
$seenHashes = @{}

function Get-SafeName([string]$value) {
  $safe = $value.ToLowerInvariant() -replace '[^a-z0-9]+', '-'
  return $safe.Trim('-')
}

function Import-Brand([string]$zipPath, [string]$brand) {
  $archive = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
  try {
    foreach ($entry in $archive.Entries) {
      $extension = [System.IO.Path]::GetExtension($entry.Name).ToLowerInvariant()
      if ($extension -notin @('.jpg', '.jpeg', '.png')) { continue }
      if ($entry.Length -le 0) { continue }

      $parts = $entry.FullName -split '/'
      if ($parts.Count -lt 2) { continue }
      $category = if ($brand -eq 'RAMA' -and $parts.Count -gt 3 -and $parts[1] -eq 'CATEGORY WISE') { $parts[2] } else { $parts[1] }
      $productName = [System.IO.Path]::GetFileNameWithoutExtension($entry.Name).Trim()
      $code = ($productName -replace "^$brand\s*-?\s*", '').Trim()

      $source = $entry.Open()
      $memory = [System.IO.MemoryStream]::new()
      try {
        $source.CopyTo($memory)
        $bytes = $memory.ToArray()
      } finally {
        $source.Dispose()
        $memory.Dispose()
      }

      $sha = [System.Security.Cryptography.SHA256]::Create()
      try { $hash = ([BitConverter]::ToString($sha.ComputeHash($bytes)) -replace '-', '').ToLowerInvariant() }
      finally { $sha.Dispose() }
      if ($seenHashes.ContainsKey($hash)) { continue }
      $seenHashes[$hash] = $true

      $brandDir = Join-Path $OutputRoot $brand.ToLowerInvariant()
      $categoryDir = Join-Path $brandDir (Get-SafeName $category)
      [System.IO.Directory]::CreateDirectory($categoryDir) | Out-Null
      $fileName = "$(Get-SafeName $code)-$($hash.Substring(0,8)).jpg"
      $target = Join-Path $categoryDir $fileName

      $inputStream = [System.IO.MemoryStream]::new([byte[]]$bytes)
      $sourceImage = $null
      $bitmap = $null
      $graphics = $null
      try {
        $sourceImage = [System.Drawing.Image]::FromStream($inputStream)
        $scale = [Math]::Min(1.0, 640.0 / [Math]::Max($sourceImage.Width, $sourceImage.Height))
        $width = [Math]::Max(1, [int]($sourceImage.Width * $scale))
        $height = [Math]::Max(1, [int]($sourceImage.Height * $scale))
        $bitmap = [System.Drawing.Bitmap]::new($width, $height)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $graphics.DrawImage($sourceImage, 0, 0, $width, $height)
        $codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object MimeType -eq 'image/jpeg'
        $encoder = [System.Drawing.Imaging.Encoder]::Quality
        $parameters = [System.Drawing.Imaging.EncoderParameters]::new(1)
        $parameters.Param[0] = [System.Drawing.Imaging.EncoderParameter]::new($encoder, 72L)
        $bitmap.Save($target, $codec, $parameters)
        $parameters.Dispose()
      } catch {
        Write-Warning "Skipped unreadable image: $($entry.FullName)"
        continue
      } finally {
        if ($graphics) { $graphics.Dispose() }
        if ($bitmap) { $bitmap.Dispose() }
        if ($sourceImage) { $sourceImage.Dispose() }
        $inputStream.Dispose()
      }

      $relative = $target.Substring((Split-Path $OutputRoot -Parent).Length + 1).Replace('\', '/')
      $catalog.Add([pscustomobject]@{
        id = "$($brand.ToLowerInvariant())-$(Get-SafeName $category)-$(Get-SafeName $code)-$($hash.Substring(0,8))"
        brand = $brand
        category = $category.Trim()
        code = $code
        name = $productName
        photoAsset = "assets/product_catalog/$($relative.Substring($relative.IndexOf('/') + 1))"
        originalPath = $entry.FullName
      })
    }
  } finally {
    $archive.Dispose()
  }
}

[System.IO.Directory]::CreateDirectory($OutputRoot) | Out-Null
Import-Brand -zipPath $RamaZip -brand 'RAMA'
Import-Brand -zipPath $RbcZip -brand 'RBC'
$catalog | Sort-Object brand, category, code | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $OutputRoot 'catalog.json') -Encoding utf8
Write-Output "Imported $($catalog.Count) unique product photos."
