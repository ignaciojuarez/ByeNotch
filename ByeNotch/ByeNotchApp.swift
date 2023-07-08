//
//  ByeNotchApp.swift
//  ByeNotch
//
//  Created by Ignacio Juarez on 7/8/23.
//

import SwiftUI

@main
struct ByeNotchApp: App {
    var body: some Scene {
        MenuBarExtra("MenuBar", systemImage: "hammer"){
            AppView()
        }
    }
}
