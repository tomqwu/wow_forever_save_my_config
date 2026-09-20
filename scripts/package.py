"""Build a deterministic standalone addon ZIP and verify its contents."""
from pathlib import Path
import re
import zipfile
import hashlib
ROOT = Path(__file__).resolve().parents[1]
ADDON = ROOT / 'addons/ForeverSaveMyConfig'


def package(output=None):
    version = re.search(r'^## Version: (.+)$', (ADDON / 'ForeverSaveMyConfig.toc').read_text(), re.M)[1]
    output = output or ROOT / 'dist' / f'ForeverSaveMyConfig-v{version}.zip'
    output.parent.mkdir(parents=True, exist_ok=True)
    sources = sorted(path for path in ADDON.rglob('*') if path.is_file())
    with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path in sources:
            name = 'ForeverSaveMyConfig/' + path.relative_to(ADDON).as_posix()
            info = zipfile.ZipInfo(name, (2026, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            archive.writestr(info, path.read_bytes())
    with zipfile.ZipFile(output) as archive:
        assert archive.testzip() is None
        assert len(archive.namelist()) == len(sources)
        for path in sources:
            assert archive.read('ForeverSaveMyConfig/' + path.relative_to(ADDON).as_posix()) == path.read_bytes()
    return output


if __name__ == '__main__':
    archive = package()
    print(archive)
    print('SHA256 ' + hashlib.sha256(archive.read_bytes()).hexdigest())
