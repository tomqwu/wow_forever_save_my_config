"""Install packaged source bytes; refuse unexpected local edits or extra files."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
from package import ADDON, ROOT


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def install(target, manifest):
    files = {p.relative_to(ADDON).as_posix(): p for p in ADDON.rglob('*') if p.is_file()}
    previous = json.loads(manifest.read_text()) if manifest.exists() else {}
    if target.exists():
        for path in target.rglob('*'):
            if not path.is_file():
                continue
            relative = path.relative_to(target).as_posix()
            if relative not in files or (digest(path) != digest(files[relative]) and digest(path) != previous.get(relative)):
                raise SystemExit(f'Preserving unexpected local file/edit: {path}')
    for relative, source in files.items():
        destination = target / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, destination)
        assert destination.read_bytes() == source.read_bytes()
    manifest.parent.mkdir(parents=True, exist_ok=True)
    manifest.write_text(json.dumps({name: digest(source) for name, source in sorted(files.items())}, indent=2)+'\n')
    print(f'Installed and byte-verified {len(files)} files at {target}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('addons', type=Path)
    args = parser.parse_args()
    install(args.addons / 'ForeverSaveMyConfig', ROOT / '.local/install-manifest.json')
