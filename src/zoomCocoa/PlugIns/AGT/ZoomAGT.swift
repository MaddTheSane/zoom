//
//  ZoomAdrift.swift
//  Adrift
//
//  Created by C.W. Betts on 10/12/21.
//
//  Some code adapted from Babel.
//

import Cocoa
import ZoomPlugIns.ZoomPlugIn
import ZoomPlugIns.ZoomPlugIn.Glk
import ZoomPlugIns.ZoomBabel
import ZoomPlugIns.ZoomStoryConverter
import ZoomPlugIns
import UniformTypeIdentifiers

private let AGX_MAGIC = Data([0x58, 0xC7, 0xC1, 0x51])

/* Helper functions to unencode integers from AGT source */
private func read_agt_short(_ sf: Data) -> Int16 {
	precondition(sf.count >= 2)
	var finalVal = UInt16(sf[0])
	finalVal |= UInt16(sf[1]) << 8
	let preRet = Int16(bitPattern: finalVal)
	return preRet
}

private func read_agt_int(_ sf: Data) -> Int32 {
	precondition(sf.count >= 4)
	var finalVal = UInt32(sf[0])
	finalVal |= UInt32(sf[1]) << 8
	finalVal |= UInt32(sf[2]) << 16
	finalVal |= UInt32(sf[3]) << 24
	let preRet = Int32(bitPattern: finalVal)
	return preRet
}

private let imgExts = [
	"pcx",
	"p06", /* 640x200x2 */
	"p40","p41","p42","p43", /* 320x200x4 */
	"p13", /* 320x200x16 */
	"p19", /* 320x200x256 */
	"p14","p16", /* 640x200x16, 640x350x16   */
	"p18", /* 640x480x16 */
	"gif","png","bmp","jpg","jpeg","jpe",
	"fli","flc","flic"]

final public class AGT: ZoomGlkPlugIn, ZoomStoryConverter {
	public override class var pluginVersion: String {
		return (Bundle(for: AGT.self).object(forInfoDictionaryKey: "CFBundleVersion") as? String)!
	}
	
	public override class var pluginDescription: String {
		return "Plays AGT files"
	}
	
	public override class var pluginAuthor: String {
		return #"C.W. "Madd the Sane" Betts"#
	}
	
	public override class var supportedFileTypes: [String] {
		return ["public.agt", "agx", "'AGTS'"]
	}
	
	public override class var supportedContentTypes: [UTType] {
		return [UTType(importedAs: "public.agt")]
	}
	
	public override class var canLoadSavegames: Bool {
		return false
	}
	
	public override class var needsPathPassedToTask: Bool {
		return true
	}
	
	public override class func canRun(_ fileURL: URL) -> Bool {
		guard ((try? fileURL.checkResourceIsReachable()) ?? false) else {
			return fileURL.pathExtension.caseInsensitiveCompare("agt") == .orderedSame || fileURL.pathExtension.caseInsensitiveCompare("agx") == .orderedSame
		}
		
		do {
			let file = try FileHandle(forReadingFrom: fileURL)
			let checkDat: Data
			if #available(macOS 10.15.4, *) {
				guard let checkData = try file.read(upToCount: 36) else {
					return false
				}
				checkDat = checkData
			} else {
				checkDat = file.readData(ofLength: 36)
			}
			guard checkDat.count >= 36 else {
				return false
			}
			return checkDat[0..<4] == AGX_MAGIC
		} catch {
			return false
		}
	}
	
	public override init?(url gameFile: URL) {
		super.init(url: gameFile)
		clientPath = Bundle(for: AGT.self).path(forAuxiliaryExecutable: "agil")
	}
	
	public override func idForStory() -> ZoomStoryID? {
		do {
			let file = try FileHandle(forReadingFrom: gameURL)
			
			/* Read the position of the game desciption block */
			try file.seek(toOffset: 32)
			guard let datVar = try file.read(upToCount: 4), datVar.count == 4 else {
				return nil
			}
			let l = read_agt_int(datVar)
			let extent = try file.seekToEnd()
			guard extent >= l + 6 else {
				return nil
			}
			try file.seek(toOffset: UInt64(l))
			guard let datVar2 = try file.read(upToCount: 6), datVar2.count == 6 else {
				return nil
			}
			let gameVersion = read_agt_short(datVar2)
			let game_sig = read_agt_int(datVar2.advanced(by: 2))
			let output = String(format: "AGT-%05d-%08X", gameVersion, game_sig)
			return ZoomStoryID(idString: output)
		} catch {
			return nil
		}
	}

	public override func defaultMetadata() throws -> ZoomStory {
		let babel = ZoomBabel(url: gameURL)
		guard let meta = babel.metadata() else {
			return try super.defaultMetadata()
		}
		
		return meta
	}
	
	public override var coverImage: NSImage? {
		let imageBase = gameURL.deletingPathExtension()
		
		for (i, ext) in imgExts.enumerated().reversed() {
			let theOut = imageBase.appendingPathExtension(ext)
			if FileManager.default.fileExists(atPath: theOut.path) {
				switch i {
				case 0 ..< 11:
					do {
						let dec = try PCXDecoder(fileAt: theOut)
						if let imgData = dec.dataRepresentation,
						   let image = NSImage(data: imgData) {
							return image
						}
					} catch {
						NSLog("PCX conversion failed: \(error)")
					}
					
				case 17 ..< 20:
					if let gifData = CreateGIFFromFLICFileURL(theOut as NSURL, true) as Data?,
					   let image = NSImage(data: gifData) {
						return image
					}
					
				case 11 ... 16:
					fallthrough
				default:
					if let image = NSImage(contentsOf: theOut) {
						return image
					}
				}
			}
		}
		let babel = ZoomBabel(url: gameURL)
		return babel.coverImage()
	}
	
	// MARK: - ZoomStoryConverter protocol
	
	public static func convertStoryFile(at url: URL) async throws -> URL {
		let ourBundle = Bundle(for: AGT.self)
		guard let agtURL = ourBundle.url(forAuxiliaryExecutable: "agt2agx") else {
			throw CocoaError(.fileReadNoSuchFile, userInfo: [NSURLErrorKey: ourBundle.bundleURL.appendingPathComponent("Contents/MacOS/agt2agx")])
		}
		var outFile = url
		outFile.deletePathExtension()
		outFile.appendPathExtension("agx")
		let convertProcess = Process()
		convertProcess.executableURL = agtURL
		convertProcess.arguments = ["-o", outFile.path, url.path]
		try convertProcess.run()
		convertProcess.waitUntilExit()
		guard convertProcess.terminationStatus == 0 else {
			throw CocoaError(.fileReadCorruptFile, userInfo: [NSURLErrorKey: url])
		}
		return outFile
	}

	public static func canConvert(_ path: URL) -> Bool {
		// TODO: more testing?
		return supportedExtensions.contains(path.pathExtension.lowercased())
	}
	
	private static let supportedExtensions = ["d$$"]
	
	public static let supportedConverterFileTypes = ["public.ddollardollar"] + supportedExtensions
	
	public static let supportedConverterContentTypes: [UTType] = {
		return [UTType(importedAs: "public.ddollardollar")]
	}()
}
