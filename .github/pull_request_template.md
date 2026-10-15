## Qué

<!-- Una o dos frases. Enlaza el issue: Closes #n -->

## Por qué

<!-- Qué parte de docs/PRD.md cubre o qué problema arregla. -->

## Cómo se ha verificado

- [ ] `scripts/test.sh` en verde (app + `backend/sync`)
- [ ] `swiftlint lint --strict FuelMap FuelMapTests` sin errores
- [ ] Reducers nuevos o cambiados con tests de `TestStore`
- [ ] Textos nuevos en `Localizable.xcstrings` con it/es/en
- [ ] Verificado en simulador con `verify-app` (si hay cambios de UI)
- [ ] `.claude/SYSTEM_MAP.md` actualizado (si se han añadido o movido ficheros)

### Capturas

<!-- Antes / después, modo claro y oscuro si aplica. -->

## Backend

<!-- Solo si el PR toca backend/: migraciones nuevas (Dani las aplica en Supabase, en orden),
     cambios en el sync o en las RPC. Si no aplica, borra la sección. -->

## Lo que no se ha podido verificar

<!-- Sé explícito. "Nada" también es una respuesta válida. -->
