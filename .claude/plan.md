# Plan: RELEASE-001 — Camino a producción (App Store)

> **Objetivo (Goal).** Dejar FuelMap listo para publicar en el App Store: onboarding,
> ads en producción, un pase de pulido/HIG, y el checklist de submission (FM-14).
> **España queda fuera de este plan** — se lanza con Italia y España entra como
> fast-follow (v1.1, PRD propio cuando se aborde). Decisión tomada con el usuario
> el 2026-09-01.

---

## Contexto (Context)

Estado verificado en esta sesión (2026-09-01): **75 tests / 20 suites verdes**, SwiftLint 0,
build verde (iPhone 17 sim). Funcionalidad core completa (FM-1…FM-19), restyle visual
completo (RESTYLE-001), favoritos con precio en vivo (FAV-PRICE), app icon (APPICON-001)
y capa premium StoreKit 2 (PREMIUM-001, recién cerrado — ver PHASE_LOG y ADR-006).

Lo que falta para publicar, en el orden que se ejecuta aquí y por qué:

1. **Onboarding** — no existe ningún flujo de bienvenida hoy: el primer contacto del
   usuario es directamente el mapa vacío + el prompt de ubicación en frío. Va primero
   porque introduce estado nuevo en `AppFeature` (flag de primer lanzamiento) que las
   fases siguientes deben respetar, y porque decide *dónde* vive la educación sobre
   permisos — que condiciona cómo se mide la fase de Polish/HIG.
2. **Ads en producción** — hoy todo AdMob (app ID + ambos ad units) son los IDs de TEST
   de Google. Depende de una cuenta AdMob real del usuario (acción externa), así que
   conviene lanzarlo pronto para no bloquear el final por tiempos de aprobación de Google.
3. **Polish / HIG pass** — pase de evaluación con agentes (`ios-reviewer` + `/simplify`
   + `/ios`), tal y como quedó acordado en memoria (`workflow-mode`: "al terminar el
   backlog, lanzar evaluación con agentes"). Va **después** de onboarding y ads para que
   cubra el flujo completo (incluida la UI nueva de esas dos fases), no solo lo que ya
   existía.
4. **App Store submission prep (FM-14)** — checklist final: depende de que ads (fase 2)
   y UI (fase 3) estén cerradas, porque privacy labels y capturas de pantalla se hacen
   sobre el estado final.

## Fuera de alcance (Out of scope)

- **España** (fuente de datos, sync adapter, marcas, ADR nuevo) — comparable en esfuerzo
  a la integración original del MIMIT. Fast-follow v1.1. El esquema Supabase ya tiene
  `country char(2) default 'IT'` (ADR-001) pensado para esto; el modelo de dominio Swift
  y el pipeline de sync siguen siendo 100% Italia/MIMIT y no se tocan aquí.
- Suscripciones / tiers premium adicionales (fuera de alcance de PREMIUM-001, sin cambios).
- Widget iOS, historial de precios, alertas (features v2 ya identificadas en PRD F12 y
  en el plan archivado de PREMIUM-001).

---

## Fase 1 — Onboarding ✅ hecho (01/09)

> Reducido a **2 pantallas** (no 3): se descartó la pantalla de selección de
> combustible a petición explícita del usuario ("sencillo, nada fancy pero
> funcional") — el combustible por defecto ya se ajusta sin fricción en
> `FiltersFeature`. Detalle completo en PHASE_LOG ("RELEASE-001 Fase 1 — Onboarding").
>
> **Hallazgo no previsto en el plan original**: el consentimiento UMP/ATT (disparado
> desde `AppFeature.onAppear` para el flujo premium) se apilaba sobre la pantalla de
> bienvenida si no se diferían. Resuelto con guards en `entitlementLoaded`/
> `entitlementChanged` + retomado al terminar el onboarding — ver PHASE_LOG.
>
> **Iteración del mismo día**: a petición del usuario, navegación por swipe
> (`TabView` paginado, `.pageChanged` unifica botón y gesto) + page control animado
> propio (cápsulas, no los puntos nativos, para mantener el design system).
>
> **Bug reportado por el usuario en simulador y corregido el mismo día**: el permiso
> de ubicación saltaba en el paso 1, no en el paso 2. Causa: `showOnboarding` se
> resolvía en `.onAppear` (reducer), pero SwiftUI ya había pintado `MapView` un
> frame antes — su propio `onAppear` disparaba el permiso. Fix: resuelto en el
> `init()` de `AppFeature.State`, síncrono (lectura de `UserDefaults`, sin razón
> para diferirla). De paso, a petición del usuario, se quitó "Non ora" del paso 2 —
> `enableLocationTapped` es ahora el único camino hacia adelante ahí. Detalle en
> PHASE_LOG.
>
> **Verificado**: 81 tests / 21 suites verdes, SwiftLint 0, build verde.
> **No verificado**: paso manual por las 2 pantallas en simulador (headless no lo
> cubre) — pendiente antes de TestFlight, igual que el tap-through del paywall.

### Decisiones
- **3 pantallas, no más**: (1) propuesta de valor — datos oficiales MIMIT frescos a
  diario vs. la competencia con datos viejos (mismo mensaje que ya usa el PRD/App Store
  copy); (2) priming de ubicación — explica *por qué* antes de que el sistema lo pregunte
  (mejora la tasa de aceptación; HIG lo recomienda); (3) selector de combustible por
  defecto (opcional, precarga `FiltersFeature.fuel` en vez de dejarlo en el valor inicial
  arbitrario).
- **Sin pitch de premium en el onboarding.** Coherente con la Decisión 3 de PREMIUM-001
  ("no se infla con features para justificar precio"): el onboarding vende la app, no la
  compra. Premium se descubre en Ajustes o al ver el banner, no se empuja en frío.
- **Skippable siempre**, con botón "Salta" visible desde la primera pantalla — un
  onboarding que bloquea es fricción, no valor.
- **Flag de estado**: `hasCompletedOnboarding` en `UserDefaults` (no SwiftData — es
  preferencia de app, no dato de dominio), leído en `AppFeature.State.init` /
  `@Shared` si se prefiere el patrón TCA de estado compartido persistente.
- El botón "Continuar" de la pantalla de ubicación es el que dispara
  `locationClient.requestWhenInUse()` — no se pide en el `.onAppear` de `MapFeature`
  como hoy, para no duplicar el prompt si el onboarding ya lo resolvió.

### Tareas
- `Features/Onboarding/OnboardingFeature.swift` — reducer: `page` (enum 3 casos),
  `advance`/`skip`/`locationPrimingConfirmed`/`fuelSelected`; delega a `@Dependency`
  `locationClient` para pedir permiso desde la pantalla 2.
- `Features/Onboarding/OnboardingView.swift` — `TabView(.page)` o carrusel custom;
  Dynamic Type, VoiceOver, respeta Reduce Motion en las transiciones. `#Preview` por
  página.
- `App/AppFeature.swift`: `State.hasCompletedOnboarding`; `@Presents`/full-screen-cover
  condicionado; `MapFeature` deja de pedir permiso de ubicación en su propio `onAppear`
  si el onboarding ya se completó y lo pidió (evitar doble prompt).
- Localización it/es/en de las ~6-8 cadenas nuevas.
- Tests: `OnboardingFeatureTests` (avance de páginas, skip, disparo de
  `requestWhenInUse` en el momento correcto, flag persistido).
- Consultar skill `/ios` (HIG) para el patrón de paginación/onboarding antes de
  implementar la vista (touch targets, indicador de página, gesto de swipe vs. botón).

### Riesgos
- Pedir ubicación en la pantalla 2 y que el usuario la deniegue ahí — el flujo debe
  seguir siendo usable sin permiso (mapa centrado en Italia por defecto, ya existe
  `MapDefaults`/fallback — verificar que sigue aplicando tras el rediseño).
- Un onboarding demasiado largo aumenta el abandono — 3 pantallas es el límite acordado.

### Definición de hecho
Build + tests verdes · SwiftLint 0 · verificado en simulador (instalación limpia):
3 pantallas, skip funcional, permiso de ubicación se pide una sola vez, flag persiste
entre lanzamientos (`hasCompletedOnboarding` sobrevive un relaunch sin reinstalar).

---

## Fase 2 — Ads en producción ✅ hecho (01/09)

> Cuenta AdMob creada por el usuario, guiada paso a paso. **Bloqueante no previsto**:
> AdMob exigió una privacy policy con URL real para completar la configuración —
> deuda ya anotada desde PREMIUM-001, resuelta en la misma sesión (`docs/privacy-
> policy.html`, repo pasado a público, publicada vía GitHub Pages, enlazada desde
> Ajustes y el paywall). Detalle completo en PHASE_LOG ("RELEASE-001 Fase 2").
>
> **Verificado**: build Debug (TEST) y Release (IDs reales) verdes; IDs reales
> confirmados embebidos solo en el binario de Release (`strings` + `plutil` sobre
> el Info.plist compilado). 87 tests / 23 suites sin cambio (config, no lógica).
> **No verificado**: banner real sirviendo impresiones en device/TestFlight (los
> límites de servicio de AdMob siguen activos hasta enlazar la app en Fase 4) y que
> el UMP cargue el mensaje GDPR configurado en la cuenta.
>
> Commit `83f05a8` en `main`: solo la privacy policy. El resto del código de esta
> fase (y de las anteriores del día) sigue sin commitear.

### Decisiones
- IDs reales solo en build de Release; TEST en Debug (patrón estándar de Google) — hoy
  `AdClient.liveValue` usa el mismo ID de test en ambos, hay que bifurcar por
  configuración de build.
- Dos ad units reales (mapa / detalle), igual que hoy con los de test, para mantener
  el reporting separado por placement.

### Tareas
- **Acción del usuario (bloqueante, externa)**: crear/verificar cuenta AdMob, crear la
  app en AdMob y los dos ad units de banner, obtener `GADApplicationIdentifier` real.
- `project.yml`: `GADApplicationIdentifier` real vía config de Release (o `xcconfig`
  separado Debug/Release) — no hardcodear en `Info.plist` compartido si hay que
  bifurcar por entorno.
- `AdClient.liveValue`: `bannerAdUnitID`/`detailAdUnitID` reales en Release, TEST en Debug.
- **SKAdNetworkItems** en `Info.plist` (lista de Google, requerida para attribution de
  ads en iOS 14+) — hoy ausente en `project.yml`.
- **`PrivacyInfo.xcprivacy`** (privacy manifest de la app) — requerido por Apple desde
  2024 para apps con SDKs de terceros que acceden a "required reason APIs"
  (`UserDefaults` cuenta). GoogleMobileAds/UMP traen el suyo propio, pero el target de
  la app necesita el suyo.
- Verificar en simulador/device: banner real aparece (o al menos deja de decir "Test
  Ad"/"Nice job!").

### Riesgos
- Aprobación de la cuenta/app en AdMob puede tardar días — lanzar esta fase pronto para
  no bloquear el final.
- Enviar a review con IDs de test no es motivo de rechazo directo de Apple, pero sí un
  problema de producto (cero ingresos) — no bloquea Fase 3/4 técnicamente, sí conviene
  no publicar así.

### Definición de hecho
Build Release con IDs reales · SKAdNetworkItems presente · `PrivacyInfo.xcprivacy`
presente y validado (`xcodebuild -showBuildSettings` / Xcode no marca warning de
privacy manifest) · banner real verificado en device.

---

## Fase 3 — Polish / HIG pass ✅ hecho (01/09)

> `ios-reviewer` lanzado sobre el diff acumulado de Fases 1-2 + LOCATION-FALLBACK-001
> + deuda diferida de RESTYLE-001. Veredicto inicial: **Changes Requested** (3
> críticos, 7 altos, 12 medios, 9 nits). Todos los críticos y altos remediados, más
> varios medios/nits/deuda de bajo coste. Detalle completo en PHASE_LOG ("RELEASE-001
> Fase 3") y en el informe `.claude/reviews/2026-09-01-release-001-f1-f2-review.md`.
>
> **Diferido a propósito** (documentado, no bloqueante): rediseño con
> `enum LocationContext` unificando el estado de ubicación (arquitectura, no bug);
> `FMButtonStyle`/`BrandIconBadge` compartidos; anuncio de accesibilidad del error
> de búsqueda; `@Shared(.appStorage(...))` en vez de `OnboardingStorage` propio.
>
> **Verificado**: 95 tests / 23 suites verdes (87 → 95), SwiftLint 0, build Debug
> **y** Release verdes. **No verificado**: todo lo visual/manual sigue pendiente,
> acumulado con lo de fases anteriores (ver Fase 4).

### Decisiones
- Ejecutar como evaluación con agentes, tal y como se acordó en `workflow-mode`
  (memoria): `ios-reviewer` corriendo `/simplify` primero y luego su propio análisis,
  más consulta a `/ios` (HIG) para cumplimiento de iPhone. Es la única fase de este plan
  que rompe el patrón de "ejecución directa" — a propósito, porque es exactamente el
  punto que ese acuerdo reservó para el cierre de todo el backlog.
- Alcance: toda la app, no solo lo nuevo — incluye la deuda ya conocida y diferida
  (ring de elevación en oscuro M-4 de RESTYLE-001, dedup de `separator`) más lo que
  introduzcan Onboarding y Ads.

### Tareas
- Lanzar `ios-reviewer` sobre el diff acumulado de Fases 1-2 + deuda diferida conocida.
- Triage de hallazgos: bloqueante vs. deuda aceptada (igual que se hizo en RESTYLE-001
  y FAV-PRICE — no todo hallazgo se remedia antes de publicar).
- Aplicar remediaciones acordadas; re-test.

### Definición de hecho
Informe de revisión en `.claude/reviews/` · remediaciones bloqueantes aplicadas ·
build + tests + SwiftLint verdes tras la remediación.

---

## Fase 4 — App Store submission prep (FM-14)

### Tareas
- **Info.plist l10n**: `NSLocationWhenInUseUsageDescription` y
  `NSUserTrackingUsageDescription` siguen solo en italiano (deuda anotada desde FM-11) —
  mover a `InfoPlist.xcstrings` con it/es/en.
- **App Privacy** (nutrition labels) en App Store Connect: declarar ubicación (uso,
  no vinculado a identidad si aplica), identificador de publicidad (AdMob/ATT),
  ninguna cuenta/login. Depende del estado final de Fase 2.
- **Metadata** it/es/en: descripción, subtítulo, keywords, notas de review.
  Mencionar la atribución IODL 2.0 en la descripción si no está ya.
- **Capturas de pantalla** (obligatorias por tamaño de dispositivo soportado) —
  depende del estado final de Fase 3.
- **Verificación de compra real** (deuda explícita de PREMIUM-001, nunca hecha
  headless): lanzar desde Xcode en device/simulador con cuenta sandbox, tap-through
  completo del paywall → hoja de compra de Apple → banner desaparece.
- **TestFlight**: build de prueba con testers internos antes de someter a review.
- Confirmar `0002_station_detail.sql` aplicada en Supabase (pendiente de sesiones
  anteriores, verificar antes de dar por cerrado).

### Acciones del usuario (Apple Developer / App Store Connect)
1. Aceptar el **Paid Applications Agreement** (bloquea IAP y TestFlight con compras).
2. Crear el no-consumible `com.danmarjim.fuelmap.premium.noads` en ASC (precio ~€3,99,
   nombre/descripción it/es/en — ya redactados en `FuelMap.storekit` como referencia).
3. Completar App Privacy, metadata y capturas en App Store Connect.
4. Probar en device con cuenta sandbox antes de enviar a review.

### Definición de hecho
Build de Release firmado · TestFlight funcional con compra sandbox verificada ·
App Store Connect completo (privacy, metadata, capturas) · submission enviada.

---

## Riesgos generales del plan

- **Dependencias externas de tiempo no controlable**: aprobación AdMob, PLA de Apple,
  review de App Store — ninguna la acelera el código. Fase 2 se adelanta por esto.
- **España diferida** puede generar presión de "salir ya con los dos países" si cambia
  la prioridad de negocio a mitad de plan — si eso ocurre, este plan se pausa y se abre
  `PRD-002-espana.md` antes de tocar código (no saltarse la fase de producto, ver
  CLAUDE.md global "Product-to-Code Pipeline").
- **Onboarding y Ads tocan `AppFeature.onAppear`/orquestación de arranque** al mismo
  tiempo que ya lo hace el entitlement premium (PREMIUM-001) — verificar con tests que
  el orden final (onboarding → entitlement → consent/ads) no regresiona el guard de
  idempotencia ya existente.
