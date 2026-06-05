# Plan: (sin plan activo)

> Última milestone cerrada: ver `.claude/PHASE_LOG.md` (sección **Current State**).
> Estado del proyecto: ver `.claude/SYSTEM_MAP.md`.

---

## Cómo arrancar la próxima fase

1. Invocar `ios-team-lead` describiendo el objetivo (feature, refactor, bugfix).
2. El team-lead rellena este archivo con: **Goal**, **Context**, **Phases**, **Out of scope**, **Verification**.
3. Cada fase ejecuta la cadena `architect → developer → qa → reviewer` y queda registrada en `PHASE_LOG.md`.
4. Al cerrar el plan, invocar `/close-phase` para mover este `plan.md` a `plan-archive/<YYYY-MM-DD>-<slug>.md` y dejar el archivo limpio para el siguiente.

## Estado: Producto & Diseño cerrado (2026-06-04)

Canon listo:
- `prd/PRD-001-fuelmap.md` (Approved)
- `rfc/RFC-001-fuelmap-architecture.md` (Accepted)
- `decisions/ADR-001..003`
- `issues/FM-1..FM-14` (backlog ordenado por dependencias)

## Backlog de ejecución (RFC §4)

| ID | Issue | Compl. | Deps |
|---|---|---|---|
| ✅ FM-1 | Proyecto Xcode + TCA (solo TCA; Supabase/AdMob diferidos a FM-5/FM-11) | M | — |
| ✅ FM-2 | Esquema Supabase + RPC + RLS (aplicado en cloud, 2026-06-05) | M | — |
| ✅ FM-3 | Sync MIMIT (desplegado; cron CI verificado: 23.7k stations / 92.6k precios) | L | FM-2 |
| ✅ FM-4 | Modelos + DTOs + mapeo | S | FM-1 |
| 🟡 FM-5 | APIClient (mock; supabase-swift real en FM-2/FM-3) | M | FM-1,4 |
| ✅ FM-6 | LocationClient + permisos | M | FM-1 |
| ✅ FM-7 | MapFeature + MapView (clustering → FM-15) | L | FM-4,5,6 |
| ✅ FM-8 | FiltersFeature | M | FM-7 |
| ✅ FM-9 | StationDetail | M | FM-7 |
| ✅ FM-10 | Más barata + orden | S | FM-7,8 |
| ✅ FM-11 | AdMob + UMP + ATT (IDs test) | M | FM-1,7 |
| ✅ FM-12 | Favoritos (SwiftData) [nice] | M | FM-9 |
| ✅ FM-13 | A11y + estados + l10n | M | FM-7,8,9 |
| FM-14 | Privacy labels + App Store prep | S | FM-11,13 |
| 🔴 FM-15 | Clustering de pins (bloqueante pre-datos reales) | L | FM-7 |

## Evaluación multi-agente (2026-06-05) — hecha

Review completa en `.claude/reviews/2026-06-05-evaluacion-completa.md`. Remediación aplicada en 3 tandas (commits `refactor/fix: review remediation batch 1-3`):
- **Corregido**: C1 (Store estable), H1 (recenter consumible), H2 (Dynamic Type pin/filtros/detalle), H3 (touch targets 44pt), H4a (deep link maps://), H4b (banner adaptativo), M1 (adClient→State), M2 (favoritos no-op fallback), M3 (VoiceOver listas), M4 (más barata con forma+color), M6 (distanceM fuera del DTO), M7 (formatters cacheados) + dedup /simplify (precio, userMessage, conversores coordenada).
- **Diferido**: C2 clustering → **FM-15**. Desviaciones docs → addendum RFC §11.

## Próximo paso inmediato

- **FM-1…FM-13 + remediación de review hechos. FM-2/FM-3 DESPLEGADOS** (Supabase poblado: 23.7k stations / 92.6k precios; cron GitHub Actions verificado en CI). Repo en GitHub `Danmarjim/FuelMap` (privado).
- **Siguiente: FM-5 real** — swap de `APIClient.liveValue` (mock) a `supabase-swift` contra la RPC `nearby_stations` (URL `https://npbhmiaegxvmxntcppgd.supabase.co` + anon key). Luego **FM-15** (clustering, bloqueante con datos reales) → **FM-14** (App Store).

## Deuda registrada (no bloqueante)

- **FM-15 Clustering (PRD F6, Must-have)** — 🔴 bloqueante antes de datos reales. Issue creado. Origen: review C2.
- **Carga inicial supeditada al permiso de ubicación** (review N13) — las estaciones no cargan hasta responder el prompt; valorar cargar con centro por defecto en paralelo + timeout en `currentLocation`.
- **Pulido a11y menor (review)** — contexto VoiceOver en dirección/marca del detalle; conservar zoom al recentrar; `MapView.camera` init desde `store.center/span`; extraer `topViewController()` a helper desacoplado.
- **APIClient real (FM-5 → FM-2/FM-3)** — `liveValue` es un mock; sustituir por supabase-swift contra la RPC `nearby_stations` cuando exista el backend. No enviar el mock a producción (verificar en FM-14).
- **Info.plist l10n (FM-13 → FM-14)** — la usage description de ubicación sigue en italiano; localizar es/en vía `InfoPlist.xcstrings` en FM-14.
- **AdMob producción (FM-11 → FM-14)** — `GADApplicationIdentifier` y el ad unit del banner son IDs de TEST de Google; sustituir por los reales + añadir `SKAdNetworkItems` y privacy labels en FM-14. No publicar con IDs de test.

## Convenciones del workflow

- Decisiones congeladas → `decisions/ADR-XXX-*.md` (numerados secuencial).
- Historia auditada → `PHASE_LOG.md` (formato: Architect / Developer / QA / Review por fase).
- Mapa de código → `SYSTEM_MAP.md` (actualizar al cerrar fase).
- Reviews puntuales (auditoría externa) → `reviews/`.
