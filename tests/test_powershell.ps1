# Integration tests on synthetic data only. No real client settings are accessed.
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$tools = Join-Path $repo 'addons\ForeverSaveMyConfig\Tools'
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('fsmc-test-' + [Guid]::NewGuid().ToString('N'))
function Assert($condition, $message) { if (-not $condition) { throw $message } }
# Shadow the process query only in this test's scope; production scripts still block live WoW.
function Get-Process { [CmdletBinding()] param() }
try {
    $client = Join-Path $fixture 'client'
    $wtf = Join-Path $client 'WTF'
    $account = Join-Path $wtf 'Account\TestAccount'
    New-Item -ItemType Directory -Path $account -Force | Out-Null
    $settings = Join-Path $account 'test.lua'
    Set-Content -LiteralPath $settings -Value 'SYNTHETIC = 1'
    $backups = Join-Path $fixture 'backups'
    & (Join-Path $tools 'Backup-WoWConfig.ps1') -ClientPath $client -BackupDirectory $backups
    $archive = (Get-ChildItem -LiteralPath $backups -Filter '*.zip')[0].FullName
    Assert (Test-Path -LiteralPath ($archive + '.sha256')) 'Checksum missing'
    Set-Content -LiteralPath $settings -Value 'SYNTHETIC = 2'
    & (Join-Path $tools 'Backup-WoWConfig.ps1') -ClientPath $client -BackupDirectory $backups -RestoreFrom $archive
    Assert ((Get-Content -LiteralPath $settings -Raw).Trim() -eq 'SYNTHETIC = 1') 'Restore did not recover original bytes'
    Assert ((Get-ChildItem -LiteralPath $client -Directory -Filter 'WTF-before-restore-*').Count -eq 1) 'Previous settings not retained'
    Set-Content -LiteralPath ($archive + '.sha256') -Value 'wrong'
    $rejected = $false
    try { & (Join-Path $tools 'Backup-WoWConfig.ps1') -ClientPath $client -BackupDirectory $backups -RestoreFrom $archive }
    catch { $rejected = $_.ToString().Contains('checksum mismatch') }
    Assert $rejected 'Damaged backup was not rejected'
    function Get-Process { [CmdletBinding()] param() [PSCustomObject]@{ProcessName='WowClassicB'} }
    $rejected = $false
    try { & (Join-Path $tools 'Backup-WoWConfig.ps1') -ClientPath $client -BackupDirectory $backups }
    catch { $rejected = $_.ToString().Contains('Close World of Warcraft') }
    Assert $rejected 'Running-game guard failed'
    function Get-Process { [CmdletBinding()] param() }
    $addons = Join-Path $client 'Interface\AddOns'
    New-Item -ItemType Directory -Path (Join-Path $addons 'Example') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $addons 'ForeverSaveMyConfig') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $addons 'Example\Example.toc') -Value "## Interface: 16001`n## SavedVariables: ExampleDB`n## SavedVariablesPerCharacter: CharacterDB"
    & (Join-Path $tools 'Update-AddonRegistry.ps1') -AddOnsPath $addons
    $registry = Get-Content -LiteralPath (Join-Path $addons 'ForeverSaveMyConfig\Registry.lua') -Raw
    Assert ($registry.Contains('["ExampleDB"] = "account"')) 'Account declaration missing'
    Assert ($registry.Contains('["CharacterDB"] = "character"')) 'Character declaration missing'
    Write-Host 'PASS PowerShell: backup, restore, retained recovery, checksums, live-game guard, registry scan'
} finally {
    if (Test-Path -LiteralPath $fixture) { Remove-Item -LiteralPath $fixture -Recurse -Force }
}
