# Phase Log — FuelMap

> Phase transitions and major milestones. Updated by agents on phase completion (via `/close-phase` skill or manually following this template).
> Append new entries at the end. The `## Current State` block at the bottom is always the snapshot of "today".

---

## Plan Iteration: Workflow — Completed
**Date:** 2026-06-04

### Architect (workflow adoption)
- Adopted Claude Code workflow system (templates, agents, hooks).
- `.claude/` scaffolded from `~/.claude/templates/`.
- Verification hook configured: `~/.claude/templates/settings-hooks-swift.json` (Swift `-parse` syntax check on Stop).
- Stack: iOS (Swift 6, SwiftUI, TCA). Type: greenfield.
- Key product/architecture decisions locked at kickoff: TCA, Supabase + GitHub Actions sync (no own backend), AdMob, iOS 17+, Italia-first.

### Developer (implementation)
- N/A — pure infrastructure setup, no code changes.

### QA (tests)
- N/A — no test changes.
- Baseline test count: 0 (greenfield).

### Review
- /init-workflow skill executed without errors.
- All artifacts verified on disk.
- Verdict: **APPROVED**.

---

## Plan Iteration: Producto & Diseño (PRD → RFC → ADRs → Issues) — Completed
**Date:** 2026-06-04

### Architect (ADR-001, ADR-002, ADR-003)
- PRD-001 redactado y **Approved** con open questions críticas validadas vía research web (endpoints MIMIT reales, límites Supabase free tier, requisitos AdMob ATT/UMP).
- Hallazgo clave: CSV MIMIT con separador **`|` (pipe)** desde 2026-02-10; `anagrafica` con línea `Estrazione del ...` a saltar; `descCarburante` en texto libre con muchas variantes.
- RFC-001 **Accepted**: arquitectura iOS (TCA) + Supabase (PostGIS, RPC `nearby_stations`, RLS read-only) + sync diario GitHub Actions; esquema SQL, contratos `@Dependency`, plan §4 de 14 issues, riesgos y testing.
- ADR-001 (capa de datos Supabase, sin BE propio), ADR-002 (TCA), ADR-003 (normalización combustible con `fuel_raw`).

### Developer (implementation)
- N/A — fase de producto/diseño, sin código.

### QA (tests)
- N/A — estrategia de test definida en RFC §7 (TestStore por reducer, parse de CSV con fixtures, RPC con seed).

### Review
- Decisiones validadas contra fuentes oficiales (MIMIT en vivo, Supabase pricing, AdMob docs).
- Artefactos verificados en disco: PRD, RFC, 3 ADRs, 14 issues.
- Verdict: **APPROVED**.

---

## Plan Iteration: FM-1 — Proyecto Xcode + TCA — Completed
**Date:** 2026-06-04

### Architect (ADR-002)
- Tooling: **XcodeGen** (`project.yml`) elegido sobre Tuist / .xcodeproj commiteado.
- Decisión de ejecución: en FM-1 solo se añade el paquete SPM **TCA**; `supabase-swift` y `GoogleMobileAds` se incorporan en FM-5/FM-11 para mantener el build inicial ligero y correr la app contra mocks (petición del usuario).

### Developer (implementation)
- `project.yml` (XcodeGen): target iOS 17, Swift 6 `complete` strict concurrency, paquete TCA `from 1.15.0`.
- `FuelMap/App/`: `FuelMapApp.swift` (@main + Store raíz), `AppFeature.swift` (reducer esqueleto), `AppView.swift` (placeholder `ContentUnavailableView`).
- `.gitignore` actualizado para `.xcodeproj` generado.

### QA (tests)
- `FuelMapTests/AppFeatureTests.swift` — Swift Testing, smoke con `TestStore` (`onAppear` sin efectos pendientes).
- **BUILD SUCCEEDED** (iPhone 17, iOS 26.5 sim). **TEST: 1 test passing**. SwiftLint: 0 violations. Sin warnings de concurrencia.

### Review
- Problemas resueltos en verificación: (1) macros TCA → `-skipMacroValidation`; (2) *undefined symbols* `CasePathsCore`/`PerceptionCore` al testear → el test target depende SOLO del host app (no re-enlaza el paquete TCA).
- Entorno: Xcode 26.5 vía `DEVELOPER_DIR` (xcode-select apunta a CLT; sin `sudo`).
- Verdict: **APPROVED**.

---

## Current State
**Date:** 2026-06-04
- App iOS arrancable: esqueleto TCA (`AppFeature`/`AppView`) compila y corre en simulador, muestra placeholder. 1 test Swift Testing passing.
- Proyecto generado con XcodeGen (`project.yml`); deps SPM: solo TCA (supabase-swift/AdMob diferidos a FM-5/FM-11).
- Backend (FM-2/FM-3) aún sin tocar — se trabajará con `APIClient` mock hasta entonces.
- Canon: `prd/PRD-001`, `rfc/RFC-001`, `decisions/ADR-001..003`, `issues/FM-1..FM-14` (FM-1 hecho).
- **Próximo paso:** FM-4 (modelos + DTOs + mapeo) y/o FM-6 (LocationClient); ambos sin dependencia de backend. FM-5 introducirá `APIClient` con `liveValue` mock.

---

> ## Usage rules
>
> - **Append, never rewrite** older entries. They are historical record.
> - **`Current State`** is the only block that gets replaced — always overwrite with the latest snapshot at the end of every phase.
> - **Date format**: `YYYY-MM-DD`. No ambiguous formats.
> - **One iteration = one block**. A "Plan Iteration" is a coherent unit of work cleared by a reviewer.
> - **Architect / Developer / QA / Review subsections** must each contain real content. If a role didn't participate, state "N/A — ..." rather than omitting.
> - **Reference ADRs by number** in Architect subsection when they exist.
> - **Bullet style**: short, factual, with file/component references where useful.
