import SwiftUI
import Foundation
import CoreVideo
import CoreGraphics

// MARK: - NotchManager

/// [main thread] handling notch-related display operations
@MainActor
final class NotchManager {
    
    public static let shared = NotchManager()
    
    // MARK: - Private Properties
    private let displayService = DisplayService()
    private let mainDisplayID = CGMainDisplayID()
    private var displayModes: [CGDisplayMode] = []
    private var originalResolution: (width: String, height: String)? = nil
    private var originalRefreshRate: Double = 0.0

    // MARK: - Initialization

    init() {
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
    
    // MARK: - Main Function
    
    /// Toggle between notch-hidden and default resolution
    public func toggleNotch(hideNotch: Bool) async throws {
        guard let displayInfo = await displayService.getDisplayInfo(
            for: getMacModelIdentifier(),
            originalResolution: originalResolution
        ) else {
            if let originalResolution, !hideNotch {
                try await changeResolution(width: originalResolution.width, height: originalResolution.height)
                print("[toggleNotch] Restored original resolution: \(originalResolution)")
            }
            return
        }
        
        let targetResolution = hideNotch ? displayInfo.moddedResolution : displayInfo.defaultResolution
        try await changeResolution(width: targetResolution.width, height: targetResolution.height)
        print("[toggleNotch] Set \(hideNotch ? "modded" : "default") resolution: \(targetResolution)")
    }
    
    // MARK: - Model Identification
    
    /// Gets the Mac model identifier
    public func getMacModelIdentifier() async -> String {
        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/sysctl")
            process.arguments = ["-n", "hw.model"]
            let pipe = Pipe()
            process.standardOutput = pipe
            
            try process.run()
            process.waitUntilExit()
            
            let data = try pipe.fileHandleForReading.readToEnd() ?? Data()
            return String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown"
        } catch {
            print("[getMacModelIdentifier] Failed to retrieve model identifier: \(error)")
            return "Unknown"
        }
    }
    
    // MARK: - Resolution Management
    
    public func getCurrentResolution() -> (width: Int, height: Int, refreshRate: Double) {
        guard let mode = CGDisplayCopyDisplayMode(mainDisplayID) else { return (0, 0, 0) }
        return (mode.width, mode.height, mode.refreshRate)
    }
    
    public func listAllDisplayModes() -> String {
        let displayList = displayModes.map { "[\($0.width)x\($0.height) @ \($0.refreshRate)Hz]" }
            .joined(separator: ", ")
        print("[listAllDisplayModes] Available modes: \(displayList)")
        return displayList
    }
    
    /// Change the resolution while preserving ProMotion if possible
    public func changeResolution(width: String, height: String) async throws {
        guard let widthInt = Int(width), let heightInt = Int(height) else {
            throw ResolutionError.invalidValues(width: width, height: height)
        }
        
        guard let mode = displayModes.first(where: { $0.width == widthInt && $0.height == heightInt }) else {
            throw ResolutionError.noMatchingMode(width: widthInt, height: heightInt)
        }
        
        try applyDisplayMode(mode)
        print("[changeResolution] Resolution changed to \(mode.width)x\(mode.height) @ \(mode.refreshRate)Hz")
        
        if mode.refreshRate < originalRefreshRate {
            try await restoreRefreshRate()
        }
    }
    
    // Testore ProMotion after resolution change
    public func restoreRefreshRate() async throws {
        let current = getCurrentResolution()
        guard current.refreshRate < originalRefreshRate else {
            print("[restoreRefreshRate] No restoration needed (current: \(current.refreshRate)Hz)")
            return
        }
        
        let matchingModes = displayModes.filter { $0.width == current.width && $0.height == current.height }
        guard let bestMode = matchingModes.first(where: { $0.refreshRate == originalRefreshRate }) ??
                matchingModes.max(by: { $0.refreshRate < $1.refreshRate }) else {
            throw ResolutionError.noHighRefreshMode
        }
        
        try applyDisplayMode(bestMode)
        print("[restoreRefreshRate] Restored to \(bestMode.refreshRate)Hz")
    }
    
    // Helper method to apply the display mode
    private func applyDisplayMode(_ mode: CGDisplayMode) throws {
        var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success else {
            throw ResolutionError.configStartFailed
        }
        
        CGConfigureDisplayWithDisplayMode(config, mainDisplayID, mode, nil)
        guard CGCompleteDisplayConfiguration(config, .permanently) == .success else {
            CGCancelDisplayConfiguration(config)
            throw ResolutionError.configApplyFailed
        }
    }
}

// MARK: - ResolutionError
enum ResolutionError: Error, CustomStringConvertible {
    case invalidValues(width: String, height: String)
    case noMatchingMode(width: Int, height: Int)
    case configStartFailed
    case configApplyFailed
    case noHighRefreshMode
    
    var description: String {
        switch self {
        case .invalidValues(let width, let height):
            return "Invalid resolution values: \(width)x\(height)"
        case .noMatchingMode(let width, let height):
            return "No display mode found for \(width)x\(height)"
        case .configStartFailed:
            return "Failed to start display configuration"
        case .configApplyFailed:
            return "Failed to apply display configuration"
        case .noHighRefreshMode:
            return "No suitable high refresh rate mode available"
        }
    }
}
