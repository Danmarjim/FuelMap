# FuelMap

App iOS nativa que muestra gasolineras italianas y sus precios de carburante sobre un mapa, con los
datos abiertos oficiales del MIMIT. Gratis con anuncios y pago único para quitarlos. Italia primero,
escalable a otros países.

Este fichero es el contrato de trabajo para cualquier agente que toque el repo. Si algo de aquí choca
con una petición concreta, pregunta antes de saltártelo.

## Qué es esta app

Lee `docs/PRD.md` antes de empezar cualquier tarea de producto. Es la fuente de verdad del alcance;
si una tarea no encaja en el PRD, dilo en vez de improvisar.

Contexto técnico (léelo cuando lo necesites, no lo dupliques aquí):

- `.claude/SYSTEM_MAP.md` — mapa de módulos y ficheros.
- `.claude/decisions/ADR-*.md` — decisiones de arquitectura (congeladas).
- `.claude/rfc/RFC-001-fuelmap-architecture.md` — diseño técnico original (esquema, RPC, contratos).
- `.claude/PHASE_LOG.md`, `.claude/plan.md`, `.claude/issues/`, `.claude/prd/PRD-001-fuelmap.md` —
  historial del flujo anterior. Consúltalos, pero el estado de trabajo vive ahora en GitHub Issues.

## Flujo de trabajo y puertas humanas

Dani coordina; GitHub Issues es el estado compartido entre sesiones. No te saltes ninguna puerta.

1. **Spec**: añade lo nuevo a "Siguientes funcionalidades" de `docs/PRD.md` con `Estado: Borrador`.
   ⛔ PUERTA 1: no crees tareas ni escribas código hasta que Dani cambie el estado a `Aprobado`.
2. **Tareas**: con el PRD aprobado, skill `spec-to-tasks` → issues con etiqueta `local` o `cloud`.
3. **Implementación**: una sesión por issue, una rama, un PR.
   - `local` (UI, simulador, build de la app): solo en el Mac de Dani.
   - `cloud` (docs, lógica pura, `backend/sync`, metadatos): puede hacerse en la nube.
   - Si estás en la nube y el issue es `local`, no lo intentes: dilo y para.
   ⛔ PUERTA 2: el merge lo hace Dani.
4. **Probar**: Dani instala la app en su iPhone desde Xcode.
   ⛔ PUERTA 3: no archives, no subas a TestFlight ni a App Store Connect, no apliques migraciones en
   Supabase y no lances el workflow `Sync MIMIT` a mano salvo petición explícita.

Al terminar una sesión, comenta en el issue qué has hecho, el enlace al PR y lo que quede pendiente.
Si te falta algo (acceso, herramienta, dato), dilo exactamente y para; no lo simules.
Escribe a Dani en español. Código, nombres y commits en inglés; los comentarios y doc comments del
código existente están en español: sigue el idioma del fichero que tocas.

Entorno de Dani: MacBook Pro M4 con macOS 27 y Xcode 27 (`xcode-select` ya apunta a él, no hace falta
`DEVELOPER_DIR`). El panel de simulador de Claude Desktop no funciona con Xcode 27: verifica con
`simctl` (skill `verify-app`).

## Stack

- iOS 17+, solo iPhone y en vertical, SwiftUI + MapKit (`Map`), Swift 6 con
  `SWIFT_STRICT_CONCURRENCY: complete`.
- Arquitectura TCA (`ComposableArchitecture`). Ver ADR-002. No propongas MVVM/MV.
- Proyecto generado con **XcodeGen**: `project.yml` es la fuente de verdad. `FuelMap.xcodeproj` y
  `FuelMap/Info.plist` no se commitean (están en `.gitignore`). Tras añadir, mover o borrar ficheros,
  o tocar `project.yml`: `xcodegen generate`.
- Un target de app (`FuelMap`) y uno de tests (`FuelMapTests`), un scheme (`FuelMap`). No hay paquetes
  locales.
- Dependencias SPM: TCA, Supabase (`supabase-swift`), Google Mobile Ads y Google UMP. Nada más sin
  preguntar.
- Datos: Supabase (PostgreSQL + PostGIS) en solo lectura desde la app, alimentado por
  `.github/workflows/sync-mimit.yml` + `backend/sync` (Node 22). Sin backend propio (ADR-001).
- Persistencia local: SwiftData para favoritos (`FavoritesClient`, `@ModelActor`), `UserDefaults` para
  preferencias de app.
- Monetización: AdMob (banner) + StoreKit 2 directo, no consumible `com.danmarjim.fuelmap.premium.noads`
  (ADR-006). Sin analytics ni crash reporting.

## Restricciones cerradas (no propongas alternativas)

1. Sin backend propio: los datos vienen de Supabase, alimentado por el sync de GitHub Actions desde
   los CSV del MIMIT (licencia IODL 2.0, actualización diaria ~08:00).
2. Arquitectura TCA.
3. iOS 17+; Swift 6 con concurrencia estricta completa.
4. SwiftUI + MapKit nativo. UIKit solo en wrappers imprescindibles (p. ej. el banner de AdMob vía
   `UIViewRepresentable`).
5. Mercado inicial Italia; modelos y queries geo agnósticos al país.
6. El banner de AdMob va **fuera** del área del mapa.

## Reglas de código

- Una feature = carpeta en `FuelMap/Features/<Nombre>/` con `<Nombre>Feature.swift` (`@Reducer` con
  `@ObservableState State`, `Action`, `body`) y `<Nombre>View.swift`. Las extensiones de un reducer
  grande van en `<Nombre>Feature+<Tema>.swift` (ver `MapFeature+Loading.swift`).
- La composición entre features es con `Scope`, `@Presents` y acciones `delegate` hacia el padre.
  Las vistas observan el `Store`; nada de lógica en las vistas.
- Efectos y servicios externos solo vía `@Dependency` en `FuelMap/Core/` (`APIClient`,
  `LocationClient`, `GeocodingClient`, `FavoritesClient`, `PurchaseClient`, `AdClient`,
  `OnboardingStorage`). Cada cliente es un `struct` de closures `@Sendable` con `liveValue`,
  `previewValue` (mock) y `testValue` (sin implementar o neutro). Prohibido llamar a Supabase, StoreKit,
  AdMob o CoreLocation directamente desde una feature.
- Las features dependen de `Core`, nunca al revés. Los DTO viven en `Core/Network/DTOs`, son
  `Decodable` (nunca `Codable`) y se mapean a modelos de dominio en el límite del `APIClient`
  (`StationMapper`). Los modelos de dominio no conocen Supabase.
- Errores tipados por cliente (`APIError`, `LocationError`, `GeocodingError`, `PurchaseError`).
  Nunca `Error` crudo hacia el reducer.
- Precios en `Decimal` con 3 decimales; distingue siempre `isSelf` (self-service / servito). Formatea
  con `Decimal.fuelPriceLabel`, no a mano.
- Las coordenadas del MIMIT pueden faltar: valida con `Coordinate.validated()`.
- Colores, espaciados, radios, elevación y tipografía salen de `FuelMap/DesignSystem/` y de los Color
  sets de `Assets.xcassets/Colors` (ADR-005). Nada de números mágicos ni colores literales.
- Textos visibles en **italiano** como clave (`developmentLanguage: it`); traducciones es/en en
  `FuelMap/Resources/Localizable.xcstrings`. Todo texto nuevo llega con sus tres idiomas.
- Accesibilidad: Dynamic Type, `accessibilityLabel`/`Value`/`Hint` en los controles, Reduce Motion en
  animaciones.
- `#Preview` en cada vista nueva (uno por estado relevante).
- Cabecera en cada fichero Swift y `// MARK: -` para secciones:

  ```swift
  //
  //  FileName.swift
  //  FuelMap
  //
  //  Created on DD/MM/YYYY.
  //
  ```

- Configuración por entorno (IDs de AdMob, entitlements de simulador) solo en `project.yml`, nunca con
  `#if DEBUG` en código.

## Tests

- Swift Testing (`import Testing`, `@Test("descripción")`, `#expect`), un `struct` por suite
  (`@MainActor` si usa `TestStore`). Un fichero por feature o cliente en `FuelMapTests/`.
- Reducers con `TestStore` y dependencias sobrescritas en su closure `withDependencies:`. Nunca red real, StoreKit
  real ni ubicación real en tests (las compras se prueban con `SKTestSession` sobre `FuelMap.storekit`).
- Lógica pura (clustering, tiers, mapper, ordenación) con tests directos, sin store.
- `backend/sync`: tests del parser con `node --test` (`sync.test.mjs`).
- Quirk: `FuelMapTests` depende solo del host app. No le añadas el paquete TCA en `project.yml` o
  aparecen *undefined symbols* de `CasePathsCore`/`PerceptionCore`.

## Cómo verificar tu trabajo (obligatorio antes de dar algo por terminado)

1. `scripts/test.sh` → regenera el proyecto, ejecuta `FuelMapTests` en simulador (compila la app como
   host) y los tests de `backend/sync`. Tiene que pasar.
2. `swiftlint lint --strict FuelMap FuelMapTests` sin errores (un hook lo ejecuta en cada fichero que
   editas). Pasa siempre las rutas: `.swiftlint.yml` no limita `included` y `.build/` tiene Swift de
   terceros.
3. Si cambiaste UI: ejecuta la skill `verify-app` y adjunta capturas en el PR.

Builds headless: las macros de TCA necesitan `-skipMacroValidation -skipPackagePluginValidation` en
`xcodebuild` (ya incluidos en los scripts).

Si no puedes ejecutar algo (no hay simulador, falta una herramienta), dilo explícitamente en el PR.
No digas que funciona si no lo has comprobado.

## Git y PRs

- Nunca trabajes sobre `main`. Rama `feat/…`, `fix/…` o `chore/…` por tarea.
- 1 tarea = 1 PR pequeño. Título en imperativo. Descripción: qué, por qué, cómo se ha verificado.
- Rellena `.github/pull_request_template.md`.
- Si añades o mueves ficheros, actualiza `.claude/SYSTEM_MAP.md` en el mismo PR. Una decisión de
  arquitectura nueva va en un ADR nuevo (`.claude/decisions/ADR-NNN-*.md`); los existentes no se editan.
- No hagas merge tú. No hagas force-push. No toques `main` directamente.

## Lo que NO debes hacer sin preguntar

- Archivar, subir builds a TestFlight o enviar a revisión: eso lo hace Dani.
- Aplicar migraciones en Supabase, ejecutar `backend/sync/sync.mjs` contra producción o lanzar
  `Sync MIMIT` con `workflow_dispatch`. Las migraciones nuevas son ficheros `NNNN_*.sql` correlativos;
  nunca edites una ya aplicada.
- Cambiar workflows de `.github/`, la firma (`DEVELOPMENT_TEAM`, entitlements), el bundle identifier,
  los IDs de AdMob o el ID del producto de StoreKit.
- Añadir dependencias de terceros (SPM o npm).
- Tocar `docs/PRD.md` salvo para marcar algo como hecho.

## Mapa del repo

```
FuelMap/                  código de la app
  App/                    @main, AppFeature (reducer raíz) y AppView
  Features/               Map, StationDetail, Filters, Onboarding, Premium, Settings
  Core/                   clientes @Dependency (Network, Location, Persistence, Purchases, Ads,
                          Onboarding), modelos de dominio y extensiones de Foundation
  DesignSystem/           tokens (Spacing, Radius, Elevation, Typography)
  Resources/              Localizable.xcstrings (it/es/en)
FuelMapTests/             Swift Testing + TestStore
FuelMap.storekit          configuración local de StoreKit (scheme Run y tests)
project.yml               spec de XcodeGen (targets, paquetes, Info.plist, firma)
backend/                  migraciones SQL de Supabase y sync MIMIT (Node)
docs/                     PRD y política de privacidad (GitHub Pages)
.github/workflows/        ci (PRs y main), sync-mimit (cron diario → Supabase)
.claude/                  permisos, hooks, skills, SYSTEM_MAP, ADRs, RFC e historial
scripts/                  test, sim-destination
```
