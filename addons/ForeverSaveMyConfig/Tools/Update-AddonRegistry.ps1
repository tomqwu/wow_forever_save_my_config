<# Run after installing new addons, then /reload. Reads TOC declarations only. #>
[CmdletBinding()]
param([string]$AddOnsPath = (Join-Path $PSScriptRoot '..\..'))
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath $AddOnsPath).Path
$lines = [Collections.Generic.List[string]]::new()
$lines.Add('-- Generated from Interface 16001 TOC declarations, not player settings.')
$lines.Add('local _, NS = ...')
$lines.Add('NS.Registry = {')
$count = 0
# WoW Forever's game type. Directive lines may end in load conditions such as
# [AllowLoadGameType camelot][ExcludeLoadGameType classic]; keep only the
# lines that apply here and merge repeated SavedVariables lines.
$gameType = 'camelot'
function Split-Directive([string]$value) {
    $active = $true
    while ($value -match '^(.*?)\s*\[([A-Za-z]+)\s*([^\]]*)\]\s*$') {
        $value = $Matches[1]
        $kind = $Matches[2].ToLowerInvariant()
        $types = @($Matches[3].ToLowerInvariant() -split '[,\s]+' | Where-Object { $_ })
        if ($kind -eq 'allowloadgametype' -and $types -notcontains $gameType) { $active = $false }
        if ($kind -eq 'excludeloadgametype' -and $types -contains $gameType) { $active = $false }
    }
    return @($value.Trim(), $active)
}
foreach ($folder in (Get-ChildItem -LiteralPath $root -Directory | Sort-Object Name)) {
    if ($folder.Name -eq 'ForeverSaveMyConfig' -or $folder.Name.StartsWith('Blizzard_')) { continue }
    if ($folder.Name -cnotmatch '^[A-Za-z0-9_.!+-]+$') { throw "Unsupported addon folder: $($folder.Name)" }
    $candidates = [Collections.Generic.List[string]]::new()
    foreach ($toc in (Get-ChildItem -LiteralPath $folder.FullName -Filter '*.toc' | Sort-Object Name)) {
        $meta = @{}
        foreach ($line in (Get-Content -LiteralPath $toc.FullName -Encoding UTF8)) {
            if ($line -notmatch '^##\s*([^:]+):\s*(.*)') { continue }
            $key = $Matches[1].Trim()
            $value, $active = Split-Directive $Matches[2]
            if (-not $active) { continue }
            if ($key -in @('SavedVariables', 'SavedVariablesPerCharacter') -and $meta[$key]) { $meta[$key] += ', ' + $value }
            else { $meta[$key] = $value }
        }
        if ($meta['Interface'] -notmatch '\b16001\b') { continue }
        $variables = @{}
        foreach ($field in @('SavedVariables', 'SavedVariablesPerCharacter')) {
            $scope = if ($field -eq 'SavedVariables') { 'account' } else { 'character' }
            foreach ($name in ($meta[$field] -split '[,\s]+')) {
                if (-not $name) { continue }
                if ($name -notmatch '^[A-Za-z_][A-Za-z0-9_]*$' -or $name -eq 'ForeverSaveMyConfigDB') { throw "Invalid variable in $($toc.Name)" }
                $variables[$name] = $scope
            }
        }
        $entry = [Collections.Generic.List[string]]::new()
        foreach ($name in ($variables.Keys | Sort-Object -CaseSensitive)) { $entry.Add('        ["' + $name + '"] = "' + $variables[$name] + '",') }
        $candidates.Add(($entry -join "`n"))
    }
    if ($candidates.Count -eq 0) { continue }
    foreach ($candidate in $candidates) { if ($candidate -cne $candidates[0]) { throw "Ambiguous Forever TOCs for $($folder.Name)" } }
    $lines.Add('    ["' + $folder.Name + '"] = {')
    if ($candidates[0]) { $lines.Add($candidates[0]) }
    $lines.Add('    },')
    $count++
}
if ($count -eq 0) { throw 'No Interface 16001 addons found. Registry left unchanged.' }
$lines.Add('}')
$target = Join-Path $root 'ForeverSaveMyConfig\Registry.lua'
[IO.File]::WriteAllText($target, ($lines -join "`n") + "`n", [Text.UTF8Encoding]::new($false))
Write-Host "Registered $count addons. Reload WoW and check /fconfig > Addon coverage."
