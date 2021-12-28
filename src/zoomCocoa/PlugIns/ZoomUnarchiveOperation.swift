//
//  ZoomUnarchiveOperation.swift
//  ZoomPlugIns
//
//  Created by C.W. Betts on 12/24/21.
//

import Cocoa
import XADMaster.Platform
import XADMaster.Swift
import XADMaster.ArchiveParser
import ZoomPlugIns.ZoomDownload

class ZoomUnarchiveOperation: Operation, XADArchiveParserDelegate, ProgressReporting {
	private let archiveLocation: URL
	private let destinationLocation: URL
	
	private var parser: XADArchiveParser?
	private var entries = [[XADArchiveKeys : Any]]()
	private var deferredLinks = [(destination: URL, relativePath: String, dictionary: [XADArchiveKeys : Any])]()
	
	private(set) var progress: Progress = Progress.discreteProgress(totalUnitCount: 100)
	
	init(archive: URL, destination: URL) {
		archiveLocation = archive
		destinationLocation = destination
		super.init()
		progress.kind = .file
		progress.fileOperationKind = .decompressingAfterDownloading
		progress.fileURL = destination
		progress.cancellationHandler = {
			self.cancel()
		}
	}
	
	override func main() {
		let parser: XADArchiveParser
		do {
			parser = try XADArchiveParser.archiveParser(for: archiveLocation)
			parser.delegate = self
		} catch {
			NSLog("Unable to open archive at \(archiveLocation.path): \(error.localizedDescription)")
			progress.cancel()
			cancel()
			return
		}
		self.parser = parser
		defer {
			self.parser = nil
		}
		
		do {
			try parser.parse()
		} catch {
			NSLog("Unable to parse archive at \(archiveLocation.path): \(error.localizedDescription)")
			progress.cancel()
			cancel()
			return
		}
		
		progress.fileTotalCount = entries.count
		progress.fileCompletedCount = 0
		
		// Now that we have all the needed entries, iterate the entries.
		for entry in entries {
			guard !isCancelled else {
				return
			}
			
			do {
				try extract(entry: entry)
			} catch {
				cancel()
				return
			}
			
			// After it is done...
			progress.fileCompletedCount! += 1
		}
	}
	
	private func predictTotalSize() -> Int {
		var total = 0
		for dict in entries {
			guard let num = dict[.fileSizeKey] as? Int64 else {
				continue
			}
			total += Int(num)
		}
		return total
	}
	
	private func extract(entry dict: [XADArchiveKeys: Any]) throws {
		let isDir = (dict[.isDirectoryKey] as? Bool) ?? false
		let isLink = (dict[.isLinkKey] as? Bool) ?? false
		let isRes = (dict[.isResourceForkKey] as? Bool) ?? false
		let isArchive = (dict[.isArchiveKey] as? Bool) ?? false
		
		var path = destinationLocation
		do {
			let name = dict[.fileNameKey] as! XADPath
			let pathComps = name.canonicalPathComponents
			for component in pathComps {
				if component == "/" {
					continue
				}
				// Replace ".." components with "__Parent__". ".." components in the middle
				// of the path have already been collapsed by canonicalPathComponents.
				if component == ".." {
					path.appendPathComponent("__Parent__")
				} else {
					let sanitized = XADPlatform.sanitizedPathComponent(component)
					path.appendPathComponent(sanitized)
				}
			}
		}
		
		if isRes {
			// TODO: implement?
		} else if isDir {
			do {
				let resVal = try path.resourceValues(forKeys: [.isDirectoryKey])
				if resVal.isDirectory ?? false {
					return
				}
			} catch {
				
			}
			
			try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true, attributes: nil)
		} else if isLink {
			let link = try parser!.linkDestination(for: dict)
			guard let linkdest = link.string else {
				return
			}

			// Check if the link destination is an absolute path, or if it contains
			// any .. path components.
			if linkdest.hasPrefix("/") || linkdest == ".." || linkdest.hasPrefix("../") || linkdest.hasSuffix("/..") || linkdest.range(of: "/../") != nil {
				// If so, consider it unsafe, and create a placeholder file instead,
				// and create the real link only in finishExtractions.

				var fh: XADFileHandle
				do {
					fh = try XADFileHandle(forWritingAtFileURL: path)
				} catch {
					_=path.withUnsafeFileSystemRepresentation { fileSysRep in
						unlink(fileSysRep)
					}
					do {
						fh = try XADFileHandle(forWritingAtFileURL: path)
					} catch {
						throw XADError(.openFile, userInfo: [NSUnderlyingErrorKey: error])
					}
				}
				fh.close()
				deferredLinks.append((path, linkdest, dict))
			} else {
				try XADPlatform.createLink(atPath: path.path, withDestinationPath: linkdest)
			}
		} else {
			//TODO: Create a Operation subclass for file extraction?
			let fh = try XADFileHandle(forWritingAtFileURL: path)
			defer {
				fh.close()
			}

			// Try to find the size of this entry.
			var size: off_t = 0
			let sizenum = dict[.fileSizeKey] as? Int64
			if let sizenum = sizenum {
				size = sizenum
				
				// If this file is empty, don't bother reading anything, just
				// call the output function once with 0 bytes and return.
				guard size > 0 else {
					var tmpDat:UInt8 = 0
					try XADOutputTo(fh, bytes: &tmpDat, length: 0)
					return
				}
			}
			
			// Create handle and start unpacking.
			let srchandle = try parser!.handleForEntry(with: dict, wantChecksum: true)
			var done: off_t = 0
			let bufSize = 0x40000
			var buffer = Data(count: 0x40000)
			
			while true {
				guard !isCancelled else {
					return
				}
				
				// Read some data, and send it to the output function.
				// Stop if no more data was available.
				let actual = buffer.withUnsafeMutableBytes { buf in
					return srchandle.read(atMost: Int32(bufSize), toBuffer: buf.baseAddress!)
				}
				guard actual > 0 else {
					break
				}
				try buffer.withUnsafeBytes { buf in
					try XADOutputTo(fh, bytes: buf.baseAddress!, length: actual)
				}
				done += Int64(actual)
			}
			
			// Check if the file has already been marked as corrupt, and
			// give up without testing checksum if so.
			if let iscorrupt = dict[.isCorruptedKey] as? Bool, iscorrupt {
				throw XADError(.decrunch)
			}

			// If the file has a checksum, check it. Otherwise, if it has a
			// size, check that the size ended up correct.
			if srchandle.hasChecksum {
				guard srchandle.isChecksumCorrect else {
					throw XADError(.checksum)
				}
			} else {
				if sizenum != nil, done != size  {
					throw XADError(.decrunch) // kind of hacky
				}
			}
		}
		try XADPlatform.updateFileAttributes(atPath: path.path, forEntryWith: dict, parser: parser!, preservePermissions: true)
	}
	
	// MARK: - XADArchiveParserDelegate calls
	
	func archiveParserNeedsPassword(_ parser: XADArchiveParser) {
		//Just fail...
		cancel()
	}
	
	func archiveParsingShouldStop(_ parser: XADArchiveParser) -> Bool {
		return isCancelled
	}
	
	func archiveParser(_ parser: XADArchiveParser, foundEntryWith dict: [XADArchiveKeys : Any]) {
		assert(parser === self.parser)
		entries.append(dict)
	}
}

private func XADOutputTo(_ handle: XADHandle, bytes: UnsafeRawPointer, length: Int32) throws {
	var err: NSError? = nil
	let success = __XADOutputToHandleBytesLengthError(handle, bytes, length, &err)
	guard success else {
		if let err = err {
			throw err
		} else {
			throw XADError(.output)
		}
	}
}
