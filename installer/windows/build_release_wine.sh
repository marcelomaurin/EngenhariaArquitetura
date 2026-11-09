#!/usr/bin/env bash
# Gera o instalador Windows x64 no Linux: compilacao cruzada win64 (FPC/Lazarus),
# testes de console win64 rodando no Wine e Inno Setup (ISCC.exe) no Wine.
# Mesmos passos e saidas do build_release.ps1.
#
# Requisitos: lazbuild, fpc com as units x86_64-win64 (RTL e pacotes), wine,
# python3 com Pillow e o Inno Setup 6.3+ (ISCC.exe).
#
#   ISCC=/caminho/ISCC.exe installer/windows/build_release_wine.sh [versao] [seq] [--allow-dirty]
#
# Sem argumentos, versao e seq vem de installer/VERSION.ini.
# EA_CHATGPT_DIR aponta para o repositorio CHATGPT (padrao: ../CHATGPT ao lado deste).
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
cd "$ROOT"
ini() { sed -n "s/^$1=//p" installer/VERSION.ini | tr -d '\r'; }
VERSION=${1:-$(ini AppVersion)}
SEQ=${2:-$(ini SetupSeq)}
ALLOW_DIRTY=${3:-}
DIST="$ROOT/dist"; APP="$DIST/app"; BIN="$ROOT/bin"
WINE=${WINE:-wine}
ISCC=${ISCC:?defina ISCC com o caminho do ISCC.exe}
LAZBUILD=${LAZBUILD:-lazbuild}
FPC_BIN=${FPC:-fpc}
CHATGPT=${EA_CHATGPT_DIR:-$(dirname "$ROOT")/CHATGPT}
export WINEDEBUG=${WINEDEBUG:--all}
# o Wine precisa de localidade UTF-8 para criar atalhos com acento
export LC_ALL=${LC_ALL:-C.UTF-8} LANG=${LANG:-C.UTF-8}
[[ "$SEQ" =~ ^[0-9]{3}$ ]] || { echo "SetupSeq invalido: $SEQ"; exit 1; }
if [ "$ALLOW_DIRTY" != "--allow-dirty" ] && [ -n "$(git status --porcelain -- . ':!bin' ':!setup' ':!dist')" ]; then
  echo "A release exige uma arvore Git limpa. Para build local use --allow-dirty."; exit 1
fi
rm -rf "$APP"
mkdir -p "$APP" "$BIN" "$DIST/build-logs" setup

# unidades da CHATGPT: repositorio ao lado, com a copia de third_party como reserva
CORE="$ROOT/third_party/chatgpt/AIProjectCore"
[ -d "$CHATGPT/pacote/AI Project Core" ] && CORE="$CHATGPT/pacote/AI Project Core"

TARGETS=(
  "planejador/src/app/planejador|planejador"
  "launcher/src/app/engenhariaarquitetura|engenhariaarquitetura"
  "cad2d/src/app/cad2d|cad2d"
)
for t in "${TARGETS[@]}"; do
  project=${t%%|*}; name=${t##*|}
  echo "Compilando $name..."
  log="$DIST/build-logs/$name.log"
  if ! "$LAZBUILD" -B --cpu=x86_64 --os=win64 --ws=win32 --build-mode=Default "$project.lpi" > "$log" 2>&1; then
    tail -35 "$log"; echo "Falha ao compilar $name"; exit 1
  fi
  cp "$BIN/$name.exe" "$APP/$name.exe"
done

mkdir -p "$DIST/tools/units"
"$FPC_BIN" -Px86_64 -Twin64 -Mobjfpc -Sh -Fu"$ROOT/shared" -Fu"$ROOT/cad2d/src/app" -Fu"$ROOT/planejador/src/core" -Fu"$ROOT/planejador/src/io" -Fu"$CORE" -FU"$DIST/tools/units" -o"$DIST/tools/gerar_exemplos_saude.exe" planejador/tools/gerar_exemplos_saude.lpr > "$DIST/build-logs/gerar_exemplos_saude.log" 2>&1
GEN_ROOT="Z:$(printf '%s' "$ROOT" | tr '/' '\\')"
"$WINE" "$DIST/tools/gerar_exemplos_saude.exe" "$GEN_ROOT"

# testes de console win64 no Wine
echo "Testes de console..."
TESTS=(
  "planejador/tests/test_planejador_core|planejador/src/core;planejador/src/io"
  "cad2d/tests/test_cad_document|cad2d/src/app;shared"
  "cad2d/tests/test_cad_dxf|cad2d/src/app;shared"
  "cad2d/tests/test_cad_catalog|cad2d/src/app;shared"
  "shared/tests/test_config|shared"
  "planejador/tests/test_recursos|planejador/src/core;planejador/src/io;shared"
  "planejador/tests/test_sprints|planejador/src/core;planejador/src/io;shared"
  "planejador/tests/test_relatorios_sprint|planejador/src/core;planejador/src/io;shared"
)
QA="$DIST/qa-tests.json"; echo "[" > "$QA"; first=1
mkdir -p "$DIST/tests"
for t in "${TESTS[@]}"; do
  src=${t%%|*}; paths=${t##*|}; name=$(basename "$src")
  args=(); IFS=';' read -ra P <<< "$paths"; for p in "${P[@]}"; do args+=("-Fu$ROOT/$p"); done
  "$FPC_BIN" -Px86_64 -Twin64 -Mobjfpc -Sh -FU"$DIST/tests/$name" "${args[@]}" -Fu"$CORE" -Fu"$ROOT/shared" \
    -o"$DIST/tests/$name.exe" "$src.lpr" > "$DIST/build-logs/$name.log" 2>&1 \
    || { mkdir -p "$DIST/tests/$name" && "$FPC_BIN" -Px86_64 -Twin64 -Mobjfpc -Sh -FU"$DIST/tests/$name" "${args[@]}" -Fu"$CORE" -Fu"$ROOT/shared" \
    -o"$DIST/tests/$name.exe" "$src.lpr" > "$DIST/build-logs/$name.log" 2>&1; } \
    || { tail -20 "$DIST/build-logs/$name.log"; echo "Falha ao compilar $name"; exit 1; }
  if "$WINE" "$DIST/tests/$name.exe" > "$DIST/build-logs/$name.run.log" 2>&1; then ok=true; else ok=false; fi
  resumo=$(tail -1 "$DIST/build-logs/$name.run.log" | tr -d '\r')
  echo "  $name: $resumo"
  [ $first -eq 1 ] || echo "," >> "$QA"; first=0
  printf '  {"test": "%s", "passed": %s, "summary": "%s"}' "$name" "$ok" "$resumo" >> "$QA"
  $ok || { cat "$DIST/build-logs/$name.run.log"; echo "Testes falharam: $name"; exit 1; }
done
# Regressao CAD 2D com LCL (rodar em sessao grafica Wine/Xvfb).
"$LAZBUILD" -B --cpu=x86_64 --os=win64 --ws=win32 cad2d/tests/test_cad2d.lpi > "$DIST/build-logs/test_cad2d.log" 2>&1
"$WINE" "$DIST/tests/test_cad2d.exe" > "$DIST/build-logs/test_cad2d.run.log" 2>&1
resumo=$(tail -1 "$DIST/build-logs/test_cad2d.run.log" | tr -d '\r')
echo "," >> "$QA"
printf '  {"test": "test_cad2d", "passed": true, "summary": "%s"}' "$resumo" >> "$QA"
echo "  test_cad2d: $resumo"
"$LAZBUILD" -B --cpu=x86_64 --os=win64 --ws=win32 planejador/tests/test_recursos_ui.lpi > "$DIST/build-logs/test_recursos_ui.log" 2>&1
"$WINE" "$DIST/tests/test_recursos_ui.exe" > "$DIST/build-logs/test_recursos_ui.run.log" 2>&1
resumo=$(tail -1 "$DIST/build-logs/test_recursos_ui.run.log" | tr -d '\r')
echo "," >> "$QA"
printf '  {"test": "test_recursos_ui", "passed": true, "summary": "%s"}' "$resumo" >> "$QA"
echo "  test_recursos_ui: $resumo"
"$LAZBUILD" -B --cpu=x86_64 --os=win64 --ws=win32 planejador/tests/test_acompanhamento_ui.lpi > "$DIST/build-logs/test_acompanhamento_ui.log" 2>&1
"$WINE" "$DIST/tests/test_acompanhamento_ui.exe" > "$DIST/build-logs/test_acompanhamento_ui.run.log" 2>&1
resumo=$(tail -1 "$DIST/build-logs/test_acompanhamento_ui.run.log" | tr -d '\r')
echo "," >> "$QA"
printf '  {"test": "test_acompanhamento_ui", "passed": true, "summary": "%s"}' "$resumo" >> "$QA"
echo "  test_acompanhamento_ui: $resumo"
"$LAZBUILD" -B --cpu=x86_64 --os=win64 --ws=win32 planejador/tests/test_relatorios_sprint_ui.lpi > "$DIST/build-logs/test_relatorios_sprint_ui.log" 2>&1
"$WINE" "$DIST/tests/test_relatorios_sprint_ui.exe" > "$DIST/build-logs/test_relatorios_sprint_ui.run.log" 2>&1
resumo=$(tail -1 "$DIST/build-logs/test_relatorios_sprint_ui.run.log" | tr -d '\r')
echo "," >> "$QA"
printf '  {"test": "test_relatorios_sprint_ui", "passed": true, "summary": "%s"}' "$resumo" >> "$QA"
echo "  test_relatorios_sprint_ui: $resumo"
mkdir -p "$DIST/tests/workflow-units"
"$FPC_BIN" -Px86_64 -Twin64 -Mobjfpc -Sh -Fu"$ROOT/shared" -FU"$DIST/tests/workflow-units" -o"$DIST/tests/test_workflow.exe" shared/tests/test_workflow.lpr > "$DIST/build-logs/test_workflow.log" 2>&1
"$WINE" "$DIST/tests/test_workflow.exe" > "$DIST/build-logs/test_workflow.run.log" 2>&1
resumo=$(tail -1 "$DIST/build-logs/test_workflow.run.log" | tr -d '\r')
echo "," >> "$QA"
printf '  {"test": "test_workflow", "passed": true, "summary": "%s"}' "$resumo" >> "$QA"
echo "  test_workflow: $resumo"
echo "]" >> "$QA"
cp "$QA" "$APP/qa-tests.json"

# documentacao, exemplos e licencas
mkdir -p "$APP/documentation/docs" "$APP/exemplos" "$APP/licencas"
mkdir -p "$APP/documentation/libraries"
cp libraries/README.md "$APP/documentation/libraries/"
cp README.md "$APP/documentation/"
cp docs/*.md "$APP/documentation/docs/"
cp planejador/README.md "$APP/documentation/Planejador_README.md"
cp cad2d/README.md "$APP/documentation/CAD2D_README.md"
cp planejador/examples/*.plan.json "$APP/exemplos/"
cp planejador/examples/*.html planejador/examples/*.csv "$APP/exemplos/"
cp cad2d/examples/*.eacad "$APP/exemplos/"
mkdir -p "$APP/bibliotecas"
cp libraries/catalogo_2d.json "$APP/bibliotecas/"
cp third_party/chatgpt/LICENSE "$APP/licencas/CHATGPT_LICENSE.txt"

CLEAN=--require-clean; [ "$ALLOW_DIRTY" = "--allow-dirty" ] && CLEAN=
python3 tools/release_manifest.py --app-dir "$APP" --version "$VERSION" --seq "$SEQ" \
  --version-include "$DIST/version.iss" $CLEAN
python3 installer/windows/prepare_images.py --version "$VERSION" --out "$DIST/installer-images"

NAME="setup_engenhariaarquitetura_$SEQ"
# caminho do Linux visto pelo Wine (unidade Z:), sem depender do winepath
ISS="Z:$(printf '%s' "$ROOT/installer/windows/engenhariaarquitetura.iss" | tr '/' '\\')"
"$WINE" "$ISCC" /Q "/dSetupSeq=$SEQ" "/dOutputExeName=$NAME" "$ISS"
cp "$DIST/$NAME.exe" "$BIN/"
cp "$DIST/$NAME.exe" setup/
HASH=$(sha256sum "$DIST/$NAME.exe" | cut -d' ' -f1)
{ [ -f setup/SHA256SUMS ] && grep -vF "  $NAME.exe" setup/SHA256SUMS | grep '\S' || true; echo "$HASH  $NAME.exe"; } > setup/SHA256SUMS.new
mv setup/SHA256SUMS.new setup/SHA256SUMS
cp "$APP/build-manifest.json" "setup/build-manifest-$SEQ.json"
cp "$APP/qa-tests.json" "setup/qa-tests-$SEQ.json"
echo "Setup gerado: bin/$NAME.exe"
