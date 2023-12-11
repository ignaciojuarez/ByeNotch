//  DisplayController.swift
//
//  Created by Ignacio Juarez on 06/07/2023.
//
//  Usage:
//  Call the `changeResolution(width:height:)` function with the desired resolution.
//  Example: `changeResolution(width: "1920", height: "1080")`
//
//  Desc:
//  This script is used to manage the display settings of a MacOS.
//  It uses CoreVideo to interact with the display settings and allows for changes in resolution.
//
//  Func:
//  `DisplayManager` is responsible for managing the settings of a single display.
//  `DisplayMode` represents a single display mode.
//  `UserSetting` represents the user's desired settings.
//  `Screens` is used to manage multiple displays.
//
//  Copyright © 2023 Ignacio Juarez. All rights reserved.

import Foundation
import CoreVideo

// A struct representing a display mode.
struct DisplayMode: Equatable {
    let mode: CGDisplayMode
    let isCurrent: Bool
    
    // Equatable protocol implementation
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.mode == rhs.mode }
}

// A class to manage display settings.
class DisplayManager {
    private let displayID: CGDirectDisplayID
    private var displayInfo: [DisplayMode]
    
    // Initialize a new DisplayManager with a display ID.
    init(displayID: CGDirectDisplayID) {
        self.displayID = displayID
        self.displayInfo = []
        let option = [kCGDisplayShowDuplicateLowResolutionModes: kCFBooleanTrue] as CFDictionary?
        let modes = (CGDisplayCopyAllDisplayModes(displayID, option) as! [CGDisplayMode]).filter { $0.isUsableForDesktopGUI() }
        self.displayInfo = modes.map { DisplayMode(mode: $0, isCurrent: $0 === CGDisplayCopyDisplayMode(displayID)) }
    }
    
    // Initialize a new DisplayManager with a display ID.
    func setMode(_ mode: CGDisplayMode) {
        var config: CGDisplayConfigRef?
        if CGBeginDisplayConfiguration(&config) == .success {
            CGConfigureDisplayWithDisplayMode(config, displayID, mode, nil)
            if CGCompleteDisplayConfiguration(config, .permanently) != .success {
                CGCancelDisplayConfiguration(config)
            }
        }
    }
    
    // Sets the display mode based on user setting.
    func set(_ setting: UserSetting) {
        if let mode = displayInfo.last(where: { $0.mode.width == setting.width && $0.mode.height == setting.height }) {
            setMode(mode.mode)
        } else {
            print("This mode is unavailable")
        }
    }
}

// A struct representing user setting.
struct UserSetting {
    var displayIndex = 0, width = 0
    var height, scale: Int?
    
    // Initialize a new UserSetting with a resolution.
    init(_ resolution: [String]) {
        var args = resolution.compactMap(Int.init)
        if args.count < 1 { return }
        if args[0] > Screens.maxDisplays { args.insert(0, at: 0) }
        if args.count < 2 { return }
        displayIndex = args[0]
        width = args[1]
        if args.count == 2 { return }
        if args[2] > Screens.maxScale {
            height = args[2]
        }
    }
}

// A class to manage multiple screens.
class Screens {
    static let maxScale = 10
    static let maxDisplays = 8
    private var displayManagers: [DisplayManager]
    
    // Initialize a new Screens manager.
    init() {
        self.displayManagers = []
        var displayIDs = [CGDirectDisplayID](repeating: 0, count: Screens.maxDisplays)
        var displayCount: UInt32 = 0
        guard CGGetOnlineDisplayList(UInt32(Screens.maxDisplays), &displayIDs, &displayCount) == .success else {
            print("Error on getting online display List.")
            return
        }
        self.displayManagers = displayIDs.filter { $0 != 0 }.map(DisplayManager.init)
    }
    
    // Sets the display mode for a specific screen based on user setting.
    func set(_ setting: UserSetting) {
        displayManagers[setting.displayIndex].set(setting)
    }
}


// Change the resolution of the screen.
public func changeResolution(width: String, height: String) {
    let screens = Screens()
    screens.set(UserSetting([width, height]))
}
