import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock
import zipfile
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))
import registry
import package
import install
import release_guard


class ToolsTests(unittest.TestCase):
    def test_registry_reads_only_declarations_and_scopes(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            addon = root / 'Example'
            addon.mkdir()
            (addon / 'Example.toc').write_text('## Interface: 16001\n## SavedVariables: ExampleDB, Other\n## SavedVariablesPerCharacter: CharDB\n')
            (addon / 'Private.lua').write_text('private configuration must not be read')
            data = registry.scan(root)
            self.assertEqual(data, {'Example': {'ExampleDB': 'account', 'Other': 'account', 'CharDB': 'character'}})
            self.assertNotIn('private', registry.render(data))

    def test_ambiguous_tocs_and_unsafe_declarations_refused(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            addon = root / 'Example'
            addon.mkdir()
            a = addon / 'Example.toc'
            b = addon / 'Example_Vanilla.toc'
            a.write_text('## Interface: 16001\n## SavedVariables: Good\n')
            b.write_text('## Interface: 16001\n## SavedVariables: Different\n')
            with self.assertRaises(ValueError):
                registry.scan(root)
            b.unlink()
            a.write_text('## Interface: 16001\n## SavedVariables: bad.name\n')
            with self.assertRaises(ValueError):
                registry.scan(root)

    def test_package_is_reproducible_and_exact_standalone_root(self):
        with tempfile.TemporaryDirectory() as directory:
            a = package.package(Path(directory) / 'a.zip')
            b = package.package(Path(directory) / 'b.zip')
            self.assertEqual(a.read_bytes(), b.read_bytes())
            with zipfile.ZipFile(a) as archive:
                for name in archive.namelist():
                    self.assertTrue(name.startswith('ForeverSaveMyConfig/'))
                    self.assertEqual(archive.read(name), (ROOT / 'addons' / name).read_bytes())

    def test_install_preserves_unexpected_local_edits(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            target, manifest = root / 'ForeverSaveMyConfig', root / 'manifest.json'
            install.install(target, manifest)
            changed = target / 'Core.lua'
            changed.write_text('-- local edit')
            with self.assertRaises(SystemExit):
                install.install(target, manifest)
            self.assertEqual(changed.read_text(), '-- local edit')

    def test_versions_match(self):
        import re
        toc = (package.ADDON / 'ForeverSaveMyConfig.toc').read_text()
        profiles = (package.ADDON / 'Profiles.lua').read_text()
        self.assertEqual(re.search(r'## Version: (\S+)', toc)[1], re.search(r"NS.Version = '(.*?)'", profiles)[1])

    def test_release_tag_comes_from_toc(self):
        self.assertRegex(release_guard.release_tag(), r'^ForeverSaveMyConfig-v\d+\.\d+\.\d+$')

    def test_release_guard_accepts_missing_tag(self):
        result = mock.Mock(returncode=1, stdout='', stderr='gh: Not Found (HTTP 404)')
        with mock.patch.object(release_guard.subprocess, 'run', return_value=result):
            release_guard.assert_unreleased('owner/repository', 'ForeverSaveMyConfig-v9.9.9')

    def test_release_guard_rejects_existing_tag(self):
        result = mock.Mock(
            returncode=0,
            stdout='{"object":{"sha":"abc123"}}',
            stderr='',
        )
        with mock.patch.object(release_guard.subprocess, 'run', return_value=result):
            with self.assertRaisesRegex(ValueError, 'already exists at abc123'):
                release_guard.assert_unreleased('owner/repository', 'ForeverSaveMyConfig-v9.9.9')

    def test_release_guard_does_not_hide_api_failures(self):
        result = mock.Mock(returncode=1, stdout='', stderr='gh: API rate limit exceeded')
        with mock.patch.object(release_guard.subprocess, 'run', return_value=result):
            with self.assertRaisesRegex(RuntimeError, 'Could not verify'):
                release_guard.assert_unreleased('owner/repository', 'ForeverSaveMyConfig-v9.9.9')


if __name__ == '__main__':
    unittest.main()
