//
//  ZoomQuest.swift
//  Quest
//
//  Created by C.W. Betts on 10/3/21.
//

import Cocoa
import ZoomPlugIns.ZoomGlkPlugIn
import ZoomPlugIns.ZoomGlkWindowController
import ZoomPlugIns.ZoomGlkDocument

final public class Quest: ZoomGlkPlugIn {
	public override class var pluginVersion: String! {
		return Bundle(for: Quest.self).object(forInfoDictionaryKey: "CFBundleVersion") as? String
	}
	
	public override class var pluginDescription: String! {
		return "Plays Quest files"
	}
	
	public override class var pluginAuthor: String! {
		return #"C.W. "Madd the Sane" Betts"#
	}
	
	public override class var canLoadSavegames: Bool {
		return false
	}
	
	public override class func canRun(_ path: URL!) -> Bool {
		guard let url = path else {
			return false
		}
		return url.lastPathComponent.lowercased() == "cas"
	}
	
	public override init!(url gameFile: URL!) {
		super.init(url: gameFile)
		clientPath = Bundle(for: Quest.self).path(forAuxiliaryExecutable: "geas")
	}
	
	/*
	public override func idForStory() -> ZoomStoryID! {
		return nil
	}
	
	public override func defaultMetadata() -> ZoomStory! {
		return nil
	}*/
	
	public override func coverImage() -> NSImage! {
		return nil
	}
}
