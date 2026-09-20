<#
.SYNOPSIS
Back up the entire WTF directory, or restore an earlier backup while WoW is closed.
.EXAMPLE
.\Backup-WoWConfig.ps1
.EXAMPLE
.\Backup-WoWConfig.ps1 -RestoreFrom 'F:\WoWConfigBackups\WTF-20260920-120000.zip'
#>
[CmdletBinding()]
param(
    [string]$ClientPath = (Join-Path $PSScriptRoot '..\..\..\..'),
    [string]$BackupDirectory = '',
    [string]$RestoreFrom = ''
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$client = (Resolve-Path -LiteralPath $ClientPath).Path
$wtf = Join-Path $client 'WTF'
$running = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match '^Wow(Classic)?[A-Za-z]*$' }
if ($running) { throw 'Close World of Warcraft normally first, so all settings are written to disk.' }
if (-not (Test-Path -LiteralPath $wtf -PathType Container)) { throw "No WTF folder found at $wtf" }
if (-not $BackupDirectory) { $BackupDirectory = Join-Path (Split-Path $client -Parent) 'WoWConfigBackups' }
$backupFull = [IO.Path]::GetFullPath($BackupDirectory)
if ($backupFull.StartsWith($wtf + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -or $backupFull -eq $wtf) {
    throw 'Backups must be stored outside the WTF folder.'
}
[IO.Directory]::CreateDirectory($backupFull) | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
$archive = Join-Path $backupFull "WTF-$stamp.zip"
if ($RestoreFrom) {
    $source = (Resolve-Path -LiteralPath $RestoreFrom).Path
    if (Test-Path -LiteralPath ($source + '.sha256')) {
        $expected = (Get-Content -LiteralPath ($source + '.sha256') -Raw).Trim()
        if ((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -ne $expected) { throw 'Backup checksum mismatch; no settings changed.' }
    }
    $zip = [IO.Compression.ZipFile]::OpenRead($source)
    try {
        if ($zip.Entries.Count -eq 0) { throw 'Empty backup archive.' }
        $hasAccount = $false
        foreach ($entry in $zip.Entries) {
            $name = $entry.FullName.Replace('\', '/')
            if ($name.StartsWith('/') -or $name.Contains(':') -or $name -match '(^|/)\.\.(/|$)') { throw 'Unsafe archive path.' }
            if ($name.StartsWith('Account/')) { $hasAccount = $true }
        }
        if (-not $hasAccount) { throw 'Expected a WTF backup with Account/ at the ZIP root.' }
    } finally { $zip.Dispose() }
    # Extract first. Never remove the current settings if extraction fails.
    $stage = Join-Path $client ('.wtf-restore-' + [Guid]::NewGuid().ToString('N'))
    try {
        [IO.Compression.ZipFile]::ExtractToDirectory($source, $stage)
        [IO.Compression.ZipFile]::CreateFromDirectory($wtf, $archive, [IO.Compression.CompressionLevel]::Optimal, $false)
        $previous = Join-Path $client "WTF-before-restore-$stamp"
        Move-Item -LiteralPath $wtf -Destination $previous
        try { Move-Item -LiteralPath $stage -Destination $wtf }
        catch { Move-Item -LiteralPath $previous -Destination $wtf; throw }
        Write-Host "Restored $source"
        Write-Host "Previous settings retained in $previous and $archive"
    } finally {
        if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
    }
} else {
    [IO.Compression.ZipFile]::CreateFromDirectory($wtf, $archive, [IO.Compression.CompressionLevel]::Optimal, $false)
    Write-Host "Saved $archive"
}
$hash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash
Set-Content -LiteralPath ($archive + '.sha256') -Value $hash
Write-Host 'This backup includes all characters, addon data, bindings, macros, chat layout, and client settings stored in WTF.'
Write-Host 'Keep this archive private. It includes account and character identifiers and addon data.'
