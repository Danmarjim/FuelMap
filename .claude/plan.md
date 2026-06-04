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
| FM-2 | Esquema Supabase + RPC + RLS | M | — |
| FM-3 | Sync MIMIT (GitHub Actions) | L | FM-2 |
| FM-4 | Modelos + DTOs + mapeo | S | FM-1 |
| FM-5 | APIClient (supabase-swift) | M | FM-1,2,4 |
| FM-6 | LocationClient + permisos | M | FM-1 |
| FM-7 | MapFeature + MapView | L | FM-4,5,6 |
| FM-8 | FiltersFeature | M | FM-7 |
| FM-9 | StationDetail | M | FM-7 |
| FM-10 | Más barata + orden | S | FM-7,8 |
| FM-11 | AdMob + UMP + ATT | M | FM-1,7 |
| FM-12 | Favoritos (SwiftData) [nice] | M | FM-9 |
| FM-13 | A11y + estados + l10n | M | FM-7,8,9 |
| FM-14 | Privacy labels + App Store prep | S | FM-11,13 |

## Próximo paso inmediato

- **FM-1 hecho** (2026-06-04): esqueleto TCA compila + 1 test passing en simulador.
- Siguiente: **FM-4** (modelos + DTOs + mapeo) y/o **FM-6** (LocationClient) — ninguno depende del backend.
- Estrategia mock: FM-5 introducirá `APIClient` con `liveValue` mock para correr la app sin Supabase hasta FM-2/FM-3.

## Deuda registrada (no bloqueante)

- [Vacío al inicio — se irá poblando conforme aparezca deuda aceptada.]

## Convenciones del workflow

- Decisiones congeladas → `decisions/ADR-XXX-*.md` (numerados secuencial).
- Historia auditada → `PHASE_LOG.md` (formato: Architect / Developer / QA / Review por fase).
- Mapa de código → `SYSTEM_MAP.md` (actualizar al cerrar fase).
- Reviews puntuales (auditoría externa) → `reviews/`.
