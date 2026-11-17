#!/bin/bash
# Atualiza a pasta ventrya-api/ com a versão mais recente do repo da Vitória
# (VitoriaMaglio/VentryaAPI), preservando os testes unitários do DevOps.
# Rodar na raiz deste repositório (Git Bash, WSL ou Cloud Shell):  bash scripts/sync-source.sh
set -e
TMP=$(mktemp -d)
git clone --depth 1 https://github.com/VitoriaMaglio/VentryaAPI.git "$TMP/src"

# guarda os testes do DevOps
cp -r ventrya-api/src/test/java/com/ventrya/api/unit "$TMP/unit-backup"

rm -rf ventrya-api
cp -r "$TMP/src/ventrya-api" ventrya-api
mkdir -p ventrya-api/src/test/java/com/ventrya/api
cp -r "$TMP/unit-backup" ventrya-api/src/test/java/com/ventrya/api/unit
rm -rf "$TMP"

echo "Código sincronizado. Revise com 'git status' e faça commit numa branch nova."
