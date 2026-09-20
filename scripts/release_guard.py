"""Print the current release tag and reject versions already published upstream."""
import argparse
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
TOC = ROOT / "addons/ForeverSaveMyConfig/ForeverSaveMyConfig.toc"


def release_tag():
    match = re.search(
        r"^## Version:\s*(\d+\.\d+\.\d+)\s*$",
        TOC.read_text(encoding="utf-8-sig"),
        re.MULTILINE,
    )
    if not match:
        raise ValueError("TOC must contain a semantic X.Y.Z version")
    return "ForeverSaveMyConfig-v" + match.group(1)


def assert_unreleased(repository, tag):
    result = subprocess.run(
        ["gh", "api", f"repos/{repository}/git/ref/tags/{tag}"],
        text=True,
        capture_output=True,
    )
    if result.returncode == 0:
        payload = json.loads(result.stdout)
        target = payload.get("object", {}).get("sha", "unknown commit")
        raise ValueError(
            f"{tag} already exists at {target}. Bump the TOC/displayed version "
            "and add an exact-version changelog entry before merging to main."
        )
    if "HTTP 404" not in result.stderr:
        raise RuntimeError("Could not verify the release tag: " + result.stderr.strip())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository", help="GitHub owner/repository to check")
    args = parser.parse_args()
    tag = release_tag()
    if args.repository:
        assert_unreleased(args.repository, tag)
    print(tag)


if __name__ == "__main__":
    main()
