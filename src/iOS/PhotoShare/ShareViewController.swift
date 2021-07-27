//
//  ShareViewController.swift
//  PhotoShare
//
//  Created by Bryce Cogswell on 7/19/21.
//  Copyright © 2021 Bryce. All rights reserved.
//

import Photos
import UIKit

/// Duplicated so we can re-use the URL parsing code in LocationParser
enum MapViewState: Int {
	case EDITOR
	case EDITORAERIAL
	case AERIAL
	case MAPNIK
}

struct MapLocation {
	var longitude = 0.0
	var latitude = 0.0
	var zoom = 0.0
	var viewState: MapViewState? = nil
}

class ShareViewController: UIViewController, URLSessionTaskDelegate {
	@IBOutlet var buttonOK: UIButton!
	@IBOutlet var popupView: UIView!
	@IBOutlet var popupText: UILabel!

	var location: CLLocationCoordinate2D?
	var photoText: String!

	override func viewDidLoad() {
		super.viewDidLoad()
		view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
		popupView.layer.cornerRadius = 10.0
		popupView.layer.masksToBounds = true
		popupView.layer.isOpaque = false
		buttonOK.isEnabled = false
		photoText = popupText.text
		popupText.text = NSLocalizedString("Processing data...",
		                                   comment: "")
	}

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		processShareItem()
	}

	@objc func openURL(_ url: URL) {}

	// intercept redirect when dealing with google maps
	func urlSession(_ session: URLSession,
	                task: URLSessionTask,
	                willPerformHTTPRedirection response: HTTPURLResponse,
	                newRequest request: URLRequest,
	                completionHandler: (URLRequest?) -> Void)
	{
		completionHandler(nil)
	}

	func setUnrecognizedText() {
		DispatchQueue.main.async {
			self.popupText.text = NSLocalizedString("The URL content isn't recognized.",
			                                        comment: "Error message when sharing a URL to Go Map!!")
		}
	}

	func processShareItem() {
		var found = false
		for item in extensionContext?.inputItems ?? [] {
			for provider in (item as? NSExtensionItem)?.attachments ?? [] {
				if provider.hasItemConformingToTypeIdentifier("public.image") {
					// A photo
					found = true
					provider.loadItem(forTypeIdentifier: "public.image", options: nil) { url, _ in
						if let url = url as? URL,
						   let data = NSData(contentsOf: url as URL),
						   let location = ExifGeolocation.location(forImage: data as Data)
						{
							DispatchQueue.main.async {
								self.location = location.coordinate
								self.buttonOK.isEnabled = true
								self.popupText.text = self.photoText
							}
						} else {
							DispatchQueue.main.async {
								var text = self.photoText!
								text += "\n\n"
								text += NSLocalizedString(
									"Unfortunately the selected image does not contain location information.",
									comment: "")
								self.popupText.text = text
							}
						}
					}
				} else if provider.hasItemConformingToTypeIdentifier("com.apple.mapkit.map-item") {
					// An MKMapItem. There should also be a URL we can use instead.
				} else if provider.hasItemConformingToTypeIdentifier("public.url") {
					found = true
					provider.loadItem(forTypeIdentifier: "public.url", options: nil) { url, _ in
						// decode as a location URL
						if let url = url as? URL,
						   let loc = LocationParser.mapLocationFrom(url: url)
						{
							DispatchQueue.main.async {
								self.location = CLLocationCoordinate2D(latitude: loc.latitude,
								                                       longitude: loc.longitude)
								self.buttonOK.isEnabled = true
								self.buttonPressOK()
							}
							return
						}

						// decode as a GPX file
						if let url = url as? URL {
							let request = NSMutableURLRequest(url: url)
							request.httpMethod = "HEAD"
							let task = URLSession.shared.dataTask(with: url) { _, response, _ in
								if let httpResponse = response as? HTTPURLResponse,
								   let contentType = httpResponse.allHeaderFields["Content-Type"] as? String,
								   contentType == "application/gpx+xml"
								{
									DispatchQueue.main.async {
										let url: String = url.absoluteString.data(using: .utf8)!.base64EncodedString()
										let app = URL(string: "gomaposm://?gpxurl=\(url)")!
										self.openApp(withUrl: app)
										self.extensionContext!.completeRequest(
											returningItems: [],
											completionHandler: nil)
									}
									return
								}
								self.setUnrecognizedText()
							}
							task.resume()
							return
						}

#if false
						// decode as google maps
						if let url = url as? URL,
						   let comps = URLComponents(url: url, resolvingAgainstBaseURL: true),
						   comps.host == "goo.gl"
						{
							// need to get the redirect to find the actual location
							let configuration = URLSessionConfiguration.default
							let session = URLSession(configuration: configuration,
							                         delegate: self,
							                         delegateQueue: nil)
							let task = session.dataTask(with: url)
							task.resume()
						}
#endif

						// error
						self.setUnrecognizedText()
					}
				}
			}
		}
		if !found {
			extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
		}
	}

	func openApp(withUrl url: URL) {
		let selector = #selector(openURL(_:))
		var responder: UIResponder? = self as UIResponder
		while responder != nil {
			if responder!.responds(to: selector),
			   responder != self
			{
				responder!.perform(selector, with: url)
				return
			}
			responder = responder?.next
		}
	}

	@IBAction func buttonPressOK() {
		guard let coord = location else { return }
		let app = URL(string: "gomaposm://?center=\(coord.latitude),\(coord.longitude)")!
		openApp(withUrl: app)
		extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
	}

	@IBAction func buttonCancel() {
		extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
	}
}