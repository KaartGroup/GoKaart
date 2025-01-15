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
    
    var systemImage: String {
        switch self {
            case .construction: return "building.2.fill"
            case .gatedCommunity: return "lock.shield.fill"
            case .accident: return "exclamationmark.triangle.fill"
            case .other: return "map.fill"
            case .standard: return "map.fill"
        }
    }
    
    var defaultImage: String {
        // Fallback images for earlier iOS versions
        switch self {
            case .construction: return "construction"
            case .gatedCommunity: return "gated"
            case .accident: return "warning"
            case .other: return "map"
            case .standard: return "map"
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
    
    override var buttonStyle: ButtonStyle {
        ButtonStyle(
            backgroundColor: type.color,
            size: CGSize(width: 20, height: 20)
        )
    }
    override var buttonLabel: String {
        return type.buttonLabel
    }
        
}

protocol WayPointMarkerSelectionPresenting: AnyObject {
    func presentAlert(alert: UIAlertController, location: MenuLocation)
}

final class HandleWayPointMarker {
    // MARK: - Properties
   private weak var owner: WayPointMarkerSelectionPresenting?
   
   // MARK: - Initialization
   init(owner: WayPointMarkerSelectionPresenting) {
       self.owner = owner
   }
   
   // MARK: - Public Methods
   func selectWayPointMarker(_ point: CGPoint) {
       let multiSelectSheet = UIAlertController(
           title: NSLocalizedString("Add Marker", comment: ""),
           message: nil,
           preferredStyle: .actionSheet
       )
       
       // Create array of marker types
       let markerTypes: [WayPointType] = [.construction, .gatedCommunity, .accident, .other]
       
       // Create actions in a loop
       for type in markerTypes {
           let action = UIAlertAction(
               title: type.rawValue,
               style: .default
           ) { [weak self] _ in
               self?.addWayPointMarker(type: type, at: point)
           }
           
           if #available(iOS 13.0, *) {
               action.setValue(UIImage(systemName: type.systemImage), forKey: "image")
           } else {
               action.setValue(UIImage(named: type.defaultImage), forKey: "image")
           }
           
           multiSelectSheet.addAction(action)
       }
       
       // Add cancel action
       multiSelectSheet.addAction(
           UIAlertAction(
               title: NSLocalizedString("Cancel", comment: ""),
               style: .cancel,
               handler: nil
           )
       )
       
       let rect = CGRect(
           x: point.x,
           y: point.y,
           width: 0.0,
           height: 0.0
       )
       
       owner?.presentAlert(
           alert: multiSelectSheet,
           location: .rect(rect)
       )
   }
   
   // MARK: - Private Methods
   private func addWayPointMarker(type: WayPointType, at point: CGPoint) {
       // 2. Add to database
       
       // 3. Update map display
       print("Creating \(type.rawValue) marker at point: \(point)")
   }
}
