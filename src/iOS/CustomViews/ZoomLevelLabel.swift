//
//  ZoomLevelLabel.swift
//  Go Map!!
//
//  Created for GoKaart to display current zoom level
//

import UIKit

/// A label that displays the current map zoom level
final class ZoomLevelLabel: UILabel {
	private var currentZoom: Double = 0.0

	override func awakeFromNib() {
		super.awakeFromNib()
		setupAppearance()
	}

	override init(frame: CGRect) {
		super.init(frame: frame)
		setupAppearance()
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
	}

	private func setupAppearance() {
		layer.cornerRadius = 5
		layer.masksToBounds = true
		backgroundColor = UIColor(white: 0.0, alpha: 0.5)
		textColor = UIColor.white
		font = UIFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
		textAlignment = .center
		isHidden = false
	}

	/// Update the displayed zoom level
	/// - Parameter zoom: The current zoom level from mapTransform.zoom()
	func updateZoom(_ zoom: Double) {
		// Only update if zoom changed significantly (avoid unnecessary redraws)
		if abs(zoom - currentZoom) > 0.01 {
			currentZoom = zoom
			text = String(format: "Z: %.1f", zoom)
		}
	}
}
