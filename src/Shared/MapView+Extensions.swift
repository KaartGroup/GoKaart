//
//  MapView+Extensions.swift
//  GoKaart
//
//  Created by Logan Barnes on 4/14/23.
//

import Foundation
import MapKit

@objc extension MapView: MKMapViewDelegate {
    
    @objc func addCityLimit(_ fileName: String) {
        print("addCityLimit")
        guard let filePath = Bundle.main.path(forResource: fileName, ofType: "json"),
              let jsonData = try? Data(contentsOf: URL(fileURLWithPath: filePath)),
              let jsonDict = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] else {
            return
        }
        
        guard let features = jsonDict["features"] as? [[String: Any]] else {
            return
        }
        
        for feature in features {
            print("polygon")
            guard let geometry = feature["geometry"] as? [String: Any],
                  let type = geometry["type"] as? String,
                  type == "Polygon",
                  let coordinates = geometry["coordinates"] as? [[[Double]]] else {
                continue
            }
            
            var polygonPoints = [CLLocationCoordinate2D]()
            for point in coordinates[0] {
                polygonPoints.append(CLLocationCoordinate2D(latitude: point[1], longitude: point[0]))
            }
            let polygon = MKPolygon(coordinates: &polygonPoints, count: polygonPoints.count)
            if let mapView = self.mapKitView {
                mapView.addOverlay(polygon)
                print("addOverlay")
            }
        }
    }
    
    @objc public func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        print("renderer")
        guard let polygon = overlay as? MKPolygon else {
            return MKOverlayRenderer()
        }
        
        let renderer = MKPolygonRenderer(polygon: polygon)
        renderer.fillColor = UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 0.25)
        renderer.strokeColor = UIColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 1.0)
        renderer.lineWidth = 2.0
        
        return renderer
    }
}
