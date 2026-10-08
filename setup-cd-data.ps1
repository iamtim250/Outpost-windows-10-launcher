# Called by "Play Outpost.bat" on first run.
# Finds the Outpost CD image (Outpost.bin from a BIN/CUE rip, or an .iso), converts
# it to a plain .iso if needed, mounts it, copies the BITMAPS / VIDEOS / MUSIC
# folders and the manual here, and unpacks the game itself (OUTPOST.EXE and its
# DLLs) from the CD's installer archive RESOURCE.000.
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $here

# ---------------------------------------------------------------------------
# PKWARE DCL "implode" decompressor (the format inside Sierra's RESOURCE.000),
# ported from zlib's contrib/blast.c.
# ---------------------------------------------------------------------------
Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Collections.Generic;
public class Blast {
  const int MAXBITS = 13;
  byte[] d; int pos; int bitbuf; int bitcnt;
  static readonly byte[] LITLEN = {11,124,8,7,28,7,188,13,76,4,10,8,12,10,12,10,8,23,8,9,7,6,7,8,7,6,55,8,23,24,12,11,7,9,11,12,6,7,22,5,7,24,6,11,9,6,7,22,7,11,38,7,9,8,25,11,8,11,9,12,8,12,5,38,5,38,5,11,7,5,6,21,6,10,53,8,7,24,10,27,44,253,253,253,252,252,252,13,12,45,12,45,12,61,12,45,44,173};
  static readonly byte[] LENLEN = {2,35,36,53,38,23};
  static readonly byte[] DISTLEN = {2,20,53,230,247,151,248};
  static readonly int[] BASE = {3,2,4,5,6,7,8,9,10,12,16,24,40,72,136,264};
  static readonly int[] EXTRA = {0,0,0,0,0,0,0,0,1,2,3,4,5,6,7,8};
  class Huff { public int[] count; public int[] symbol; }
  static Huff Build(byte[] compact) {
    List<int> length = new List<int>();
    foreach (byte b in compact) for (int r = 0; r < (b >> 4) + 1; r++) length.Add(b & 15);
    Huff h = new Huff(); h.count = new int[MAXBITS + 1];
    foreach (int l in length) h.count[l]++;
    int[] offs = new int[MAXBITS + 1];
    for (int l = 1; l < MAXBITS; l++) offs[l + 1] = offs[l] + h.count[l];
    h.symbol = new int[length.Count];
    for (int s = 0; s < length.Count; s++) if (length[s] != 0) h.symbol[offs[length[s]]++] = s;
    return h;
  }
  static readonly Huff LIT = Build(LITLEN), LEN = Build(LENLEN), DIST = Build(DISTLEN);
  int Bits(int need) {
    int val = bitbuf;
    while (bitcnt < need) { val |= d[pos++] << bitcnt; bitcnt += 8; }
    bitbuf = val >> need; bitcnt -= need;
    return val & ((1 << need) - 1);
  }
  int Decode(Huff h) {
    int code = 0, first = 0, index = 0;
    for (int len = 1; len <= MAXBITS; len++) {
      code |= Bits(1) ^ 1;
      int c = h.count[len];
      if (code < first + c) return h.symbol[index + (code - first)];
      index += c; first += c; first <<= 1; code <<= 1;
    }
    throw new Exception("bad huffman code");
  }
  public static byte[] Explode(byte[] data) {
    Blast b = new Blast(); b.d = data;
    int lit = data[0], dict = data[1]; b.pos = 2;
    if (lit > 1 || dict < 4 || dict > 6) throw new Exception("not a DCL implode stream");
    List<byte> outp = new List<byte>();
    while (true) {
      if (b.Bits(1) != 0) {
        int sym = b.Decode(LEN);
        int length = BASE[sym] + b.Bits(EXTRA[sym]);
        if (length == 519) break;
        sym = b.Decode(DIST);
        int dist = (length == 2) ? ((sym << 2) | b.Bits(2)) : ((sym << dict) | b.Bits(dict));
        dist += 1;
        if (dist > outp.Count) throw new Exception("bad distance");
        for (int i = 0; i < length; i++) outp.Add(outp[outp.Count - dist]);
      } else {
        outp.Add((byte)(lit == 0 ? b.Bits(8) : b.Decode(LIT)));
      }
    }
    return outp.ToArray();
  }
  // Sierra Windows-installer archive: "DISK01", then 26-byte entries
  // ("DH91" + 13-byte name + flag + 4-byte compressed size + 4 bytes), then the data in order.
  public static string[] ExtractSierraArchive(string archive, string outDir) {
    byte[] d = File.ReadAllBytes(archive);
    List<string> names = new List<string>(); List<int> sizes = new List<int>();
    int off = 6;
    while (off + 26 <= d.Length && d[off] == 'D' && d[off+1] == 'H') {
      int n = 0; while (n < 13 && d[off + 4 + n] != 0) n++;
      string name = System.Text.Encoding.ASCII.GetString(d, off + 4, n);
      int size = BitConverter.ToInt32(d, off + 18);
      off += 26;
      if (name == "THE_END") break;
      names.Add(name); sizes.Add(size);
    }
    int pos = off;
    List<string> written = new List<string>();
    for (int i = 0; i < names.Count; i++) {
      byte[] chunk = new byte[sizes[i]]; Array.Copy(d, pos, chunk, 0, sizes[i]); pos += sizes[i];
      byte[] plain = Explode(chunk);
      File.WriteAllBytes(Path.Combine(outDir, names[i]), plain);
      written.Add(names[i] + " (" + plain.Length + " bytes)");
    }
    return written.ToArray();
  }
}
'@

function Find-Image {
    $names = @('Outpost.bin', 'Outpost.iso', 'OUTPOST.BIN', 'OUTPOST.ISO')
    $roots = @($here, (Join-Path $env:USERPROFILE 'Downloads'), (Join-Path $env:USERPROFILE 'Desktop'))
    foreach ($r in $roots) {
        if (-not (Test-Path -LiteralPath $r)) { continue }
        foreach ($n in $names) {
            $hit = Get-ChildItem -LiteralPath $r -Recurse -Depth 2 -Filter $n -File -ErrorAction SilentlyContinue |
                   Where-Object { $_.Length -gt 100MB } | Select-Object -First 1
            if ($hit) { return $hit.FullName }
        }
        # Still zipped?  Unpack a zip whose name contains "Outpost" and look inside.
        $zip = Get-ChildItem -LiteralPath $r -Depth 1 -Filter '*Outpost*.zip' -File -ErrorAction SilentlyContinue |
               Where-Object { $_.Length -gt 100MB } | Select-Object -First 1
        if ($zip) {
            Write-Host "  Unzipping $($zip.Name) ..."
            $dest = Join-Path $here 'cd_tmp'
            Expand-Archive -LiteralPath $zip.FullName -DestinationPath $dest -Force
            $hit = Get-ChildItem -LiteralPath $dest -Recurse -Include '*.bin','*.iso' -File | Sort-Object Length -Descending | Select-Object -First 1
            if ($hit) { return $hit.FullName }
        }
    }
    # Real CD in a drive?
    foreach ($v in Get-Volume -ErrorAction SilentlyContinue | Where-Object { $_.DriveType -eq 'CD-ROM' -and $_.DriveLetter }) {
        if (Test-Path -LiteralPath "$($v.DriveLetter):\RESOURCE.000") { return "$($v.DriveLetter):\" }
    }
    # Ask.
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show(
        "Outpost needs its files from the original CD.`n`nOn the next screen, please pick your CD image: Outpost.bin (from a BIN/CUE rip) or an .iso.",
        'Outpost - first-time setup', 'OK', 'Information') | Out-Null
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Title = 'Pick the Outpost CD image (Outpost.bin or .iso)'
    $dlg.Filter = 'CD image (*.bin;*.iso)|*.bin;*.iso|All files (*.*)|*.*'
    $dlg.InitialDirectory = Join-Path $env:USERPROFILE 'Downloads'
    if ($dlg.ShowDialog() -eq 'OK') { return $dlg.FileName }
    return $null
}

function Convert-BinToIso([string]$bin, [string]$iso) {
    # MODE1/2352 raw sectors -> 2048-byte ISO sectors (16-byte sync/header, 288-byte ECC stripped).
    $in = [IO.File]::OpenRead($bin)
    try {
        $sync = New-Object byte[] 16
        $in.Read($sync, 0, 16) | Out-Null
        $isRaw = ($sync[0] -eq 0 -and $sync[1] -eq 0xFF -and $sync[11] -eq 0 -and $sync[15] -eq 1)
        $in.Position = 0
        if (-not $isRaw) { Copy-Item -LiteralPath $bin -Destination $iso -Force; return }
        $out = [IO.File]::Create($iso)
        try {
            # Data track only: stop at the first sector without a sync header (post-gap / audio track).
            $n = 2000; $buf = New-Object byte[] (2352 * $n)
            $total = [math]::Floor($in.Length / 2352); $done = 0; $stop = $false
            while (-not $stop) {
                $got = $in.Read($buf, 0, $buf.Length); if ($got -le 0) { break }
                $cnt = [math]::Floor($got / 2352)
                for ($i = 0; $i -lt $cnt; $i++) {
                    $o = $i * 2352
                    if ($buf[$o] -ne 0 -or $buf[$o+1] -ne 0xFF -or $buf[$o+15] -ne 1) { $stop = $true; break }
                    $out.Write($buf, $o + 16, 2048)
                }
                $done += $cnt
                Write-Progress -Activity 'Converting CD image' -PercentComplete ([int](100 * $done / $total))
            }
        } finally { $out.Close() }
    } finally { $in.Close() }
    Write-Progress -Activity 'Converting CD image' -Completed
}

$needData = @('BITMAPS', 'VIDEOS', 'MUSIC') | Where-Object { -not (Test-Path -LiteralPath (Join-Path $here $_)) }
$needGame = -not (Test-Path -LiteralPath (Join-Path $here 'OUTPOST.EXE'))
if (-not $needData -and -not $needGame) { exit 0 }

Write-Host ''
Write-Host '  First-time setup: getting the game and its data off the Outpost CD...'
$src = Find-Image
if (-not $src) { Write-Host '  No CD image chosen.'; exit 2 }
Write-Host "  Using: $src"

$iso = $null; $letter = $null
if ($src.EndsWith(':\')) {
    $letter = $src.Substring(0, 1)
} else {
    $iso = Join-Path $here 'Outpost_tmp.iso'
    if ($src.ToLower().EndsWith('.iso')) { $iso = $src } else { Convert-BinToIso $src $iso }
    $img = Mount-DiskImage -ImagePath $iso -PassThru
    Start-Sleep -Seconds 2
    $letter = ($img | Get-Volume).DriveLetter
    if (-not $letter) { $letter = (Get-DiskImage -ImagePath $iso | Get-Volume).DriveLetter }
    if (-not $letter) { throw 'Windows mounted the image but gave it no drive letter.' }
}

try {
    foreach ($d in $needData) {
        $from = "${letter}:\$d"
        if (-not (Test-Path -LiteralPath $from)) { throw "Folder $d not found on the CD." }
        Write-Host "  Copying $d ..."
        Copy-Item -LiteralPath $from -Destination (Join-Path $here $d) -Recurse -Force
    }
    $man = "${letter}:\MANUAL\OUTP_GB.PDF"
    if (Test-Path -LiteralPath $man) {
        New-Item -ItemType Directory -Path (Join-Path $here 'Manual') -Force | Out-Null
        Copy-Item -LiteralPath $man -Destination (Join-Path $here 'Manual\Outpost Manual.pdf') -Force
    }
    if ($needGame) {
        $res = "${letter}:\RESOURCE.000"
        if (-not (Test-Path -LiteralPath $res)) { throw 'RESOURCE.000 (the game installer archive) not found on the CD.' }
        Write-Host '  Unpacking the game from RESOURCE.000 ...'
        $tmp = Join-Path $here 'RESOURCE.000'
        Copy-Item -LiteralPath $res -Destination $tmp -Force
        [Blast]::ExtractSierraArchive($tmp, $here) | ForEach-Object { Write-Host "    $_" }
        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
        foreach ($f in 'READ.ME', 'LANGUAGE.INF') {
            if (Test-Path -LiteralPath "${letter}:\$f") { Copy-Item -LiteralPath "${letter}:\$f" -Destination $here -Force }
        }
    }
} finally {
    if ($iso) { Dismount-DiskImage -ImagePath $iso | Out-Null }
}
if ($iso -and $iso -ne $src) { Remove-Item -LiteralPath $iso -Force -ErrorAction SilentlyContinue }
Remove-Item -LiteralPath (Join-Path $here 'cd_tmp') -Recurse -Force -ErrorAction SilentlyContinue

# Sensible default settings (the game fills in opimage= itself via the launcher).
$ini = Join-Path $here 'OUTPOST.INI'
if (-not (Test-Path -LiteralPath $ini) -or (Get-Item -LiteralPath $ini).Length -lt 40) {
    @('[general]','opimage=','falseMap=off','anims=on','music=on','sound=on','movies=on','turns=5','turnsDlgStatus=off','aiName=ai','playerName=player') -join "`r`n" |
        Set-Content -LiteralPath $ini -Encoding ASCII
}
Write-Host '  Done.'
exit 0
