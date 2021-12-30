//
//  ZoomStoryOrganiser.swift
//  Zoom
//
//  Created by C.W. Betts on 10/28/21.
//

import Foundation
import ZoomPlugIns
import ZoomPlugIns.ZoomStoryID
import ZoomPlugIns.ZoomPlugInManager
import ZoomPlugIns.ZoomPlugIn
import ZoomView.ZoomPreferences
import ZoomView.Swift
import ZoomView

/// The story organiser is used to store story locations and identifications
/// (mainly to build up the iFiction window).
@objcMembers class ZoomStoryOrganiser2: NSObject {
	private(set) var stories = [Object]()
	struct Object: Hashable, Codable {
		enum CodingKeys: String, CodingKey {
			case ifdbStringID = "ifdb_string_id"
			case url
			case bookmarkData = "bookmark_data"
		}

		var url: URL
		var bookmarkData: Data? = nil
		var fileID: ZoomStoryID
		
		func encode(to encoder: Encoder) throws {
			var container = encoder.container(keyedBy: CodingKeys.self)

			try container.encode(url, forKey: .url)
			try container.encode(fileID.description, forKey: .ifdbStringID)
			try container.encodeIfPresent(bookmarkData, forKey: .bookmarkData)
		}
		
		init(from decoder: Decoder) throws {
			let values = try decoder.container(keyedBy: CodingKeys.self)
			
			url = try values.decode(URL.self, forKey: .url)
			let ifmbString = try values.decode(String.self, forKey: .ifdbStringID)
			fileID = ZoomStoryID(idString: ifmbString)
			bookmarkData = try values.decodeIfPresent(Data.self, forKey: .bookmarkData)
		}
		
		init(url: URL, bookmarkData: Data? = nil, fileID: ZoomStoryID) {
			self.url = url
			self.bookmarkData = bookmarkData
			self.fileID = fileID
		}
		
		mutating func update() throws {
			guard let bookmarkData = bookmarkData else {
				return
			}
			var stale = false
			url = try URL(resolvingBookmarkData: bookmarkData, bookmarkDataIsStale: &stale)
			if stale {
				self.bookmarkData = try url.bookmarkData(options: [.securityScopeAllowOnlyReadAccess])
			}
		}
	}
	
	@objc(sharedStoryOraniser)
	static let shared: ZoomStoryOrganiser2 = {
		let toRet = ZoomStoryOrganiser2()
		try? toRet.load()
		return toRet
	}()
	
	override init() {
		super.init()
		weak var weakSelf = self
		dataChangedNotificationObject = NotificationCenter.default.addObserver(forName: .ZoomStoryDataHasChanged, object: nil, queue: nil, using: { noti in
			guard let story = noti.object as? ZoomStory else {
				NSLog("someStoryHasChanged: called with a non-story object (too many spoons?)")
				return // Unlikely but possible. If I'm a spoon, that is.
			}
			guard let strongSelf = weakSelf else {
				return
			}
			
			// De and requeue this to be done next time through the run loop
			// (stops this from being performed multiple times when many story parameters are updated together)
			RunLoop.current.cancelPerform(#selector(self.finishChanging(_:)), target: strongSelf, argument: story)
			RunLoop.current.perform(#selector(self.finishChanging(_:)), target: strongSelf, argument: story, order: 128, modes: [.default, .modalPanel])
		})
	}
	
	deinit {
		NotificationCenter.default.removeObserver(dataChangedNotificationObject!)
	}
	
	@objc private
	func finishChanging(_ story: ZoomStory) {
		
	}
	
	func load() throws {
		let dir = (NSApp.delegate as! ZoomAppDelegate).zoomConfigDirectory!
		var saveURL = URL(fileURLWithPath: dir, isDirectory: true)
		saveURL.appendPathComponent("Library.json")
		let dat = try Data(contentsOf: saveURL)
		let decoder = JSONDecoder()
		stories = try decoder.decode(Array<Object>.self, from: dat)
	}
	
	func save() throws {
		let dir = (NSApp.delegate as! ZoomAppDelegate).zoomConfigDirectory!
		var saveURL = URL(fileURLWithPath: dir, isDirectory: true)
		saveURL.appendPathComponent("Library.json")
		let encoder = JSONEncoder()
		let dat = try encoder.encode(stories)
		try dat.write(to: saveURL)
	}
	
	private var storyLock = NSLock()
	private var dataChangedNotificationObject: NSObjectProtocol? = nil
	
	func updateFromOldDefaults() {
		guard let oldDict = UserDefaults.standard.dictionary(forKey: "ZoomStoryOrganiser") as? [String: Data] else {
			return
		}
		
		let unarchiveDict = oldDict.compactMapValues { dat -> ZoomStoryID? in
			var storyId: ZoomStoryID? = nil
			do {
				storyId = try NSKeyedUnarchiver.unarchivedObject(ofClass: ZoomStoryID.self, from: dat)
			} catch { }
			if storyId == nil {
				if let newID = NSUnarchiver.unarchiveObject(with: dat) as? ZoomStoryID {
					return newID
				}
			}
			
			return storyId
		}
		
		for (path, storyID) in unarchiveDict {
			let pathurl = URL(fileURLWithPath: path)
			try? addStory(at: pathurl, withIdentity: storyID)
		}
//		UserDefaults.standard.removeObject(forKey: "ZoomStoryOrganiser")
		try? save()
	}
	
	@objc(addStoryAtURL:withIdentity:organise:error:)
	func addStory(at filename: URL, withIdentity ident: ZoomStoryID, organise: Bool = false) throws {
		guard try filename.checkResourceIsReachable() else {
			throw CocoaError(.fileNoSuchFile, userInfo: [NSURLErrorKey: filename])
		}
		
		let newIdentifier = try filename.resourceValues(forKeys: [.fileResourceIdentifierKey]).fileResourceIdentifier!
		// check for duplicates
		let dupURLIdx = stories.firstIndex(where: { obj in
			guard let identifier = try? obj.url.resourceValues(forKeys: [.fileResourceIdentifierKey]).fileResourceIdentifier else {
				return false
			}
			return identifier.isEqual(newIdentifier)
		})
		let dupIDIdx = stories.firstIndex { obj in
			return obj.fileID == ident
		}
		let oldURL: URL? = {
			if let dupIdx = dupIDIdx {
				return stories[dupIdx].url
			}
			return nil
		}()
		let oldURLID: (NSCopying & NSSecureCoding & NSObjectProtocol)? = {
			if let oldURL = oldURL, let resVals = try? oldURL.resourceValues(forKeys: [.fileResourceIdentifierKey]), let theID = resVals.fileResourceIdentifier {
				return theID
			}
			return nil
		}()
		let oldIdent: ZoomStoryID? = {
			if let dupIdx = dupURLIdx {
				return stories[dupIdx].fileID
			}
			return nil
		}()
		
		// Get the story from the metadata database
		var theStory = (NSApp.delegate as! ZoomAppDelegate).findStory(ident)
		// If there's no story registered, then we need to create one
		if theStory == nil {
			let pluginClass = ZoomPlugInManager.shared.plugIn(for: filename) as? ZoomPlugIn.Type
			let pluginInstance = pluginClass?.init(url: filename)
			
			if let pluginInstance = pluginInstance {
				theStory = try pluginInstance.defaultMetadata()
			} else {
				theStory = try ZoomStory.defaultMetadata(for: filename)
			}
			(NSApp.delegate as! ZoomAppDelegate).userMetadata().copyStory(theStory!)
			if theStory!.title == nil {
				theStory!.title = filename.deletingPathExtension().lastPathComponent
			}
			try? (NSApp.delegate as! ZoomAppDelegate).userMetadata().writeToDefaultFile()
		}
		
		if let oldURLID = oldURLID, let oldIdent = oldIdent, oldIdent == ident, oldURLID.isEqual(newIdentifier) {
			// Nothing to do
			if organise {
				organiseStory(theStory!, with: ident)
			}
			return
		}
		
		var toRemove = IndexSet()
		if let dupIDIdx = dupIDIdx {
			toRemove.insert(dupIDIdx)
		}
		if let dupURLIdx = dupURLIdx {
			toRemove.insert(dupURLIdx)
		}
		
		if !toRemove.isEmpty {
			stories.remove(indexes: toRemove)
		}
		
		var bookData: Data? = nil
		do {
			bookData = try filename.bookmarkData(options: [.securityScopeAllowOnlyReadAccess])
		} catch { }

		stories.append(Object(url: filename, bookmarkData: bookData, fileID: ident))
		
		if organise {
			organiseStory(theStory!, with: ident)
		}
		
	}
	
	@objc(URLForIdent:)
	func urlFor(_ ident: ZoomStoryID) -> URL? {
		storyLock.lock()
		defer {
			storyLock.unlock()
		}
		return stories.first(where: {$0.fileID == ident})?.url
	}
	
	@available(*, deprecated, message: "Use urlFor(_:) or -URLForIdent: instead")
	@objc(filenameForIdent:)
	func filename(for ident: ZoomStoryID) -> String? {
		return urlFor(ident)?.path
	}
	
	func organiseStory(_ story: ZoomStory) {
		var organized = false
		
		if let ids = story.storyIDs {
			for thisID in ids {
				let filename = urlFor(thisID)
				
				if filename != nil {
					organiseStory(story, with: thisID)
					organized = true
				}
			}
		}
		
		if !organized {
			NSLog("WARNING: attempted to organise story with no IDs")
		}
	}
	
	@objc(organiseStory:withIdent:)
	func organiseStory(_ story: ZoomStory, with ident: ZoomStoryID) {
		
	}

	var storyIdents: [ZoomStoryID] {
		return stories.map({$0.fileID})
	}
}

extension ZoomStoryOrganiser {
	@objc(frontispieceForBlorb:)
	static func frontispiece(for decodedFile: ZoomBlorbFile) -> NSImage? {
		var coverPictureNumber: Int32 = -1
		
		// Try to retrieve the frontispiece tag (overrides metadata if present)
		guard let front = decodedFile.dataForChunk(withType: "Fspc"), front.count >= 4 else {
			return nil
		}
		do {
			let fpc = front[0 ..< 4]

			let val = UInt32(fpc[0]) << 24 | UInt32(fpc[1]) << 16 | UInt32(fpc[2]) << 8 | UInt32(fpc[3])
			coverPictureNumber = Int32(bitPattern: val)
		}
		
		if coverPictureNumber >= 0 {
			// Attempt to retrieve the cover picture image
			guard let coverPictureData = decodedFile.imageData(withNumber: coverPictureNumber),
				  let coverPicture = NSImage(data: coverPictureData) else {
					  return nil
				  }
			
			// Sometimes the image size and pixel size do not match up
			let coverRep = coverPicture.representations.first!
			let pixSize = NSSize(width: coverRep.pixelsWide, height: coverRep.pixelsHigh)
			
			if pixSize != .zero, // just in case it's a vector format. Not likely, but still possible.
			   pixSize != coverPicture.size {
				coverPicture.size = pixSize
			}
			
			return coverPicture
		}
		
		return nil
	}

	@available(*, deprecated, message: "Use +frontispieceForURL: or frontispiece(for:) instead")
	@objc(frontispieceForFile:)
	static func frontispiece(forFile filename: String) -> NSImage? {
		return frontispiece(for: URL(fileURLWithPath: filename))
	}

	@objc(frontispieceForURL:)
	static func frontispiece(for filename: URL) -> NSImage? {
		// First see if a plugin can provide the image...
		if let plugin = ZoomPlugInManager.shared.instance(for: filename),
			let res = plugin.coverImage {
			return res
		}
		
		// Then try using the standard blorb decoder
		if let decodedFile = try? ZoomBlorbFile(contentsOf: filename) {
			return frontispiece(for: decodedFile)
		}
		
		return nil
	 }
}


extension Array {
	// Code taken from https://stackoverflow.com/a/50835467/1975001
	/// Removes objects at indexes that are in the specified `IndexSet`.
	/// - parameter indexes: the index set containing the indexes of objects that will be removed
	@inlinable mutating func remove(indexes: IndexSet) {
		guard var i = indexes.first, i < count else {
			return
		}
		var j = index(after: i)
		var k = indexes.integerGreaterThan(i) ?? endIndex
		while j != endIndex {
			if k != j {
				swapAt(i, j)
				formIndex(after: &i)
			} else {
				k = indexes.integerGreaterThan(k) ?? endIndex
			}
			formIndex(after: &j)
		}
		removeSubrange(i...)
	}
}
