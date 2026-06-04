# FM-14: Privacy labels, atribución IODL 2.0 y preparación App Store/TestFlight

> Derivado de RFC-001 §10 (NF7). Self-contained.

## Description
Preparar la app para distribución: privacy nutrition labels (ubicación, IDFA/AdMob), atribución de licencia IODL 2.0 del MIMIT, metadatos y configuración de TestFlight/App Store.

Complexity: S
Dependencies: FM-11, FM-13

## Files to Modify
- App Store Connect (metadatos, privacy labels) — fuera del repo.
- `Info.plist` — verificar todas las usage descriptions.
- `Features/Settings/AboutView.swift` (nuevo) — atribución "Dati: MIMIT — Osservaprezzi Carburanti, licenza IODL 2.0" + enlace.
- `PrivacyInfo.xcprivacy` (nuevo) — privacy manifest (location, tracking, AdMob).

## Technical Specification (from RFC)
**Source:** RFC §10; PRD NF7.

- Privacy nutrition labels: ubicación (uso app), identificadores (IDFA via AdMob), datos de uso si aplica.
- `PrivacyInfo.xcprivacy` con required reason APIs y tracking domains de AdMob.
- Atribución IODL 2.0 visible en la app (pantalla "Acerca de").
- Build de release firmado; subir a TestFlight (beta interna → externa) antes de submission.

## What NOT to Do
- Do NOT enviar a App Store sin privacy labels completas (rechazo seguro).
- Do NOT omitir la atribución de licencia IODL 2.0.
- Do NOT incluir IDs de AdMob de test en el build de release.

## Tests to Add
- N/A unit. Checklist de release verificado manualmente; smoke test del build de release en dispositivo.

## Acceptance Criteria
- [ ] Privacy labels y `PrivacyInfo.xcprivacy` completos y coherentes con el uso real.
- [ ] Atribución IODL 2.0 presente en "Acerca de".
- [ ] Build de release sube a TestFlight sin warnings de validación.
- [ ] Checklist de App Store verificado.

## References
- RFC: §10; PRD NF7
- MIMIT IODL 2.0
