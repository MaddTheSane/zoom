//
//  PreviewProvider.swift
//  ZoomNewQL
//
//  Created by C.W. Betts on 10/19/22.
//

import Cocoa
import Quartz
import ZoomPlugIns
import ZoomPlugIns.ZoomStoryID
import ZoomPlugIns.ZoomBabel
import ZoomView

private let zoomConfigDirectory: URL? = {
	let libraryDirs = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
	for dir in libraryDirs {
		var isDir: ObjCBool = false
		let zoomLib = dir.appendingPathComponent("Zoom")
		if FileManager.default.fileExists(atPath: zoomLib.path, isDirectory: &isDir) {
			if isDir.boolValue {
				return zoomLib
			}
		}
	}
	
	for dir in libraryDirs {
		let zoomLib = dir.appendingPathComponent("Zoom", isDirectory: true)
		do {
			try FileManager.default.createDirectory(at: zoomLib, withIntermediateDirectories: false)
			return zoomLib
		} catch {}
	}
	
	return nil
}()


public class PreviewProvider: QLPreviewProvider, QLPreviewingController {
	
	private func providePreviewforBabel(at fileURL: URL) throws -> QLPreviewReply {
		guard fileURL.isFileURL else {
			throw CocoaError(.fileReadUnsupportedScheme, userInfo: [NSURLErrorKey: fileURL])
		}
		let babel = ZoomBabel(url: fileURL)
		var story = babel.metadata()
		var storyID = story?.storyID
		let image: NSImage?
		if let tmpImage = babel.coverImage() {
			image = tmpImage
		} else {
			// If there's no image, then we need to use a default one
			image = Bundle(for: PreviewProvider.self).image(forResource: "zoom-game")!
		}
		
		// Try to use babel to work out the story ID, if we have no metadata
		if story == nil || storyID == nil {
			storyID = babel.storyID()
		}
		
		// Give up if the ID is still nil
		guard let storyID else {
			// TODO: Better error thrown
			throw CocoaError(.featureUnsupported)
		}

		// Try to load Zoom's built-in metadata if we can
		if let anURL = zoomConfigDirectory?.appendingPathComponent("metadata.iFiction"),
		   let metadata = try? ZoomMetadata(contentsOf: anURL) {
			story = metadata.containsStory(withIdent: storyID) ? metadata.findOrCreateStory(storyID) : story
		}
		
		// If there's no metadata returned, then give up
		guard let story else {
			// TODO: Better error thrown
			throw CocoaError(.featureUnsupported)
		}
		
		// Generate an attributed string describing the story
		let titleFont		= NSFont.boldSystemFont(ofSize: 24)
		let descriptionFont	= NSFont.systemFont(ofSize: 11)
		let smallFont		= NSFont.systemFont(ofSize: 10)
		let ifidFont		= NSFont.boldSystemFont(ofSize: 9)
		let foreground		= NSColor.white
		let background		= NSColor.clear

		let titleCont: AttributeContainer = {
			let titleAttr: [NSAttributedString.Key: Any] = [.font: titleFont,
															.foregroundColor: foreground,
															.backgroundColor: background]
			return try! AttributeContainer(titleAttr, including: AttributeScopes.AppKitAttributes.self)
		}()
		let smallCont: AttributeContainer = {
			let smallAttr: [NSAttributedString.Key: Any] = [.font: smallFont,
															.foregroundColor: foreground,
															.backgroundColor: background]
			return try! AttributeContainer(smallAttr, including: AttributeScopes.AppKitAttributes.self)
		}()
		let ifidCont: AttributeContainer = {
			let ifidAttr: [NSAttributedString.Key: Any] = [.font: ifidFont,
															.foregroundColor: foreground,
															.backgroundColor: background]
			return try! AttributeContainer(ifidAttr, including: AttributeScopes.AppKitAttributes.self)
		}()
		let descrCont: AttributeContainer = {
			let descrAttr: [NSAttributedString.Key: Any] = [.font: descriptionFont,
															.foregroundColor: foreground,
															.backgroundColor: background]
			return try! AttributeContainer(descrAttr, including: AttributeScopes.AppKitAttributes.self)
		}()

		var description = AttributedString()
		
		if let title = story.title {
			description.append(AttributedString("\(title)\n", attributes: titleCont))
		}
		
		description.append(AttributedString("IFID: \(storyID.description)\n", attributes: ifidCont))
		
		if let author = story.author, author.count > 0 {
			var publication = ""
			if story.year > 0 {
				publication = ", published \(story.year)"
			}
			description.append(AttributedString("by \(author)\(publication)\n", attributes: smallCont))
		}
		if let storDes = story.description, storDes.count > 0 {
			description.append(AttributedString("\(storDes)\n", attributes: descrCont))
		} else if let teaser = story.teaser, teaser.count > 0 {
			description.append(AttributedString("\(teaser)\n", attributes: descrCont))
		}
		
		// Decide on the size of the graphics context
		var previewSize = CGSize(width: 760, height: 320)
		
		let nsDescription = try NSAttributedString(description, including: AttributeScopes.AppKitAttributes.self)

		let descriptionRect = nsDescription.boundingRect(with: NSSize(width: (previewSize.width - previewSize.height) - 16, height: 1e8))
		if let image {
			previewSize.height = image.size.height
			if (previewSize.height < 180) {
				previewSize.height = 180
			}
			if (previewSize.height < descriptionRect.size.height + 32) {
				previewSize.height = descriptionRect.size.height + 32
			}
			if (previewSize.height > 320) {
				previewSize.height = 320
			}
			
			previewSize.width *= previewSize.height / 320.0
			if (previewSize.width < 560) {
				previewSize.width = 560
			}
		}

		let reply = QLPreviewReply(contextSize: previewSize, isBitmap: false) { cgContext, reply in
			if let title = story.title {
				reply.title = title
			}
			
			let context = NSGraphicsContext(cgContext: cgContext, flipped: false)
			
			// Start drawing
			NSGraphicsContext.saveGraphicsState()
			NSGraphicsContext.current = context
			context.imageInterpolation = .high
			defer {
				// Done with the drawing
				NSGraphicsContext.restoreGraphicsState()
			}
			
			// Draw the image
			var imageRect = NSRect(x: 8,y: 8, width: 0,height: 0);
			if let image {
				let imageSize = image.size
				imageRect.size = NSSize(width: previewSize.height - 16, height: previewSize.height - 16)
				let ratio = imageSize.height / imageSize.width
				if ratio < 1 {
					imageRect.size.height *= ratio;
				} else {
					imageRect.size.width /= ratio;
				}
				
				image.draw(in: imageRect, from: .zero, operation: .sourceOver, fraction: 1)
			}
			
			// Draw the description
			let descRect = NSRect(x: imageRect.size.width + 24, y: 8, width: (previewSize.width - previewSize.height) - 16, height: previewSize.height - 16)
			nsDescription.draw(in: descRect)
		}
		
		return reply
	}
	
	public func providePreview(for request: QLFilePreviewRequest) async throws -> QLPreviewReply {
		let url = request.fileURL
		let resVals = try url.resourceValues(forKeys: [.contentTypeKey])
		guard let contentType = resVals.contentType else {
			// TODO: Better error thrown
			throw CocoaError(.featureUnsupported)
		}
		
		var skeinData: Data
		var storyID: ZoomStoryID? = nil
		
		switch contentType {
		case UTType("uk.org.logicalshift.zoomsave"):
			// .zoomsave package
			
			// Read in the skein
			let skeinURL = url.appendingPathComponent("Skein.skein", isDirectory: false)
			skeinData = try Data(contentsOf: skeinURL)
			
			// Work out the story ID
			let plistUrl = url.appendingPathComponent("Info.plist", isDirectory: false)
			if let plist = try? Data(contentsOf: plistUrl),
			   let plistDict = (try? PropertyListSerialization.propertyList(from: plist, format: nil)) as? [String: Any],
			   let idString = plistDict["ZoomStoryId"] as? String {
				storyID = ZoomStoryID(idString: idString)
			}
			
		case UTType("uk.org.logicalshift.glksave"):
			// .glksave package

			// Read in the skein
			let skeinURL = url.appendingPathComponent("Skein.skein", isDirectory: false)
			skeinData = try Data(contentsOf: skeinURL)
			
			// Work out the story ID
			let plistUrl = url.appendingPathComponent("Info.plist", isDirectory: false)
			if let plist = try? Data(contentsOf: plistUrl),
			   let plistDict = (try? PropertyListSerialization.propertyList(from: plist, format: nil)) as? [String: Any],
			   let idString = plistDict["ZoomGlkGameId"] as? String {
				storyID = ZoomStoryID(idString: idString)
			}

		default:
			return try providePreviewforBabel(at: url)
		}
		
		// Try to parse the skein
		let skein = ZoomSkein()
		try skein.parseXmlData(skeinData)

		let reply = QLPreviewReply(dataOfContentType: .rtf, contentSize: CGSize(width: 200, height: 200)) { reply in
			// If we've got a skein, then generate an attributed string to represent the transcript of play
			var result = AttributedString()
			var activeItem: ZoomSkeinItem? = skein.activeItem
			
			// Set up the attributes for the fonts
			let transcriptFont = NSFontManager.shared.font(withFamily: "Gill Sans", traits: [.unboldFontMask], weight: 5, size: 12) ?? NSFont.systemFont(ofSize: 12)
			let inputFont = NSFontManager.shared.font(withFamily: "Gill Sans", traits: [.boldFontMask], weight: 9, size: 12) ?? NSFont.systemFont(ofSize: 12)
			let titleFont = NSFontManager.shared.font(withFamily: "Gill Sans", traits: [.boldFontMask], weight: 9, size: 18) ?? NSFont.systemFont(ofSize: 12, weight: .bold)
			
			let transcriptAttributes: AttributeContainer = {
				let titleAttr: [NSAttributedString.Key: Any] = [.font: transcriptFont]
				return try! AttributeContainer(titleAttr, including: AttributeScopes.AppKitAttributes.self)
			}()
			let inputAttributes: AttributeContainer = {
				let titleAttr: [NSAttributedString.Key: Any] = [.font: inputFont]
				return try! AttributeContainer(titleAttr, including: AttributeScopes.AppKitAttributes.self)
			}()
			let titleAttributes: AttributeContainer = {
				let titleAttr: [NSAttributedString.Key: Any] = [.font: titleFont]
				return try! AttributeContainer(titleAttr, including: AttributeScopes.AppKitAttributes.self)
			}()
			let newline = AttributedString("\n", attributes: transcriptAttributes)

			
			// Build the transcript
			while let activeItem2 = activeItem {
				// Append this string
				var inputString: AttributedString? = nil
				var responseString: AttributedString? = nil
				if let command = activeItem2.command {
					inputString = AttributedString(command, attributes: inputAttributes)
				}
				if let result = activeItem2.result {
					responseString = AttributedString(result, attributes: transcriptAttributes)
				}
				
				if let responseString {
					result = responseString + result
				}
				
				if let inputString, activeItem2.parent != nil {
					result = inputString + newline + result
				}
				
				// Move up the tree
				activeItem = activeItem2.parent
			}

			// Add a title indicating which game this came from
			if let storyID {
				let attrStory = AttributedString("IFID: \(storyID.description)", attributes: inputAttributes)
				result = attrStory + newline + newline + result
				
				if let metadataURL = zoomConfigDirectory?.appendingPathComponent("metadata.iFiction"),
				   let metadata = try? ZoomMetadata(contentsOf: metadataURL),
				   let story = metadata.containsStory(withIdent: storyID) ? metadata.findOrCreateStory(storyID) : nil,
				   let title = story.title, title.count > 0 {
					let titleAttr = AttributedString("Saved game from \(title)", attributes: titleAttributes)
					result = titleAttr + newline + result
				}
			}
			
			let nsResult = try NSAttributedString(result, including: AttributeScopes.AppKitAttributes.self)
			guard let theRTF = nsResult.rtf(from: NSRange(location: 0, length: nsResult.length - 1)) else {
				// TODO: Better error thrown
				throw CocoaError(.featureUnsupported)
			}
			
			return theRTF
		}
		
        return reply
    }
}
