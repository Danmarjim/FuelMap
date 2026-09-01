//
//  MapFeature.swift
//  FuelMap
//
//  Created on 04/06/2026.
//

import ComposableArchitecture
import CoreLocation
import Foundation
import UIKit

/// Feature principal: mapa con gasolineras y precios (RFC §6.2).
@Reducer
struct MapFeature {
    @ObservableState
    struct State: Equatable {
        /// Centro actual del mapa (usado para consultar la API).
        var center: Coordinate = .italyDefault
        /// Ubicación del usuario (referencia para distancias). Fijada al arrancar.
        var userLocation: Coordinate?
        /// Apertura del mapa (latitudeDelta) para el zoom de la cámara.
        var span: Double = MapDefaults.span
        var filters = FiltersFeature.State()
        var stations: [Station] = []
        var isLoading = false
        @Presents var detail: StationDetailFeature.State?
        var errorMessage: String?
        /// Objetivo de recentrado one-shot (p. ej. ubicación del usuario al arrancar).
        var recenter: Coordinate?
        var didRequestLocation = false
        /// El usuario denegó (o tiene restringido) el permiso de ubicación: se muestra
        /// Roma por defecto y un banner con acceso directo a Ajustes.
        var locationPermissionDenied = false
        var sortOrder: StationSort = .price
        /// Tipo de mapa (estándar / híbrido / satélite) — control de capas.
        var mapStyle: MapStyleOption = .standard
        /// Estación más barata del conjunto actual (para destacarla en el mapa).
        var cheapestStationID: Int?
        /// Favoritos persistidos (id + nombre + coordenada). Fuente de la lista.
        var favorites: [FavoriteStationInfo] = []
        /// Precios en vivo de los favoritos para el combustible activo (filtrado en servidor).
        /// Puede no incluir un favorito si no vende ese combustible.
        var favoriteStations: [Station] = []
        var isLoadingFavoritePrices = false
        var isSearchingLocation = false
        var locationSearchError: String?
        /// La hoja de búsqueda la abre/cierra el reducer, no un `@State` de la vista:
        /// así el cierre en éxito es explícito (`handleLocationSearchResponse`), no
        /// inferido de `isSearching`+`error` cambiando en el mismo frame (review
        /// RELEASE-001 F1-F2, M-1).
        var isShowingLocationSearch = false

        /// Elementos del mapa: estaciones individuales o clusters según el zoom (FM-15).
        var mapItems: [MapItem] {
            MapClustering.items(stations: stations, span: span)
        }

        /// Umbrales de color de precio (terciles) del set actual (FM-18).
        var priceTiers: PriceTiers {
            PriceTiers(prices: stations.compactMap { $0.cheapest?.price })
        }

        /// Origen para calcular distancias: la ubicación del usuario; si no hay, el centro.
        var distanceOrigin: Coordinate { userLocation ?? center }

        /// Estaciones ordenadas según `sortOrder` (para la lista).
        var sortedStations: [Station] {
            switch sortOrder {
            case .price:
                return stations.sorted {
                    ($0.cheapest?.price ?? .greatestFiniteMagnitude)
                        < ($1.cheapest?.price ?? .greatestFiniteMagnitude)
                }
            case .distance:
                let origin = distanceOrigin
                return stations.sorted {
                    origin.distance(to: $0.coordinate) < origin.distance(to: $1.coordinate)
                }
            }
        }
    }

    enum Action: Equatable {
        case onAppear
        case locationResponse(Coordinate?)
        case locationPermissionDenied
        /// El permiso quedó resuelto (concedido/denegado/restringido) — puede venir
        /// del propio `.onAppear` o, si el onboarding lo pidió primero, reenviado por
        /// `AppFeature` tras `.onboarding(.delegate(.finished))`. Nadie vuelve a
        /// llamar a `requestWhenInUse()` una segunda vez para el mismo lanzamiento.
        case locationPermissionResolved(CLAuthorizationStatus)
        case openLocationSettingsTapped
        /// La app vuelve a primer plano: si aún no hay ubicación real del usuario,
        /// comprueba si concedió el permiso desde Ajustes (incluso si mientras tanto
        /// buscó una ciudad a mano — eso no sustituye la ubicación real).
        case appBecameActive
        case mapCameraChanged(center: Coordinate, span: Double)
        case stationsResponse(Result<[Station], APIError>)
        case stationTapped(Station)
        case stationSelectedFromList(Station)
        case detail(PresentationAction<StationDetailFeature.Action>)
        case filters(FiltersFeature.Action)
        case sortOrderChanged(StationSort)
        case mapStyleChanged(MapStyleOption)
        case recenterOnStation(Station)
        case clusterTapped(StationCluster)
        case recenterHandled
        case loadFavorites
        case favoritesResponse([FavoriteStationInfo])
        case favoritePricesResponse(Result<[Station], APIError>)
        case favoriteSelected(FavoriteStationInfo)
        case reload
        /// Búsqueda manual de ciudad/dirección (para quien deniega el permiso, o
        /// simplemente quiere mirar otra zona).
        case locationSearchButtonTapped
        case locationSearchDismissed
        case locationSearchSubmitted(String)
        case locationSearchResponse(Result<Coordinate, GeocodingError>)
        case delegate(Delegate)
    }

    /// Lo que el mapa delega en el reducer raíz. Fuera de `Action` para respetar el
    /// límite de anidamiento de SwiftLint (1 nivel).
    enum Delegate: Equatable {
        /// El usuario abrió la hoja de informazioni desde el chrome del mapa. El estado
        /// premium vive en `AppFeature`, así que la hoja se presenta allí y no aquí
        /// (evita duplicar `isPremium` y que quede obsoleto tras comprar).
        case settingsTapped
    }

    @Dependency(\.apiClient) var apiClient
    @Dependency(\.locationClient) var locationClient
    @Dependency(\.favoritesClient) var favoritesClient
    @Dependency(\.geocodingClient) var geocodingClient
    @Dependency(\.openURL) var openURL
    @Dependency(\.continuousClock) var clock

    /// No `private`: `MapFeature+Loading.swift`/`MapFeature+LocationSearch.swift`
    /// (otros archivos) necesitan referenciarla en `.cancellable(id:)`.
    enum CancelID { case reload, favoritePrices, locationSearch }

    var body: some ReducerOf<Self> {
        Scope(state: \.filters, action: \.filters) {
            FiltersFeature()
        }
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard !state.didRequestLocation else { return .send(.loadFavorites) }
                state.didRequestLocation = true
                return .merge(
                    .run { send in
                        let status = await locationClient.requestWhenInUse()
                        await send(.locationPermissionResolved(status))
                    },
                    .send(.loadFavorites)
                )

            case let .locationPermissionResolved(status):
                // Idempotente: si ya se resolvió (p. ej. lo trajo el onboarding antes
                // de que este `MapView` llegara a montarse), no hace nada más aquí —
                // el `.onAppear` que lo disparó ya puso `didRequestLocation = true`.
                state.didRequestLocation = true
                return resolveLocationEffect(for: status)

            case let .locationResponse(coordinate):
                if let coordinate {
                    state.center = coordinate
                    state.userLocation = coordinate
                    state.recenter = coordinate
                    state.locationPermissionDenied = false
                }
                return load(&state)

            case .locationPermissionDenied:
                state.locationPermissionDenied = true
                return load(&state)

            case .openLocationSettingsTapped:
                return .run { _ in
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    await openURL(url)
                }

            case .appBecameActive:
                // No basta con mirar `locationPermissionDenied`: una búsqueda manual lo
                // limpia sin que haya ubicación real. Lo que importa es si ya tenemos
                // `userLocation` — si no, comprueba si concedió el permiso en Ajustes.
                guard state.userLocation == nil else { return .none }
                return .run { send in
                    switch locationClient.authorizationStatus() {
                    case .authorizedWhenInUse, .authorizedAlways:
                        await send(.locationResponse(try? await locationClient.currentLocation()))
                    default:
                        break
                    }
                }

            case let .mapCameraChanged(center, span):
                // El span (zoom) se actualiza siempre para reclusterizar; el centro y la
                // recarga solo si el movimiento supera el epsilon (ignora el jitter, que
                // si no reiniciaría el debounce sin cesar dejando isLoading pegado).
                state.span = span
                let epsilon = 0.0005
                let moved = abs(center.latitude - state.center.latitude) > epsilon
                    || abs(center.longitude - state.center.longitude) > epsilon
                guard moved else { return .none }
                state.center = center
                return load(&state, debounced: true)

            case .filters:
                // Cualquier cambio de filtro (combustible/self/radio) recarga el mapa y,
                // si hay favoritos, refresca sus precios al nuevo combustible/self.
                return .merge(load(&state), loadFavoritePrices(&state))

            case let .sortOrderChanged(order):
                state.sortOrder = order
                return .none

            case let .mapStyleChanged(style):
                state.mapStyle = style
                return .none

            case let .recenterOnStation(station):
                state.recenter = station.coordinate
                return .none

            case let .clusterTapped(cluster):
                // Acercar para desagrupar: reduce el span y recentra en el cluster.
                state.span = max(state.span / 3, 0.005)
                state.recenter = cluster.coordinate
                return .none

            case .recenterHandled:
                // La vista ya aplicó el recentrado; consumir el evento para que
                // reseleccionar el mismo destino vuelva a disparar (nil → coord).
                state.recenter = nil
                return .none

            case .loadFavorites:
                return .run { send in
                    await send(.favoritesResponse(favoritesClient.all()))
                }

            case let .favoritesResponse(favorites):
                state.favorites = favorites
                return loadFavoritePrices(&state)

            case let .favoritePricesResponse(.success(stations)):
                state.isLoadingFavoritePrices = false
                state.favoriteStations = stations
                return .none

            case .favoritePricesResponse(.failure):
                // Fallo silencioso: la hoja sigue usable por nombre/distancia; conserva
                // cualquier precio previo en vez de vaciar la vista.
                state.isLoadingFavoritePrices = false
                return .none

            case let .favoriteSelected(favorite):
                // Mismo patrón que la lista: recentra ya y abre el detalle tras cerrarse
                // el sheet de favoritos. Pre-rellena con lo que sabemos (nombre+coords);
                // el detalle carga el resto (todos los combustibles) vía station_detail.
                state.recenter = favorite.coordinate
                let station = Station(
                    id: favorite.id, name: favorite.name, brand: nil, address: nil,
                    municipality: nil, province: nil, coordinate: favorite.coordinate, prices: []
                )
                return .run { send in
                    try await clock.sleep(for: .milliseconds(350))
                    await send(.stationTapped(station))
                }

            case .reload:
                return load(&state)

            case .locationSearchButtonTapped:
                state.isShowingLocationSearch = true
                state.locationSearchError = nil
                return .none

            case .locationSearchDismissed:
                state.isShowingLocationSearch = false
                state.locationSearchError = nil
                return .none

            case let .locationSearchSubmitted(query):
                return searchLocation(&state, query: query)

            case let .locationSearchResponse(result):
                return handleLocationSearchResponse(&state, result: result)

            case .delegate:
                return .none

            case let .stationsResponse(.success(stations)):
                state.isLoading = false
                state.errorMessage = nil
                state.stations = stations
                state.cheapestStationID = stations.min {
                    ($0.cheapest?.price ?? .greatestFiniteMagnitude)
                        < ($1.cheapest?.price ?? .greatestFiniteMagnitude)
                }?.id
                return .none

            case let .stationsResponse(.failure(error)):
                state.isLoading = false
                state.errorMessage = error.userMessage(
                    noResults: String(localized: "Nessun distributore trovato in zona.")
                )
                return .none

            case let .stationTapped(station):
                // Centra el mapa en el pin pulsado (mejor UX) y abre el detalle.
                state.recenter = station.coordinate
                state.detail = StationDetailFeature.State(
                    stationId: station.id,
                    station: station,
                    selectedFuel: state.filters.fuel
                )
                return .none

            case let .stationSelectedFromList(station):
                // Recentra ya; el detalle se abre tras cerrarse el sheet de la lista.
                state.recenter = station.coordinate
                return .run { send in
                    try await clock.sleep(for: .milliseconds(350))
                    await send(.stationTapped(station))
                }

            case .detail(.dismiss):
                // Al cerrar el detalle, refresca favoritos (pudo cambiar el toggle).
                return .send(.loadFavorites)

            case .detail:
                return .none
            }
        }
        .ifLet(\.$detail, action: \.detail) {
            StationDetailFeature()
        }
    }

    /// Único punto que decide qué hacer con un `CLAuthorizationStatus` ya resuelto —
    /// antes estaba escrito dos veces (en `.onAppear` y en `appBecameActive`).
    private func resolveLocationEffect(for status: CLAuthorizationStatus) -> Effect<Action> {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            return .run { send in
                await send(.locationResponse(try? await locationClient.currentLocation()))
            }
        case .denied, .restricted:
            return .send(.locationPermissionDenied)
        default:
            return .send(.locationResponse(nil))
        }
    }
}

// Tipos auxiliares (`MapDefaults`, `MapStyleOption`, `StationSort`) en `MapTypes.swift`.
