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

private var casHeader: Data = {
	let strData = "QCGF002"
	return strData.data(using: .ascii)!
}()

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
		
		guard let hand = try? FileHandle(forReadingFrom: path) else {
			return false
		}
		
		var datToTest: Data
		
		if #available(macOS 10.15.4, *) {
			guard let outDat = try? hand.read(upToCount: 7), outDat.count == 7 else {
				return false
			}
			datToTest = outDat
		} else {
			let outDat = hand.readData(ofLength: 7)
			guard outDat.count == 7 else {
				return false
			}
			datToTest = outDat
		}
		if datToTest == casHeader {
			return true
		}
		
		return url.pathExtension.lowercased() == "asl"
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
