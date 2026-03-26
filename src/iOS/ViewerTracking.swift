//
//  ViewerTracking.swift
//  Go Map!!
//
//  Viewer live vehicle tracking service.
//  Sends GPS pings to Viewer backend at a user-configured interval.
//  Queues pings offline and batch-uploads when connectivity returns.
//

import CoreLocation
import Network
import UIKit

// MARK: - ViewerTrackingService

class ViewerTrackingService {
	static let shared = ViewerTrackingService()

	private let baseURL = "https://viewer.kaart.com/backend/api/vehicle"
	private let queueDirectory: URL
	private let monitor = NWPathMonitor()
	private let monitorQueue = DispatchQueue(label: "com.kaart.tracking.monitor")
	private let lock = NSLock()

	private var _hasConnection = true
	private var hasConnection: Bool {
		get { lock.lock(); defer { lock.unlock() }; return _hasConnection }
		set { lock.lock(); defer { lock.unlock() }; _hasConnection = newValue }
	}

	private var pingTimer: Timer?
	private var latestLocation: CLLocation?
	private var isRunning = false

	private init() {
		let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
		queueDirectory = appSupport.appendingPathComponent("ViewerPingQueue", isDirectory: true)
		try? FileManager.default.createDirectory(at: queueDirectory, withIntermediateDirectories: true)

		monitor.pathUpdateHandler = { [weak self] path in
			self?.hasConnection = path.status == .satisfied
			if path.status == .satisfied {
				self?.drainQueue()
			}
		}
		monitor.start(queue: monitorQueue)
	}

	/// Number of offline pings waiting to upload
	var pendingPingCount: Int {
		(try? FileManager.default.contentsOfDirectory(atPath: queueDirectory.path)
			.filter { $0.hasSuffix(".json") }.count) ?? 0
	}

	// MARK: - Start / Stop

	func start() {
		guard !isRunning else {
			print("[ViewerTracking] start() skipped — already running")
			return
		}

		print("[ViewerTracking] start() called")
		isRunning = true

		Task {
			do {
				let token = try await ViewerAuth.shared.getValidToken()
				print("[ViewerTracking] Got valid token: \(token.prefix(20))...")
				await MainActor.run { self.continueStart() }
			} catch {
				print("[ViewerTracking] Auth failed: \(error.localizedDescription)")
				isRunning = false
			}
		}
	}

	private func continueStart() {
		print("[ViewerTracking] continueStart() — setting up location + timer")

		// Enable background location and ensure location manager is running
		LocationProvider.shared.allowsBackgroundLocationUpdates = true
		LocationProvider.shared.ensureUpdatingLocation()

		// Subscribe to location updates
		LocationProvider.shared.onChangeLocation.subscribe(self) { [weak self] location in
			self?.latestLocation = location
		}

		// Observe interval changes to restart timer
		UserPrefs.shared.vehicleTrackingInterval.onChange.subscribe(self) { [weak self] _ in
			DispatchQueue.main.async {
				self?.restartTimer()
			}
		}

		// Register device if needed, then start pinging
		Task {
			await ensureRegistered()
			await MainActor.run {
				self.restartTimer()
			}
			// Drain any offline pings from previous session
			drainQueue()
		}
	}

	func stop() {
		guard isRunning else { return }
		isRunning = false

		pingTimer?.invalidate()
		pingTimer = nil

		// Unsubscribe from notifications
		LocationProvider.shared.onChangeLocation.unsubscribe(self)
		UserPrefs.shared.vehicleTrackingInterval.onChange.unsubscribe(self)

		// Only disable background location if GPX recording doesn't need it
		let gpxNeedsBackground = GpxLayer.recordTracksInBackground
		if !gpxNeedsBackground {
			LocationProvider.shared.allowsBackgroundLocationUpdates = false
		}

		NotificationCenter.default.post(
			name: NSNotification.Name("CollectGpxTracksInBackgroundChanged"),
			object: nil)
	}

	// MARK: - Registration

	private func ensureRegistered() async {
		// Force re-registration to fix org_id mismatch (one-time)
		// TODO: Remove this after first successful re-registration
		if UserPrefs.shared.vehicleId.value == 1 {
			print("[ViewerTracking] Clearing stale vehicle_id=1 to re-register with correct org")
			UserPrefs.shared.vehicleId.value = nil
		}

		if UserPrefs.shared.vehicleId.value != nil {
			print("[ViewerTracking] Already registered with vehicle_id: \(UserPrefs.shared.vehicleId.value!)")
			return
		}

		print("[ViewerTracking] Attempting registration...")

		let vendorId = await MainActor.run { UIDevice.current.identifierForVendor?.uuidString }
		let deviceId = vendorId ?? UUID().uuidString
		let deviceName = await MainActor.run { UIDevice.current.name }
		let vehicleName = UserPrefs.shared.vehicleName.value ?? deviceName
		let interval = UserPrefs.shared.vehicleTrackingInterval.value ?? 30

		guard let token = try? await ViewerAuth.shared.getValidToken() else {
			print("[ViewerTracking] ensureRegistered: no valid token")
			return
		}

		let deviceModel = await MainActor.run { UIDevice.current.model }
		let iosVersion = await MainActor.run { UIDevice.current.systemVersion }
		let body: [String: Any] = [
			"device_id": deviceId,
			"vehicle_name": vehicleName,
			"org_id": "org_9alzx7S32reIQ86s",
			"ping_interval_seconds": interval,
			"device_model": deviceModel,
			"ios_version": iosVersion,
			"app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
		]

		guard let url = URL(string: "\(baseURL)/register"),
		      let jsonData = try? JSONSerialization.data(withJSONObject: body)
		else { return }

		var request = URLRequest(url: url)
		request.httpMethod = "POST"
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
		request.httpBody = jsonData

		print("[ViewerTracking] POST \(url.absoluteString)")
		print("[ViewerTracking] Body: \(String(data: jsonData, encoding: .utf8) ?? "nil")")

		do {
			let data = try await URLSession.shared.data(with: request)
			let responseStr = String(data: data, encoding: .utf8) ?? "non-utf8"
			print("[ViewerTracking] Registration response: \(responseStr)")
			if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
				if let vehicleId = json["vehicle_id"] as? Int {
					UserPrefs.shared.vehicleId.value = vehicleId
					print("[ViewerTracking] Registered with vehicle_id: \(vehicleId)")
				} else {
					print("[ViewerTracking] Response missing vehicle_id: \(json)")
				}
			}
		} catch {
			print("[ViewerTracking] Registration error: \(error)")
		}
	}

	// MARK: - Ping Timer

	private func restartTimer() {
		assert(Thread.isMainThread, "restartTimer must be called on main thread")
		pingTimer?.invalidate()
		let interval = TimeInterval(UserPrefs.shared.vehicleTrackingInterval.value ?? 30)
		print("[ViewerTracking] Starting ping timer with interval: \(interval)s")
		pingTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
			self?.sendPing()
		}
		// Fire immediately
		sendPing()
	}

	private func sendPing() {
		guard let vehicleId = UserPrefs.shared.vehicleId.value else {
			print("[ViewerTracking] sendPing: no vehicle_id")
			return
		}
		guard let location = latestLocation else {
			print("[ViewerTracking] sendPing: no location yet")
			return
		}

		let formatter = ISO8601DateFormatter()
		formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

		let ping: [String: Any] = [
			"vehicle_id": vehicleId,
			"latitude": location.coordinate.latitude,
			"longitude": location.coordinate.longitude,
			"timestamp": formatter.string(from: location.timestamp),
			"accuracy": location.horizontalAccuracy,
			"altitude": location.altitude,
			"speed": max(0, location.speed),
			"heading": location.course >= 0 ? location.course : 0
		]

		// Always save to queue first, then try to drain
		// This avoids the race where postPing silently fails and pings are lost
		savePingToQueue(ping)
		drainQueue()
	}

	// MARK: - Network

	private func postPing(_ ping: [String: Any]) async {
		guard let token = try? await ViewerAuth.shared.getValidToken(),
		      let url = URL(string: "\(baseURL)/ping"),
		      let jsonData = try? JSONSerialization.data(withJSONObject: ping)
		else {
			print("[ViewerTracking] postPing: failed to build request")
			return
		}

		var request = URLRequest(url: url)
		request.httpMethod = "POST"
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
		request.httpBody = jsonData

		do {
			let data = try await URLSession.shared.data(with: request)
			let resp = String(data: data, encoding: .utf8) ?? ""
			print("[ViewerTracking] Ping sent OK: \(resp.prefix(100))")
		} catch {
			print("[ViewerTracking] Ping failed: \(error) — queuing")
			savePingToQueue(ping)
		}
	}

	// MARK: - Offline Queue

	private func savePingToQueue(_ ping: [String: Any]) {
		let filename = "\(UUID().uuidString).json"
		let fileURL = queueDirectory.appendingPathComponent(filename)
		if let data = try? JSONSerialization.data(withJSONObject: ping) {
			try? data.write(to: fileURL)
		}
	}

	private var isDraining = false

	private func drainQueue() {
		guard hasConnection else {
			print("[ViewerTracking] drainQueue: no connection")
			return
		}
		guard !isDraining else { return }
		guard let vehicleId = UserPrefs.shared.vehicleId.value else { return }

		let files = (try? FileManager.default.contentsOfDirectory(atPath: queueDirectory.path)
			.filter { $0.hasSuffix(".json") }
			.sorted()) ?? []

		guard !files.isEmpty else { return }

		isDraining = true

		// Read up to 100 pings at a time to avoid huge payloads
		let batch = Array(files.prefix(100))
		var pings: [[String: Any]] = []
		var fileURLs: [URL] = []

		for filename in batch {
			let fileURL = queueDirectory.appendingPathComponent(filename)
			guard let data = try? Data(contentsOf: fileURL),
			      var ping = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
			else {
				try? FileManager.default.removeItem(at: fileURL)
				continue
			}
			ping.removeValue(forKey: "vehicle_id")
			pings.append(ping)
			fileURLs.append(fileURL)
		}

		guard !pings.isEmpty else {
			isDraining = false
			return
		}

		print("[ViewerTracking] drainQueue: sending batch of \(pings.count) pings")

		Task {
			defer { isDraining = false }

			guard let token = try? await ViewerAuth.shared.getValidToken(),
			      let url = URL(string: "\(baseURL)/ping/batch")
			else {
				print("[ViewerTracking] drainQueue: failed to get token or build URL")
				return
			}

			let body: [String: Any] = [
				"vehicle_id": vehicleId,
				"pings": pings
			]

			guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
				print("[ViewerTracking] drainQueue: failed to serialize JSON")
				return
			}

			var request = URLRequest(url: url)
			request.httpMethod = "POST"
			request.setValue("application/json", forHTTPHeaderField: "Content-Type")
			request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
			request.httpBody = jsonData

			do {
				let data = try await URLSession.shared.data(with: request)
				let resp = String(data: data, encoding: .utf8) ?? ""
				print("[ViewerTracking] drainQueue: batch sent OK (\(pings.count) pings): \(resp.prefix(100))")
				for fileURL in fileURLs {
					try? FileManager.default.removeItem(at: fileURL)
				}
				// If more files remain, drain again
				if files.count > batch.count {
					drainQueue()
				}
			} catch {
				print("[ViewerTracking] drainQueue: batch failed: \(error)")
			}
		}
	}
}

// MARK: - ViewerTrackingSettingsViewController

class ViewerTrackingSettingsViewController: UITableViewController {

	private let intervalOptions: [(label: String, seconds: Int)] = [
		("10 seconds", 10),
		("30 seconds", 30),
		("1 minute", 60),
		("2 minutes", 120),
		("5 minutes", 300),
		("10 minutes", 600),
	]

	private var enableSwitch: UISwitch!

	override func viewDidLoad() {
		super.viewDidLoad()
		title = "Vehicle Tracking"
		tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")

		enableSwitch = UISwitch()
		enableSwitch.isOn = UserPrefs.shared.vehicleTrackingEnabled.value ?? false
		enableSwitch.addTarget(self, action: #selector(enableToggled), for: .valueChanged)
	}

	@objc private func enableToggled() {
		let enabled = enableSwitch.isOn
		UserPrefs.shared.vehicleTrackingEnabled.value = enabled

		if enabled {
			// Default vehicle name if not set
			if UserPrefs.shared.vehicleName.value == nil {
				UserPrefs.shared.vehicleName.value = UIDevice.current.name
			}
			// Default interval if not set
			if UserPrefs.shared.vehicleTrackingInterval.value == nil {
				UserPrefs.shared.vehicleTrackingInterval.value = 30
			}
			ViewerTrackingService.shared.start()
		} else {
			ViewerTrackingService.shared.stop()
		}

		tableView.reloadData()
	}

	// MARK: - Table View Data Source

	override func numberOfSections(in tableView: UITableView) -> Int {
		return enableSwitch.isOn ? 3 : 1
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		switch section {
		case 0: return 2 // enable toggle + vehicle name
		case 1: return intervalOptions.count // interval picker
		case 2: return 2 // status info
		default: return 0
		}
	}

	override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		switch section {
		case 0: return "Live Tracking"
		case 1: return "Update Interval"
		case 2: return "Status"
		default: return nil
		}
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
		cell.accessoryView = nil
		cell.accessoryType = .none
		cell.selectionStyle = .none

		switch (indexPath.section, indexPath.row) {
		case (0, 0):
			cell.textLabel?.text = "Enable Live Tracking"
			cell.accessoryView = enableSwitch
		case (0, 1):
			let name = UserPrefs.shared.vehicleName.value ?? UIDevice.current.name
			cell.textLabel?.text = "Vehicle: \(name)"
			cell.selectionStyle = .default
			cell.accessoryType = .disclosureIndicator
		case (1, let row):
			let option = intervalOptions[row]
			cell.textLabel?.text = option.label
			let current = UserPrefs.shared.vehicleTrackingInterval.value ?? 30
			cell.accessoryType = current == option.seconds ? .checkmark : .none
			cell.selectionStyle = .default
		case (2, 0):
			let count = ViewerTrackingService.shared.pendingPingCount
			cell.textLabel?.text = "Queued pings: \(count)"
		case (2, 1):
			if let vid = UserPrefs.shared.vehicleId.value {
				cell.textLabel?.text = "Vehicle ID: \(vid)"
			} else {
				cell.textLabel?.text = "Not registered"
			}
		default:
			break
		}

		return cell
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		tableView.deselectRow(at: indexPath, animated: true)

		switch (indexPath.section, indexPath.row) {
		case (0, 1):
			// Edit vehicle name
			let alert = UIAlertController(title: "Vehicle Name", message: nil, preferredStyle: .alert)
			alert.addTextField { tf in
				tf.text = UserPrefs.shared.vehicleName.value ?? UIDevice.current.name
			}
			alert.addAction(UIAlertAction(title: "Save", style: .default) { _ in
				if let name = alert.textFields?.first?.text, !name.isEmpty {
					UserPrefs.shared.vehicleName.value = name
					tableView.reloadRows(at: [indexPath], with: .automatic)
				}
			})
			alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
			present(alert, animated: true)

		case (1, let row):
			// Select interval
			let option = intervalOptions[row]
			UserPrefs.shared.vehicleTrackingInterval.value = option.seconds
			tableView.reloadSections(IndexSet(integer: 1), with: .automatic)

		default:
			break
		}
	}
}
