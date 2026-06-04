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
    var body: some Scene {
        WindowGroup {
            // NOTE: el Store se crea inline para el esqueleto (FM-1). Se promoverá
            // a un owner estable (@State / static) al introducir estado real en FM-7.
            AppView(
                store: Store(initialState: AppFeature.State()) {
                    AppFeature()
                }
            )
        }
    }
}
