# Called by "Play Outpost.bat" (runs hidden, no console window).
#   run-game.ps1 <width> <height>   -> lower the screen resolution, run Outpost, restore when it closes
#   run-game.ps1 restore            -> just put the screen back to its normal resolution
#
# The resolution change is session-only (nothing is written to the registry), so
# "restore" simply tells Windows to go back to the saved/normal mode. It needs no
# remembered value and is safe to run at any time.
$ErrorActionPreference = 'Continue'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $here

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class Res {
  [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Ansi)]
  public struct DEVMODE {
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dmDeviceName;
    public short dmSpecVersion, dmDriverVersion, dmSize, dmDriverExtra;
    public int dmFields, dmPositionX, dmPositionY, dmDisplayOrientation, dmDisplayFixedOutput;
    public short dmColor, dmDuplex, dmYResolution, dmTTOption, dmCollate;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dmFormName;
    public short dmLogPixels;
    public int dmBitsPerPel, dmPelsWidth, dmPelsHeight, dmDisplayFlags, dmDisplayFrequency;
    public int dmICMMethod, dmICMIntent, dmMediaType, dmDitherType, dmReserved1, dmReserved2, dmPanningWidth, dmPanningHeight;
  }
  [DllImport("user32.dll")] public static extern bool EnumDisplaySettings(string dev, int mode, ref DEVMODE dm);
  [DllImport("user32.dll")] public static extern int ChangeDisplaySettings(ref DEVMODE dm, int flags);
  [DllImport("user32.dll", EntryPoint = "ChangeDisplaySettings")] public static extern int ChangeDisplaySettingsNull(IntPtr dm, int flags);
  public const int ENUM_CURRENT_SETTINGS = -1;
  public const int DM_PELSWIDTH = 0x80000, DM_PELSHEIGHT = 0x100000;

  public static int[] Current() {
    DEVMODE dm = new DEVMODE(); dm.dmSize = (short)Marshal.SizeOf(dm);
    EnumDisplaySettings(null, ENUM_CURRENT_SETTINGS, ref dm);
    return new int[] { dm.dmPelsWidth, dm.dmPelsHeight };
  }
  public static int Set(int w, int h, int flags) {
    DEVMODE dm = new DEVMODE(); dm.dmSize = (short)Marshal.SizeOf(dm);
    EnumDisplaySettings(null, ENUM_CURRENT_SETTINGS, ref dm);
    dm.dmPelsWidth = w; dm.dmPelsHeight = h; dm.dmFields = DM_PELSWIDTH | DM_PELSHEIGHT;
    return ChangeDisplaySettings(ref dm, flags);  // flags 0 = this session only; 1 = also save as the normal mode
  }
  // A null DEVMODE means: go back to the mode stored in the registry (the normal one).
  public static int Restore() { return ChangeDisplaySettingsNull(IntPtr.Zero, 0); }
  // Largest resolution the monitor offers (its native size, in practice).
  public static int[] Largest() {
    DEVMODE dm = new DEVMODE(); dm.dmSize = (short)Marshal.SizeOf(dm);
    int bw = 0, bh = 0;
    for (int i = 0; EnumDisplaySettings(null, i, ref dm); i++) {
      if (dm.dmBitsPerPel < 32) continue;
      if ((long)dm.dmPelsWidth * dm.dmPelsHeight > (long)bw * bh) { bw = dm.dmPelsWidth; bh = dm.dmPelsHeight; }
    }
    return new int[] { bw, bh };
  }
}
'@

$saved = Join-Path $here 'otvdm\saved-resolution.txt'

function Restore-Screen([bool]$useLargest = $true) {
    # 1) Ask Windows for the normal (registry) mode.
    [Res]::Restore() | Out-Null
    Start-Sleep -Milliseconds 500
    # 2) Belt and braces: if we remembered the resolution we started from, set it
    #    explicitly and make it the saved mode, in case Windows kept the low one.
    #    Without a remembered value, use the monitor's largest (native) resolution.
    $target = $null
    if (Test-Path -LiteralPath $saved) {
        $p = (Get-Content -LiteralPath $saved -Raw).Trim() -split 'x'
        if ($p.Count -eq 2) { $target = @([int]$p[0], [int]$p[1]) }
        Remove-Item -LiteralPath $saved -Force -ErrorAction SilentlyContinue
    }
    if (-not $target -and $useLargest) { $target = [Res]::Largest() }
    if (-not $target) { return }
    $cur = [Res]::Current()
    if ($target[0] -gt 0 -and ($cur[0] -ne $target[0] -or $cur[1] -ne $target[1])) {
        [Res]::Set($target[0], $target[1], 1) | Out-Null
    }
}

if ($args.Count -ge 1 -and $args[0] -eq 'restore') { Restore-Screen; exit 0 }

$w = 0; $h = 0
if ($args.Count -ge 2) { $w = [int]$args[0]; $h = [int]$args[1] }

try {
    if ($w -gt 0 -and $h -gt 0) {
        if (Test-Path -LiteralPath $saved) { Restore-Screen $false }   # a previous run didn't finish; undo it first
        $cur = [Res]::Current()
        if (-not (Test-Path -LiteralPath $saved)) {
            New-Item -ItemType Directory -Path (Split-Path $saved) -Force | Out-Null
            "$($cur[0])x$($cur[1])" | Set-Content -LiteralPath $saved -Encoding ASCII
        }
        [Res]::Set($w, $h, 0) | Out-Null
    }

    $otvdm = Join-Path $here 'otvdm\otvdm.exe'
    $game  = Join-Path $here 'OUTPOST.EXE'
    $p = Start-Process -FilePath $otvdm -ArgumentList ('"' + $game + '"') -WorkingDirectory $here -PassThru
    $p.WaitForExit()
    # otvdm hands the game to a second copy of itself; wait until every copy is gone.
    Start-Sleep -Seconds 2
    while (Get-Process -Name 'otvdm*' -ErrorAction SilentlyContinue) { Start-Sleep -Seconds 1 }
}
finally {
    if ($w -gt 0 -and $h -gt 0) { Restore-Screen $false }
}
exit 0
