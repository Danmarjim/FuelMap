# Plan: RESTYLE-001 — Restyle visual completo (Design System "Bold & Energetic", azul)

> **Objetivo (Goal).** Reescribir la capa visual de FuelMap aplicando íntegramente el
> design system entregado por Claude Design (`Design_System/`): personalidad *bold &
> energetic*, ancla **azure `#0091FF`**, paridad claro/oscuro, tokens semánticos
> mapeados 1:1 a un asset catalog de SwiftUI, y tiers de precio **a prueba de
> daltonismo** (color + forma + etiqueta). Nada se difiere: entra también el sistema
> de tiers, los estados (loading/empty/error con skeletons), Reduce Motion y el
> **control de capas del mapa** (tipo de mapa).

> **Fuente de verdad.** `Design_System/assets/tokens.css` (valores hex claro/oscuro,
> spacing, radios, elevación, tipografía) + `Design_System/assets/app.css` (specs
> exactas por componente) + `Design_System/FuelMap Design System.html` (mockups de
> las 7 pantallas y estados, claro/oscuro). **No es solo recolorear**: introduce UI
> funcional nueva (formas+etiquetas de tier, cluster con "da X", fresh-pill, skeletons,
> control de capas).

---

## Contexto (Context)

- App ya funcional (FM-1…FM-19 + clustering + UX enrichment). Este plan toca **solo
  la capa de presentación**; sin cambios de arquitectura, dominio, red ni datos.
- TCA + SwiftUI + MapKit, iOS 17+, Swift 6 strict concurrency. Mantener todo testeable.
- Ya existe `FuelMap/Assets.xcassets` con `AppIcon` y los 6 logos de marca
  (`brand-eni`…). Se amplía con los **Color sets semánticos**.
- Decisión UX confirmada por el usuario: **adoptar forma (▲ ● ▼) + etiqueta
  (BASSO/MEDIO/ALTO)** en los tiers, en pin, filas y detalle.

## Fuera de alcance (Out of scope)

- FM-14 (App Store prep) — sigue pendiente como trabajo de producto independiente.
- Feature premium / calculadora de viaje (análisis hecho, sin construir).
- CarPlay (investigado; post-lanzamiento y sujeto a entitlement de Apple).
- Cambios de lógica de negocio, RPCs o sync.

---

## Mapa diseño → tokens → asset catalog

Crear **Color sets semánticos** (nombres = custom properties de `tokens.css`, mapeo 1:1).
Apariencias **Any + Dark** salvo donde se indique *valor único*.

| Grupo | Color sets | Nota |
|---|---|---|
| Brand | `brandPrimary` `brandPrimaryFill` `brandPrimaryPressed` `brandTint` `brandSurface` `onBrand` | onBrand = blanco |
| Surfaces | `surface` `surfaceElevated` `surfaceSecondary` `surfaceTertiary` `surfaceScrim` | scrim con alpha |
| Text | `textPrimary` `textSecondary` `textTertiary` `textOnTier` | |
| Lines | `separator` `separatorStrong` `hairline` | hairline con alpha |
| **Tiers (fills)** | `priceCheap` `priceMid` `priceHigh` | **VALOR ÚNICO** (idénticos claro/oscuro) |
| Tier ink | `priceCheapInk` `priceMidInk` `priceHighInk` | Any+Dark (brillan en oscuro) |
| Tier surface | `priceCheapSurface` `priceMidSurface` `priceHighSurface` | Any+Dark |
| Tier stroke | `tierStroke` | blanco (claro) / `#0B0E14` (oscuro) |
| Functional | `success` `warning` `warningSurface` `error` `errorSurface` | |
| Accent | `cheapestGold` (`#F5B301`) | corona/anillo "más barata" |

**`DesignTokens.swift`** (no-color):
- `Spacing`: 2/4/8/12/16/20/24/32/40/48 (grid 4pt).
- `Radius`: sm 8 · md 12 · lg 16 · xl 20 · pill (capsule).
- `Elevation` (ViewModifiers): `e1 e2 e3 ePin ePinSelected eSheet` (sombra + hairline; en
  oscuro sombra más profunda + ring claro 1px — aproximar las multi-sombra del CSS).
- `Typography`: roles SF Pro (largeTitle 34/bold … caption2 11/medium) mapeados a text
  styles para Dynamic Type; precio/números con `.monospacedDigit()`; **pin price con
  Dynamic Type capada** (no crece más de Large para no desbordar sobre el mapa).

---

## Fases de ejecución

### Fase R0 — Fundación (no destructiva) ✅
**Meta:** tokens disponibles sin tocar ninguna vista; build verde, app idéntica.
- [x] Reubicar `Design_System/` → `.claude/design/` (referencia versionada fuera del árbol de fuentes).
- [x] Crear los 34 **Color sets** en `Assets.xcassets/Colors` (claro/oscuro; tiers fill = valor único). Símbolos `Color(.brandPrimary)` confirmados (35 generados).
- [x] `DesignSystem/Spacing.swift`, `Radius.swift`, `Elevation.swift` (modifier `.elevation(_:)`), `Typography.swift` (Font roles + helpers de precio) + `TokenGallery` (#Preview).
- [x] Build + lint verdes; 51 tests OK. `.swiftlint.yml` permite tokens cortos.
- **Verificación:** ✅ compila, app idéntica (aún no migrado).

### Fase R1 — Sistema de tiers (modelo base del resto) ✅
**Meta:** `PriceTier` expone color+forma+etiqueta; cimiento de pin/filas/detalle.
- [x] `PriceTier`: `fill`, `ink`, `surface` (tokens), `symbolName` (▲ `arrowtriangle.up.fill` / ● `circle.fill` / ▼ `arrowtriangle.down.fill`), `label` localizada + alias `color`.
- [x] Strings de tier (Basso/Medio/Alto) en `Localizable.xcstrings` (it/es/en).
- [x] Tests del mapeo de tier (forma+etiqueta distintas por nivel). 52 tests OK.
- **Verificación:** ✅ tests verdes.

### Fase R2 — Mapa: pins + chrome + capas
**Meta:** el mapa con el lenguaje visual nuevo, legible sobre cualquier tile.
- [ ] `StationPin.swift`: cápsula (fill de tier) con badge 28pt (logo/monograma; ★ dorada si más barata; `fuelpump.fill` si bianca), **forma de tier**, precio tabular, cola + halo `tierStroke` + `ePin`. Estados: **seleccionado** (42pt, chip de combustible, `ePinSelected`), **más barata** (badge dorado + anillo `cheapestGold` + corona), **dot** (zoom out).
- [ ] `ClusterPin.swift`: burbuja `surfaceElevated` con borde del tier del más barato + cápsula `da X €/L` del mismo tier; halo + sombra.
- [ ] `BrandBadge.swift`: alinear al spec de chip (rounded rect `surfaceElevated`, hairline, alturas 30/44pt `lg`); conservar `logoBackground` por marca (navy Eni).
- [ ] `MapView.swift` chrome: status banner (overlay) restyle (`surfaceElevated`/`e2`; variantes loading/error/empty con `errorSurface`); float controls 44pt (`floatctl`: locate, **layers**, favoritos); entrada a lista (`pillbtn`/`floatctl`).
- [ ] **Control de capas (NUEVO):** `mapStyle` en `MapFeature.State` (standard/hybrid/imagery) + `.mapStyle(...)` en `MapView`; el `floatctl` de capas abre menú/cicla. Acción + reducer + test.
- **Verificación:** build/lint; capturas mapa claro/oscuro (pins, cluster, seleccionado, más barata, banner, capas).

### Fase R3 — Barra de filtros
**Meta:** filtros con el nuevo estilo, ≥44pt, sin truncar labels.
- [ ] `FiltersView.swift`: segmented scrollable de combustible (`seg`/`seg__item`, activo `surfaceElevated`+`brandPrimary`), toggle Self (switch `success`), stepper de radio, sort pills (Prezzo/Distanza). Fondo de barra con degradado a `surface`.
- **Verificación:** build/lint; capturas filtros claro/oscuro; Dynamic Type grande sin romper.

### Fase R4 — Sheets: lista, favoritos, detalle
**Meta:** las 3 hojas con el vocabulario de filas/precios nuevo.
- [ ] Chrome de sheet: grab, head (título + count + `iconbtn` cerrar), `sortbar` con `sortpill`.
- [ ] `StationListView.swift`: fila `lrow` (chip, nombre, meta con `best-flag` + distancia, precio tabular + unidad, `tier-tag` forma+palabra+bg tintado); separador con sangría.
- [ ] `FavoritesView.swift`: misma fila + `star-toggle` (oro).
- [ ] `StationDetailView.swift`: hero (chip `lg`, nombre, dirección, `star-toggle` `iconbtn`), section header + `fresh-pill` (ok/stale con `warningSurface`), filas `prow` (combustible + badge **Filtro** en el seleccionado, Self/Servito, mejor precio en `priceCheapInk`, fila activa `brandSurface` + barra de acento izq.), `detail__rowline` dirección, **CTA `Indicazioni`** (`brandPrimaryFill`, 52pt) → selector de navegación.
- **Verificación:** build/lint; capturas de lista/favoritos/detalle claro/oscuro.

### Fase R5 — Estados, movimiento y accesibilidad
**Meta:** loading/empty/error consistentes + a11y.
- [ ] Skeletons (`sk` shimmer) en carga de lista; `state-block` (em-ic, título, texto, pill de acción) para empty/error; banner de estado en mapa.
- [ ] **Reduce Motion**: spinner lento, shimmer off, pins colocan (sin bounce), sheets cross-fade.
- [ ] **Dynamic Type**: capada en pin; escala completa en sheets/listas (reflow multilínea, sin truncar). **VoiceOver**: labels con tier (palabra), rango y precio.
- [ ] Ad banner: paridad de estilo (`surfaceSecondary` + separador superior).
- **Verificación:** build/lint; pase a11y (Dynamic Type, Reduce Motion, VoiceOver) y contraste AA.

### Fase R6 — QA, docs y review
- [ ] Suite completa de tests + lint; capturas claro/oscuro de las 7 pantallas.
- [ ] Actualizar `SYSTEM_MAP.md` (nuevos `DesignSystem/*`, color sets) y `PHASE_LOG.md`.
- [ ] **Evaluación multi-agente** del restyle (architect/developer/qa/reviewer) — funde aquí la "valoración final" acordada.
- [ ] ADR del design system (tokens semánticos, tiers daltónico-seguros, fills mode-independent).

---

## Verificación global (Definition of Done)

- Build + lint limpios; **todos los tests verdes** (incluidos los nuevos de tier y mapStyle).
- Paridad **claro/oscuro** en las 7 pantallas y todos los estados.
- Tiers distinguibles por **color + forma + etiqueta**; AA de contraste en texto/UI esencial.
- Sin regresiones funcionales (filtros, detalle, favoritos, navegación, clustering, frescura).
- `Design_System` versionado en `.claude/design/`; tokens 1:1 con el asset catalog.

---

## Riesgos / decisiones

- **Sombras multi-capa del CSS** no traducen literal a SwiftUI → aproximar con 1-2
  `.shadow` + overlay de hairline; validar sobre el mapa.
- **Pin más ancho** (badge+forma+precio) sobre el mapa → vigilar footprint y solape; la
  Dynamic Type capada del precio lo protege.
- **Tiers fill mode-independent**: crear esos Color sets con valor único (no Any/Dark) o
  el blanco del pin perdería contraste en un modo.
- **Control de capas**: feature nueva — mantener mínima (toggle de `mapStyle`), sin tocar
  el flujo de carga.

---

## Estado previo del proyecto (referencia — no parte del restyle)

**Backlog FM (todo hecho salvo FM-14):** FM-1…FM-13, FM-15…FM-19 ✅; FM-2/FM-3 desplegados;
APIClient real; 49 tests iOS + 3 backend. Evaluación multi-agente 2026-06-05 aplicada
(`reviews/2026-06-05-evaluacion-completa.md`). UX posterior: lista→detalle con recentrado,
detalle por variante real (`fuel_raw`, migración 0003), recentrado al pulsar pin, banner de
estado como overlay, **logos reales de 6 marcas** en el detalle.

**Pendiente de producto (independiente del restyle):**
- **FM-14** (App Store): IDs AdMob reales + `SKAdNetworkItems`, `PrivacyInfo.xcprivacy`,
  l10n del Info.plist (es/en), atribución IODL 2.0, prep TestFlight.
- **Acción del usuario:** aceptar el PLA en developer.apple.com (firma device/TestFlight).

**Deuda no bloqueante:** carga inicial supeditada al permiso de ubicación; pulido a11y
menor (VoiceOver dirección/marca, conservar zoom al recentrar, `MapView.camera` desde
`store.center/span`); IP es logo raster (vector puro pendiente si aparece).

---

## Convenciones del workflow

- Decisiones congeladas → `decisions/ADR-XXX-*.md`. Historia → `PHASE_LOG.md`.
- Mapa de código → `SYSTEM_MAP.md` (actualizar al cerrar fase).
- Al cerrar RESTYLE-001 → `/close-phase` mueve este `plan.md` a `plan-archive/`.
