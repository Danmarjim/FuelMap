---
name: verify-app
description: Compila FuelMap, la lanza en el simulador de iOS con una ubicación simulada, recorre las pantallas afectadas y guarda capturas como prueba. Úsala antes de dar por terminado cualquier cambio de UI o de flujo.
---

# Verificar la app en el simulador

El objetivo es demostrar con evidencia que el cambio funciona, no suponerlo.

## 1. Tests y build

```bash
scripts/test.sh
```

Si falla, arregla antes de seguir. No continúes con la verificación visual sobre un build roto.
`scripts/test.sh` ya regenera `FuelMap.xcodeproj` con XcodeGen.

## 2. Lanza la app

El panel de simulador de Claude Desktop no funciona con Xcode 27: hazlo por línea de comandos.

```bash
DEST="$(scripts/sim-destination.sh)"
UDID="${DEST##*id=}"
xcrun simctl boot "$UDID" 2>/dev/null || true
xcodebuild build -project FuelMap.xcodeproj -scheme FuelMap \
  -destination "$DEST" -derivedDataPath build/DerivedData \
  -clonedSourcePackagesDirPath .build/spm \
  -skipMacroValidation -skipPackagePluginValidation -quiet
xcrun simctl install "$UDID" build/DerivedData/Build/Products/Debug-iphonesimulator/FuelMap.app

# Ubicación: concede el permiso y sitúa el simulador en Roma (hay estaciones reales alrededor).
xcrun simctl privacy "$UDID" grant location com.danmarjim.fuelmap
xcrun simctl location "$UDID" set 41.9028,12.4964

xcrun simctl launch "$UDID" com.danmarjim.fuelmap
```

Variantes según lo que cambiaste:

- **Onboarding**: se muestra solo en el primer lanzamiento. Para verlo, desinstala antes
  (`xcrun simctl uninstall "$UDID" com.danmarjim.fuelmap`) y no concedas el permiso por `simctl privacy`:
  el paso 2 del onboarding es el que lo pide.
- **Saltar el onboarding** (cuando no es lo que verificas), tras instalar y antes de lanzar:
  `xcrun simctl spawn "$UDID" defaults write com.danmarjim.fuelmap hasCompletedOnboarding -bool YES`
- **Permiso de ubicación denegado** (tarjeta con blur + búsqueda manual):
  `xcrun simctl privacy "$UDID" revoke location com.danmarjim.fuelmap`
- **Idioma** (it es el idioma base; comprueba también es y en):
  `xcrun simctl launch "$UDID" com.danmarjim.fuelmap -AppleLanguages "(es)" -AppleLocale es_ES`

## 3. Recorre lo que has cambiado

- Llega a cada pantalla afectada por el cambio (mapa, lista, favoritos, detalle, filtros, ajustes,
  paywall, onboarding).
- Comprueba: estado de carga, estado vacío, estado con datos, error (si aplica), modo oscuro y
  Dynamic Type grande.
  - Modo oscuro: `xcrun simctl ui "$UDID" appearance dark`
  - Texto grande: `xcrun simctl ui "$UDID" content_size extra-extra-large`
- Captura cada estado:

```bash
mkdir -p build/screenshots
xcrun simctl io "$UDID" screenshot build/screenshots/<pantalla>-<estado>.png
```

Mira tú mismo cada captura antes de adjuntarla. Si algo se ve cortado, solapado o ilegible, es un bug.
Presta atención al banner de AdMob: debe quedar fuera del área del mapa.

## 4. Límites conocidos

- Los datos vienen de Supabase en producción (lectura): lo que ves depende del último sync del MIMIT.
- En Debug el banner es de prueba de Google ("Test Ad"); los IDs reales solo van en Release.
- **Compras**: `simctl launch` no carga `FuelMap.storekit`; esa configuración solo se aplica al
  ejecutar desde Xcode (scheme `FuelMap` → Run). El flujo de compra del paywall no se puede verificar
  con esta skill: dilo en el PR.
- Consentimiento UMP/ATT: el formulario depende de la configuración de la cuenta AdMob y de la región;
  no lo des por verificado si no lo has visto.

## 5. Informa

En el PR (o en tu respuesta), incluye:

- Qué has verificado y cómo.
- Las capturas.
- Qué no has podido verificar y por qué.

Restaura el simulador al terminar: `xcrun simctl ui "$UDID" appearance light`,
`xcrun simctl ui "$UDID" content_size large` y `xcrun simctl location "$UDID" clear`.
