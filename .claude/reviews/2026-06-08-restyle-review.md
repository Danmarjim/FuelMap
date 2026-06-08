# RESTYLE-001 — Review final del restyle visual

**Reviewer:** ios-reviewer · **Fecha:** 2026-06-08
**Alcance:** `0fb77cd..HEAD` (R0–R5) · TCA + SwiftUI, iOS 17+, Swift 6 strict concurrency
**Fuente de verdad:** `.claude/design/` (tokens.css, app.css, mockups HTML)

---

## Paso 0 — `/simplify` (obligatorio): duplicación y simplificación

El skill `/simplify` está orientado a *aplicar* fixes; aquí se ejecuta en modo
análisis (la consigna prohíbe tocar fuente/tests). Hallazgos de reuso/simplificación:

1. **`SortPill` (SheetComponents.swift:39) y `sortPill(_:)` (FiltersView.swift:141)
   son el mismo componente duplicado.** Misma estructura (icono condicional + label +
   cápsula activa con borde `brandPrimary` 0.3). Única diferencia real: `frame(height:)`
   34 vs 44. **Fix:** parametrizar `SortPill` con `height` y reutilizarlo en `FiltersView`,
   borrando `sortPill(_:)`. Elimina ~20 líneas y un punto de divergencia de estilo.

2. **`separator` está triplicado** con cuerpo idéntico
   (`Rectangle().fill(Color(.separator)).frame(height: 1).padding(.leading, 60)`):
   `StationListView.swift:65`, `FavoritesView.swift:43`, y variantes inline en
   `StationDetailView.swift:136` (`.padding(.horizontal, s5)`) y `:195`. **Fix:** un
   `InsetSeparator(leading:)` en `SheetComponents.swift`.

3. **El cómputo de `PriceTiers` se repite.** Vive en `MapFeature.State.priceTiers`
   (MapFeature.swift:42) y se recalcula a mano en `StationListView.tiers`
   (StationListView.swift:22). La lista recibe `stations` pero no los tiers; debería
   recibir el `PriceTiers` ya calculado del store para no recomputar terciles en cada
   render del sheet (ver Medio-2).

4. **VoiceOver del pin/fila ensambla strings casi idénticos** en
   `StationPin.accessibilityText` (StationPin.swift:136) y
   `StationListView.voiceOverLabel` (:94). No es crítico, pero un helper compartido
   `stationVoiceOverLabel(name:fuel:price:tier:isCheapest:)` evitaría que diverjan.

5. **`MapStyleModifier` (MapView.swift:215) es correcto** (los `some MapStyle` son tipos
   distintos por rama → el `ViewModifier` con `@ViewBuilder switch` es la forma idiomática).
   No simplificar a un único `.mapStyle(option.mapStyle)`: no compilaría. Bien resuelto.

---

## Hallazgos por severidad

### 🔴 Crítico

Ninguno. No hay data races, force-unwraps, retain cycles ni crashes. La capa TCA y la
concurrencia Swift 6 están correctas (ver notas positivas).

### 🟠 Alto

**A-1 · Doble unidad de moneda en la fila de lista.**
`FuelMap/Features/Map/SheetComponents.swift:242-243`
```swift
Text(price.fuelPriceLabel)            // -> "1,879 €"  (fuelPriceLabel ya añade " €")
Text("€/L").font(.fmCaption2)…        // -> "€/L"
```
Render real: **"1,879 € €/L"**. El diseño (`app.css .lrow__price`) quiere
`1,879` + unidad `€/L`. `fuelPriceLabel` (`Decimal+FuelPrice.swift:13`) concatena " €".
**Fix:** en la fila usar el número desnudo
(`price.formatted(.number.precision(.fractionLength(3)))`) y dejar `€/L` como unidad; o
añadir un `fuelPriceValue` sin símbolo al extension y usarlo aquí. Afecta a lista y
favoritos (vía `StationRow`).

**A-2 · `BestFlag` mode-independent rompe contraste/fidelidad en oscuro.**
`FuelMap/Features/Map/SheetComponents.swift:28-36` usa `Color(.goldInk)`. El asset
`goldInk` SÍ es adaptativo (B8860B claro / F5B301 oscuro) — correcto. **Pero** el diseño
(`app.css .best-flag`) usa además `letter-spacing 0.04em` y el icono a 12px; aquí el
texto es `.fmCaption2` (11pt, escala con Dynamic Type) sin `tracking`. Menor desviación
tipográfica; lo marco Alto solo por consistencia con `TierTag` que sí lleva
`textCase(.uppercase)`. **Fix:** añadir `.tracking(0.4)` y unificar tamaños con el spec.
(Si se prefiere, baja a Medio.)

**A-3 · `il più economico` y `Più basso` son strings hardcodeados sin clave estable.**
`StationPin.swift:140`, `StationListView.swift:98`, `SheetComponents.swift:33`.
Usan `String(localized: "il più economico")` con el literal italiano como clave. Ya
existen en `Localizable.xcstrings` (líneas 457, 660), así que funciona, pero "Più basso"
(BestFlag) y "il più economico" (VoiceOver) son **conceptos distintos con riesgo de
divergencia** y el primero se repite. No bloquea, pero conviene `comment:` para el
traductor (es/en) como en `PriceTier.label`. **Fix:** añadir `comment:` y considerar
constantes. Verificar que it/es/en están todas traducidas (no solo la clave it).

### 🟡 Medio

**M-1 · `FreshnessPill` recalcula "stale" con `Date.now` en cada render y el umbral
está duplicado.**
`FuelMap/Features/Map/SheetComponents.swift:121`
```swift
private var stale: Bool { date < Date.now.addingTimeInterval(-2 * 24 * 3600) }
```
`Date.now` en un `body` no es determinista (cambia entre renders) y el umbral de 48h es
un número mágico que ya existe conceptualmente en el dominio de frescura. Para una pill
no es grave, pero rompe `#Preview` reproducibles y testabilidad. **Fix:** inyectar el
"now" o exponer el cálculo de stale en el dominio (`FuelPrice`/util de frescura) y pasar
un `Bool`/enum a la pill.

**M-2 · La lista recomputa `PriceTiers` en vez de recibirlo del store.**
`StationListView.swift:22` construye `PriceTiers(prices:)` ordenando todos los precios en
cada render del sheet. El store ya lo tiene (`MapFeature.State.priceTiers`). Ordenar N
precios por cada update del sheet es trabajo evitable. **Fix:** pasar `tiers: PriceTiers`
como parámetro desde `MapView` (igual que `cheapestStationID`).

**M-3 · `availableNavApps` llama a `UIApplication.shared.canOpenURL` en `body`.**
`StationDetailView.swift:19-24`. Es un `computed var` consultado en `content(for:)`
(ConfirmationDialog) y en `requestDirections()`. `canOpenURL` no es gratis y se evalúa en
cada render del detalle. **Fix:** calcular una vez (`@State` poblado en `.onAppear`, o en
el reducer como dependencia). Menor, pero es I/O de UIKit en hot path de SwiftUI.

**M-4 · Elevación: el `e3`/`pinSelected` aproxima una sola sombra; falta el ring/hairline
en modo oscuro que el spec pide.**
`Elevation.swift:30-45` aplica un único `.shadow`. tokens.css define para oscuro
`0 0 0 0.5px rgba(255,255,255,0.06/0.08)` (ring claro de 1px) además de la sombra
profunda. El doc del enum dice "el hairline/ring se aplica aparte en cada componente",
pero **solo el pin/cluster lo aplican** (overlay `tierStroke`); las cards/banners
(`MapView.banner`, sheets) NO añaden ese ring en oscuro → sobre `surface` oscuro las
tarjetas elevadas pierden separación. **Fix:** o bien el `ElevationModifier` añade el
overlay de hairline en `.dark`, o documentar/forzar que cada superficie elevada lo ponga.
Recomendado: meterlo en el modifier (altitud correcta — un solo sitio).

**M-5 · `FreshnessPill` y `StationDetailView.latestUpdate` definen "frescura" en dos
sitios.** La pill decide stale a 48h; el detalle solo calcula `max(communicatedAt)`. Si
mañana cambia el umbral, hay que tocar dos archivos. Relacionado con M-1. **Fix:**
centralizar.

### 🔵 Bajo

**B-1 · `priceHighInk` claro == `priceHigh` fill (`#C62828`).** Es intencional (tokens.css
lo define así) pero significa que `TierTag.high` en claro usa texto rojo idéntico al fill
del pin; sobre `priceHighSurface` (#FBE9E9) el contraste es ~4.0:1 — pasa AA para texto
grande/bold (la tag es 10.5pt **bold**, borderline). Verificar con contraste real; si
falla, oscurecer el ink. Solo aplica a la tag, no al pin (pin usa blanco sobre fill, 5.2:1 OK).

**B-2 · `StationPin` tail "costura".** `tail` usa `.offset(y: -1)` y el halo se dibuja con
dos `DownTriangle` superpuestos (16x10 stroke + 12x7 fill). En el spec el tail es un
pseudo-elemento con `z-index: -1`; en SwiftUI el ZStack lo aproxima bien, pero a `@3x`
puede verse 1px de `tierStroke` asomando entre cápsula y cola. Validar en device retina.
No bloqueante. **Fix opcional:** solapar 1pt más la cola con la cápsula.

**B-3 · `BrandBadge` logo sobre chip en modo oscuro.** `content` (BrandBadge.swift:31-39)
pinta el logo sobre `brand.logoBackground` (blanco/navy). En modo oscuro un chip blanco
con logo dentro de una fila `surfaceElevated` (#1A1F29) es correcto y deseado (los logos
necesitan su fondo de marca), pero el `strokeBorder(Color(.separator))` (1px) sobre fondo
blanco en oscuro casi no se ve. Es un riesgo conocido del plan ("logos sobre chip en modo
oscuro"). Aceptable; verificar visualmente Eni (navy) y los raster.

**B-4 · `ClusterPin` borde fijo `tier.fill` 2.5px + halo `tierStroke` 2px con
`.padding(-2)`.** Correcto, pero el spec usa el tier del **más barato** para el borde de
la burbuja (`.cluster__bubble border: priceCheap`) — aquí se pasa `tier` desde
`MapView` que ya es `priceTiers.tier(for: cluster.cheapestPrice)`, así que es correcto.
Solo confirmo que no hay bug. ✓

**B-5 · `FiltersView.fuelSegment` Dynamic Type.** El segmentado usa `minHeight: 38` y
`.fmSubheadline`. Con Dynamic Type accesible (AX5) los labels de combustible pueden
truncar dentro del scroll horizontal. El pin sí capa Dynamic Type; los filtros no, pero
al ser scroll horizontal el desbordamiento es tolerable. Validar AX5.

### ⚪ Nit

- **N-1 · `Radius.pill = 999`** existe pero el código usa `Capsule()` en todos los sitios
  (correcto). El token queda muerto salvo doc. OK dejarlo documentado.
- **N-2 · `PriceTier.color` alias** (PriceTiers.swift:68) marcado "migran a `fill` en R2".
  R2 ya cerró; el alias ya no debería tener usos. **Fix:** `grep` y borrar si está huérfano.
- **N-3 · `StationPin.priceText` y `ClusterPin`** usan `"—"` como placeholder; consistente. OK.
- **N-4 · `Shimmer`** aplica `.blendMode(.overlay)` + `.mask(content)`; en modo oscuro el
  gradiente blanco a 0.5 puede ser sutil de más. Validar visualmente; no bloqueante.
- **N-5 · `mapControlChrome()` radius 14** hardcodeado en vez de un token (`Radius` no
  tiene 14; el spec `.floatctl` usa 14). Aceptable, pero documentar o añadir token.
- **N-6 · `SheetEmptyState`** usa `Spacing.s8` (32) de padding; el spec `.state-block`
  usa 40px. Desviación menor de spacing.

---

## Fidelidad al design system — resumen

| Área | Estado |
|---|---|
| Tokens (color sets 1:1 con tokens.css) | ✅ Verificado: tiers fill mode-independent, `tierStroke` blanco/navy, inks adaptativos, scrim/hairline con alpha correcto |
| Tiers daltónico-seguros (color+forma+etiqueta) | ✅ Pin, TierTag, detalle; test cubre forma+label distintas |
| Tipografía (roles → Dynamic Type) | ✅ Mapeo a text styles nativos; precio del pin capado a `.large` |
| Elevación | ⚠️ Aproximación a 1 sombra; falta ring oscuro en superficies no-pin (M-4) |
| Unidad de precio en fila | 🟠 Doble " € €/L" (A-1) |
| Accesibilidad (VoiceOver, touch 44pt, Reduce Motion) | ✅ Pins 44pt, controles 44pt, Reduce Motion en shimmer/spring/recentrado, VoiceOver con tier |
| Contraste AA | ⚠️ TierTag.high en claro borderline (B-1) — validar |

---

## Concurrencia / TCA (Swift 6)

- ✅ `MapStyleOption` y `StationSort` son `Sendable, Equatable, CaseIterable`.
- ✅ Nuevo estado `mapStyle` en `@ObservableState`; acción `mapStyleChanged` + reducer
  + test (`map_mapStyleChanged_updatesState`). Correcto.
- ✅ Bindings `$store.fuel.wrappedValue` / `$store.selfOnly.wrappedValue` correctos; el
  `sort` se inyecta como `Binding` derivado del store (patrón limpio, evita duplicar estado).
- ✅ `load(_:debounced:)` cancela en vuelo (`cancellable(id:cancelInFlight:)`), debounce
  con `continuousClock` inyectado, jitter filtrado por epsilon. Sin bloqueo de main actor.
- ✅ No hay `var` mutable cruzando dominios de aislamiento; vistas son value types.
- Sin observaciones de hangs/hitches en code review; los sheets usan `LazyVStack`. La
  única ineficiencia es recomputar `PriceTiers` (M-2) y `canOpenURL` en body (M-3).

---

## Notas positivas

1. **Sistema de tiers ejemplar:** color + forma + etiqueta viajan juntos en un solo enum,
   testeado, y el `tierStroke`/fills mode-independent resuelven el contraste del pin sobre
   cualquier tile y en ambos modos. Decisión de diseño bien ejecutada.
2. **Reduce Motion completo y coherente** (shimmer, spring del pin, recentrado del mapa),
   y Dynamic Type del precio del pin capada para no desbordar — detalle de oficio.
3. **TCA limpio:** el control de capas se añadió como estado+acción+reducer+test sin tocar
   el flujo de carga; los bindings derivados evitan duplicar `sort`/`mapStyle` en la vista.

---

## Acciones sugeridas (para ios-developer)

- [ ] **A-1** Quitar la doble unidad en `StationRow` (número sin " €" + `€/L`).
- [ ] **M-4** Mover el ring/hairline de oscuro al `ElevationModifier` (un solo sitio).
- [ ] **M-2** Pasar `PriceTiers` del store a `StationListView` en vez de recomputarlo.
- [ ] **M-3** Cachear `availableNavApps` (onAppear/dependency) fuera del `body`.
- [ ] **M-1/M-5** Centralizar el cálculo de frescura (umbral 48h) e inyectar "now".
- [ ] **simplify-1/2/3** Unificar `SortPill`, extraer `InsetSeparator`, compartir el
      label de VoiceOver.
- [ ] **A-3 / N-2** Añadir `comment:` a las claves de a11y y borrar `PriceTier.color` si huérfano.

Para **ios-qa**:
- [ ] Verificar contraste AA real de `TierTag.high` en claro (B-1) y captura claro/oscuro
      de las 7 pantallas (pendiente R6).
- [ ] Test de `StationRow` que aserte el texto de precio (habría cazado A-1).

---

## Veredicto

**CHANGES REQUESTED** — por **A-1** (bug visible de doble unidad de moneda en la lista de
estaciones, la pantalla más usada tras el mapa). El resto del restyle es sólido: sin
problemas críticos de corrección, concurrencia ni memoria; fidelidad alta al design
system; accesibilidad bien cubierta. Una vez corregido A-1 y, deseablemente, M-2/M-3/M-4,
queda **APPROVED**. Los Medios/Bajos/Nits no bloquean pero conviene barrerlos en R6 antes
del ADR del design system.
