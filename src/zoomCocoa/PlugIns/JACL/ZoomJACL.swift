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
import CryptoKit

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
			return super.idForStory()
		}
		
		return ZoomStoryID(idString: stringID)
	}

	public override func defaultMetadata() throws -> ZoomStory {
		let babel = ZoomBabel(url: gameURL)
		guard let meta = babel.metadata() else {
			do {
				let fileData = try Data(contentsOf: gameURL)
				let id = ZoomStoryID(for: gameURL) ?? ZoomStoryID(data: fileData)!
				let fileString: String
				guard let fstr2 = String(data: fileData, encoding: .utf8) else {
					throw CocoaError(.fileReadInapplicableStringEncoding)
				}
				fileString = fstr2

				let meta = ZoomMetadata()
				let story = meta.findOrCreateStory(id)

				let gameRegex = try! NSRegularExpression(pattern: #"constant\s+game_title\s+"(.*)""#, options: [])
				guard let firstMatch = gameRegex.firstMatch(in: fileString, options: [], range: NSRange(fileString.startIndex ..< fileString.endIndex, in: fileString)) else {
					//Just here to throw an error to be caught in the current scope.
					throw CocoaError(.fileReadInapplicableStringEncoding)
				}
				let firstString = fileString[Range(firstMatch.range(at: 1), in: fileString)!]
				story.title = String(firstString)

				let autorRegex = try! NSRegularExpression(pattern: #"constant\s+game_author\s+"(.*)""#, options: [])
				if let authorMatch = autorRegex.firstMatch(in: fileString, options: [], range: NSRange(fileString.startIndex ..< fileString.endIndex, in: fileString)) {
					let authorSubstring = fileString[Range(authorMatch.range(at: 1), in: fileString)!]
					let authorString = String(authorSubstring)
					story.author = authorString
				}

				return story
			} catch {
				return try super.defaultMetadata()
			}
		}
		
		return meta
	}
	
//	public override var coverImage: NSImage? {
//		let babel = ZoomBabel(url: gameURL)
//		return babel.coverImage()
//	}
}

private let ifidJACL: Data = {
	"ifid:JACL-".data(using: .ascii)!
}()
private func stringIDForJACLFile(at url: URL) -> String? {
	// TAKE A COPY OF THE FIRST 2000 BYTES
	guard let fh = try? FileHandle(forReadingFrom: url) else {
		return nil
	}
	let fileData: Data
	if #available(macOS 10.15.4, *) {
		guard let dat = try? fh.read(upToCount: 2000) else {
			return nil
		}
		fileData = dat
	} else {
		fileData = fh.readData(ofLength: 2000)
	}

	if let ifidRange = fileData.range(of: ifidJACL) {
		let first = fileData.index(ifidRange.startIndex, offsetBy: 5)
		let last = fileData.index(first, offsetBy: 8)
		let ifidData = fileData[first ... last]
		if let str = String(data: ifidData, encoding: .ascii) {
			return str
		}
	}
	guard let fileString = String(data: fileData, encoding: .isoLatin1) else {
		return nil
	}
	let gameRegex = try! NSRegularExpression(pattern: #"constant\s+ifid\s+"(JACL-\d{3})""#, options: [])
	guard let firstMatch = gameRegex.firstMatch(in: fileString, options: [], range: NSRange(fileString.startIndex ..< fileString.endIndex, in: fileString)) else {
		return nil
	}
	let firstString = fileString[Range(firstMatch.range(at: 1), in: fileString)!]

	return String(firstString)
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
