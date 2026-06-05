//
//  FavoritesClientTests.swift
//  FuelMapTests
//
//  Created on 05/06/2026.
//

import Testing

@testable import FuelMap

struct FavoritesClientTests {

    private func input(_ id: Int) -> FavoriteInput {
        FavoriteInput(id: id, name: "Estación \(id)", latitude: 41.9, longitude: 12.5)
    }

    @Test("toggle añade y luego elimina; isFavorite y all reflejan el estado")
    func favorites_toggle_addsThenRemoves() async {
        let client = FavoritesClient.inMemory()

        #expect(await client.isFavorite(1) == false)

        let added = await client.toggle(input(1))
        #expect(added == true)
        #expect(await client.isFavorite(1) == true)
        #expect(await client.all().map(\.id) == [1])

        let removed = await client.toggle(input(1))
        #expect(removed == false)
        #expect(await client.isFavorite(1) == false)
        #expect(await client.all().isEmpty)
    }

    @Test("all devuelve los favoritos más recientes primero")
    func favorites_all_ordersByRecency() async {
        let client = FavoritesClient.inMemory()
        _ = await client.toggle(input(1))
        _ = await client.toggle(input(2))

        let ids = await client.all().map(\.id)
        #expect(Set(ids) == [1, 2])
        // El más reciente (2) va primero.
        #expect(ids.first == 2)
    }
}
