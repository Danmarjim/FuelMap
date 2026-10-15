---
name: spec-to-tasks
description: Convierte las "Siguientes funcionalidades" del PRD aprobado (docs/PRD.md) en issues de GitHub pequeños, ordenados y con criterios de aceptación, cada uno del tamaño de un PR. Úsala justo después de aprobar el PRD o una versión nueva.
---

# De PRD a tareas

## Precondición

`docs/PRD.md` debe tener `Estado: Aprobado`. Si pone `Borrador`, para y pide aprobación: la spec es
la primera puerta humana del proceso.

FuelMap ya está construida: lo que se trocea es la sección **Siguientes funcionalidades** del PRD, no
lo que la app ya hace (secciones de estado actual). Si esa sección está vacía, dilo y para.

## 1. Lee y trocea

- Lee el PRD completo, `.claude/SYSTEM_MAP.md` (mapa de módulos) y los ADR de
  `.claude/decisions/` que afecten a lo que vas a trocear. `.claude/rfc/RFC-001-fuelmap-architecture.md`
  tiene el diseño técnico original (esquema Supabase, RPC, contratos `@Dependency`).
- Divide cada funcionalidad en tareas que cumplan **todas** estas condiciones:
  - Se pueden revisar en un PR de menos de ~400 líneas.
  - Dejan la app compilando y con tests en verde.
  - Tienen un resultado visible o comprobable.
- Orden típico en FuelMap: backend (migración SQL / RPC / sync) → `@Dependency` en `Core/`
  (cliente + `testValue`/`previewValue`) → reducer de la feature con sus tests → vista → l10n
  it/es/en y accesibilidad.
- Separa siempre en tareas distintas lo que toca `backend/` y lo que toca la app: las migraciones las
  aplica Dani en Supabase y la app no puede depender de una RPC que todavía no existe en producción.
- Si una funcionalidad necesita una decisión de arquitectura nueva, la primera tarea es el ADR.

## 2. Escribe cada tarea

Formato de cada issue:

```markdown
## Contexto
Qué parte del PRD cubre (enlaza la sección).

## Alcance
- Lo que entra.
- Lo que explícitamente NO entra.

## Criterios de aceptación
- [ ] Comportamiento comprobable 1
- [ ] Comportamiento comprobable 2
- [ ] Tests con `TestStore` del reducer (y de la lógica pura que se extraiga)
- [ ] Textos nuevos en `Localizable.xcstrings` con it/es/en
- [ ] Verificado con `verify-app` (si hay UI)

## Backend
Migración o cambio en el sync necesario, o "ninguno". Las migraciones nuevas son `NNNN_*.sql`
correlativas en `backend/migrations/`.

## Dependencias
#n de las que depende, o "ninguna".

## Dónde se ejecuta
`local` (necesita Xcode/simulador) o `cloud` (lógica pura, docs, backend/sync, metadatos).
```

## 3. Créalas

```bash
gh issue create --title "<imperativo corto>" --body-file <fichero> --label local   # o cloud
```

Las etiquetas `local` y `cloud` ya existen en el repo. Si faltaran, créalas con `gh label create`.

## 4. Resume

Devuelve una tabla: número, título, dependencias, dónde se ejecuta. Señala qué tareas se pueden
hacer en paralelo sin tocar los mismos ficheros (ojo con `MapFeature.swift`, `AppFeature.swift` y
`Localizable.xcstrings`, que tocan casi todas las features).
