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
		return "Plays JACL Adventure Creation Language files"
	}
	
	public override class var pluginAuthor: String {
		return #"C.W. "Madd the Sane" Betts"#
	}
	
	public override class var canLoadSavegames: Bool {
		return false
	}
	
	public override class var needsPathPassedToTask: Bool {
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
		
		return isCompatibleJACLFile(at: fileURL)
	}
	
	public override init?(url gameFile: URL) {
		super.init(url: gameFile)
		clientPath = Bundle(for: JACL.self).path(forAuxiliaryExecutable: "jacl-interpreter")
	}
	
	public override func idForStory() -> ZoomStoryID? {
		guard let stringID = stringIDForJACLFile(at: gameURL) else {
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
	
//	public override var coverImage: NSImage? {
//		let babel = ZoomBabel(url: gameURL)
//		return babel.coverImage()
//	}
}

private func stringIDForJACLFile(at url: URL) -> String? {
	return nil
}

private let processedData: Data = {
	"\n#processed:".data(using: .ascii)!
}()
private func isCompatibleJACLFile(at url: URL) -> Bool {
	// TAKE A COPY OF THE FIRST 2000 BYTES
	guard let fh = try? FileHandle(forReadingFrom: url) else {
		return false
	}
	let fileData: Data
	if #available(macOS 10.15.4, *) {
		guard let dat = try? fh.read(upToCount: 2000) else {
			return false
		}
		fileData = dat
	} else {
		fileData = fh.readData(ofLength: 2000)
	}
	if fileData.range(of: processedData) != nil {
		return true
	}
	//TODO: JACL checks.
	return url.pathExtension.caseInsensitiveCompare("jacl") == .orderedSame
}
