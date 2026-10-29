#!/usr/bin/env python3
"""Gera dist/app/build-manifest.json e dist/version.iss para o instalador.

Uso: release_manifest.py --app-dir dist/app --version 0.01 --seq 001
       --version-include dist/version.iss [--require-clean]
"""
import argparse
import datetime
import hashlib
import json
import os
import subprocess
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))


def git(*args):
    try:
        return subprocess.check_output(["git", "-C", ROOT, *args], text=True).strip()
    except Exception:
        return ""


def sha256(caminho):
    h = hashlib.sha256()
    with open(caminho, "rb") as f:
        for bloco in iter(lambda: f.read(1 << 20), b""):
            h.update(bloco)
    return h.hexdigest()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--app-dir", required=True)
    ap.add_argument("--version", required=True)
    ap.add_argument("--seq", required=True)
    ap.add_argument("--version-include", required=True)
    ap.add_argument("--require-clean", action="store_true")
    a = ap.parse_args()

    sujo = bool(git("status", "--porcelain"))
    if a.require_clean and sujo:
        sys.exit("a release exige árvore git limpa (use --allow-dirty para teste local)")

    partes = [int(p) for p in a.version.split(".") if p.isdigit()]
    while len(partes) < 4:
        partes.append(0)
    binaria = ".".join(str(p) for p in partes[:4])

    arquivos = []
    for base, _, nomes in os.walk(a.app_dir):
        for n in sorted(nomes):
            if n == "build-manifest.json":
                continue
            c = os.path.join(base, n)
            arquivos.append({"path": os.path.relpath(c, a.app_dir).replace(os.sep, "/"),
                             "bytes": os.path.getsize(c), "sha256": sha256(c)})

    testes = {}
    qa = os.path.join(a.app_dir, "qa-tests.json")
    if os.path.exists(qa):
        with open(qa, encoding="utf-8") as f:
            testes = json.load(f)

    manifesto = {
        "schema_version": "1.0",
        "package_type": "build_manifest",
        "product": "EngenhariaArquitetura",
        "version": a.version,
        "binary_version": binaria,
        "setup_seq": a.seq,
        "os": "windows",
        "arch": "amd64",
        "built_at": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
        "source_commit": git("rev-parse", "HEAD"),
        "source_branch": git("rev-parse", "--abbrev-ref", "HEAD"),
        "source_dirty": sujo,
        "tests": testes,
        "files": sorted(arquivos, key=lambda x: x["path"]),
    }
    with open(os.path.join(a.app_dir, "build-manifest.json"), "w", encoding="utf-8") as f:
        json.dump(manifesto, f, ensure_ascii=False, indent=2)
    with open(a.version_include, "w", encoding="utf-8") as f:
        f.write('#define MyAppVersion "%s"\n#define MyBinaryVersion "%s"\n' % (a.version, binaria))
    print("manifesto:", len(arquivos), "arquivos, commit", manifesto["source_commit"][:7],
          "(alterações locais)" if sujo else "")


if __name__ == "__main__":
    main()
