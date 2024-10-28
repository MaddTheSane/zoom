//
//  MagneticScrolls.swift
//  Magnetic Scrolls
//
//  Created by C.W. Betts on 10/27/24.
//

import Cocoa
import ZoomPlugIns.ZoomPlugIn
import ZoomPlugIns.ZoomPlugIn.Glk

public class MagneticScrolls: ZoomGlkPlugIn {
	public override class var pluginVersion: String {
		return (Bundle(for: MagneticScrolls.self).object(forInfoDictionaryKey: "CFBundleVersion") as? String)!
	}
	
	public override class var pluginDescription: String {
		return "Plays Magnetic Scrolls files"
	}
	
	public override class var pluginAuthor: String {
		return #"C.W. "Madd the Sane" Betts"#
	}
	
	public override class var canLoadSavegames: Bool {
		return false
	}
	
	public override class var supportedFileTypes: [String] {
		return ["public.magnetic-scroll", "mag"]
	}

	
	
	public override init?(url gameFile: URL) {
		super.init(url: gameFile)
		clientPath = Bundle(for: MagneticScrolls.self).path(forAuxiliaryExecutable: "magnetic")
	}

}
