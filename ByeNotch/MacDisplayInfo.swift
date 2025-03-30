//
//  MacDisplayInfo.swift
//  ByeNotch
//
//  Created by Ignacio Juarez on 3/27/25.
//

public struct DisplayResolution {
    public let defaultResolution: (width: String, height: String)
    public let moddedResolution: (width: String, height: String)
    public let supportsProMotion: Bool
}

// MARK: - MacDisplayInfoProvider

/// Class to provide MacDisplayInfo for different Mac models
actor DisplayService {
    
    /// Get display info for a specific Mac model
    public func getDisplayInfo(for macModelId: String) -> DisplayResolution? {
        switch macModelId {
            // MARK: - MacBook Air [ M2 -> M4 ]
            
            // M2 MacBook Air (13-inch)
            case "Mac14,2":
                return DisplayResolution(
                    defaultResolution: ("1470", "956"),
                    moddedResolution: ("1470", "918"),
                    supportsProMotion: false
                )
                
            // M2 MacBook Air (15-inch)
            case "Mac14,15":
                return DisplayResolution(
                    defaultResolution: ("1680", "1050"),
                    moddedResolution: ("1680", "1012"),
                    supportsProMotion: false
                )
                
            // M3 MacBook Air (13-inch)
            case "Mac15,12":
                return DisplayResolution(
                    defaultResolution: ("1470", "956"),
                    moddedResolution: ("1470", "918"),
                    supportsProMotion: false
                )
                
            // M3 MacBook Air (15-inch)
            case "Mac15,13":
                return DisplayResolution(
                    defaultResolution: ("1680", "1050"),
                    moddedResolution: ("1680", "1012"),
                    supportsProMotion: false
                )
                
            // M4 MacBook Air (13-inch)
            case "Mac16,12":
                return DisplayResolution(
                    defaultResolution: ("1470", "956"),
                    moddedResolution: ("1470", "918"),
                    supportsProMotion: false
                )
                
            // M4 MacBook Air (15-inch)
            case "Mac16,13":
                return DisplayResolution(
                    defaultResolution: ("1680", "1050"),
                    moddedResolution: ("1680", "1012"),
                    supportsProMotion: false
                )
                
            // MARK: - MacBook Pro [ M1 -> M4 ]
                
            // M4 MacBook Pro (14-inch)
            case "Mac16,1", "Mac16,6", "Mac16,8":
                return DisplayResolution(
                    defaultResolution: ("1512", "982"),
                    moddedResolution: ("1512", "945"),
                    supportsProMotion: true
                )
                
            // M4 MacBook Pro (16-inch)
            case "Mac16,7", "Mac16,5":
                return DisplayResolution(
                    defaultResolution: ("1728", "1117"),
                    moddedResolution: ("1728", "1080"),
                    supportsProMotion: true
                )
                
            // M3 MacBook Pro (14-inch)
            case "Mac15,3", "Mac15,6", "Mac15,8", "Mac15,10":
                return DisplayResolution(
                    defaultResolution: ("1512", "982"),
                    moddedResolution: ("1512", "945"),
                    supportsProMotion: true
                )
                
            // M3 MacBook Pro (16-inch)
            case "Mac15,7", "Mac15,9", "Mac15,11":
                return DisplayResolution(
                    defaultResolution: ("1728", "1117"),
                    moddedResolution: ("1728", "1080"),
                    supportsProMotion: true
                )
                
            // M2 MacBook Pro (14-inch)
            case "Mac14,5", "Mac14,9":
                return DisplayResolution(
                    defaultResolution: ("1512", "982"),
                    moddedResolution: ("1512", "945"),
                    supportsProMotion: true
                )
                
            // M2 MacBook Pro (16-inch)
            case "Mac14,6", "Mac14,10":
                return DisplayResolution(
                    defaultResolution: ("1728", "1117"),
                    moddedResolution: ("1728", "1080"),
                    supportsProMotion: true
                )
                
            // M1 MacBook Pro (14-inch)
            case "MacBookPro18,3", "MacBookPro18,4":
                return DisplayResolution(
                    defaultResolution: ("1512", "982"),
                    moddedResolution: ("1512", "945"),
                    supportsProMotion: true
                )
                
            // M1 MacBook Pro (16-inch)
            case "MacBookPro18,1", "MacBookPro18,2":
                return DisplayResolution(
                    defaultResolution: ("1728", "1117"),
                    moddedResolution: ("1728", "1080"),
                    supportsProMotion: true
                )
                
            default:
            return nil
        }
    }
    
    public func getAutomaticDisplayInfo(defaultResolution: (width: String, height: String)) -> DisplayResolution? {
        let resolutionMap: [((String, String), (String, String), Bool)] = [
            (("1470", "956"), ("1470", "918"), false),  // MacBook Air 13"
            (("1680", "1050"), ("1680", "1012"), false), // MacBook Air 15"
            (("1512", "982"), ("1512", "945"), true),   // MacBook Pro 14"
            (("1728", "1117"), ("1728", "1080"), true)  // MacBook Pro 16"
        ]
        
        for (defaultRes, moddedRes, supportsProMotion) in resolutionMap {
            if defaultRes == defaultResolution {
                return DisplayResolution(
                    defaultResolution: defaultRes,
                    moddedResolution: moddedRes,
                    supportsProMotion: supportsProMotion
                )
            }
        }
        
        return nil // Return nil if no matching resolution is found
    }
}
