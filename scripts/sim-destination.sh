#!/usr/bin/env bash
# Imprime un destino de xcodebuild para un iPhone con el iOS más reciente que soporta
# el Xcode seleccionado (los runtimes más nuevos que el SDK no sirven para compilar).
# Sobrescríbelo con SIMULATOR_DESTINATION="platform=iOS Simulator,name=iPhone 17" si lo necesitas
# (p. ej. para reproducir un fallo en un iOS concreto; FuelMap soporta iOS 17+).
set -euo pipefail

if [[ -n "${SIMULATOR_DESTINATION:-}" ]]; then
  echo "$SIMULATOR_DESTINATION"
  exit 0
fi

if ! xcrun --find simctl >/dev/null 2>&1; then
  {
    echo "❌ No se encuentra simctl: xcode-select apunta a $(xcode-select -p 2>/dev/null || echo '(nada)')."
    echo "   Selecciona Xcode completo y vuelve a intentarlo:"
    echo "     sudo xcode-select -s /Applications/Xcode.app"
    echo "     sudo xcodebuild -license accept && xcodebuild -runFirstLaunch"
  } >&2
  exit 1
fi

SDK_VERSION="$(xcrun --sdk iphonesimulator --show-sdk-version)"

xcrun simctl list devices available -j | /usr/bin/python3 -c '
import json, re, sys

sdk = tuple(int(part) for part in sys.argv[1].split(".")[:2])
devices = json.load(sys.stdin)["devices"]

def version(runtime):
    match = re.search(r"iOS-(\d+)-(\d+)", runtime)
    return (int(match.group(1)), int(match.group(2))) if match else (0, 0)

runtimes = [r for r in devices if ".iOS-" in r and version(r) <= sdk]
for runtime in sorted(runtimes, key=version, reverse=True):
    phones = [d for d in devices[runtime] if d["name"].startswith("iPhone")]
    if phones:
        udid = phones[0]["udid"]
        print("platform=iOS Simulator,id=" + udid)
        sys.exit(0)

sys.exit(
    "No hay simuladores de iPhone con iOS <= %s (el SDK de tu Xcode). "
    "Instala el runtime con: xcodebuild -downloadPlatform iOS" % sys.argv[1]
)
' "$SDK_VERSION"
