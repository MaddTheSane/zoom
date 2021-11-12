//
//  ZoomQuest.swift
//  Quest
//
//  Created by C.W. Betts on 10/3/21.
//

import Cocoa
import ZoomPlugIns.ZoomPlugIn.Glk
import ZoomPlugIns.ZoomPlugIn.Glk.WindowController
import ZoomPlugIns.ZoomPlugIn.Glk.Document

private var casHeader: Data = {
	let strData = "QCGF002"
	return strData.data(using: .ascii)!
}()

final public class Quest: ZoomGlkPlugIn {
	public override class var pluginVersion: String {
		return (Bundle(for: Quest.self).object(forInfoDictionaryKey: "CFBundleVersion") as? String)!
	}
	
	public override class var pluginDescription: String {
		return "Plays Quest 4 files"
	}
	
	public override class var pluginAuthor: String {
		return #"C.W. "Madd the Sane" Betts"#
	}
	
	public override class var canLoadSavegames: Bool {
		return false
	}
	
	public override class func canRun(_ url: URL) -> Bool {
		guard ((try? url.checkResourceIsReachable()) ?? false) else {
			let extensions = ["cas", "asl"]
			
			return extensions.contains(url.pathExtension.lowercased())
		}
		
		guard let hand = try? FileHandle(forReadingFrom: url) else {
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
	
	public override class var supportedFileTypes: [String] {
		return ["uk.co.textadventures.asl", "uk.co.textadventures.cas", "asl", "cas"]
	}
	
	public override init?(url gameFile: URL) {
		super.init(url: gameFile)
		clientPath = Bundle(for: Quest.self).path(forAuxiliaryExecutable: "geas")
	}
	
	/*
	
	public override func defaultMetadata() -> ZoomStory! {
		return nil
	}*/
	
	public override var coverImage: NSImage? {
		return nil
	}
}
