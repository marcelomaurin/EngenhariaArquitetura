"""Testes de integridade, versoes e extracao do atualizador Linux."""
import io
from pathlib import Path
import tarfile
import tempfile
import unittest
from updater.linux import update


def archive_with(files):
    stream = io.BytesIO()
    with tarfile.open(fileobj=stream, mode="w:gz") as archive:
        for name, data in files.items():
            raw = data.encode("utf-8")
            entry = tarfile.TarInfo(name)
            entry.size = len(raw)
            entry.mode = 0o755
            archive.addfile(entry, io.BytesIO(raw))
    return stream.getvalue()


class UpdateTests(unittest.TestCase):
    def test_version_comparison(self):
        self.assertTrue(update.version_tuple("v0.02.101") > update.version_tuple("0.02"))
        self.assertTrue(update.version_tuple("0.03") > update.version_tuple("0.02.99"))
        self.assertEqual(update.version_tuple("v1.0.0"), (1, 0, 0, 0))
        with self.assertRaises(ValueError):
            update.version_tuple("v1.0/../../x")

    def test_extract_valid_bundle(self):
        data = archive_with({
            "./bin/engenhariaarquitetura": "launcher",
            "./bin/cad2d": "cad2d",
            "./updater/linux/update.py": "# updater",
        })
        with tempfile.TemporaryDirectory() as tmp:
            stage = Path(tmp) / "stage"
            stage.mkdir()
            update.safe_extract(data, stage)
            self.assertTrue((stage / "bin" / "engenhariaarquitetura").is_file())
            self.assertTrue((stage / "bin" / "cad2d").is_file())

    def test_reject_path_traversal(self):
        data = archive_with({
            "../escape": "bad",
            "bin/engenhariaarquitetura": "ok",
            "bin/cad2d": "ok",
        })
        with tempfile.TemporaryDirectory() as tmp:
            stage = Path(tmp) / "stage"
            stage.mkdir()
            with self.assertRaises(ValueError):
                update.safe_extract(data, stage)
            self.assertFalse((Path(tmp) / "escape").exists())

    def test_asset_host_whitelist(self):
        release = {"assets": [{"name": update.ASSET, "browser_download_url":
          "https://example.org/bad.tar.gz"}]}
        with self.assertRaises(ValueError):
            update.asset_url(release, update.ASSET)


if __name__ == "__main__":
    unittest.main()
