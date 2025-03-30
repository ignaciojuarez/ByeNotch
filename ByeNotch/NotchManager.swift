import SwiftUI
import Foundation
import CoreVideo
import CoreGraphics

// MARK: - NotchManager

/// Main controller for handling notch-related display operations
public class NotchManager {
    // Singleton instance
    public static let shared = NotchManager()
    
    // MARK: - Private Properties
    private let displayService = DisplayService()
    private let mainDisplayID = CGMainDisplayID()
    private var displayModes: [CGDisplayMode] = []
    private var originalResolution: (width: Int, height: Int)? = nil
    private var originalRefreshRate: Double = 0.0
    
    // MARK: - Initialization
    
    private init() {
        let options = [kCGDisplayShowDuplicateLowResolutionModes: kCFBooleanTrue] as CFDictionary
        displayModes = (CGDisplayCopyAllDisplayModes(mainDisplayID, options) as? [CGDisplayMode])?
            .filter { $0.isUsableForDesktopGUI() } ?? []
        
        if let currentMode = CGDisplayCopyDisplayMode(mainDisplayID) {
            originalResolution = (currentMode.width, currentMode.height)
            originalRefreshRate = currentMode.refreshRate
        } else {
            originalResolution = nil
            originalRefreshRate = 0.0
        }
    }
    
    // MARK: - Notch Detection and Model Identification
    
    /// Gets the Mac model identifier
    public func getMacModelIdentifier() -> String {
        let process = Process()
        process.launchPath = "/usr/sbin/sysctl"
        process.arguments = ["-n", "hw.model"]
        let pipe = Pipe()
        process.standardOutput = pipe
        
        process.launch()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown"
    }
    
    // MARK: - Resolution Management
    
    /// Get the current display resolution and refresh rate
    public func getCurrentResolution() -> (width: Int, height: Int, refreshRate: Double) {
        guard let mode = CGDisplayCopyDisplayMode(mainDisplayID) else { return (0, 0, 0) }
        return (mode.width, mode.height, mode.refreshRate)
    }
    
    /// List all available modes with refresh rates
    public func listAllDisplayModes() -> String {
        let displayList = displayModes.map { "[\($0.width)x\($0.height) @ \($0.refreshRate)Hz]" }
            .joined(separator: ", ")
        print(displayList)
        return displayList
    }
    
    /// Change the resolution while preserving ProMotion if possible
    public func changeResolution(width: String, height: String) async -> Bool {
        print("[changeResolution] 🔄 Changing resolution to \(width)x\(height)")

        guard let widthInt = Int(width), let heightInt = Int(height) else {
            print("[changeResolution] ❌ Invalid resolution values")
            return false
        }

        let matchingModes = displayModes.filter { $0.width == widthInt && $0.height == heightInt }
        guard !matchingModes.isEmpty else {
            print("[changeResolution] ❌ No matching modes found for \(widthInt)x\(heightInt)")
            return false
        }

        let macModel = getMacModelIdentifier()
        let supportsProMotion = await displayService.getDisplayInfo(for: macModel)?.supportsProMotion ?? false
        let selectedMode = supportsProMotion
            ? matchingModes.first(where: { $0.refreshRate > 90 }) ?? matchingModes.first
            : matchingModes.first

        guard let mode = selectedMode else {
            print("[changeResolution] ❌ No suitable display mode available")
            return false
        }

        var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success else {
            print("[changeResolution] ❌ Failed to start display configuration")
            return false
        }

        CGConfigureDisplayWithDisplayMode(config, mainDisplayID, mode, nil)
        let success = CGCompleteDisplayConfiguration(config, .permanently) == .success

        if !success { CGCancelDisplayConfiguration(config) }
        print(success ? "[changeResolution] ✅ Resolution changed successfully" : "❌ Failed to change resolution")

        return success
    }
    
    /// Toggle between notch-hidden and default resolution
    @MainActor
    public func toggleNotch(hideNotch: Bool) async  {
        let modelId = getMacModelIdentifier()
        guard let displayInfo = await displayService.getDisplayInfo(for: modelId) else {
            
            // restore to original resolution
            if let originalResolution, hideNotch == false {
                let result = await changeResolution(width: String(originalResolution.0), height: String(originalResolution.1))
                restoreRefreshRate()
                print ("[toggleNotch] Set: originalResolution: ", result, originalResolution)
            }
            return
        }
        
        if hideNotch {
            let moddedResolution = displayInfo.moddedResolution
            let result = await changeResolution(width: moddedResolution.width, height: moddedResolution.height)
            print ("[toggleNotch] Set: moddedResolution: ", result, moddedResolution)
        } else {
            let defaultResolution = displayInfo.defaultResolution
            let result = await changeResolution(width: defaultResolution.width, height: defaultResolution.height)
            print ("[toggleNotch] Set: defaultResolution: ", result, defaultResolution)
        }
        
        if displayInfo.supportsProMotion { restoreRefreshRate() }
    }

    
    // Implement this method to manually restore ProMotion after resolution change
    public func restoreRefreshRate() {
        let current = getCurrentResolution()
        guard current.refreshRate < 90,
              originalRefreshRate > 90,
              let highRefreshMode = displayModes.first(where: {
                  $0.width == current.width &&
                  $0.height == current.height &&
                  $0.refreshRate > 90
              }),
              var config: CGDisplayConfigRef? = nil,
              CGBeginDisplayConfiguration(&config) == .success else { return }
        
        CGConfigureDisplayWithDisplayMode(config, mainDisplayID, highRefreshMode, nil)
        if CGCompleteDisplayConfiguration(config, .permanently) != .success {
            CGCancelDisplayConfiguration(config)
        }
    }
}
