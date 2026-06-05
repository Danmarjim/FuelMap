# Evaluación completa FuelMap — 2026-06-05

> Review multi-agente (report-only) tras FM-1…FM-13 (39 tests, mock data).
> Agentes: ios-reviewer (Opus, corrección/concurrencia), ios-developer (Sonnet, HIG/a11y), ios-reviewer (Sonnet, calidad+consistencia docs).
> Análisis previo: Opus (hilo principal). Estado del código: sólido; sin data races demostrables. Verdict global: **cambios recomendados antes de datos reales / App Store**.

## 🔴 Crítico

| ID | Hallazgo | Archivo | Acción |
|---|---|---|---|
| C1 | **`Store` raíz recreado en cada evaluación del `body`** → se pierde todo el estado (mapa, filtros, detalle, favoritos) y se relanzan efectos en cada recomposición. (comentario propio "diferido a FM-7" nunca resuelto) | `App/FuelMapApp.swift:17-21` | Owner estable: `@State`/`static let`. |
| C2 | **F6 Clustering (Must-have) diferido como deuda**. `Map` SwiftUI no clusteriza annotations custom; con ~22k reales + `limit 200` el mapa es inusable. La premisa del RFC §5 ("clustering nativo de Map") es falsa. | FM-7 / RFC §5 | Crear **FM-15** (MKMapView+MKClusterAnnotation o grid). Bloqueante antes de datos reales. |

## 🟠 Alto

| ID | Hallazgo | Archivo | Acción |
|---|---|---|---|
| H1 | **Recentrado one-shot roto**: `recenter` nunca se resetea; reseleccionar el mismo favorito/estación no recentra la 2ª vez. | `MapFeature.swift` + `MapView.swift:95` | Modelar como evento consumible (token UUID) o reset a nil vía acción. + test. |
| H2 | **Dynamic Type rompe en tamaños AX**: `StationPin` (`.caption2`) desborda y solapa pins; segmentado de 4 combustibles se trunca ya en AX1; `priceLabel` (HStack) del detalle desborda. | `StationPin.swift:26`, `FiltersView.swift:17-21`, `StationDetailView.swift:98-107` | `@Environment(\.dynamicTypeSize)`: pin solo-icono en AX; segmented→menu en AX; HStack→VStack. |
| H3 | **Touch targets < 44×44 pt**: pins (~28pt), botones flotantes lista/favoritos (~37pt), filas de lista (~38pt). | `StationPin`, `MapView.swift:108-130`, `StationListView.swift:68` | `.contentShape`/`.frame(minHeight:44)`, padding 12. |
| H4a | **Bug deep link**: usa `http://maps.apple.com/?daddr=` (pasa por Safari/Universal Links) en vez de `maps://?daddr=` (scheme nativo, robusto offline). El RFC §6.2 ya especifica `maps://`. | `StationDetailFeature.swift:95` | Cambiar a `maps://?daddr=`. |
| H4b | **Banner fijo, no adaptativo** (RFC §6.4 pide adaptativo): `GADAdSizeBanner` (320×50) → menor fill rate/eCPM. | `BannerAdView.swift:16` | `GADCurrentOrientationAnchoredAdaptiveBannerAdSizeWithWidth(...)`. |

## 🟡 Medio

| ID | Hallazgo | Archivo | Acción |
|---|---|---|---|
| M1 | `@Dependency(\.adClient)` leído en el `body` de `AppView` (rompe flujo TCA; además la `#Preview` cargaría un `GADBannerView` real). | `AppView.swift:14,19` | Mover `bannerAdUnitID` a `AppFeature.State`. |
| M2 | `try!` de fallback en `ModelContainer.fuelMapShared` puede crashear en arranque (lo que el do/catch quería evitar). | `FavoritesClient.swift:124` | Degradar a `FavoritesClient` no-op si ambos contenedores fallan. |
| M3 | **VoiceOver incompleto**: filas de lista/favoritos sin `accessibilityLabel`/`Hint`; labels dirección/marca sin contexto; toggle self sin hint. | `StationListView`, `FavoritesView`, `StationDetailView`, `FiltersView` | Añadir labels/hints compuestos. |
| M4 | "Más barata" se distingue **solo por color** (verde) → invisible para daltonismo. | `StationPin`, `StationListView` | Añadir badge/símbolo además del color. |
| M5 | Safe areas: banner de 50pt puede quedar bajo el home indicator; botones flotantes bajo la Dynamic Island. | `AppView.swift:19`, `MapView.swift:50-57` | Respetar `safeAreaInsets`. |
| M6 | `distance_m` del RPC se descarta; FM-10 recalcula haversine en cliente → doble fuente de verdad con el backend real. | `NearbyStationRowDTO.swift:28`, `StationMapper.swift` | Decidir: quitar del DTO o propagar a `Station` con fallback. |
| M7 | `ISO8601DateFormatter` (×2) y `JSONDecoder.fuelMap` se reconstruyen en cada llamada (caro; ~400 formatters por respuesta de 200 filas). | `ISO8601.swift:15-21`, `JSONDecoder+FuelMap.swift:14` | `static let` cacheados. |

## 🟢 Bajo / limpieza (/simplify)

- **Dedup**: formateo de precio en 3 vistas (`StationPin`/`StationListView`/`StationDetailView`) → `Decimal.FormatStyle.fuelPrice` (+ forzar locale `it_IT` para la coma decimal); `APIError.userMessage` duplicado en 2 reducers; `Coordinate↔CLLocationCoordinate2D` repetido; `italyDefault` vs `StationFixtures.anchor` (mismo punto, 2 nombres); lógica "min por precio" en 3 sitios.
- `StationSort.label` ("Prezzo"/"Distanza") sin `String(localized:)` (visible al usuario).
- `BannerAdView.updateUIView` vacío (no reacciona a cambios de `adUnitID`/`rootViewController`).
- `currentLocation` sin timeout: si CoreLocation no responde, el efecto nunca completa (mapa sin estaciones ni error).
- Recentrar pierde el zoom (`span` nunca se actualiza desde la cámara).
- `MapView` `@State camera` hardcodea `italyDefault/0.08` en vez de init desde `store.center/span`.
- Estado vacío de precios en `StationDetailView` (estación sin precios → sección "Prezzi" vacía).
- `Localizable.xcstrings`: ~28 entradas `stale` tras el build (usadas vía `String(localized:)`/interpolación) — limpiar/decidir estrategia de claves.
- `topViewController()` acopla `BannerAdView` con `AdConsentCoordinator` → mover a helper `UIWindowScene+KeyWindow`.
- Precompute `cheapest` (la RPC ya ordena por precio asc → `prices.first`).

## 📄 Consistencia documentación (addenda al RFC "Accepted")

| Ítem | Veredicto | Acción |
|---|---|---|
| RFC §2.2 `FuelType` 5 vs 6 (`.altro`) | Correcto en código (ADR-003) | Addendum RFC §2.2 → ref ADR-003 |
| RFC §9 agnosticismo `country` | Solo a nivel BD, no en modelo Swift | Aclarar RFC §9 |
| RFC §6.2 `region` vs `center`+`span` | Desviación razonable | Addendum RFC §6.2 |
| RFC §6.2 deep link | **Bug código** (ver H4a) | Corregir código |
| RFC §6.4 banner adaptativo | **Gap código** (ver H4b) | Corregir código + RFC |
| PRD F6 clustering Must-have | Deuda registrada (ver C2) | FM-15 + revisar prioridad |
| `FuelType.selectable` sin `hvo` | Alineado con PRD F2 | Comentario inline ref PRD F2 |

## ✅ Sólido (confirmado por los agentes)
- Concurrencia `LocationClient` (LockIsolated + extracción Sendable + puente delegate→async) bien resuelta.
- Disciplina de tipos/access control (Decodable no Codable, errores tipados, Sendable, final, let).
- TCA esencial correcto (`.cancellable(cancelInFlight:)`, `@Presents`/`ifLet`, `Scope`, `unimplemented` en testValue, TestClock/ImmediateClock).
- Separación wire/dominio (StationMapper). 39 tests verdes, SwiftLint 0.
