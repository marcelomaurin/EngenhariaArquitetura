#!/usr/bin/env python3
"""Gera as imagens do instalador (BMP) a partir do ícone e das capturas de tela.

Uso: prepare_images.py --version 0.01 --out dist/installer-images
"""
import argparse
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
NAVY, NAVY2 = (15, 23, 42), (30, 64, 145)


def fonte(tamanho, negrito=False):
    nomes = ["DejaVuSans-Bold.ttf" if negrito else "DejaVuSans.ttf",
             "segoeuib.ttf" if negrito else "segoeui.ttf", "arial.ttf"]
    for pasta in ["/usr/share/fonts/truetype/dejavu", r"C:\Windows\Fonts"]:
        for n in nomes:
            caminho = os.path.join(pasta, n)
            if os.path.exists(caminho):
                return ImageFont.truetype(caminho, tamanho)
    return ImageFont.load_default()


def gradiente(w, h):
    im = Image.new("RGB", (w, h))
    d = ImageDraw.Draw(im)
    for y in range(h):
        t = y / max(1, h - 1)
        d.line([(0, y), (w, y)], fill=tuple(int(NAVY[i] * (1 - t) + NAVY2[i] * t) for i in range(3)))
    return im


def icone(tamanho):
    ico = Image.open(os.path.join(ROOT, "planejador", "src", "app", "planejador.ico"))
    ico.size = (256, 256)
    return ico.convert("RGBA").resize((tamanho, tamanho), Image.LANCZOS)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--version", required=True)
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)

    # painel lateral das paginas de boas-vindas e conclusao (164x314 a 100%)
    w, h = 240, 459
    im = gradiente(w, h)
    ic = icone(120)
    im.paste(ic, ((w - 120) // 2, 70), ic)
    d = ImageDraw.Draw(im)
    for texto, y, f, cor in [("Engenharia", 225, fonte(26, True), (255, 255, 255)),
                             ("Arquitetura", 258, fonte(26, True), (255, 255, 255)),
                             ("Planejador", 310, fonte(16), (191, 219, 254)),
                             ("versão " + a.version, 410, fonte(13), (148, 163, 184))]:
        tw = d.textlength(texto, font=f)
        d.text(((w - tw) / 2, y), texto, font=f, fill=cor)
    im.save(os.path.join(a.out, "welcome.bmp"))

    # imagem pequena do cabecalho das paginas internas (55x55 a 100%)
    pequeno = Image.new("RGB", (80, 80), (255, 255, 255))
    ic = icone(72)
    pequeno.paste(ic, (4, 4), ic)
    pequeno.save(os.path.join(a.out, "small.bmp"))

    # imagem exibida durante a copia dos arquivos
    cap = Image.open(os.path.join(ROOT, "planejador", "screenshots", "planejador_gantt.png")).convert("RGB")
    cap.thumbnail((1000, 640), Image.LANCZOS)
    cap.save(os.path.join(a.out, "slide0.bmp"))
    print("imagens geradas em", a.out)


if __name__ == "__main__":
    main()
