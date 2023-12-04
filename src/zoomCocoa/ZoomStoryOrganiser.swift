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
import ZoomView
import ZoomView.ZoomPreferences
import ZoomView.Swift

private let ZoomIdentityFilename = ".zoomIdentity"


/// The story organiser is used to store story locations and identifications
/// (mainly to build up the iFiction window).
@objcMembers class ZoomStoryOrganiser: NSObject {
	// TODO: migrate to CoreData/Swift Data

	@nonobjc @inlinable public class var changedNotification: NSNotification.Name {
		return .__ZoomStoryOrganiserChanged
	}

	@nonobjc @inlinable public class var progressNotification: NSNotification.Name {
		return .__ZoomStoryOrganiserProgress
	}
	
	@MainActor private(set) var stories = [Object]()
	@MainActor private var gameDirectories = [String: URL]()
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
			try? update()
		}
		
		init(url: URL, bookmarkData: Data? = nil, fileID: ZoomStoryID) {
			self.url = url
			self.bookmarkData = bookmarkData
			self.fileID = fileID
		}
		
		mutating func update() throws {
			guard let bookmarkData else {
				if let newData = try? url.bookmarkData(options: [.securityScopeAllowOnlyReadAccess]) {
					self.bookmarkData = newData
				}
				return
			}
			var stale = false
			url = try URL(resolvingBookmarkData: bookmarkData, options: [.withoutUI, .withSecurityScope], bookmarkDataIsStale: &stale)
			if stale {
				self.bookmarkData = try url.bookmarkData(options: [.securityScopeAllowOnlyReadAccess])
			}
		}
	}
	
	private struct SaveWrapper: Codable {
		var stories: [Object]
		var gameDirectories: [String: URL]
		enum CodingKeys: String, CodingKey {
			case stories
			case gameDirectories = "game_directories"
		}
	}
	
	/// The shared organiser
	@objc(sharedStoryOrganiser)
	@MainActor static let shared: ZoomStoryOrganiser = {
		let toRet = ZoomStoryOrganiser()
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
			RunLoop.current.cancelPerform(#selector(ZoomStoryOrganiser.finishChanging(_:)), target: strongSelf, argument: story)
			RunLoop.current.perform(#selector(ZoomStoryOrganiser.finishChanging(_:)), target: strongSelf, argument: story, order: 128, modes: [.default, .modalPanel])
		})
		checkTimer = Timer(timeInterval: 10, target: self, selector: #selector(self.checkOrganizerChanged(_:)), userInfo: nil, repeats: true)
		checkTimer.tolerance = 5
		RunLoop.main.add(checkTimer, forMode: .default)
	}
	
	@MainActor @objc private func checkOrganizerChanged(_ timer: Timer) {
		if organizerChanged && !alreadyOrganising {
			organiserChanged()
		}
	}
	
	deinit {
		checkTimer.invalidate()
		NotificationCenter.default.removeObserver(dataChangedNotificationObject!)
	}
	
	//MARK: - Progress

	@MainActor private func startedActing() {
		NotificationCenter.default.post(name: ZoomStoryOrganiser.progressNotification, object: self, userInfo: ["ActionStarting": true])
	}
	
	@MainActor private func endedActing() {
		NotificationCenter.default.post(name: ZoomStoryOrganiser.progressNotification, object: self, userInfo: ["ActionStarting": false])
	}

	//MARK: -
	
	@MainActor private func organiserChanged() {
		try? save()
		
		NotificationCenter.default.post(name: ZoomStoryOrganiser.changedNotification, object: self)
		organizerChanged = false
	}
	
	private static let libraryPath: URL = {
		var saveURL = (NSApp.delegate as! ZoomAppDelegate).zoomConfigDirectoryURL!
		saveURL.appendPathComponent("Library.json", isDirectory: false)
		return saveURL
	}()
	
	@MainActor func load() throws {
		let dat = try Data(contentsOf: ZoomStoryOrganiser.libraryPath)
		let decoder = JSONDecoder()
		let wrapper = try decoder.decode(SaveWrapper.self, from: dat)
		gameDirectories = wrapper.gameDirectories
		stories = wrapper.stories.filter { story in
			do {
				return try story.url.checkResourceIsReachable()
			} catch {
				return false
			}
		}
		organizerChanged = false
	}
	
	@MainActor func save() throws {
		let encoder = JSONEncoder()
		let wrapper = SaveWrapper(stories: stories, gameDirectories: gameDirectories)
		let dat = try encoder.encode(wrapper)
		try dat.write(to: ZoomStoryOrganiser.libraryPath)
	}
	
	private let storyLock: NSLock = {
		let toRet = NSLock()
		toRet.name = "Zoom Story Lock"
		return toRet
	}()
	private var dataChangedNotificationObject: NSObjectProtocol? = nil
	private var alreadyOrganising = false
	private var organizerChanged = false
	private var checkTimer: Timer! = nil
	
	@MainActor func setOrganiserChanged() {
		organizerChanged = true
	}
	
	@MainActor func updateFromOldDefaults() {
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
			try? addStory(at: pathurl, with: storyID, skipSave: true)
		}
		if let oldDict2 = UserDefaults.standard.dictionary(forKey: "ZoomGameDirectories") as? [String: String] {
			let mappedDict = oldDict2.mapValues { val in
				return URL(fileURLWithPath: val, isDirectory: true)
			}
			gameDirectories = mappedDict
		}
		
		UserDefaults.standard.removeObject(forKey: "ZoomStoryOrganiser")
		UserDefaults.standard.removeObject(forKey: "ZoomGameDirectories")
		setOrganiserChanged()
	}
	
	// MARK: - Storing stories
	
	@objc(addStoryAtURL:withIdentity:organise:error:)
	@MainActor func addStory(at filename: URL, with ident: ZoomStoryID, organise: Bool = false) throws {
		try addStory(at: filename, with: ident, organise: organise, skipSave: false)
	}
	
	@MainActor private func addStory(at filename: URL, with ident: ZoomStoryID, organise: Bool = false, skipSave: Bool) throws {
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
			guard let oldURL = oldURL,
			   let resVals = try? oldURL.resourceValues(forKeys: [.fileResourceIdentifierKey]),
			   let theID = resVals.fileResourceIdentifier else {
				return nil
			}
			return theID
		}()
		let oldIdent: ZoomStoryID? = {
			if let dupURLIdx {
				return stories[dupURLIdx].fileID
			}
			return nil
		}()
		
		// Get the story from the metadata database
		var theStory = (NSApp.delegate as! ZoomAppDelegate).findStory(ident)
#if DEVELOPMENT_BUILD
		NSLog("Adding %@ (IFID %@)", filename.path, ident)
		if let oldFilename = oldURL {
			NSLog("... previously %@ (%@)", oldFilename.path, oldIdent?.description ?? "(nil)")
		}
#endif
		// If there's no story registered, then we need to create one
		if theStory == nil {
			let pluginClass = ZoomPlugInManager.shared.plugIn(for: filename)
			let pluginInstance = pluginClass?.init(url: filename)
			
			if let pluginInstance {
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
		
		if let oldURLID,
		   let oldIdent,
		   oldIdent == ident,
		   oldURLID.isEqual(newIdentifier) {
			// Nothing to do
			if organise {
				organiseStory(theStory!, with: ident)
			}
			return
		}
		
		var toRemove = IndexSet()
		if let dupIDIdx {
			toRemove.insert(dupIDIdx)
		}
		if let dupURLIdx {
			toRemove.insert(dupURLIdx)
		}
		
		if !toRemove.isEmpty {
			stories.remove(indexes: toRemove)
		}
		
		let bookData = try? filename.bookmarkData(options: [.securityScopeAllowOnlyReadAccess])

		stories.append(Object(url: filename, bookmarkData: bookData, fileID: ident))
		
		if organise {
			organiseStory(theStory!, with: ident)
		}
		
		if !skipSave {
			setOrganiserChanged()
		}
	}
	
	@objc(removeStoryWithIdent:deleteFromMetadata:)
	@MainActor func removeStory(with ident: ZoomStoryID, deleteFromMetadata delete: Bool) {
		storyLock.withLock {
			let idx = stories.firstIndex { obj in
				return obj.fileID == ident
			}
			if let idx {
				stories.remove(at: idx)
			}
			
			if delete {
				let usrMeta = (NSApp.delegate as! ZoomAppDelegate).userMetadata()
				usrMeta.removeStory(withIdent: ident)
				try? usrMeta.writeToDefaultFile()
			}
		}
		
		setOrganiserChanged()
	}
	
	@MainActor private func id(for filename: URL) -> ZoomStoryID? {
		ZoomIsSpotlightIndexing = false
		guard (try? filename.checkResourceIsReachable()) ?? false else {
			return nil
		}
		return ZoomStoryID(for: filename)
	}
	
	private func preferenceThread() async {
		await startedActing()
		
		// If story organisation is on, we need to check for any disappeared stories that have appeared in
		// the organiser directory, and recreate any story data as required.
		//
		// REMEMBER: this is not the main thread! Don't make bad things happen!
		if await MainActor.run(body: { () -> Bool in
			return ZoomPreferences.global.keepGamesOrganised
		}) {
			// Directory scanning time.
			let gameStorageDirectory = await MainActor.run { () -> URL in
				let org = ZoomPreferences.global.organiserDirectory!
				return URL(fileURLWithPath: org, isDirectory: true)
			}
			if let orgDir = try? FileManager.default.contentsOfDirectory(at: gameStorageDirectory, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsSubdirectoryDescendants, .skipsHiddenFiles]) {
				for newDir in orgDir {
					// Must be a directory
					guard (try? newDir.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false else {
						continue
					}
					
					// Iterate through the files in this directory
					if let groupD = try? FileManager.default.contentsOfDirectory(at: newDir, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsSubdirectoryDescendants, .skipsHiddenFiles]) {
						for newDir2 in groupD {
							var gameFile: URL? = nil
							// Must be a directory
							guard (try? newDir2.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false else {
								continue
							}
							var gameFileID: ZoomStoryID? = nil
							if let gameD = try? FileManager.default.contentsOfDirectory(at: newDir2, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsSubdirectoryDescendants, .skipsHiddenFiles]) {
								for newDir3 in gameD {
									gameFileID = await id(for: newDir3)

									if gameFileID != nil {
										gameFile = newDir3
										break
									}
								}
								
								guard let gameFile = gameFile else {
									continue
								}
								let urlData = try? gameFile.resourceValues(forKeys: [.fileResourceIdentifierKey]).fileResourceIdentifier
								
								// See if it's already in our database
								let story = await stories.first { obj in
									guard let localUrlData = try? gameFile.resourceValues(forKeys: [.fileResourceIdentifierKey]).fileResourceIdentifier else {
										return false
									}
									return localUrlData.isEqual(urlData)
								}
								let fileID = story?.fileID
								
								if fileID == nil {
									try? await foundFileNotInDatabase(groupName: newDir.lastPathComponent, gameName: newDir2.lastPathComponent, gameFile: gameFile)
								}
							}
						}
					}
				}
			}
		}
		
		await setOrganiserChanged()
		// Tidy up
		await endedActing()
	}
	
	/// Called from the `preferenceThread()` (to the main thread) when a story not in the database is found
	@MainActor private func foundFileNotInDatabase(groupName: String, gameName: String, gameFile: URL) throws {
		ZoomIsSpotlightIndexing = false
		
		guard let newID = ZoomStoryID(for: gameFile) else {
			NSLog("Found unindexed game at %@, but failed to obtain an ID. Not indexing", gameFile.path)
			return
		}
		
		var otherFile = false
		storyLock.withLock {
			if let identFile = stories.first(where: {$0.fileID == newID}) {
				otherFile = true
				
				NSLog("Story %@ appears to be a duplicate of %@", gameFile.path, identFile.url.path)
			} else {
				otherFile = false
				
				NSLog("Story %@ not in database (will add)", gameFile.path)
			}
		}
		let data = (NSApp.delegate as! ZoomAppDelegate).userMetadata()
		var oldStory = (NSApp.delegate as! ZoomAppDelegate).findStory(newID)
		if oldStory == nil {
			NSLog("Creating metadata entry for story '%@'", gameName)
			
			let newStory = try ZoomStory.defaultMetadata(for: gameFile)
			
			data.copyStory(newStory)
			try? data.writeToDefaultFile()
			oldStory = newStory
		} else {
			NSLog("Found metadata for story '%@'", gameName)
		}
		
		guard let oldStory = oldStory else {
			return
		}
		
		// Check for any resources associated with this story
		if oldStory.object(forKey: "ResourceFilename") == nil {
			var possibleResource = gameFile.deletingLastPathComponent().appendingPathComponent("resource.blb")
			var isDir: ObjCBool = false
			var exists = urlIsAvailable(possibleResource, isDirectory: &isDir, isPackage: nil, isReadable: nil, error: nil)
			if exists && !isDir.boolValue {
				NSLog("Found resources for game at %@", possibleResource.path)
				
				oldStory.setObject(possibleResource.path, forKey: "ResourceFilename")
				
				data.copyStory(oldStory)
				try? data.writeToDefaultFile()
			} else {
				possibleResource = gameFile.deletingLastPathComponent().appendingPathComponent(gameFile.deletingPathExtension().lastPathComponent).appendingPathExtension("blb")
				isDir = false
				exists = urlIsAvailable(possibleResource, isDirectory: &isDir, isPackage: nil, isReadable: nil, error: nil)
				
				if (exists && !isDir.boolValue) {
					NSLog("Found resources for game at %@", possibleResource.path)
					
					oldStory.setObject(possibleResource.path, forKey: "ResourceFilename")
					
					data.copyStory(oldStory)
					try? data.writeToDefaultFile()
				}
			}
		}
		
		// Now store with us
		try addStory(at: gameFile, with: newID)
	}
	
	// MARK: - Story-specific data
	
	/// Gets rid of certain illegal characters from the name, returning a valid directory name
	/// (Most illegal characters are replaced by `'?'`, but `'/'` is replaced by `':'` - look in the Finder
	/// to see why)
	///
	/// Techincally, only `'/'` and `NUL` are invalid characters under UNIX. We invalidate a few more so as to
	/// avoid the possibility of slightly dumb-looking filenames.
	private func sanitiseDirectoryName(_ name: String?) -> String? {
		guard let name else {
			return nil
		}

		let mappedChars = name.map { aChar -> Character in
			switch aChar {
			case "/": // Makes some twisted kind of sense
				return ":"
			case ":":
				return "_"
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
	@MainActor private func preferredDirectory(for ident: ZoomStoryID) -> URL? {
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
	@objc(directory:isForIdent:)
	@MainActor func directory(_ dir: URL, isFor ident: ZoomStoryID) -> Bool {
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
	@MainActor private func findDirectory(for ident: ZoomStoryID, createGameDir createGame: Bool, createGroupDir createGroup: Bool) -> URL? {
		var isDir: ObjCBool = false
		
		let theStory = (NSApp.delegate as! ZoomAppDelegate).findStory(ident)
		var group: String? = sanitiseDirectoryName(theStory?.group)
		var title: String? = sanitiseDirectoryName(theStory?.title)
		
		if group == nil || group == "" {
			group = "Ungrouped"
		}
		if title == nil || title == "" {
			title = "Untitled"
		}

		let rootDir: String = ZoomPreferences.global.organiserDirectory!
		let rootURL = URL(fileURLWithPath: rootDir, isDirectory: true)
		
		if !urlIsAvailable(rootURL, isDirectory: &isDir, isPackage: nil, isReadable: nil, error: nil) {
			if createGroup {
				try? FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true, attributes: nil)
				isDir = true
			} else {
				return nil
			}
		}
		
		guard isDir.boolValue else {
			return nil
		}
		// Find the group directory
		let groupDir = rootURL.appendingPathComponent(group!)
		
		if !urlIsAvailable(groupDir, isDirectory: &isDir, isPackage: nil, isReadable: nil, error: nil) {
			if createGroup {
				try? FileManager.default.createDirectory(at: groupDir, withIntermediateDirectories: false, attributes: nil)
				isDir = true
			} else {
				return nil
			}
		}
		
		guard isDir.boolValue else {
			return nil
		}
		
		// Now the game directory
		var gameDir = groupDir.appendingPathComponent(title!)
		var number = 0
		let maxNumber = 20
		
		while !directory(gameDir, isFor: ident) && number < maxNumber {
			number += 1
			gameDir = groupDir.appendingPathComponent("\(title!) \(number)")
		}
		
		guard number < maxNumber else {
			return nil
		}
		
		// Create the directory if necessary
		if !urlIsAvailable(gameDir, isDirectory: &isDir, isPackage: nil, isReadable: nil, error: nil) {
			if createGame {
				try? FileManager.default.createDirectory(at: gameDir, withIntermediateDirectories: false, attributes: nil)
				isDir = true
			} else {
				if createGroup {
					// Special case, really. Sometimes we need to know where we're going to move the game to
					return gameDir
				} else {
					return nil
				}
			}
		}
		if !urlIsAvailable(gameDir, isDirectory: &isDir, isPackage: nil, isReadable: nil, error: nil) || !isDir.boolValue {
			// Chances of reaching here should have been eliminated previously
			return nil
		}
		
		// Create the identifier file
		let identityFile = gameDir.appendingPathComponent(ZoomIdentityFilename)
		let dat = try! NSKeyedArchiver.archivedData(withRootObject: ident, requiringSecureCoding: true)
		try! dat.write(to: identityFile)
		
		return gameDir
	}

	
	@objc(directoryForIdent:create:)
	@MainActor func directory(for ident: ZoomStoryID, create: Bool) -> URL? {
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
	
	@MainActor func moveStoryToPreferredDirectory(with ident: ZoomStoryID) -> Bool {
		guard let currentDir = directory(for: ident, create: false)?.standardizedFileURL else {
			return false
		}
		
#if DEVELOPMENT_BUILD
		NSLog("Moving %@ to its preferred path (currently at %@)", ident, currentDir.path)
#endif

		// Get the 'ideal' directory
		let idealDir = findDirectory(for: ident, createGameDir: false, createGroupDir: true)?.standardizedFileURL

		// See if they already match
		if idealDir == currentDir {
			return true
		}
		
#if DEVELOPMENT_BUILD
		NSLog("Ideal location is %@", idealDir?.path ?? "(nil)")
#endif

		guard let idealDir = idealDir else {
#if DEVELOPMENT_BUILD
			NSLog("...which isn't a real path!")
#endif
			return false
		}
		
		// If they don't match, then idealDir should be new (or something weird has just occured)
		// Hmph. HFS+ is case-insensitve, and stringByStandardizingPath does not take account of this. This could
		// cause some major problems with organiseStory:withIdent:, as that deletes/copies files...
		// We're dealing with this by calling lowercaseString, but there's no guarantee that this matches the algorithm
		// used for comparing filenames internally to HFS+.
		//
		// Don't even think about UFS or HFSX. There's no way to tell which we're using
		if (try? idealDir.checkResourceIsReachable()) ?? false {
			// Doh!
			NSLog("Wanted to move game from '%1$@' to '%2$@', but '%2$@' already exists", currentDir.path, idealDir.path)
			return false
		}
		
		// Move the old directory to the new directory
		
		// Vague possibilities of this failing: in particular, currentDir may be not write-accessible or
		// something might appear there between our check and actually moving the directory
		do {
			try FileManager.default.moveItem(at: currentDir, to: idealDir)
		} catch {
			NSLog("Failed to move '%@' to '%@'", currentDir.path, idealDir.path)
			return false
		}
		
		// Success: store the new directory in the defaults
		if let identStr = ident.idString {
			gameDirectories[identStr] = idealDir
			try? save()
		}
		
		return true
	}
	
	@MainActor @objc private
	func finishChanging(_ story: ZoomStory) {
		// For our pre-arranged stories, several IDs are possible, but more usually one
		guard let storyIDs = story.storyIDs else {
			return
		}
		guard ZoomPreferences.global.keepGamesOrganised else {
			return
		}
		var changed = false
		
#if DEVELOPMENT_BUILD
		NSLog("Finishing changing %@", story.title ?? "(nil)")
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
			NSLog("ID %@ (%@) is located at %@ (%@)", ident, realID, oldGameFile?.path ?? "(nil)", oldGameLoc.path)
#endif
			
			// Actually perform the move
			if moveStoryToPreferredDirectory(with: stories[identID].fileID) {
				changed = true
				
				// Store the new location of the game, if necessary
				if (/* DISABLES CODE */ true || oldGameLoc == oldGameFile ) {
					var newGameFile = directory(for: ident, create: false)?.appendingPathComponent(oldGameLoc.lastPathComponent)
					newGameFile = newGameFile?.standardizedFileURL
					
#if DEVELOPMENT_BUILD
					NSLog("Have moved to %@", newGameFile?.path ?? "(nil)")
#endif
					if oldGameFile == nil || newGameFile == nil {
						NSLog("Story ID %@ doesn't seem to exist...", ident)
						continue
					}
					
					if oldGameFile != newGameFile, let newGameFile {
						stories.remove(at: identID)
						stories.append(Object(url: newGameFile, bookmarkData: try? newGameFile.bookmarkData(options: [.securityScopeAllowOnlyReadAccess]), fileID: ident))
					}
				}
			}
		}
		
		if changed {
			setOrganiserChanged()
		}
	}

	// MARK: - Retrieving story information
	
	@MainActor var storyIdents: [ZoomStoryID] {
		return stories.map({$0.fileID})
	}

	@objc(URLForIdent:)
	@MainActor func urlFor(_ ident: ZoomStoryID) -> URL? {
		return storyLock.withLock {
			guard let storyIdx = stories.firstIndex(where: {$0.fileID == ident}) else {
				return nil
			}
			let aURL = stories[storyIdx].url
			
			if (try? aURL.checkResourceIsReachable()) ?? false {
				return aURL
			}
			do {
				try stories[storyIdx].update()
			} catch {
				// Return the old, bad URL
				return aURL
			}
			
			return stories[storyIdx].url
		}
	}
	
	// MARK: - Reorganising stories
	
	@objc(organiseStory:)
	@MainActor func organiseStory(_ story: ZoomStory) {
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
	@MainActor func organiseStory(_ story: ZoomStory, with ident: ZoomStoryID) {
		guard var filename = urlFor(ident) else {
			NSLog("WARNING: Attempted to organise a story with no filename")
			return
		}
		
#if DEVELOPMENT_BUILD
		NSLog("Organising %@ (%@)", story.title!, ident)
#endif
		
		storyLock.withLock {
			let oldFilename = filename
			
#if DEVELOPMENT_BUILD
			NSLog("... currently at %@", oldFilename.path)
#endif
			
			// Copy to a standard directory, change the filename we're using
			filename = filename.standardizedFileURL
			
			let fileDir = directory(for: ident, create: true)
			var destFile = fileDir?.appendingPathComponent(oldFilename.lastPathComponent)
			destFile = destFile?.standardizedFileURL
			
#if DEVELOPMENT_BUILD
			NSLog("... best directory %@ (file will be %@)", fileDir?.path ?? "(nil)", destFile?.path ?? "(nil)")
#endif
			
			if filename != destFile, let destFile = destFile {
				var moved = false
				if filename.path.lowercased() == destFile.path.lowercased() {
					// *LIKELY* that these are in fact the same file with different case names
					// Cocoa doesn't seem to provide a good way to see if too paths are actually the same:
					// so the semantics of this might be incorrect in certain edge cases. We move to ensure
					// that everything is nice and safe
					try? FileManager.default.moveItem(at: filename, to: destFile)
					moved = true
					filename = destFile
				}
				// The file might already be organised, but in the wrong directory
				let gameStorageDirectory: String = ZoomPreferences.global.organiserDirectory!
				let gameStorageURL = URL(fileURLWithPath: gameStorageDirectory, isDirectory: true)
				let storageComponents = gameStorageURL.pathComponents
				
				let filenameComponents = filename.pathComponents
				var outsideOrganisation = true
				
				if filenameComponents.count == storageComponents.count + 3 {
					// filenameComponents should have 3 components extra over the storage directory: group/title/game.ext
					
					// Compare the components
					outsideOrganisation = false
					for (c1, c2) in zip(filenameComponents, storageComponents) {
						// Note, there's no way to see if we're using a case-sensitive file system or not. We assume
						// we are, as that's the default. People running with HFSX or UFS can just put up with the
						// odd weirdness occuring due to this.
						if c1.compare(c2, options: [.caseInsensitive]) != .orderedSame {
							outsideOrganisation = true
							break
						}
					}
				}
				
			organization: do  {
				if !outsideOrganisation {
					// Have to move the file from the directory its in to the new directory
					// Really want to move resources and savegames too... Hmm
					let oldDir = filename.deletingLastPathComponent()
					guard let dirEnum = try? FileManager.default.contentsOfDirectory(at: oldDir, includingPropertiesForKeys: nil, options: [.skipsSubdirectoryDescendants]) else {
						break organization
					}
					
					for fileToMove in dirEnum {
#if DEVELOPMENT_BUILD
						NSLog("... reorganising %@ to %@",  fileToMove.path, fileDir?.appendingPathComponent(fileToMove.lastPathComponent).path ?? "(nil)")
#endif
						
						try? FileManager.default.moveItem(at: fileToMove, to: fileDir!.appendingPathComponent(fileToMove.lastPathComponent))
					}
					moved = true
					filename = destFile
				}
			}
				// If we haven't already moved the file, then
				if !moved {
					do {
						try? FileManager.default.removeItem(at: destFile)
						try FileManager.default.copyItem(at: filename, to: destFile)
						filename = destFile
					} catch {
						NSLog("Warning: couldn't copy '%@' to '%@'", filename.path, destFile.path)
					}
				}
				
				// Notify the workspace of the change
				// Actually, don't: -noteFileSystemChanged: seems to be soft-deprecated.
			}
			
			// Update the index
			if let filenameIndex = stories.firstIndex(where: { obj in
				return obj.url == oldFilename
			}) {
				stories.remove(at: filenameIndex)
			}
			
			if ident != nil {
				stories.append(Object(url: filename, bookmarkData: try? filename.bookmarkData(options: [.securityScopeAllowOnlyReadAccess]), fileID: ident))
			}
			// Organise the story's resources
			if var resources = story.object(forKey: "ResourceFilename") as? String, FileManager.default.fileExists(atPath: resources) {
				guard let dir = directory(for: ident, create: false) else {
					NSLog("No organised directory for game: cannot store resources")
					return
				}
				
				var isDir: ObjCBool = false
				let exists = urlIsAvailable(dir, isDirectory: &isDir, isPackage: nil, isReadable: nil, error: nil)
				
				guard exists, isDir.boolValue else {
					NSLog("Organised directory for game does not exist")
					return
				}
				
				let newFile = dir.appendingPathComponent("resource.blb").standardizedFileURL
				let oldFile = URL(fileURLWithPath: resources, isDirectory: false).standardizedFileURL
				
				if oldFile.path.lowercased() != newFile.path.lowercased() {
					if (try? newFile.checkResourceIsReachable()) ?? false {
						try? FileManager.default.removeItem(at: newFile)
					}
					
					do {
						try FileManager.default.copyItem(at: oldFile, to: newFile)
						resources = newFile.path
					} catch {
						NSLog("Unable to copy resource file to new location: \(error.localizedDescription)")
					}
					story.setObject(resources, forKey: "ResourceFilename")
				}
			} else {
				story.setObject(nil, forKey: "ResourceFilename")
			}
		}
	}
	
	func organiseAllStories() {
		guard !alreadyOrganising else {
			NSLog("ZoomStoryOrganiser: organiseAllStories called while Zoom was already in the process of organising")
			return
		}
		storyLock.withLock {
			alreadyOrganising = true
			
			Task {
				await organiserThread()
			}
		}
	}
	
	@MainActor private func renamed(_ ident: ZoomStoryID?, to url: URL) {
		guard let ident else {
			return
		}

		storyLock.withLock {
			if let oldFileName = stories.firstIndex(where: {$0.fileID == ident}) {
				stories.remove(at: oldFileName)
			}
			
			stories.append(Object(url: url, bookmarkData: try? url.bookmarkData(options: [.securityScopeAllowOnlyReadAccess]), fileID: ident))
		}
		setOrganiserChanged()
	}
	
	/// Changes the story organisation directory.
	/// Should be called before changing the story directory in the preferences.
	@MainActor @objc(reorganiseStoriesToNewDirectoryURL:)
	func reorganiseStories(to newStoryDirectory: URL) {
		do {
			if !((try? newStoryDirectory.checkResourceIsReachable()) ?? false) {
				do {
					try FileManager.default.createDirectory(at: newStoryDirectory, withIntermediateDirectories: false, attributes: nil)
				} catch {
					NSLog("WARNING: Can't reorganise to %@ - couldn't create directory: %@", newStoryDirectory.path, error.localizedDescription)
					return
				}
			}
			
			storyLock.lock()
			defer {
				storyLock.unlock()
			}
			
			// Get the old story directory
			let lastStoryDirectory = ZoomPreferences.global.organiserDirectory!
			
			// Nothing to do if it's not different
			if lastStoryDirectory.lowercased() == newStoryDirectory.path.lowercased() {
				storyLock.unlock()
				storyLock.lock()
			}
			
			// Move the stories around
			startedActing()
			defer {
				endedActing()
			}
			
			let lastStoryDirURL = URL(fileURLWithPath: lastStoryDirectory, isDirectory: true)
			
			/// List of files in our database
			let allStories = stories
			
			/// Parts of directories
			let originalComponents = lastStoryDirURL.pathComponents
			
			for aStory in allStories {
				// Retrieve info about the file
				let storyID = aStory.fileID
				let filename = aStory.url
				let filenameComponents = filename.pathComponents
				// Do nothing if the file is definitely outside the organisation structure
				guard filenameComponents.count > originalComponents.count + 1 else {
					NSLog("WARNING: Not organising %@, as it doesn't appear to have been organised before", aStory.url.path)
					continue	// Can't be equivalent.
				}
				
				// Work out where this file would end up
				var newFilename = newStoryDirectory
				for part in filenameComponents[filenameComponents.index(filenameComponents.endIndex, offsetBy: -3) ..< filenameComponents.endIndex] {
					newFilename.appendPathComponent(part)
				}
				
				guard ((try? filename.checkResourceIsReachable()) ?? false) else {
					// File has gone away - note that with the way this algorithm is implemented, this is expected to happen
					// If the file now exists in the new location, update our database
					// If not, then log a warning
					if !((try? newFilename.checkResourceIsReachable()) ?? false) {
						NSLog("WARNING: The file %@ appears to have gone away somewhere mysterious", filename.path)
					} else {
						storyLock.unlock()
						renamed(storyID, to: newFilename)
						storyLock.lock()
					}
					continue
				}
				
				// If filename is in the original directory, then move it to the new one
				var isOrganised = true
				for (x, comp) in originalComponents.enumerated() {
					if filenameComponents[x].caseInsensitiveCompare(comp) != .orderedSame {
						isOrganised = false
						break
					}
				}
				
				if !isOrganised {
					NSLog("WARNING: Not organising %@, as it doesn't appear to have been organised before", filename.path)
					continue	// Can't be equivalent.
				}

				// Work out what to move to where
				let component = originalComponents.count
				
				var moveFrom: URL? = nil
				var moveTo: URL? = nil
				
				while component < filenameComponents.count {
					let componentToMove = filenameComponents[originalComponents.count]
					
					moveFrom = lastStoryDirURL.appendingPathComponent(componentToMove)
					moveTo = newStoryDirectory.appendingPathComponent(componentToMove)
				}
				
				guard let moveFrom = moveFrom, let moveTo = moveTo else {
					continue
				}
				
				if (try? moveTo.checkResourceIsReachable()) ?? false {
					NSLog("WARNING: Not moving %@, as it would clobber a file at %@", moveFrom.path, moveTo.path)
					continue
				}
				
				do {
					try FileManager.default.moveItem(at: moveFrom, to: moveTo)
				} catch {
					NSLog("WARNING: Failed to move %@ to %@, error %@", moveFrom.path, moveTo.path, error.localizedDescription)
					continue
				}
				
				// Update our database
				storyLock.unlock()
				renamed(storyID, to: newFilename)
				storyLock.lock()
			}
		}
		try? save() // In case we later crash
	}
	
	@MainActor @objc(storyFromId:)
	func story(from storyID: ZoomStoryID) -> ZoomStory? {
		return storyLock.withLock {
			return (NSApp.delegate as! ZoomAppDelegate).findStory(storyID)
		}
	}
	
	private func organiserThread() async {
		await startedActing()
		
		let gameStorageDirectory = await MainActor.run { () -> URL in
			let org = ZoomPreferences.global.organiserDirectory!
			return URL(fileURLWithPath: org, isDirectory: true)
		}
		let storageComponents = gameStorageDirectory.pathComponents
		
		// Get the list of stories we need to update
		// It is assumed any new stories at this point will be organised correctly
		let ourStories = await MainActor.run(body: {
			storyLock.withLock {
				return stories
			}
		})
		
		for story in ourStories {
			let filename = story.url
			
			if !((try? filename.checkResourceIsReachable()) ?? false) {
				// The story does not exist: remove from the database and keep moving
				
				await MainActor.run(body: {
					if let idx = stories.firstIndex(of: story) {
						_=stories.remove(at: idx)
					}
					setOrganiserChanged()
				})
				
				continue
			}
			
			// OK, the story still exists with that filename. Pass this off to the main thread
			// for organisation
			// [(ZoomStoryOrganiser*)[subThreadConnection rootProxy] reorganiseStoryWithFilename: filename];
			// ---  FAILS, creates duplicates sometimes
			
			// There are a few possibilities:
			//
			//		1. The story is outside the organisation directory
			//		2. The story is in the organisation directory, but in the wrong group
			//		3. The story is in the organisation directory, but in the wrong directory
			//		4. There are multiple copies of the story in the directory
			//
			// 2 and 3 here are not exclusive. There may be a story in the organisation directory with the
			// same title, so the 'ideal' location might turn out to be unavailable.
			//
			// In case 1, act as if the story has been newly added, except move the old story to the trash. Finished.
			// In case 2, move the story directory to the new group. Rename if it already exists there (pick
			//		something generic, I guess). Fall through to check case 3.
			// In case 3, pick the 'best' possible name, and rename it
			// In case 4, merge the story directories. (We'll leave this out for the moment)
			//
			// Also a faint chance that the file/directory will disappear while we're operating on it.
			
			let storyID = story.fileID
			guard let zStory = await self.story(from: storyID) else {
				// No info (file has gone away?)
				NSLog("Organiser: failed to reorganise file '%@' - couldn't find any information for this file", filename.path)
				continue
			}
			
			// CHECK FOR CASE 1 - does filename begin with gameStorageDirectory?
			let filenameComponents = filename.pathComponents
			var outsideOrganisation = true
			
			if filenameComponents.count == storageComponents.count + 3 {
				// filenameComponents should have 3 components extra over the storage directory: group/title/game.ext
				
				// Compare the components
				outsideOrganisation = false
				for (c1, c2) in zip(filenameComponents, storageComponents) {
					// Note, there's no way to see if we're using a case-sensitive file system or not. We assume
					// we are, as that's the default. People running with HFSX or UFS can just put up with the
					// odd weirdness occuring due to this.
					if c1.compare(c2, options: [.caseInsensitive]) != .orderedSame {
						outsideOrganisation = true
						break
					}
				}
			}
			
			if outsideOrganisation {
				// CASE 1 HAS OCCURED. Organise this story
				NSLog("File %@ outside of organisation directory: organising", filename.path)
				
				await organiseStory(zStory, with: storyID)
				
				continue
			}
			
			// CHECK FOR CASE 2: story is in the wrong group
			var inWrongGroup = false
			
			let (expectedGroup, actualGroup) = storyLock.withLock {
				var expectedGroup = sanitiseDirectoryName(zStory.group) ?? "Ungrouped"
				let actualGroup = filenameComponents[filenameComponents.count-3]
				if expectedGroup == "" {
					expectedGroup = "Ungrouped"
				}
				return (expectedGroup, actualGroup)
			}

			if actualGroup.lowercased() != expectedGroup.lowercased() {
				NSLog("Organiser: File %@ not in the expected group (%@ vs %@)", filename.path, actualGroup, expectedGroup)
				inWrongGroup = true
			}

			// CHECK FOR CASE 3: story is in the wrong directory
			var inWrongDirectory = false
			
			let (expectedDir, actualDir) = storyLock.withLock {
				let a = sanitiseDirectoryName(zStory.title)!
				let b = filenameComponents[filenameComponents.count - 2]
				return (a, b)
			}

			if actualDir.lowercased() != expectedDir.lowercased() {
				NSLog("Organiser: File %@ not in the expected directory (%@ vs %@)", filename.path, actualDir, expectedDir)
				inWrongDirectory = true
			}
			
			// Deal with these two cases: create the group/move the directory
			if inWrongGroup {
				// Create the group directory if required
				let groupDirectory = gameStorageDirectory.appendingPathComponent(expectedGroup, isDirectory: true)
				
				// Create the group directory if it doesn't already exist
				// Don't organise this file if there's a file already here

				var isDir: ObjCBool = false
				if urlIsAvailable(groupDirectory, isDirectory: &isDir, isPackage: nil, isReadable: nil, error: nil) {
					if isDir.boolValue {
						// Oops, this is a file: can't move anything here
						NSLog("Organiser: Can't create group directory at %@ - there's a file in the way", groupDirectory.path)
						continue
					}
				} else {
					NSLog("Organiser: Creating group directory at %@", groupDirectory.path)
					do {
						try FileManager.default.createDirectory(at: groupDirectory, withIntermediateDirectories: false, attributes: nil)
					} catch {
						// strerror & co aren't thread-safe so we can't safely retrieve the actual error number
						NSLog("Organiser: Failed to create directory at %@, returned %@", groupDirectory.path, error.localizedDescription)
						continue

					}
				}
			}
			
			if inWrongGroup || inWrongDirectory {
				// Move the game (semi-atomically)
				let titleDirectory: URL? = storyLock.withLock {
					let oldDirectory = filename.deletingLastPathComponent()
					
					let groupDirectory = gameStorageDirectory.appendingPathComponent(expectedGroup, isDirectory: true)
					
					var titleDirectory: URL? = nil
					
					var count = 0
					
					// Work out where to put the game (duplicates might exist)
					repeat {
						if (count == 0) {
							titleDirectory = groupDirectory.appendingPathComponent(expectedDir, isDirectory: true)
						} else {
							titleDirectory = groupDirectory.appendingPathComponent("\(expectedDir) \(count)", isDirectory: true)
						}
						
						if titleDirectory!.path.lowercased() == oldDirectory.path.lowercased() {
							// Nothing to do!
							NSLog("Organiser: oops, name difference is due to multiple stories with the same title")
							break
						}
						
						if (try? titleDirectory!.checkResourceIsReachable()) ?? false {
							// Already exists - try the next name along
							count += 1
							continue
						}
						
						// Doesn't exist at the moment: OK for renaming
						break
					} while true

					
					if titleDirectory!.path.lowercased() == oldDirectory.path.lowercased() {
						// Still nothing to do
						return nil
					}
					
					// Move the game to its new home
					NSLog("Organiser: Moving %@ to %@", oldDirectory.path, titleDirectory!.path)
					do {
						try FileManager.default.moveItem(at: oldDirectory, to: titleDirectory!)
					} catch {
						NSLog("Organiser: Failed to move %@ to %@ (rename failed)", oldDirectory.path, titleDirectory!.path)
						return nil
					}
					
					// Change the storyFilenames array
					/* -- ??
					NSInteger oldIndex = [storyFilenames indexOfObject: filename];
					
					if (oldIndex != NSNotFound) {
						[storyFilenames removeObjectAtIndex: oldIndex];
						[storyIdents removeObjectAtIndex: oldIndex];
					}
					 */
					return titleDirectory
				}

				// Update filenamesToIdents and identsToFilenames appropriately
				if let tmpString = titleDirectory?.appendingPathComponent(filename.lastPathComponent) {
					await renamed(storyID, to: tmpString)
				}
			}
		}
		
		// Not organising any more
		storyLock.withLock {
			alreadyOrganising = false
		}
		
		// Tidy up
		await endedActing()
	}
	
	// MARK: -
	
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
