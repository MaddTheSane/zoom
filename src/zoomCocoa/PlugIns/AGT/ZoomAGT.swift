//
//  ZoomAdrift.swift
//  Adrift
//
//  Created by C.W. Betts on 10/12/21.
//

import Cocoa
import ZoomPlugIns.ZoomPlugIn
import ZoomPlugIns.ZoomGlkPlugIn
import ZoomPlugIns.ZoomGlkWindowController
import ZoomPlugIns.ZoomGlkDocument
import CommonCrypto

final public class AGT: ZoomGlkPlugIn {
	public override class var pluginVersion: String! {
		return Bundle(for: AGT.self).object(forInfoDictionaryKey: "CFBundleVersion") as? String
	}
	
	public override class var pluginDescription: String! {
		return "Plays AGT files"
	}
	
	public override class var pluginAuthor: String! {
		return #"C.W. "Madd the Sane" Betts"#
	}
	
	public override class var supportedFileTypes: [String]! {
		return ["public.agt", "agx", "'AGTS'"]
	}
	
	public override class var canLoadSavegames: Bool {
		return false
	}
	
	public override class func canRun(_ path: URL!) -> Bool {
		guard let fileURL = path else {
			return false
		}
		
		guard ((try? fileURL.checkResourceIsReachable()) ?? false) else {
			return fileURL.pathExtension.caseInsensitiveCompare("agt") == .orderedSame
		}
		
		return false
	}
	
	public override init!(url gameFile: URL!) {
		super.init(url: gameFile)
		clientPath = Bundle(for: AGT.self).path(forAuxiliaryExecutable: "agil")
	}
	
	public override func idForStory() -> ZoomStoryID! {
		return nil
	}

	/*
	public override func defaultMetadata() -> ZoomStory! {
		return nil
	}*/
	
	public override func coverImage() -> NSImage! {
		return nil
	}
}
