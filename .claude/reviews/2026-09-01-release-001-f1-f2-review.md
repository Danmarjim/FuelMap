# RELEASE-001 F1+F2 & LOCATION-FALLBACK-001 — Review

**Reviewer:** ios-reviewer · **Fecha:** 2026-09-01
**Alcance:** working tree sin commitear sobre `c335b04` (onboarding, fallback de ubicación, ads en producción) · TCA + SwiftUI, iOS 17+, Swift 6 strict concurrency
**Estado de partida verificado:** `xcodegen generate` + `xcodebuild build` → **BUILD SUCCEEDED** · `xcodebuild test` → **87 tests en 23 suites, todos verdes** · `swiftlint` → **0 violaciones**

---

## Veredicto

### ⚠️ Changes Requested

La arquitectura es correcta y el trabajo está bien razonado — los comentarios explican
el *por qué* de cada decisión no obvia, la separación TCA es limpia y no hay data races,
force-unwraps ni retain cycles. Pero hay **tres defectos que llegan al usuario en el
primer lanzamiento** y un bloque de deuda de accesibilidad/submission que no debería
cruzar a TestFlight. Ninguno exige rediseño: son fixes localizados.

| Severidad | Nº |
|---|---|
| 🔴 Crítico | 3 |
| 🟠 Alto | 7 |
| 🟡 Medio | 12 |
| 🔵 Bajo / nit | 9 |
| ⚫ Deuda RESTYLE-001 diferida | 2 (ambas siguen vivas) |

---

## Paso 0 — `/simplify` (obligatorio): reuso, simplificación, eficiencia, altitud

Ejecutado en **modo análisis** (la consigna prohíbe aplicar fixes), con las cuatro
pasadas del skill. Resumen; los hallazgos que además son defectos suben a la tabla de
severidad de abajo.

### Reuso

1. **El CTA primario está copiado 4 veces en este diff** (5 en el repo):
   `OnboardingView.swift:135-146`, `LocationPromptOverlay.swift:51-60` y `:62-71`,
   `LocationSearchView.swift:46-61`, más el preexistente `PaywallView.swift:129-144`.
   Los cinco son idénticos: `.fmHeadline.weight(.semibold)` + `Color(.onBrand)` +
   `.frame(maxWidth: .infinity, minHeight: 50)` + `brandPrimaryFill` +
   `RoundedRectangle(Radius.md, .continuous)`. `LocationSearchView` y `PaywallView`
   repiten hasta el mismo wrapper `Group { if busy { ProgressView().tint(...) } else {...} }`.
   Y ya hay una sexta variante divergente: `StationDetailView.swift:226-239` usa altura 52
   y `Radius.lg`. **Fix:** un `FMButtonStyle` (`.primary`/`.secondary`) en `DesignSystem/`
   — hoy `DesignSystem/` no tiene ni un helper de botón, solo `elevation(_:)`.

2. **El badge circular de icono está duplicado**: `OnboardingView.swift:95-100` (96/44) y
   `LocationPromptOverlay.swift:28-33` (88/40), misma receta que `PaywallView.swift:61-66`
   (88/44) y `SettingsView.swift:50-54` (44/`fmTitle3`). Cuatro sitios, tres diámetros
   distintos para lo que se lee como un único componente. **Fix:** `BrandIconBadge(symbol:size:)`.

3. **`LocationPromptOverlay.swift:26-48` reimplementa `SheetEmptyState`**
   (`SheetComponents.swift:92-116`), que ya es icono-chip + título + mensaje centrado y ya
   está parametrizado por `systemImage`/`tint`/`tintSurface`. Bastaría con darle un slot
   `@ViewBuilder` de acciones.

4. **`MapFeature+LocationSearch.swift:13` crea un `private enum SearchCancelID`** cuando
   `MapFeature.CancelID` (`MapFeature.swift:124`) dejó de ser `private` **en este mismo
   diff**, con un comentario que dice literalmente que es para que las extensiones lo usen
   — y `MapFeature+Loading.swift:35,60` sí lo usa. Dos espacios de cancel-ID para un
   reducer, y nada fuera de ese archivo puede cancelar la búsqueda.

5. **`MapFeature.swift:136-146` y `:167-174` escriben dos veces el mismo bloque**
   (switch de autorización → `currentLocation()` → `.locationResponse`). El follow-up de
   denegado solo existe en uno de los dos.

6. **`PaywallView.swift:163-174` y `SettingsView.swift:126-140`** son la misma fila de
   enlaces legales, ambas nuevas en este diff, **con el orden invertido** y fuentes/colores
   distintos. Dos definiciones del footer legal de la app, ya inconsistentes, y App Review
   mira las dos.

7. **Tests:** `OnboardingFeatureTests.swift:43-45`, `LocationPermissionTests.swift:84-86` y
   `LocationSearchTests.swift:63` redeclaran a mano exactamente lo que ya es el `testValue`
   del cliente (`LocationClient.swift:43-49`, `GeocodingClient.swift:41`). Borrarlos es
   equivalente en comportamiento.

### Simplificación

8. `AppFeature.swift:32-33,65-67` — `showOnboarding: Bool` + un `onboarding` state y un
   child reducer vivos para siempre. `@Presents var onboarding:` + `.ifLet` expresa lo
   mismo con una propiedad y libera el estado al terminar.
9. `AppFeature.swift:91,103,126` — la misma regla de "activar ads" escrita tres veces en
   tres codificaciones distintas, la tercera usando `bannerAdUnitID.isEmpty` como centinela
   de "aún no arrancados" (un `String` que ya codifica dos estados según su propio doc
   comment en `:16-19`). Un `shouldRunAds` derivado + un `syncAds(&state)` idempotente
   colapsa los tres brazos a `return syncAds(&state)`.
10. `OnboardingView.swift:46-51` — `Binding(get:set:)` a mano donde `@Bindable` +
    `@ObservableState` dan `$store.page.sending(\.pageChanged)`.
11. `OnboardingView.swift:119-133` — `@ViewBuilder` inerte (el cuerpo es una sola
    expresión) sobre un `VStack(spacing:)` de un único hijo. *Matiz:* el `switch` sí aporta
    dos identidades de vista, que es lo que hace que `.animation` haga cross-fade del botón.
12. `MapFeature+Loading.swift:22-34` y `:50-59` — la escalera
    `do / catch let as APIError / catch` escrita dos veces; un `apiEffect(_:into:)` deja
    cada loader en ~6 líneas.
13. `Localizable.xcstrings` — tres claves italianas casi iguales (`Attiva la posizione`,
    `Attiva posizione`, `Attiva la posizione per continuare`); las dos primeras se traducen
    igual en inglés.

### Eficiencia

14. `MapFeature.swift:159-161` — `.locationPermissionDenied` llama a `load(&state)`:
    una RPC a Supabase + decode + clustering de estaciones de Roma que el overlay tapa por
    completo, en **cada arranque** de un usuario denegado. `MapFeature.swift:147` añade
    encima un `.loadFavorites` → `stationsByIDs` igual de invisible.
15. `MapView.swift:162,173` — `store.priceTiers` es una **computed property**
    (`compactMap` + `sorted`) leída **una vez por annotation**: el body es O(N² log N) sobre
    el set de estaciones. Preexistente, pero este diff añade dos disparadores nuevos de body.
    **Fix barato:** `let tiers = store.priceTiers` una vez en `body`.
16. `MapView.swift:27,133-136` — el `@Environment(\.scenePhase)` leído en `MapView.body`
    hace que **todo** el body del mapa dependa de cada transición de scene phase (centro de
    control, app switcher, notificación…), y cada re-evaluación rehace `MapClustering.items`.
    Aislarlo en una hoja que no renderiza nada, o subirlo a `AppView`.
17. `LocationSearchView.swift:62` — `trimmingCharacters` en `body` en cada pulsación;
    `query.allSatisfy(\.isWhitespace)` no asigna.

**Verificado y descartado:** el `UserDefaults.standard.bool` síncrono de
`AppFeature.State.init()` **no** es un problema — `FuelMapApp.swift:14` construye el State
exactamente una vez (`@State` de la `App`, no dentro de un `body`); un round-trip a
cfprefsd antes del primer frame es más barato que la alternativa que sustituye. El
`load()` duplicado tras una búsqueda tampoco se materializa: `state.center` se escribe
*antes* de `load()`, así que el asentamiento de la cámara cae dentro del épsilon de
`MapFeature.swift:181-184`.

### Altitud

18. **El split `MapFeature+Loading` / `MapFeature+LocationSearch` es por presión de lint,
    no por dominio** — sus propias cabeceras lo dicen. Solo se movieron los *cuerpos* de los
    efectos; todos los `case` siguen en el switch monolítico, así que el acoplamiento no
    cambió, solo el recuento de líneas (y costó el `private` de `CancelID`). Mientras tanto,
    el concepto "contexto de ubicación" está repartido en 5 campos de `State`, 6 acciones,
    2 archivos y `OnboardingFeature`. Un `LocationContextFeature` hijo scopeado en
    `MapFeature` es lo que convertiría C-2, M-1 y M-2 en un solo cambio en vez de tres
    parches — y satisfaría `type_body_length` como efecto secundario, no como motivo.
19. `OnboardingStorage.swift` completo — TCA 1.25.5 (resuelto en `Package.resolved`) trae
    `@Shared(.appStorage("hasCompletedOnboarding"))`, el mecanismo estándar para exactamente
    esto, y es igual de síncrono (el razonamiento del primer frame sigue siendo válido).
    No es un error tener el cliente propio; es que hay una vía más corta.

---

## Hallazgos por severidad

### 🔴 Crítico

**C-1 · "Salta" no salta nada: el prompt de ubicación sale sin primer, y encima corre
contra el formulario UMP.**
`FuelMap/Features/Onboarding/OnboardingFeature.swift:50-51` · `FuelMap/Features/Map/MapFeature.swift:132-148` · `FuelMap/App/AppFeature.swift:121-127`

`skipTapped` termina el onboarding dejando el status en `.notDetermined`. Acto seguido
`AppView` renderiza `mainContent`, `MapView.onAppear` dispara `.map(.onAppear)`, y como
`didRequestLocation` es `false` se llama a `requestWhenInUse()` → **el alert del sistema
sale igualmente, sin la pantalla de priming que existe justo para eso** (HIG 9.2). Es
exactamente el mismo síntoma que el usuario reportó en la iteración anterior de esta fase
(PHASE_LOG, "el permiso de ubicación se pedía de golpe"), solo que ahora por la rama de
skip en vez de por el primer frame.

Peor: en ese mismo frame, `.onboarding(.delegate(.finished))` llama a `enableAds(&state)`
→ `adClient.requestConsent()` → formulario UMP + prompt ATT. Un usuario que pulsa "Salta"
recibe **tres flujos modales del sistema compitiendo a la vez**: alert de ubicación,
hoja GDPR y prompt ATT.

La ruta "Attiva posizione" **sí** está bien: `enableLocationTapped` espera el
`requestWhenInUse()` antes de emitir `.finished`, así que el alert termina antes de que
arranque UMP. El defecto es solo de la rama de skip.

**Fix:** que el onboarding sea el único dueño del prompt. `Delegate.finished` lleva el
`CLAuthorizationStatus` resuelto (y `skipTapped` lo pide también, o marca explícitamente
"no pedido"); `AppFeature` lo reenvía a `MapFeature`, que pone `didRequestLocation = true`
y salta directo a `currentLocation()` / `.locationPermissionDenied`. Alternativa mínima si
se quiere tocar poco: `skipTapped` también hace `await locationClient.requestWhenInUse()`,
que es lo que el usuario cree que está saltando (la copy dice "Salta", no "no me pidas el
permiso").

---

**C-2 · `locationPermissionDenied` significa tres cosas distintas, y por eso volver de
Ajustes deja de funcionar tras una búsqueda manual.**
`FuelMap/Features/Map/MapFeature.swift:32,166` · `FuelMap/Features/Map/MapFeature+LocationSearch.swift:42`

El nombre dice "permiso denegado", `MapView.swift:69-75` lo documenta como "sin ningún
contexto de ubicación", y `handleLocationSearchResponse` lo limpia con el sentido de "el
usuario ya eligió dónde mirar". Secuencia real y reproducible:

1. Usuario deniega → `locationPermissionDenied = true`, tarjeta bloqueante. ✅
2. Busca "Milano" → éxito → `locationPermissionDenied = false` (`+LocationSearch.swift:42`). ✅
3. Va a Ajustes y **concede** el permiso.
4. Vuelve a la app → `appBecameActive` → `guard state.locationPermissionDenied` (`:166`)
   corta → **nunca se recupera su ubicación real**, hasta el siguiente arranque en frío.

El `appBecameActive` existe precisamente para cerrar ese callejón sin salida (así está
justificado en PHASE_LOG), y la salida manual de la Parte 2 lo desactiva.

**Fix (el de altitud correcta):** una sola pieza de estado
`enum LocationContext { case unknown, denied, user(Coordinate), manual(Coordinate) }`.
`userLocation`, la semilla de `center`, `distanceOrigin`, el gate del overlay y el
re-chequeo de `appBecameActive` derivan de ella (re-chequear siempre que el caso no sea
`.user`; overlay en `.unknown`/`.denied`). Cierra también M-2 de paso.
**Fix mínimo si se prefiere no rediseñar ahora:** cambiar el guard de `appBecameActive`
a `guard state.userLocation == nil`.

---

**C-3 · La tarjeta "bloqueante" no bloquea nada para VoiceOver.**
`FuelMap/Features/Map/LocationPromptOverlay.swift:19-24` · `FuelMap/Features/Map/MapView.swift:68-81`

El `.overlay` tapa visualmente y captura los toques (una `Shape` rellena sí es
hit-testable), pero **no toca el árbol de accesibilidad**. Un usuario de VoiceOver sigue
recorriendo por debajo los pins del mapa, los 5 controles flotantes y toda la
`FiltersView` del `safeAreaInset` — justo lo que la decisión de producto quería impedir
("no tiene sentido dejar ajustar filtros si no ve nada en pantalla"). El foco además
puede aterrizar fuera de la tarjeta sin que nada lo devuelva.

**Fix:** `.accessibilityAddTraits(.isModal)` en la raíz del overlay, y
`.accessibilityHidden(store.locationPermissionDenied)` sobre el contenido de debajo (o
presentar la tarjeta con `.fullScreenCover`, que ya gestiona el modal AX y de paso resuelve
el punto 14 de eficiencia: el `MKMapView` deja de estar vivo bajo un blur compuesto cada
frame).

---

### 🟠 Alto

**A-1 · `AppFeature.onAppear` no es idempotente y `AppView` puede emitirlo dos veces en
el primer lanzamiento.**
`FuelMap/App/AppView.swift:16-24` · `FuelMap/App/AppFeature.swift:70-84`

El `.onAppear` está colgado de un `Group` cuyo único hijo es un `_ConditionalContent`.
Cuando `showOnboarding` pasa de `true` a `false`, la rama se sustituye; si SwiftUI
propaga el modificador a la rama (que es exactamente para lo que existe `Group`), el
`.onAppear` vuelve a dispararse sobre `mainContent`.

**No lo he podido verificar en runtime** (headless), así que lo dejo marcado como "a
comprobar" — pero el efecto sí es objetivamente no idempotente y merece el guard
independientemente de cómo lo resuelva SwiftUI: un segundo `.onAppear` reejecuta
`refreshEntitlement()` → `.entitlementLoaded(false)` → y ahora `showOnboarding` ya es
`false`, así que pasa el guard y llama a `enableAds` **por segunda vez** →
`requestConsent()` + `AdSDK.start()` duplicados (ATT concurrente es comportamiento no
definido), además de reiniciar el listener de `entitlementUpdates`.

**Fix:** un `didAppear` en `State` con `guard !state.didAppear`, exactamente el patrón que
`MapFeature.swift:133` ya usa con `didRequestLocation`. Dos líneas y la pregunta desaparece.
Ningún test cubre hoy un segundo `.onAppear`.

**A-2 · `SKAdNetworkItems` solo declara la red de Google.**
`project.yml:80-84`

`cstr6suwn9.skadnetwork` es la red propia de Google. AdMob sirve además compradores de
terceros vía Open Bidding, y Google publica una lista de ~90 identificadores que hay que
pegar en `Info.plist` **aunque no se use mediation** (el comentario del diff asume que sin
mediation basta con uno; no es así). Con un solo ID, la atribución SKAdNetwork de todos
los demás compradores falla → menos demanda y eCPM más bajo, de forma invisible.
**Fix:** pegar la lista completa que publica Google en su doc de AdMob para iOS.

**A-3 · El CTA secundario de la tarjeta falla WCAG AA en modo claro.**
`FuelMap/Features/Map/LocationPromptOverlay.swift:62-71`

`Color(.brandTint)` (#0091FF claro) sobre `Color(.surfaceSecondary)` (#F2F3F7) da
**2,92:1**. El texto es `.fmHeadline.weight(.semibold)` = 17pt semibold, que **no** cuenta
como "large text" (hace falta 18pt, o 14pt bold), así que el umbral aplicable es 4,5:1.
En oscuro sí pasa (7,39:1). Comprobado sobre los valores reales de los colorsets.
**Fix:** usar `brandPrimary` en vez de `brandTint` para este texto, o un relleno más
oscuro. Referencia: el CTA primario sí pasa (4,61:1 claro / 4,75:1 oscuro).

**A-4 · Dos interruptores distintos para la misma decisión Debug/Release en ads.**
`FuelMap/Core/Ads/AdClient.swift:28-37` (`#if DEBUG`) · `project.yml:62-69` (`configs.Release`)

Coinciden hoy solo porque existen exactamente dos configuraciones cuyos nombres encajan.
En cuanto se añada una config Beta/TestFlight — el siguiente paso obvio de RELEASE-001 —
rompen **de forma asimétrica**: `#if DEBUG` es falso → ad units **reales**, mientras
`GAD_APPLICATION_IDENTIFIER` cae al `settings.base` → App ID **de test**. Unidades reales
bajo un App ID de test: sin fill en runtime, e invisible desde Debug.
**Fix:** una sola fuente de verdad en `project.yml` — declarar también
`GAD_BANNER_UNIT_ID`/`GAD_DETAIL_UNIT_ID` en `settings.base` + `configs.Release`, exponerlos
por `info.properties` y leerlos con `Bundle.main.object(forInfoDictionaryKey:)`. El
`#if DEBUG` desaparece.

**A-5 · Las tres vistas nuevas se rompen con Dynamic Type en tamaños de accesibilidad.**
`OnboardingView.swift:87-115` · `LocationPromptOverlay.swift:26-78` · `LocationSearchView.swift:22-67`

Ninguna es scrollable y las tres son layouts fijos con un badge de tamaño constante
(96pt / 88pt) más título + subtítulo + CTA de 50pt. En AX3+ el contenido no cabe: las
páginas de un `TabView` no hacen scroll, así que el texto se recorta sin recurso. La
tarjeta del overlay además está dentro de un `Rectangle().ignoresSafeArea()`, de modo que
al crecer se mete bajo la Dynamic Island / el home indicator (HIG 1.2).
**Fix:** envolver el contenido de cada una en un `ScrollView`, y reducir el badge cuando
`dynamicTypeSize.isAccessibilitySize`.

**A-6 · Cualquier fallo de geocoding se reporta como "no hay resultados".**
`FuelMap/Features/Map/MapFeature+LocationSearch.swift:24-26`

```swift
} catch {
    await send(.locationSearchResponse(.failure(.noResults)))
}
```
Sin red, con `MKLocalSearch` limitado por rate o con un error de servidor, el usuario lee
"Nessun risultato per questa ricerca." y concluye que su ciudad no existe. Es la **única**
salida de un usuario que ya denegó el permiso, así que el diagnóstico equivocado lo deja
atrapado. `GeocodingError` solo tiene un caso, así que la información se pierde ya en el
tipo.
**Fix:** añadir `case network`/`case cancelled` a `GeocodingError`, mapear en el
`liveValue` (`MKError.Code`), y dar una copy distinta para "no hay conexión".

**A-7 · `UIApplication.shared.open` en la vista, teniendo `@Dependency(\.openURL)`.**
`FuelMap/Features/Map/MapView.swift:11,265-270`

Mete `import UIKit` en un `MapView` que no lo tenía y, sobre todo, deja **el único camino
que existe para revertir un permiso denegado** fuera del reducer, donde
`LocationPermissionTests` no puede alcanzarlo. `StationDetailFeature.swift:43,108` ya hace
el mismo trabajo por la dependencia.
**Fix:** acción `.openLocationSettingsTapped` → `.run { _ in await openURL(...) }`; el
overlay envía una acción como cualquier otro control.

---

### 🟡 Medio

**M-1 · La presentación de la hoja de búsqueda está repartida entre tres dueños y se
cierra por inferencia.**
`MapView.swift:25,107-115` · `MapFeature.swift:44-45` · `LocationSearchView.swift:70-74`

`guard wasSearching, !nowSearching, errorMessage == nil` reconstruye "la búsqueda salió
bien" a partir de dos campos, cuando `handleLocationSearchResponse` tiene el `.success`
literalmente en la mano. Depende además de que ambos campos lleguen en la **misma**
actualización de vista: si alguna vez se separan, la hoja se cierra sobre un fallo.
Síntoma colateral ya presente: `locationSearchError` no se limpia al cerrar, así que
reabrir la hoja muestra de entrada el error de la búsqueda anterior.
**Fix:** que el reducer sea dueño de la presentación (`isShowingLocationSearch` o
`@Presents`), puesto a `false` en la rama `.success`. Desaparecen el `@State`, el
`onChange` y el `@Environment(\.dismiss)`, y la búsqueda pasa a ser testeable de punta a
punta. Mover también `@State private var query` al estado: hoy una búsqueda fallida
conserva lo tecleado solo porque la hoja da la casualidad de seguir abierta.

**M-2 · El caso "no sé dónde está el usuario" no tiene representación en el estado.**
`MapFeature.swift:143-144,140,170`

El `default:` manda `.locationResponse(nil)` tanto para `.notDetermined` como — vía
`try?` — para un `currentLocation()` que falla **con el permiso concedido**. Ese estado no
levanta ninguna bandera: sin overlay, sin error, mapa aparcado en silencio sobre
`.italyDefault` mostrando gasolineras de Roma como si fueran las de al lado. Se cierra con
el `LocationContext` de C-2.

**M-3 · `.presentationDetents([.medium])` + teclado tapa el botón "Cerca".**
`MapView.swift:113`

Con el teclado levantado (la vista se autoenfoca en `onAppear`) y un detent medium, en
iPhone SE/13 mini el CTA queda debajo del teclado. El resto de hojas del proyecto usan
`[.medium, .large]`.
**Fix:** `[.medium, .large]`, o confiar solo en `.onSubmit`.

**M-4 · VoiceOver pierde la etiqueta del botón durante la búsqueda, y el error no se
anuncia.**
`LocationSearchView.swift:46-61,39-44`

Mientras `isSearching`, el label del botón es un `ProgressView` desnudo: VoiceOver lee un
botón sin nombre. Y el mensaje de error aparece como texto suelto sin notificación, así
que un usuario de VoiceOver no se entera de que la búsqueda falló.
**Fix:** `.accessibilityLabel("Cerca")` + `.accessibilityValue(...)` en el botón, y
`AccessibilityNotification.Announcement` (o `.accessibilityFocused`) al aparecer el error.

**M-5 · El page control es invisible para VoiceOver y casi invisible en claro.**
`OnboardingView.swift:72-83`

`.accessibilityHidden(true)` deja al usuario de VoiceOver sin ninguna noción de en qué
página está ni de cuántas hay, en una vista cuya navegación principal es el swipe. Y el
punto inactivo usa `Color(.separator)` (#D6DAE2) sobre `surface`: **1,40:1**, muy por
debajo del 3:1 que WCAG pide a un componente de UI no textual.
**Fix:** exponer el control como un elemento con
`.accessibilityValue("Pagina 1 di 2")` en vez de ocultarlo, y usar `separatorStrong` o
`textTertiary` para el punto inactivo.

**M-6 · "Salta" se oculta con `.opacity(0)` — sigue en el árbol de accesibilidad y
contradice la documentación.**
`OnboardingView.swift:64-65`

`.opacity(0)` no saca la vista del árbol AX; con `.disabled(true)` VoiceOver la anuncia
como "Salta, atenuado". Además la misma condición está escrita dos veces y negada. Y de
fondo: el doc comment del archivo (`:11`) y `SYSTEM_MAP.md:85` dicen "siempre saltable",
pero en la página 2 no hay ninguna salida visible — hay que descubrir que se puede volver
con swipe.
**Fix:** renderizarlo condicionalmente (`if store.page == .welcome`), o —mejor, y coherente
con lo documentado— dejarlo visible siempre.

**M-7 · Los criterios de trim divergen entre vista y reducer; `"\n"` deja la hoja muerta.**
`LocationSearchView.swift:62,78` (`.whitespaces`) vs `MapFeature+LocationSearch.swift:16`
(`.whitespacesAndNewlines`)

Una query que sea solo salto de línea (pegada, por ejemplo) pasa el `.disabled`, pasa el
guard de `submit()`, dispara `.locationSearchSubmitted` y el reducer devuelve `.none`:
hoja abierta, sin spinner, sin error, sin nada. `Core/Foundation/String+NilIfEmpty.swift:11`
ya es exactamente ese guard y no se usa en ninguno de los tres sitios.

**M-8 · Trabajo de red tirado a la basura en el arranque de un usuario denegado.**
`MapFeature.swift:159-161,147`

Ver punto 14 de eficiencia: una RPC `nearby_stations` + un `stations_by_ids` cuyo
resultado la tarjeta bloqueante tapa por completo, en cada arranque.
**Ojo:** `LocationPermissionTests.swift:31,51` afirman hoy esa llamada, así que arreglarlo
implica actualizarlos.

**M-9 · Dos features son dueñas del mismo prompt del sistema.**
`OnboardingFeature.swift:53-62` · `MapFeature.swift:132-148`

Es idempotente a nivel de CoreLocation (`LocationClient.swift:87` corta si el status ya
está resuelto), así que no hay doble alert — pero el onboarding **descarta** el status que
acaba de obtener y `MapFeature` lo vuelve a pedir. El acoplamiento es frágil: la secuencia
solo funciona porque `AppView` mete `MapView` en la rama `else`; cambiarlo a un `ZStack`
reintroduce silenciosamente el prompt por debajo del onboarding. Raíz de C-1.

**M-10 · Dos espacios de cancel-ID para un mismo reducer.** `MapFeature+LocationSearch.swift:13`.
Ver reuso #4.

**M-11 · `PrivacyInfo.xcprivacy`: sintaxis y categorías correctas, dos puntos a revisar
antes de submission.**
`FuelMap/PrivacyInfo.xcprivacy`

Confirmado que el archivo **sí entra en el bundle** (`PrivacyInfo.xcprivacy in Resources`
en el `.pbxproj` generado) y que las categorías existen y encajan con lo que el código
hace: `PreciseLocation`/AppFunctionality/no-linked/no-tracking para la ubicación que va a
las RPC de Supabase, `DeviceID`/tracking/ThirdPartyAdvertising para AdMob, y
`UserDefaults` + `CA92.1` para el flag de onboarding (correcto: es el único uso directo de
`UserDefaults` en la app). Dos matices:
- `NSPrivacyTracking` a `true` con `NSPrivacyTrackingDomains` como array **vacío**. Es
  defendible (los dominios los declara el manifest embebido de Google), pero Apple pide
  los dominios cuando declaras tracking; conviene confirmarlo o listar los de AdMob.
- `LocationClient.swift:80` usa `kCLLocationAccuracyHundredMeters`; con esa precisión,
  `NSPrivacyCollectedDataTypeCoarseLocation` describe mejor lo recogido que
  `PreciseLocation` (declarar de más también tiene coste en la ficha de privacidad).

**M-12 · Huecos de cobertura en los tests nuevos.**
- **Nadie verifica que `onboardingStorage.setCompleted()` se llame.** `testValue.setCompleted`
  es un no-op (`OnboardingStorage.swift:33`), así que una regresión que no persista el flag
  —onboarding en cada arranque— pasaría verde. Dejar `hasCompleted: { true }` pero poner
  `setCompleted: unimplemented(...)` y sobreescribirlo con un spy en el test de `finished`.
- `store.exhaustivity = .off` en 5 de los 7 tests nuevos de ubicación
  (`LocationPermissionTests.swift:27,47,69`, `LocationSearchTests.swift:27,48`). Es el patrón
  del repo, pero significa que ningún test afirma el conjunto completo de mutaciones.
- Sin test de `cancelInFlight` en la búsqueda (dos submits seguidos), ni del cierre de la
  hoja (imposible hoy, ver M-1), ni de un segundo `.onAppear` en `AppFeature` (A-1), ni del
  guard de `appBecameActive` tras una búsqueda manual — que es justamente C-2.

---

### 🔵 Bajo / nits

1. `AppFeature.swift:32-33` — `@Presents var onboarding:` en vez de `Bool` + state
   permanente (simplificación #8).
2. `AppFeature.swift:91,103,126` — un `syncAds(&state)` idempotente en vez de tres guards
   (simplificación #9).
3. `OnboardingView.swift:46-51` — `$store.page.sending(\.pageChanged)` (simplificación #10).
4. `OnboardingView.swift:119-133` — `@ViewBuilder` inerte + `VStack` de un hijo
   (simplificación #11).
5. `MapView.swift:162,173` — hoistear `store.priceTiers` fuera del `ForEach` (eficiencia #15).
6. `MapView.swift:27,133-136` — aislar la observación de `scenePhase` (eficiencia #16).
7. `OnboardingFeatureTests.swift:43-45`, `LocationPermissionTests.swift:84-86`,
   `LocationSearchTests.swift:63` — overrides `unimplemented` que solo repiten el `testValue`
   del cliente (reuso #7).
8. **Inconsistencia documental dentro del propio `PHASE_LOG.md`:** la sección *Developer* de
   RELEASE-001 F1 sigue diciendo que `showOnboarding` se resuelve "en `.onAppear` … no en
   `init()`"; la entrada *Fix* posterior lo corrige. Conviene reconciliar la primera para
   que no se lea como la decisión vigente.
9. `Localizable.xcstrings` — varias claves **nuevas** entran con
   `"extractionState": "stale"` (`Attiva la posizione`, `Continua`,
   `Nessun risultato per questa ricerca.`, `Trova il distributore più conveniente`,
   `Es. Milano, Barcellona…`). Confirmar con un build que están realmente enganchadas.
   *(Comprobado aparte: las 11 claves nuevas sí tienen las tres locales it/es/en. Las 14
   claves del catálogo sin es/en son preexistentes y de preview/verbatim.)*

---

## ⚫ Deuda diferida de RESTYLE-001 — ambas siguen vivas

Registrada en `PHASE_LOG.md:437` ("Diferido (deuda menor): ring hairline de elevación en
oscuro (M-4), dedup de `separator`, nits varios").

**D-1 · Ring de elevación en modo oscuro (M-4) — sigue viva, y este diff la hace más
visible. Recomiendo arreglarla ahora.**
`FuelMap/DesignSystem/Elevation.swift:11-13,36-45`

El doc del archivo dice "El hairline/ring se aplica aparte en cada componente", pero
**ningún** componente aplica un hairline dependiente de `colorScheme`: el único
`@Environment(\.colorScheme)` del proyecto está dentro del propio `ElevationModifier`
(`:28`), y los `strokeBorder` que existen (`StationPin.swift:74,85,109`,
`ClusterPin.swift:41,45,61`) son bordes de *tier*, no de elevación. En oscuro,
`surfaceElevated` (#1A1F29) sobre `surface` se distingue casi solo por una sombra negra
que a esas luminancias es prácticamente invisible → las superficies flotantes pierden el
borde.

Por qué ahora: este diff **añade** superficies elevadas grandes —la tarjeta de
`LocationPromptOverlay.swift:75-76` (`surfaceElevated` + `.elevation(.e3)`) sobre un blur—
donde la falta de definición de borde es mucho más evidente que en un pin de 30pt.
**Fix (~10 líneas):** que `ElevationModifier` aplique también un
`.overlay(shape.strokeBorder(Color(.separator), lineWidth: 0.5))` cuando `scheme == .dark`,
lo que exige parametrizar el modifier con la forma (`elevation(_:in:)`), o exponer un
`.elevatedSurface(_:in:)` que combine fondo + sombra + ring.

**D-2 · Dedup de `separator` — sigue viva y ha crecido a 6 llamadas. Recomiendo arreglarla
ahora (es de 15 minutos).**

`Rectangle().fill(Color(.separator)).frame(height: 1)` está en:
`AppView.swift:35`, `FavoritesView.swift:58`, `StationListView.swift:64`,
`StationDetailView.swift:142`, `StationDetailView.swift:201`, `PaywallView.swift:181`.
Las de `FavoritesView` y `StationListView` son `private var separator` **idénticas byte a
byte** (mismo `.padding(.leading, 60)`), copiadas literalmente. Las dos de
`StationDetailView` comparten `.padding(.horizontal, Spacing.s5)`.

En descargo del diff: **no añade ninguna copia nueva** — es deuda que sigue igual, no una
regresión. Pero el `60` mágico repetido en dos archivos ya es un punto de divergencia real.
**Fix:** un `HairlineDivider(leadingInset: CGFloat = 0)` en `SheetComponents.swift`, donde
ya viven el resto de componentes compartidos de hoja.

---

## Lo que está bien hecho

- **La corrección del bug del primer frame es la correcta y está bien argumentada.** Resolver
  `showOnboarding` en `State.init()` de forma síncrona, con el razonamiento explícito de por
  qué el entitlement de StoreKit *sí* espera a `.onAppear` y esto no, es exactamente el nivel
  de decisión que quiero ver documentado en el código
  (`AppFeature.swift:25-31`). El test `appFeature_state_resolvesShowOnboardingSynchronouslyAtInit`
  ancla la regresión sin enviar ninguna acción — la forma más limpia de fijarla.
- **La concurrencia Swift 6 está limpia.** `OnboardingStorage` y `GeocodingClient` son
  `Sendable` con closures `@Sendable`, los efectos nuevos van todos por `.run` con
  `.cancellable(cancelInFlight:)`, `LocationCoordinator` mantiene el aislamiento
  `@MainActor` + `LockIsolated` para la lectura síncrona, y no hay ni un `var` compartido
  cruzando dominios. Cero data races, cero force-unwraps nuevos, cero retain cycles.
- **La colocación del `.overlay` después de `.safeAreaInset` es correcta y no obvia**, y el
  comentario de `MapView.swift:69-74` explica exactamente por qué — que es la clase de nota
  que evita que alguien lo "arregle" seis meses después. Igual de bueno el criterio de
  retirar la rama del banner al meter la tarjeta, en vez de acumular los dos mensajes.
- **La ruta "Attiva posizione" del onboarding es un priming de manual** (HIG 9.2): explica
  antes de pedir, y el reducer termina igual conceda o deniegue. El defecto de C-1 está en
  la rama de skip, no en esta.

---

## Action items

### Bloqueantes (antes de TestFlight)
- [ ] **ios-developer** — C-1: hacer que el onboarding sea el único dueño del prompt de
      ubicación; `Delegate.finished` lleva el `CLAuthorizationStatus` y `MapFeature` no
      vuelve a pedirlo. Elimina de paso la carrera skip → alert + UMP + ATT.
- [ ] **ios-developer** — C-2: sustituir `locationPermissionDenied: Bool` por
      `LocationContext` (o, como mínimo, cambiar el guard de `appBecameActive` a
      `state.userLocation == nil`).
- [ ] **ios-developer** — C-3: `.accessibilityAddTraits(.isModal)` + ocultar el contenido
      de debajo mientras el overlay está presente.
- [ ] **ios-developer** — A-1: `didAppear` en `AppFeature.State`, patrón
      `MapFeature.didRequestLocation`. Y verificar en simulador si el `.onAppear` del
      `Group` se emite dos veces.
- [ ] **ios-developer** — A-2: lista completa de `SKAdNetworkItems` de Google en `project.yml`.
- [ ] **ios-developer** — A-3: subir el contraste del CTA secundario del overlay (2,92:1 en claro).
- [ ] **ios-developer** — A-4: unificar el switch Debug/Release de ads en `project.yml`.
- [ ] **ios-developer** — A-5: `ScrollView` en las tres vistas nuevas + badge adaptativo en
      tamaños de accesibilidad.
- [ ] **ios-developer** — A-6: `GeocodingError` con caso de red y copy distinta.
- [ ] **ios-qa** — M-12: test de que `setCompleted()` se llama al terminar el onboarding
      (con `setCompleted: unimplemented` por defecto + spy); test del guard de
      `appBecameActive` tras búsqueda manual (ancla C-2); test de un segundo `.onAppear`
      (ancla A-1).

### No bloqueantes (recomendados en esta fase)
- [ ] **ios-developer** — A-7 + M-1: mover a `@Dependency(\.openURL)` y dar al reducer la
      propiedad de la hoja de búsqueda (cierra también el error rancio al reabrir).
- [ ] **ios-developer** — M-3, M-4, M-5, M-6, M-7: detents, labels de VoiceOver, contraste
      y accesibilidad del page control, "Salta" visible, unificar el trim con `nilIfEmpty`.
- [ ] **ios-developer** — D-1 y D-2: cerrar la deuda de RESTYLE-001. Las dos son baratas y
      D-1 ya está afectando a una superficie nueva.
- [ ] **ios-developer** — Reuso #1/#2/#6: `FMButtonStyle`, `BrandIconBadge` y `LegalLinks`
      en `DesignSystem/`. Son 4 copias del CTA nuevas en este diff; es el momento.
- [ ] **ios-developer** — M-8 + eficiencia #15/#16: no cargar bajo el overlay, hoistear
      `priceTiers`, aislar `scenePhase`.
- [ ] **ios-architect** — Altitud #18: evaluar un `LocationContextFeature` hijo. Es lo que
      convierte C-2, M-1 y M-2 en un solo cambio, y sustituye un split de archivos motivado
      por `type_body_length` por uno motivado por el dominio.

### Verificación manual pendiente (acumulada de esta fase y las anteriores)
- [ ] Instalación limpia: las 2 páginas del onboarding, swipe, page control, y que el
      permiso **no** salga en la página 1 ni de golpe al saltar (C-1).
- [ ] Que el blur bloquee de verdad mapa, controles y filtros — con VoiceOver activado (C-3).
- [ ] Que "Attiva posizione" abra Ajustes y que volver con el permiso concedido recupere la
      ubicación, **también después de haber buscado una ciudad a mano** (C-2).
- [ ] Build de Release en dispositivo: que `GADApplicationIdentifier` resuelva el App ID
      real (la sustitución de `$(GAD_APPLICATION_IDENTIFIER)` en el `Info.plist`) y que el
      banner de producción reciba fill.
