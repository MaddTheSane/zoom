//
//  ZoomAdrift.swift
//  Adrift
//
//  Created by C.W. Betts on 10/12/21.
//

import Cocoa
import ZoomPlugIns.ZoomPlugIn
import ZoomPlugIns.ZoomGlkWindowController
import ZoomPlugIns.ZoomGlkDocument

public class Adrift: ZoomPlugIn {
	public override class var pluginVersion: String! {
		return Bundle(for: Quest.self).object(forInfoDictionaryKey: "CFBundleVersion") as? String
	}
	
	public override class var pluginDescription: String! {
		return "Plays Adrift files"
	}
	
	public override class var pluginAuthor: String! {
		return "C.W. \"Madd the Sane\" Betts"
	}
	
	public override class var canLoadSavegames: Bool {
		return false
	}
	
	public override class func canRunPath(_ path: String!) -> Bool {
		return false
	}
	
	public override init!(filename gameFile: String!) {
		super.init(filename: gameFile)
		return nil
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
