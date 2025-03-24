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
    
    private let mainDisplayID = CGMainDisplayID()
    private var displayModes: [CGDisplayMode] = []
    private var originalResolution: (width: Int, height: Int)? = nil
    private var originalRefreshRate: Double = 0.0
    
    // MARK: - Initialization
    
    private init() {
        let option = [kCGDisplayShowDuplicateLowResolutionModes: kCFBooleanTrue] as CFDictionary
        
        if let modes = CGDisplayCopyAllDisplayModes(mainDisplayID, option) as? [CGDisplayMode] {
            displayModes = modes.filter { $0.isUsableForDesktopGUI() }
        }
        
        // Store the original resolution and refresh rate when initializing
        if let currentMode = CGDisplayCopyDisplayMode(mainDisplayID) {
            originalResolution = (width: currentMode.width, height: currentMode.height)
            originalRefreshRate = currentMode.refreshRate
            print("Original resolution: \(currentMode.width)x\(currentMode.height) at \(currentMode.refreshRate)Hz")
        }
    }
    
    // MARK: - Notch Detection and Model Identification
    
    /// Gets the Mac model identifier
    public func getMacModelIdentifier() -> String {
        let process = Process()
        let pipe = Pipe()
        
        process.standardOutput = pipe
        process.launchPath = "/usr/sbin/sysctl"
        process.arguments = ["-n", "hw.model"]
        
        process.launch()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)
        
        return output?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown"
    }
    
    /// Check if the current Mac model has a notch
    public func hasNotch() -> Bool {
        let model = getMacModelIdentifier()
        
        // Check for notched models
        if model.contains("MacBookPro18,") || // M1 Pro/Max models
           model.contains("Mac14,") ||        // M2 models
           model.contains("Mac15,") ||        // M3 models
           model.contains("Mac16,") ||        // M4 models
           model.contains("MacBookPro14,") {  // Later models
            return true
        }
        
        // MacBook Air M2 and later
        if model == "Mac14,2" || model == "Mac14,15" ||
           model.contains("Mac16,") && model.contains("Air") {
            return true
        }
        
        return false
    }
    
    /// Check if the current Mac model supports ProMotion
    public func supportsProMotion() -> Bool {
        let model = getMacModelIdentifier()
        
        // MacBook Pro models from 2021 and later that support ProMotion
        if model.contains("MacBookPro18,") || // M1 Pro/Max
           model.contains("Mac14,10") || model.contains("Mac14,6") || // M2 Pro/Max
           model.contains("Mac15,") ||       // M3 models
           model.contains("Mac16,") && !model.contains("Air") { // M4 Pro models, not Air
            return true
        }
        
        return false
    }
    
    /// Get the pixel height reduction based on Mac model
    private func getNotchHeightReduction() -> Int {
        let model = getMacModelIdentifier()
        
        // MacBook Air models use 38 pixel reduction
        if model == "Mac14,2" || model == "Mac14,15" ||
           model.contains("Mac16,") && model.contains("Air") {
            return 38
        }
        
        // MacBook Pro models use 37 pixel reduction
        if model.contains("MacBookPro18,") ||
           model.contains("Mac14,") ||
           model.contains("Mac15,") ||
           model.contains("Mac16,") ||
           model.contains("MacBookPro14,") {
            return 37
        }
        
        return 0
    }
    
    // MARK: - Resolution Management
    
    /// Get the current display resolution and refresh rate
    public func getCurrentResolution() -> (width: Int, height: Int, refreshRate: Double) {
        guard let mode = CGDisplayCopyDisplayMode(mainDisplayID) else {
            return (0, 0, 0)
        }
        return (width: mode.width, height: mode.height, refreshRate: mode.refreshRate)
    }
    
    /// List all available modes with refresh rates
    public func listAllModes() -> String {
        let modeDetails = displayModes.map { mode in
            "[\(mode.width)x\(mode.height) @ \(mode.refreshRate)Hz]"
        }
        print(modeDetails.joined(separator: ", "))
        return modeDetails.joined(separator: ", ")
    }
    
    /// Find the best display mode for a given resolution that preserves ProMotion if possible
    private func findBestDisplayMode(width: Int, height: Int) -> CGDisplayMode? {
        print("Original refresh rate: \(originalRefreshRate)Hz")
        print("Searching for best mode at \(width)x\(height)")
        
        // Log all available modes
        print("Available modes: \(listAllModes())")
        
        // Get current refresh rate to try to match it
        let targetRefreshRate = originalRefreshRate > 0 ? originalRefreshRate : 120.0
        
        // First, try to find an exact match with the same refresh rate
        if let exactMatchWithRefresh = displayModes.first(where: {
            $0.width == width &&
            $0.height == height &&
            abs($0.refreshRate - targetRefreshRate) < 1.0
        }) {
            print("Found exact match with refresh rate: \(width)x\(height) at \(exactMatchWithRefresh.refreshRate)Hz")
            return exactMatchWithRefresh
        }
        
        // Next, try to find any mode with the resolution and highest refresh rate
        let matchingModes = displayModes.filter { $0.width == width && $0.height == height }
        if let highestRefreshMode = matchingModes.max(by: { $0.refreshRate < $1.refreshRate }) {
            print("Found mode with highest refresh rate: \(width)x\(height) at \(highestRefreshMode.refreshRate)Hz")
            return highestRefreshMode
        }
        
        // Fall back to any mode with the correct resolution
        if let anyMatch = displayModes.first(where: { $0.width == width && $0.height == height }) {
            print("Found matching resolution: \(width)x\(height) at \(anyMatch.refreshRate)Hz")
            return anyMatch
        }
        
        // Last resort - try to find a mode with the same width
        if let widthMatch = displayModes.first(where: { $0.width == width }) {
            print("Found width match only: \(width)x\(widthMatch.height) at \(widthMatch.refreshRate)Hz")
            return widthMatch
        }
        
        print("No matching mode found for \(width)x\(height)")
        return nil
    }
    
    /// Get the default (native) resolution
    public func getDefaultResolution() -> (width: String, height: String) {
        // First try to use the original resolution we stored at startup
        if let original = originalResolution {
            return (width: String(original.width), height: String(original.height))
        }
        
        // Next, try to get from current resolution if not already in modded mode
        let current = getCurrentResolution()
        if current.width > 0 && current.height > 0 {
            // Check if the current resolution is likely a modded one
            let defaultByModel = getDefaultResolutionByModel()
            if let defaultWidth = Int(defaultByModel.width),
               let defaultHeight = Int(defaultByModel.height),
               current.width == defaultWidth && current.height != defaultHeight {
                // We're likely in a modded resolution, use the model's default
                return defaultByModel
            }
            return (width: String(current.width), height: String(current.height))
        }
        
        // Fallback to model-specific resolution
        return getDefaultResolutionByModel()
    }
    
    /// Get the modded resolution to hide the notch
    public func getModdedResolution() -> (width: String, height: String) {
        // First try to get from current resolution
        let current = getCurrentResolution()
        if current.width > 0 && current.height > 0 && hasNotch() {
            // Check if current resolution matches a default one from our model list
            let defaultByModel = getDefaultResolutionByModel()
            if let defaultWidth = Int(defaultByModel.width),
               let defaultHeight = Int(defaultByModel.height),
               current.width == defaultWidth && abs(current.height - defaultHeight) < 5 {
                // We're likely at default resolution, calculate the modded height
                let reduction = getNotchHeightReduction()
                let moddedHeight = defaultHeight - reduction
                return (width: defaultByModel.width, height: String(moddedHeight))
            }
            
            // Otherwise just apply the reduction to the current height
            let reduction = getNotchHeightReduction()
            let moddedHeight = current.height - reduction
            return (width: String(current.width), height: String(moddedHeight))
        }
        
        // Fallback to model-specific resolution
        return getModdedResolutionByModel()
    }
    
    // MARK: - Model-Specific Fallback Methods
    
    /// Fallback method to get default resolution by model
    private func getDefaultResolutionByModel() -> (width: String, height: String) {
        let model = getMacModelIdentifier()
        
        switch model {
        // M2 MacBook Air
        case "Mac14,2": return ("1470", "956")
        case "Mac14,15": return ("1680", "1050")
            
        // M4 MacBook Air (13-inch)
        case "Mac16,1", "Mac16,2": return ("1470", "956")
            
        // M4 MacBook Air (15-inch)
        case "Mac16,3", "Mac16,4": return ("1680", "1050")
            
        // M1/M2/M3 MacBook Pro 14"
        case "MacBookPro18,3", "MacBookPro18,4", "MacBookPro14,5", "MacBookPro14,9",
             "Mac14,9", "Mac14,5", "Mac15,3", "Mac15,6", "Mac15,8", "Mac15,10":
            return ("1512", "982")
            
        // M4 MacBook Pro 14"
        case "Mac16,5", "Mac16,6", "Mac16,7":
            return ("1512", "982")
            
        // M1/M2/M3 MacBook Pro 16"
        case "MacBookPro18,1", "MacBookPro18,2", "MacBookPro14,10", "MacBookPro14,6",
             "Mac14,10", "Mac14,6", "Mac15,7", "Mac15,9", "Mac15,11":
            return ("1728", "1117")
            
        // M4 MacBook Pro 16"
        case "Mac16,8", "Mac16,9", "Mac16,10":
            return ("1728", "1117")
            
        default:
            // If we can't determine from model, try to get from current if it seems like default
            let current = getCurrentResolution()
            if current.width > 0 && current.height > 0 {
                return (width: String(current.width), height: String(current.height))
            }
            return ("No", "Match")
        }
    }
    
    /// Fallback method to get modded resolution by model
    private func getModdedResolutionByModel() -> (width: String, height: String) {
        let model = getMacModelIdentifier()
        
        switch model {
        // M2 MacBook Air
        case "Mac14,2": return ("1470", "918")
        case "Mac14,15": return ("1680", "1012")
            
        // M4 MacBook Air (13-inch)
        case "Mac16,1", "Mac16,2": return ("1470", "918")
            
        // M4 MacBook Air (15-inch)
        case "Mac16,3", "Mac16,4": return ("1680", "1012")
            
        // M1/M2/M3 MacBook Pro 14"
        case "MacBookPro18,3", "MacBookPro18,4", "MacBookPro14,5", "MacBookPro14,9",
             "Mac14,9", "Mac14,5", "Mac15,3", "Mac15,6", "Mac15,8", "Mac15,10":
            return ("1512", "945")
            
        // M4 MacBook Pro 14"
        case "Mac16,5", "Mac16,6", "Mac16,7":
            return ("1512", "945")
            
        // M1/M2/M3 MacBook Pro 16"
        case "MacBookPro18,1", "MacBookPro18,2", "MacBookPro14,10", "MacBookPro14,6",
             "Mac14,10", "Mac14,6", "Mac15,7", "Mac15,9", "Mac15,11":
            return ("1728", "1080")
            
        // M4 MacBook Pro 16"
        case "Mac16,8", "Mac16,9", "Mac16,10":
            return ("1728", "1080")
            
        default: return ("No", "Match")
        }
    }
    
    /// Change the resolution while preserving ProMotion if possible
    public func changeResolution(width: String, height: String) -> Bool {
        guard let widthInt = Int(width), let heightInt = Int(height) else {
            print("Invalid resolution values: \(width)x\(height)")
            return false
        }
        
        print("Trying to set resolution to: \(widthInt)x\(heightInt)")
        
        // Find the best display mode that preserves high refresh rate if possible
        if let bestMode = findBestDisplayMode(width: widthInt, height: heightInt) {
            var config: CGDisplayConfigRef?
            if CGBeginDisplayConfiguration(&config) == .success {
                print("Setting display to \(bestMode.width)x\(bestMode.height) at \(bestMode.refreshRate)Hz")
                
                // Configure the display with the selected mode
                CGConfigureDisplayWithDisplayMode(config, mainDisplayID, bestMode, nil)
                
                if CGCompleteDisplayConfiguration(config, .permanently) == .success {
                    print("Successfully changed resolution")
                    
                    // Verify the change
                    if let newMode = CGDisplayCopyDisplayMode(mainDisplayID) {
                        print("New display mode: \(newMode.width)x\(newMode.height) at \(newMode.refreshRate)Hz")
                    }
                    
                    return true
                } else {
                    CGCancelDisplayConfiguration(config)
                    print("Failed to complete display configuration")
                }
            } else {
                print("Failed to begin display configuration")
            }
        } else {
            print("No matching mode found for \(widthInt)x\(heightInt)")
        }
        
        return false
    }
    
    /// Toggle between notch-hidden and default resolution
    public func toggleNotch(hideNotch: Bool) -> Bool {
        let resolution: (width: String, height: String)
        
        if hideNotch {
            resolution = getModdedResolution()
            print("Switching to modded resolution: \(resolution.width)x\(resolution.height)")
        } else {
            resolution = getDefaultResolution()
            print("Switching to default resolution: \(resolution.width)x\(resolution.height)")
        }
        
        return changeResolution(width: resolution.width, height: resolution.height)
    }
    
    // Implement this method to manually restore ProMotion after resolution change
    public func restoreProMotionIfNeeded() {
        if !supportsProMotion() {
            return
        }
        
        let currentRes = getCurrentResolution()
        if currentRes.refreshRate < 90 && originalRefreshRate > 90 {
            print("Attempting to restore ProMotion")
            
            // Try to find a mode with the same resolution but higher refresh rate
            if let highRefreshMode = displayModes.first(where: {
                $0.width == currentRes.width &&
                $0.height == currentRes.height &&
                $0.refreshRate > 90
            }) {
                var config: CGDisplayConfigRef?
                if CGBeginDisplayConfiguration(&config) == .success {
                    CGConfigureDisplayWithDisplayMode(config, mainDisplayID, highRefreshMode, nil)
                    if CGCompleteDisplayConfiguration(config, .permanently) == .success {
                        print("Restored ProMotion: \(highRefreshMode.refreshRate)Hz")
                    } else {
                        CGCancelDisplayConfiguration(config)
                    }
                }
            }
        }
    }
}
