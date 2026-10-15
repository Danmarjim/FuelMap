#!/usr/bin/env bash
# Regenera FuelMap.xcodeproj con XcodeGen, ejecuta FuelMapTests (Swift Testing) en un simulador de
# iPhone y los tests del parser del sync MIMIT (backend/sync). `xcodebuild test` compila la app como
# host de los tests, así que también valida que la app compila.
# Es la verificación mínima que debe pasar antes de abrir un PR (y la que ejecuta CI).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="FuelMap"
SCHEME="FuelMap"
DEST="$("$ROOT/scripts/sim-destination.sh")"
SPM_DIR="$ROOT/.build/spm"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "❌ No se encuentra xcodegen (el .xcodeproj se genera desde project.yml). Instálalo: brew install xcodegen" >&2
  exit 1
fi

echo "▶ Destino: $DEST"

# El .xcodeproj no se commitea: se regenera siempre para que el build refleje project.yml.
echo "▶ Generando ${APP_NAME}.xcodeproj desde project.yml"
(cd "$ROOT" && xcodegen generate --quiet)

RESULT_BUNDLE="$ROOT/.build/test-results/${APP_NAME}Tests.xcresult"
rm -rf "$RESULT_BUNDLE"
mkdir -p "$(dirname "$RESULT_BUNDLE")"

# -skipMacroValidation / -skipPackagePluginValidation: las macros de TCA no se pueden aprobar en un
# build headless (sin ellas, xcodebuild falla pidiendo confiar en el paquete).
echo "▶ Tests de ${APP_NAME}Tests (scheme: $SCHEME)"
xcodebuild test \
  -project "$ROOT/${APP_NAME}.xcodeproj" \
  -scheme "$SCHEME" \
  -destination "$DEST" \
  -clonedSourcePackagesDirPath "$SPM_DIR" \
  -resultBundlePath "$RESULT_BUNDLE" \
  -skipMacroValidation \
  -skipPackagePluginValidation \
  -quiet

# Con -quiet no se ve cuántos tests se ejecutan. Lo leemos del result bundle y fallamos si son 0,
# para detectar un scheme que haya dejado de incluir el target de test.
SUMMARY="$(xcrun xcresulttool get test-results summary --path "$RESULT_BUNDLE" --format json 2>/dev/null || true)"
if [[ -n "$SUMMARY" ]]; then
  printf '%s' "$SUMMARY" | /usr/bin/python3 -c '
import json, sys
s = json.load(sys.stdin)
total = s.get("totalTestCount", 0)
print("  %d tests: %d pasados, %d fallidos, %d omitidos" % (
    total, s.get("passedTests", 0), s.get("failedTests", 0), s.get("skippedTests", 0)))
if total == 0:
    sys.exit("❌ No se ha ejecutado ningún test: revisa que el scheme incluya FuelMapTests en project.yml.")
'
else
  echo "  (no he podido leer el resumen de tests; revisa $RESULT_BUNDLE)"
fi

# Los tests del parser no tienen dependencias npm (solo node:test), así que no hace falta npm install.
echo "▶ Tests del sync MIMIT (backend/sync)"
if command -v node >/dev/null 2>&1; then
  (cd "$ROOT/backend/sync" && node --test)
else
  echo "❌ No se encuentra node: no puedo ejecutar los tests de backend/sync. Instálalo o ejecútalos en CI." >&2
  exit 1
fi

echo "✅ Tests correctos"
