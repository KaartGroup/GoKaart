//
//  ViewerUpload.swift
//  Go Map!!
//
//  Created by Claude Code on 3/19/26.
//  Copyright © 2026 Kaart Group. All rights reserved.
//

import AuthenticationServices
import CoreLocation
import CryptoKit
import ImageIO
import Network
import UIKit

// MARK: - ViewerAuth

class ViewerAuth: NSObject, ASWebAuthenticationPresentationContextProviding {
	static let shared = ViewerAuth()

	private let domain = "dev-p6r3cciondp4has2.us.auth0.com"
	private let clientId = "aIEX8Be7Vjf4zsdSI3MbRUcFeiyVa78D"
	private let clientSecret = "G-GbV8X7J3gSb1Chm1pswp_uVH_rcbsGMO3d40YQ9TlRd09PO5ZDnY8kDwAerg72"
	private let audience = "https://Viewer/api/authorize"
	private let redirectURI = "gomaposm://viewer/callback"

	private let accessTokenKey = "Viewer_access_token"
	private let refreshTokenKey = "Viewer_refresh_token"

	private(set) var accessToken: String?
	private(set) var refreshToken: String?
	private var authSession: ASWebAuthenticationSession?

	private override init() {
		super.init()
		accessToken = KeyChain.getStringForIdentifier(accessTokenKey)
		refreshToken = KeyChain.getStringForIdentifier(refreshTokenKey)
	}

	var isLoggedIn: Bool {
		accessToken != nil
	}

	// MARK: ASWebAuthenticationPresentationContextProviding

	func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
		UIApplication.shared.connectedScenes
			.compactMap { $0 as? UIWindowScene }
			.flatMap(\.windows)
			.first(where: \.isKeyWindow) ?? ASPresentationAnchor()
	}

	// MARK: Login

	func login() async throws {
		let codeVerifier = generateCodeVerifier()
		let codeChallenge = generateCodeChallenge(from: codeVerifier)

		var components = URLComponents(string: "https://\(domain)/authorize")!
		components.queryItems = [
			URLQueryItem(name: "client_id", value: clientId),
			URLQueryItem(name: "redirect_uri", value: redirectURI),
			URLQueryItem(name: "response_type", value: "code"),
			URLQueryItem(name: "scope", value: "openid profile email offline_access"),
			URLQueryItem(name: "audience", value: audience),
			URLQueryItem(name: "code_challenge", value: codeChallenge),
			URLQueryItem(name: "code_challenge_method", value: "S256")
		]

		guard let authorizeURL = components.url else {
			throw ViewerAuthError.invalidURL
		}

		let callbackURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
			let session = ASWebAuthenticationSession(
				url: authorizeURL,
				callbackURLScheme: "gomaposm"
			) { [weak self] url, error in
				self?.authSession = nil
				if let error = error {
					continuation.resume(throwing: error)
				} else if let url = url {
					continuation.resume(returning: url)
				} else {
					continuation.resume(throwing: ViewerAuthError.missingCallback)
				}
			}
			session.presentationContextProvider = self
			session.prefersEphemeralWebBrowserSession = false
			self.authSession = session
			session.start()
		}

		guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
		      let code = components.queryItems?.first(where: { $0.name == "code" })?.value
		else {
			throw ViewerAuthError.missingAuthCode
		}

		try await exchangeCode(code, codeVerifier: codeVerifier)
	}

	// MARK: Token Exchange

	private func exchangeCode(_ code: String, codeVerifier: String) async throws {
		let url = URL(string: "https://\(domain)/oauth/token")!
		var request = URLRequest(url: url)
		request.httpMethod = "POST"
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")

		let body: [String: String] = [
			"grant_type": "authorization_code",
			"client_id": clientId,
			"client_secret": clientSecret,
			"code": code,
			"redirect_uri": redirectURI,
			"code_verifier": codeVerifier
		]
		request.httpBody = try JSONSerialization.data(withJSONObject: body)

		let data = try await URLSession.shared.data(with: request)
		try parseTokenResponse(data)
	}

	// MARK: Token Refresh

	func refreshAccessToken() async throws {
		guard let refreshToken = refreshToken else {
			throw ViewerAuthError.noRefreshToken
		}

		let url = URL(string: "https://\(domain)/oauth/token")!
		var request = URLRequest(url: url)
		request.httpMethod = "POST"
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")

		let body: [String: String] = [
			"grant_type": "refresh_token",
			"client_id": clientId,
			"client_secret": clientSecret,
			"refresh_token": refreshToken
		]
		request.httpBody = try JSONSerialization.data(withJSONObject: body)

		let data = try await URLSession.shared.data(with: request)
		try parseTokenResponse(data)
	}

	// MARK: Get Valid Token

	func getValidToken() async throws -> String {
		if let token = accessToken {
			// Check if token is expired by decoding JWT payload
			if !isTokenExpired(token) {
				return token
			}
			// Try refresh
			if refreshToken != nil {
				do {
					try await refreshAccessToken()
					if let token = accessToken {
						return token
					}
				} catch {
					// Refresh failed, need re-login
				}
			}
		}
		// Need full login
		try await login()
		guard let token = accessToken else {
			throw ViewerAuthError.loginFailed
		}
		return token
	}

	// MARK: Logout

	func logout() {
		accessToken = nil
		refreshToken = nil
		KeyChain.deleteString(forIdentifier: accessTokenKey)
		KeyChain.deleteString(forIdentifier: refreshTokenKey)
	}

	// MARK: Private Helpers

	private func parseTokenResponse(_ data: Data) throws {
		guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
			throw ViewerAuthError.invalidResponse
		}

		if let error = json["error"] as? String {
			let description = json["error_description"] as? String ?? error
			throw ViewerAuthError.serverError(description)
		}

		guard let newAccessToken = json["access_token"] as? String else {
			throw ViewerAuthError.missingToken
		}

		accessToken = newAccessToken
		_ = KeyChain.setString(newAccessToken, forIdentifier: accessTokenKey)

		if let newRefreshToken = json["refresh_token"] as? String {
			refreshToken = newRefreshToken
			_ = KeyChain.setString(newRefreshToken, forIdentifier: refreshTokenKey)
		}
	}

	private func isTokenExpired(_ token: String) -> Bool {
		let parts = token.split(separator: ".")
		guard parts.count == 3 else { return true }

		var payload = String(parts[1])
		// Pad base64 string
		let remainder = payload.count % 4
		if remainder > 0 {
			payload += String(repeating: "=", count: 4 - remainder)
		}

		guard let data = Data(base64Encoded: payload),
		      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
		      let exp = json["exp"] as? TimeInterval
		else {
			return true
		}

		// Consider expired 60 seconds early
		return Date().timeIntervalSince1970 >= (exp - 60)
	}

	private func generateCodeVerifier() -> String {
		var buffer = [UInt8](repeating: 0, count: 32)
		_ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
		return Data(buffer).base64EncodedString()
			.replacingOccurrences(of: "+", with: "-")
			.replacingOccurrences(of: "/", with: "_")
			.replacingOccurrences(of: "=", with: "")
	}

	private func generateCodeChallenge(from verifier: String) -> String {
		guard let data = verifier.data(using: .utf8) else { return "" }
		let hash = SHA256.hash(data: data)
		return Data(hash).base64EncodedString()
			.replacingOccurrences(of: "+", with: "-")
			.replacingOccurrences(of: "/", with: "_")
			.replacingOccurrences(of: "=", with: "")
	}
}

enum ViewerAuthError: LocalizedError {
	case invalidURL
	case missingCallback
	case missingAuthCode
	case noRefreshToken
	case loginFailed
	case invalidResponse
	case missingToken
	case serverError(String)

	var errorDescription: String? {
		switch self {
		case .invalidURL: return "Invalid authorization URL"
		case .missingCallback: return "No callback received"
		case .missingAuthCode: return "Authorization code not found"
		case .noRefreshToken: return "No refresh token available — please log in again"
		case .loginFailed: return "Login failed"
		case .invalidResponse: return "Invalid server response"
		case .missingToken: return "Access token not found in response"
		case .serverError(let msg): return msg
		}
	}
}

// MARK: - ViewerUploader

class ViewerUploader {
	static let shared = ViewerUploader()
	private let baseURL = "https://viewer.kaart.com/backend/api/still-images/upload"
	private let geocoder = CLGeocoder()

	func uploadStillImage(
		imageData: Data,
		location: CLLocation,
		heading: Double?,
		capturedAt: Date,
		country: String? = nil,
		city: String? = nil
	) async throws -> [String: Any] {
		let token = try await ViewerAuth.shared.getValidToken()

		// Use provided country/city or reverse geocode
		let resolvedCountry: String
		let resolvedCity: String
		if let country = country, let city = city {
			resolvedCountry = country
			resolvedCity = city
		} else {
			(resolvedCountry, resolvedCity) = await reverseGeocode(location: location)
		}

		// Build multipart request
		let boundary = "Boundary-\(UUID().uuidString)"
		var request = URLRequest(url: URL(string: baseURL)!)
		request.setUserAgent()
		request.httpMethod = "POST"
		request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
		request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

		var body = Data()

		// Image file
		appendFormField(&body, boundary: boundary, name: "image", filename: "photo.jpg",
		                contentType: "image/jpeg", data: imageData)

		// Required fields
		appendTextField(&body, boundary: boundary, name: "latitude",
		                value: String(location.coordinate.latitude))
		appendTextField(&body, boundary: boundary, name: "longitude",
		                value: String(location.coordinate.longitude))

		let formatter = ISO8601DateFormatter()
		formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
		appendTextField(&body, boundary: boundary, name: "captured_at",
		                value: formatter.string(from: capturedAt))

		// Optional fields
		appendTextField(&body, boundary: boundary, name: "altitude",
		                value: String(location.altitude))

		if let heading = heading {
			appendTextField(&body, boundary: boundary, name: "heading",
			                value: String(heading))
		}

		appendTextField(&body, boundary: boundary, name: "accuracy",
		                value: String(location.horizontalAccuracy))

		let deviceId: String? = await MainActor.run { UIDevice.current.identifierForVendor?.uuidString }
		if let deviceId {
			appendTextField(&body, boundary: boundary, name: "device_id", value: deviceId)
		}

		appendTextField(&body, boundary: boundary, name: "country", value: resolvedCountry)
		appendTextField(&body, boundary: boundary, name: "city", value: resolvedCity)

		// Close boundary
		body.append("--\(boundary)--\r\n".data(using: .utf8)!)
		request.httpBody = body

		// Send request, retry once on 401
		do {
			return try await sendRequest(request)
		} catch UrlSessionError.badStatusCode(401, _) {
			// Attempt token refresh and retry
			try await ViewerAuth.shared.refreshAccessToken()
			let newToken = try await ViewerAuth.shared.getValidToken()
			request.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
			return try await sendRequest(request)
		}
	}

	private func sendRequest(_ request: URLRequest) async throws -> [String: Any] {
		let data = try await URLSession.shared.data(with: request)
		guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
			throw ViewerUploadError.invalidResponse
		}
		return json
	}

	private func reverseGeocode(location: CLLocation) async -> (country: String, city: String) {
		do {
			let placemarks = try await geocoder.reverseGeocodeLocation(location)
			let placemark = placemarks.first
			return (
				country: placemark?.country ?? "Unknown",
				city: placemark?.locality ?? "Unknown"
			)
		} catch {
			return ("Unknown", "Unknown")
		}
	}

	private func appendTextField(_ body: inout Data, boundary: String, name: String, value: String) {
		body.append("--\(boundary)\r\n".data(using: .utf8)!)
		body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
		body.append("\(value)\r\n".data(using: .utf8)!)
	}

	private func appendFormField(_ body: inout Data, boundary: String, name: String,
	                             filename: String, contentType: String, data: Data)
	{
		body.append("--\(boundary)\r\n".data(using: .utf8)!)
		body.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
		body.append("Content-Type: \(contentType)\r\n\r\n".data(using: .utf8)!)
		body.append(data)
		body.append("\r\n".data(using: .utf8)!)
	}
}

enum ViewerUploadError: LocalizedError {
	case invalidResponse
	case uploadFailed(String)

	var errorDescription: String? {
		switch self {
		case .invalidResponse: return "Invalid response from server"
		case .uploadFailed(let msg): return "Upload failed: \(msg)"
		}
	}
}

// MARK: - ViewerUploadQueue

/// Persistent offline upload queue. Saves images + metadata to disk immediately,
/// then uploads in the background. Monitors connectivity and drains the queue
/// when a connection becomes available.
class ViewerUploadQueue {
	static let shared = ViewerUploadQueue()

	private let queueDirectory: URL
	private let monitor = NWPathMonitor()
	private let monitorQueue = DispatchQueue(label: "com.kaart.uploadQueue.monitor")
	private let lock = NSLock()
	private var _isProcessing = false
	private var _hasConnection = true

	private var isProcessing: Bool {
		get { lock.lock(); defer { lock.unlock() }; return _isProcessing }
		set { lock.lock(); defer { lock.unlock() }; _isProcessing = newValue }
	}
	private var hasConnection: Bool {
		get { lock.lock(); defer { lock.unlock() }; return _hasConnection }
		set { lock.lock(); defer { lock.unlock() }; _hasConnection = newValue }
	}

	/// Whether the device currently has a network connection
	var currentlyConnected: Bool { hasConnection }

	/// Number of items waiting to upload
	var pendingCount: Int {
		(try? FileManager.default.contentsOfDirectory(atPath: queueDirectory.path)
			.filter { $0.hasSuffix(".json") }.count) ?? 0
	}

	private init() {
		let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
		queueDirectory = appSupport.appendingPathComponent("ViewerUploadQueue", isDirectory: true)
		try? FileManager.default.createDirectory(at: queueDirectory, withIntermediateDirectories: true)

		// Monitor connectivity
		monitor.pathUpdateHandler = { [weak self] path in
			self?.hasConnection = path.status == .satisfied
			if path.status == .satisfied {
				self?.processQueue()
			}
		}
		monitor.start(queue: monitorQueue)

		// Drain any items left from previous session
		processQueue()
	}

	/// Save an image + metadata to the disk queue, then attempt upload.
	func enqueue(imageData: Data, location: CLLocation, heading: Double?, capturedAt: Date,
	             country: String, city: String) {
		let id = UUID().uuidString

		// Save image
		let imageFile = queueDirectory.appendingPathComponent("\(id).jpg")
		try? imageData.write(to: imageFile)

		// Save metadata
		let meta: [String: Any] = [
			"id": id,
			"latitude": location.coordinate.latitude,
			"longitude": location.coordinate.longitude,
			"altitude": location.altitude,
			"accuracy": location.horizontalAccuracy,
			"heading": heading as Any,
			"captured_at": ISO8601DateFormatter().string(from: capturedAt),
			"country": country,
			"city": city
		]
		let metaFile = queueDirectory.appendingPathComponent("\(id).json")
		if let jsonData = try? JSONSerialization.data(withJSONObject: meta) {
			try? jsonData.write(to: metaFile)
		}

		processQueue()
	}

	/// Process all queued items. Runs on a background task.
	private func processQueue() {
		guard !isProcessing else { return }
		guard hasConnection else { return }
		isProcessing = true

		Task {
			defer { isProcessing = false }

			let metaFiles = (try? FileManager.default.contentsOfDirectory(atPath: queueDirectory.path)
				.filter { $0.hasSuffix(".json") }
				.sorted()) ?? []

			for metaFilename in metaFiles {
				guard hasConnection else { break }

				let metaURL = queueDirectory.appendingPathComponent(metaFilename)
				let id = metaFilename.replacingOccurrences(of: ".json", with: "")
				let imageURL = queueDirectory.appendingPathComponent("\(id).jpg")

				guard FileManager.default.fileExists(atPath: imageURL.path),
				      let metaData = try? Data(contentsOf: metaURL),
				      let meta = try? JSONSerialization.jsonObject(with: metaData) as? [String: Any],
				      let imageData = try? Data(contentsOf: imageURL)
				else {
					// Corrupted entry — remove it
					try? FileManager.default.removeItem(at: metaURL)
					try? FileManager.default.removeItem(at: imageURL)
					continue
				}

				let lat = meta["latitude"] as? Double ?? 0
				let lng = meta["longitude"] as? Double ?? 0
				let alt = meta["altitude"] as? Double ?? 0
				let acc = meta["accuracy"] as? Double ?? 0
				let heading = meta["heading"] as? Double
				let capturedStr = meta["captured_at"] as? String ?? ""
				let capturedAt = ISO8601DateFormatter().date(from: capturedStr) ?? Date()

				let location = CLLocation(
					coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng),
					altitude: alt,
					horizontalAccuracy: acc,
					verticalAccuracy: -1,
					timestamp: capturedAt
				)

				let country = meta["country"] as? String
				let city = meta["city"] as? String

				do {
					_ = try await ViewerUploader.shared.uploadStillImage(
						imageData: imageData,
						location: location,
						heading: heading,
						capturedAt: capturedAt,
						country: country,
						city: city
					)
					// Success — remove from queue
					try? FileManager.default.removeItem(at: metaURL)
					try? FileManager.default.removeItem(at: imageURL)
				} catch let error as URLError where error.code == .notConnectedToInternet
					|| error.code == .networkConnectionLost
					|| error.code == .timedOut {
					// Network error — stop processing, retry when connection returns
					break
				} catch {
					// Other error (server reject, auth failure, etc.) — skip this item, try next
					continue
				}
			}
		}
	}
}

// MARK: - ViewerUploadViewController

/// Handles Viewer still image capture and upload.
/// Presents PhotoCapture directly from the calling VC (no intermediate VC layering).
/// After photo acceptance, shows upload progress and result alerts on the presenting VC.
class ViewerUploadViewController {
	private static let locationManager = CLLocationManager()

	/// Call this from MainViewController to start the capture flow.
	static func presentCapture(from presenter: UIViewController) {
		locationManager.startUpdatingLocation()
		locationManager.startUpdatingHeading()

		var sessionPhotoCount = 0

		let photoPicker = PhotoCapture()
		photoPicker.locationManager = locationManager
		photoPicker.onError = {
			// Photo capture failed for this frame — user can retake
		}
		photoPicker.onAccept = { image, imageData in
			// Queue each photo for upload without dismissing the camera
			sessionPhotoCount += 1
			Task { @MainActor in
				await enqueuePhoto(imageData: imageData)
			}
		}
		photoPicker.onDone = {
			// Camera session finished — stop location updates and show summary
			locationManager.stopUpdatingLocation()
			locationManager.stopUpdatingHeading()
			if sessionPhotoCount > 0 {
				Task { @MainActor in
					showSessionSummary(photoCount: sessionPhotoCount, on: presenter)
				}
			}
		}
		photoPicker.modalPresentationStyle = .fullScreen
		presenter.present(photoPicker, animated: true)
	}

	@MainActor
	private static func enqueuePhoto(imageData: Data) async {
		guard let location = extractLocation(from: imageData) else {
			return
		}

		let heading = extractHeading(from: imageData)

		let geocoder = CLGeocoder()
		var country = "Unknown"
		var city = "Unknown"
		if let placemarks = try? await geocoder.reverseGeocodeLocation(location) {
			country = placemarks.first?.country ?? "Unknown"
			city = placemarks.first?.locality ?? "Unknown"
		}

		ViewerUploadQueue.shared.enqueue(
			imageData: imageData,
			location: location,
			heading: heading,
			capturedAt: Date(),
			country: country,
			city: city
		)
	}

	@MainActor
	private static func showSessionSummary(photoCount: Int, on presenter: UIViewController) {
		let pending = ViewerUploadQueue.shared.pendingCount
		let hasNetwork = ViewerUploadQueue.shared.currentlyConnected
		let message: String
		if !hasNetwork {
			message = String(format: NSLocalizedString("%d photo(s) saved. Will upload when connection is restored.", comment: ""), photoCount)
		} else if pending > 0 {
			message = String(format: NSLocalizedString("%d photo(s) saved. %d upload(s) pending.", comment: ""), photoCount, pending)
		} else {
			message = String(format: NSLocalizedString("%d photo(s) saved. Uploading...", comment: ""), photoCount)
		}
		showAlert(
			on: presenter,
			title: NSLocalizedString("Session Complete", comment: ""),
			message: message
		)
	}

	private static func extractLocation(from imageData: Data) -> CLLocation? {
		guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
		      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
		      let gps = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any],
		      let latitude = gps[kCGImagePropertyGPSLatitude as String] as? Double,
		      let longitude = gps[kCGImagePropertyGPSLongitude as String] as? Double,
		      let latRef = gps[kCGImagePropertyGPSLatitudeRef as String] as? String,
		      let lonRef = gps[kCGImagePropertyGPSLongitudeRef as String] as? String
		else {
			return nil
		}

		let lat = latRef == "S" ? -latitude : latitude
		let lon = lonRef == "W" ? -longitude : longitude
		let altitude = gps[kCGImagePropertyGPSAltitude as String] as? Double ?? 0
		let accuracy = gps[kCGImagePropertyGPSHPositioningError as String] as? Double ?? 0

		return CLLocation(
			coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
			altitude: altitude,
			horizontalAccuracy: accuracy,
			verticalAccuracy: -1,
			timestamp: Date()
		)
	}

	private static func extractHeading(from imageData: Data) -> Double? {
		guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
		      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
		      let gps = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any],
		      let imgDirection = gps[kCGImagePropertyGPSImgDirection as String] as? Double
		else {
			return nil
		}
		return imgDirection
	}

	@MainActor
	private static func showAlert(on presenter: UIViewController, title: String, message: String) {
		let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
		alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default))
		presenter.present(alert, animated: true)
	}
}
