//
//  QuestDefinition.swift
//  Go Map!!
//
//  Created by Bryce Cogswell on 2/8/23.
//  Copyright © 2023 Bryce. All rights reserved.
//

import UIKit

protocol QuestProtocol {
	var ident: String { get }
	var title: String { get }
	var icon: UIImage? { get }
	var presetKey: String { get }
	func appliesTo(_ object: OsmBaseObject) -> Bool
	func accepts(tagValue: String) -> Bool
}

enum QuestError: Error {
	case unknownKey(String)
	case unknownFeature(String)
}

struct QuestHighwaySurface: QuestProtocol {
	var ident: String { "QuestHighwaySurface" }
	var title: String { "Highway surface" }
	var presetKey: String { "surface" }
	var icon: UIImage? { nil }
	var presetField: PresetField

	func appliesTo(_ object: OsmBaseObject) -> Bool {
		if let way = object as? OsmWay,
		   way.tags["highway"] != nil,
		   way.tags["surface"] == nil
		{
			return true
		}
		return false
	}

	func accepts(tagValue: String) -> Bool {
		return !tagValue.isEmpty
	}
}

class QuestDefinition: QuestProtocol {
	// These items define the quest
	let ident: String // Uniquely identify the quest
	let title: String // Localized instructions on what action to take
	let icon: UIImage?
	let presetKey: String // The value the user is being asked to set
	let appliesToObject: (OsmBaseObject) -> Bool
	let acceptsValue: (String) -> Bool

	func appliesTo(_ object: OsmBaseObject) -> Bool {
		return appliesToObject(object)
	}

	func accepts(tagValue: String) -> Bool {
		return acceptsValue(tagValue)
	}

	init(ident: String,
	     title: String,
	     icon: UIImage?,
	     presetKey: String,
	     appliesToObject: @escaping (OsmBaseObject) -> Bool,
	     acceptsValue: @escaping (String) -> Bool)
	{
		self.ident = ident
		self.title = title
		self.icon = icon
		self.presetKey = presetKey
		self.appliesToObject = appliesToObject
		self.acceptsValue = acceptsValue
	}

	convenience init(ident: String,
	                 title: String,
	                 icon: UIImage,
	                 presetKey: String, // The value the user is being asked to set
	                 // The set of features the user is interested in (everything if empty)
	                 includeFeatures: [PresetFeature],
	                 excludeFeatures: [PresetFeature], // The set of features to exclude
	                 accepts: @escaping ((String) -> Bool)) // This is acceptance criteria for a value the user typed in
	{
		typealias Validator = (OsmBaseObject) -> Bool

		let includeFunc = Self.getMatchFunc(includeFeatures.map { $0.tags })
		let excludeFunc = Self.getMatchFunc(excludeFeatures.map { $0.tags })
		let applies: Validator = { obj in
			obj.tags[presetKey] == nil && includeFunc(obj.tags) && !excludeFunc(obj.tags)
		}
		self.init(ident: ident,
		          title: title,
		          icon: icon,
		          presetKey: presetKey,
		          appliesToObject: applies,
		          acceptsValue: accepts)
	}

	convenience
	init(ident: String,
	     title: String,
	     icon: UIImage,
	     presetKey: String, // The value the user is being asked to set
	     includeFeatures: [String], // The set of features the user is interested in (everything if empty)
	     excludeFeatures: [String], // The set of features to exclude
	     accepts: ((String) -> Bool)? = nil // This is acceptance criteria for a value the user typed in
	) throws {
		// If the user didn't define any features then infer them
		var includeFeatures = includeFeatures
		if includeFeatures.isEmpty {
			includeFeatures = try Self.featuresContaining(presetKey: presetKey)
		}

		let include = try includeFeatures.map {
			guard let feature = PresetsDatabase.shared.stdPresets[$0] else { throw QuestError.unknownFeature($0) }
			return feature
		}
		let exclude = try excludeFeatures.map {
			guard let feature = PresetsDatabase.shared.stdPresets[$0] else { throw QuestError.unknownFeature($0) }
			return feature
		}

		self.init(ident: ident,
		          title: title,
		          icon: icon,
		          presetKey: presetKey,
		          includeFeatures: include,
		          excludeFeatures: exclude,
		          accepts: accepts ?? { !$0.isEmpty })
	}

	convenience init(userQuest quest: QuestUserDefition) throws {
		try self.init(ident: quest.title,
		              title: quest.title,
		              icon: UIImage(),
		              presetKey: quest.presetKey,
		              includeFeatures: quest.includeFeatures,
		              excludeFeatures: quest.excludeFeatures)
	}

	// Compute a function that determines whether a given tag dictionary matches the feature(s) of the quest
	static func getMatchFunc(_ featureList: [[String: String]]) -> (([String: String]) -> Bool) {
		if featureList.isEmpty {
			return { _ in false }
		}

		// build a dictionary of tags that must match
		var matchDict: [String: [[String: String]]] = [:]
		for feature in featureList {
			for key in feature.keys {
				if matchDict[key]?.append(feature) == nil {
					matchDict[key] = [feature]
				}
			}
		}

		// check whether candidate object matches all tags in feature
		@inline(__always)
		func matchTagsOf(candidate: [String: String], to feature: [String: String]) -> Bool {
			// check whether candidate object matches all tags in feature
			for kv in feature {
				guard let value = candidate[kv.key],
				      value == kv.value || kv.value == "*"
				else {
					return false
				}
			}
			return true
		}

		return { candidate in
			for key in candidate.keys {
				guard let features = matchDict[key] else { continue }
				for feature in features {
					if matchTagsOf(candidate: candidate, to: feature) {
						return true
					}
				}
			}
			return false
		}
	}

	static func featuresContaining(presetKey: String) throws -> [String] {
		// find all features containing the desired field
		var featureNames = Set<String>()
		for feature in PresetsDatabase.shared.stdPresets.values {
			for fieldName in feature.fields ?? [] {
				if let field = PresetsDatabase.shared.presetFields[fieldName],
				   field.key == presetKey
				{
					featureNames.insert(feature.featureID)
					break
				}
			}
		}
		if featureNames.isEmpty {
			throw QuestError.unknownKey(presetKey)
		}
		return Array(featureNames)
	}
}

struct QuestUserDefition: Codable {
	var title: String
	var presetKey: String
	var includeFeatures: [String] // list of featureID
	var excludeFeatures: [String] // list of featureID
}
