//  GetMacIndo.swift
//
//  Created by Ignacio Juarez on 7/7/23.
//
//  Usage:
//  Call:    `getDefaultResolution()` function ge the default scaled macbook resolution.
//  Example: `getDefaultResolution()` return -> ("x", "y")
//
//  Call:    `getModdedResolution()` function ge the modded (for hidding notch) macbook resolution.
//  Example: `getModdedResolution()` return -> ("x", "y")
//
//  Desc:
//  This swift script is in charge of extracting the current macbook resolution
//  Through the model identifier to get its default and modded resolution
//
//  Func:
//  `getMacModelIdentifier` private
//  `getDefaultResolution` public
//  `getModdedResolution` public
//
//  Copyright © 2023 Ignacio Juarez. All rights reserved.
//
//
//  Supported Resolutions:
//
// 13 inch Macbook Air M2
// default -> (1470 x 956)
// modded  -> (1470 x 918)

// 15 inch Macbook Air M2
// default -> (1680 x 1050)
// modded  -> (1680 x 1012)

// 14 inch MacbookPro M1Pro
// default -> (1512 x 982)
// modded  -> (1512 x 945)

// 16 inch MacbookPro M1Pro
// default -> (1728 x 1117)
// modded  -> (1728 x 1080)

import Foundation

// This function returns the model identifier of the Mac
private func getMacModelIdentifier() -> String {
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

// This function returns the default resolution (scaled HDPI) for the current Mac model.
public func getDefaultResolution() -> (width: String, height: String) {
    let model = getMacModelIdentifier()
    
    switch model {
        
    case "Mac14,2":
        return ("1470", "956")
        
    case "Mac14,15":
        return ("1680" , "1050")
        
    case "MacBookPro18,3", "MacBookPro18,4", "MacBookPro14,5", "MacBookPro14,9":
        return ("1523", "982")
        
    case "MacBookPro18,1", "MacBookPro18,2", "MacBookPro14,10", "MacBookPro14,6":
        return ("1728", "1117")
        
    default:
        return ("No", "Match")
    }
}

//  This function returns the modded resolution (hidding notch purposes) for the current Mac model
public func getModdedResolution() -> (width: String, height: String) {
    let model = getMacModelIdentifier()
    
    switch model {
    case "Mac14,2":
        return ("1470", "918")
        
    case "Mac14,15":
        return ("1680" , "1050")
        
    case "MacBookPro18,3", "MacBookPro18,4", "MacBookPro14,5", "MacBookPro14,9":
        return ("1523", "945")
        
    case "MacBookPro18,1", "MacBookPro18,2", "MacBookPro14,10", "MacBookPro14,6":
        return ("1728", "1080")
        
    default:
        return ("No", "Match")
    }
}
