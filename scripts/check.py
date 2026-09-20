"""Validate Lua 5.1 syntax, mocked client behavior, and packaging tools."""
import subprocess
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
for source in sorted((ROOT / 'addons').rglob('*.lua')):
    subprocess.run(['luac5.1', '-p', str(source)], check=True)
subprocess.run(['lua5.1', 'tests/test.lua'], cwd=ROOT, check=True)
subprocess.run(['python3', '-m', 'unittest', 'discover', '-s', 'tests', '-p', 'test_*.py'], cwd=ROOT, check=True)
