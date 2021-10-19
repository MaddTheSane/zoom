//
//  ZoomQuest.swift
//  Quest
//
//  Created by C.W. Betts on 10/3/21.
//

import Cocoa
import ZoomPlugIns.ZoomPlugIn
import ZoomPlugIns.ZoomGlkWindowController
import ZoomPlugIns.ZoomGlkDocument

public class Quest: ZoomPlugIn {
	public override class var pluginVersion: String! {
		return Bundle(for: Quest.self).object(forInfoDictionaryKey: "CFBundleVersion") as? String
	}
	
	public override class var pluginDescription: String! {
		return "Plays Quest files"
	}
	
	public override class var pluginAuthor: String! {
		return "C.W. \"Madd the Sane\" Betts"
	}
	
	public override class var canLoadSavegames: Bool {
		return false
	}
	
	public override class func canRun(_ path: URL!) -> Bool {
		return false
	}
	
	public override class func canRunPath(_ path: String!) -> Bool {
		return false
	}
	
	public override init!(url gameFile: URL!) {
		return nil
	}
	
	public override func gameDocument(withMetadata story: ZoomStory!) -> NSDocument! {
		let toRet = QuestDocument()
		toRet.plugIn = self
		return toRet
	}
	
	public override func gameDocument(withMetadata story: ZoomStory!, saveGame: String!) -> NSDocument! {
		let toRet = QuestDocument()
		toRet.plugIn = self
		return toRet
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
	
	public override func setPreferredSaveDirectory(_ dir: String!) {
		
	}
}
