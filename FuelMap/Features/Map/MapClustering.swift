//
//  MapClustering.swift
//  FuelMap
//
//  Created on 05/06/2026.
//

import Foundation

/// Elemento a renderizar en el mapa: estación individual o cluster (FM-15).
enum MapItem: Identifiable, Equatable {
    case station(Station)
    case cluster(StationCluster)

    var id: String {
        switch self {
        case let .station(station): return "s\(station.id)"
        case let .cluster(cluster): return "c\(cluster.id)"
        }
    }
}

/// Grupo de estaciones próximas, representado por un solo pin con conteo.
struct StationCluster: Identifiable, Equatable {
    let id: String
    let coordinate: Coordinate
    let count: Int
    let cheapestPrice: Decimal?
}

/// Clustering por celdas de una rejilla cuyo tamaño es proporcional al zoom visible.
/// Con pocas estaciones (la RPC limita a ~200) es trivial; al hacer zoom las celdas
/// se reducen y los clusters se deshacen en pins individuales.
enum MapClustering {
    /// Fracción del alto visible (latitudeDelta) que ocupa cada celda.
    static let cellFraction = 0.07

    static func items(stations: [Station], span: Double) -> [MapItem] {
        guard span > 0 else { return stations.map(MapItem.station) }
        let cell = max(span * cellFraction, 0.0001)

        var order: [String] = []
        var groups: [String: [Station]] = [:]
        for station in stations {
            let row = Int((station.coordinate.latitude / cell).rounded(.down))
            let col = Int((station.coordinate.longitude / cell).rounded(.down))
            let key = "\(row):\(col)"
            if groups[key] == nil { order.append(key) }
            groups[key, default: []].append(station)
        }

        return order.compactMap { key -> MapItem? in
            guard let group = groups[key], let first = group.first else { return nil }
            if group.count == 1 { return .station(first) }

            let count = Double(group.count)
            let lat = group.reduce(0) { $0 + $1.coordinate.latitude } / count
            let lng = group.reduce(0) { $0 + $1.coordinate.longitude } / count
            let cheapest = group.compactMap { $0.cheapest?.price }.min()
            return .cluster(
                StationCluster(
                    id: key,
                    coordinate: Coordinate(latitude: lat, longitude: lng),
                    count: group.count,
                    cheapestPrice: cheapest
                )
            )
        }
    }
}
