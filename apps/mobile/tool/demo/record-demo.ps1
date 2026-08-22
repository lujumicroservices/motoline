<#
.SYNOPSIS
  Record RiderLab section demos from a running Android emulator or phone.

.DESCRIPTION
  For each clip: start adb screenrecord, run the Maestro flow (taps by demo.* ids),
  then pull the MP4 into tool/demo/out.

  Prerequisites:
    - Device/emulator with RiderLab installed and signed in (real rides/rodadas).
    - adb on PATH
    - Maestro on PATH for automated navigation:
        https://docs.maestro.dev  (Windows: scoop install maestro, or the install script)

.EXAMPLE
  .\record-demo.ps1 -List
  .\record-demo.ps1 -Clip 01-home
  .\record-demo.ps1 -All
  .\record-demo.ps1 -Clip 02-ride-summary -SkipMaestro
#>
[CmdletBinding()]
param(
  [string] $Clip,
  [switch] $All,
  [switch] $List,
  [switch] $SkipMaestro,
  [int] $Seconds,
  [string] $Adb = "adb",
  [string] $Package = "com.rawthrottle.riderlab"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$here = $PSScriptRoot
$catalogPath = Join-Path $here "clips.json"
$maestroDir = Join-Path $here "maestro"
$outDir = Join-Path $here "out"
$catalog = Get-Content -Raw -Path $catalogPath | ConvertFrom-Json

function Get-Clips {
  if ($Clip) {
    $match = @($catalog.clips | Where-Object { $_.id -eq $Clip })
    if ($match.Count -eq 0) {
      throw "Unknown clip '$Clip'. Use -List."
    }
    return $match
  }
  return @($catalog.clips)
}

if ($List) {
  $catalog.clips | ForEach-Object {
    "{0,-18} {1,-28} {2,3}s  needs:{3}" -f $_.id, $_.title, $_.seconds, (($_.needs -join ",") )
  }
  return
}

if (-not $Clip -and -not $All) {
  Write-Host "Pass -List, -Clip <id>, or -All"
  $catalog.clips | ForEach-Object { Write-Host ("  " + $_.id + "  " + $_.title) }
  return
}

$adbOk = & $Adb devices 2>$null | Select-String "device$"
if (-not $adbOk) {
  throw "No Android device/emulator (adb devices). Start one, then flutter run --flavor sideload."
}

$maestro = Get-Command maestro -ErrorAction SilentlyContinue
if (-not $SkipMaestro -and -not $maestro) {
  Write-Warning "Maestro not on PATH — recording the current screen only. Install: https://docs.maestro.dev"
  $SkipMaestro = $true
}

New-Item -ItemType Directory -Force -Path $outDir | Out-Null

function Record-One($item) {
  $sec = if ($Seconds -gt 0) { $Seconds } else { [int]$item.seconds }
  if ($sec -lt 3) { $sec = 8 }
  if ($sec -gt 180) { $sec = 180 }

  $remote = "/sdcard/riderlab-$($item.id).mp4"
  $local = Join-Path $outDir "$($item.id).mp4"
  Write-Host ""
  Write-Host "== $($item.id)  $($item.title)  ${sec}s =="

  & $Adb shell "am force-stop $Package" 2>$null | Out-Null
  Start-Sleep -Milliseconds 400

  $null = & $Adb shell "rm -f $remote" 2>$null
  $rec = Start-Process -FilePath $Adb -ArgumentList @(
    "shell", "screenrecord", "--time-limit", "$sec", "--bit-rate", "8000000", $remote
  ) -WindowStyle Hidden -PassThru

  Start-Sleep -Milliseconds 600

  if (-not $SkipMaestro -and $item.flow) {
    $flow = Join-Path $maestroDir $item.flow
    if (-not (Test-Path $flow)) {
      throw "Missing Maestro flow $flow"
    }
    Write-Host "Maestro $($item.flow)"
    & maestro test $flow
    if ($LASTEXITCODE -ne 0) {
      Write-Warning "Maestro failed for $($item.id) (exit $LASTEXITCODE). Still pulling video if any."
    }
  } else {
    & $Adb shell "monkey -p $Package -c android.intent.category.LAUNCHER 1" | Out-Null
    Start-Sleep -Seconds ([Math]::Min($sec - 1, 8))
  }

  if (-not $rec.HasExited) {
    $wait = $sec + 8
    try {
      Wait-Process -Id $rec.Id -Timeout $wait
    } catch {
      Stop-Process -Id $rec.Id -Force -ErrorAction SilentlyContinue
    }
  }

  Start-Sleep -Milliseconds 500
  & $Adb pull $remote $local
  if (Test-Path $local) {
    $size = (Get-Item $local).Length
    Write-Host "Saved $local ($([Math]::Round($size/1MB, 2)) MB)"
  } else {
    Write-Warning "No video pulled for $($item.id). Emulator must support screenrecord."
  }
}

foreach ($item in Get-Clips) {
  Record-One $item
}

Write-Host ""
Write-Host "Clips in $outDir"
