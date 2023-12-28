//
//  ImportExtension.swift
//  ZoomNewSpotlight
//
//  Created by C.W. Betts on 10/29/22.
//

import CoreSpotlight
import ZoomPlugIns
import ZoomPlugIns.ifmetabase
import ZoomPlugIns.ZoomMetadata
import ZoomPlugIns.ZoomStory
import ZoomPlugIns.ZoomStoryID
import ZoomView
import ZoomView.ZoomBlorbFile

private let zoomConfigDirectory: URL? = {
	if #available(macOSApplicationExtension 13.0, *) {
		var zoomLib = URL.applicationSupportDirectory.appending(path: "Zoom", directoryHint: .isDirectory)
		do {
			guard try zoomLib.checkResourceIsReachable() else {
				return nil
			}
			let resVals = try zoomLib.resourceValues(forKeys: [.isDirectoryKey])
			guard resVals.isDirectory! else {
				return nil
			}
			return zoomLib
		} catch {
			return nil
		}
	} else {
	let libraryDirs = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
	for dir in libraryDirs {
		var isDir: ObjCBool = false
		let zoomLib = dir.appendingPathComponent("Zoom")
		if FileManager.default.fileExists(atPath: zoomLib.path, isDirectory: &isDir) {
			if isDir.boolValue {
				return zoomLib
			}
		}
	}
	
	return nil
	}
}()

private func loadMetadataFromBlorb(at url: URL, lookingFor identifier: ZoomStoryID) -> ZoomStory? {
	guard let blorb = try? ZoomBlorbFile(contentsOf: url),
		  let data = blorb.dataForChunk(withType: "IFmd"),
		  let meta = try? ZoomMetadata(data: data) else {
		return nil
	}
	
	return meta.findStory(identifier)
}

class ImportExtension: CSImportExtension {
    
    override func update(_ attributes: CSSearchableItemAttributeSet, forFileAt: URL) throws {
		ZoomIsSpotlightIndexing = true
		
		let story_id = try ZoomStoryID(zCodeFileAt: forFileAt)
		var story = findStory(with: story_id)
		if story == nil {
			story = loadMetadataFromBlorb(at: forFileAt, lookingFor: story_id)
		}
		guard let story else {
			throw CocoaError(.fileReadCorruptFile)
		}
		
		attributes.identifier = story_id.description
		
		//
		// title
		//
		if let title = story.title {
			attributes.title = title
		}
		
		//
		// headline
		//
		if let headline = story.headline {
			attributes.headline = headline
		}
		
		//
		// author
		//
		if let author = story.author {
			attributes.authorNames = [author]
		}
		
		//
		// genre
		//
		if let genre = story.genre, let genreKey = CSCustomAttributeKey(keyName: "public_zcode_genre") {
			attributes.setValue(genre as NSString, forCustomKey: genreKey)
		}
		
		//
		// year
		//
		let year = story.year
		if year != 0, let genreKey = CSCustomAttributeKey(keyName: "public_zcode_year") {
			attributes.setValue(year as NSNumber, forCustomKey: genreKey)
		}
		
		//
		// group
		//
		if let group = story.group, let genreKey = CSCustomAttributeKey(keyName: "public_zcode_group") {
			attributes.setValue(group as NSString, forCustomKey: genreKey)
		}

		//
		// zarf rating
		//
		do {
			let zarfString: NSString?
			switch story.zarfian {
			case .merciful:
				zarfString = "Merciful"
			case .polite:
				zarfString = "Polite"
			case .tough:
				zarfString = "Tough"
			case .nasty:
				zarfString = "Nasty"
			case .cruel:
				zarfString = "Cruel"
			case .unrated:
				fallthrough
			@unknown default:
				zarfString = nil
			}
			if let zarfString, let crueltyKey = CSCustomAttributeKey(keyName: "public_zcode_cruelty") {
				attributes.setValue(zarfString, forCustomKey: crueltyKey)
			}
		}
		
		//
		// teaser
		//
		if let teaser = story.teaser, let genreKey = CSCustomAttributeKey(keyName: "public_zcode_teaser") {
			attributes.setValue(teaser as NSString, forCustomKey: genreKey)
		}

		 
		//
		// comment
		//
		if let comment = story.comment {
			attributes.comment = comment
		}

		//
		// rating
		//
		let rating = story.rating
		if rating != -1 {
			attributes.rating = rating as NSNumber
		}
    }
}

private func findStory(with gameID: ZoomStoryID) -> ZoomStory? {
	for repository in gameIndices {
		if let story = repository.findStory(gameID) {
			return story
		}
	}
	
	return nil
}

private let gameIndices: [ZoomMetadata] = {
	var game_indices = [ZoomMetadata]()
	let userData: Data?
	if let userDir = zoomConfigDirectory?.appendingPathComponent("metadata.iFiction", isDirectory: false) {
		userData = try? Data(contentsOf: userDir)
	} else {
		userData = nil
	}
	let bundle = Bundle(for: ImportExtension.self)
	
	if let userData, let userMeta = try? ZoomMetadata(data: userData) {
		game_indices.append(userMeta)
	} else {
		game_indices.append(ZoomMetadata())
	}
	
	if let infoComURL = bundle.url(forResource: "infocom", withExtension: "iFiction"),
	   let infoCom = try? ZoomMetadata(contentsOf: infoComURL) {
		game_indices.append(infoCom)
	}
	if let archiveURL = bundle.url(forResource: "archive", withExtension: "iFiction"),
	   let archive = try? ZoomMetadata(contentsOf: archiveURL) {
		game_indices.append(archive)
	}

	return game_indices
}()
