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
    private var originalResolution: (width: String, height: String)? = nil
    private var originalRefreshRate: Double = 0.0

    // MARK: - Initialization

    private init() {
        let options = [kCGDisplayShowDuplicateLowResolutionModes: kCFBooleanTrue] as CFDictionary
        displayModes = (CGDisplayCopyAllDisplayModes(mainDisplayID, options) as? [CGDisplayMode])?
            .filter { $0.isUsableForDesktopGUI() } ?? []
        
        if let currentMode = CGDisplayCopyDisplayMode(mainDisplayID) {
            originalResolution = (width: String(currentMode.width), height: String(currentMode.height))
            originalRefreshRate = currentMode.refreshRate
        } else {
            originalResolution = nil
            originalRefreshRate = 0.0
        }
        print("[Init] OriginalResolution: ", originalResolution ?? "")
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
    public func changeResolution(width: String, height: String) async {
        guard let widthInt = Int(width), let heightInt = Int(height) else {
            print("[changeResolution] ❌ Invalid resolution values: \(width)x\(height)")
            return
        }
        
        let matchingModes = displayModes.filter { $0.width == widthInt && $0.height == heightInt }
        guard !matchingModes.isEmpty else {
            print("[changeResolution] ❌ No matching modes found for \(widthInt)x\(heightInt)")
            return
        }
        
        // Select initial mode (any valid mode for the resolution)
        guard let mode = matchingModes.first else {
            print("[changeResolution] ❌ No suitable display mode available")
            return
        }
        
        var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success else {
            print("[changeResolution] ❌ Failed to start display configuration")
            return
        }
        
        CGConfigureDisplayWithDisplayMode(config, mainDisplayID, mode, nil)
        let success = CGCompleteDisplayConfiguration(config, .permanently) == .success
        
        if !success {
            CGCancelDisplayConfiguration(config)
            print("[changeResolution] ❌ Failed to change resolution")
        }
        
        print("[changeResolution] ✅ Resolution changed to \(mode.width)x\(mode.height) @ \(mode.refreshRate)Hz")
        
        // After successful resolution change, restore original refresh rate or highest available
        await restoreRefreshRate()
    }
    
    func getDisplayInfo() async -> DisplayResolution? {
        let modelId = getMacModelIdentifier()
        
        var displayInfo: DisplayResolution?
        
        if let info = await displayService.getDisplayInfoWithMacId(for: modelId) {
            displayInfo = info
        }
        else if let originalResolution{
            displayInfo = await displayService.getDisplayInfoWithResolution(originalResolution: originalResolution)
        }
        return displayInfo
    }
    
    /// Toggle between notch-hidden and default resolution
    @MainActor
    public func toggleNotch(hideNotch: Bool) async  {
        
        guard let displayInfo = await getDisplayInfo() else {
            // restore to original resolution
            if let originalResolution, hideNotch == false {
                await changeResolution(width: originalResolution.width, height: originalResolution.height)
                print ("[toggleNotch] Set: originalResolution: ", originalResolution)
            }
            return
        }
        
        if hideNotch {
            let moddedResolution = displayInfo.moddedResolution
            await changeResolution(width: moddedResolution.width, height: moddedResolution.height)
            print ("[toggleNotch] Set: moddedResolution: ", moddedResolution)
        } else {
            let defaultResolution = displayInfo.defaultResolution
            await changeResolution(width: defaultResolution.width, height: defaultResolution.height)
            print ("[toggleNotch] Set: defaultResolution: ", defaultResolution)
        }
    }

    
    // Testore ProMotion after resolution change
    public func restoreRefreshRate() async {
        let current = getCurrentResolution()
        
        guard current.refreshRate < originalRefreshRate else {
            print("[restoreRefreshRate] ℹ️ No refresh rate restoration needed (current: \(current.refreshRate)Hz)")
            return
        }
        
        // Try to match original refresh rate first
        let targetMode = displayModes.first(where: {
            $0.width == current.width &&
            $0.height == current.height &&
            $0.refreshRate == originalRefreshRate
        }) ?? displayModes.filter {  // Fall back to highest available refresh rate
            $0.width == current.width &&
            $0.height == current.height
        }.max(by: { $0.refreshRate < $1.refreshRate })
        
        guard let highRefreshMode = targetMode else {
            print("[restoreRefreshRate] ❌ No high refresh rate mode available")
            return
        }
        
        var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success else {
            print("[restoreRefreshRate] ❌ Failed to start display configuration")
            return
        }
        
        CGConfigureDisplayWithDisplayMode(config, mainDisplayID, highRefreshMode, nil)
        let success = CGCompleteDisplayConfiguration(config, .permanently) == .success
        
        if success {
            print("[restoreRefreshRate] ✅ Restored to \(highRefreshMode.refreshRate)Hz")
        } else {
            CGCancelDisplayConfiguration(config)
            print("[restoreRefreshRate] ❌ Failed to restore refresh rate")
        }
    }
}
