//
//  ZoomAdrift.swift
//  Adrift
//
//  Created by C.W. Betts on 10/12/21.
//

import Cocoa
import ZoomPlugIns.ZoomPlugIn
import ZoomPlugIns.ZoomPlugIn.Glk
import ZoomPlugIns.ZoomBabel
import CommonCrypto

final public class JACL: ZoomGlkPlugIn {
	public override class var pluginVersion: String {
		return (Bundle(for: JACL.self).object(forInfoDictionaryKey: "CFBundleVersion") as? String)!
	}
	
	public override class var pluginDescription: String {
		return "Plays Adrift files"
	}
	
	public override class var pluginAuthor: String {
		return #"C.W. "Madd the Sane" Betts"#
	}
	
	public override class var canLoadSavegames: Bool {
		return true
	}
	
	public override class var supportedFileTypes: [String] {
		return ["jacl", "j2"]
	}
	
	public override class func canRun(_ fileURL: URL) -> Bool {
		guard (try? fileURL.checkResourceIsReachable()) ?? false else {
			return fileURL.pathExtension.caseInsensitiveCompare("jacl") == .orderedSame ||
			fileURL.pathExtension.caseInsensitiveCompare("j2") == .orderedSame
		}
		
		return isCompatibleAdriftFile(at: fileURL)
	}
	
	public override init?(url gameFile: URL) {
		super.init(url: gameFile)
		clientPath = Bundle(for: JACL.self).path(forAuxiliaryExecutable: "scare")
	}
	
	public override func idForStory() -> ZoomStoryID? {
		guard let stringID = stringIDForAdriftFile(at: gameURL) else {
			return nil
		}
		
		return ZoomStoryID(idString: stringID)
	}

	public override func defaultMetadata() throws -> ZoomStory {
		let babel = ZoomBabel(url: gameURL)
		guard let meta = babel.metadata() else {
			return try super.defaultMetadata()
		}
		
		return meta
	}
	
	public override var coverImage: NSImage? {
		let babel = ZoomBabel(url: gameURL)
		return babel.coverImage()
	}
}

