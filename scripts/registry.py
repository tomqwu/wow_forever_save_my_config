"""Generate only addon names and TOC variable declarations; never read saved values."""
import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ADDON = ROOT / 'addons/ForeverSaveMyConfig'
IDENTIFIER = re.compile(r'^[A-Za-z_][A-Za-z0-9_]*$')
# Folder names such as !BugGrabber or +Wowhead_Looter load in the client.
# Kept in step with Update-AddonRegistry.ps1 and Profiles.lua validation.
FOLDER = re.compile(r'[A-Za-z0-9_.!+-]+')
GAME_TYPE = 'camelot'  # WoW Forever's game type for TOC load conditions.
CONDITION = re.compile(r'\s*\[([A-Za-z]+)\s*([^\]]*)\]\s*$')


def applies(value):
    """Strip trailing [AllowLoadGameType ...]/[ExcludeLoadGameType ...] conditions.

    Returns (value, applies to Forever). Other conditions, such as text
    locale or environment, do not decide between game types and are ignored.
    """
    active = True
    while True:
        match = CONDITION.search(value)
        if not match:
            return value.strip(), active
        kind, types = match[1].lower(), set(re.split(r'[,\s]+', match[2].strip().lower())) - {''}
        if kind == 'allowloadgametype' and GAME_TYPE not in types:
            active = False
        elif kind == 'excludeloadgametype' and GAME_TYPE in types:
            active = False
        value = value[:match.start()]


def metadata(toc):
    """Directive values that apply to Forever; repeated SavedVariables lines are merged."""
    result = {}
    for line in toc.read_text(encoding='utf-8-sig').splitlines():
        match = re.match(r'##\s*([^:]+):\s*(.*)', line)
        if not match:
            continue
        value, active = applies(match[2])
        if not active:
            continue
        key = match[1].strip().lower()
        if key in ('savedvariables', 'savedvariablespercharacter') and result.get(key):
            result[key] += ', ' + value
        else:
            result[key] = value
    return result


def scan(folder):
    result = {}
    for addon in sorted(folder.iterdir()):
        if not addon.is_dir() or addon.name == 'ForeverSaveMyConfig' or addon.name.startswith('Blizzard_'):
            continue
        if not FOLDER.fullmatch(addon.name):
            raise ValueError(f'Unsupported addon folder name: {addon.name}')
        candidates = []
        for toc in sorted(addon.glob('*.toc')):
            meta = metadata(toc)
            if '16001' not in re.findall(r'\d+', meta.get('interface', '')):
                continue
            variables = {}
            for key, scope in [('savedvariables', 'account'), ('savedvariablespercharacter', 'character')]:
                for name in re.split(r'[,\s]+', meta.get(key, '')):
                    if not name:
                        continue
                    if not IDENTIFIER.fullmatch(name) or name == 'ForeverSaveMyConfigDB':
                        raise ValueError(f'Unsafe saved variable declaration in {toc}: {name}')
                    variables[name] = scope
            candidates.append(variables)
        if not candidates:
            continue
        if any(candidate != candidates[0] for candidate in candidates):
            raise ValueError(f'Ambiguous Forever TOCs for {addon.name}; choose the active TOC before scanning.')
        result[addon.name] = candidates[0]
    return result


def render(entries):
    lines = ['-- Generated from Interface 16001 TOC declarations, not player settings.', 'local _, NS = ...', 'NS.Registry = {']
    for addon, variables in sorted(entries.items()):
        lines.append(f'    [{json.dumps(addon)}] = {{')
        for name, scope in sorted(variables.items()):
            lines.append(f'        [{json.dumps(name)}] = {json.dumps(scope)},')
        lines.append('    },')
    return '\n'.join(lines + ['}', ''])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('addons', type=Path, help='Client Interface/AddOns directory')
    parser.add_argument('--output', type=Path, default=ADDON / 'Registry.lua')
    args = parser.parse_args()
    entries = scan(args.addons)
    if not entries:
        raise SystemExit('No Interface 16001 addons found; registry left unchanged.')
    args.output.write_text(render(entries), encoding='utf-8')
    print(f'Registered {len(entries)} addons / {sum(map(len, entries.values()))} saved variables.')


if __name__ == '__main__':
    main()
