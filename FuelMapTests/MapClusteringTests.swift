//
//  MapClusteringTests.swift
//  FuelMapTests
//
//  Created on 05/06/2026.
//

import Testing

@testable import FuelMap

struct MapClusteringTests {

    private func stationCount(_ item: MapItem) -> Int {
        switch item {
        case .station: return 1
        case let .cluster(cluster): return cluster.count
        }
    }

    @Test("span enorme → un solo cluster con todas las estaciones")
    func clustering_largeSpan_singleCluster() {
        let items = MapClustering.items(stations: StationFixtures.all, span: 10)
        #expect(items.count == 1)
        #expect(items.map(stationCount) == [StationFixtures.all.count])
    }

    @Test("span diminuto → todas las estaciones individuales")
    func clustering_tinySpan_allIndividual() {
        let items = MapClustering.items(stations: StationFixtures.all, span: 0.0002)
        #expect(items.count == StationFixtures.all.count)
        #expect(items.allSatisfy { if case .station = $0 { return true } else { return false } })
    }

    @Test("conserva el total de estaciones (clusters + individuales)")
    func clustering_preservesTotal() {
        let items = MapClustering.items(stations: StationFixtures.all, span: 0.08)
        #expect(items.map(stationCount).reduce(0, +) == StationFixtures.all.count)
    }

    @Test("span 0 no divide por cero (todas individuales)")
    func clustering_zeroSpan() {
        let items = MapClustering.items(stations: StationFixtures.all, span: 0)
        #expect(items.count == StationFixtures.all.count)
    }
}
