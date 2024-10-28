//
//  MagneticScrolls.swift
//  Magnetic Scrolls
//
//  Created by C.W. Betts on 10/27/24.
//

import Cocoa
import ZoomPlugIns.ZoomPlugIn
import ZoomPlugIns.ZoomPlugIn.Glk
import ZoomPlugIns.ZoomBabel
import ZoomPlugIns.ZoomStoryConverter

private let magID: Data = "MaSc".data(using: .utf8)!

private struct Maginfo {
	var gv: Int32
	var header: Data
	var title: String
	var bafn: Int32
	var year: Int32
	var ifid: String
	var author: String
}

// Taken from Babel
private let manifest: [Maginfo] = [
	.init(gv: 0,
		  header: Data([0o000, 0o000, 0o000, 0o000, 0o000, 0o000, 0o000, 0o000,
						0o000, 0o000, 0o000, 0o000, 0o000, 0o000, 0o000, 0o000,
						0o000, 0o000, 0o000, 0o000]),
		  title: "The Pawn",
		  bafn: 0,
		  year: 1985,
		  ifid: "MAGNETIC-1",
		  author: "Rob Steggles"),
	.init(gv: 1,
		  header: Data([0o000, 0o004, 0o000, 0o001, 0o007, 0o370, 0o000, 0o000,
						0o340, 0o000, 0o000, 0o000, 0o041, 0o064, 0o000, 0o000,
						0o040, 0o160, 0o000, 0o000]),
		  title: "Guild of Thieves",
		  bafn: 0,
		  year: 1987,
		  ifid: "MAGNETIC-2",
		  author: "Rob Steggles"),
	.init(gv: 2,
		  header: Data([0o000, 0o000, 0o000, 0o000, 0o000, 0o000, 0o000, 0o000,
						0o000, 0o000, 0o000, 0o000, 0o000, 0o000, 0o000, 0o000,
						0o000, 0o000, 0o000, 0o000]),
		  title: "Jinxter",
		  bafn: 0,
		  year: 1987,
		  ifid: "MAGNETIC-3",
		  author: "Georgina Sinclair and Michael Bywater"),
	.init(gv: 4,
		  header: Data([0o000, 0o004, 0o000, 0o001, 0o045, 0o140, 0o000, 0o001,
						0o000, 0o000, 0o000, 0o000, 0o161, 0o017, 0o000, 0o000,
						0o035, 0o210, 0o000, 0o001]),
		  title: "Corruption",
		  bafn: 0,
		  year: 1988,
		  ifid: "MAGNETIC-4",
		  author: "Rob Steggles and Hugh Steers"),
	.init(gv: 4,
		  header: Data([0o000, 0o004, 0o000, 0o001, 0o044, 0o304, 0o000, 0o001,
						0o000, 0o000, 0o000, 0o000, 0o134, 0o137, 0o000, 0o000,
						0o040, 0o230, 0o000, 0o001]),
		  title: "Fish!",
		  bafn: 0,
		  year: 1988,
		  ifid: "MAGNETIC-5",
		  author: "John Molloy, Pete Kemp, Phil South, Rob Steggles"),
	.init(gv: 4,
		  header: Data([0o000, 0o003, 0o000, 0o000, 0o377, 0o000, 0o000, 0o000,
						0o340, 0o000, 0o000, 0o000, 0o221, 0o000, 0o000, 0o000,
						0o036, 0o000, 0o000, 0o001]),
		  title: "Corruption",
		  bafn: 0,
		  year: 1988,
		  ifid: "MAGNETIC-4",
		  author: "Rob Steggles and Hugh Steers"),
	.init(gv: 4,
		  header: Data([0o000, 0o003, 0o000, 0o001, 0o000, 0o000, 0o000, 0o000,
						0o340, 0o000, 0o000, 0o000, 0o175, 0o000, 0o000, 0o000,
						0o037, 0o000, 0o000, 0o001]),
		  title: "Fish!",
		  bafn: 0,
		  year: 1988,
		  ifid: "MAGNETIC-5",
		  author: "John Molloy, Pete Kemp, Phil South, Rob Steggles"),
	.init(gv: 4,
		  header: Data([0o000, 0o003, 0o000, 0o000, 0o335, 0o000, 0o000, 0o000,
						0o140, 0o000, 0o000, 0o000, 0o064, 0o000, 0o000, 0o000,
						0o023, 0o000, 0o000, 0o000]),
		  title: "Myth",
		  bafn: 0,
		  year: 1989,
		  ifid: "MAGNETIC-6",
		  author: "Paul Findley"),
	.init(gv: 4,
		  header: Data([0o000, 0o004, 0o000, 0o001, 0o122, 0o074, 0o000, 0o001,
						0o000, 0o000, 0o000, 0o000, 0o114, 0o146, 0o000, 0o000,
						0o057, 0o240, 0o000, 0o001]),
		  title: "Wonderland",
		  bafn: 0,
		  year: 1990,
		  ifid: "MAGNETIC-7",
		  author: "David Bishop")
]


//TODO: implement ZoomStoryConverter
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
	
	public override class var needsPathPassedToTask: Bool {
		return true
	}

	public override class var supportedFileTypes: [String] {
		return ["public.magnetic-scroll", "mag"]
	}

	public override class func canRun(_ fileURL: URL) -> Bool {
		guard (try? fileURL.checkResourceIsReachable()) ?? false else {
			return fileURL.pathExtension.caseInsensitiveCompare("mag") == .orderedSame
		}
		
		guard let fh = try? FileHandle(forReadingFrom: fileURL),
			  let dat = try? fh.read(upToCount: 4),
			  dat.count == 4 else {
			return false
		}
		
		return dat == magID
	}
	
	public override init?(url gameFile: URL) {
		super.init(url: gameFile)
		clientPath = Bundle(for: MagneticScrolls.self).path(forAuxiliaryExecutable: "magnetic")
	}
	
	public override func idForStory() -> ZoomStoryID? {
		guard let fh = try? FileHandle(forReadingFrom: gameURL),
			  let dat = try? fh.read(upToCount: 42),
			  dat.count == 42 else {
			return nil
		}

		for entry in manifest {
			if (dat[13] < 3 && entry.gv == dat[13]) || dat[12..<32].elementsEqual(entry.header) {
				return ZoomStoryID(idString: entry.ifid)
			}
		}
		return ZoomStoryID(idString: "MAGNETIC-")
	}

	public override func defaultMetadata() throws -> ZoomStory {
		guard let id = idForStory()?.idString,
			  let entry = manifest.first(where: { mi in
				  mi.ifid.caseInsensitiveCompare(id) == .orderedSame
			  }) else {
			return try super.defaultMetadata()
		}
		
		let babel = ZoomBabel(url: gameURL)
		guard let meta = babel.metadata() else {
			return try super.defaultMetadata()
		}
		
		meta.title = entry.title
		meta.year = entry.year
		meta.author = entry.author
		
		return meta
	}
}
