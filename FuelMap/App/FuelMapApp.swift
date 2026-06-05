//
//  FuelMapApp.swift
//  FuelMap
//
//  Created on 04/06/2026.
//

import ComposableArchitecture
import SwiftUI

@main
struct FuelMapApp: App {
    // Owner estable del Store raíz: no recrear en cada evaluación de `body`.
    @State private var store = Store(initialState: AppFeature.State()) {
        AppFeature()
    }

    var body: some Scene {
        WindowGroup {
            AppView(store: store)
        }
    }
}
