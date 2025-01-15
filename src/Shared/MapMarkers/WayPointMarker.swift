//
//  WayPoint.swift
//  Go Map!!
//
//  Created by Bryce Cogswell on 9/16/21.
//  Copyright © 2021 Bryce Cogswell. All rights reserved.
//

import Foundation
import UIKit

// MARK: - Marker Types
enum WayPointType: String {
    case construction = "Construction"
    case gatedCommunity = "Gated Community"
    case accident = "Accident"
    case other = "Other"
    case standard = "standard"
    
    var buttonLabel: String {
        switch self {
            case .construction: return "C"
            case .gatedCommunity: return "G"
            case .accident: return "A"
            case .other: return "O"
            case .standard: return "W"
        }
    }
    
    var color: UIColor {
        switch self {
            case .construction: return .orange
            case .gatedCommunity: return .green
            case .accident: return .red
            case .other: return .gray
            case .standard: return .blue
        }
    }
    
    static func from(gpxType: String?) -> WayPointType {
        guard let gpxType = gpxType else { return .standard }
        
        // Try to match the exact raw value first
        if let type = WayPointType(rawValue: gpxType) {
            return type
        }
        
        // Fall back to matching based on the GPX type string
        let typeStr = gpxType.lowercased()
        switch typeStr {
            case "construction": return .construction
            case "gated community": return .gatedCommunity
            case "accident": return .accident
            case "other": return .other
            default: return .standard
        }
    }
}

// A GPX waypoint
final class WayPointMarker: OsmMapMarker {
	let description: String
    let type: WayPointType
    

    init(with latLon: LatLon, description: String, type: WayPointType = .standard) {
        self.description = description
        self.type = type
        super.init(latLon: latLon)
        
        if let button = self.button {
            button.backgroundColor = type.color
        }
    }

    convenience init(with gpxPoint: GpxPoint) {
        var text = gpxPoint.name
        if let r1 = text.range(of: "<a "),
           let r2 = text.range(of: "\">")
        {
            text.removeSubrange(r1.lowerBound..<r2.upperBound)
        }
        text = text.replacingOccurrences(of: "&quot;", with: "\"")
        
        // Use the type property from GPX point instead of parsing description
        let wayPointType = WayPointType.from(gpxType: gpxPoint.type)
        
        self.init(with: gpxPoint.latLon, description: text, type: wayPointType)
    }
    
    override var markerIdentifier: String {
        return "waypoint-\(type.rawValue)-\(latLon.lat),\(latLon.lon)"
    }
    
    override var buttonLabel: String {
        return type.buttonLabel
    }
}
