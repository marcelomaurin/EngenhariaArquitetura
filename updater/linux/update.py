#!/usr/bin/env python3
"""Atualizador de pacotes Linux publicados no GitHub Releases (sem dependencias)."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import tarfile
import tempfile
import time
from urllib.request import Request, urlopen

REPO = "marcelomaurin/EngenhariaArquitetura"
ASSET = "engenhariaarquitetura-linux-x86_64.tar.gz"
CHECKSUM = ASSET + ".sha256"
API = "https://api.github.com/repos/" + REPO + "/releases/latest"
ROOT = Path.home() / ".local" / "share" / "EngenhariaArquitetura"
STATE = Path.home() / ".cache" / "EngenhariaArquitetura" / "updater.json"
VERSION_RE = re.compile(r"^v?(\d+(?:\.\d+){1,3})$")
MAX_BYTES = 180 * 1024 * 1024


def version_tuple(value):
    match = VERSION_RE.fullmatch(value.strip())
    if not match:
        raise ValueError("versao de release invalida")
    parts = [int(p) for p in match.group(1).split(".")]
    return tuple((parts + [0] * 4)[:4])


def fetch(url, limit=MAX_BYTES):
    if not url.startswith("https://"):
        raise ValueError("download sem HTTPS")
    with urlopen(Request(url, headers={"User-Agent": "EA-Updater/1", "Accept": "application/vnd.github+json"}), timeout=20) as resp:
        length = resp.headers.get("Content-Length")
        if length and int(length) > limit:
            raise ValueError("download acima do limite")
        data = resp.read(limit + 1)
    if len(data) > limit:
        raise ValueError("download acima do limite")
    return data


def safe_extract(data, dest):
    archive_path = dest.parent / "package.tar.gz"
    archive_path.write_bytes(data)
    with tarfile.open(archive_path, "r:gz") as tf:
        members = tf.getmembers()
        if len(members) > 2000:
            raise ValueError("arquivo possui entradas demais")
        for member in members:
            name = member.name.lstrip("./")
            path = Path(name)
            if (not name or path.is_absolute() or ".." in path.parts or
                    not (member.isfile() or member.isdir()) or
                    member.size > MAX_BYTES):
                raise ValueError("pacote com caminho ou tipo inseguro")
        for member in members:
            name = member.name.lstrip("./")
            if not name:
                continue
            target = dest / name
            if member.isdir():
                target.mkdir(parents=True, exist_ok=True)
            else:
                target.parent.mkdir(parents=True, exist_ok=True)
                src = tf.extractfile(member)
                if src is None:
                    raise ValueError("entrada invalida no arquivo")
                with target.open("wb") as out:
                    shutil.copyfileobj(src, out)
                if name.startswith("bin/") and member.mode & 0o111:
                    target.chmod(0o755)
    if not (dest / "bin" / "engenhariaarquitetura").is_file():
        raise ValueError("pacote nao inclui launcher")
    if not (dest / "bin" / "cad2d").is_file():
        raise ValueError("pacote nao inclui CAD 2D")


def installed_version():
    for p in (ROOT / "current" / "release-version.txt",
              Path(__file__).resolve().parents[2] / "release-version.txt"):
        try:
            return p.read_text(encoding="utf-8").strip()
        except OSError:
            continue
    return "0.0.0"


def asset_url(release, name):
    for item in release.get("assets", []):
        if item.get("name") == name:
            url = item.get("browser_download_url", "")
            prefix = "https://github.com/" + REPO + "/releases/download/"
            if not url.startswith(prefix):
                raise ValueError("URL de release nao confiavel")
            return url
    return None


def write_state(status):
    STATE.parent.mkdir(parents=True, exist_ok=True)
    STATE.write_text(json.dumps({"last_check": int(time.time()), "status": status}), encoding="utf-8")


def install(release_tag, data):
    ROOT.mkdir(parents=True, exist_ok=True)
    versions = ROOT / "versions"
    versions.mkdir(exist_ok=True)
    final = versions / release_tag
    if not final.is_dir():
        with tempfile.TemporaryDirectory(prefix="ea-update-") as tmp:
            staging = Path(tmp) / "stage"
            staging.mkdir()
            safe_extract(data, staging)
            (staging / "release-version.txt").write_text(release_tag.lstrip("v") + "\n", encoding="utf-8")
            os.replace(staging, final)
    current = ROOT / "current"
    temp_link = ROOT / ".current-next"
    if temp_link.is_symlink() or temp_link.exists():
        temp_link.unlink()
    temp_link.symlink_to(final, target_is_directory=True)
    os.replace(temp_link, current)
    bindir = Path.home() / ".local" / "bin"
    bindir.mkdir(parents=True, exist_ok=True)
    for app in ("engenhariaarquitetura", "cad2d"):
        wrapper = bindir / app
        if wrapper.exists() and not wrapper.read_text(encoding="utf-8").startswith("# EA managed launcher"):
            continue
        wrapper.write_text('# EA managed launcher\n#!/bin/sh\nexec "$HOME/.local/share/EngenhariaArquitetura/current/bin/' +
                           app + '" "$@"\n', encoding="utf-8")
        wrapper.chmod(0o755)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--manual", action="store_true")
    args = parser.parse_args()
    if platform.system() != "Linux" or platform.machine().lower() not in ("x86_64", "amd64"):
        return 0
    if not args.manual and STATE.is_file():
        try:
            last = json.loads(STATE.read_text(encoding="utf-8")).get("last_check", 0)
            if time.time() - last < 86400:
                return 0
        except (ValueError, OSError):
            pass
    try:
        release = json.loads(fetch(API, limit=2*1024*1024).decode("utf-8"))
        tag = release.get("tag_name", "")
        if release.get("draft") or release.get("prerelease") or not tag:
            write_state("sem release estavel")
            return 0
        if version_tuple(tag) <= version_tuple(installed_version()):
            write_state("atualizado: " + tag)
            return 0
        url = asset_url(release, ASSET)
        checksum_url = asset_url(release, CHECKSUM)
        if not url or not checksum_url:
            write_state("release sem pacote Linux e checksum")
            return 0
        checksum = fetch(checksum_url, limit=1024).decode("ascii").strip().split()[0].lower()
        if not re.fullmatch(r"[0-9a-f]{64}", checksum):
            raise ValueError("checksum invalido")
        data = fetch(url)
        if hashlib.sha256(data).hexdigest() != checksum:
            raise ValueError("SHA256 nao confere")
        install(tag, data)
        write_state("instalado: " + tag)
        print("EngenhariaArquitetura atualizado:", tag)
    except Exception as exc:
        write_state("falha: " + str(exc)[:250])
        if args.manual:
            print("Nao foi possivel atualizar:", exc)
            return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
