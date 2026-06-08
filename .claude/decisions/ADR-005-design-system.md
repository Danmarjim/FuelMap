# ADR-005: Design system con tokens semánticos y tiers de precio daltónico-seguros

> Fecha: 2026-06-08
> Estado: Aceptado
> Contexto: RESTYLE-001. Restyle visual completo a partir del design system entregado por Claude Design (`.claude/design/`). Personalidad *bold & energetic*, ancla azul, paridad claro/oscuro.

---

## 1. Contexto

La app (FM-1…FM-19) tenía una capa visual funcional pero ad-hoc: colores de sistema (`.green/.orange/.red`, `.blue`), `regularMaterial`, sin tokens. Se encarga un design system a Claude Design; entrega tokens (claro/oscuro), specs de componente y mockups de las 7 pantallas. Hay que aplicarlo sin tocar arquitectura, dominio, red ni datos.

---

## 2. Decisión

### 2.1 Tokens semánticos en Asset Catalog (1:1 con `tokens.css`)

35 Color sets en `Assets.xcassets/Colors/` con nombres semánticos (`brandPrimary`, `surface`, `priceCheapInk`…), apariencias Any/Dark, accedidos por símbolo `Color(.brandPrimary)`. Los **fills de tier (`priceCheap/Mid/High`) son de valor único** (idénticos en claro y oscuro): el texto blanco del pin mantiene contraste AA en ambos modos; solo las variantes *ink* (texto de tier sobre superficie) y *surface* cambian por modo.

Tokens no-color en `DesignSystem/`: `Spacing` (grid 4pt), `Radius`, `Elevation` (modifier `.elevation(_:)` que aproxima las multi-sombra del CSS y profundiza en oscuro), `Typography` (roles SF Pro mapeados a text styles nativos → Dynamic Type gratis + fuentes de precio tabulares).

### 2.2 Tiers de precio a prueba de daltonismo

`PriceTier` nunca depende solo del color: expone `fill`/`ink`/`surface` **+ `symbolName`** (▲ bajo · ● medio · ▼ alto) **+ `label`** localizada (Basso/Medio/Alto). Forma y palabra viajan con el color en pin, filas (`TierTag`) y detalle. Cumple WCAG y la confusión verde/rojo de deuteranopía.

### 2.3 Reutilización de componentes

`SheetComponents.swift` centraliza el vocabulario de las hojas (`TierTag`, `BestFlag`, `SortPill`, `SheetHeader`, `SheetEmptyState`, `FreshnessPill`, `StationRow`, `SkeletonRow/List`). El pin del mapa usa su propio badge (monograma de marca, no logo: ilegible a tamaño pin); el logo real va en el chip de detalle/listas.

### 2.4 Capas de mapa (feature nueva del restyle)

`MapStyleOption` (standard/hybrid/imagery) en `MapFeature` + `.mapStyle` vía `MapStyleModifier` + menú en un control flotante.

---

## 3. Consecuencias

- **A favor:** una sola fuente de verdad de color/tipografía/espaciado; paridad claro/oscuro garantizada; accesibilidad (tier daltónico-seguro, Dynamic Type, Reduce Motion, VoiceOver) integrada, no parcheada; cambios visuales futuros = editar tokens.
- **Coste:** los logos multicolor van sobre chip blanco también en oscuro (diseñados para fondo claro); las sombras CSS multi-capa se aproximan con una `.shadow` + hairline.
- **Pendiente:** favoritos sin precio/tier/distancia en vivo (el modelo `FavoriteStationInfo` no los lleva) — mejora futura, no restyle.

### Archivos

- Nuevos: `DesignSystem/{Spacing,Radius,Elevation,Typography,TokenGallery}.swift`, `Features/Map/SheetComponents.swift`, `Assets.xcassets/Colors/*` (35 + `goldInk`).
- Migrados: `StationPin`, `ClusterPin`, `BrandBadge`, `MapView`, `MapFeature`, `FiltersView`, `StationListView`, `FavoritesView`, `StationDetailView`, `AppView`, `PriceTiers`.
- Referencia versionada del sistema: `.claude/design/`.
