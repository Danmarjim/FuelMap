# PRD: FuelMap

Estado: Borrador
<!-- Cambia a "Aprobado" cuando Dani dé el OK. Es la puerta 1: sin esto no se crean tareas. -->

> Este PRD describe lo que FuelMap **hace hoy** (rama `main`, octubre de 2026) y es el punto de
> partida del flujo de la plantilla. La spec original con la que se construyó la app es
> `.claude/prd/PRD-001-fuelmap.md` (histórica, no se actualiza). El trabajo nuevo entra por
> **Siguientes funcionalidades** (sección 12).

## 1. Problema

Los conductores en Italia no tienen una forma rápida, moderna y fiable de encontrar la gasolinera más
barata cerca de ellos. Los datos oficiales existen (MIMIT Open Data, actualizados a diario), pero las
apps que los muestran tienen datos percibidos como antiguos y una UX anticuada.

## 2. Usuario objetivo

- Conductores particulares en Italia sensibles al precio del carburante (commuters, familias,
  autónomos con vehículo), con iPhone.
- La usan antes de repostar o en ruta: abren la app, ven precios en el mapa y eligen estación.
- Hoy usan Prezzi Benzina, el portal Osservaprezzi del MIMIT o la gasolinera de siempre.

## 3. Propuesta de valor

Precios oficiales del MIMIT de cada día, sobre un mapa nativo rápido y claro: ver la gasolinera más
barata del radio en segundos. Gratis con anuncios; pago único para quitarlos.

## 4. Competencia

| App | Qué hace bien | Qué le falta | Precio |
|---|---|---|---|
| Prezzi Benzina | Muy conocida, cobertura amplia | Datos percibidos como antiguos, UX anticuada | Gratis con anuncios |
| Osservaprezzi Carburanti (MIMIT) | Fuente oficial | Portal web, no pensado para buscar en movilidad | Gratis |

Diferenciación: UX nativa SwiftUI + MapKit, velocidad, datos oficiales frescos a diario y tiers de
precio legibles de un vistazo.

## 5. Lo que hace la app hoy

### Mapa y búsqueda
- [x] Mapa (MapKit) centrado en la ubicación del usuario con un pin por estación y el precio del
      combustible seleccionado; zoom inicial ≈ 5 km.
- [x] Clustering de pins por zoom; cada cluster muestra el precio más barato que contiene.
- [x] Tiers de precio (terciles del radio) con color y símbolo, legibles para daltónicos.
- [x] Marca visual de la estación más barata del radio.
- [x] Capas de mapa: estándar, híbrido y satélite.
- [x] Recarga al mover el mapa (con debounce) y al cambiar filtros.
- [x] Búsqueda manual de ciudad o dirección para centrar el mapa.

### Filtros y lista
- [x] Combustible: benzina, gasolio, GPL, metano, HVO.
- [x] Solo self-service (sí/no).
- [x] Radio: 1, 3, 5, 10 o 20 km (5 km por defecto).
- [x] Lista de estaciones del radio ordenable por precio o por distancia.

### Detalle de estación
- [x] Nombre, marca (logo o monograma), dirección y todos los combustibles con precio self/servito.
- [x] Antigüedad del precio; aviso si tiene más de 48 h.
- [x] "Indicaciones" con selector de app: Apple Maps, Google Maps o Waze (si están instaladas).
- [x] Añadir o quitar de favoritos.

### Favoritos
- [x] Lista de favoritos con precio en vivo del combustible activo, ordenada por precio (desempate
      por distancia), con la más barata marcada y "n/d" si no vende ese combustible.

### Primer uso y permisos
- [x] Onboarding de 2 pantallas (propuesta de valor + explicación del permiso de ubicación),
      navegable por swipe o botón y siempre saltable.
- [x] Sin permiso de ubicación ni ciudad buscada: el mapa se difumina y una tarjeta ofrece activar el
      permiso en Ajustes o buscar una ciudad. Al volver de Ajustes se recupera la ubicación.

### Ajustes y premium
- [x] Hoja de ajustes: comprar premium, restaurar compras, atribución IODL 2.0, privacidad y
      condiciones, versión.
- [x] Paywall con precio de App Store, compra, restaurar y estados de carga/error/pendiente/éxito.

### Transversal
- [x] Idiomas: italiano (base), español e inglés.
- [x] Modo claro y oscuro, Dynamic Type, VoiceOver y Reduce Motion.
- [x] Solo iPhone, vertical, iOS 17+.

### Todavía no
- Publicación en App Store (FM-14 / RELEASE-001 Fase 4 en `.claude/plan.md`): textos del permiso de
  ubicación y ATT solo en italiano, App Privacy, metadatos, capturas, TestFlight y compra real en
  sandbox sin verificar.
- España y otros países (la base de datos ya tiene columna `country`; app y sync son solo Italia).
- Widget, historial de precios y alertas.

## 6. Pantallas y flujo

1. **Onboarding** (solo primer lanzamiento) → bienvenida → permiso de ubicación → mapa.
2. **Mapa** → pins y clusters; barra de filtros abajo; controles flotantes (lista, favoritos, capas,
   buscar, ajustes); banner de anuncio fuera del área del mapa.
   - Pin → **Detalle de estación** (hoja) → Indicaciones → app de navegación.
   - Lista → **Lista de estaciones** (hoja) → detalle.
   - Favoritos → **Favoritos** (hoja) → detalle.
   - Buscar → **Búsqueda de ciudad** (hoja) → mapa centrado.
   - Ajustes → **Ajustes** (hoja) → **Paywall**.
3. Sin ubicación → **tarjeta de ubicación** sobre el mapa → Ajustes del sistema o búsqueda de ciudad.

## 7. Datos

- **Estaciones y precios**: MIMIT Open Data (licencia IODL 2.0). Un workflow de GitHub Actions
  (`sync-mimit.yml`, 06:30 UTC con reintentos 09:30 y 12:30) descarga los CSV y hace upsert en
  Supabase (PostgreSQL + PostGIS). La app solo lee, vía RPC (`nearby_stations`, `station_detail`,
  `stations_by_ids`) con la clave anónima y RLS de solo lectura.
- **Favoritos**: SwiftData, solo en el dispositivo. Se pierden al reinstalar (no hay iCloud).
- **Onboarding completado**: `UserDefaults`.
- **Premium**: lo resuelve StoreKit 2 a partir de las transacciones de Apple; se recupera con
  "Restaurar compras" tras reinstalar.
- Sin cuentas ni login.

## 8. Monetización

- Modelo: gratis con anuncios (AdMob, banner en el mapa y en el detalle) + pago único sin anuncios.
- Premium quita los anuncios. No desbloquea funcionalidades.
- Producto de StoreKit (no consumible; debe coincidir con `PurchaseClient.premiumProductID`,
  `FuelMap.storekit` y App Store Connect):
  - `com.danmarjim.fuelmap.premium.noads` (~3,99 €)
- Pendiente de Dani: aceptar el Paid Applications Agreement y crear el producto en App Store Connect.

## 9. Métricas

La app no tiene analytics ni crash reporting propios. Las métricas objetivo de PRD-001 siguen
vigentes pero hoy no se pueden medir desde la app:

- Tiempo hasta ver precios en el mapa < 3 s (p50).
- Retención D7 ≥ 20 %.
- Sesiones sin crash ≥ 99,5 % (se podrá ver en App Store Connect tras publicar).
- Valoración en App Store ≥ 4,3.

## 10. Privacidad

Política publicada en `https://danmarjim.github.io/FuelMap/privacy-policy.html` (fuente:
`docs/privacy-policy.html`, it/es/en).

- **Ubicación**: con permiso, se envía a Supabase solo al buscar estaciones en el radio; no se guarda
  ni se asocia a un perfil.
- **Identificador publicitario**: AdMob, tras consentimiento GDPR (Google UMP) y ATT si el sistema lo
  requiere. Sin consentimiento, anuncios no personalizados.
- **Compras**: las gestiona Apple; la app no recibe datos de pago.
- Favoritos y preferencias solo en el dispositivo. Sin cuentas.
- `FuelMap/PrivacyInfo.xcprivacy` es un borrador razonado: revisar antes de enviar a revisión.

## 11. Riesgos y preguntas abiertas

- El MIMIT bloquea IPs de cloud de forma intermitente: el sync tiene reintentos, pero un día sin sync
  deja precios de ayer.
- Supabase free tier: pausa por inactividad (mitigada por el sync diario) y límite de egress a escala.
- Confirmar que `0002_station_detail.sql` está aplicada en Supabase.
- ¿Basta un sync al día o conviene dos? Revisar con datos en producción.
- "FuelMap" es nombre de trabajo: confirmar disponibilidad en App Store.
- Sin analytics, no hay forma de medir activación ni embudo hasta la compra.

## 12. Siguientes funcionalidades

<!-- Vacía a propósito. Añade aquí lo siguiente que quieras construir; con el PRD en "Aprobado",
     la skill spec-to-tasks lo convierte en issues. -->
