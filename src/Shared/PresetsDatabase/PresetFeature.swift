//
//  PresetFeature.swift
//  Go Map!!
//
//  Created by Bryce Cogswell on 12/11/20.
//  Copyright © 2020 Bryce Cogswell. All rights reserved.
//

import Foundation
import UIKit

// A feature-defining tag such as amenity=shop
class PresetFeature {

	static let uninitializedImage = UIImage()

	let featureID: String

	// from json dictionary:
	let _addTags: [String : String]?
	let fields: [String]?
	let geometry: [String]
	let icon: String?							// icon on the map
	let logoURL: String?					// NSI brand image
	let locationSet: [String: [String]]?
	let matchScore: Double
	let moreFields: [String]?
	let name: String?
	let reference: [String : String]?
	let _removeTags: [String : String]?
	let searchable: Bool
	let tags: [String : String]
	let terms: [String]

	init(withID featureID:String, jsonDict:[String:Any], isNSI:Bool)
	{
		self.featureID = featureID

		self._addTags = jsonDict["addTags"] as? [String: String]
		self.fields = jsonDict["fields"] as? [String]
		self.geometry = jsonDict["geometry"] as? [String] ?? []
		self.icon = jsonDict["icon"] as? String
		self.logoURL = jsonDict["imageURL"] as? String
		self.locationSet = PresetFeature.convertLocationSet( jsonDict["locationSet"] as? [String: [String]] )
		self.matchScore = jsonDict["matchScore"] as? Double ?? 1.0
		self.moreFields = jsonDict["moreFields"] as? [String]
		self.name = jsonDict["name"] as? String
		self.reference = jsonDict["reference"] as? [String : String]
		self._removeTags = jsonDict["removeTags"] as? [String: String]
		self.searchable = jsonDict["searchable"] as? Bool ?? true
		self.tags = jsonDict["tags"] as! [String: String]
		if let terms = jsonDict["terms"] as? String {
			self.terms = terms.split(separator: ",").map({ String($0) })
		} else {
			self.terms = jsonDict["terms"] as? [String] ?? jsonDict["matchNames"] as? [String] ?? []
		}

		self.nsiSuggestion = isNSI
	}

	class func convertLocationSet( _ locationSet:[String:[String]]? ) -> [String:[String]]?
	{
		// convert locations to country codes
		guard var includes = locationSet?["include"] else { return nil }
		for i in 0 ..< includes.count {
			switch includes[i] {
			case "conus":
				includes[i] = "us"
			case "001":
				return nil
			default:
				continue
			}
		}
		return ["include":includes]
	}

	let nsiSuggestion: Bool		// is from NSI
	var nsiLogo: UIImage? = nil	// from NSI imageURL

	var _iconUnscaled: UIImage? = PresetFeature.uninitializedImage
	var _iconScaled24: UIImage? = PresetFeature.uninitializedImage

	var description : String {
		return self.featureID
	}

	func friendlyName() -> String
	{
		return self.name ?? self.featureID
	}

	func summary() -> String? {
		let parentID = PresetFeature.parentIDofID( self.featureID )
		let result = PresetsDatabase.shared.inheritedValueOfFeature(parentID, fieldGetter: { $0.name })
		return result as? String
	}

	func iconUnscaled() -> UIImage? {
		if _iconUnscaled == PresetFeature.uninitializedImage {
			_iconUnscaled = self.icon != nil ? UIImage(named: self.icon!) : nil
		}
		return _iconUnscaled
	}
	func iconScaled24() -> UIImage?
	{
		if _iconScaled24 == PresetFeature.uninitializedImage {
			if let image = self.iconUnscaled() {
				_iconScaled24 = EditorMapLayer.IconScaledForDisplay( image )
			} else {
				_iconScaled24 = nil
			}
		}
		return _iconScaled24
	}

	func addTags() -> [String : String] {
		return self._addTags ?? self.tags
	}

	func removeTags() -> [String : String] {
		return self._removeTags ?? self.addTags()
	}

	class func parentIDofID(_ featureID:String) -> String?
	{
		if let range = featureID.range(of: "/", options: .backwards, range: nil, locale: nil) {
			return String( featureID.prefix(upTo: range.lowerBound) )
		}
		return nil
	}

	func matchesSearchText(_ searchText: String?, geometry:String) -> Bool {
		guard let searchText = searchText else {
			return false
		}
		if !self.geometry.contains(geometry) {
			return false
		}
		if self.featureID.range(of: searchText, options: [.caseInsensitive,.diacriticInsensitive]) != nil {
			return true
		}
		if self.name?.range(of: searchText, options: [.caseInsensitive,.diacriticInsensitive]) != nil {
			return true
		}
		for term in self.terms {
			if term.range(of: searchText, options: [.caseInsensitive,.diacriticInsensitive]) != nil {
				return true
			}
		}
		return false
	}

	func matchObjectTagsScore(_ objectTags: [String: String], geometry: String) -> Double
	{
		guard self.geometry.contains(geometry) else { return 0.0 }

		var totalScore = 1.0

		var seen = Set<String>()
		for (key, value) in self.tags {
			seen.insert(key)

			var v: String?
			if key.hasSuffix("*") {
				let c = String(key.dropLast())
				v = objectTags.first(where: { (key: String, _: String) -> Bool in
					key.hasPrefix(c)
				})?.value
			} else {
				v = objectTags[key]
			}
			if let v = v {
				if value == v {
					totalScore += self.matchScore
					continue
				}
				if value == "*" {
					totalScore += self.matchScore / 2
					continue
				}
			} else if key == "area", value == "yes", geometry == "area" {
				totalScore += 0.1
				continue
			}
			return 0.0 // invalid match
		}

		// boost score for additional matches in addTags
		if let addTags = self._addTags {
			for (key, val) in addTags {
				if !seen.contains(key), objectTags[key] == val {
					totalScore += self.matchScore
				}
			}
		}
		return totalScore
	}

	func defaultValuesForGeometry(_ geometry: String) -> [String : String]
	{
		var result : [String : String] = [:]
		let fields = PresetsForFeature.fieldsFor(featureID:self.featureID, field:{ f in return f.fields })
		for fieldName in fields {
			if let field = PresetsDatabase.shared.jsonFields[fieldName] as? [String:Any],
			   let key = field["key"] as? String,
			   let def = field["default"] as? String,
			   let geom = field["geometry"] as? [String],
			   geom.contains(geometry)
			{
				result[key] = def
			}
		}
		return result
	}
}
