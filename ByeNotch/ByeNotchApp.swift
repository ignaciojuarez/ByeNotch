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
        
        // new menu bar SwiftUI
        // replaced entire class of AppDelegate to create this result, works great!
        MenuBarExtra("MenuBar", systemImage: "return"){
            AppView()
        }
    }
}
