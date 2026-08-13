Add-Type -AssemblyName System.Drawing

$srcPath = "C:\Users\USER\bosses-party-planner\Bosses.png"
$src = [System.Drawing.Bitmap]::FromFile($srcPath)

# Grilla de 5 columnas x 2 filas sobre el lienzo de 1536x1024
$colX = @(0, 307, 614, 921, 1229, 1536)
$rowY = @(0, 512, 1024)

$cells = @{
  "adversary" = @{ col = 0; row = 0 }
  "kaling"    = @{ col = 1; row = 0 }
  "malefic"   = @{ col = 2; row = 0 }
  "limbo"     = @{ col = 3; row = 0 }
  "baldrix"   = @{ col = 4; row = 0 }
  "seren"     = @{ col = 0; row = 1 }
  "kalos"     = @{ col = 1; row = 1 }
}

function Get-BgRemoved {
  param($bmp, [int]$tolerance)

  $w = [int]$bmp.Width
  $h = [int]$bmp.Height
  $rect = New-Object System.Drawing.Rectangle(0, 0, $w, $h)
  $bd = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadWrite, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $bytes = New-Object byte[] ($bd.Stride * $h)
  [System.Runtime.InteropServices.Marshal]::Copy($bd.Scan0, $bytes, 0, $bytes.Length)
  $stride = [int]$bd.Stride

  $total = $w * $h
  $visited = New-Object bool[] $total
  $isBg = New-Object bool[] $total
  $queue = New-Object System.Collections.Generic.Queue[int]

  for ($x = 0; $x -lt $w; $x++) {
    $i = $x
    if (-not $visited[$i]) { $visited[$i] = $true; $isBg[$i] = $true; [void]$queue.Enqueue($i) }
    $i2 = (($h - 1) * $w) + $x
    if (-not $visited[$i2]) { $visited[$i2] = $true; $isBg[$i2] = $true; [void]$queue.Enqueue($i2) }
  }
  for ($y = 0; $y -lt $h; $y++) {
    $i = $y * $w
    if (-not $visited[$i]) { $visited[$i] = $true; $isBg[$i] = $true; [void]$queue.Enqueue($i) }
    $i2 = ($y * $w) + ($w - 1)
    if (-not $visited[$i2]) { $visited[$i2] = $true; $isBg[$i2] = $true; [void]$queue.Enqueue($i2) }
  }

  while ($queue.Count -gt 0) {
    $i = $queue.Dequeue()
    $cx = $i % $w
    $cy = ($i - $cx) / $w
    $off = $cy * $stride + $cx * 4
    $cb = [int]$bytes[$off]; $cg = [int]$bytes[$off+1]; $cr = [int]$bytes[$off+2]

    if ($cx -gt 0) {
      $ni = $i - 1
      if (-not $visited[$ni]) {
        $noff = $off - 4
        $nb = [int]$bytes[$noff]; $ng = [int]$bytes[$noff+1]; $nr = [int]$bytes[$noff+2]
        $dist = [Math]::Abs($nb-$cb) + [Math]::Abs($ng-$cg) + [Math]::Abs($nr-$cr)
        $visited[$ni] = $true
        if ($dist -le $tolerance) { $isBg[$ni] = $true; [void]$queue.Enqueue($ni) }
      }
    }
    if ($cx -lt ($w - 1)) {
      $ni = $i + 1
      if (-not $visited[$ni]) {
        $noff = $off + 4
        $nb = [int]$bytes[$noff]; $ng = [int]$bytes[$noff+1]; $nr = [int]$bytes[$noff+2]
        $dist = [Math]::Abs($nb-$cb) + [Math]::Abs($ng-$cg) + [Math]::Abs($nr-$cr)
        $visited[$ni] = $true
        if ($dist -le $tolerance) { $isBg[$ni] = $true; [void]$queue.Enqueue($ni) }
      }
    }
    if ($cy -gt 0) {
      $ni = $i - $w
      if (-not $visited[$ni]) {
        $noff = $off - $stride
        $nb = [int]$bytes[$noff]; $ng = [int]$bytes[$noff+1]; $nr = [int]$bytes[$noff+2]
        $dist = [Math]::Abs($nb-$cb) + [Math]::Abs($ng-$cg) + [Math]::Abs($nr-$cr)
        $visited[$ni] = $true
        if ($dist -le $tolerance) { $isBg[$ni] = $true; [void]$queue.Enqueue($ni) }
      }
    }
    if ($cy -lt ($h - 1)) {
      $ni = $i + $w
      if (-not $visited[$ni]) {
        $noff = $off + $stride
        $nb = [int]$bytes[$noff]; $ng = [int]$bytes[$noff+1]; $nr = [int]$bytes[$noff+2]
        $dist = [Math]::Abs($nb-$cb) + [Math]::Abs($ng-$cg) + [Math]::Abs($nr-$cr)
        $visited[$ni] = $true
        if ($dist -le $tolerance) { $isBg[$ni] = $true; [void]$queue.Enqueue($ni) }
      }
    }
  }

  # Quedarnos solo con la componente conexa MAS GRANDE del primer plano,
  # para descartar manchas/artefactos sueltos que el flood fill no alcanzó
  # a limpiar (inflan el recorte final con ruido desconectado del ícono).
  $compId = New-Object int[] $total
  $bestId = 0
  $bestSize = -1
  $nextId = 1
  $q2 = New-Object System.Collections.Generic.Queue[int]
  for ($i = 0; $i -lt $total; $i++) {
    if ($isBg[$i] -or $compId[$i] -ne 0) { continue }
    $q2.Clear()
    $q2.Enqueue($i)
    $compId[$i] = $nextId
    $count = 0
    while ($q2.Count -gt 0) {
      $j = $q2.Dequeue()
      $count++
      $jx = $j % $w
      $jy = ($j - $jx) / $w
      if ($jx -gt 0) { $nj = $j - 1; if (-not $isBg[$nj] -and $compId[$nj] -eq 0) { $compId[$nj] = $nextId; [void]$q2.Enqueue($nj) } }
      if ($jx -lt ($w - 1)) { $nj = $j + 1; if (-not $isBg[$nj] -and $compId[$nj] -eq 0) { $compId[$nj] = $nextId; [void]$q2.Enqueue($nj) } }
      if ($jy -gt 0) { $nj = $j - $w; if (-not $isBg[$nj] -and $compId[$nj] -eq 0) { $compId[$nj] = $nextId; [void]$q2.Enqueue($nj) } }
      if ($jy -lt ($h - 1)) { $nj = $j + $w; if (-not $isBg[$nj] -and $compId[$nj] -eq 0) { $compId[$nj] = $nextId; [void]$q2.Enqueue($nj) } }
    }
    if ($count -gt $bestSize) { $bestSize = $count; $bestId = $nextId }
    $nextId++
  }
  if ($bestId -ne 0) {
    for ($i = 0; $i -lt $total; $i++) {
      if (-not $isBg[$i] -and $compId[$i] -ne $bestId) { $isBg[$i] = $true }
    }
  }

  $minX = $w; $minY = $h; $maxX = -1; $maxY = -1
  for ($y = 0; $y -lt $h; $y++) {
    $rowBase = $y * $w
    $rowOff = $y * $stride
    for ($x = 0; $x -lt $w; $x++) {
      $i = $rowBase + $x
      $off = $rowOff + $x * 4
      if ($isBg[$i]) {
        $bytes[$off+3] = 0
      } else {
        if ($x -lt $minX) { $minX = $x }
        if ($x -gt $maxX) { $maxX = $x }
        if ($y -lt $minY) { $minY = $y }
        if ($y -gt $maxY) { $maxY = $y }
      }
    }
  }

  [System.Runtime.InteropServices.Marshal]::Copy($bytes, 0, $bd.Scan0, $bytes.Length)
  $bmp.UnlockBits($bd)

  if ($maxX -lt 0) { return $null }

  $pad = 4
  $minX = [Math]::Max(0, $minX - $pad)
  $minY = [Math]::Max(0, $minY - $pad)
  $maxX = [Math]::Min($w - 1, $maxX + $pad)
  $maxY = [Math]::Min($h - 1, $maxY + $pad)
  $cropRect = New-Object System.Drawing.Rectangle($minX, $minY, ($maxX - $minX + 1), ($maxY - $minY + 1))
  return $bmp.Clone($cropRect, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
}

foreach ($name in $cells.Keys) {
  $c = $cells[$name]
  $x0 = $colX[$c.col]; $x1 = $colX[$c.col + 1]
  $y0 = $rowY[$c.row]; $y1 = $rowY[$c.row + 1]
  $r = New-Object System.Drawing.Rectangle($x0, $y0, ($x1 - $x0), ($y1 - $y0))
  $cellBmp = $src.Clone($r, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $result = Get-BgRemoved $cellBmp 30
  $outPath = "C:\Users\USER\bosses-party-planner\icon-$name.png"
  $result.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
  Write-Output "$name -> $outPath ($($result.Width)x$($result.Height))"
  $result.Dispose()
  $cellBmp.Dispose()
}

$src.Dispose()
