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
import ZoomPlugIns.Swift
import ZoomView.ZoomPreferences
import ZoomView.Swift
import ZoomView

private let ZoomIdentityFilename = ".zoomIdentity"


/// The story organiser is used to store story locations and identifications
/// (mainly to build up the iFiction window).
@objcMembers class ZoomStoryOrganiser2: NSObject {
	private(set) var stories = [Object]()
	private var gameDirectories = [String: URL]()
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
			do {
				try update()
			} catch { }
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
	
	struct SaveWrapper: Codable {
		var stories: [Object]
		var gameDirectories: [String: URL]
		enum CodingKeys: String, CodingKey {
			case stories
			case gameDirectories = "game_directories"
		}
	}
	
	/// The shared organiser
	@objc(sharedStoryOraniser)
	static let shared: ZoomStoryOrganiser2 = {
		let toRet = ZoomStoryOrganiser2()
		try? toRet.load()
		return toRet
	}()
	
	override init() {
		super.init()
		dataChangedNotificationObject = NotificationCenter.default.addObserver(forName: .ZoomStoryDataHasChanged, object: nil, queue: nil, using: { [weak self] noti in
			guard let story = noti.object as? ZoomStory else {
				NSLog("someStoryHasChanged: called with a non-story object (too many spoons?)")
				return // Unlikely but possible. If I'm a spoon, that is.
			}
			guard let strongSelf = self else {
				return
			}
			
			// De and requeue this to be done next time through the run loop
			// (stops this from being performed multiple times when many story parameters are updated together)
			RunLoop.current.cancelPerform(#selector(ZoomStoryOrganiser2.finishChanging(_:)), target: strongSelf, argument: story)
			RunLoop.current.perform(#selector(ZoomStoryOrganiser2.finishChanging(_:)), target: strongSelf, argument: story, order: 128, modes: [.default, .modalPanel])
		})
	}
	
	deinit {
		NotificationCenter.default.removeObserver(dataChangedNotificationObject!)
	}
	
	//MARK: - Progress

	private func startedActing() {
		NotificationCenter.default.post(name: ZoomStoryOrganiser.progressNotification, object: self, userInfo: ["ActionStarting": true])
	}
	
	private func endedActing() {
		NotificationCenter.default.post(name: ZoomStoryOrganiser.progressNotification, object: self, userInfo: ["ActionStarting": false])
	}

	//MARK: -
	
	func organiserChanged() {
		try? save()
		
		NotificationCenter.default.post(name: ZoomStoryOrganiser.changedNotification, object: self)
	}
	
	func load() throws {
		let dir = (NSApp.delegate as! ZoomAppDelegate).zoomConfigDirectory!
		var saveURL = URL(fileURLWithPath: dir, isDirectory: true)
		saveURL.appendPathComponent("Library.json")
		let dat = try Data(contentsOf: saveURL)
		let decoder = JSONDecoder()
		let wrapper = try decoder.decode(SaveWrapper.self, from: dat)
		stories = wrapper.stories
		gameDirectories = wrapper.gameDirectories
	}
	
	func save() throws {
		let dir = (NSApp.delegate as! ZoomAppDelegate).zoomConfigDirectory!
		var saveURL = URL(fileURLWithPath: dir, isDirectory: true)
		saveURL.appendPathComponent("Library.json")
		let encoder = JSONEncoder()
		let wrapper = SaveWrapper(stories: stories, gameDirectories: gameDirectories)
		let dat = try encoder.encode(wrapper)
		try dat.write(to: saveURL)
	}
	
	private var storyLock = NSLock()
	private var dataChangedNotificationObject: NSObjectProtocol? = nil
	
	func updateFromOldDefaults() {
		guard let oldDict = UserDefaults.standard.dictionary(forKey: "ZoomStoryOrganiser") as? [String: Data] else {
			return
		}
		startedActing()
		defer {
			endedActing()
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
		if let oldDict2 = UserDefaults.standard.dictionary(forKey: "ZoomGameDirectories") as? [String: String] {
			let mappedDict = oldDict2.mapValues { val in
				return URL(fileURLWithPath: val, isDirectory: true)
			}
			gameDirectories = mappedDict
		}
		
//		UserDefaults.standard.removeObject(forKey: "ZoomStoryOrganiser")
//		UserDefaults.standard.removeObject(forKey: "ZoomGameDirectories")
		try? save()
	}
	
	// MARK: - Storing stories
	
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
#if DEVELOPMENT_BUILD
		NSLog("Adding %@ (IFID %@)", filename.path, ident);
		if let oldFilename = oldURL {
			NSLog("... previously %@ (%@)", oldFilename, oldIdent);
		}
#endif
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
		
		organiserChanged()
	}
	
	@objc(removeStoryWithIdent:deleteFromMetadata:)
	func removeStory(with ident: ZoomStoryID, deleteFromMetadata delete: Bool) {
		storyLock.lock()
		
		let idx = stories.firstIndex { obj in
			return obj.fileID == ident
		}
		if let idx = idx {
			stories.remove(at: idx)
		}
		
		if delete {
			let usrMeta = (NSApp.delegate as! ZoomAppDelegate).userMetadata()
			usrMeta.removeStory(withIdent: ident)
			try? usrMeta.writeToDefaultFile()
		}
		
		storyLock.unlock()
		organiserChanged()
	}
	
	// MARK: - Story-specific data
	
	/// Gets rid of certain illegal characters from the name, returning a valid directory name
	/// (Most illegal characters are replaced by `'?'`, but `'/'` is replaced by `':'` - look in the Finder
	/// to see why)
	///
	/// Techincally, only `'/'` and `NUL` are invalid characters under UNIX. We invalidate a few more so as to
	/// avoid the possibility of slightly dumb-looking filenames.
	private func sanitiseDirectoryName(_ name: String?) -> String? {
		guard let name = name else {
			return nil
		}

		let mappedChars = name.map { aChar -> Character in
			switch aChar {
			case "/": // Makes some twisted kind of sense
				return ":"
			case ":":
				return "?"
			case "\0" ..< " ":
				return "?"
			default:
				return aChar
			}
		}
		return String(mappedChars)
	}
	
	/// The preferred directory is defined by the story group and title
	/// (Ungrouped/untitled if there is no story group/title)
	private func preferredDirectory(for ident: ZoomStoryID) -> URL? {
		let confDir = ZoomPreferences.global.organiserDirectory!
		var confURL: URL = URL(fileURLWithPath: confDir, isDirectory: true)
		let theStory = (NSApp.delegate as! ZoomAppDelegate).findStory(ident)
		
		confURL.appendPathComponent(sanitiseDirectoryName(theStory?.group) ?? "Ungrouped", isDirectory: true)
		confURL.appendPathComponent(sanitiseDirectoryName(theStory?.title) ?? "Untitled", isDirectory: true)

		return confURL
	}
	
	/// If the preferences get corrupted or something similarily silly happens,
	/// we want to avoid having games point to the wrong directories. This
	/// routine checks that a directory belongs to a particular game.
	func directory(_ dir: URL, isFor ident: ZoomStoryID) -> Bool {
		var isDir: ObjCBool = false
		guard urlIsAvailable(dir, isDirectory: &isDir, isPackage: nil, isReadable: nil, error: nil) else {
			// Corner case
			return true
		}
		
		guard isDir.boolValue else {
			// Files belong to no game
			return false
		}
		
		let idFile = dir.appendingPathComponent(ZoomIdentityFilename)
		guard urlIsAvailable(idFile, isDirectory: &isDir, isPackage: nil, isReadable: nil, error: nil) else {
			// Directory has no identification
			return false
		}
		
		guard !isDir.boolValue else {
			// Identification must be a file
			return false
		}
		
		guard let fileData = try? Data(contentsOf: idFile) else {
			// we need data, of course
			return false
		}
		var owner: Any? = try? NSKeyedUnarchiver.unarchivedObject(ofClass: ZoomStoryID.self, from: fileData)
		if owner == nil {
			owner = NSUnarchiver.unarchiveObject(with: fileData)
		}
		
		if let owner = owner as? ZoomStoryID, owner == ident {
			return true
		}
		
		// Directory belongs to some other game
		return false
	}
	
	/// Assuming a story doesn't already have a directory, find (and possibly create)
	/// a directory for it.
	private func findDirectory(for ident: ZoomStoryID, createGameDir createGame: Bool, createGroupDir createGroup: Bool) -> URL? {
		var isDir: ObjCBool = false
		
		let theStory = (NSApp.delegate as! ZoomAppDelegate).findStory(ident)
		var group = sanitiseDirectoryName(theStory?.group)
		var title = sanitiseDirectoryName(theStory?.title)
		
		if group == nil || group == "" {
			group = "Ungrouped"
		}
		if title == nil || title == "" {
			group = "Untitled"
		}

		let rootDir = ZoomPreferences.global.organiserDirectory!
		let rootURL: URL = URL(fileURLWithPath: rootDir)

		return nil
	}

	
	@objc(directoryForIdent:create:)
	func directory(for ident: ZoomStoryID, create: Bool) -> URL? {
		var confDir: URL? = nil
		
		// If there is a directory in the preferences, then that's the directory to use
		confDir = gameDirectories[ident.description]
		
		var isDir: ObjCBool = false
		if let confDir2 = confDir, !urlIsAvailable(confDir2, isDirectory: &isDir, isPackage: nil, isReadable: nil, error: nil) {
			confDir = nil
		}
		
		if !isDir.boolValue {
			confDir = nil
		}
		
		if let confDir = confDir, directory(confDir, isFor: ident) {
			return confDir
		}
		
		confDir = nil

		guard let gameDir = findDirectory(for: ident, createGameDir: create, createGroupDir: create) else {
			return nil
		}
		
		// Store this directory as the dir for this game
		gameDirectories[ident.description] = gameDir
		try? save()
		
		return gameDir
	}
	
	func moveStoryToPreferredDirectory(with ident: ZoomStoryID) -> Bool {
		guard let currentDir = directory(for: ident, create: false)?.standardizedFileURL else {
			return false
		}
		
#if DEVELOPMENT_BUILD
		NSLog("Moving %@ to its preferred path (currently at %@)", ident, currentDir);
#endif

		// Get the 'ideal' directory
		let idealDir = findDirectory(for: ident, createGameDir: false, createGroupDir: true)?.standardizedFileURL

		// See if they already match
		if idealDir == currentDir {
			return true;
		}
		
#if DEVELOPMENT_BUILD
		NSLog("Ideal location is %@", idealDir);
#endif

		
		// If they don't match, then idealDir should be new (or something weird has just occured)
		// Hmph. HFS+ is case-insensitve, and stringByStandardizingPath does not take account of this. This could
		// cause some major problems with organiseStory:withIdent:, as that deletes/copies files...
		// We're dealing with this by calling lowercaseString, but there's no guarantee that this matches the algorithm
		// used for comparing filenames internally to HFS+.
		//
		// Don't even think about UFS or HFSX. There's no way to tell which we're using
		if ((try? idealDir?.checkResourceIsReachable() ?? false) != nil) {
			// Doh!
			NSLog("Wanted to move game from '%@' to '%@', but '%@' already exists", currentDir.path, idealDir?.path ?? "Nil", idealDir?.path ?? "Nil");
			return false
		}
		
		// Move the old directory to the new directory
		
		// Vague possibilities of this failing: in particular, currentDir may be not write-accessible or
		// something might appear there between our check and actually moving the directory
		do {
			try FileManager.default.moveItem(at: currentDir, to: idealDir!)
		} catch {
			NSLog("Failed to move '%@' to '%@'", currentDir.path, idealDir!.path)
			return false
		}
		
		// Success: store the new directory in the defaults
		if ident != nil && ident.description != nil {
			gameDirectories[ident.description] = idealDir
			try? save()
		}
		
		return true
	}
	
	@objc private
	func finishChanging(_ story: ZoomStory) {
		// For our pre-arranged stories, several IDs are possible, but more usually one
		guard let storyIDs = story.storyIDs else {
			return
		}
		var changed = false
		
#if DEVELOPMENT_BUILD
		NSLog("Finishing changing %@", story.title ?? "(nil)");
#endif

		for ident in storyIDs {
			guard let identID = stories.firstIndex(where: { obj in
				return obj.fileID == ident
			}) else {
				continue
			}
			// Get the old location of the game
			let realID = stories[identID].fileID
			var oldGameFile = directory(for: ident, create: false)
			let oldGameLoc = stories[identID].url.standardizedFileURL
			oldGameFile?.appendPathComponent(oldGameLoc.lastPathComponent)
			
#if DEVELOPMENT_BUILD
			NSLog("ID %@ (%@) is located at %@ (%@)", ident, realID, oldGameFile, oldGameLoc);
#endif

			
			// Actually perform the move
			if moveStoryToPreferredDirectory(with: stories[identID].fileID) {
				changed = true
			}
		}
		
		if changed {
			organiserChanged()
		}
	}

	// MARK: - Retrieving story information
	
	var storyIdents: [ZoomStoryID] {
		return stories.map({$0.fileID})
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
	
	// MARK: - Reorganising stories
	
	@objc(organiseStory:)
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
		guard var filename = urlFor(ident) else {
			NSLog("WARNING: Attempted to organise a story with no filename");
			return
		}
		
#if DEVELOPMENT_BUILD
		NSLog("Organising %@ (%@)", story.title, ident);
#endif
		
		storyLock.lock()
		defer {
			storyLock.unlock()
		}
		
		let oldFilename = filename

#if DEVELOPMENT_BUILD
	NSLog("... currently at %@", oldFilename);
#endif

		// Copy to a standard directory, change the filename we're using
		filename = filename.standardizedFileURL
			
		let fileDir = directory(for: ident, create: true)
		var destFile = fileDir?.appendingPathComponent(oldFilename.lastPathComponent)
		destFile = destFile?.standardizedFileURL
		
	#if DEVELOPMENT_BUILD
		NSLog("... best directory %@ (file will be %@)", fileDir, destFile);
	#endif

	
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
