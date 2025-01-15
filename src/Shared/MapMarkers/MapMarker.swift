//
//  MapMarker.swift
//  Go Map!!
//
//  Created by Bryce Cogswell on 9/16/21.
//  Copyright © 2021 Bryce Cogswell. All rights reserved.
//

import UIKit

// A marker that is displayed above the map. This could be:
// * Quest
// * FIXME
// * Notes
// * GPX Waypoint
// * KeepRight

class OsmMapMarker {
	private(set) var buttonId: Int // a unique value we assign to track marker buttons.
	let latLon: LatLon
	weak var object: OsmBaseObject?
	weak var ignorable: MapMarkerIgnoreListProtocol?
	var button: UIButton?

	// a unique identifier for a marker across multiple downloads
	var markerIdentifier: String {
		fatalError()
	}

	deinit {
		button?.removeFromSuperview()
	}

	func reuseButtonFrom(_ other: OsmMapMarker) {
		button = other.button
		buttonId = other.buttonId
		other.button = nil // nullify it so it doesn't get removed on deinit
	}

	private static var nextButtonID = (1...).makeIterator()

	init(latLon: LatLon) {
		buttonId = Self.nextButtonID.next()!
		self.latLon = latLon
	}

    struct ButtonStyle {
        let backgroundColor: UIColor
        let borderColor: UIColor
        let borderWidth: CGFloat
        let size: CGSize
        
        init(
            backgroundColor: UIColor = .blue,
            borderColor: UIColor = .white,
            borderWidth: CGFloat = 2.0,
            size: CGSize = CGSize(width: 34, height: 34)
        ) {
            self.backgroundColor = backgroundColor
            self.borderColor = borderColor
            self.borderWidth = borderWidth
            self.size = size
        }
    }
    
    var buttonStyle: ButtonStyle {
        return ButtonStyle()
    }
    
    var buttonLabel: String { "?" }

    func makeButton() -> UIButton {
        let button: MapView.MapViewButton
        if self is QuestMarker {
            button = LocationButton(withLabel: buttonLabel)
        } else {
            button = MapView.MapViewButton(type: .custom)
            let style = buttonStyle
            
            button.bounds = CGRect(origin: .zero, size: style.size)
            button.layer.backgroundColor = style.backgroundColor.cgColor
            button.layer.borderColor = style.borderColor.cgColor
            button.layer.borderWidth = style.borderWidth
            
            if buttonLabel.count > 1 {
                // icon button
                button.layer.cornerRadius = style.size.width / 2
                button.setImage(UIImage(named: buttonLabel), for: .normal)
            } else {
                // text button
                button.layer.cornerRadius = 5
                button.titleLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
                button.titleLabel?.textColor = .white
                button.titleLabel?.textAlignment = .center
                button.setTitle(buttonLabel, for: .normal)
            }
        }
        self.button = button
        return button
    }
}
