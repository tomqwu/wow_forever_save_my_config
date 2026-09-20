"""Generate only addon names and TOC variable declarations; never read saved values."""
import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ADDON = ROOT / 'addons/ForeverSaveMyConfig'
IDENTIFIER = re.compile(r'^[A-Za-z_][A-Za-z0-9_]*$')


def metadata(toc):
    result = {}
    for line in toc.read_text(encoding='utf-8-sig').splitlines():
        match = re.match(r'##\s*([^:]+):\s*(.*)', line)
        if match:
            result[match[1].strip().lower()] = match[2].strip()
    return result


def scan(folder):
    result = {}
    for addon in sorted(folder.iterdir()):
        if not addon.is_dir() or addon.name == 'ForeverSaveMyConfig' or addon.name.startswith('Blizzard_'):
            continue
        if not re.fullmatch(r'[A-Za-z0-9_-]+', addon.name):
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
