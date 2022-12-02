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
import UniformTypeIdentifiers

final public class Adrift: ZoomGlkPlugIn {
	public override class var pluginVersion: String {
		return (Bundle(for: Adrift.self).object(forInfoDictionaryKey: "CFBundleVersion") as? String)!
	}
	
	public override class var pluginDescription: String {
		return "Plays Adrift files"
	}
	
	public override class var pluginAuthor: String {
		return #"C.W. "Madd the Sane" Betts"#
	}
	
	public override class var canLoadSavegames: Bool {
		return true
	}
	
	public override class var supportedFileTypes: [String] {
		return ["public.adrift", "taf"]
	}
	
	@available(macOS 11.0, *)
	public override class var supportedContentTypes: [UTType] {
		return [UTType.init(importedAs: "public.adrift")]
	}
	
	public override class func canRun(_ fileURL: URL) -> Bool {
		guard (try? fileURL.checkResourceIsReachable()) ?? false else {
			return fileURL.pathExtension.caseInsensitiveCompare("taf") == .orderedSame
		}
		
		return isCompatibleAdriftFile(at: fileURL)
	}
	
	public override init?(url gameFile: URL) {
		super.init(url: gameFile)
		clientPath = Bundle(for: Adrift.self).path(forAuxiliaryExecutable: "scare")
	}
	
	public override func idForStory() -> ZoomStoryID? {
		guard let stringID = stringIDForAdriftFile(at: gameURL) else {
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
	
	public override var coverImage: NSImage? {
		let babel = ZoomBabel(url: gameURL)
		return babel.coverImage()
	}
}

// MARK: - code adapted from Babel
private struct VisualBasicRNG {
	private var vbrState: Int32 = VisualBasicRNG.VB_INIT
	/* VB RNG constants */
	private static let VB_RAND1: Int32 = 0x43FD43FD
	private static let VB_RAND2: Int32 = 0x00C39EC3
	private static let VB_RAND3: Int32 = 0x00FFFFFF
	private static let VB_INIT: Int32 = 0x00A09E86

	/// Unobfuscates one byte from a taf file. This should be called on each byte
	/// in order, as the ADRIFT obfuscation function is stately.
	///
	/// The de-obfuscation algorithm works by xoring the byte with the next
	/// byte in the sequence produced by the Visual Basic pseudorandom number
	/// generator, which is simulated here.
	mutating func translate(byte: UInt8) -> UInt8 {
		vbrState = (vbrState &* VisualBasicRNG.VB_RAND1 + VisualBasicRNG.VB_RAND2) & VisualBasicRNG.VB_RAND3;
		var r: UInt32 = UInt32(UInt8.max) * UInt32(bitPattern: vbrState)
		r /= UInt32(VisualBasicRNG.VB_RAND3) + 1
		return UInt8(r ^ UInt32(byte))
	}
	
	mutating func reset() {
		vbrState = VisualBasicRNG.VB_INIT
	}
}

private func hashMD5(from handle: FileHandle) -> String {
	var md5 = Insecure.MD5()
	handle.seek(toFileOffset: 0)
	var dat = handle.readData(ofLength: 65536)
	while dat.count > 0 {
		md5.update(data: dat)
		dat = handle.readData(ofLength: 65536)
	}
	
	let mappedBytes = md5.finalize().map { byte in
		return String(format: "%02X", byte)
	}
	return mappedBytes.joined()
}

private func stringIDForAdriftFile(at url: URL) -> String? {
	var vbr = VisualBasicRNG()
	guard let fh = try? FileHandle(forReadingFrom: url) else {
		return nil
	}

	let data = fh.readData(ofLength: 12)
	guard data.count >= 12 else {
		return nil
	}

	/* Burn the first 8 bytes of translation */
	for _ in 0 ..< 8 { _=vbr.translate(byte: 0) }
	/* Bytes 8-11 contain the Adrift version number in the formay N.NN */
	var buf: [UInt8] = [0,0,0]
	buf[0] = vbr.translate(byte: data[8])
	_=vbr.translate(byte: 0)
	buf[1] = vbr.translate(byte: data[10])
	buf[2] = vbr.translate(byte: data[11])
	let bufDat = Data(buf)
	guard let bufTxt = String(data: bufDat, encoding: .utf8),
			let adv = Int32(bufTxt) else {
		return nil
	}
	var output = String(format: "ADRIFT-%03d-", adv)
	output.append(hashMD5(from: fh))
	
	return output
}

private let versionData: Data = {
	let versionString = "Version"
	return versionString.data(using: .ascii)!
}()

/// The claim algorithm for ADRIFT is to unobfuscate the first
/// seven bytes, and check for the word "Version".
///
/// It seems fairly unlikely that the obfuscated form of that
/// word would occur in the wild
private func isCompatibleAdriftFile(at url: URL) -> Bool {
	var rng = VisualBasicRNG()
	guard let fh = try? FileHandle(forReadingFrom: url) else {
		return false
	}
	let data = fh.readData(ofLength: 12)
	guard data.count >= 12 else {
		return false
	}
	var buf = data.subdata(in: 0 ..< 7).map { val in
		return rng.translate(byte: val)
	}
	let bufDat = Data(buf)
	guard bufDat == versionData else {
		return false
	}
	_=rng.translate(byte: 0)
	buf = [0,0,0]
	buf[0] = rng.translate(byte: data[8])
	_=rng.translate(byte: 0)
	buf[1] = rng.translate(byte: data[10])
	buf[2] = rng.translate(byte: data[11])
	let versDat = Data(buf)
	guard let bufTxt = String(data: versDat, encoding: .utf8),
			let adv = Int32(bufTxt) else {
		return false
	}
	// We can't run version 5.00 Adrift files yet
	guard adv < 500 else {
		return false
	}
	return true
}
