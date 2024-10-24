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

private let AGX_MAGIC: Data = {
	let preDat: [UInt8] = [0x58, 0xC7, 0xC1, 0x51]
	
	return Data(preDat)
}()

/* Helper functions to unencode integers from AGT source */
private func read_agt_short(_ sf: Data) -> Int16 {
	precondition(sf.count >= 2)
	var finalVal: UInt16 = 0
	finalVal |= UInt16(sf[0])
	finalVal |= UInt16(sf[1]) << 8
	let preRet = Int16(bitPattern: finalVal)
	return preRet
}

private func read_agt_int(_ sf: Data) -> Int32 {
	precondition(sf.count >= 4)
	var finalVal: UInt32 = 0
	finalVal |= UInt32(sf[0])
	finalVal |= UInt32(sf[1]) << 8
	finalVal |= UInt32(sf[2]) << 16
	finalVal |= UInt32(sf[3]) << 24
	let preRet = Int32(bitPattern: finalVal)
	return preRet
}


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
			return fileURL.pathExtension.caseInsensitiveCompare("agt") == .orderedSame
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
		guard let file = try? FileHandle(forReadingFrom: gameURL) else {
			return nil
		}
		
		/* Read the position of the game desciption block */
		file.seek(toFileOffset: 32)
		var datVar = file.readData(ofLength: 4)
		let l = read_agt_int(datVar)
		let extent = file.seekToEndOfFile()
		guard extent >= l + 6 else {
			return nil
		}
		file.seek(toFileOffset: UInt64(l))
		datVar = file.readData(ofLength: 6)
		let gameVersion = read_agt_short(datVar)
		let game_sig = read_agt_int(datVar.advanced(by: 2))
		let output = String(format: "AGT-%05d-%08X", gameVersion, game_sig)

		return ZoomStoryID(idString: output)
	}

	public override func defaultMetadata() throws -> ZoomStory {
		let babel = ZoomBabel(url: gameURL)
		guard let meta = babel.metadata() else {
			return try super.defaultMetadata()
		}
		
		return meta
	}
	
	public override var coverImage: NSImage? {
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
		return supportedConverterFileTypes.contains(path.pathExtension.lowercased())
	}
	
	public static var supportedConverterFileTypes: [String] {
		return ["d$$"]
	}
	
	public static var supportedConverterContentTypes: [UTType] {
		return [UTType(importedAs: "public.ddollardollar")]
	}
}
