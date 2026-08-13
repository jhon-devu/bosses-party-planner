Add-Type -AssemblyName System.Drawing

$srcPath = "C:\Users\USER\bosses-party-planner\Dificultades.png"
$src = [System.Drawing.Bitmap]::FromFile($srcPath)

# Cuadrantes aproximados en la grilla 2x2 de 1536x1024
$quads = @{
  "hard"    = New-Object System.Drawing.Rectangle(0,   0,   768, 512)
  "extreme" = New-Object System.Drawing.Rectangle(768, 0,   768, 512)
  "chaos"   = New-Object System.Drawing.Rectangle(0,   512, 768, 512)
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

  # sembrar desde todo el borde del recorte
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

    # vecino izquierda
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
    # vecino derecha
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
    # vecino arriba
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
    # vecino abajo
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

  $pad = 6
  $minX = [Math]::Max(0, $minX - $pad)
  $minY = [Math]::Max(0, $minY - $pad)
  $maxX = [Math]::Min($w - 1, $maxX + $pad)
  $maxY = [Math]::Min($h - 1, $maxY + $pad)
  $cropRect = New-Object System.Drawing.Rectangle($minX, $minY, ($maxX - $minX + 1), ($maxY - $minY + 1))
  return $bmp.Clone($cropRect, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
}

foreach ($name in $quads.Keys) {
  $r = $quads[$name]
  $quadBmp = $src.Clone($r, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $tol = if ($name -eq "extreme") { 12 } else { 30 }
  $result = Get-BgRemoved $quadBmp $tol
  $outPath = "C:\Users\USER\bosses-party-planner\badge-$name.png"
  $result.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
  Write-Output "$name -> $outPath ($($result.Width)x$($result.Height))"
  $result.Dispose()
  $quadBmp.Dispose()
}

$src.Dispose()
