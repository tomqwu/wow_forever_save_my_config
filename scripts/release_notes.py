"""Validate tag/version and render the matching changelog entry."""
from pathlib import Path
import re
import sys
ROOT = Path(__file__).resolve().parents[1]
version = re.search(r'^## Version: (.+)$', (ROOT / 'addons/ForeverSaveMyConfig/ForeverSaveMyConfig.toc').read_text(), re.M)[1]
assert sys.argv[1] == f'ForeverSaveMyConfig-v{version}', 'Tag and TOC version differ.'
changelog = (ROOT / 'docs/changelog.md').read_text()
entry = re.search(r'^## ' + re.escape(version) + r'\n(.*?)(?=^## |\Z)', changelog, re.M | re.S)
assert entry, 'Missing version changelog.'
print(entry[1].strip())
