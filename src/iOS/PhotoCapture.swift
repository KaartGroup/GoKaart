//
//  PhotoCapture.swift
//  Go Map!!
//
//  Created by Bryce Cogswell on 7/21/25.
//  Copyright © 2025 Bryce Cogswell. All rights reserved.
//

import CoreLocation
import Foundation
import UIKit

private func dataFor(image: UIImage, location: CLLocation?, heading: CLHeading?) -> Data? {
	guard let imageData = image.jpegData(compressionQuality: 0.9),
	      let source = CGImageSourceCreateWithData(imageData as CFData, nil),
	      let imageType = CGImageSourceGetType(source),
	      let metadataOrig = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any]
	else {
		return nil
	}

	var gpsDict: [String: Any] = [:]

	// Inject location values
	if let loc = location {
		let timeFormatter = DateFormatter()
		timeFormatter.timeZone = TimeZone(abbreviation: "UTC")
		timeFormatter.dateFormat = "HH:mm:ss"

		let dateFormatter = DateFormatter()
		dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
		dateFormatter.dateFormat = "yyyy:MM:dd"

		gpsDict[kCGImagePropertyGPSLatitude as String] = abs(loc.coordinate.latitude)
		gpsDict[kCGImagePropertyGPSLatitudeRef as String] = loc.coordinate.latitude >= 0 ? "N" : "S"
		gpsDict[kCGImagePropertyGPSLongitude as String] = abs(loc.coordinate.longitude)
		gpsDict[kCGImagePropertyGPSLongitudeRef as String] = loc.coordinate.longitude >= 0 ? "E" : "W"
		gpsDict[kCGImagePropertyGPSAltitude as String] = loc.altitude
		gpsDict[kCGImagePropertyGPSAltitudeRef as String] = loc.altitude >= 0 ? 0 : 1
		gpsDict[kCGImagePropertyGPSDateStamp as String] = dateFormatter.string(from: loc.timestamp)
		gpsDict[kCGImagePropertyGPSTimeStamp as String] = timeFormatter.string(from: loc.timestamp)
	}

	// Inject heading values
	if let hdg = heading {
		gpsDict[kCGImagePropertyGPSImgDirection as String] = hdg.trueHeading
		gpsDict[kCGImagePropertyGPSImgDirectionRef as String] = "T" // "T" for true north
	}

	var metadata = metadataOrig
	metadata[kCGImagePropertyGPSDictionary as String] = gpsDict

	// Write the new data to exif
	let outputData = NSMutableData()
	guard let destination = CGImageDestinationCreateWithData(outputData, imageType, 1, nil) else {
		return nil
	}
	CGImageDestinationAddImageFromSource(destination, source, 0, metadata as CFDictionary)
	CGImageDestinationFinalize(destination)

	return outputData as Data
}

private class CameraOverlayView: UIView {
	enum State {
		case capturing
		case reviewing
	}

	let doneButton = UIButton(type: .system)
	let shutterButton = makeShutterButton(size: 70)
	let retakeButton = UIButton(type: .system)
	let acceptButton = UIButton(type: .system)

	private let previewView = UIImageView()
	private let controlBar = UIView()
	private let counterLabel = UILabel()
	private var currentState: State = .capturing

	var photoCount: Int = 0 {
		didSet {
			if photoCount > 0 {
				counterLabel.text = "\(photoCount) photo\(photoCount == 1 ? "" : "s") taken"
				counterLabel.isHidden = false
			} else {
				counterLabel.isHidden = true
			}
		}
	}

	override init(frame: CGRect) {
		super.init(frame: frame)
		backgroundColor = .clear
		setupButtons()
		switchToState(.capturing)
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	private static func makeShutterButton(size: CGFloat) -> UIButton {
		let button = UIButton()
		button.backgroundColor = .white

		button.translatesAutoresizingMaskIntoConstraints = false
		NSLayoutConstraint.activate([
			button.widthAnchor.constraint(equalToConstant: size),
			button.heightAnchor.constraint(equalTo: button.widthAnchor)
		])

		// Make circular
		button.layer.cornerRadius = size / 2
		button.layer.masksToBounds = true

		// Add black ring just inside edge
		let ringLayer = CAShapeLayer()
		let inset: CGFloat = 2.0
		let radius = (size / 2) - inset
		let ringPath = UIBezierPath(arcCenter: CGPoint(x: size / 2, y: size / 2),
		                            radius: radius,
		                            startAngle: 0,
		                            endAngle: .pi * 2,
		                            clockwise: true)
		ringLayer.path = ringPath.cgPath
		ringLayer.strokeColor = UIColor.black.cgColor
		ringLayer.fillColor = UIColor.clear.cgColor
		ringLayer.lineWidth = 1.0
		button.layer.addSublayer(ringLayer)
		return button
	}

	private func setupButtons() {
		// Black bar behind the controls to cover camera passthrough at the bottom
		controlBar.backgroundColor = .black
		controlBar.translatesAutoresizingMaskIntoConstraints = false
		addSubview(controlBar)

		let buttonSize: CGFloat = 44
		let config = UIImage.SymbolConfiguration(pointSize: 28, weight: .medium)
		doneButton.setImage(UIImage(systemName: "xmark.circle", withConfiguration: config), for: .normal)
		acceptButton.setImage(UIImage(systemName: "checkmark.circle", withConfiguration: config), for: .normal)
		retakeButton.setImage(UIImage(systemName: "arrow.clockwise", withConfiguration: config), for: .normal)
		doneButton.tintColor = .white
		retakeButton.tintColor = .white
		acceptButton.tintColor = .white

		// Photo counter label
		counterLabel.textColor = .white
		counterLabel.font = .systemFont(ofSize: 14, weight: .medium)
		counterLabel.textAlignment = .center
		counterLabel.isHidden = true
		counterLabel.translatesAutoresizingMaskIntoConstraints = false
		addSubview(counterLabel)

		// Add buttons on top of the control bar
		[shutterButton, doneButton, retakeButton, acceptButton].forEach { button in
			button.translatesAutoresizingMaskIntoConstraints = false
			addSubview(button)
		}

		NSLayoutConstraint.activate([
			// Black bar: from 20pt above shutter to bottom of screen
			controlBar.leadingAnchor.constraint(equalTo: leadingAnchor),
			controlBar.trailingAnchor.constraint(equalTo: trailingAnchor),
			controlBar.topAnchor.constraint(equalTo: shutterButton.topAnchor, constant: -20),
			controlBar.bottomAnchor.constraint(equalTo: bottomAnchor),

			doneButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 40),
			doneButton.centerYAnchor.constraint(equalTo: shutterButton.centerYAnchor),
			doneButton.widthAnchor.constraint(equalToConstant: buttonSize),
			doneButton.heightAnchor.constraint(equalToConstant: buttonSize),

			shutterButton.centerXAnchor.constraint(equalTo: centerXAnchor),
			shutterButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -30),

			acceptButton.centerXAnchor.constraint(equalTo: centerXAnchor),
			acceptButton.centerYAnchor.constraint(equalTo: shutterButton.centerYAnchor),
			acceptButton.widthAnchor.constraint(equalToConstant: buttonSize),
			acceptButton.heightAnchor.constraint(equalToConstant: buttonSize),

			retakeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -40),
			retakeButton.centerYAnchor.constraint(equalTo: shutterButton.centerYAnchor),
			retakeButton.widthAnchor.constraint(equalToConstant: buttonSize),
			retakeButton.heightAnchor.constraint(equalToConstant: buttonSize),

			// Counter label above the control bar
			counterLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
			counterLabel.bottomAnchor.constraint(equalTo: controlBar.topAnchor, constant: -8),
		])

		// Preview after image is captured — fills area above buttons, black background
		previewView.contentMode = .scaleAspectFit
		previewView.backgroundColor = .black
		previewView.isHidden = true
		insertSubview(previewView, belowSubview: shutterButton)
		previewView.translatesAutoresizingMaskIntoConstraints = false
		NSLayoutConstraint.activate([
			previewView.leadingAnchor.constraint(equalTo: leadingAnchor),
			previewView.trailingAnchor.constraint(equalTo: trailingAnchor),
			previewView.topAnchor.constraint(equalTo: topAnchor),
			previewView.bottomAnchor.constraint(equalTo: shutterButton.topAnchor, constant: -10)
		])
	}

	func switchToState(_ state: State) {
		currentState = state

		switch state {
		case .capturing:
			shutterButton.isHidden = false
			retakeButton.isHidden = true
			acceptButton.isHidden = true
			updateDoneButtonIcon()
		case .reviewing:
			shutterButton.isHidden = true
			retakeButton.isHidden = false
			acceptButton.isHidden = false
		}
	}

	private func updateDoneButtonIcon() {
		let config = UIImage.SymbolConfiguration(pointSize: 28, weight: .medium)
		let iconName = photoCount > 0 ? "checkmark.circle" : "xmark.circle"
		doneButton.setImage(UIImage(systemName: iconName, withConfiguration: config), for: .normal)
	}

	func showPreview(_ image: UIImage) {
		previewView.image = image
		previewView.alpha = 0
		previewView.isHidden = false
		UIView.animate(withDuration: 0.3) {
			self.previewView.alpha = 1
		}
	}

	func hidePreview() {
		previewView.isHidden = true
		previewView.image = nil
	}
}

class PhotoCapture: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
	private let picker = UIImagePickerController()
	private let overlayView = CameraOverlayView()
	private var capturedImage: UIImage?
	private var capturedImageData: Data?
	private var hasAppliedCameraTransform = false

	var locationManager: CLLocationManager?
	/// Called for each accepted photo (fires without dismissing the camera)
	var onAccept: ((UIImage, Data) -> Void)?
	/// Called when the user taps Done to close the camera session
	var onDone: (() -> Void)?
	var onError: (() -> Void)?
	private var photoCount = 0

	override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
		return .portrait
	}

	override var shouldAutorotate: Bool {
		return false
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		if #available(iOS 13.0, *) {
			isModalInPresentation = true
		}

		picker.sourceType = .camera
		picker.allowsEditing = false
		picker.showsCameraControls = false
		picker.cameraOverlayView = overlayView
		picker.delegate = self

		addChild(picker)
		view.addSubview(picker.view)
		picker.didMove(toParent: self)

		// Set up overlay transitions
		overlayView.shutterButton.addTarget(self, action: #selector(shutterTapped), for: .touchUpInside)
		overlayView.retakeButton.addTarget(self, action: #selector(retakeTapped), for: .touchUpInside)
		overlayView.acceptButton.addTarget(self, action: #selector(acceptTapped), for: .touchUpInside)
		overlayView.doneButton.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
	}

	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()

		// Update frames to match current (portrait) geometry
		picker.view.frame = view.bounds
		overlayView.frame = view.bounds

		// Apply camera transform once after the view has settled into portrait
		if !hasAppliedCameraTransform, view.bounds.height > view.bounds.width {
			hasAppliedCameraTransform = true
			let screenSize = view.bounds.size
			let cameraAspectRatio: CGFloat = 4.0 / 3.0
			let previewHeight = screenSize.width * cameraAspectRatio
			let verticalOffset = (screenSize.height - previewHeight) / 2
			picker.cameraViewTransform = CGAffineTransform(translationX: 0, y: verticalOffset)
		}
	}

	@objc private func shutterTapped() {
		picker.takePicture()
		overlayView.acceptButton.isEnabled = false
		overlayView.switchToState(.reviewing)
	}

	@objc private func retakeTapped() {
		overlayView.hidePreview()
		overlayView.switchToState(.capturing)
	}

	@objc private func acceptTapped() {
		if let image = capturedImage,
		   let data = capturedImageData
		{
			photoCount += 1
			overlayView.photoCount = photoCount
			onAccept?(image, data)
		}
		// Return to capture mode for next photo
		capturedImage = nil
		capturedImageData = nil
		overlayView.hidePreview()
		overlayView.switchToState(.capturing)
	}

	@objc private func doneTapped() {
		dismiss(animated: true)
		onDone?()
	}

	func imagePickerController(_ picker: UIImagePickerController,
	                           didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any])
	{
		// get image
		let location = locationManager?.location
		let heading = locationManager?.heading
		guard let image = info[.originalImage] as? UIImage else {
			onError?()
			return
		}
		overlayView.showPreview(image)
		overlayView.switchToState(.reviewing)

		// converting to data is slow so we do it in the background so we can show the preview immediately
		DispatchQueue.global(qos: .userInitiated).async {
			let data = dataFor(image: image, location: location, heading: heading)
			DispatchQueue.main.sync {
				guard let data else {
					self.onError?()
					self.overlayView.hidePreview()
					self.overlayView.switchToState(.capturing)
					return
				}
				self.capturedImage = image
				self.capturedImageData = data
				self.overlayView.acceptButton.isEnabled = true
			}
		}
	}

	func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
		dismiss(animated: true)
	}
}
